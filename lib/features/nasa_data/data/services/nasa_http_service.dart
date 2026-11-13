import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:luna_sight/core/logging/app_logger.dart';
import 'package:luna_sight/features/nasa_data/data/datasources/nasa_product_catalog.dart';
import 'package:luna_sight/features/nasa_data/domain/failures/nasa_data_failures.dart';

/// Callback signature for streaming byte transfer progress.
typedef OnBytesReceivedCallback = void Function(
  int bytesReceived,
  int? totalBytesExpected,
);

/// Remote HTTP communication service tailored for NASA GSFC PGDA data endpoints.
class NasaHttpService {
  final http.Client _client;
  final Duration headerTimeout;
  final Duration streamIdleTimeout;
  final int maxRetries;

  NasaHttpService({
    http.Client? client,
    this.headerTimeout = const Duration(seconds: 45),
    this.streamIdleTimeout = const Duration(seconds: 30),
    this.maxRetries = 3,
  }) : _client = client ?? http.Client();

  /// Validates remote endpoint capabilities with a HEAD request.
  Future<RemoteResourceMetadata> inspectRemoteResource(Uri uri) async {
    _ensureTrustedNasaUri(uri);

    return _executeWithRetry(() async {
      final request = http.Request('HEAD', uri);
      final streamedResponse = await _client
          .send(request)
          .timeout(headerTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      _validateStatusCode(response.statusCode, uri, response.headers);

      final contentLengthStr = response.headers['content-length'];
      final contentLength = contentLengthStr != null
          ? int.tryParse(contentLengthStr)
          : null;
      final acceptRanges = response.headers['accept-ranges']?.toLowerCase();
      final supportsRange = acceptRanges == 'bytes';
      final etag = response.headers['etag'];
      final lastModified = response.headers['last-modified'];

      return RemoteResourceMetadata(
        uri: uri,
        contentLength: contentLength,
        supportsRangeRequests: supportsRange,
        etag: etag,
        lastModified: lastModified,
      );
    });
  }

  /// Downloads an official NASA asset, supporting resume if ranges are supported.
  ///
  /// Recalculates file length on every attempt, validates Content-Range, Content-Length,
  /// respects stream idle timeouts, and gracefully recovers from HTTP 416 or 200 responses.
  Future<DownloadCompletionInfo> streamDownloadToFile({
    required Uri uri,
    required File destinationFile,
    OnBytesReceivedCallback? onProgress,
    int? expectedTotalBytes,
    Completer<void>? cancelSignal,
  }) async {
    _ensureTrustedNasaUri(uri);

    return _executeWithRetry(() async {
      if (cancelSignal != null && cancelSignal.isCompleted) {
        throw const AcquisitionCancelledFailure();
      }

      // Requirement 1 & 2: Recalculate actual file length immediately before every request attempt
      int existingBytes = 0;
      if (await destinationFile.exists()) {
        existingBytes = await destinationFile.length();
      }

      // If existing bytes already match or exceed expected total, check if 416 or finished
      if (expectedTotalBytes != null && existingBytes > expectedTotalBytes) {
        AppLogger.warning(
          'Existing file size ($existingBytes) exceeds expected ($expectedTotalBytes). Resetting.',
        );
        if (await destinationFile.exists()) {
          await destinationFile.delete();
        }
        existingBytes = 0;
      }

      final request = http.Request('GET', uri);
      final willAttemptResume = existingBytes > 0;
      if (willAttemptResume) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await _client
            .send(request)
            .timeout(
              headerTimeout,
              onTimeout: () => throw const NasaNetworkFailure(
                message: 'Timeout waiting for NASA server headers.',
              ),
            );
      } catch (e) {
        if (e is NasaDataFailure) rethrow;
        throw NasaNetworkFailure(
          message: 'Failed to establish connection to NASA server: $e',
          cause: e,
        );
      }

      final statusCode = streamedResponse.statusCode;
      final headers = streamedResponse.headers;

      // Handle 416 Range Not Satisfiable by resetting corrupted/stale partial file
      if (statusCode == 416) {
        AppLogger.warning(
          'NASA server returned 416 Range Not Satisfiable for offset $existingBytes. Resetting partial file.',
        );
        if (await destinationFile.exists()) {
          await destinationFile.delete();
        }
        throw const NasaNetworkFailure(
          message: 'Range Not Satisfiable (HTTP 416). Resetting file for clean download.',
          statusCode: 416,
        );
      }

      _validateStatusCode(statusCode, uri, headers);

      IOSink sink;
      int bytesReceivedSoFar = 0;
      int? effectiveTotalBytes;

      if (statusCode == 206) {
        // Requirement 3 & 4: Validate all Content-Range components
        final contentRangeHeader = headers['content-range'];
        final rangeInfo = _parseContentRange(contentRangeHeader);

        if (rangeInfo == null) {
          throw const NasaNetworkFailure(
            message:
                'Malformed or missing Content-Range header in 206 response.',
            statusCode: 206,
          );
        }

        // Start offset must match existing local bytes exactly
        if (rangeInfo.start != existingBytes) {
          AppLogger.warning(
            'Inconsistent range start (${rangeInfo.start}) for local offset $existingBytes. Resetting file.',
          );
          if (await destinationFile.exists()) {
            await destinationFile.delete();
          }
          throw const NasaNetworkFailure(
            message: 'Inconsistent Content-Range start received during resume.',
            statusCode: 206,
          );
        }

        // Total resource size check
        if (rangeInfo.total != null &&
            expectedTotalBytes != null &&
            rangeInfo.total != expectedTotalBytes) {
          throw IntegrityValidationFailure(
            message:
                'Content-Range total (${rangeInfo.total}) does not match expected size ($expectedTotalBytes).',
            expectedSize: expectedTotalBytes,
            actualSize: rangeInfo.total,
          );
        }

        // Content-Length consistency with range length
        final lengthHeader = headers['content-length'];
        if (lengthHeader != null) {
          final declaredLength = int.tryParse(lengthHeader);
          final expectedRangeLength = (rangeInfo.end - rangeInfo.start) + 1;
          if (declaredLength != null && declaredLength != expectedRangeLength) {
            throw const NasaNetworkFailure(
              message:
                  'Content-Length does not match Content-Range declared span.',
              statusCode: 206,
            );
          }
        }

        effectiveTotalBytes = rangeInfo.total ?? expectedTotalBytes;
        bytesReceivedSoFar = existingBytes;
        sink = destinationFile.openWrite(mode: FileMode.append);
      } else if (statusCode == 200) {
        // Requirement 7: If a resume attempt receives 200, restart safely from byte zero
        if (willAttemptResume) {
          AppLogger.info(
            'Server responded with 200 OK instead of 206 Partial Content. Resetting partial file to avoid byte duplication.',
          );
          if (await destinationFile.exists()) {
            await destinationFile.delete();
          }
        }
        final lengthHeader = headers['content-length'];
        effectiveTotalBytes = lengthHeader != null
            ? int.tryParse(lengthHeader)
            : expectedTotalBytes;
        bytesReceivedSoFar = 0;
        sink = destinationFile.openWrite(mode: FileMode.write);
      } else {
        throw NasaNetworkFailure(
          message: 'Unexpected HTTP status code: $statusCode',
          statusCode: statusCode,
        );
      }

      onProgress?.call(bytesReceivedSoFar, effectiveTotalBytes);

      StreamSubscription<List<int>>? subscription;
      final streamCompleter = Completer<void>();
      Timer? idleTimer;

      void resetIdleTimeout() {
        idleTimer?.cancel();
        idleTimer = Timer(streamIdleTimeout, () {
          subscription?.cancel();
          if (!streamCompleter.isCompleted) {
            streamCompleter.completeError(
              NasaNetworkFailure(
                message:
                    'Stream idle timeout exceeded (${streamIdleTimeout.inSeconds}s without data).',
              ),
            );
          }
        });
      }

      resetIdleTimeout();

      try {
        subscription = streamedResponse.stream.listen(
          (chunk) {
            resetIdleTimeout();

            if (cancelSignal != null && cancelSignal.isCompleted) {
              idleTimer?.cancel();
              subscription?.cancel();
              if (!streamCompleter.isCompleted) {
                streamCompleter.completeError(
                  const AcquisitionCancelledFailure(),
                );
              }
              return;
            }

            sink.add(chunk);
            bytesReceivedSoFar += chunk.length;
            onProgress?.call(bytesReceivedSoFar, effectiveTotalBytes);
          },
          onError: (Object error, StackTrace stack) {
            idleTimer?.cancel();
            if (!streamCompleter.isCompleted) {
              streamCompleter.completeError(
                NasaNetworkFailure(
                  message: 'Stream transmission failed: $error',
                  cause: error,
                  stackTrace: stack,
                ),
              );
            }
          },
          onDone: () {
            idleTimer?.cancel();
            if (!streamCompleter.isCompleted) {
              streamCompleter.complete();
            }
          },
          cancelOnError: true,
        );

        if (cancelSignal != null) {
          cancelSignal.future.then((_) {
            idleTimer?.cancel();
            if (!streamCompleter.isCompleted) {
              subscription?.cancel();
              streamCompleter.completeError(
                const AcquisitionCancelledFailure(),
              );
            }
          });
        }

        await streamCompleter.future;
      } finally {
        idleTimer?.cancel();
        await sink.flush();
        await sink.close();
      }

      // Check Content-Length integrity if expected total was supplied
      if (effectiveTotalBytes != null &&
          bytesReceivedSoFar != effectiveTotalBytes) {
        throw IntegrityValidationFailure(
          message:
              'Transfer interrupted. Expected $effectiveTotalBytes bytes, received $bytesReceivedSoFar bytes.',
          expectedSize: effectiveTotalBytes,
          actualSize: bytesReceivedSoFar,
        );
      }

      return DownloadCompletionInfo(
        totalBytesWritten: bytesReceivedSoFar,
        etag: headers['etag'],
        lastModified: headers['last-modified'],
      );
    });
  }

  void _ensureTrustedNasaUri(Uri uri) {
    if (!NasaProductCatalog.isApprovedNasaUrl(uri)) {
      throw UntrustedUrlFailure(url: uri.toString());
    }
  }

  void _validateStatusCode(int code, Uri uri, Map<String, String> headers) {
    if (code >= 200 && code < 300) {
      return;
    }

    if (code == 403) {
      throw NasaForbiddenFailure(
        message: 'Access to NASA asset at $uri was forbidden (HTTP 403).',
      );
    }
    if (code == 404) {
      throw NasaNetworkFailure(
        message: 'NASA asset not found at $uri (HTTP 404).',
        statusCode: 404,
      );
    }
    if (code == 416) {
      throw const NasaNetworkFailure(
        message: 'Range Not Satisfiable (HTTP 416).',
        statusCode: 416,
      );
    }
    if (code == 429) {
      final retryAfterStr = headers['retry-after'];
      Duration? retryAfter;
      if (retryAfterStr != null) {
        final seconds = int.tryParse(retryAfterStr);
        if (seconds != null) {
          retryAfter = Duration(seconds: seconds);
        }
      }
      throw NasaRateLimitedFailure(
        message: 'NASA server rate limit exceeded (HTTP 429).',
        retryAfter: retryAfter,
      );
    }

    throw NasaNetworkFailure(
      message: 'NASA server returned error status HTTP $code.',
      statusCode: code,
    );
  }

  /// Retries transient network failures with exponential backoff and jitter.
  Future<T> _executeWithRetry<T>(Future<T> Function() action) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        return await action();
      } catch (e) {
        // Never retry permanent errors or cancellations
        if (e is NasaForbiddenFailure ||
            (e is NasaNetworkFailure && e.statusCode == 404) ||
            e is UntrustedUrlFailure ||
            e is AcquisitionCancelledFailure ||
            attempts >= maxRetries) {
          rethrow;
        }

        Duration delay = Duration(milliseconds: 300 * (1 << (attempts - 1)));
        if (e is NasaRateLimitedFailure && e.retryAfter != null) {
          delay = e.retryAfter!;
        }

        AppLogger.warning(
          'Transient network failure ($e). Retrying attempt $attempts/$maxRetries in ${delay.inMilliseconds}ms...',
        );
        await Future<void>.delayed(delay);
      }
    }
  }

  ({int start, int end, int? total})? _parseContentRange(String? header) {
    if (header == null) return null;
    final regex = RegExp(r'^bytes\s+(\d+)-(\d+)\/(\d+|\*)$');
    final match = regex.firstMatch(header.trim());
    if (match == null) return null;

    final start = int.parse(match.group(1)!);
    final end = int.parse(match.group(2)!);
    final totalStr = match.group(3)!;
    final total = totalStr == '*' ? null : int.parse(totalStr);

    if (end < start) return null;

    return (start: start, end: end, total: total);
  }

  void dispose() {
    _client.close();
  }
}

class RemoteResourceMetadata {
  final Uri uri;
  final int? contentLength;
  final bool supportsRangeRequests;
  final String? etag;
  final String? lastModified;

  const RemoteResourceMetadata({
    required this.uri,
    this.contentLength,
    required this.supportsRangeRequests,
    this.etag,
    this.lastModified,
  });
}

class DownloadCompletionInfo {
  final int totalBytesWritten;
  final String? etag;
  final String? lastModified;

  const DownloadCompletionInfo({
    required this.totalBytesWritten,
    this.etag,
    this.lastModified,
  });
}

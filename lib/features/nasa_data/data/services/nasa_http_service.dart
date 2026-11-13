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
  final Duration requestTimeout;
  final int maxRetries;

  NasaHttpService({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 45),
    this.maxRetries = 3,
  }) : _client = client ?? http.Client();

  /// Validates remote endpoint capabilities with a HEAD request.
  Future<RemoteResourceMetadata> inspectRemoteResource(Uri uri) async {
    _ensureTrustedNasaUri(uri);

    return _executeWithRetry(() async {
      final request = http.Request('HEAD', uri);
      final streamedResponse = await _client
          .send(request)
          .timeout(requestTimeout);
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
  Future<DownloadCompletionInfo> streamDownloadToFile({
    required Uri uri,
    required File destinationFile,
    OnBytesReceivedCallback? onProgress,
    int? expectedTotalBytes,
    Completer<void>? cancelSignal,
  }) async {
    _ensureTrustedNasaUri(uri);

    int existingBytes = 0;
    if (await destinationFile.exists()) {
      existingBytes = await destinationFile.length();
    }

    return _executeWithRetry(() async {
      final request = http.Request('GET', uri);

      final willAttemptResume = existingBytes > 0;
      if (willAttemptResume) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      final streamedResponse = await _client
          .send(request)
          .timeout(requestTimeout);
      final statusCode = streamedResponse.statusCode;
      final headers = streamedResponse.headers;

      _validateStatusCode(statusCode, uri, headers);

      IOSink sink;
      int bytesReceivedSoFar = 0;
      int? effectiveTotalBytes;

      if (statusCode == 206) {
        // Partial Content verified
        final contentRange = headers['content-range'];
        final rangeInfo = _parseContentRange(contentRange);
        if (rangeInfo == null || rangeInfo.start != existingBytes) {
          // Inconsistent range received; reset file to prevent corrupted byte alignment
          AppLogger.warning(
            'Received inconsistent range "$contentRange" for expected offset $existingBytes. Resetting transfer.',
          );
          if (await destinationFile.exists()) {
            await destinationFile.delete();
          }
          throw const NasaNetworkFailure(
            message: 'Inconsistent Content-Range received from server during resume.',
            statusCode: 206,
          );
        }
        effectiveTotalBytes = rangeInfo.total ?? expectedTotalBytes;
        bytesReceivedSoFar = existingBytes;
        sink = destinationFile.openWrite(mode: FileMode.append);
      } else if (statusCode == 200) {
        // Normal Full Stream
        if (willAttemptResume) {
          // Server did not satisfy range; reset partial file to prevent corrupted duplication
          AppLogger.info(
            'Server responded with 200 OK instead of 206 Partial Content. Resetting local partial file.',
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

      try {
        subscription = streamedResponse.stream.listen(
          (chunk) {
            if (cancelSignal != null && cancelSignal.isCompleted) {
              subscription?.cancel();
              streamCompleter.completeError(
                const AcquisitionCancelledFailure(),
              );
              return;
            }

            sink.add(chunk);
            bytesReceivedSoFar += chunk.length;
            onProgress?.call(bytesReceivedSoFar, effectiveTotalBytes);
          },
          onError: (Object error, StackTrace stack) {
            streamCompleter.completeError(
              NasaNetworkFailure(
                message: 'Stream transmission failed: $error',
                cause: error,
                stackTrace: stack,
              ),
            );
          },
          onDone: () {
            streamCompleter.complete();
          },
          cancelOnError: true,
        );

        if (cancelSignal != null) {
          cancelSignal.future.then((_) {
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
        await sink.flush();
        await sink.close();
      }

      // Check Content-Length integrity if server supplied it
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

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:luna_sight/features/nasa_data/data/services/nasa_http_service.dart';
import 'package:luna_sight/features/nasa_data/domain/failures/nasa_data_failures.dart';

void main() {
  late Directory tempDir;
  late File targetFile;
  final validUri = Uri.parse(
    'https://pgda.gsfc.nasa.gov/data/LOLA_5mpp/87S/ldem_87s_5mpp.tif',
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nasa_http_test_');
    targetFile = File('${tempDir.path}/test_download.part');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('NasaHttpService Range Completeness & Retry Tests', () {
    test(
      'inspectRemoteResource parses Content-Length and Accept-Ranges properly',
      () async {
        final mockClient = http_testing.MockClient((request) async {
          expect(request.method, 'HEAD');
          return http.Response(
            '',
            200,
            headers: {
              'content-length': '3465285714',
              'accept-ranges': 'bytes',
              'etag': '"ce8c1052"',
              'last-modified': 'Thu, 14 Oct 2021 12:54:49 GMT',
            },
          );
        });

        final service = NasaHttpService(client: mockClient);
        final meta = await service.inspectRemoteResource(validUri);

        expect(meta.contentLength, 3465285714);
        expect(meta.supportsRangeRequests, isTrue);
        expect(meta.etag, '"ce8c1052"');
        expect(meta.lastModified, 'Thu, 14 Oct 2021 12:54:49 GMT');
      },
    );

    test('Partial transfer followed by retry resumes with fresh offset and without byte duplication', () async {
      int requestCount = 0;
      final mockClient = http_testing.MockClient.streaming((
        request,
        bodyStream,
      ) async {
        requestCount++;
        if (requestCount == 1) {
          // Attempt 1: Start fresh (bytes 0-), send 300 bytes and simulate socket error
          final controller = StreamController<List<int>>();
          controller.add(List.generate(300, (i) => i % 256));
          controller.addError(const SocketException('Interrupted connection'));
          controller.close();
          return http.StreamedResponse(
            controller.stream,
            206,
            headers: {
              'content-range': 'bytes 0-999/1000',
              'content-length': '1000',
            },
          );
        } else {
          // Attempt 2: Must request Range from exactly 300 (bytes=300-)
          expect(request.headers['Range'], 'bytes=300-');
          final remainingBytes = List.generate(700, (i) => (i + 300) % 256);
          return http.StreamedResponse(
            Stream.value(remainingBytes),
            206,
            headers: {
              'content-range': 'bytes 300-999/1000',
              'content-length': '700',
            },
          );
        }
      });

      final service = NasaHttpService(client: mockClient, maxRetries: 3);
      final info = await service.streamDownloadToFile(
        uri: validUri,
        destinationFile: targetFile,
        expectedTotalBytes: 1000,
      );

      expect(requestCount, 2);
      expect(info.totalBytesWritten, 1000);
      expect(await targetFile.length(), 1000);

      final finalBytes = await targetFile.readAsBytes();
      for (int i = 0; i < 1000; i++) {
        expect(finalBytes[i], i % 256);
      }
    });

    test(
      'Unknown total (*) with complete segment and no Content-Length succeeds',
      () async {
        final payload = List.generate(100, (i) => i % 256);
        final mockClient = http_testing.MockClient.streaming((
          request,
          bodyStream,
        ) async {
          return http.StreamedResponse(
            Stream.value(payload),
            206,
            headers: {
              'content-range': 'bytes 0-99/*',
              // No Content-Length
            },
          );
        });

        final service = NasaHttpService(client: mockClient);
        final info = await service.streamDownloadToFile(
          uri: validUri,
          destinationFile: targetFile,
        );

        expect(info.totalBytesWritten, 100);
        expect(await targetFile.length(), 100);
      },
    );

    test('Unknown total (*) with truncated segment and no Content-Length fails segment validation', () async {
      // Range declares 0-99 (100 bytes), but stream delivers only 40 bytes
      final truncatedPayload = List.generate(40, (i) => i % 256);
      final mockClient = http_testing.MockClient.streaming((
        request,
        bodyStream,
      ) async {
        return http.StreamedResponse(
          Stream.value(truncatedPayload),
          206,
          headers: {'content-range': 'bytes 0-99/*'},
        );
      });

      final service = NasaHttpService(client: mockClient, maxRetries: 1);

      await expectLater(
        () => service.streamDownloadToFile(
          uri: validUri,
          destinationFile: targetFile,
        ),
        throwsA(isA<IntegrityValidationFailure>()),
      );
    });

    test('Numeric total with end >= total fails validation', () async {
      final mockClient = http_testing.MockClient.streaming((
        request,
        bodyStream,
      ) async {
        return http.StreamedResponse(
          Stream.value([1, 2, 3]),
          206,
          headers: {
            'content-range': 'bytes 0-100/100', // end offset 100 >= total 100
          },
        );
      });

      final service = NasaHttpService(client: mockClient, maxRetries: 1);

      await expectLater(
        () => service.streamDownloadToFile(
          uri: validUri,
          destinationFile: targetFile,
        ),
        throwsA(isA<IntegrityValidationFailure>()),
      );
    });

    test(
      'Numeric total with valid partial segment succeeds and updates file',
      () async {
        final payload = List.generate(50, (i) => i);
        final mockClient = http_testing.MockClient.streaming((
          request,
          bodyStream,
        ) async {
          return http.StreamedResponse(
            Stream.value(payload),
            206,
            headers: {
              'content-range': 'bytes 0-49/200',
              'content-length': '50',
            },
          );
        });

        final service = NasaHttpService(client: mockClient);
        final info = await service.streamDownloadToFile(
          uri: validUri,
          destinationFile: targetFile,
        );

        expect(info.totalBytesWritten, 50);
        expect(await targetFile.length(), 50);
      },
    );

    test('Segment body shorter than its declared Content-Range span throws IntegrityValidationFailure', () async {
      // Declares bytes 0-49 (50 bytes), sends 25 bytes
      final shortPayload = List.generate(25, (i) => i);
      final mockClient = http_testing.MockClient.streaming((
        request,
        bodyStream,
      ) async {
        return http.StreamedResponse(
          Stream.value(shortPayload),
          206,
          headers: {'content-range': 'bytes 0-49/100', 'content-length': '50'},
        );
      });

      final service = NasaHttpService(client: mockClient, maxRetries: 1);

      await expectLater(
        () => service.streamDownloadToFile(
          uri: validUri,
          destinationFile: targetFile,
        ),
        throwsA(isA<IntegrityValidationFailure>()),
      );
    });

    test('Segment body longer than its declared Content-Range span throws IntegrityValidationFailure', () async {
      // Declares bytes 0-49 (50 bytes), sends 60 bytes
      final longPayload = List.generate(60, (i) => i);
      final mockClient = http_testing.MockClient.streaming((
        request,
        bodyStream,
      ) async {
        return http.StreamedResponse(
          Stream.value(longPayload),
          206,
          headers: {'content-range': 'bytes 0-49/100', 'content-length': '50'},
        );
      });

      final service = NasaHttpService(client: mockClient, maxRetries: 1);

      await expectLater(
        () => service.streamDownloadToFile(
          uri: validUri,
          destinationFile: targetFile,
        ),
        throwsA(isA<IntegrityValidationFailure>()),
      );
    });

    test(
      'Rejects invalid Content-Range start offset and resets file',
      () async {
        await targetFile.writeAsBytes(List.generate(200, (i) => i));

        final mockClient = http_testing.MockClient((request) async {
          return http.Response.bytes(
            [1, 2, 3],
            206,
            headers: {
              'content-range': 'bytes 0-202/1000',
              'content-length': '3',
            },
          );
        });

        final service = NasaHttpService(client: mockClient, maxRetries: 1);

        await expectLater(
          () => service.streamDownloadToFile(
            uri: validUri,
            destinationFile: targetFile,
            expectedTotalBytes: 1000,
          ),
          throwsA(isA<NasaNetworkFailure>()),
        );

        expect(await targetFile.exists(), isFalse);
      },
    );

    test('Rejects invalid Content-Range end (end < start)', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response.bytes(
          [1, 2, 3],
          206,
          headers: {'content-range': 'bytes 50-20/1000', 'content-length': '3'},
        );
      });

      final service = NasaHttpService(client: mockClient, maxRetries: 1);

      await expectLater(
        () => service.streamDownloadToFile(
          uri: validUri,
          destinationFile: targetFile,
          expectedTotalBytes: 1000,
        ),
        throwsA(isA<NasaNetworkFailure>()),
      );
    });

    test('Rejects inconsistent Content-Range total size', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response.bytes(
          [1, 2, 3],
          206,
          headers: {'content-range': 'bytes 0-2/5000', 'content-length': '3'},
        );
      });

      final service = NasaHttpService(client: mockClient, maxRetries: 1);

      await expectLater(
        () => service.streamDownloadToFile(
          uri: validUri,
          destinationFile: targetFile,
          expectedTotalBytes: 1000,
        ),
        throwsA(isA<IntegrityValidationFailure>()),
      );
    });

    test('Recovers from HTTP 416 Range Not Satisfiable by resetting file and retrying clean download', () async {
      await targetFile.writeAsBytes(List.generate(500, (i) => i));

      int attempts = 0;
      final mockClient = http_testing.MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          expect(request.headers['Range'], 'bytes=500-');
          return http.Response('Requested range not satisfiable', 416);
        } else {
          expect(request.headers.containsKey('Range'), isFalse);
          return http.Response.bytes(
            [10, 20, 30],
            200,
            headers: {'content-length': '3'},
          );
        }
      });

      final service = NasaHttpService(client: mockClient, maxRetries: 2);
      final info = await service.streamDownloadToFile(
        uri: validUri,
        destinationFile: targetFile,
        expectedTotalBytes: 3,
      );

      expect(attempts, 2);
      expect(info.totalBytesWritten, 3);
      expect(await targetFile.length(), 3);
    });

    test(
      'Resets partial file when server sends 200 OK during resume attempt',
      () async {
        await targetFile.writeAsBytes([1, 2, 3, 4]);

        final mockClient = http_testing.MockClient((request) async {
          return http.Response.bytes(
            [100, 200],
            200,
            headers: {'content-length': '2'},
          );
        });

        final service = NasaHttpService(client: mockClient);
        final info = await service.streamDownloadToFile(
          uri: validUri,
          destinationFile: targetFile,
          expectedTotalBytes: 2,
        );

        expect(info.totalBytesWritten, 2);
        expect(await targetFile.length(), 2);
        expect(await targetFile.readAsBytes(), [100, 200]);
      },
    );

    test('Stream idle timeout triggers failure and cleans up', () async {
      final mockClient = http_testing.MockClient.streaming((
        request,
        bodyStream,
      ) async {
        final controller = StreamController<List<int>>();
        controller.add([1, 2, 3]);
        return http.StreamedResponse(controller.stream, 200);
      });

      final service = NasaHttpService(
        client: mockClient,
        streamIdleTimeout: const Duration(milliseconds: 100),
        maxRetries: 1,
      );

      await expectLater(
        () => service.streamDownloadToFile(
          uri: validUri,
          destinationFile: targetFile,
        ),
        throwsA(isA<NasaNetworkFailure>()),
      );
    });

    test(
      'Cancellation during download aborts cleanly without retrying',
      () async {
        final cancelSignal = Completer<void>();
        int attempts = 0;

        final mockClient = http_testing.MockClient.streaming((
          request,
          bodyStream,
        ) async {
          attempts++;
          final stream = Stream<List<int>>.periodic(
            const Duration(milliseconds: 40),
            (count) => [count],
          );
          return http.StreamedResponse(stream, 200);
        });

        final service = NasaHttpService(client: mockClient, maxRetries: 3);

        final downloadFuture = service.streamDownloadToFile(
          uri: validUri,
          destinationFile: targetFile,
          cancelSignal: cancelSignal,
        );

        Future.delayed(const Duration(milliseconds: 60), () {
          cancelSignal.complete();
        });

        await expectLater(
          downloadFuture,
          throwsA(isA<AcquisitionCancelledFailure>()),
        );

        expect(attempts, 1);
      },
    );
  });
}

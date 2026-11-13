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

  group('NasaHttpService Tests', () {
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

    test('streamDownloadToFile succeeds with HTTP 200 full stream and verifies size', () async {
      final payload = List.generate(1024, (i) => i % 256);
      final mockClient = http_testing.MockClient((request) async {
        return http.Response.bytes(
          payload,
          200,
          headers: {'content-length': '1024', 'etag': '"test-etag"'},
        );
      });

      final service = NasaHttpService(client: mockClient);
      int progressUpdates = 0;

      final info = await service.streamDownloadToFile(
        uri: validUri,
        destinationFile: targetFile,
        expectedTotalBytes: 1024,
        onProgress: (received, total) {
          progressUpdates++;
          expect(total, 1024);
        },
      );

      expect(info.totalBytesWritten, 1024);
      expect(await targetFile.exists(), isTrue);
      expect(await targetFile.length(), 1024);
      expect(progressUpdates, greaterThan(0));
    });

    test('streamDownloadToFile resumes existing bytes with HTTP 206 Partial Content', () async {
      // Simulate 500 existing bytes
      final existingBytes = List.generate(500, (i) => i % 256);
      await targetFile.writeAsBytes(existingBytes);

      final additionalBytes = List.generate(524, (i) => (i + 500) % 256);

      final mockClient = http_testing.MockClient((request) async {
        expect(request.headers['Range'], 'bytes=500-');
        return http.Response.bytes(
          additionalBytes,
          206,
          headers: {
            'content-range': 'bytes 500-1023/1024',
            'content-length': '524',
          },
        );
      });

      final service = NasaHttpService(client: mockClient);
      final info = await service.streamDownloadToFile(
        uri: validUri,
        destinationFile: targetFile,
        expectedTotalBytes: 1024,
      );

      expect(info.totalBytesWritten, 1024);
      expect(await targetFile.length(), 1024);
    });

    test('streamDownloadToFile resets file when server sends 200 OK instead of 206 on resume', () async {
      // Existing partial bytes
      await targetFile.writeAsBytes(List.generate(300, (i) => 1));

      final fullPayload = List.generate(600, (i) => 2);
      final mockClient = http_testing.MockClient((request) async {
        return http.Response.bytes(
          fullPayload,
          200,
          headers: {'content-length': '600'},
        );
      });

      final service = NasaHttpService(client: mockClient);
      final info = await service.streamDownloadToFile(
        uri: validUri,
        destinationFile: targetFile,
        expectedTotalBytes: 600,
      );

      expect(info.totalBytesWritten, 600);
      expect(await targetFile.length(), 600);
    });

    test(
      'Rejects untrusted non-approved URLs with UntrustedUrlFailure',
      () async {
        final untrustedUri = Uri.parse('https://evil-mirror.com/file.tif');
        final service = NasaHttpService();

        expect(
          () => service.inspectRemoteResource(untrustedUri),
          throwsA(isA<UntrustedUrlFailure>()),
        );

        expect(
          () => service.streamDownloadToFile(
            uri: untrustedUri,
            destinationFile: targetFile,
          ),
          throwsA(isA<UntrustedUrlFailure>()),
        );
      },
    );

    test('Throws NasaForbiddenFailure on 403 without retrying', () async {
      int attempts = 0;
      final mockClient = http_testing.MockClient((request) async {
        attempts++;
        return http.Response('Forbidden', 403);
      });

      final service = NasaHttpService(client: mockClient, maxRetries: 3);

      await expectLater(
        () => service.streamDownloadToFile(
          uri: validUri,
          destinationFile: targetFile,
        ),
        throwsA(isA<NasaForbiddenFailure>()),
      );
      expect(attempts, 1);
    });

    test('Throws NasaNetworkFailure on 404 without retrying', () async {
      int attempts = 0;
      final mockClient = http_testing.MockClient((request) async {
        attempts++;
        return http.Response('Not Found', 404);
      });

      final service = NasaHttpService(client: mockClient, maxRetries: 3);

      await expectLater(
        () => service.streamDownloadToFile(
          uri: validUri,
          destinationFile: targetFile,
        ),
        throwsA(isA<NasaNetworkFailure>()),
      );
      expect(attempts, 1);
    });

    test('Handles 429 Rate Limiting with Retry-After', () async {
      int attempts = 0;
      final mockClient = http_testing.MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          return http.Response(
            'Too Many Requests',
            429,
            headers: {'retry-after': '0'},
          );
        }
        return http.Response.bytes(
          [1, 2, 3],
          200,
          headers: {'content-length': '3'},
        );
      });

      final service = NasaHttpService(client: mockClient, maxRetries: 2);
      final info = await service.streamDownloadToFile(
        uri: validUri,
        destinationFile: targetFile,
      );

      expect(attempts, 2);
      expect(info.totalBytesWritten, 3);
    });

    test('Supports explicit cancellation signal', () async {
      final cancelSignal = Completer<void>();
      final mockClient = http_testing.MockClient.streaming((
        request,
        bodyStream,
      ) async {
        final stream = Stream<List<int>>.periodic(
          const Duration(milliseconds: 50),
          (count) => [count],
        );
        return http.StreamedResponse(stream, 200);
      });

      final service = NasaHttpService(client: mockClient);

      final downloadFuture = service.streamDownloadToFile(
        uri: validUri,
        destinationFile: targetFile,
        cancelSignal: cancelSignal,
      );

      // Trigger cancellation shortly after starting
      Future.delayed(const Duration(milliseconds: 80), () {
        cancelSignal.complete();
      });

      await expectLater(
        downloadFuture,
        throwsA(isA<AcquisitionCancelledFailure>()),
      );
    });

    test(
      'Throws IntegrityValidationFailure on truncated transmission',
      () async {
        final mockClient = http_testing.MockClient((request) async {
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-length': '10'}, // Expected 10, sent 3
          );
        });

        final service = NasaHttpService(client: mockClient, maxRetries: 1);

        await expectLater(
          () => service.streamDownloadToFile(
            uri: validUri,
            destinationFile: targetFile,
            expectedTotalBytes: 10,
          ),
          throwsA(isA<IntegrityValidationFailure>()),
        );
      },
    );
  });
}

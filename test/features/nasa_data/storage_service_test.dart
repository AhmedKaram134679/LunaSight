import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/nasa_data/data/storage/local_data_storage_service.dart';
import 'package:luna_sight/features/nasa_data/domain/failures/nasa_data_failures.dart';

void main() {
  late Directory testDir;
  late LocalDataStorageService storage;

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('nasa_storage_test_');
    storage = LocalDataStorageService(baseStorageDirectory: testDir);
    await storage.initialize();
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('LocalDataStorageService Tests', () {
    test('Initializes directory structures properly', () async {
      expect(await Directory('${testDir.path}/completed').exists(), isTrue);
      expect(await Directory('${testDir.path}/temp').exists(), isTrue);
      expect(await Directory('${testDir.path}/meta').exists(), isTrue);
    });

    test('Prevents path traversal attacks in product ID', () {
      expect(
        () => storage.getTempFile('../escape'),
        throwsA(isA<NasaStorageFailure>()),
      );
      expect(
        () => storage.getCompletedFile('sub/dir', 'tif'),
        throwsA(isA<NasaStorageFailure>()),
      );
      expect(
        () => storage.deleteAsset('..'),
        throwsA(isA<NasaStorageFailure>()),
      );
    });

    test('Atomically commits asset and computes SHA-256', () async {
      final tempFile = storage.getTempFile('test_product');
      final payload = List.generate(512, (i) => i % 256);
      await tempFile.writeAsBytes(payload);

      final sha = await storage.computeSha256(tempFile);
      expect(sha.length, 64);

      final metadata = await storage.commitAsset(
        productId: 'test_product',
        tempFile: tempFile,
        fileExtension: 'tif',
        expectedSize: 512,
        expectedSha256: sha,
      );

      expect(metadata.productId, 'test_product');
      expect(metadata.fileSizeBytes, 512);
      expect(metadata.sha256Digest, sha);
      expect(metadata.isIntegrityVerified, isTrue);

      // Verify temp file no longer exists (renamed)
      expect(await tempFile.exists(), isFalse);

      // Verify asset can be retrieved from storage index
      final verified = await storage.getVerifiedAsset('test_product');
      expect(verified, isNotNull);
      expect(verified!.fileSizeBytes, 512);
    });

    test(
      'Rejects commit and deletes temp file when size does not match expected',
      () async {
        final tempFile = storage.getTempFile('bad_size_product');
        await tempFile.writeAsBytes([1, 2, 3]);

        await expectLater(
          () => storage.commitAsset(
            productId: 'bad_size_product',
            tempFile: tempFile,
            fileExtension: 'tif',
            expectedSize: 100, // Expected 100, actual 3
          ),
          throwsA(isA<IntegrityValidationFailure>()),
        );

        expect(await tempFile.exists(), isFalse);
        expect(await storage.getVerifiedAsset('bad_size_product'), isNull);
      },
    );

    test('Rejects commit and deletes temp file on SHA-256 mismatch', () async {
      final tempFile = storage.getTempFile('bad_sha_product');
      await tempFile.writeAsBytes([1, 2, 3]);

      await expectLater(
        () => storage.commitAsset(
          productId: 'bad_sha_product',
          tempFile: tempFile,
          fileExtension: 'tif',
          expectedSha256: '0000000000000000000000000000000000000000000000000000000000000000',
        ),
        throwsA(isA<IntegrityValidationFailure>()),
      );

      expect(await tempFile.exists(), isFalse);
    });

    test(
      'Detects missing cached file and purges invalid metadata record safely',
      () async {
        final tempFile = storage.getTempFile('missing_file_product');
        await tempFile.writeAsBytes([10, 20, 30]);

        final meta = await storage.commitAsset(
          productId: 'missing_file_product',
          tempFile: tempFile,
          fileExtension: 'tif',
        );

        // Artificially delete the physical completed file
        await File(meta.localFilePath).delete();

        // Next retrieval detects the missing file, cleans up the orphaned meta record, and returns null
        final retrieved = await storage.getVerifiedAsset(
          'missing_file_product',
        );
        expect(retrieved, isNull);
      },
    );

    test(
      'deleteAsset removes file, metadata, and temporary files cleanly',
      () async {
        final tempFile = storage.getTempFile('deleted_product');
        await tempFile.writeAsBytes([1, 2, 3]);

        await storage.commitAsset(
          productId: 'deleted_product',
          tempFile: tempFile,
          fileExtension: 'tif',
        );

        expect(await storage.getVerifiedAsset('deleted_product'), isNotNull);

        await storage.deleteAsset('deleted_product');
        expect(await storage.getVerifiedAsset('deleted_product'), isNull);
      },
    );
  });
}

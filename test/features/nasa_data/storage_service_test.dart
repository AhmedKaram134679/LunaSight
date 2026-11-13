import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/nasa_data/data/models/local_asset_record.dart';
import 'package:luna_sight/features/nasa_data/data/storage/local_data_storage_service.dart';
import 'package:luna_sight/features/nasa_data/domain/entities/acquisition_status.dart';
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

  group('LocalDataStorageService Path Traversal & Atomicity Tests', () {
    test('Rejects path traversal in product ID and relative paths', () {
      expect(
        () => storage.getTempFile('../escape'),
        throwsA(isA<NasaStorageFailure>()),
      );
      expect(
        () => storage.getCompletedFile('..\\escape', 'tif'),
        throwsA(isA<NasaStorageFailure>()),
      );
      expect(
        () => storage.deleteAsset('sub/product'),
        throwsA(isA<NasaStorageFailure>()),
      );
    });

    test('Rejects cross-product file access or corrupted record with mismatched product ID', () async {
      final metaDir = Directory('${testDir.path}/meta');
      final corruptedMetaFile = File('${metaDir.path}/product_a.json');

      // Record claims to belong to product_b
      final record = LocalAssetRecord(
        productId: 'product_b',
        relativeFilePath: 'product_a.tif',
        fileSizeBytes: 100,
        acquiredAt: DateTime.now().toUtc(),
      );
      await corruptedMetaFile.writeAsString(record.serialize());

      // Attempting to retrieve product_a should detect mismatch and purge metadata
      final verified = await storage.getVerifiedAsset('product_a');
      expect(verified, isNull);
      expect(await corruptedMetaFile.exists(), isFalse);
    });

    test('Rejects malformed cache metadata with negative file size or invalid json', () async {
      final metaDir = Directory('${testDir.path}/meta');
      final corruptedFile = File('${metaDir.path}/corrupt_product.json');
      await corruptedFile.writeAsString(
        '{ "productId": "corrupt_product", "fileSizeBytes": -5 }',
      );

      final result = await storage.getVerifiedAsset('corrupt_product');
      expect(result, isNull);
      expect(await corruptedFile.exists(), isFalse);
    });

    test(
      'Atomic commit stages files and updates verificationLevel accurately',
      () async {
        final tempFile = storage.getTempFile('test_product');
        final payload = List.generate(512, (i) => i % 256);
        await tempFile.writeAsBytes(payload);

        final sha = await storage.computeSha256(tempFile);

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
        expect(
          metadata.verificationLevel,
          IntegrityVerificationLevel.sha256Verified,
        );
        expect(metadata.isIntegrityVerified, isTrue);

        final retrieved = await storage.getVerifiedAsset('test_product');
        expect(retrieved, isNotNull);
        expect(
          retrieved!.verificationLevel,
          IntegrityVerificationLevel.sha256Verified,
        );
      },
    );

    test(
      'Commit preserves existing valid asset if replacement fails validation',
      () async {
        // 1. Commit initial valid asset
        final initialTemp = storage.getTempFile('safe_product');
        await initialTemp.writeAsBytes([1, 2, 3, 4]);
        await storage.commitAsset(
          productId: 'safe_product',
          tempFile: initialTemp,
          fileExtension: 'tif',
          expectedSize: 4,
        );

        final existingAsset = await storage.getVerifiedAsset('safe_product');
        expect(existingAsset, isNotNull);
        expect(existingAsset!.fileSizeBytes, 4);

        // 2. Try committing replacement with bad size
        final badTemp = storage.getTempFile('safe_product');
        await badTemp.writeAsBytes([1, 2]); // 2 bytes instead of expected 10

        await expectLater(
          () => storage.commitAsset(
            productId: 'safe_product',
            tempFile: badTemp,
            fileExtension: 'tif',
            expectedSize: 10,
          ),
          throwsA(isA<IntegrityValidationFailure>()),
        );

        // Verify original asset was preserved and not destroyed
        final preservedAsset = await storage.getVerifiedAsset('safe_product');
        expect(preservedAsset, isNotNull);
        expect(preservedAsset!.fileSizeBytes, 4);
      },
    );

    test('Orphaned staged files are recovered on initialize', () async {
      final completedDir = Directory('${testDir.path}/completed');
      final orphanedStagedFile = File('${completedDir.path}/orphan.staged.tif');
      await orphanedStagedFile.writeAsString('orphaned');
      expect(await orphanedStagedFile.exists(), isTrue);

      // Calling initialize cleans up orphaned files
      await storage.initialize();
      expect(await orphanedStagedFile.exists(), isFalse);
    });
  });
}

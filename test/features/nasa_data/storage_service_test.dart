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

  group('LocalDataStorageService Path Traversal & Crash Recovery Tests', () {
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

      final record = LocalAssetRecord(
        productId: 'product_b',
        relativeFilePath: 'product_a.tif',
        fileSizeBytes: 100,
        acquiredAt: DateTime.now().toUtc(),
      );
      await corruptedMetaFile.writeAsString(record.serialize());

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

    // Crash Recovery Tests simulating interruption at transaction boundaries

    test('Interruption simulation: First installation interrupted before metadata commit', () async {
      final completedDir = Directory('${testDir.path}/completed');
      final uncommittedAsset = File(
        '${completedDir.path}/first_install_gen123.tif',
      );
      await uncommittedAsset.writeAsBytes([1, 2, 3, 4]);

      // No metadata committed yet
      await storage.recoverStorageState();

      // Asset was unreferenced by any metadata record, so it must be cleaned up
      expect(await uncommittedAsset.exists(), isFalse);
      expect(await storage.getVerifiedAsset('first_install'), isNull);
    });

    test('Interruption simulation: Staged metadata written but interrupted before rename', () async {
      final completedDir = Directory('${testDir.path}/completed');
      final metaDir = Directory('${testDir.path}/meta');

      final asset = File('${completedDir.path}/interrupted_gen100.tif');
      await asset.writeAsBytes([10, 20, 30]);

      final stagedMeta = File('${metaDir.path}/interrupted.staged.json');
      final record = LocalAssetRecord(
        productId: 'interrupted',
        relativeFilePath: 'interrupted_gen100.tif',
        fileSizeBytes: 3,
        acquiredAt: DateTime.now().toUtc(),
      );
      await stagedMeta.writeAsString(record.serialize());

      // Recovery detects complete staged metadata and valid matching asset, completing the commit
      await storage.recoverStorageState();

      final verified = await storage.getVerifiedAsset('interrupted');
      expect(verified, isNotNull);
      expect(verified!.fileSizeBytes, 3);
      expect(await File(verified.localFilePath).readAsBytes(), [10, 20, 30]);
    });

    test('Interruption simulation: Replacement interrupted before new metadata committed preserves old generation', () async {
      final completedDir = Directory('${testDir.path}/completed');
      final metaDir = Directory('${testDir.path}/meta');

      // Generation 1 (fully committed)
      final oldAsset = File('${completedDir.path}/prod_gen1.tif');
      await oldAsset.writeAsBytes([1, 1, 1]);
      final activeMeta = File('${metaDir.path}/prod.json');
      final oldRecord = LocalAssetRecord(
        productId: 'prod',
        relativeFilePath: 'prod_gen1.tif',
        fileSizeBytes: 3,
        acquiredAt: DateTime.now().toUtc(),
      );
      await activeMeta.writeAsString(oldRecord.serialize());

      // Generation 2 staged but interrupted
      final newAsset = File('${completedDir.path}/prod_gen2.tif');
      await newAsset.writeAsBytes([2, 2, 2, 2, 2]);

      await storage.recoverStorageState();

      // Old generation must be intact and verified
      final verified = await storage.getVerifiedAsset('prod');
      expect(verified, isNotNull);
      expect(verified!.fileSizeBytes, 3);
      expect(await File(verified.localFilePath).readAsBytes(), [1, 1, 1]);

      // Unreferenced generation 2 cleaned up
      expect(await newAsset.exists(), isFalse);
    });

    test('Interruption simulation: Legacy backup recovery when backup is the only valid asset', () async {
      final completedDir = Directory('${testDir.path}/completed');
      final metaDir = Directory('${testDir.path}/meta');

      // Metadata expects prod_legacy.tif of size 4
      final activeMeta = File('${metaDir.path}/prod_legacy.json');
      final record = LocalAssetRecord(
        productId: 'prod_legacy',
        relativeFilePath: 'prod_legacy.tif',
        fileSizeBytes: 4,
        acquiredAt: DateTime.now().toUtc(),
      );
      await activeMeta.writeAsString(record.serialize());

      // Only prod_legacy.bak exists of size 4
      final bakFile = File('${completedDir.path}/prod_legacy.bak');
      await bakFile.writeAsBytes([9, 9, 9, 9]);

      await storage.recoverStorageState();

      // Asset was restored from backup and is now verified
      final verified = await storage.getVerifiedAsset('prod_legacy');
      expect(verified, isNotNull);
      expect(verified!.fileSizeBytes, 4);
      expect(await File(verified.localFilePath).readAsBytes(), [9, 9, 9, 9]);
    });

    test(
      'Recovery protocol is idempotent across repeated invocations',
      () async {
        final tempFile = storage.getTempFile('idempotent_test');
        await tempFile.writeAsBytes([5, 6, 7]);
        await storage.commitAsset(
          productId: 'idempotent_test',
          tempFile: tempFile,
          fileExtension: 'tif',
          expectedSize: 3,
        );

        // Run recovery multiple times
        await storage.recoverStorageState();
        await storage.recoverStorageState();
        await storage.recoverStorageState();

        final verified = await storage.getVerifiedAsset('idempotent_test');
        expect(verified, isNotNull);
        expect(verified!.fileSizeBytes, 3);
        expect(await File(verified.localFilePath).readAsBytes(), [5, 6, 7]);
      },
    );
  });
}

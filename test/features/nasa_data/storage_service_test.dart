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

    // Security & Path Traversal Regression Tests in Recovery

    test('Security: Recovery rejects path traversal in authoritative metadata and preserves external sentinel', () async {
      final sentinel = File('${testDir.parent.path}/sentinel_auth.txt');
      await sentinel.writeAsString('CRITICAL_SENTINEL_DATA');

      final metaDir = Directory('${testDir.path}/meta');
      final maliciousMeta = File('${metaDir.path}/malicious_auth.json');
      final record = LocalAssetRecord(
        productId: 'malicious_auth',
        relativeFilePath: '../../sentinel_auth.txt',
        fileSizeBytes: 22,
        acquiredAt: DateTime.now().toUtc(),
      );
      await maliciousMeta.writeAsString(record.serialize());

      // Valid product in same directory
      final validTemp = storage.getTempFile('valid_prod');
      await validTemp.writeAsBytes([42, 43]);
      await storage.commitAsset(
        productId: 'valid_prod',
        tempFile: validTemp,
        fileExtension: 'tif',
        expectedSize: 2,
      );

      await storage.recoverStorageState();

      // Sentinel must remain untouched
      expect(await sentinel.exists(), isTrue);
      expect(await sentinel.readAsString(), 'CRITICAL_SENTINEL_DATA');

      // Malicious metadata must be rejected / purged and not verified
      expect(await storage.getVerifiedAsset('malicious_auth'), isNull);

      // Unrelated valid product remains completely intact
      final validVerified = await storage.getVerifiedAsset('valid_prod');
      expect(validVerified, isNotNull);
      expect(validVerified!.fileSizeBytes, 2);

      await sentinel.delete();
    });

    test(
      'Security: Recovery rejects Windows-style and absolute paths in metadata',
      () async {
        final metaDir = Directory('${testDir.path}/meta');

        // Windows traversal
        final winMeta = File('${metaDir.path}/win_meta.json');
        final winRecord = LocalAssetRecord(
          productId: 'win_meta',
          relativeFilePath: '..\\..\\win_escape.tif',
          fileSizeBytes: 10,
          acquiredAt: DateTime.now().toUtc(),
        );
        await winMeta.writeAsString(winRecord.serialize());

        // Absolute path
        final absMeta = File('${metaDir.path}/abs_meta.json');
        final absRecord = LocalAssetRecord(
          productId: 'abs_meta',
          relativeFilePath: Platform.isWindows
              ? r'C:\Windows\System32\calc.exe'
              : '/bin/sh',
          fileSizeBytes: 100,
          acquiredAt: DateTime.now().toUtc(),
        );
        await absMeta.writeAsString(absRecord.serialize());

        await storage.recoverStorageState();

        expect(await storage.getVerifiedAsset('win_meta'), isNull);
        expect(await storage.getVerifiedAsset('abs_meta'), isNull);
      },
    );

    test('Security: Recovery rejects malicious staged metadata attempting traversal', () async {
      final sentinel = File('${testDir.parent.path}/sentinel_staged.txt');
      await sentinel.writeAsString('SENTINEL_STAGED_PAYLOAD');

      final metaDir = Directory('${testDir.path}/meta');
      final maliciousStaged = File(
        '${metaDir.path}/traversal_staged.staged.json',
      );
      final record = LocalAssetRecord(
        productId: 'traversal_staged',
        relativeFilePath: '../../sentinel_staged.txt',
        fileSizeBytes: 23,
        acquiredAt: DateTime.now().toUtc(),
      );
      await maliciousStaged.writeAsString(record.serialize());

      await storage.recoverStorageState();

      // Sentinel intact
      expect(await sentinel.exists(), isTrue);
      expect(await sentinel.readAsString(), 'SENTINEL_STAGED_PAYLOAD');

      // Malicious staged file cleaned
      expect(await maliciousStaged.exists(), isFalse);
      expect(await storage.getVerifiedAsset('traversal_staged'), isNull);

      await sentinel.delete();
    });

    test('Security: Malicious record attempting to redirect legacy .bak restoration is rejected', () async {
      final completedDir = Directory('${testDir.path}/completed');
      final metaDir = Directory('${testDir.path}/meta');

      // Attacker creates a legacy bak file
      final legacyBak = File('${completedDir.path}/redirect_attack.bak');
      await legacyBak.writeAsBytes([1, 2, 3]);

      // Metadata attempts to redirect restore destination outside completed dir
      final maliciousMeta = File('${metaDir.path}/redirect_attack.json');
      final maliciousRecord = LocalAssetRecord(
        productId: 'redirect_attack',
        relativeFilePath: '../redirected_target.tif',
        fileSizeBytes: 3,
        acquiredAt: DateTime.now().toUtc(),
      );
      await maliciousMeta.writeAsString(maliciousRecord.serialize());

      final externalTarget = File('${testDir.path}/redirected_target.tif');

      await storage.recoverStorageState();

      // Target must not have been created or overwritten outside completed dir
      expect(await externalTarget.exists(), isFalse);
      expect(await storage.getVerifiedAsset('redirect_attack'), isNull);
    });

    test('Cleanup hardening: Non-application files in completed directory are never deleted', () async {
      final completedDir = Directory('${testDir.path}/completed');
      final unrelatedUserFile = File('${completedDir.path}/user_notes.txt');
      final customScript = File('${completedDir.path}/custom_tool.py');
      await unrelatedUserFile.writeAsString('IMPORTANT_NOTES');
      await customScript.writeAsString('print("hello")');

      await storage.recoverStorageState();

      // Unrelated non-application files must remain untouched
      expect(await unrelatedUserFile.exists(), isTrue);
      expect(await unrelatedUserFile.readAsString(), 'IMPORTANT_NOTES');
      expect(await customScript.exists(), isTrue);
    });

    // Mandatory Transaction Boundary Recovery Tests

    test('Case A: Replacement interrupted before metadata commit retains Gen 1 unchanged', () async {
      // 1. Commit Generation 1
      final temp1 = storage.getTempFile('case_a');
      final gen1Bytes = [10, 20, 30, 40];
      await temp1.writeAsBytes(gen1Bytes);
      final meta1 = await storage.commitAsset(
        productId: 'case_a',
        tempFile: temp1,
        fileExtension: 'tif',
        expectedSize: 4,
      );

      expect(meta1.productId, 'case_a');
      final gen1FilePath = meta1.localFilePath;
      final gen1Relative = meta1.localFilePath
          .split(Platform.pathSeparator)
          .last;

      // 2. Stage Generation 2 and write its staged metadata (simulate crash before final commit)
      final completedDir = Directory('${testDir.path}/completed');
      final metaDir = Directory('${testDir.path}/meta');
      final gen2Timestamp =
          DateTime.now().toUtc().microsecondsSinceEpoch + 1000;
      final gen2FileName = 'case_a_gen$gen2Timestamp.tif';
      final gen2File = File('${completedDir.path}/$gen2FileName');
      final gen2Bytes = [50, 60, 70, 80, 90];
      await gen2File.writeAsBytes(gen2Bytes);

      final stagedMeta = File('${metaDir.path}/case_a.staged.json');
      final stagedRecord = LocalAssetRecord(
        productId: 'case_a',
        relativeFilePath: gen2FileName,
        fileSizeBytes: 5,
        acquiredAt: DateTime.now().toUtc(),
      );
      await stagedMeta.writeAsString(stagedRecord.serialize());

      // 3. Run recovery
      await storage.recoverStorageState();

      // 4. Verify Generation 1 is active, byte-for-byte unchanged
      final activeAsset = await storage.getVerifiedAsset('case_a');
      expect(activeAsset, isNotNull);
      expect(activeAsset!.productId, 'case_a');
      expect(
        activeAsset.localFilePath.split(Platform.pathSeparator).last,
        gen1Relative,
      );
      expect(activeAsset.localFilePath, gen1FilePath);
      expect(activeAsset.fileSizeBytes, 4);
      expect(await File(activeAsset.localFilePath).readAsBytes(), gen1Bytes);

      // Staged gen2 metadata and uncommitted gen2 file must be cleaned up
      expect(await stagedMeta.exists(), isFalse);
      expect(await gen2File.exists(), isFalse);
    });

    test('Case B: Replacement interrupted immediately after metadata commit promotes Gen 2 and cleans Gen 1', () async {
      final completedDir = Directory('${testDir.path}/completed');
      final metaDir = Directory('${testDir.path}/meta');

      // Gen 1 asset
      final gen1FileName = 'case_b_gen100.tif';
      final gen1File = File('${completedDir.path}/$gen1FileName');
      await gen1File.writeAsBytes([1, 2, 3]);

      // Gen 2 asset
      final gen2FileName = 'case_b_gen200.tif';
      final gen2File = File('${completedDir.path}/$gen2FileName');
      final gen2Bytes = [7, 8, 9, 10, 11];
      await gen2File.writeAsBytes(gen2Bytes);

      // Metadata pointer was committed to Gen 2, but process crashed before cleaning Gen 1
      final activeMeta = File('${metaDir.path}/case_b.json');
      final gen2Record = LocalAssetRecord(
        productId: 'case_b',
        relativeFilePath: gen2FileName,
        fileSizeBytes: 5,
        acquiredAt: DateTime.now().toUtc(),
      );
      await activeMeta.writeAsString(gen2Record.serialize());

      // Run recovery
      await storage.recoverStorageState();

      // Gen 2 is active and exact bytes match
      final activeAsset = await storage.getVerifiedAsset('case_b');
      expect(activeAsset, isNotNull);
      expect(activeAsset!.productId, 'case_b');
      expect(
        activeAsset.localFilePath.split(Platform.pathSeparator).last,
        gen2FileName,
      );
      expect(activeAsset.fileSizeBytes, 5);
      expect(await File(activeAsset.localFilePath).readAsBytes(), gen2Bytes);

      // Gen 1 cleaned up because active committed pointer is Gen 2
      expect(await gen1File.exists(), isFalse);
    });

    test('Case C: Metadata staging write failure preserves old authoritative metadata and asset', () async {
      // Initial committed state
      final temp = storage.getTempFile('case_c');
      final originalBytes = [100, 101, 102];
      await temp.writeAsBytes(originalBytes);
      final initialMeta = await storage.commitAsset(
        productId: 'case_c',
        tempFile: temp,
        fileExtension: 'tif',
        expectedSize: 3,
      );

      // Interruption: Staged metadata failed during write (partially written or invalid)
      final metaDir = Directory('${testDir.path}/meta');
      final brokenStagedMeta = File('${metaDir.path}/case_c.staged.json');
      await brokenStagedMeta.writeAsString(
        '{ "productId": "case_c", "fileSize',
      );

      // Run recovery
      await storage.recoverStorageState();

      // Old authoritative metadata and asset remain intact
      final verified = await storage.getVerifiedAsset('case_c');
      expect(verified, isNotNull);
      expect(verified!.productId, 'case_c');
      expect(verified.localFilePath, initialMeta.localFilePath);
      expect(verified.fileSizeBytes, 3);
      expect(await File(verified.localFilePath).readAsBytes(), originalBytes);
      expect(await brokenStagedMeta.exists(), isFalse);
    });

    test('Case D: Metadata rename failure during commit preserves previous committed asset', () async {
      final completedDir = Directory('${testDir.path}/completed');
      final metaDir = Directory('${testDir.path}/meta');

      // Gen 1 committed
      final gen1File = File('${completedDir.path}/case_d_gen1.tif');
      final gen1Bytes = [40, 50, 60];
      await gen1File.writeAsBytes(gen1Bytes);
      final finalMeta = File('${metaDir.path}/case_d.json');
      final record1 = LocalAssetRecord(
        productId: 'case_d',
        relativeFilePath: 'case_d_gen1.tif',
        fileSizeBytes: 3,
        acquiredAt: DateTime.now().toUtc(),
      );
      await finalMeta.writeAsString(record1.serialize());

      // Gen 2 staged metadata exists (rename failed/interrupted)
      final gen2File = File('${completedDir.path}/case_d_gen2.tif');
      await gen2File.writeAsBytes([70, 80, 90, 100]);
      final stagedMeta = File('${metaDir.path}/case_d.staged.json');
      final record2 = LocalAssetRecord(
        productId: 'case_d',
        relativeFilePath: 'case_d_gen2.tif',
        fileSizeBytes: 4,
        acquiredAt: DateTime.now().toUtc(),
      );
      await stagedMeta.writeAsString(record2.serialize());

      // Recovery detects authoritative case_d.json already exists -> discards redundant staged meta
      await storage.recoverStorageState();

      final verified = await storage.getVerifiedAsset('case_d');
      expect(verified, isNotNull);
      expect(verified!.productId, 'case_d');
      expect(
        verified.localFilePath.split(Platform.pathSeparator).last,
        'case_d_gen1.tif',
      );
      expect(verified.fileSizeBytes, 3);
      expect(await File(verified.localFilePath).readAsBytes(), gen1Bytes);
      expect(await stagedMeta.exists(), isFalse);
      expect(await gen2File.exists(), isFalse);
    });

    test('Case E: First installation interruption before authoritative commit leaves no asset exposed', () async {
      final completedDir = Directory('${testDir.path}/completed');
      final metaDir = Directory('${testDir.path}/meta');

      // Boundary 1: Temp file downloaded, but commit not initiated
      final tempFile = storage.getTempFile('case_e1');
      await tempFile.writeAsBytes([1, 2, 3]);

      // Boundary 2: Moved to completed generation file, but no metadata written
      final orphanedGen = File('${completedDir.path}/case_e2_gen999.tif');
      await orphanedGen.writeAsBytes([4, 5, 6]);

      // Boundary 3: Corrupt/empty staged metadata file
      final emptyStaged = File('${metaDir.path}/case_e3.staged.json');
      await emptyStaged.writeAsString('');

      await storage.recoverStorageState();

      expect(await storage.getVerifiedAsset('case_e1'), isNull);
      expect(await storage.getVerifiedAsset('case_e2'), isNull);
      expect(await storage.getVerifiedAsset('case_e3'), isNull);

      expect(await orphanedGen.exists(), isFalse);
      expect(await emptyStaged.exists(), isFalse);
    });
  });
}

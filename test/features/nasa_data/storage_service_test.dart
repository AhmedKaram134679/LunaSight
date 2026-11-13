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

    // Canonical Path Boundary & Symlink Tests

    test('Canonical Boundary: Normal in-directory file resolves and validates successfully', () async {
      final completedDir = Directory('${testDir.path}/completed');
      final normalFile = File('${completedDir.path}/normal_asset.tif');
      await normalFile.writeAsBytes([1, 2, 3]);

      final metaDir = Directory('${testDir.path}/meta');
      final meta = File('${metaDir.path}/normal_asset.json');
      final record = LocalAssetRecord(
        productId: 'normal_asset',
        relativeFilePath: 'normal_asset.tif',
        fileSizeBytes: 3,
        acquiredAt: DateTime.now().toUtc(),
      );
      await meta.writeAsString(record.serialize());

      final verified = await storage.getVerifiedAsset('normal_asset');
      expect(verified, isNotNull);
      expect(verified!.fileSizeBytes, 3);
    });

    test('Canonical Boundary: Non-existent in-directory target is accepted during safe restoration', () async {
      final completedDir = Directory('${testDir.path}/completed');
      final metaDir = Directory('${testDir.path}/meta');

      // Target asset does not exist yet, but legacy backup exists
      final legacyBak = File('${completedDir.path}/restore_test.bak');
      await legacyBak.writeAsBytes([4, 5, 6, 7]);

      final meta = File('${metaDir.path}/restore_test.json');
      final record = LocalAssetRecord(
        productId: 'restore_test',
        relativeFilePath: 'restore_test.tif',
        fileSizeBytes: 4,
        acquiredAt: DateTime.now().toUtc(),
      );
      await meta.writeAsString(record.serialize());

      await storage.recoverStorageState();

      final verified = await storage.getVerifiedAsset('restore_test');
      expect(verified, isNotNull);
      expect(verified!.fileSizeBytes, 4);
      expect(await File(verified.localFilePath).readAsBytes(), [4, 5, 6, 7]);
    });

    test(
      'Canonical Boundary: Sibling-directory prefix collision is rejected',
      () async {
        // completed_evil shares the textual prefix of completed
        final evilDir = Directory('${testDir.path}/completed_evil');
        await evilDir.create(recursive: true);
        final evilFile = File('${evilDir.path}/evil.tif');
        await evilFile.writeAsBytes([6, 6, 6]);

        final metaDir = Directory('${testDir.path}/meta');
        final evilMeta = File('${metaDir.path}/evil_prod.json');
        // relativeFilePath with directory traversal into sibling directory
        final record = LocalAssetRecord(
          productId: 'evil_prod',
          relativeFilePath: '../completed_evil/evil.tif',
          fileSizeBytes: 3,
          acquiredAt: DateTime.now().toUtc(),
        );
        await evilMeta.writeAsString(record.serialize());

        await storage.recoverStorageState();

        expect(await storage.getVerifiedAsset('evil_prod'), isNull);
        expect(await evilFile.exists(), isTrue);
        expect(await evilFile.readAsBytes(), [6, 6, 6]);
      },
    );

    test('Canonical Boundary: Symlink escapes, external targets, and dangling symlinks are rejected', () async {
      final completedDir = Directory('${testDir.path}/completed');
      final metaDir = Directory('${testDir.path}/meta');
      final externalDir = Directory('${testDir.path}/external_dir');
      await externalDir.create(recursive: true);

      // External sentinel file
      final sentinel = File('${testDir.path}/sentinel_sym.txt');
      await sentinel.writeAsString('CRITICAL_SENTINEL_SYM');

      // Check if symlinks can be created in this environment
      bool symlinksSupported = true;
      try {
        final probeLink = Link('${completedDir.path}/probe_link.tmp');
        await probeLink.create(sentinel.path);
        await probeLink.delete();
      } catch (e) {
        symlinksSupported = false;
        // ignore: avoid_print
        print(
          'Symlink tests skipped: Environment does not permit symlink creation ($e)',
        );
      }

      if (!symlinksSupported) {
        // Report explicitly as required by prompt
        return;
      }

      // 1. Symlink inside completed pointing to external file
      final linkToFile = Link('${completedDir.path}/sym_file.tif');
      await linkToFile.create(sentinel.path);

      final meta1 = File('${metaDir.path}/sym_file.json');
      final record1 = LocalAssetRecord(
        productId: 'sym_file',
        relativeFilePath: 'sym_file.tif',
        fileSizeBytes: 21,
        acquiredAt: DateTime.now().toUtc(),
      );
      await meta1.writeAsString(record1.serialize());

      // 2. Symlink inside completed pointing to sibling directory completed_evil
      final evilDir = Directory('${testDir.path}/completed_evil');
      await evilDir.create(recursive: true);
      final evilTarget = File('${evilDir.path}/evil_target.tif');
      await evilTarget.writeAsBytes([9, 9, 9]);

      final linkToSiblingDir = Link('${completedDir.path}/sym_evil.tif');
      await linkToSiblingDir.create(evilTarget.path);

      final meta2 = File('${metaDir.path}/sym_evil.json');
      final record2 = LocalAssetRecord(
        productId: 'sym_evil',
        relativeFilePath: 'sym_evil.tif',
        fileSizeBytes: 3,
        acquiredAt: DateTime.now().toUtc(),
      );
      await meta2.writeAsString(record2.serialize());

      // 3. Symlink pointing to external directory with existing target file
      final extFile = File('${externalDir.path}/ext.tif');
      await extFile.writeAsBytes([1, 1]);
      final linkToExt = Link('${completedDir.path}/sym_ext.tif');
      await linkToExt.create(extFile.path);

      final meta3 = File('${metaDir.path}/sym_ext.json');
      final record3 = LocalAssetRecord(
        productId: 'sym_ext',
        relativeFilePath: 'sym_ext.tif',
        fileSizeBytes: 2,
        acquiredAt: DateTime.now().toUtc(),
      );
      await meta3.writeAsString(record3.serialize());

      // 4. Dangling symlink
      final linkDangling = Link('${completedDir.path}/sym_dangling.tif');
      await linkDangling.create('${externalDir.path}/does_not_exist.tif');

      final meta4 = File('${metaDir.path}/sym_dangling.json');
      final record4 = LocalAssetRecord(
        productId: 'sym_dangling',
        relativeFilePath: 'sym_dangling.tif',
        fileSizeBytes: 10,
        acquiredAt: DateTime.now().toUtc(),
      );
      await meta4.writeAsString(record4.serialize());

      await storage.recoverStorageState();

      // All malicious/unsafe symlinks must be rejected
      expect(await storage.getVerifiedAsset('sym_file'), isNull);
      expect(await storage.getVerifiedAsset('sym_evil'), isNull);
      expect(await storage.getVerifiedAsset('sym_ext'), isNull);
      expect(await storage.getVerifiedAsset('sym_dangling'), isNull);

      // Verify external sentinel file and external evil file remain byte-for-byte unchanged
      expect(await sentinel.exists(), isTrue);
      expect(await sentinel.readAsString(), 'CRITICAL_SENTINEL_SYM');
      expect(await evilTarget.exists(), isTrue);
      expect(await evilTarget.readAsBytes(), [9, 9, 9]);
      expect(await extFile.exists(), isTrue);
      expect(await extFile.readAsBytes(), [1, 1]);
    });

    // Actual commitAsset() Failure-Injection Tests

    test('Failure Injection Point A: generationAssetRename failure preserves temp and state', () async {
      storage.testFailureInjectionPoint =
          StorageCommitFailurePoint.generationAssetRename;

      final temp = storage.getTempFile('fail_a');
      final tempPayload = [1, 2, 3];
      await temp.writeAsBytes(tempPayload);

      await expectLater(
        () => storage.commitAsset(
          productId: 'fail_a',
          tempFile: temp,
          fileExtension: 'tif',
          expectedSize: 3,
        ),
        throwsA(isA<NasaStorageFailure>()),
      );

      // Reset failure point
      storage.testFailureInjectionPoint = StorageCommitFailurePoint.none;

      // 1. Verify original temporary file still exists and exact bytes remain unchanged
      expect(await temp.exists(), isTrue);
      expect(await temp.readAsBytes(), tempPayload);

      // 2. Verify no uncommitted generation asset was created in completed directory
      final completedDir = Directory('${testDir.path}/completed');
      final completedFiles = completedDir
          .listSync()
          .whereType<File>()
          .where((f) => f.uri.pathSegments.last.startsWith('fail_a_gen'))
          .toList();
      expect(completedFiles, isEmpty);

      // 3. Verify no authoritative metadata points to failed generation
      final metaFile = File('${testDir.path}/meta/fail_a.json');
      expect(await metaFile.exists(), isFalse);

      // 4. Uncommitted product returns null
      expect(await storage.getVerifiedAsset('fail_a'), isNull);

      // 5. Recovery remains safe and idempotent
      await storage.recoverStorageState();
      expect(await storage.getVerifiedAsset('fail_a'), isNull);
      expect(await temp.exists(), isTrue);
    });

    test('Failure Injection Point B: stagedMetadataWrite failure preserves old generation and cleans staged', () async {
      // 1. Establish initial committed Gen 1
      final temp1 = storage.getTempFile('fail_b');
      final gen1Bytes = [10, 20];
      await temp1.writeAsBytes(gen1Bytes);
      final meta1 = await storage.commitAsset(
        productId: 'fail_b',
        tempFile: temp1,
        fileExtension: 'tif',
        expectedSize: 2,
      );

      // 2. Inject failure at stagedMetadataWrite
      storage.testFailureInjectionPoint =
          StorageCommitFailurePoint.stagedMetadataWrite;

      final temp2 = storage.getTempFile('fail_b');
      await temp2.writeAsBytes([30, 40, 50]);

      await expectLater(
        () => storage.commitAsset(
          productId: 'fail_b',
          tempFile: temp2,
          fileExtension: 'tif',
          expectedSize: 3,
        ),
        throwsA(isA<NasaStorageFailure>()),
      );

      storage.testFailureInjectionPoint = StorageCommitFailurePoint.none;

      // Old generation remains active, verified, and byte-for-byte unchanged
      final verified = await storage.getVerifiedAsset('fail_b');
      expect(verified, isNotNull);
      expect(verified!.localFilePath, meta1.localFilePath);
      expect(verified.fileSizeBytes, 2);
      expect(await File(verified.localFilePath).readAsBytes(), gen1Bytes);

      // Staged metadata was cleaned up
      final stagedMeta = File('${testDir.path}/meta/fail_b.staged.json');
      expect(await stagedMeta.exists(), isFalse);
    });

    test('Failure Injection Point C: stagedMetadataFlush failure preserves old generation and cleans partial metadata', () async {
      final temp1 = storage.getTempFile('fail_c');
      final gen1Bytes = [11, 22];
      await temp1.writeAsBytes(gen1Bytes);
      final meta1 = await storage.commitAsset(
        productId: 'fail_c',
        tempFile: temp1,
        fileExtension: 'tif',
        expectedSize: 2,
      );

      storage.testFailureInjectionPoint =
          StorageCommitFailurePoint.stagedMetadataFlush;

      final temp2 = storage.getTempFile('fail_c');
      final gen2Bytes = [33, 44, 55];
      await temp2.writeAsBytes(gen2Bytes);

      await expectLater(
        () => storage.commitAsset(
          productId: 'fail_c',
          tempFile: temp2,
          fileExtension: 'tif',
          expectedSize: 3,
        ),
        throwsA(isA<NasaStorageFailure>()),
      );

      storage.testFailureInjectionPoint = StorageCommitFailurePoint.none;

      // 1. Partial/staged metadata was cleaned up
      final stagedMeta = File('${testDir.path}/meta/fail_c.staged.json');
      expect(await stagedMeta.exists(), isFalse);

      // 2. Previously committed Generation 1 remains active and byte-for-byte unchanged
      final verified = await storage.getVerifiedAsset('fail_c');
      expect(verified, isNotNull);
      expect(verified!.localFilePath, meta1.localFilePath);
      expect(verified.fileSizeBytes, 2);
      expect(await File(verified.localFilePath).readAsBytes(), gen1Bytes);

      // 3. Generation 2 is not exposed as committed
      expect(verified.fileSizeBytes, isNot(equals(3)));

      // 4. Uncommitted Gen 2 asset file cleaned up
      final completedDir = Directory('${testDir.path}/completed');
      final gen1Canonical = File(meta1.localFilePath)
          .resolveSymbolicLinksSync();
      final completedGen2Files = completedDir
          .listSync()
          .whereType<File>()
          .where(
            (f) =>
                f.resolveSymbolicLinksSync() != gen1Canonical &&
                f.uri.pathSegments.last.startsWith('fail_c_gen'),
          )
          .toList();
      expect(completedGen2Files, isEmpty);

      // 5. Subsequent recoverStorageState() is safe and idempotent
      await storage.recoverStorageState();
      final afterRecovery = await storage.getVerifiedAsset('fail_c');
      expect(afterRecovery, isNotNull);
      expect(afterRecovery!.localFilePath, meta1.localFilePath);
      expect(afterRecovery.fileSizeBytes, 2);
      expect(await File(afterRecovery.localFilePath).readAsBytes(), gen1Bytes);
    });

    test('Failure Injection Point D: authoritativeMetadataRename failure preserves old generation and cleans uncommitted Gen 2', () async {
      final temp1 = storage.getTempFile('fail_d');
      final gen1Bytes = [101, 102];
      await temp1.writeAsBytes(gen1Bytes);
      final meta1 = await storage.commitAsset(
        productId: 'fail_d',
        tempFile: temp1,
        fileExtension: 'tif',
        expectedSize: 2,
      );

      storage.testFailureInjectionPoint =
          StorageCommitFailurePoint.authoritativeMetadataRename;

      final temp2 = storage.getTempFile('fail_d');
      await temp2.writeAsBytes([201, 202, 203]);

      await expectLater(
        () => storage.commitAsset(
          productId: 'fail_d',
          tempFile: temp2,
          fileExtension: 'tif',
          expectedSize: 3,
        ),
        throwsA(isA<NasaStorageFailure>()),
      );

      storage.testFailureInjectionPoint = StorageCommitFailurePoint.none;

      // Old generation 1 remains active
      final verified = await storage.getVerifiedAsset('fail_d');
      expect(verified, isNotNull);
      expect(verified!.localFilePath, meta1.localFilePath);
      expect(verified.fileSizeBytes, 2);
      expect(await File(verified.localFilePath).readAsBytes(), gen1Bytes);

      // Run recovery to ensure complete cleanup idempotency
      await storage.recoverStorageState();
      final afterRecovery = await storage.getVerifiedAsset('fail_d');
      expect(afterRecovery, isNotNull);
      expect(afterRecovery!.fileSizeBytes, 2);
      expect(await File(afterRecovery.localFilePath).readAsBytes(), gen1Bytes);
    });

    test('Failure Injection Point E: postCommitCleanup failure retains new committed Gen 2 and recovery repairs cleanup', () async {
      // 1. Gen 1 committed
      final temp1 = storage.getTempFile('fail_e');
      final gen1Bytes = [7, 8];
      await temp1.writeAsBytes(gen1Bytes);
      final meta1 = await storage.commitAsset(
        productId: 'fail_e',
        tempFile: temp1,
        fileExtension: 'tif',
        expectedSize: 2,
      );

      // 2. Inject failure at postCommitCleanup
      storage.testFailureInjectionPoint =
          StorageCommitFailurePoint.postCommitCleanup;

      final temp2 = storage.getTempFile('fail_e');
      final gen2Bytes = [70, 80, 90];
      await temp2.writeAsBytes(gen2Bytes);

      await expectLater(
        () => storage.commitAsset(
          productId: 'fail_e',
          tempFile: temp2,
          fileExtension: 'tif',
          expectedSize: 3,
        ),
        throwsA(isA<NasaStorageFailure>()),
      );

      storage.testFailureInjectionPoint = StorageCommitFailurePoint.none;

      // Crucial invariant: Authoritative commit was completed BEFORE postCommitCleanup failed!
      // Therefore, Gen 2 is the active, verified generation!
      final verified = await storage.getVerifiedAsset('fail_e');
      expect(verified, isNotNull);
      expect(verified!.productId, 'fail_e');
      expect(verified.fileSizeBytes, 3);
      expect(await File(verified.localFilePath).readAsBytes(), gen2Bytes);

      // Gen 1 asset file still exists because cleanup threw before finishing
      final gen1File = File(meta1.localFilePath);
      expect(await gen1File.exists(), isTrue);

      // Run recovery: recovery validates active Gen 2, cleans up old unreferenced Gen 1
      await storage.recoverStorageState();

      final afterRecovery = await storage.getVerifiedAsset('fail_e');
      expect(afterRecovery, isNotNull);
      expect(afterRecovery!.fileSizeBytes, 3);
      expect(await File(afterRecovery.localFilePath).readAsBytes(), gen2Bytes);

      // Old generation 1 is now cleaned up
      expect(await gen1File.exists(), isFalse);
    });

    // Mandatory Successful Real Replacement Public Operation Test

    test('Mandatory Successful Replacement: Full end-to-end commitAsset() replacement on real filesystem', () async {
      const prodId = 'replace_real_product';

      // 1. Commit Generation 1 through public commitAsset()
      final temp1 = storage.getTempFile(prodId);
      final gen1Payload = [1, 2, 3, 4, 5];
      await temp1.writeAsBytes(gen1Payload);
      final gen1Sha = await storage.computeSha256(temp1);

      final meta1 = await storage.commitAsset(
        productId: prodId,
        tempFile: temp1,
        fileExtension: 'tif',
        expectedSize: 5,
        expectedSha256: gen1Sha,
      );

      expect(meta1.productId, prodId);
      expect(meta1.fileSizeBytes, 5);

      // 2. Verify Generation 1 using getVerifiedAsset()
      final verified1 = await storage.getVerifiedAsset(prodId);
      expect(verified1, isNotNull);
      expect(verified1!.productId, prodId);
      expect(verified1.fileSizeBytes, 5);
      expect(verified1.sha256Digest, gen1Sha);
      expect(await File(verified1.localFilePath).readAsBytes(), gen1Payload);
      final gen1FilePath = verified1.localFilePath;

      // 3. Download/write a different payload to a second temporary file
      final temp2 = storage.getTempFile(prodId);
      final gen2Payload = [10, 20, 30, 40, 50, 60, 70];
      await temp2.writeAsBytes(gen2Payload);
      final gen2Sha = await storage.computeSha256(temp2);

      // 4. Call commitAsset() again using the same product ID
      final meta2 = await storage.commitAsset(
        productId: prodId,
        tempFile: temp2,
        fileExtension: 'tif',
        expectedSize: 7,
        expectedSha256: gen2Sha,
      );

      // 5. Verify the authoritative metadata now references Generation 2
      final verified2 = await storage.getVerifiedAsset(prodId);
      expect(verified2, isNotNull);
      expect(verified2!.productId, prodId);
      expect(verified2.localFilePath, meta2.localFilePath);
      expect(verified2.localFilePath, isNot(equals(gen1FilePath)));

      // 6. Verify Generation 2 exact bytes and size
      expect(verified2.fileSizeBytes, 7);
      expect(verified2.sha256Digest, gen2Sha);
      expect(await File(verified2.localFilePath).readAsBytes(), gen2Payload);

      // 7. Verify Generation 1 cleanup occurred after the new pointer was committed
      final gen1File = File(gen1FilePath);
      expect(await gen1File.exists(), isFalse);

      // 8. Run recoverStorageState() again and verify active generation remains correct
      await storage.recoverStorageState();
      final verifiedAfterRecovery = await storage.getVerifiedAsset(prodId);
      expect(verifiedAfterRecovery, isNotNull);
      expect(verifiedAfterRecovery!.localFilePath, verified2.localFilePath);
      expect(verifiedAfterRecovery.fileSizeBytes, 7);
      expect(
        await File(verifiedAfterRecovery.localFilePath).readAsBytes(),
        gen2Payload,
      );
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android Runtime: File.rename() atomic replacement semantics on app-private storage',
    (tester) async {
      // 1. Establish app-private storage directory
      final appDir = await Directory.systemTemp.createTemp(
        'android_storage_runtime_test_',
      );
      final metaDir = Directory('${appDir.path}/meta');
      await metaDir.create(recursive: true);

      try {
        final finalMetaFile = File('${metaDir.path}/android_test_product.json');
        final stagedMetaFile = File(
          '${metaDir.path}/android_test_product.staged.json',
        );

        const gen1Json =
            '{"productId":"android_test_product","relativeFilePath":"android_test_product_gen1.tif","fileSizeBytes":1024}';
        const gen2Json =
            '{"productId":"android_test_product","relativeFilePath":"android_test_product_gen2.tif","fileSizeBytes":2048}';

        // 2. Create authoritative metadata with Generation 1 contents
        await finalMetaFile.writeAsString(gen1Json, flush: true);
        expect(await finalMetaFile.exists(), isTrue);
        expect(await finalMetaFile.readAsString(), gen1Json);

        // 3. Create staged metadata with Generation 2 contents
        await stagedMetaFile.writeAsString(gen2Json, flush: true);
        expect(await stagedMetaFile.exists(), isTrue);
        expect(await stagedMetaFile.readAsString(), gen2Json);

        // 4. Execute actual Dart File.rename() replacing existing authoritative destination
        final renameResult = await stagedMetaFile.rename(finalMetaFile.path);

        // 5. Verify authoritative destination contains complete Generation 2 metadata
        expect(await finalMetaFile.exists(), isTrue);
        final finalContent = await finalMetaFile.readAsString();
        expect(finalContent, gen2Json);
        expect(renameResult.path, finalMetaFile.path);

        // 6. Verify staged file no longer exists
        expect(await stagedMetaFile.exists(), isFalse);

        // 7. Verify no partial metadata is observable
        expect(finalContent.contains('android_test_product_gen2.tif'), isTrue);
        expect(finalContent.contains('2048'), isTrue);
        expect(finalContent.contains('gen1'), isFalse);

        // 8. Test safely induced replacement failure (e.g. attempting to rename over a non-empty directory)
        final conflictDir = Directory('${metaDir.path}/conflict_dir.json');
        await conflictDir.create(recursive: true);
        final conflictChild = File('${conflictDir.path}/child.txt');
        await conflictChild.writeAsString('cannot overwrite non-empty dir');

        final stagedFailFile = File('${metaDir.path}/fail.staged.json');
        await stagedFailFile.writeAsString(
          '{"productId":"fail","relativeFilePath":"fail_gen3.tif"}',
          flush: true,
        );

        // Attempting to rename file over a directory must fail with FileSystemException on POSIX Android
        Object? capturedError;
        try {
          await stagedFailFile.rename(conflictDir.path);
        } catch (e) {
          capturedError = e;
        }
        expect(capturedError, isNotNull);
        expect(capturedError, isA<FileSystemException>());

        // 9. Verify original authoritative metadata file remains intact after failure
        expect(await finalMetaFile.exists(), isTrue);
        expect(await finalMetaFile.readAsString(), gen2Json);

        // 10. Verify staged file still exists after failed rename
        expect(await stagedFailFile.exists(), isTrue);
      } finally {
        if (await appDir.exists()) {
          await appDir.delete(recursive: true);
        }
      }
    },
  );
}

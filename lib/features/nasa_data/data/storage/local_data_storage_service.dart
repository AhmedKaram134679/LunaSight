import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:luna_sight/core/logging/app_logger.dart';
import 'package:luna_sight/features/nasa_data/data/models/local_asset_record.dart';
import 'package:luna_sight/features/nasa_data/domain/entities/acquisition_status.dart';
import 'package:luna_sight/features/nasa_data/domain/failures/nasa_data_failures.dart';

/// Manages local disk storage, generation-tracked atomic commits, crash recovery, and integrity.
class LocalDataStorageService {
  final Directory baseStorageDirectory;

  LocalDataStorageService({required this.baseStorageDirectory});

  Directory get _completedDir => Directory(
    '${baseStorageDirectory.path}${Platform.pathSeparator}completed',
  );
  Directory get _tempDir =>
      Directory('${baseStorageDirectory.path}${Platform.pathSeparator}temp');
  Directory get _metaDir =>
      Directory('${baseStorageDirectory.path}${Platform.pathSeparator}meta');

  /// Ensures storage directories exist and runs crash-recovery.
  Future<void> initialize() async {
    await _completedDir.create(recursive: true);
    await _tempDir.create(recursive: true);
    await _metaDir.create(recursive: true);
    await recoverStorageState();
  }

  /// Path to a temporary file during transfer.
  File getTempFile(String productId) {
    _validateProductId(productId);
    return File('${_tempDir.path}${Platform.pathSeparator}$productId.part');
  }

  /// Path to a completed asset file.
  File getCompletedFile(String productId, String extension) {
    _validateProductId(productId);
    final ext = extension.startsWith('.') ? extension : '.$extension';
    return File('${_completedDir.path}${Platform.pathSeparator}$productId$ext');
  }

  /// Metadata file for tracking a completed asset.
  File _getMetaFile(String productId) {
    _validateProductId(productId);
    return File('${_metaDir.path}${Platform.pathSeparator}$productId.json');
  }

  /// Prevents path traversal vulnerabilities in product identifiers.
  void _validateProductId(String productId) {
    if (productId.contains('..') ||
        productId.contains('/') ||
        productId.contains('\\') ||
        productId.trim().isEmpty) {
      throw NasaStorageFailure(
        message: 'Invalid product identifier for storage path: "$productId"',
      );
    }
  }

  /// Validates that a filename/relative path is strictly a single filename
  /// within the completed directory and does not traverse outward.
  File _resolveAndValidateCompletedFile(String relativeFilePath) {
    if (relativeFilePath.contains('..') ||
        relativeFilePath.contains('/') ||
        relativeFilePath.contains('\\') ||
        relativeFilePath.trim().isEmpty) {
      throw NasaStorageFailure(
        message:
            'Path traversal detected in relativeFilePath: "$relativeFilePath"',
      );
    }

    final file = File(
      '${_completedDir.path}${Platform.pathSeparator}$relativeFilePath',
    );

    final completedCanonical = _completedDir.resolveSymbolicLinksSync();
    String fileCanonical;
    try {
      fileCanonical = file.resolveSymbolicLinksSync();
    } catch (_) {
      fileCanonical = file.absolute.path;
    }

    if (!fileCanonical.startsWith(completedCanonical)) {
      throw NasaStorageFailure(
        message:
            'Target file outside completed storage directory: "$relativeFilePath"',
      );
    }

    return file;
  }

  /// Checks if an asset is present, intact, and matches its metadata record.
  Future<LocalAssetMetadata?> getVerifiedAsset(String productId) async {
    _validateProductId(productId);
    final metaFile = _getMetaFile(productId);
    if (!await metaFile.exists()) {
      return null;
    }

    try {
      final jsonStr = await metaFile.readAsString();
      final record = LocalAssetRecord.tryDeserialize(jsonStr);
      if (record == null) {
        AppLogger.warning('Corrupted cache record for $productId. Purging.');
        await metaFile.delete();
        return null;
      }

      // Security check: product ID in record must match requested product
      if (record.productId != productId) {
        AppLogger.warning(
          'Security alert: record productId (${record.productId}) does not match requested ($productId). Purging.',
        );
        await metaFile.delete();
        return null;
      }

      File completedFile;
      try {
        completedFile = _resolveAndValidateCompletedFile(
          record.relativeFilePath,
        );
      } catch (e) {
        AppLogger.warning(
          'Invalid relative path in record for $productId: $e. Purging.',
        );
        await metaFile.delete();
        return null;
      }

      if (!await completedFile.exists()) {
        AppLogger.warning(
          'Cached file missing for $productId. Purging metadata.',
        );
        await metaFile.delete();
        return null;
      }

      final actualSize = await completedFile.length();
      if (actualSize != record.fileSizeBytes) {
        AppLogger.warning(
          'Cached file size mismatch for $productId (expected: ${record.fileSizeBytes}, actual: $actualSize). Purging.',
        );
        await deleteAsset(productId);
        return null;
      }

      return record.toEntity(completedFile.path);
    } catch (e, stack) {
      AppLogger.error(
        'Failed reading verified asset for $productId: $e',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Crash-safe, generation-tracked commit of a completed temp file into storage.
  ///
  /// Protocol:
  /// 1. Validate tempFile existence, expected size, and expected SHA-256.
  /// 2. Generate a unique generation ID (timestamp).
  /// 3. Move tempFile to generation-tagged asset: `<productId>_gen<timestamp>.<ext>`.
  /// 4. Write staged metadata `<productId>.staged.json` pointing to the generation asset.
  /// 5. Atomically commit metadata by renaming `<productId>.staged.json` -> `<productId>.json`.
  ///    (The authoritative commit point is the metadata file).
  /// 6. Clean up previous generation assets that are no longer referenced.
  Future<LocalAssetMetadata> commitAsset({
    required String productId,
    required File tempFile,
    required String fileExtension,
    int? expectedSize,
    String? expectedSha256,
    String? etag,
    String? lastModifiedHeader,
  }) async {
    _validateProductId(productId);

    if (!await tempFile.exists()) {
      throw const NasaStorageFailure(
        message: 'Cannot commit asset: temporary file does not exist.',
      );
    }

    final actualSize = await tempFile.length();
    if (expectedSize != null && actualSize != expectedSize) {
      await tempFile.delete();
      throw IntegrityValidationFailure(
        message:
            'Size verification failed for $productId. Expected $expectedSize bytes, found $actualSize bytes.',
        expectedSize: expectedSize,
        actualSize: actualSize,
      );
    }

    String? actualSha256;
    IntegrityVerificationLevel verificationLevel =
        IntegrityVerificationLevel.notVerified;

    if (expectedSha256 != null) {
      actualSha256 = await computeSha256(tempFile);
      if (actualSha256.toLowerCase() != expectedSha256.toLowerCase()) {
        await tempFile.delete();
        throw IntegrityValidationFailure(
          message: 'SHA-256 digest mismatch for $productId.',
          expectedSha256: expectedSha256,
          actualSha256: actualSha256,
        );
      }
      verificationLevel = IntegrityVerificationLevel.sha256Verified;
    } else if (expectedSize != null) {
      verificationLevel = IntegrityVerificationLevel.sizeVerified;
    }

    final ext = fileExtension.startsWith('.')
        ? fileExtension
        : '.$fileExtension';
    final genTimestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final genFileName = '${productId}_gen$genTimestamp$ext';
    final genAssetFile = File(
      '${_completedDir.path}${Platform.pathSeparator}$genFileName',
    );

    // Step 1: Move temp file to generation asset file
    await tempFile.rename(genAssetFile.path);

    // Step 2: Prepare new metadata record pointing to this generation file
    final record = LocalAssetRecord(
      productId: productId,
      relativeFilePath: genFileName,
      fileSizeBytes: actualSize,
      acquiredAt: DateTime.now().toUtc(),
      sha256Digest: actualSha256,
      verificationLevel: verificationLevel,
      etag: etag,
      lastModifiedHeader: lastModifiedHeader,
    );

    final stagedMetaFile = File(
      '${_metaDir.path}${Platform.pathSeparator}$productId.staged.json',
    );
    final finalMetaFile = _getMetaFile(productId);

    try {
      // Step 3: Write staged metadata file and flush
      await stagedMetaFile.writeAsString(record.serialize(), flush: true);

      // Step 4: Authoritative atomic commit: rename staged metadata over final metadata
      await stagedMetaFile.rename(finalMetaFile.path);

      // Step 5: Post-commit cleanup: remove any older generation files or legacy unreferenced files for this product
      await _cleanUnreferencedGenerations(
        productId,
        activeRelativeFile: genFileName,
      );

      return record.toEntity(genAssetFile.path);
    } catch (e, stack) {
      AppLogger.error(
        'Failed committing metadata for $productId: $e',
        error: e,
        stackTrace: stack,
      );

      // Clean up the newly created generation file so it doesn't leak
      if (await genAssetFile.exists()) {
        await genAssetFile.delete();
      }
      if (await stagedMetaFile.exists()) {
        await stagedMetaFile.delete();
      }

      throw NasaStorageFailure(
        message: 'Commit failed for $productId: $e',
        cause: e,
        stackTrace: stack,
      );
    }
  }

  /// Crash-safe idempotent recovery protocol.
  ///
  /// Examines existing metadata records in `meta/` as the single authoritative commit pointer.
  /// Resolves any legacy .bak files, recovers any complete staged commits,
  /// validates referenced assets, and only purges unreferenced orphaned files.
  Future<void> recoverStorageState() async {
    try {
      // 1. Process meta files
      if (!await _metaDir.exists()) return;

      final metaFiles = await _metaDir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      final referencedCompletedFiles = <String>{};

      for (final metaFile in metaFiles) {
        final filename = metaFile.uri.pathSegments.last;

        // Handle interrupted staged metadata commit
        if (filename.endsWith('.staged.json')) {
          final prodId = filename.substring(
            0,
            filename.length - '.staged.json'.length,
          );
          final finalMeta = _getMetaFile(prodId);

          // If final metadata already exists, staged metadata is redundant
          if (await finalMeta.exists()) {
            await metaFile.delete();
          } else {
            // Interrupted right before rename: verify if staged metadata points to valid asset
            final jsonStr = await metaFile.readAsString();
            final record = LocalAssetRecord.tryDeserialize(jsonStr);
            if (record != null) {
              final assetFile = File(
                '${_completedDir.path}${Platform.pathSeparator}${record.relativeFilePath}',
              );
              if (await assetFile.exists() &&
                  (await assetFile.length()) == record.fileSizeBytes) {
                // Complete the commit
                await metaFile.rename(finalMeta.path);
                referencedCompletedFiles.add(record.relativeFilePath);
                continue;
              }
            }
            await metaFile.delete();
          }
          continue;
        }

        if (filename.endsWith('.json')) {
          final prodId = filename.substring(
            0,
            filename.length - '.json'.length,
          );
          try {
            final jsonStr = await metaFile.readAsString();
            final record = LocalAssetRecord.tryDeserialize(jsonStr);
            if (record != null && record.productId == prodId) {
              final assetFile = File(
                '${_completedDir.path}${Platform.pathSeparator}${record.relativeFilePath}',
              );
              if (await assetFile.exists() &&
                  (await assetFile.length()) == record.fileSizeBytes) {
                referencedCompletedFiles.add(record.relativeFilePath);
                continue;
              } else {
                // File missing or size corrupt; check if a legacy .bak exists for this product that matches
                final legacyBak = File(
                  '${_completedDir.path}${Platform.pathSeparator}$prodId.bak',
                );
                if (await legacyBak.exists() &&
                    (await legacyBak.length()) == record.fileSizeBytes) {
                  // Restore from legacy bak
                  await legacyBak.rename(assetFile.path);
                  referencedCompletedFiles.add(record.relativeFilePath);
                  continue;
                }
              }
            }
          } catch (_) {}
        }
      }

      // 2. Scan completed directory to clean only unreferenced staged or orphaned files
      if (await _completedDir.exists()) {
        await for (final entity in _completedDir.list()) {
          if (entity is File) {
            final name = entity.uri.pathSegments.last;
            // If referenced by a valid committed metadata record, never delete!
            if (referencedCompletedFiles.contains(name)) {
              continue;
            }

            // Check if this is an unreferenced generation or legacy .bak or .staged file
            final isUnreferencedStaged =
                name.contains('.staged') || name.contains('.staged.');
            final isGenerationFile = name.contains('_gen');
            final isLegacyBak = name.endsWith('.bak');

            // Before deleting a legacy .bak, ensure there is no metadata file that needed it
            if (isLegacyBak) {
              final prodId = name.substring(0, name.length - '.bak'.length);
              final meta = _getMetaFile(prodId);
              if (await meta.exists()) {
                // Keep it if metadata exists
                continue;
              }
            }

            if (isUnreferencedStaged || isGenerationFile || isLegacyBak) {
              await entity.delete();
            }
          }
        }
      }
    } catch (e, stack) {
      AppLogger.warning('Error during crash recovery: $e\n$stack');
    }
  }

  /// Removes older generation asset files for [productId] that are no longer referenced.
  Future<void> _cleanUnreferencedGenerations(
    String productId, {
    required String activeRelativeFile,
  }) async {
    try {
      if (!await _completedDir.exists()) return;

      await for (final entity in _completedDir.list()) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (name != activeRelativeFile &&
              (name.startsWith('${productId}_gen') ||
                  name == '$productId.bak' ||
                  name.startsWith('$productId.staged'))) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Error cleaning unreferenced generations for $productId: $e',
      );
    }
  }

  /// Safely deletes an asset, its temp files, and its metadata.
  Future<void> deleteAsset(String productId) async {
    _validateProductId(productId);

    try {
      final tempFile = getTempFile(productId);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final metaFile = _getMetaFile(productId);
      if (await metaFile.exists()) {
        final jsonStr = await metaFile.readAsString();
        final record = LocalAssetRecord.tryDeserialize(jsonStr);
        if (record != null && record.productId == productId) {
          try {
            final target = _resolveAndValidateCompletedFile(
              record.relativeFilePath,
            );
            if (await target.exists()) {
              await target.delete();
            }
          } catch (e) {
            AppLogger.warning(
              'Target file resolution failed during delete for $productId: $e',
            );
          }
        }
        await metaFile.delete();
      }

      // Also clean any unreferenced files or generations for this product
      await _cleanUnreferencedGenerations(productId, activeRelativeFile: '');
    } catch (e, stack) {
      AppLogger.error(
        'Error deleting asset $productId: $e',
        error: e,
        stackTrace: stack,
      );
      throw NasaStorageFailure(
        message: 'Failed to delete cached asset for $productId.',
        cause: e,
        stackTrace: stack,
      );
    }
  }

  /// Computes SHA-256 digest in chunks without loading entire file into memory.
  Future<String> computeSha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}

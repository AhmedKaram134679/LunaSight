import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:luna_sight/core/logging/app_logger.dart';
import 'package:luna_sight/features/nasa_data/data/models/local_asset_record.dart';
import 'package:luna_sight/features/nasa_data/domain/entities/acquisition_status.dart';
import 'package:luna_sight/features/nasa_data/domain/failures/nasa_data_failures.dart';

/// Manages local disk storage, atomic file movement, cache indexes, and integrity.
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

  /// Ensures storage directories exist and cleans any orphaned temporary files.
  Future<void> initialize() async {
    await _completedDir.create(recursive: true);
    await _tempDir.create(recursive: true);
    await _metaDir.create(recursive: true);
    await recoverOrphanedStagedFiles();
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

    // Canonicalize paths and ensure target is inside _completedDir
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

  /// Safely and atomically commits a completed temp file into the completed cache directory.
  ///
  /// Never destroys a previous valid asset before validating the new asset.
  /// Writes metadata to a staged temp file before atomically completing.
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

    final finalTargetFile = getCompletedFile(productId, fileExtension);
    final relativeFileName = finalTargetFile.uri.pathSegments.last;

    // Stage 1: Stage the new asset file in completed directory as .staged
    final stagedAssetFile = File(
      '${_completedDir.path}${Platform.pathSeparator}$productId.staged$fileExtension',
    );
    if (await stagedAssetFile.exists()) {
      await stagedAssetFile.delete();
    }

    // Move tempFile to staged file
    await tempFile.rename(stagedAssetFile.path);

    // Stage 2: Stage metadata file
    final record = LocalAssetRecord(
      productId: productId,
      relativeFilePath: relativeFileName,
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
    await stagedMetaFile.writeAsString(record.serialize(), flush: true);

    // Stage 3: Atomic swap of file and metadata
    // If an existing file exists, keep it as backup until replacement succeeds
    File? backupFile;
    if (await finalTargetFile.exists()) {
      backupFile = File(
        '${_completedDir.path}${Platform.pathSeparator}$productId.bak',
      );
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      await finalTargetFile.rename(backupFile.path);
    }

    try {
      // Rename staged asset to final target file
      await stagedAssetFile.rename(finalTargetFile.path);

      // Rename staged metadata to final metadata file
      final finalMetaFile = _getMetaFile(productId);
      await stagedMetaFile.rename(finalMetaFile.path);

      // Success: clean up backup
      if (backupFile != null && await backupFile.exists()) {
        await backupFile.delete();
      }

      return record.toEntity(finalTargetFile.path);
    } catch (e, stack) {
      AppLogger.error(
        'Failed atomic swap for $productId: $e. Restoring backup if available.',
        error: e,
        stackTrace: stack,
      );

      // Rollback: restore backup
      if (backupFile != null && await backupFile.exists()) {
        if (await finalTargetFile.exists()) {
          await finalTargetFile.delete();
        }
        await backupFile.rename(finalTargetFile.path);
      }

      // Cleanup staged files
      if (await stagedAssetFile.exists()) {
        await stagedAssetFile.delete();
      }
      if (await stagedMetaFile.exists()) {
        await stagedMetaFile.delete();
      }

      throw NasaStorageFailure(
        message: 'Atomic commit failed for $productId: $e',
        cause: e,
        stackTrace: stack,
      );
    }
  }

  /// Recovers any leftover staged files from interrupted operations.
  Future<void> recoverOrphanedStagedFiles() async {
    try {
      if (await _completedDir.exists()) {
        await for (final entity in _completedDir.list()) {
          if (entity is File &&
              (entity.path.endsWith('.staged') ||
                  entity.path.contains('.staged.') ||
                  entity.path.endsWith('.bak'))) {
            await entity.delete();
          }
        }
      }
      if (await _metaDir.exists()) {
        await for (final entity in _metaDir.list()) {
          if (entity is File && entity.path.contains('.staged.')) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Error cleaning up orphaned staged files: $e');
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

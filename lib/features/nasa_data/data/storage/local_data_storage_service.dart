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

  /// Ensures storage directories exist.
  Future<void> initialize() async {
    await _completedDir.create(recursive: true);
    await _tempDir.create(recursive: true);
    await _metaDir.create(recursive: true);
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
        productId.isEmpty) {
      throw NasaStorageFailure(
        message: 'Invalid product identifier for storage path: "$productId"',
      );
    }
  }

  /// Checks if an asset is present, intact, and matches its metadata record.
  Future<LocalAssetMetadata?> getVerifiedAsset(String productId) async {
    final metaFile = _getMetaFile(productId);
    if (!await metaFile.exists()) {
      return null;
    }

    try {
      final jsonStr = await metaFile.readAsString();
      final record = LocalAssetRecord.tryDeserialize(jsonStr);
      if (record == null) {
        AppLogger.warning('Corrupted cache record for $productId. Purging.');
        await deleteAsset(productId);
        return null;
      }

      final completedFile = File(
        '${_completedDir.path}${Platform.pathSeparator}${record.relativeFilePath}',
      );

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

  /// Atomically commits a completed temp file into the completed cache directory.
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
      throw NasaStorageFailure(
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
    }

    final targetFile = getCompletedFile(productId, fileExtension);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    // Atomic move / rename
    await tempFile.rename(targetFile.path);

    final record = LocalAssetRecord(
      productId: productId,
      relativeFilePath: targetFile.uri.pathSegments.last,
      fileSizeBytes: actualSize,
      acquiredAt: DateTime.now().toUtc(),
      sha256Digest: actualSha256,
      isIntegrityVerified: expectedSize != null || expectedSha256 != null,
      etag: etag,
      lastModifiedHeader: lastModifiedHeader,
    );

    final metaFile = _getMetaFile(productId);
    await metaFile.writeAsString(record.serialize());

    return record.toEntity(targetFile.path);
  }

  /// Deletes an asset, its temp files, and its metadata.
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
        if (record != null) {
          final target = File(
            '${_completedDir.path}${Platform.pathSeparator}${record.relativeFilePath}',
          );
          if (await target.exists()) {
            await target.delete();
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

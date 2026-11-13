import 'dart:convert';

import 'package:luna_sight/features/nasa_data/domain/entities/acquisition_status.dart';

/// Data model representing a local cache entry for an acquired NASA dataset.
class LocalAssetRecord {
  final String productId;
  final String relativeFilePath;
  final int fileSizeBytes;
  final DateTime acquiredAt;
  final String? sha256Digest;
  final bool isIntegrityVerified;
  final String? etag;
  final String? lastModifiedHeader;

  const LocalAssetRecord({
    required this.productId,
    required this.relativeFilePath,
    required this.fileSizeBytes,
    required this.acquiredAt,
    this.sha256Digest,
    this.isIntegrityVerified = false,
    this.etag,
    this.lastModifiedHeader,
  });

  LocalAssetMetadata toEntity(String absolutePath) {
    return LocalAssetMetadata(
      productId: productId,
      localFilePath: absolutePath,
      fileSizeBytes: fileSizeBytes,
      lastModified: acquiredAt,
      sha256Digest: sha256Digest,
      isIntegrityVerified: isIntegrityVerified,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'relativeFilePath': relativeFilePath,
    'fileSizeBytes': fileSizeBytes,
    'acquiredAt': acquiredAt.toIso8601String(),
    'sha256Digest': sha256Digest,
    'isIntegrityVerified': isIntegrityVerified,
    'etag': etag,
    'lastModifiedHeader': lastModifiedHeader,
  };

  factory LocalAssetRecord.fromJson(Map<String, dynamic> json) {
    return LocalAssetRecord(
      productId: json['productId'] as String,
      relativeFilePath: json['relativeFilePath'] as String,
      fileSizeBytes: json['fileSizeBytes'] as int,
      acquiredAt: DateTime.parse(json['acquiredAt'] as String),
      sha256Digest: json['sha256Digest'] as String?,
      isIntegrityVerified: json['isIntegrityVerified'] as bool? ?? false,
      etag: json['etag'] as String?,
      lastModifiedHeader: json['lastModifiedHeader'] as String?,
    );
  }

  String serialize() => jsonEncode(toJson());

  static LocalAssetRecord? tryDeserialize(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return LocalAssetRecord.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

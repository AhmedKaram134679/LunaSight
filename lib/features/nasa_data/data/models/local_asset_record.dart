import 'dart:convert';

import 'package:luna_sight/features/nasa_data/domain/entities/acquisition_status.dart';

/// Data model representing a local cache entry for an acquired NASA dataset.
class LocalAssetRecord {
  final String productId;
  final String relativeFilePath;
  final int fileSizeBytes;
  final DateTime acquiredAt;
  final String? sha256Digest;
  final IntegrityVerificationLevel verificationLevel;
  final String? etag;
  final String? lastModifiedHeader;

  const LocalAssetRecord({
    required this.productId,
    required this.relativeFilePath,
    required this.fileSizeBytes,
    required this.acquiredAt,
    this.sha256Digest,
    this.verificationLevel = IntegrityVerificationLevel.notVerified,
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
      verificationLevel: verificationLevel,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'relativeFilePath': relativeFilePath,
    'fileSizeBytes': fileSizeBytes,
    'acquiredAt': acquiredAt.toIso8601String(),
    'sha256Digest': sha256Digest,
    'verificationLevel': verificationLevel.name,
    'etag': etag,
    'lastModifiedHeader': lastModifiedHeader,
  };

  factory LocalAssetRecord.fromJson(Map<String, dynamic> json) {
    final productId = json['productId'];
    final relativeFilePath = json['relativeFilePath'];
    final fileSizeBytes = json['fileSizeBytes'];
    final acquiredAtStr = json['acquiredAt'];

    if (productId is! String ||
        relativeFilePath is! String ||
        fileSizeBytes is! int ||
        fileSizeBytes < 0 ||
        acquiredAtStr is! String) {
      throw const FormatException(
        'Invalid or missing fields in LocalAssetRecord JSON',
      );
    }

    final acquiredAt = DateTime.tryParse(acquiredAtStr);
    if (acquiredAt == null) {
      throw const FormatException('Invalid acquiredAt timestamp format');
    }

    IntegrityVerificationLevel level = IntegrityVerificationLevel.notVerified;
    if (json.containsKey('verificationLevel')) {
      final levelStr = json['verificationLevel'] as String?;
      level = IntegrityVerificationLevel.values.firstWhere(
        (e) => e.name == levelStr,
        orElse: () => IntegrityVerificationLevel.notVerified,
      );
    } else if (json['isIntegrityVerified'] == true) {
      // Backward compatibility with previous records
      level = (json['sha256Digest'] != null)
          ? IntegrityVerificationLevel.sha256Verified
          : IntegrityVerificationLevel.sizeVerified;
    }

    return LocalAssetRecord(
      productId: productId,
      relativeFilePath: relativeFilePath,
      fileSizeBytes: fileSizeBytes,
      acquiredAt: acquiredAt,
      sha256Digest: json['sha256Digest'] as String?,
      verificationLevel: level,
      etag: json['etag'] as String?,
      lastModifiedHeader: json['lastModifiedHeader'] as String?,
    );
  }

  String serialize() => jsonEncode(toJson());

  static LocalAssetRecord? tryDeserialize(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr);
      if (map is! Map<String, dynamic>) return null;
      return LocalAssetRecord.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

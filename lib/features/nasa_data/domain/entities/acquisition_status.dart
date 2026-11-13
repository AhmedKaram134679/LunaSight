import 'package:flutter/foundation.dart';

/// Lifecycle state of an asset download or local acquisition.
enum AcquisitionLifecycleState {
  notRequested,
  waiting,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
  integrityCheckFailed,
}

/// Dynamic runtime progress and state for an acquisition job.
@immutable
class AcquisitionProgress {
  final String productId;
  final AcquisitionLifecycleState state;
  final int bytesDownloaded;
  final int? totalBytes;
  final String? errorMessage;

  const AcquisitionProgress({
    required this.productId,
    required this.state,
    this.bytesDownloaded = 0,
    this.totalBytes,
    this.errorMessage,
  });

  double? get fractionCompleted {
    if (totalBytes == null || totalBytes! <= 0) return null;
    return (bytesDownloaded / totalBytes!).clamp(0.0, 1.0);
  }

  bool get isTerminal =>
      state == AcquisitionLifecycleState.completed ||
      state == AcquisitionLifecycleState.failed ||
      state == AcquisitionLifecycleState.cancelled ||
      state == AcquisitionLifecycleState.integrityCheckFailed;

  AcquisitionProgress copyWith({
    AcquisitionLifecycleState? state,
    int? bytesDownloaded,
    int? totalBytes,
    String? errorMessage,
  }) {
    return AcquisitionProgress(
      productId: productId,
      state: state ?? this.state,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() =>
      'AcquisitionProgress($productId, $state, $bytesDownloaded/${totalBytes ?? "?"})';
}

/// Metadata reflecting an asset stored locally and verified on disk.
@immutable
class LocalAssetMetadata {
  final String productId;
  final String localFilePath;
  final int fileSizeBytes;
  final DateTime lastModified;
  final String? sha256Digest;
  final bool isIntegrityVerified;

  const LocalAssetMetadata({
    required this.productId,
    required this.localFilePath,
    required this.fileSizeBytes,
    required this.lastModified,
    this.sha256Digest,
    this.isIntegrityVerified = false,
  });

  @override
  String toString() =>
      'LocalAssetMetadata($productId, path: $localFilePath, size: $fileSizeBytes)';
}

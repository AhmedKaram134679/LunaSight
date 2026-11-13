import 'package:luna_sight/core/error/failures.dart';

/// Base failure class for NASA data integration operations.
abstract class NasaDataFailure extends AppFailure {
  const NasaDataFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

/// Thrown when a requested NASA product is not found in the catalog.
class ProductNotFoundFailure extends NasaDataFailure {
  const ProductNotFoundFailure({required String productId})
    : super(
        message: 'NASA product "$productId" was not found in the catalog.',
        code: 'PRODUCT_NOT_FOUND',
      );
}

/// Thrown when an HTTP request fails or encounters an invalid status.
class NasaNetworkFailure extends NasaDataFailure {
  final int? statusCode;

  const NasaNetworkFailure({
    required super.message,
    this.statusCode,
    super.cause,
    super.stackTrace,
  }) : super(code: 'NASA_NETWORK_ERROR');
}

/// Thrown when the NASA server returns a rate-limiting 429 response.
class NasaRateLimitedFailure extends NasaNetworkFailure {
  final Duration? retryAfter;

  const NasaRateLimitedFailure({
    required super.message,
    this.retryAfter,
    super.cause,
    super.stackTrace,
  }) : super(statusCode: 429);
}

/// Thrown when the remote asset is forbidden (403).
class NasaForbiddenFailure extends NasaNetworkFailure {
  const NasaForbiddenFailure({
    required super.message,
    super.cause,
    super.stackTrace,
  }) : super(statusCode: 403);
}

/// Thrown when an untrusted or non-official URL is provided for acquisition.
class UntrustedUrlFailure extends NasaDataFailure {
  const UntrustedUrlFailure({required String url})
    : super(
        message:
            'Security validation failed: "$url" is not an approved official NASA product URL.',
        code: 'UNTRUSTED_URL_ERROR',
      );
}

/// Thrown when an acquisition is cancelled by the user or application.
class AcquisitionCancelledFailure extends NasaDataFailure {
  const AcquisitionCancelledFailure({
    super.message = 'NASA data acquisition was cancelled.',
  }) : super(code: 'ACQUISITION_CANCELLED');
}

/// Thrown when a concurrent acquisition of the same asset is already underway.
class AcquisitionConflictFailure extends NasaDataFailure {
  const AcquisitionConflictFailure({required String productId})
    : super(
        message:
            'An acquisition for product "$productId" is already actively running.',
        code: 'ACQUISITION_CONFLICT',
      );
}

/// Thrown when local filesystem, cache, or storage operations fail.
class NasaStorageFailure extends NasaDataFailure {
  const NasaStorageFailure({
    required super.message,
    super.cause,
    super.stackTrace,
  }) : super(code: 'NASA_STORAGE_ERROR');
}

/// Thrown when file size or digest verification fails.
class IntegrityValidationFailure extends NasaDataFailure {
  final int? expectedSize;
  final int? actualSize;
  final String? expectedSha256;
  final String? actualSha256;

  const IntegrityValidationFailure({
    required super.message,
    this.expectedSize,
    this.actualSize,
    this.expectedSha256,
    this.actualSha256,
  }) : super(code: 'INTEGRITY_VALIDATION_ERROR');
}

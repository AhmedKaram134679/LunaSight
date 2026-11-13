import 'dart:async';

import 'package:luna_sight/core/logging/app_logger.dart';
import 'package:luna_sight/features/nasa_data/data/datasources/nasa_product_catalog.dart';
import 'package:luna_sight/features/nasa_data/data/services/nasa_http_service.dart';
import 'package:luna_sight/features/nasa_data/data/storage/local_data_storage_service.dart';
import 'package:luna_sight/features/nasa_data/domain/entities/acquisition_status.dart';
import 'package:luna_sight/features/nasa_data/domain/entities/nasa_product_definition.dart';
import 'package:luna_sight/features/nasa_data/domain/failures/nasa_data_failures.dart';
import 'package:luna_sight/features/nasa_data/domain/repositories/nasa_data_repository.dart';

/// Production implementation of [NasaDataRepository].
class NasaDataRepositoryImpl implements NasaDataRepository {
  final NasaHttpService httpService;
  final LocalDataStorageService storageService;

  final Map<String, Completer<void>> _activeCancellations = {};
  final Map<String, StreamController<AcquisitionProgress>>
  _progressControllers = {};
  final Map<String, AcquisitionProgress> _currentProgress = {};

  NasaDataRepositoryImpl({
    required this.httpService,
    required this.storageService,
  });

  @override
  List<NasaProductDefinition> getAvailableProducts() {
    return NasaProductCatalog.allProducts;
  }

  @override
  Future<NasaProductDefinition?> getProductById(String productId) async {
    return NasaProductCatalog.findById(productId);
  }

  @override
  Future<bool> isAssetLocallyAvailable(String productId) async {
    final meta = await storageService.getVerifiedAsset(productId);
    return meta != null;
  }

  @override
  Future<LocalAssetMetadata?> getLocalAssetMetadata(String productId) async {
    return storageService.getVerifiedAsset(productId);
  }

  @override
  Stream<AcquisitionProgress> watchAcquisitionProgress(String productId) {
    final controller = _progressControllers.putIfAbsent(
      productId,
      () => StreamController<AcquisitionProgress>.broadcast(),
    );
    return controller.stream;
  }

  @override
  AcquisitionProgress getAcquisitionProgress(String productId) {
    return _currentProgress[productId] ??
        AcquisitionProgress(
          productId: productId,
          state: AcquisitionLifecycleState.notRequested,
        );
  }

  @override
  Future<LocalAssetMetadata> acquireProductAsset(
    String productId, {
    bool forceReacquire = false,
  }) async {
    final product = NasaProductCatalog.findById(productId);
    if (product == null) {
      throw ProductNotFoundFailure(productId: productId);
    }

    // Check if already available and not forced
    if (!forceReacquire) {
      final existing = await storageService.getVerifiedAsset(productId);
      if (existing != null) {
        _updateProgress(
          AcquisitionProgress(
            productId: productId,
            state: AcquisitionLifecycleState.completed,
            bytesDownloaded: existing.fileSizeBytes,
            totalBytes: existing.fileSizeBytes,
          ),
        );
        return existing;
      }
    }

    // Prevent duplicate concurrent acquisition
    if (_activeCancellations.containsKey(productId)) {
      throw AcquisitionConflictFailure(productId: productId);
    }

    final cancelSignal = Completer<void>();
    _activeCancellations[productId] = cancelSignal;

    _updateProgress(
      AcquisitionProgress(
        productId: productId,
        state: AcquisitionLifecycleState.waiting,
        totalBytes: product.publishedSizeBytes,
      ),
    );

    try {
      await storageService.initialize();
      final tempFile = storageService.getTempFile(productId);

      _updateProgress(
        AcquisitionProgress(
          productId: productId,
          state: AcquisitionLifecycleState.downloading,
          totalBytes: product.publishedSizeBytes,
        ),
      );

      final downloadInfo = await httpService.streamDownloadToFile(
        uri: product.officialAssetUrl,
        destinationFile: tempFile,
        expectedTotalBytes: product.publishedSizeBytes,
        cancelSignal: cancelSignal,
        onProgress: (bytesReceived, totalExpected) {
          _updateProgress(
            AcquisitionProgress(
              productId: productId,
              state: AcquisitionLifecycleState.downloading,
              bytesDownloaded: bytesReceived,
              totalBytes: totalExpected ?? product.publishedSizeBytes,
            ),
          );
        },
      );

      final extension = product.format.toLowerCase().contains('tiff')
          ? 'tif'
          : 'bin';

      final completedMetadata = await storageService.commitAsset(
        productId: productId,
        tempFile: tempFile,
        fileExtension: extension,
        expectedSize: product.publishedSizeBytes,
        etag: downloadInfo.etag,
        lastModifiedHeader: downloadInfo.lastModified,
      );

      _updateProgress(
        AcquisitionProgress(
          productId: productId,
          state: AcquisitionLifecycleState.completed,
          bytesDownloaded: completedMetadata.fileSizeBytes,
          totalBytes: completedMetadata.fileSizeBytes,
        ),
      );

      AppLogger.info(
        'Successfully acquired and committed NASA asset $productId (${completedMetadata.fileSizeBytes} bytes).',
      );

      return completedMetadata;
    } catch (e) {
      if (e is AcquisitionCancelledFailure) {
        _updateProgress(
          AcquisitionProgress(
            productId: productId,
            state: AcquisitionLifecycleState.cancelled,
            errorMessage: 'Acquisition cancelled by user.',
          ),
        );
      } else if (e is IntegrityValidationFailure) {
        _updateProgress(
          AcquisitionProgress(
            productId: productId,
            state: AcquisitionLifecycleState.integrityCheckFailed,
            errorMessage: e.message,
          ),
        );
      } else {
        _updateProgress(
          AcquisitionProgress(
            productId: productId,
            state: AcquisitionLifecycleState.failed,
            errorMessage: e.toString(),
          ),
        );
      }
      rethrow;
    } finally {
      _activeCancellations.remove(productId);
    }
  }

  @override
  Future<void> cancelAcquisition(String productId) async {
    final cancelSignal = _activeCancellations[productId];
    if (cancelSignal != null && !cancelSignal.isCompleted) {
      cancelSignal.complete();
    }
  }

  @override
  Future<void> removeCachedAsset(String productId) async {
    await storageService.deleteAsset(productId);
    _updateProgress(
      AcquisitionProgress(
        productId: productId,
        state: AcquisitionLifecycleState.notRequested,
      ),
    );
  }

  void _updateProgress(AcquisitionProgress progress) {
    _currentProgress[progress.productId] = progress;
    final controller = _progressControllers[progress.productId];
    if (controller != null && !controller.isClosed) {
      controller.add(progress);
    }
  }

  void dispose() {
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
  }
}

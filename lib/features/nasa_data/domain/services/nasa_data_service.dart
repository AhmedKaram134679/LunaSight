import 'package:luna_sight/features/nasa_data/domain/entities/acquisition_status.dart';
import 'package:luna_sight/features/nasa_data/domain/entities/nasa_product_definition.dart';
import 'package:luna_sight/features/nasa_data/domain/repositories/nasa_data_repository.dart';

/// Application/domain service orchestrating high-level NASA dataset interactions.
class NasaDataService {
  final NasaDataRepository repository;

  const NasaDataService({required this.repository});

  /// Lists all supported official NASA products.
  List<NasaProductDefinition> listAvailableProducts() {
    return repository.getAvailableProducts();
  }

  /// Retrieves detailed definition of a given product.
  Future<NasaProductDefinition?> getProductDetails(String productId) {
    return repository.getProductById(productId);
  }

  /// Verifies whether the asset file is stored locally and validated.
  Future<bool> isDatasetAvailable(String productId) {
    return repository.isAssetLocallyAvailable(productId);
  }

  /// Returns validated local file information.
  Future<LocalAssetMetadata?> getLocalDatasetInfo(String productId) {
    return repository.getLocalAssetMetadata(productId);
  }

  /// Initiates an explicit acquisition request for a product.
  Future<LocalAssetMetadata> acquireDataset(
    String productId, {
    bool forceReacquire = false,
  }) {
    return repository.acquireProductAsset(
      productId,
      forceReacquire: forceReacquire,
    );
  }

  /// Cancels an active acquisition.
  Future<void> cancelAcquisition(String productId) {
    return repository.cancelAcquisition(productId);
  }

  /// Removes a cached dataset from local storage.
  Future<void> purgeCachedDataset(String productId) {
    return repository.removeCachedAsset(productId);
  }

  /// Observes real-time progress for a dataset acquisition.
  Stream<AcquisitionProgress> observeProgress(String productId) {
    return repository.watchAcquisitionProgress(productId);
  }

  /// Current progress snapshot.
  AcquisitionProgress currentProgress(String productId) {
    return repository.getAcquisitionProgress(productId);
  }
}

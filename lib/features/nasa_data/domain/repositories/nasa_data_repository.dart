import 'dart:async';

import 'package:luna_sight/features/nasa_data/domain/entities/acquisition_status.dart';
import 'package:luna_sight/features/nasa_data/domain/entities/nasa_product_definition.dart';

/// Pure domain contract for interacting with NASA planetary datasets.
///
/// Decouples higher-level consumers and scientific engines from HTTP streaming,
/// disk caching, and network protocols.
abstract class NasaDataRepository {
  /// Lists all registered and officially verified NASA products in the catalog.
  List<NasaProductDefinition> getAvailableProducts();

  /// Retrieves the detailed product definition for a specific product ID.
  Future<NasaProductDefinition?> getProductById(String productId);

  /// Checks whether the asset file for [productId] exists locally in verified cache.
  Future<bool> isAssetLocallyAvailable(String productId);

  /// Retrieves validated local file metadata for [productId], or null if absent or invalid.
  Future<LocalAssetMetadata?> getLocalAssetMetadata(String productId);

  /// Streams real-time acquisition progress and state transitions for [productId].
  Stream<AcquisitionProgress> watchAcquisitionProgress(String productId);

  /// Gets the current acquisition snapshot for [productId].
  AcquisitionProgress getAcquisitionProgress(String productId);

  /// Initiates explicit download of the official asset for [productId].
  ///
  /// Never executes automatically; requires explicit initiation.
  Future<LocalAssetMetadata> acquireProductAsset(
    String productId, {
    bool forceReacquire = false,
  });

  /// Cancels an in-progress acquisition job for [productId].
  Future<void> cancelAcquisition(String productId);

  /// Removes cached asset file and associated tracking records for [productId].
  Future<void> removeCachedAsset(String productId);
}

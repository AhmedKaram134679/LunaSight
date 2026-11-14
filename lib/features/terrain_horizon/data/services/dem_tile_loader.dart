import 'dart:io';
import 'dart:typed_data';

import 'package:luna_sight/features/terrain_horizon/data/providers/tiled_terrain_data_provider.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/dem_metadata.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/elevation_sample.dart';

/// Service responsible for loading, decoding, and caching local DEM tile files.
class DemTileLoader {
  final String baseDirectoryPath;

  const DemTileLoader({required this.baseDirectoryPath});

  /// Loads a decoded binary tile file from disk.
  Future<DemTile?> loadTile({
    required int tileX,
    required int tileY,
    required DemMetadata metadata,
    String? customFileName,
  }) async {
    final fileName = customFileName ?? 'tile_${tileX}_$tileY.bin';
    final file = File('$baseDirectoryPath/$fileName');

    if (!await file.exists()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    final byteData = ByteData.sublistView(bytes);

    const expectedPixels = 256 * 256;
    if (bytes.lengthInBytes != expectedPixels * 4) {
      throw FormatException(
        'Invalid tile binary length: got ${bytes.lengthInBytes} bytes, expected ${expectedPixels * 4} bytes.',
      );
    }

    final floatList = Float32List(expectedPixels);
    for (var i = 0; i < expectedPixels; i++) {
      floatList[i] = byteData.getFloat32(i * 4, Endian.little);
    }

    return TiledTerrainDataProvider.createTileFromFloat32Buffer(
      tileX: tileX,
      tileY: tileY,
      elevations: floatList,
      metadata: metadata,
    );
  }
}

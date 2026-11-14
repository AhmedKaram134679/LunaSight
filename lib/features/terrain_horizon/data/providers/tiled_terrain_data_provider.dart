import 'dart:typed_data';

import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/dem_metadata.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/elevation_sample.dart';
import 'package:luna_sight/features/terrain_horizon/domain/projections/south_polar_stereographic.dart';
import 'package:luna_sight/features/terrain_horizon/domain/services/terrain_horizon_engine.dart';

/// In-memory terrain data provider backed by decoded DEM tiles (e.g. LOLA Product 81).
class TiledTerrainDataProvider implements TerrainDataProvider {
  final DemMetadata metadata;
  final SouthPolarStereographic projection;
  final Map<int, DemTile> _tiles = {};

  TiledTerrainDataProvider({
    required this.metadata,
    SouthPolarStereographic? projection,
  }) : projection =
           projection ??
           SouthPolarStereographic(
             sphereRadiusMeters:
                 metadata.referenceSurface.equatorialRadius.meters,
           );

  @override
  double get sphereRadiusMeters =>
      metadata.referenceSurface.equatorialRadius.meters;

  /// Adds a decoded tile to the in-memory cache.
  void addTile(DemTile tile) {
    // Unique key from tile coordinates (e.g. tileY * 1000 + tileX)
    final key = tile.tileY * 10000 + tile.tileX;
    _tiles[key] = tile;
  }

  /// Number of currently loaded tiles.
  int get loadedTileCount => _tiles.length;

  /// Samples elevation at given geographic coordinates.
  @override
  ElevationSample getElevation(Angle latitude, Angle longitude) {
    if (metadata.projectionType == ProjectionType.southPolarStereographic) {
      // 1. Project (lat, lon) -> (x, y)
      final (x, y) = projection.forward(
        latitude: latitude,
        longitude: longitude,
      );

      // Check overall DEM projected extent
      final extent = metadata.projectedExtent;
      if (extent != null && !extent.contains(x, y)) {
        return ElevationSample(
          elevationMeters: double.nan,
          status: ElevationSampleStatus.outsideCoverage,
          latitude: latitude,
          longitude: longitude,
          projectedX: x,
          projectedY: y,
        );
      }

      // 2. Identify corresponding tile
      // TiePoint: (-100000, 100000). Pixel scale: 5m.
      // Column = (x - tiePointX) / pixelScale
      // Row = (tiePointY - y) / pixelScale
      final col = (x - metadata.tiePointX) / metadata.pixelScaleX;
      final row = (metadata.tiePointY - y) / metadata.pixelScaleY;

      final tileX = (col / 256).floor();
      final tileY = (row / 256).floor();

      final key = tileY * 10000 + tileX;
      final tile = _tiles[key];

      if (tile == null) {
        // Tile not loaded in memory
        return ElevationSample(
          elevationMeters: double.nan,
          status: ElevationSampleStatus.outsideCoverage,
          latitude: latitude,
          longitude: longitude,
          projectedX: x,
          projectedY: y,
        );
      }

      final (elev, sampleStatus) = tile.sampleDetailed(x, y);
      if (elev == null) {
        return ElevationSample(
          elevationMeters: double.nan,
          status: sampleStatus,
          latitude: latitude,
          longitude: longitude,
          projectedX: x,
          projectedY: y,
        );
      }

      return ElevationSample(
        elevationMeters: elev,
        status: sampleStatus,
        latitude: latitude,
        longitude: longitude,
        projectedX: x,
        projectedY: y,
      );
    } else {
      throw UnsupportedError(
        'Unsupported DEM projection: ${metadata.projectionType}',
      );
    }
  }

  /// Helper factory to load a raw decoded tile binary fixture.
  static DemTile createTileFromFloat32Buffer({
    required int tileX,
    required int tileY,
    required Float32List elevations,
    required DemMetadata metadata,
  }) {
    const tilePixels = 256;
    final minX = metadata.tiePointX + tileX * tilePixels * metadata.pixelScaleX;
    final maxX = minX + tilePixels * metadata.pixelScaleX;
    final maxY = metadata.tiePointY - tileY * tilePixels * metadata.pixelScaleY;
    final minY = maxY - tilePixels * metadata.pixelScaleY;

    return DemTile(
      tileX: tileX,
      tileY: tileY,
      width: tilePixels,
      height: tilePixels,
      elevations: elevations,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      pixelScale: metadata.pixelScaleX,
      noDataValue: metadata.noDataValue,
    );
  }
}

import 'dart:typed_data';

import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';

/// Scientific status of an elevation sample.
enum ElevationSampleStatus {
  /// Valid elevation measurement.
  valid,

  /// Valid elevation measurement from bilinear interpolation.
  validBilinear,

  /// Valid elevation measurement from nearest-neighbor fallback (e.g. edge or mixed neighbor cell).
  validNearestNeighbor,

  /// Sample lies outside available raster coverage.
  outsideCoverage,

  /// Sample falls on a designated NoData cell.
  noData;

  /// Convenience getter for any valid elevation status.
  bool get isValid =>
      this == ElevationSampleStatus.valid ||
      this == ElevationSampleStatus.validBilinear ||
      this == ElevationSampleStatus.validNearestNeighbor;
}

/// An elevation sample extracted from a digital elevation model.
class ElevationSample {
  /// The signed elevation in meters relative to the DEM reference surface.
  final double elevationMeters;

  /// Quality/validity status of this sample.
  final ElevationSampleStatus status;

  /// Latitude of the sample.
  final Angle latitude;

  /// Longitude of the sample.
  final Angle longitude;

  /// Projected coordinates (if applicable).
  final double? projectedX;
  final double? projectedY;

  const ElevationSample({
    required this.elevationMeters,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.projectedX,
    this.projectedY,
  });

  bool get isValid => status.isValid;

  static final ElevationSample outOfBounds = ElevationSample(
    elevationMeters: double.nan,
    status: ElevationSampleStatus.outsideCoverage,
    latitude: Angle.fromRadians(0.0),
    longitude: Angle.fromRadians(0.0),
  );

  static final ElevationSample noDataSample = ElevationSample(
    elevationMeters: double.nan,
    status: ElevationSampleStatus.noData,
    latitude: Angle.fromRadians(0.0),
    longitude: Angle.fromRadians(0.0),
  );
}

/// An in-memory raster tile of decoded elevation data.
class DemTile {
  /// Tile index along column (X direction).
  final int tileX;

  /// Tile index along row (Y direction).
  final int tileY;

  /// Tile width in pixels.
  final int width;

  /// Tile height in pixels.
  final int height;

  /// Decoded 32-bit floating point elevations (row-major order).
  final Float32List elevations;

  /// Upper-left projected X of this tile in meters.
  final double minX;

  /// Lower-right projected X of this tile in meters.
  final double maxX;

  /// Lower-right projected Y of this tile in meters.
  final double minY;

  /// Upper-left projected Y of this tile in meters.
  final double maxY;

  /// Horizontal pixel scale.
  final double pixelScale;

  /// NoData indicator.
  final double? noDataValue;

  DemTile({
    required this.tileX,
    required this.tileY,
    required this.width,
    required this.height,
    required this.elevations,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.pixelScale,
    this.noDataValue,
  });

  /// Samples elevation at projected coordinates (x, y) returning both elevation and interpolation quality.
  ///
  /// Conforms to GeoTIFF PixelIsArea semantics:
  /// Continuous sample array coordinates are centered at half-pixel offsets from outer cell edges:
  /// $$c = \frac{x - \text{minX}}{\text{pixelScale}} - 0.5$$
  /// $$r = \frac{\text{maxY} - y}{\text{pixelScale}} - 0.5$$
  ///
  /// Mathematical interpolation domain:
  /// Valid bilinear interpolation is defined strictly within the convex hull of available pixel centers:
  /// $$c \in [0, \text{width} - 1] \quad \text{and} \quad r \in [0, \text{height} - 1]$$
  /// Outside this domain (the outer half-pixel border $[ -0.5, 0 )$ or $( \text{width} - 1, \text{width} - 0.5 ]$),
  /// a full $2 \times 2$ neighborhood does not exist within the tile. Bilinear extrapolation is strictly rejected,
  /// and the engine falls back to [ElevationSampleStatus.validNearestNeighbor] using the nearest available pixel center.
  (double?, ElevationSampleStatus) sampleDetailed(double x, double y) {
    if (x < minX || x > maxX || y < minY || y > maxY) {
      return (null, ElevationSampleStatus.outsideCoverage);
    }

    final col = (x - minX) / pixelScale - 0.5;
    final row = (maxY - y) / pixelScale - 0.5;

    // Nearest neighbor pixel index
    final nearestCol = col.round().clamp(0, width - 1);
    final nearestRow = row.round().clamp(0, height - 1);

    // If query point lies outside the interior bilinear convex hull of pixel centers,
    // fallback to nearest neighbor to prevent invalid extrapolation.
    final isEdgeBorder =
        col < 0.0 || col > (width - 1) || row < 0.0 || row > (height - 1);

    if (isEdgeBorder) {
      final nearestVal = elevations[nearestRow * width + nearestCol];
      if (_isNoData(nearestVal)) {
        return (null, ElevationSampleStatus.noData);
      }
      return (
        nearestVal.toDouble(),
        ElevationSampleStatus.validNearestNeighbor,
      );
    }

    // Inside bilinear domain: c0 in [0, width - 2], r0 in [0, height - 2]
    // Note: When col == width - 1 exactly, c0 would be width - 1; in that boundary case,
    // (col - c0) == 0.0, evaluating to the exact column sample.
    final c0 = col.floor().clamp(0, width - 2);
    final r0 = row.floor().clamp(0, height - 2);
    final c1 = c0 + 1;
    final r1 = r0 + 1;

    final v00 = elevations[r0 * width + c0];
    final v10 = elevations[r0 * width + c1];
    final v01 = elevations[r1 * width + c0];
    final v11 = elevations[r1 * width + c1];

    if (_isNoData(v00) || _isNoData(v10) || _isNoData(v01) || _isNoData(v11)) {
      // Nearest neighbor fallback if one neighbor is NoData
      final nearestVal = elevations[nearestRow * width + nearestCol];
      if (_isNoData(nearestVal)) {
        return (null, ElevationSampleStatus.noData);
      }
      return (
        nearestVal.toDouble(),
        ElevationSampleStatus.validNearestNeighbor,
      );
    }

    final dx = (col - c0).clamp(0.0, 1.0);
    final dy = (row - r0).clamp(0.0, 1.0);

    final top = v00 * (1.0 - dx) + v10 * dx;
    final bottom = v01 * (1.0 - dx) + v11 * dx;

    return (
      (top * (1.0 - dy) + bottom * dy).toDouble(),
      ElevationSampleStatus.validBilinear,
    );
  }

  /// Samples elevation at projected coordinates (x, y) using bilinear interpolation.
  double? sampleBilinear(double x, double y) {
    final (val, _) = sampleDetailed(x, y);
    return val;
  }

  /// Samples elevation using nearest-neighbor under PixelIsArea semantics.
  double? sampleNearest(double x, double y) {
    if (x < minX || x > maxX || y < minY || y > maxY) {
      return null;
    }
    final col = ((x - minX) / pixelScale - 0.5).round().clamp(0, width - 1);
    final row = ((maxY - y) / pixelScale - 0.5).round().clamp(0, height - 1);

    final val = elevations[row * width + col];
    return _isNoData(val) ? null : val.toDouble();
  }

  bool _isNoData(double val) {
    if (!val.isFinite) return true;
    if (noDataValue != null) {
      // Float comparison with tolerance
      return (val - noDataValue!).abs() < 1e-4 || val < -1e30;
    }
    return val < -1e30;
  }
}

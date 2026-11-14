import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';

/// Geographic bounding box defining the geographic coverage of a terrain grid or tile.
class GeographicExtent {
  /// Minimum latitude (South limit) as an [Angle].
  final Angle minLatitude;

  /// Maximum latitude (North limit) as an [Angle].
  final Angle maxLatitude;

  /// Minimum longitude (West limit) as an [Angle].
  final Angle minLongitude;

  /// Maximum longitude (East limit) as an [Angle].
  final Angle maxLongitude;

  const GeographicExtent({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  /// Checks whether [latitude] and [longitude] fall within this extent.
  bool contains(Angle latitude, Angle longitude) {
    final latDeg = latitude.inDegrees;
    final lonDeg = longitude.inDegrees;

    if (latDeg < minLatitude.inDegrees || latDeg > maxLatitude.inDegrees) {
      return false;
    }

    // Handle standard longitude containment
    final minLon = minLongitude.inDegrees;
    final maxLon = maxLongitude.inDegrees;

    if (minLon <= maxLon) {
      return lonDeg >= minLon && lonDeg <= maxLon;
    } else {
      // Crosses antimeridian / wrapping boundary
      return lonDeg >= minLon || lonDeg <= maxLon;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GeographicExtent &&
          minLatitude == other.minLatitude &&
          maxLatitude == other.maxLatitude &&
          minLongitude == other.minLongitude &&
          maxLongitude == other.maxLongitude);

  @override
  int get hashCode =>
      Object.hash(minLatitude, maxLatitude, minLongitude, maxLongitude);

  @override
  String toString() =>
      'GeographicExtent(lat: [${minLatitude.inDegrees}°, ${maxLatitude.inDegrees}°], '
      'lon: [${minLongitude.inDegrees}°, ${maxLongitude.inDegrees}°])';
}

/// Projected bounding box in meters for projected coordinate systems (e.g. Polar Stereographic).
class ProjectedExtent {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const ProjectedExtent({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  double get width => maxX - minX;
  double get height => maxY - minY;

  bool contains(double x, double y) =>
      x >= minX && x <= maxX && y >= minY && y <= maxY;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectedExtent &&
          minX == other.minX &&
          maxX == other.maxX &&
          minY == other.minY &&
          maxY == other.maxY);

  @override
  int get hashCode => Object.hash(minX, maxX, minY, maxY);

  @override
  String toString() =>
      'ProjectedExtent(X: [$minX, $maxX] m, Y: [$minY, $maxY] m)';
}

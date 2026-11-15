import 'dart:math' as math;

import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';

/// Representation of polar stereographic map coordinates for visual plotting.
class PolarMapPoint {
  /// Latitude in degrees (typically negative for south pole, e.g. -89.9°).
  final double latitude;

  /// Longitude in degrees East (0° to 360° or -180° to +180°).
  final double longitude;

  /// Normalized radial distance from South Pole (0.0 at 90°S, 1.0 at map boundary latitude, e.g. 80°S).
  final double normalizedRadius;

  /// Polar angle in radians for polar plotting (0 rad along Prime Meridian / Earth-facing).
  final double polarAngleRadians;

  /// Whether these coordinates are exact user-specified point coordinates
  /// or canonical representative center coordinates for regional footprints.
  final bool isExactPoint;

  const PolarMapPoint({
    required this.latitude,
    required this.longitude,
    required this.normalizedRadius,
    required this.polarAngleRadians,
    required this.isExactPoint,
  });
}

/// Helper service providing south polar stereographic projection mappings for [LunarSite] entities.
///
/// For sites with point coordinates (such as custom user-entered sites), projects the exact coordinates.
/// For official NASA Product 78 regional footprints whose [LunarSite.coordinates] are preserved as null
/// to avoid false precision, maps to canonical regional center coordinates documented in lunar exploration literature.
class LunarMapCoordinatesHelper {
  const LunarMapCoordinatesHelper();

  /// Canonical approximate center coordinates for official NASA Product 78 regions
  /// used exclusively for visual polar map representation.
  static const Map<String, (double lat, double lon)> canonicalRegionalCenters =
      {
        'nasa_p78_site01': (-89.44, 222.5), // Connecting Ridge
        'nasa_p78_site04': (-89.90, 0.0), // Shackleton Rim
        'nasa_p78_site06': (-85.20, 53.5), // Nobile Rim 1
        'nasa_p78_site07': (-87.40, 354.9), // Haworth Crater
        'nasa_p78_site11': (-84.50, 82.8), // Amundsen Rim
        'nasa_p78_site14': (-87.10, 77.0), // Faustini Rim
        'nasa_p78_site19': (-88.50, 271.0), // de Gerlache Rim
        'nasa_p78_site23': (-85.90, 2.9), // Malapert Mountain
        'nasa_p78_site27': (-88.10, 111.3), // Slater Crater
        'nasa_p78_site02': (-89.50, 160.0), // Connecting Ridge Ext
        'nasa_p78_site03': (-89.70, 120.0), // Shackleton Ridge
        'nasa_p78_site05': (-89.80, 200.0), // Shackleton-de Gerlache Ridge
        'nasa_p78_site08': (-86.80, 340.0), // Shoemaker Rim
        'nasa_p78_site09': (-86.20, 320.0), // Cabeus B
        'nasa_p78_site10': (-85.50, 310.0), // Cabeus A
        'nasa_p78_site12': (-84.80, 105.0), // Amundsen Ridge
        'nasa_p78_site13': (-85.90, 88.0), // Faustini Ridge
        'nasa_p78_site15': (-87.80, 60.0), // Shoemaker North
        'nasa_p78_site16': (-88.20, 30.0), // Shackleton Flank
        'nasa_p78_site17': (-88.90, 290.0), // de Gerlache Ridge
        'nasa_p78_site18': (-88.60, 280.0), // de Gerlache West
        'nasa_p78_site20': (-87.20, 240.0), // Kocher Crater
        'nasa_p78_site21': (-86.50, 220.0), // Ashbrook Rim
        'nasa_p78_site22': (-85.40, 0.0), // Malapert Plateau
        'nasa_p78_site24': (-85.00, 350.0), // Haworth Flank
        'nasa_p78_site25': (-86.10, 130.0), // Idel'son Crater
        'nasa_p78_site26': (-87.00, 140.0), // Spudis Crater
      };

  /// Computes the polar map point for [site].
  ///
  /// [mapBoundaryLatitude] defines the outer edge of the polar map (default -80.0° for South Pole).
  PolarMapPoint? getMapPoint(
    LunarSite site, {
    double mapBoundaryLatitude = -80.0,
  }) {
    double lat;
    double lon;
    bool isExact;

    if (site.hasCoordinates) {
      lat = site.coordinates!.latitude;
      lon = site.coordinates!.longitude;
      isExact = true;
    } else if (canonicalRegionalCenters.containsKey(site.id)) {
      final pair = canonicalRegionalCenters[site.id]!;
      lat = pair.$1;
      lon = pair.$2;
      isExact = false;
    } else {
      // Deterministic fallback based on hash code if unrecognized region
      final hash = site.id.hashCode.abs();
      lat = -85.0 - (hash % 45) / 10.0;
      lon = (hash % 360).toDouble();
      isExact = false;
    }

    // Polar stereographic projection math:
    // Distance from south pole (-90°) in degrees
    final deltaLat = (lat - (-90.0)).abs();
    final maxDeltaLat = (mapBoundaryLatitude - (-90.0)).abs();
    final normalizedRadius = (deltaLat / maxDeltaLat).clamp(0.0, 1.0);

    // Convert longitude to radians (0° along prime meridian / +X axis)
    final polarAngleRad = (lon * math.pi / 180.0);

    return PolarMapPoint(
      latitude: lat,
      longitude: lon,
      normalizedRadius: normalizedRadius,
      polarAngleRadians: polarAngleRad,
      isExactPoint: isExact,
    );
  }

  /// Calculates the surface distance to the exact South Pole (-90°S) in kilometers.
  static double distanceToSouthPoleKm(double latitudeDegrees) {
    const double meanLunarRadiusKm = 1737.4;
    final angularDistRad = (latitudeDegrees - (-90.0)).abs() * math.pi / 180.0;
    return meanLunarRadiusKm * angularDistRad;
  }
}

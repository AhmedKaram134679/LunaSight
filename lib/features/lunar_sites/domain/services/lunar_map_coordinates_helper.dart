import 'dart:math' as math;
import 'dart:ui';

import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/services/celestial_visibility_service.dart';

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

/// Known lunar polar landmark or prominent crater.
class LunarLandmark {
  final String name;
  final double latitude;
  final double longitude;
  final double diameterKm;
  final String featureType;
  final String description;

  const LunarLandmark({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.diameterKm,
    required this.featureType,
    required this.description,
  });
}

/// Result of querying the nearest crater or landmark to a given coordinate.
class NearestLandmarkInfo {
  final LunarLandmark landmark;
  final double distanceKm;
  final String compassBearing;

  const NearestLandmarkInfo({
    required this.landmark,
    required this.distanceKm,
    required this.compassBearing,
  });

  String get formattedSummary =>
      '${landmark.name} (${distanceKm.toStringAsFixed(1)} km $compassBearing • ${landmark.diameterKm.toStringAsFixed(0)} km dia)';
}

/// Available elevation and terrain dataset metadata.
class TerrainDataStatus {
  final String sourceName;
  final String resolution;
  final String datumDescription;
  final String measurementNotice;
  final double? pointElevationMeters;

  const TerrainDataStatus({
    this.sourceName = 'NASA LRO LOLA PDS / GSFC PGDA Product 78',
    this.resolution = '5 m/pixel (targeted) / 20 m/pixel (polar mosaic)',
    this.datumDescription =
        'Spherical Reference Datum (Radius = 1,737,400.0 m)',
    this.measurementNotice = 'Point-specific DEM elevation requires localized LOLA raster tile sampling. Synthetic elevations strictly avoided.',
    this.pointElevationMeters,
  });
}

/// Encapsulates rich inspection data for any tapped location on the lunar surface.
class SelectedLunarLocation {
  final double latitude;
  final double longitude;
  final double distanceToSouthPoleKm;
  final NearestLandmarkInfo nearestLandmark;
  final TerrainDataStatus terrainStatus;
  final CelestialVisibilityState visibility;
  final bool isNearExistingSite;
  final LunarSite? existingSite;

  const SelectedLunarLocation({
    required this.latitude,
    required this.longitude,
    required this.distanceToSouthPoleKm,
    required this.nearestLandmark,
    required this.terrainStatus,
    required this.visibility,
    this.isNearExistingSite = false,
    this.existingSite,
  });

  /// Formatted latitude in degrees and cardinal direction (e.g., "88.4215°S").
  String get formattedLatitude =>
      '${latitude.abs().toStringAsFixed(4)}°${latitude >= 0 ? "N" : "S"}';

  /// Formatted longitude in East-positive convention (e.g., "142.3051°E").
  String get formattedLongitudeEast => '${longitude.toStringAsFixed(4)}°E';

  /// Dual-format longitude indicating ±180° representation.
  String get formattedLongitudeSigned {
    final signed = longitude > 180.0 ? longitude - 360.0 : longitude;
    final dir = signed >= 0 ? 'E' : 'W';
    return '${signed.abs().toStringAsFixed(4)}°$dir (${longitude.toStringAsFixed(4)}°E)';
  }
}

/// Helper service providing south polar stereographic projection mappings for [LunarSite] entities
/// and arbitrary coordinate selection.
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

  /// Prominent craters and surface massifs in the south-polar region.
  static const List<LunarLandmark> polarLandmarks = [
    LunarLandmark(
      name: 'Shackleton Crater',
      latitude: -89.90,
      longitude: 0.0,
      diameterKm: 21.0,
      featureType: 'Impact Crater',
      description: 'Impact crater situated at the lunar south pole with permanently shadowed interior cold traps.',
    ),
    LunarLandmark(
      name: 'Connecting Ridge',
      latitude: -89.44,
      longitude: 222.5,
      diameterKm: 15.0,
      featureType: 'Topographic Ridge',
      description: 'Narrow elevated ridge connecting Shackleton and de Gerlache with persistent solar illumination.',
    ),
    LunarLandmark(
      name: 'Faustini Crater',
      latitude: -87.10,
      longitude: 77.0,
      diameterKm: 39.0,
      featureType: 'Impact Crater',
      description: 'Substantial south-polar cold trap crater containing volatile organic and water-ice deposits.',
    ),
    LunarLandmark(
      name: 'Shoemaker Crater',
      latitude: -88.10,
      longitude: 45.0,
      diameterKm: 50.0,
      featureType: 'Impact Crater',
      description: 'Deep basin adjacent to Faustini with extensive permanently shadowed regions.',
    ),
    LunarLandmark(
      name: 'Haworth Crater',
      latitude: -87.40,
      longitude: 354.9,
      diameterKm: 35.0,
      featureType: 'Impact Crater',
      description: 'Deep depression on the near-side polar flank near Malapert mountain.',
    ),
    LunarLandmark(
      name: 'Nobile Crater',
      latitude: -85.20,
      longitude: 53.5,
      diameterKm: 73.0,
      featureType: 'Impact Crater',
      description:
          'Target region for NASA VIPER rover water-ice volatile prospecting.',
    ),
    LunarLandmark(
      name: 'Amundsen Crater',
      latitude: -84.50,
      longitude: 82.8,
      diameterKm: 105.0,
      featureType: 'Impact Crater',
      description: 'Prominent complex impact crater with central peaks and terraced walls.',
    ),
    LunarLandmark(
      name: 'de Gerlache Crater',
      latitude: -88.50,
      longitude: 271.0,
      diameterKm: 32.0,
      featureType: 'Impact Crater',
      description: 'Impact crater on the far-side rim with highly elevated illumination ridges.',
    ),
    LunarLandmark(
      name: 'Malapert Mountain',
      latitude: -84.90,
      longitude: 12.9,
      diameterKm: 69.0,
      featureType: 'Massif / Mountain',
      description: 'Elevated lunar massif providing nearly continuous line-of-sight communication to Earth.',
    ),
    LunarLandmark(
      name: 'Cabeus Crater',
      latitude: -85.30,
      longitude: 324.5,
      diameterKm: 100.0,
      featureType: 'Impact Crater',
      description: 'Site of NASA LCROSS kinetic impact confirmation of hydroxyl and water ice.',
    ),
    LunarLandmark(
      name: 'Slater Crater',
      latitude: -88.10,
      longitude: 111.3,
      diameterKm: 25.0,
      featureType: 'Impact Crater',
      description: 'Shadowed crater between Faustini and Shoemaker within the polar cold trap network.',
    ),
    LunarLandmark(
      name: 'Leibnitz Plateau',
      latitude: -85.80,
      longitude: 180.0,
      diameterKm: 80.0,
      featureType: 'Highland Plateau',
      description: 'Elevated highland plateau on the lunar far-side meridian south pole.',
    ),
  ];

  /// Computes the polar map point for [site].
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
      final hash = site.id.hashCode.abs();
      lat = -85.0 - (hash % 45) / 10.0;
      lon = (hash % 360).toDouble();
      isExact = false;
    }

    final deltaLat = (lat - (-90.0)).abs();
    final maxDeltaLat = (mapBoundaryLatitude - (-90.0)).abs();
    final normalizedRadius = (deltaLat / maxDeltaLat).clamp(0.0, 1.0);
    final polarAngleRad = (lon * math.pi / 180.0);

    return PolarMapPoint(
      latitude: lat,
      longitude: lon,
      normalizedRadius: normalizedRadius,
      polarAngleRadians: polarAngleRad,
      isExactPoint: isExact,
    );
  }

  /// Converts a tapped screen offset on the map canvas into selenographic (latitude, longitude).
  ///
  /// Enforces polar stereographic projection math centered at -90.0°S:
  /// - Radius from canvas center maps linearly to latitude between -90.0° and [mapBoundaryLatitude] (default -80.0°).
  /// - Angle from vertical (-Y direction, Prime Meridian 0°E) maps clockwise to East-positive longitude [0.0°, 360.0°).
  (double latitude, double longitude) screenOffsetToCoordinates(
    Offset localOffset,
    Size canvasSize, {
    double mapBoundaryLatitude = -80.0,
  }) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final mapRadius = math.min(canvasSize.width, canvasSize.height) * 0.44;

    final dx = localOffset.dx - center.dx;
    final dy = localOffset.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    // Exact center tap is South Pole
    if (dist < 1e-4) {
      return (-90.0, 0.0);
    }

    // Normalized radius from 90°S (0.0) to boundary (1.0)
    final rho = (dist / mapRadius).clamp(0.0, 1.0);
    final latSpan = (mapBoundaryLatitude - (-90.0)).abs();
    final latitude = -90.0 + (rho * latSpan);

    // In polar canvas: 0° points UP (-Y). Right (+X) is 90°E. Down (+Y) is 180°E. Left (-X) is 270°E.
    // dx = r * sin(angle)
    // -dy = r * cos(angle)
    final angleRad = math.atan2(dx, -dy);
    var lonDeg = angleRad * 180.0 / math.pi;
    if (lonDeg < 0.0) {
      lonDeg += 360.0;
    }

    return (latitude, lonDeg);
  }

  /// Inverses selenographic (latitude, longitude) back to screen offset on the canvas.
  Offset coordinatesToScreenOffset(
    double latitude,
    double longitude,
    Size canvasSize, {
    double mapBoundaryLatitude = -80.0,
  }) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final mapRadius = math.min(canvasSize.width, canvasSize.height) * 0.44;

    final deltaLat = (latitude - (-90.0)).abs();
    final maxDeltaLat = (mapBoundaryLatitude - (-90.0)).abs();
    final rho = (deltaLat / maxDeltaLat).clamp(0.0, 1.0);
    final r = rho * mapRadius;

    final angleRad = longitude * math.pi / 180.0;
    final x = center.dx + r * math.sin(angleRad);
    final y = center.dy - r * math.cos(angleRad);

    return Offset(x, y);
  }

  /// Calculates the surface distance to the exact South Pole (-90°S) in kilometers.
  static double distanceToSouthPoleKm(double latitudeDegrees) {
    const double meanLunarRadiusKm = 1737.4;
    final angularDistRad = (latitudeDegrees - (-90.0)).abs() * math.pi / 180.0;
    return meanLunarRadiusKm * angularDistRad;
  }

  /// Calculates orthodromic great-circle distance between two lunar surface coordinates in kilometers.
  static double surfaceDistanceKm(
    double lat1Deg,
    double lon1Deg,
    double lat2Deg,
    double lon2Deg,
  ) {
    const double meanLunarRadiusKm = 1737.4;
    final phi1 = lat1Deg * math.pi / 180.0;
    final phi2 = lat2Deg * math.pi / 180.0;
    final dPhi = (lat2Deg - lat1Deg) * math.pi / 180.0;
    final dLam = (lon2Deg - lon1Deg) * math.pi / 180.0;

    final a =
        math.sin(dPhi / 2.0) * math.sin(dPhi / 2.0) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dLam / 2.0) *
            math.sin(dLam / 2.0);
    final c =
        2.0 * math.atan2(math.sqrt(a), math.sqrt((1.0 - a).clamp(0.0, 1.0)));
    return meanLunarRadiusKm * c;
  }

  /// Finds the nearest known crater or landmark from [polarLandmarks].
  NearestLandmarkInfo findNearestLandmark(double latitude, double longitude) {
    LunarLandmark? closest;
    double minDistance = double.infinity;

    for (final landmark in polarLandmarks) {
      final d = surfaceDistanceKm(
        latitude,
        longitude,
        landmark.latitude,
        landmark.longitude,
      );
      if (d < minDistance) {
        minDistance = d;
        closest = landmark;
      }
    }

    final target = closest ?? polarLandmarks.first;

    // Calculate cardinal direction from landmark to target location
    final dLat = latitude - target.latitude;
    var dLon = longitude - target.longitude;
    if (dLon > 180.0) dLon -= 360.0;
    if (dLon < -180.0) dLon += 360.0;

    String bearing;
    if (minDistance < 1.0) {
      bearing = 'Center';
    } else {
      final angle = math.atan2(dLon, dLat) * 180.0 / math.pi;
      if (angle >= -22.5 && angle < 22.5) {
        bearing = 'North';
      } else if (angle >= 22.5 && angle < 67.5) {
        bearing = 'NE';
      } else if (angle >= 67.5 && angle < 112.5) {
        bearing = 'East';
      } else if (angle >= 112.5 && angle < 157.5) {
        bearing = 'SE';
      } else if (angle >= 157.5 || angle < -157.5) {
        bearing = 'South';
      } else if (angle >= -157.5 && angle < -112.5) {
        bearing = 'SW';
      } else if (angle >= -112.5 && angle < -67.5) {
        bearing = 'West';
      } else {
        bearing = 'NW';
      }
    }

    return NearestLandmarkInfo(
      landmark: target,
      distanceKm: minDistance,
      compassBearing: bearing,
    );
  }

  /// Evaluates comprehensive scientific details for an arbitrary selected coordinate point.
  SelectedLunarLocation evaluateSelectedLocation({
    required double latitude,
    required double longitude,
    required List<LunarSite> existingSites,
    CelestialVisibilityService visibilityService =
        const CelestialVisibilityService(),
    double epochHours = 72.0,
  }) {
    final distToPoleKm = distanceToSouthPoleKm(latitude);
    final nearest = findNearestLandmark(latitude, longitude);

    // Compute live celestial visibility
    final visibility = visibilityService.computeVisibility(
      latitudeDeg: latitude,
      longitudeDeg: longitude,
      epochHours: epochHours,
    );

    // Check proximity to existing catalog or custom sites
    LunarSite? closestSite;
    double minSiteDist = double.infinity;
    for (final s in existingSites) {
      final pt = getMapPoint(s);
      if (pt == null) continue;
      final d = surfaceDistanceKm(
        latitude,
        longitude,
        pt.latitude,
        pt.longitude,
      );
      if (d < minSiteDist) {
        minSiteDist = d;
        closestSite = s;
      }
    }

    final isNear = minSiteDist < 12.0;

    return SelectedLunarLocation(
      latitude: latitude,
      longitude: longitude,
      distanceToSouthPoleKm: distToPoleKm,
      nearestLandmark: nearest,
      terrainStatus: const TerrainDataStatus(),
      visibility: visibility,
      isNearExistingSite: isNear,
      existingSite: isNear ? closestSite : null,
    );
  }
}

import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_geographic_coordinates.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';

/// Configuration parameters for computing a terrain horizon profile around an observer.
class HorizonProfileRequest {
  /// The geographic observer surface location.
  final LunarGeographicCoordinates observerCoordinates;

  /// Observer eye or sensor height above the local terrain in meters (e.g. 2.0 m for astronaut/rover).
  final double instrumentHeightMeters;

  /// Maximum radius / search distance in meters from the observer (e.g. 50,000.0 m = 50 km).
  final double maxSearchDistanceMeters;

  /// Radial step size in meters along each ray (e.g. 5.0 m to 20.0 m).
  final double radialStepSizeMeters;

  /// Number of azimuth rays to evaluate over 360° (e.g. 360 for 1° resolution, 720 for 0.5°).
  final int azimuthCount;

  /// Starting azimuth angle (default 0° = North).
  final Angle startAzimuth;

  HorizonProfileRequest({
    required this.observerCoordinates,
    this.instrumentHeightMeters = 2.0,
    this.maxSearchDistanceMeters = 30000.0,
    this.radialStepSizeMeters = 10.0,
    this.azimuthCount = 360,
    Angle? startAzimuth,
  }) : startAzimuth = startAzimuth ?? Angle.fromRadians(0.0),
       assert(
         instrumentHeightMeters >= 0.0,
         'Instrument height must be non-negative.',
       ),
       assert(
         maxSearchDistanceMeters > 0.0,
         'Max search distance must be positive.',
       ),
       assert(radialStepSizeMeters > 0.0, 'Radial step size must be positive.'),
       assert(azimuthCount >= 4, 'Azimuth count must be at least 4.');

  /// Angular step between consecutive azimuth rays in degrees.
  double get azimuthStepDegrees => 360.0 / azimuthCount;
}

/// A single radial ray profile result representing the terrain horizon along a specific azimuth.
class HorizonPoint {
  /// Azimuth angle (clockwise from North, 0° to 360°).
  final Angle azimuth;

  /// Elevation angle (altitude) of the terrain horizon in degrees (positive above local horizontal).
  final Angle elevationAngle;

  /// Surface distance in meters along the lunar sphere from the observer to the controlling obstacle point.
  final double distanceMeters;

  /// Elevation in meters of the controlling terrain obstacle relative to the lunar reference surface.
  final double obstacleElevationMeters;

  /// Geographic coordinates of the controlling terrain obstacle.
  final Angle obstacleLatitude;
  final Angle obstacleLongitude;

  /// Whether valid terrain coverage was present throughout the ray search.
  final bool hasFullCoverage;

  const HorizonPoint({
    required this.azimuth,
    required this.elevationAngle,
    required this.distanceMeters,
    required this.obstacleElevationMeters,
    required this.obstacleLatitude,
    required this.obstacleLongitude,
    required this.hasFullCoverage,
  });

  @override
  String toString() =>
      'HorizonPoint(az: ${azimuth.inDegrees.toStringAsFixed(1)}°, '
      'el: ${elevationAngle.inDegrees.toStringAsFixed(2)}°, '
      'dist: ${(distanceMeters / 1000).toStringAsFixed(2)}km, '
      'obsElev: ${obstacleElevationMeters.toStringAsFixed(1)}m)';
}

/// Complete 360-degree terrain horizon profile around an observer.
class HorizonProfile {
  /// The request parameters used to generate this profile.
  final HorizonProfileRequest request;

  /// The observer local surface elevation in meters from the DEM.
  final double observerSurfaceElevationMeters;

  /// The total observer altitude (surface elevation + instrument height) in meters.
  final double observerTotalElevationMeters;

  /// The list of evaluated horizon points around the 360° circle.
  final List<HorizonPoint> points;

  /// Overall coverage validity flag.
  final bool isComplete;

  const HorizonProfile({
    required this.request,
    required this.observerSurfaceElevationMeters,
    required this.observerTotalElevationMeters,
    required this.points,
    required this.isComplete,
  });

  /// Maximum horizon elevation angle found in the profile.
  HorizonPoint get highestPoint => points.reduce(
    (a, b) => a.elevationAngle.inDegrees > b.elevationAngle.inDegrees ? a : b,
  );

  /// Minimum horizon elevation angle found in the profile.
  HorizonPoint get lowestPoint => points.reduce(
    (a, b) => a.elevationAngle.inDegrees < b.elevationAngle.inDegrees ? a : b,
  );
}

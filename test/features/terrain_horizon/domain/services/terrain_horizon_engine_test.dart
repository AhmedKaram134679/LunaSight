import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/coordinate_conventions.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_geographic_coordinates.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/reference_surface_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/reference_frame_id.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/elevation_sample.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/horizon_profile.dart';
import 'package:luna_sight/features/terrain_horizon/domain/services/terrain_horizon_engine.dart';

/// Synthetic test terrain provider that simulates mathematical surfaces.
class SyntheticTerrainProvider implements TerrainDataProvider {
  final double Function(double latDeg, double lonDeg) elevationFn;
  final double radius;

  SyntheticTerrainProvider(this.elevationFn, {this.radius = 1737400.0});

  @override
  double get sphereRadiusMeters => radius;

  @override
  ElevationSample getElevation(Angle latitude, Angle longitude) {
    final elev = elevationFn(latitude.inDegrees, longitude.inDegrees);
    return ElevationSample(
      elevationMeters: elev,
      status: ElevationSampleStatus.valid,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

LunarGeographicCoordinates createTestObserver({
  required double latitudeDeg,
  required double longitudeDeg,
  double heightMeters = 0.0,
}) {
  return LunarGeographicCoordinates(
    latitude: Angle.fromDegrees(latitudeDeg),
    latitudeType: LatitudeType.planetocentric,
    longitude: Angle.fromDegrees(longitudeDeg),
    longitudeDirection: LongitudeDirection.eastPositive,
    longitudeDomain: LongitudeDomain.symmetric180,
    heightMeters: heightMeters,
    heightReference: HeightReferenceId.sphereRelative,
    frame: ReferenceFrameId.moonMeDe421,
  );
}

void main() {
  group('TerrainHorizonEngine Geometric & Analytical Tests', () {
    test('Flat sphere horizon dip matches analytical formula theta = -sqrt(2h/R)', () {
      // For a smooth lunar sphere (R = 1,737,400 m) with constant 0m elevation:
      // An observer at instrument height h above the surface will see the horizon below horizontal.
      // Analytically: sin(dip) = sqrt(2*R*h + h^2) / (R + h) ~ sqrt(2h/R)
      // For h = 10 m:
      // dip ~ sqrt(20 / 1,737,400) = sqrt(1.151145e-5) ~ 0.00339285 rad ~ 0.1944 deg (~ -0.1944 deg elevation).
      final flatMoonProvider = SyntheticTerrainProvider((lat, lon) => 0.0);
      final engine = TerrainHorizonEngine(terrainProvider: flatMoonProvider);

      final observer = createTestObserver(
        latitudeDeg: -89.9,
        longitudeDeg: 0.0,
        heightMeters: 0.0,
      );

      final request = HorizonProfileRequest(
        observerCoordinates: observer,
        instrumentHeightMeters: 10.0,
        maxSearchDistanceMeters: 20000.0, // 20 km horizon search
        azimuthCount: 4, // 4 cardinal directions
        radialStepSizeMeters: 100.0,
      );

      final profile = engine.calculateHorizon(request);

      expect(profile.points.length, 4);
      final expectedDipDeg =
          -math.sqrt(2 * 10.0 / 1737400.0) * (180.0 / math.pi);

      for (final pt in profile.points) {
        expect(
          pt.elevationAngle.inDegrees,
          closeTo(expectedDipDeg, 0.02),
          reason:
              'Azimuth ${pt.azimuth.inDegrees}° dip should match analytical curvature dip',
        );
      }
    });

    test('Isolated obstacle produces exact line-of-sight elevation angle', () {
      // Place observer at South Pole (-90°), R = 1,737,400 m, h = 0 m.
      // Place an obstacle of height H = 500 m along the meridian (lon = 0°) at distance d = 5,000 m.
      // Relative vector: ground distance d = 5000 m -> angular separation theta = 5000 / 1737400 rad.
      // In flat approximation (d << R):
      // Delta-h_curvature ~ d^2 / (2R) = 25,000,000 / 3,474,800 ~ 7.19 m.
      // Effective height ~ 500 - 7.19 = 492.81 m.
      // Elevation angle ~ atan(492.81 / 5000) ~ 5.629°
      final rMoon = 1737400.0;
      final targetDistanceMeters = 5000.0;
      final targetAngularDistRad = targetDistanceMeters / rMoon;
      final targetLatDeg = -90.0 + (targetAngularDistRad * 180.0 / math.pi);

      final obstacleProvider = SyntheticTerrainProvider((lat, lon) {
        // Obstacle at targetLatDeg +/- 0.002 deg, lon ~ 0 deg
        if ((lat - targetLatDeg).abs() < 0.002 &&
            (lon < 2.0 || lon > 358.0 || lon.abs() < 2.0)) {
          return 500.0;
        }
        return 0.0;
      });

      final engine = TerrainHorizonEngine(terrainProvider: obstacleProvider);

      final observer = createTestObserver(
        latitudeDeg: -90.0,
        longitudeDeg: 0.0,
        heightMeters: 0.0,
      );

      final request = HorizonProfileRequest(
        observerCoordinates: observer,
        instrumentHeightMeters: 0.0,
        maxSearchDistanceMeters: 10000.0,
        azimuthCount: 12,
        radialStepSizeMeters: 50.0,
      );

      final profile = engine.calculateHorizon(request);

      final northPoint = profile.points.firstWhere(
        (p) => p.azimuth.inDegrees.abs() < 1e-3,
      );

      expect(northPoint.elevationAngle.inDegrees, greaterThan(5.0));
      expect(northPoint.elevationAngle.inDegrees, lessThan(6.0));
      expect(northPoint.distanceMeters, closeTo(5000.0, 100.0));
    });

    test(
      'Closer obstacle occludes farther taller obstacle when angle is greater',
      () {
        // Closer obstacle: distance 1000 m, height 200 m -> angle ~ atan(200/1000) ~ 11.3°
        // Farther obstacle: distance 5000 m, height 400 m -> angle ~ atan(400/5000) ~ 4.5°
        // The horizon angle must be ~11.3° from the closer obstacle.
        final rMoon = 1737400.0;
        final d1 = 1000.0;
        final d2 = 5000.0;
        final lat1 = -90.0 + (d1 / rMoon) * (180.0 / math.pi);
        final lat2 = -90.0 + (d2 / rMoon) * (180.0 / math.pi);

        final twoPeakProvider = SyntheticTerrainProvider((lat, lon) {
          if ((lat - lat1).abs() < 0.001) return 200.0;
          if ((lat - lat2).abs() < 0.001) return 400.0;
          return 0.0;
        });

        final engine = TerrainHorizonEngine(terrainProvider: twoPeakProvider);
        final observer = createTestObserver(
          latitudeDeg: -90.0,
          longitudeDeg: 0.0,
          heightMeters: 0.0,
        );

        final request = HorizonProfileRequest(
          observerCoordinates: observer,
          instrumentHeightMeters: 0.0,
          maxSearchDistanceMeters: 8000.0,
          azimuthCount: 4,
          radialStepSizeMeters: 50.0,
        );

        final profile = engine.calculateHorizon(request);
        final northPoint = profile.points.firstWhere(
          (p) => p.azimuth.inDegrees.abs() < 1e-3,
        );

        expect(northPoint.elevationAngle.inDegrees, closeTo(11.3, 0.5));
        expect(northPoint.distanceMeters, closeTo(1000.0, 100.0));
      },
    );

    test('Increasing instrument height decreases the perceived terrain elevation angle', () {
      // With obstacle at 2000m of height 100m:
      // At h = 0m, angle ~ atan(100/2000) ~ 2.86°
      // At h = 50m, angle ~ atan(50/2000) ~ 1.43°
      final rMoon = 1737400.0;
      final d = 2000.0;
      final latTarget = -90.0 + (d / rMoon) * (180.0 / math.pi);

      final peakProvider = SyntheticTerrainProvider((lat, lon) {
        if ((lat - latTarget).abs() < 0.001) return 100.0;
        return 0.0;
      });

      final engine = TerrainHorizonEngine(terrainProvider: peakProvider);
      final observer = createTestObserver(
        latitudeDeg: -90.0,
        longitudeDeg: 0.0,
        heightMeters: 0.0,
      );

      final req0 = HorizonProfileRequest(
        observerCoordinates: observer,
        instrumentHeightMeters: 0.0,
        maxSearchDistanceMeters: 4000.0,
        azimuthCount: 4,
        radialStepSizeMeters: 50.0,
      );

      final req50 = HorizonProfileRequest(
        observerCoordinates: observer,
        instrumentHeightMeters: 50.0,
        maxSearchDistanceMeters: 4000.0,
        azimuthCount: 4,
        radialStepSizeMeters: 50.0,
      );

      final p0 = engine.calculateHorizon(req0);
      final p50 = engine.calculateHorizon(req50);

      final pt0 = p0.points.firstWhere((p) => p.azimuth.inDegrees.abs() < 1e-3);
      final pt50 = p50.points.firstWhere(
        (p) => p.azimuth.inDegrees.abs() < 1e-3,
      );

      expect(
        pt0.elevationAngle.inDegrees,
        greaterThan(pt50.elevationAngle.inDegrees),
      );
      expect(pt0.elevationAngle.inDegrees, closeTo(2.86, 0.2));
      expect(pt50.elevationAngle.inDegrees, closeTo(1.43, 0.2));
    });
  });
}

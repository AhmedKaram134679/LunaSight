import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/coordinate_conventions.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_geographic_coordinates.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/reference_surface_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/distance.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/reference_frame_id.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/elevation_sample.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/horizon_profile.dart';
import 'package:luna_sight/features/terrain_horizon/domain/services/terrain_horizon_engine.dart';

/// Synthetic test terrain provider that simulates mathematical surfaces.
class SyntheticTerrainProvider implements TerrainDataProvider {
  final double Function(double latDeg, double lonDeg) elevationFn;
  final ElevationSampleStatus Function(double latDeg, double lonDeg)? statusFn;
  final double radius;

  SyntheticTerrainProvider(
    this.elevationFn, {
    this.statusFn,
    this.radius = 1737400.0,
  });

  @override
  double get sphereRadiusMeters => radius;

  @override
  ElevationSample getElevation(Angle latitude, Angle longitude) {
    final status = statusFn != null
        ? statusFn!(latitude.inDegrees, longitude.inDegrees)
        : ElevationSampleStatus.validBilinear;
    final elev = status.isValid
        ? elevationFn(latitude.inDegrees, longitude.inDegrees)
        : double.nan;
    return ElevationSample(
      elevationMeters: elev,
      status: status,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

LunarGeographicCoordinates createTestObserver({
  required double latitudeDeg,
  required double longitudeDeg,
  double heightMeters = 0.0,
  HeightReferenceId? heightReference,
}) {
  return LunarGeographicCoordinates(
    latitude: Angle.fromDegrees(latitudeDeg),
    latitudeType: LatitudeType.planetocentric,
    longitude: Angle.fromDegrees(longitudeDeg),
    longitudeDirection: LongitudeDirection.eastPositive,
    longitudeDomain: LongitudeDomain.symmetric180,
    heightMeters: heightMeters,
    heightReference: heightReference ?? HeightReferenceId.sphereRelative,
    frame: ReferenceFrameId.moonMeDe421,
  );
}

void main() {
  group('TerrainHorizonEngine Geometric & Analytical Tests', () {
    test('Flat sphere horizon dip matches analytical formula theta = -sqrt(2h/R)', () {
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
      final rMoon = 1737400.0;
      final targetDistanceMeters = 5000.0;
      final targetAngularDistRad = targetDistanceMeters / rMoon;
      final targetLatDeg = -90.0 + (targetAngularDistRad * 180.0 / math.pi);

      final obstacleProvider = SyntheticTerrainProvider((lat, lon) {
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

  group('TerrainHorizonEngine Observer Terrain Validity & Height Semantics (Audit A)', () {
    test('Throws ScientificComputationException with OBSERVER_TERRAIN_OUTSIDE_COVERAGE when observer is outside coverage', () {
      final outsideProvider = SyntheticTerrainProvider(
        (lat, lon) => 0.0,
        statusFn: (lat, lon) => ElevationSampleStatus.outsideCoverage,
      );
      final engine = TerrainHorizonEngine(terrainProvider: outsideProvider);

      final observer = createTestObserver(
        latitudeDeg: -80.0,
        longitudeDeg: 0.0,
      );

      final req = HorizonProfileRequest(
        observerCoordinates: observer,
        maxSearchDistanceMeters: 5000.0,
      );

      expect(
        () => engine.calculateHorizon(req),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'OBSERVER_TERRAIN_OUTSIDE_COVERAGE',
          ),
        ),
      );
    });

    test('Throws ScientificComputationException with OBSERVER_TERRAIN_NODATA when observer falls on NoData', () {
      final noDataProvider = SyntheticTerrainProvider(
        (lat, lon) => 0.0,
        statusFn: (lat, lon) => ElevationSampleStatus.noData,
      );
      final engine = TerrainHorizonEngine(terrainProvider: noDataProvider);

      final observer = createTestObserver(
        latitudeDeg: -89.5,
        longitudeDeg: 10.0,
      );

      final req = HorizonProfileRequest(
        observerCoordinates: observer,
        maxSearchDistanceMeters: 5000.0,
      );

      expect(
        () => engine.calculateHorizon(req),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'OBSERVER_TERRAIN_NODATA',
          ),
        ),
      );
    });

    test('Correctly combines observer DEM surface elevation with instrument height exactly once', () {
      // Surface elevation: 1200.0 m. Instrument height: 2.5 m.
      // Total observer height: 1202.5 m.
      final provider = SyntheticTerrainProvider((lat, lon) => 1200.0);
      final engine = TerrainHorizonEngine(terrainProvider: provider);

      final observer = createTestObserver(
        latitudeDeg: -89.9,
        longitudeDeg: 0.0,
      );

      final req = HorizonProfileRequest(
        observerCoordinates: observer,
        instrumentHeightMeters: 2.5,
        maxSearchDistanceMeters: 2000.0,
        azimuthCount: 4,
      );

      final profile = engine.calculateHorizon(req);
      expect(profile.observerSurfaceElevationMeters, closeTo(1200.0, 1e-4));
      expect(profile.observerTotalElevationMeters, closeTo(1202.5, 1e-4));
    });

    test('Rejects incompatible height reference on observer coordinates at construction', () {
      final customSurface = ReferenceSurfaceId(
        name: 'CUSTOM_SPHERE',
        equatorialRadius: Distance.fromMeters(1738000.0),
        polarRadius: Distance.fromMeters(1738000.0),
      );
      final customHeightRef = HeightReferenceId(
        name: 'CUSTOM_DATUM',
        referenceSurface: customSurface,
      );

      expect(
        () => createTestObserver(
          latitudeDeg: -89.9,
          longitudeDeg: 0.0,
          heightReference: customHeightRef,
        ),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'INCOMPATIBLE_HEIGHT_REFERENCE',
          ),
        ),
      );
    });
  });

  group('TerrainHorizonEngine Polar Azimuth Frame Consistency (Audit B)', () {
    test('Polar cardinal azimuths follow deterministic basis regardless of observer longitude representation', () {
      // At South Pole (-90°), any longitude represents the same geometric pole.
      // Verify that Az 0° targets along prime meridian (lon 0°),
      // Az 90° targets along lon +90°,
      // Az 180° targets along lon 180°,
      // Az 270° targets along lon -90° (+270°).
      // Even if observer has longitude 0°, 45°, or 120°!
      for (final obsLon in [0.0, 45.0, 120.0, -90.0]) {
        // Place an isolated obstacle at Az 90° (which corresponds to meridian +90°E at South Pole)
        final obstacleDist = 4000.0;
        final targetAngularDistRad = obstacleDist / 1737400.0;
        final targetLatDeg = -90.0 + (targetAngularDistRad * 180.0 / math.pi);

        final eastObstacleProvider = SyntheticTerrainProvider((lat, lon) {
          // Peak on +90° meridian
          if ((lat - targetLatDeg).abs() < 0.002 && (lon - 90.0).abs() < 2.0) {
            return 300.0;
          }
          return 0.0;
        });

        final engine = TerrainHorizonEngine(
          terrainProvider: eastObstacleProvider,
        );
        final observer = createTestObserver(
          latitudeDeg: -90.0,
          longitudeDeg: obsLon,
        );

        final req = HorizonProfileRequest(
          observerCoordinates: observer,
          instrumentHeightMeters: 0.0,
          maxSearchDistanceMeters: 8000.0,
          azimuthCount: 4, // 0°, 90°, 180°, 270°
          radialStepSizeMeters: 50.0,
        );

        final profile = engine.calculateHorizon(req);

        final ptNorth = profile.points.firstWhere(
          (p) => p.azimuth.inDegrees == 0.0,
        );
        final ptEast = profile.points.firstWhere(
          (p) => p.azimuth.inDegrees == 90.0,
        );
        final ptSouth = profile.points.firstWhere(
          (p) => p.azimuth.inDegrees == 180.0,
        );
        final ptWest = profile.points.firstWhere(
          (p) => p.azimuth.inDegrees == 270.0,
        );

        // East ray (Az 90°) must detect the peak on +90° meridian
        expect(
          ptEast.elevationAngle.inDegrees,
          greaterThan(3.5),
          reason:
              'Azimuth 90° must detect the obstacle on lon +90° regardless of observer lon $obsLon°',
        );
        expect(ptEast.distanceMeters, closeTo(4000.0, 100.0));

        // North, South, West rays should see flat baseline (~0.0m dip)
        expect(ptNorth.elevationAngle.inDegrees, lessThan(0.1));
        expect(ptSouth.elevationAngle.inDegrees, lessThan(0.1));
        expect(ptWest.elevationAngle.inDegrees, lessThan(0.1));
      }
    });
  });
}

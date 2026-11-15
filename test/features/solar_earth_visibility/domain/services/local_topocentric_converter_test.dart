import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/coordinate_conventions.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_geographic_coordinates.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/reference_surface_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/coordinate_origin_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/framed_vector3.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/reference_frame_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/vector3.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/vector_unit.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/astronomical_time.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/celestial_vector.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/leap_second_provider.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/local_horizon_basis.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/time_scale.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/services/local_topocentric_converter.dart';

void main() {
  group('Milestone 02 Audit Tests — LeapSecondProvider & AstronomicalTime', () {
    const provider = LeapSecondProvider();

    test('Audit A: LeapSecondProvider contains exactly 28 entries (epoch + 27 step increments)', () {
      expect(LeapSecondProvider.leapSecondIncrementCount, 27);
      expect(LeapSecondProvider.currentConfirmedOffsetSeconds, 37);

      // Initial epoch: 1972-01-01 -> 10s
      expect(provider.getTaiMinusUtcSeconds(DateTime.utc(1972, 1, 1)), 10);

      // 2017-01-01 -> 37s
      expect(provider.getTaiMinusUtcSeconds(DateTime.utc(2017, 1, 1)), 37);
    });

    test('Audit B: Strict default extrapolation policy rejects unconfirmed future dates', () {
      final futureDate = DateTime.utc(2030, 1, 1);

      // Strict mode (default allowExtrapolation = false):
      expect(
        () => provider.getTaiMinusUtcSeconds(futureDate),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'TIME_SCALE_UNCONFIRMED_FUTURE',
          ),
        ),
      );

      // Explicit forward planning (allowExtrapolation = true):
      expect(
        provider.getTaiMinusUtcSeconds(futureDate, allowExtrapolation: true),
        37,
      );
    });

    test(
      'Audit C: TDB - TT approximation accuracy and J2000 epoch continuity',
      () {
        // At J2000.0 (T = 0):
        // g = 357.53 deg. gRad = 357.53 * pi / 180 = 6.24008 rad
        // TDB - TT = 0.001657 * sin(g + 0.0167*sin(g)) ~ -0.0000726s = -72.6 microseconds
        final j2000Utc = DateTime.utc(2000, 1, 1, 12, 0, 0);
        final tUtc = AstronomicalTime.fromUtcDateTime(j2000Utc);
        final tTT = tUtc.toTerrestrialTime();
        final tTDB = tUtc.toBarycentricDynamicalTime();

        final diffSeconds = tTDB.differenceInSeconds(tTT);
        expect(diffSeconds, closeTo(-7.26e-5, 1e-6));
        expect(diffSeconds.abs(), lessThan(0.0017));
      },
    );
  });

  group('Milestone 03: LocalHorizonBasis Tests', () {
    test('Basis vectors are unit length and mutually orthogonal across diverse coordinates', () {
      final testCoords = [
        (0.0, 0.0), // Equator at Prime Meridian
        (45.0, 60.0), // Mid-latitude
        (-89.9, 0.0), // Near South Pole
        (-90.0, 0.0), // Exact South Pole Prime Meridian
        (-90.0, 45.0), // Exact South Pole 45 deg Meridian
        (90.0, 0.0), // Exact North Pole
      ];

      for (final (latDeg, lonDeg) in testCoords) {
        final basis = LocalHorizonBasis.fromCoordinates(
          latitude: Angle.fromDegrees(latDeg),
          longitude: Angle.fromDegrees(lonDeg),
        );

        // Unit lengths (scaled magnitude):
        expect(basis.north.magnitude, closeTo(1.0, 1e-12));
        expect(basis.east.magnitude, closeTo(1.0, 1e-12));
        expect(basis.zenith.magnitude, closeTo(1.0, 1e-12));
        expect(basis.south.magnitude, closeTo(1.0, 1e-12));

        // Mutual orthogonality:
        expect(basis.north.dot(basis.east).abs(), lessThan(1e-12));
        expect(basis.north.dot(basis.zenith).abs(), lessThan(1e-12));
        expect(basis.east.dot(basis.zenith).abs(), lessThan(1e-12));

        // Right-handedness in SEZ: S x E = Z
        final crossSE = basis.south.cross(basis.east);
        expect((crossSE - basis.zenith).magnitude, lessThan(1e-12));
      }
    });

    test(
      'Exact South Pole Prime Meridian convention matches specification',
      () {
        final basis = LocalHorizonBasis.fromCoordinates(
          latitude: Angle.fromDegrees(-90.0),
          longitude: Angle.fromDegrees(0.0),
        );

        // At South Pole (phi = -90 deg, lam = 0 deg):
        // Zenith = (0, 0, -1)
        // North = (1, 0, 0)
        // East = (0, 1, 0)
        expect(basis.zenith.x, closeTo(0.0, 1e-12));
        expect(basis.zenith.y, closeTo(0.0, 1e-12));
        expect(basis.zenith.z, closeTo(-1.0, 1e-12));

        expect(basis.north.x, closeTo(1.0, 1e-12));
        expect(basis.north.y, closeTo(0.0, 1e-12));
        expect(basis.north.z, closeTo(0.0, 1e-12));

        expect(basis.east.x, closeTo(0.0, 1e-12));
        expect(basis.east.y, closeTo(1.0, 1e-12));
        expect(basis.east.z, closeTo(0.0, 1e-12));
      },
    );
  });

  group('Milestone 03: LocalTopocentricConverter Tests', () {
    const converter = LocalTopocentricConverter();
    final epoch = AstronomicalTime.fromJulianDate(
      2451545.0,
      scale: TimeScale.tdb,
    );
    const rMoon = 1737400.0;

    LunarGeographicCoordinates makeCoords(double lat, double lon) {
      return LunarGeographicCoordinates(
        latitude: Angle.fromDegrees(lat),
        latitudeType: LatitudeType.planetocentric,
        longitude: Angle.fromDegrees(lon),
        longitudeDirection: LongitudeDirection.eastPositive,
        longitudeDomain: LongitudeDomain.symmetric180,
        heightMeters: 0.0,
        heightReference: HeightReferenceId.sphereRelative,
        frame: ReferenceFrameId.moonMeDe421,
      );
    }

    test(
      'Transforms cardinal directions accurately at South Pole observer',
      () {
        final obsCoords = makeCoords(-90.0, 0.0);

        // Observer at (0, 0, -R)
        final obsVector = CelestialVector(
          position: FramedVector3(
            vector: Vector3(0.0, 0.0, -rMoon),
            frame: ReferenceFrameId.moonMeDe421,
            origin: CoordinateOriginId.moonCenterOfMass,
            unit: VectorUnit.meters,
          ),
          epoch: epoch,
        );

        // 1. Target due North: rho = (+10000, 0, 0)
        final targetNorth = CelestialVector(
          position: FramedVector3(
            vector: Vector3(10000.0, 0.0, -rMoon),
            frame: ReferenceFrameId.moonMeDe421,
            origin: CoordinateOriginId.moonCenterOfMass,
            unit: VectorUnit.meters,
          ),
          epoch: epoch,
        );

        final topoNorth = converter.toTopocentric(
          targetVector: targetNorth,
          observerVector: obsVector,
          observerCoordinates: obsCoords,
        );
        expect(topoNorth.azimuth!.inDegrees, closeTo(0.0, 1e-6));
        expect(topoNorth.elevation.inDegrees, closeTo(0.0, 1e-6));
        expect(topoNorth.slantRangeMeters, closeTo(10000.0, 1e-6));
        expect(topoNorth.southMeters, closeTo(-10000.0, 1e-6));
        expect(topoNorth.eastMeters, closeTo(0.0, 1e-6));
        expect(topoNorth.zenithMeters, closeTo(0.0, 1e-6));

        // 2. Target due East: rho = (0, +10000, 0)
        final targetEast = CelestialVector(
          position: FramedVector3(
            vector: Vector3(0.0, 10000.0, -rMoon),
            frame: ReferenceFrameId.moonMeDe421,
            origin: CoordinateOriginId.moonCenterOfMass,
            unit: VectorUnit.meters,
          ),
          epoch: epoch,
        );

        final topoEast = converter.toTopocentric(
          targetVector: targetEast,
          observerVector: obsVector,
          observerCoordinates: obsCoords,
        );
        expect(topoEast.azimuth!.inDegrees, closeTo(90.0, 1e-6));
        expect(topoEast.elevation.inDegrees, closeTo(0.0, 1e-6));

        // 3. Target due South: rho = (-10000, 0, 0)
        final targetSouth = CelestialVector(
          position: FramedVector3(
            vector: Vector3(-10000.0, 0.0, -rMoon),
            frame: ReferenceFrameId.moonMeDe421,
            origin: CoordinateOriginId.moonCenterOfMass,
            unit: VectorUnit.meters,
          ),
          epoch: epoch,
        );

        final topoSouth = converter.toTopocentric(
          targetVector: targetSouth,
          observerVector: obsVector,
          observerCoordinates: obsCoords,
        );
        expect(topoSouth.azimuth!.inDegrees, closeTo(180.0, 1e-6));
        expect(topoSouth.elevation.inDegrees, closeTo(0.0, 1e-6));

        // 4. Target due West: rho = (0, -10000, 0)
        final targetWest = CelestialVector(
          position: FramedVector3(
            vector: Vector3(0.0, -10000.0, -rMoon),
            frame: ReferenceFrameId.moonMeDe421,
            origin: CoordinateOriginId.moonCenterOfMass,
            unit: VectorUnit.meters,
          ),
          epoch: epoch,
        );

        final topoWest = converter.toTopocentric(
          targetVector: targetWest,
          observerVector: obsVector,
          observerCoordinates: obsCoords,
        );
        expect(topoWest.azimuth!.inDegrees, closeTo(270.0, 1e-6));
        expect(topoWest.elevation.inDegrees, closeTo(0.0, 1e-6));

        // 5. Target at Zenith: rho = (0, 0, -50000) (away from Moon center)
        final targetZenith = CelestialVector(
          position: FramedVector3(
            vector: Vector3(0.0, 0.0, -rMoon - 50000.0),
            frame: ReferenceFrameId.moonMeDe421,
            origin: CoordinateOriginId.moonCenterOfMass,
            unit: VectorUnit.meters,
          ),
          epoch: epoch,
        );

        final topoZenith = converter.toTopocentric(
          targetVector: targetZenith,
          observerVector: obsVector,
          observerCoordinates: obsCoords,
        );
        expect(topoZenith.hasDefinedAzimuth, isFalse);
        expect(topoZenith.azimuth, isNull);
        expect(topoZenith.elevation.inDegrees, closeTo(90.0, 1e-6));
        expect(topoZenith.slantRangeMeters, closeTo(50000.0, 1e-6));

        // 6. Target at Nadir: rho = (0, 0, +50000) (towards Moon center)
        final targetNadir = CelestialVector(
          position: FramedVector3(
            vector: Vector3(0.0, 0.0, -rMoon + 50000.0),
            frame: ReferenceFrameId.moonMeDe421,
            origin: CoordinateOriginId.moonCenterOfMass,
            unit: VectorUnit.meters,
          ),
          epoch: epoch,
        );

        final topoNadir = converter.toTopocentric(
          targetVector: targetNadir,
          observerVector: obsVector,
          observerCoordinates: obsCoords,
        );
        expect(topoNadir.hasDefinedAzimuth, isFalse);
        expect(topoNadir.azimuth, isNull);
        expect(topoNadir.elevation.inDegrees, closeTo(-90.0, 1e-6));
        expect(topoNadir.slantRangeMeters, closeTo(50000.0, 1e-6));
      },
    );

    test(
      'Preserves range invariant: S^2 + E^2 + Z^2 = rho^2 for arbitrary angles',
      () {
        final obsCoords = makeCoords(-85.0, 30.0);

        final obsPos = Vector3(
          rMoon * math.cos(-85 * math.pi / 180) * math.cos(30 * math.pi / 180),
          rMoon * math.cos(-85 * math.pi / 180) * math.sin(30 * math.pi / 180),
          rMoon * math.sin(-85 * math.pi / 180),
        );

        final obsVector = CelestialVector(
          position: FramedVector3(
            vector: obsPos,
            frame: ReferenceFrameId.moonMeDe421,
            origin: CoordinateOriginId.moonCenterOfMass,
            unit: VectorUnit.meters,
          ),
          epoch: epoch,
        );

        final targetPos = Vector3(1.5e8, 2.5e8, -3.5e8);
        final targetVector = CelestialVector(
          position: FramedVector3(
            vector: targetPos,
            frame: ReferenceFrameId.moonMeDe421,
            origin: CoordinateOriginId.moonCenterOfMass,
            unit: VectorUnit.meters,
          ),
          epoch: epoch,
        );

        final topo = converter.toTopocentric(
          targetVector: targetVector,
          observerVector: obsVector,
          observerCoordinates: obsCoords,
        );

        final sumSq =
            topo.southMeters * topo.southMeters +
            topo.eastMeters * topo.eastMeters +
            topo.zenithMeters * topo.zenithMeters;
        final reconstructedSlant = math.sqrt(sumSq);

        expect(reconstructedSlant, closeTo(topo.slantRangeMeters, 1e-6));
      },
    );

    test('Rejects zero relative range and incompatible frames', () {
      final obsCoords = makeCoords(0.0, 0.0);

      final obsVector = CelestialVector(
        position: FramedVector3(
          vector: Vector3(rMoon, 0.0, 0.0),
          frame: ReferenceFrameId.moonMeDe421,
          origin: CoordinateOriginId.moonCenterOfMass,
          unit: VectorUnit.meters,
        ),
        epoch: epoch,
      );

      // 1. Zero relative range
      expect(
        () => converter.toTopocentric(
          targetVector: obsVector,
          observerVector: obsVector,
          observerCoordinates: obsCoords,
        ),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ZERO_RELATIVE_RANGE',
          ),
        ),
      );

      // 2. Incompatible frame
      final icrfTarget = CelestialVector(
        position: FramedVector3(
          vector: Vector3(rMoon + 100.0, 0.0, 0.0),
          frame: ReferenceFrameId.icrf,
          origin: CoordinateOriginId.moonCenterOfMass,
          unit: VectorUnit.meters,
        ),
        epoch: epoch,
      );

      expect(
        () => converter.toTopocentric(
          targetVector: icrfTarget,
          observerVector: obsVector,
          observerCoordinates: obsCoords,
        ),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'INCOMPATIBLE_REFERENCE_FRAME',
          ),
        ),
      );
    });
  });
}

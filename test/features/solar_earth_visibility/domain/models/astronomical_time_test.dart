import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/coordinate_origin_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/framed_vector3.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/reference_frame_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/vector3.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/vector_unit.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/astronomical_time.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/celestial_vector.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/leap_second_provider.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/time_scale.dart';

void main() {
  group('LeapSecondProvider Tests', () {
    const provider = LeapSecondProvider();

    test('Identifies standard historical leap second offsets correctly', () {
      // 1972-01-01 -> 10s
      expect(
        provider.getTaiMinusUtcSeconds(DateTime.utc(1972, 1, 1, 0, 0, 0)),
        10,
      );
      expect(
        provider.getTaiMinusUtcSeconds(DateTime.utc(1972, 6, 30, 23, 59, 59)),
        10,
      );

      // 1972-07-01 -> 11s
      expect(
        provider.getTaiMinusUtcSeconds(DateTime.utc(1972, 7, 1, 0, 0, 0)),
        11,
      );

      // 2000-01-01 (J2000 epoch) -> 32s
      expect(
        provider.getTaiMinusUtcSeconds(DateTime.utc(2000, 1, 1, 12, 0, 0)),
        32,
      );

      // 2012-07-01 -> 35s
      expect(
        provider.getTaiMinusUtcSeconds(DateTime.utc(2012, 7, 1, 0, 0, 0)),
        35,
      );

      // 2017-01-01 through 2026 -> 37s
      expect(
        provider.getTaiMinusUtcSeconds(DateTime.utc(2017, 1, 1, 0, 0, 0)),
        37,
      );
      expect(
        provider.getTaiMinusUtcSeconds(DateTime.utc(2024, 1, 1, 0, 0, 0)),
        37,
      );
      expect(
        provider.getTaiMinusUtcSeconds(DateTime.utc(2026, 11, 15, 0, 0, 0)),
        37,
      );
    });

    test(
      'Rejects UTC dates prior to modern leap second epoch (1972-01-01)',
      () {
        expect(
          () => provider.getTaiMinusUtcSeconds(
            DateTime.utc(1971, 12, 31, 23, 59, 59),
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'TIME_SCALE_OUT_OF_RANGE',
            ),
          ),
        );
      },
    );

    test('Rejects non-UTC DateTime instances', () {
      // Local time without UTC flag
      final nonUtc = DateTime(2024, 1, 1, 12, 0);
      if (!nonUtc.isUtc) {
        expect(
          () => provider.getTaiMinusUtcSeconds(nonUtc),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'TIME_SCALE_INVALID_TIMEZONE',
            ),
          ),
        );
      }
    });

    test('Enforces strict extrapolation flag past guaranteed horizon', () {
      final futureDate = DateTime.utc(2035, 1, 1);
      // Allowed when allowExtrapolation = true
      expect(
        provider.getTaiMinusUtcSeconds(futureDate, allowExtrapolation: true),
        37,
      );

      // Throws under strict default (allowExtrapolation = false)
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
    });
  });

  group('AstronomicalTime Core Model & Conversion Tests', () {
    test('Converts Gregorian UTC calendar date to Julian Date accurately', () {
      // J2000.0 epoch: 2000-01-01 12:00:00 UTC = JD 2451545.0 UTC
      final j2000Utc = DateTime.utc(2000, 1, 1, 12, 0, 0);
      final t = AstronomicalTime.fromUtcDateTime(j2000Utc);

      expect(t.scale, TimeScale.utc);
      expect(t.julianDate, closeTo(2451545.0, 1e-9));
      expect(t.julianCenturiesSinceJ2000, closeTo(0.0, 1e-12));

      // 1999-01-01 00:00:00 UTC = JD 2451179.5
      final d1999 = DateTime.utc(1999, 1, 1, 0, 0, 0);
      final t1999 = AstronomicalTime.fromUtcDateTime(d1999);
      expect(t1999.julianDate, closeTo(2451179.5, 1e-9));

      // 2024-01-01 00:00:00 UTC = JD 2460310.5
      final d2024 = DateTime.utc(2024, 1, 1, 0, 0, 0);
      final t2024 = AstronomicalTime.fromUtcDateTime(d2024);
      expect(t2024.julianDate, closeTo(2460310.5, 1e-9));
    });

    test('Round-trip identity: fromUtcDateTime -> toUtcDateTime preserves microsecond precision', () {
      final sampleDates = [
        DateTime.utc(2000, 1, 1, 12, 0, 0),
        DateTime.utc(2024, 7, 20, 15, 30, 45, 123, 456),
        DateTime.utc(2026, 11, 15, 23, 59, 59, 999),
      ];

      for (final original in sampleDates) {
        final astroTime = AstronomicalTime.fromUtcDateTime(original);
        final roundTripped = astroTime.toUtcDateTime();
        expect(
          roundTripped.difference(original).inMicroseconds.abs(),
          lessThanOrEqualTo(1),
          reason: 'Round-trip must preserve time within 1 microsecond',
        );
      }
    });

    test('Converts UTC to Terrestrial Time (TT) accounting for leap seconds and 32.184s offset', () {
      // 2000-01-01 12:00:00 UTC:
      // TAI - UTC = 32s. TT - TAI = 32.184s. Total offset = 64.184s.
      // 64.184s in days = 64.184 / 86400 = 0.00074287037037...
      // Expected JD_TT = 2451545.0 + 0.00074287037037... = 2451545.0007428704
      final tUtc = AstronomicalTime.fromUtcDateTime(
        DateTime.utc(2000, 1, 1, 12, 0, 0),
      );
      final tTT = tUtc.toTerrestrialTime();

      expect(tTT.scale, TimeScale.tt);
      expect(tTT.julianDate, closeTo(2451545.0 + 64.184 / 86400.0, 1e-9));

      // 2024-01-01 00:00:00 UTC:
      // TAI - UTC = 37s. Total offset = 37 + 32.184 = 69.184s.
      // Expected JD_TT = 2460310.5 + 69.184 / 86400.0
      final t2024Utc = AstronomicalTime.fromUtcDateTime(
        DateTime.utc(2024, 1, 1, 0, 0, 0),
      );
      final t2024TT = t2024Utc.toTerrestrialTime();
      expect(t2024TT.scale, TimeScale.tt);
      expect(t2024TT.julianDate, closeTo(2460310.5 + 69.184 / 86400.0, 1e-9));
    });

    test('Converts TT to Barycentric Dynamical Time (TDB) with bounded relativistic difference', () {
      final tUtc = AstronomicalTime.fromUtcDateTime(
        DateTime.utc(2024, 1, 1, 0, 0, 0),
      );
      final tTT = tUtc.toTerrestrialTime();
      final tTDB = tUtc.toBarycentricDynamicalTime();

      expect(tTDB.scale, TimeScale.tdb);

      // |TDB - TT| must be strictly bounded under 0.002 seconds (< 2 milliseconds)
      final diffSeconds = tTDB.differenceInSeconds(tTT);
      expect(diffSeconds.abs(), lessThan(0.002));
      expect(
        diffSeconds.abs(),
        greaterThan(0.00005),
      ); // Relativistic variation is nonzero
    });

    test('Rejects non-finite Julian Dates in factory constructor', () {
      expect(
        () => AstronomicalTime.fromJulianDate(double.nan, scale: TimeScale.tt),
        throwsA(isA<ScientificComputationException>()),
      );
      expect(
        () => AstronomicalTime.fromJulianDate(
          double.infinity,
          scale: TimeScale.tt,
        ),
        throwsA(isA<ScientificComputationException>()),
      );
    });
  });

  group('CelestialVector Contract & Invariant Tests', () {
    test('Constructs valid CelestialVector and preserves coordinate frame and origin', () {
      final epoch = AstronomicalTime.fromJulianDate(
        2451545.0,
        scale: TimeScale.tdb,
      );
      final pos = FramedVector3(
        vector: Vector3(1000.0, 2000.0, 3000.0),
        frame: ReferenceFrameId.moonMeDe421,
        origin: CoordinateOriginId.moonCenterOfMass,
        unit: VectorUnit.meters,
      );

      final cv = CelestialVector(position: pos, epoch: epoch);

      expect(cv.frame, ReferenceFrameId.moonMeDe421);
      expect(cv.origin, CoordinateOriginId.moonCenterOfMass);
      expect(cv.unit, VectorUnit.meters);
      expect(cv.vector.x, 1000.0);
    });

    test('Computes relative celestial position vector correctly between target and observer', () {
      final epoch = AstronomicalTime.fromJulianDate(
        2451545.0,
        scale: TimeScale.tdb,
      );

      // Sun at (1.5e11, 0, 0) m
      final target = CelestialVector(
        position: FramedVector3(
          vector: Vector3(1.5e11, 0.0, 0.0),
          frame: ReferenceFrameId.moonMeDe421,
          origin: CoordinateOriginId.moonCenterOfMass,
          unit: VectorUnit.meters,
        ),
        epoch: epoch,
      );

      // Lunar surface observer at (1.7374e6, 0, 0) m
      final observer = CelestialVector(
        position: FramedVector3(
          vector: Vector3(1.7374e6, 0.0, 0.0),
          frame: ReferenceFrameId.moonMeDe421,
          origin: CoordinateOriginId.moonCenterOfMass,
          unit: VectorUnit.meters,
        ),
        epoch: epoch,
      );

      final rel = target.relativePositionFrom(observer);

      expect(rel.frame, ReferenceFrameId.moonMeDe421);
      expect(rel.origin, CoordinateOriginId.moonCenterOfMass);
      expect(rel.unit, VectorUnit.meters);
      expect(rel.vector.x, closeTo(1.5e11 - 1.7374e6, 1e-4));
      expect(rel.vector.y, 0.0);
      expect(rel.vector.z, 0.0);
    });

    test(
      'Rejects relative vector calculation across differing reference frames',
      () {
        final epoch = AstronomicalTime.fromJulianDate(
          2451545.0,
          scale: TimeScale.tdb,
        );

        final target = CelestialVector(
          position: FramedVector3(
            vector: Vector3(100.0, 0.0, 0.0),
            frame: ReferenceFrameId.moonMeDe421,
            origin: CoordinateOriginId.moonCenterOfMass,
            unit: VectorUnit.meters,
          ),
          epoch: epoch,
        );

        final observer = CelestialVector(
          position: FramedVector3(
            vector: Vector3(10.0, 0.0, 0.0),
            frame: ReferenceFrameId.icrf,
            origin: CoordinateOriginId.moonCenterOfMass,
            unit: VectorUnit.meters,
          ),
          epoch: epoch,
        );

        expect(
          () => target.relativePositionFrom(observer),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'INCOMPATIBLE_REFERENCE_FRAME',
            ),
          ),
        );
      },
    );

    test(
      'Rejects relative vector calculation across differing coordinate origins',
      () {
        final epoch = AstronomicalTime.fromJulianDate(
          2451545.0,
          scale: TimeScale.tdb,
        );

        final target = CelestialVector(
          position: FramedVector3(
            vector: Vector3(100.0, 0.0, 0.0),
            frame: ReferenceFrameId.moonMeDe421,
            origin: CoordinateOriginId.moonCenterOfMass,
            unit: VectorUnit.meters,
          ),
          epoch: epoch,
        );

        final observer = CelestialVector(
          position: FramedVector3(
            vector: Vector3(10.0, 0.0, 0.0),
            frame: ReferenceFrameId.moonMeDe421,
            origin: CoordinateOriginId.earthCenterOfMass,
            unit: VectorUnit.meters,
          ),
          epoch: epoch,
        );

        expect(
          () => target.relativePositionFrom(observer),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'INCOMPATIBLE_COORDINATE_ORIGIN',
            ),
          ),
        );
      },
    );
  });
}

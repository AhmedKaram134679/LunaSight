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

    test(
      'Strict exclusive upper boundary behavior for [1972-01-01, 2027-01-01)',
      () {
        // 1. 2026-12-31T23:59:59.999999Z -> Confirmed, returns 37s
        final lastInstant = DateTime.utc(2026, 12, 31, 23, 59, 59, 999, 999);
        expect(provider.isConfirmed(lastInstant), isTrue);
        expect(provider.getTaiMinusUtcSeconds(lastInstant), 37);

        // 2. 2027-01-01T00:00:00Z (Exact boundary) -> Unconfirmed!
        final exactBoundary = DateTime.utc(2027, 1, 1, 0, 0, 0);
        expect(provider.isConfirmed(exactBoundary), isFalse);
        expect(
          () => provider.getTaiMinusUtcSeconds(exactBoundary),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'TIME_SCALE_UNCONFIRMED_FUTURE',
            ),
          ),
        );

        // 3. 2027-01-01T00:00:00.000001Z -> Unconfirmed!
        final justAfterBoundary = DateTime.utc(2027, 1, 1, 0, 0, 0, 0, 1);
        expect(provider.isConfirmed(justAfterBoundary), isFalse);
        expect(
          () => provider.getTaiMinusUtcSeconds(justAfterBoundary),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'TIME_SCALE_UNCONFIRMED_FUTURE',
            ),
          ),
        );

        // 4. A clearly future date with explicit extrapolation enabled -> returns 37s
        final distantFuture = DateTime.utc(2030, 6, 1, 12, 0, 0);
        expect(provider.isConfirmed(distantFuture), isFalse);
        expect(
          provider.getTaiMinusUtcSeconds(
            distantFuture,
            allowExtrapolation: true,
          ),
          37,
        );

        // 5. Same future date with strict default behavior -> throws TIME_SCALE_UNCONFIRMED_FUTURE
        expect(
          () => provider.getTaiMinusUtcSeconds(distantFuture),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'TIME_SCALE_UNCONFIRMED_FUTURE',
            ),
          ),
        );
      },
    );
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

    test('Verifies TT and TDB are distinct non-interchangeable scales with sub-millisecond relativistic shift', () {
      // Pick an epoch near the maximum annual relativistic eccentricity perturbation (e.g. October, when g ~ 270 deg)
      final tUtc = AstronomicalTime.fromUtcDateTime(
        DateTime.utc(2024, 10, 12, 12, 0, 0),
      );
      final tTT = tUtc.toTerrestrialTime();
      final tTDB = tUtc.toBarycentricDynamicalTime();

      expect(tTT.scale, TimeScale.tt);
      expect(tTDB.scale, TimeScale.tdb);

      // Julian Dates are distinct: TDB Julian Date != TT Julian Date
      expect(tTDB.julianDate, isNot(equals(tTT.julianDate)));

      final diffSec = tTDB.differenceInSeconds(tTT);
      // The relativistic offset is in the range [-0.0017s, +0.0017s]
      expect(diffSec.abs(), lessThanOrEqualTo(0.0017));

      // Treating TT as TDB directly without conversion causes a systematic offset of up to ~1.65 ms (~1650 us),
      // which severely violates sub-100-microsecond astronomical accuracy requirements.
      final directJdDiffMicroseconds =
          (tTDB.julianDate - tTT.julianDate) * 86400.0 * 1e6;
      expect(directJdDiffMicroseconds.abs(), greaterThan(100.0));
    });

    test('Verifies algebraic round-trip consistency of TT <-> TDB conversion pair', () {
      // Test at seasonal points across the Earth's orbit
      final testDates = [
        DateTime.utc(2000, 1, 1, 12, 0, 0),
        DateTime.utc(2010, 4, 15, 6, 0, 0),
        DateTime.utc(2020, 7, 5, 12, 0, 0),
        DateTime.utc(2024, 10, 12, 18, 0, 0),
        DateTime.utc(2026, 11, 15, 0, 0, 0),
        DateTime.utc(2050, 12, 31, 23, 0, 0),
      ];

      for (final date in testDates) {
        final tTT = AstronomicalTime.fromUtcDateTime(date)
            .toTerrestrialTime(allowExtrapolation: true);
        final tTDB = tTT.toBarycentricDynamicalTime(allowExtrapolation: true);
        final tTTReconstructed = tTDB.toTerrestrialTime(
          allowExtrapolation: true,
        );

        // Mathematical Note:
        // This test verifies internal algebraic reversibility between toBarycentricDynamicalTime()
        // and toTerrestrialTime(). It does NOT assert that the compact Keplerian model achieves
        // sub-nanosecond physical accuracy against solar system ephemerides (the compact model itself
        // exhibits residuals up to ~40 us relative to canonical IAU SOFA/ERFA due to unmodeled planetary terms).
        // Since |d(delta)/dt| <= 1.2e-9 s/s, single-step inversion error is analytically bounded by
        // |d(delta)/dt| * delta <= 2e-12 s.
        // We assert reversibility within 1 microsecond (1e-6 s), matching AstronomicalTime's standard resolution:
        final errorSec = tTTReconstructed.differenceInSeconds(tTT).abs();
        expect(
          errorSec,
          lessThan(1e-6),
          reason:
              'TT -> TDB -> TT algebraic round-trip error at $date must be < 1 us, got $errorSec s',
        );

        // Physical instant equivalence must hold within default microsecond tolerance
        expect(
          tTT.representsSameInstant(tTDB, allowExtrapolation: true),
          isTrue,
        );
        expect(
          tTT.representsSameInstant(tTTReconstructed, allowExtrapolation: true),
          isTrue,
        );
      }
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

    test('Enforces epoch compatibility in relativePositionFrom()', () {
      final epoch1 = AstronomicalTime.fromJulianDate(
        2451545.0,
        scale: TimeScale.tdb,
      );
      final epoch2 = AstronomicalTime.fromJulianDate(
        2451545.5,
        scale: TimeScale.tdb,
      );

      final target = CelestialVector(
        position: FramedVector3(
          vector: Vector3(100.0, 0.0, 0.0),
          frame: ReferenceFrameId.moonMeDe421,
          origin: CoordinateOriginId.moonCenterOfMass,
          unit: VectorUnit.meters,
        ),
        epoch: epoch1,
      );

      final observerDifferentEpoch = CelestialVector(
        position: FramedVector3(
          vector: Vector3(10.0, 0.0, 0.0),
          frame: ReferenceFrameId.moonMeDe421,
          origin: CoordinateOriginId.moonCenterOfMass,
          unit: VectorUnit.meters,
        ),
        epoch: epoch2,
      );

      expect(
        () => target.relativePositionFrom(observerDifferentEpoch),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'INCOMPATIBLE_EPOCHS',
          ),
        ),
      );

      // Equivalent epochs across time scales (UTC vs TT)
      final dtUtc = DateTime.utc(2024, 1, 1, 12, 0, 0);
      final tUtc = AstronomicalTime.fromUtcDateTime(dtUtc);
      final tTT = tUtc.toTerrestrialTime();

      final targetUtc = CelestialVector(
        position: FramedVector3(
          vector: Vector3(1000.0, 0.0, 0.0),
          frame: ReferenceFrameId.moonMeDe421,
          origin: CoordinateOriginId.moonCenterOfMass,
          unit: VectorUnit.meters,
        ),
        epoch: tUtc,
      );

      final observerTT = CelestialVector(
        position: FramedVector3(
          vector: Vector3(200.0, 0.0, 0.0),
          frame: ReferenceFrameId.moonMeDe421,
          origin: CoordinateOriginId.moonCenterOfMass,
          unit: VectorUnit.meters,
        ),
        epoch: tTT,
      );

      final rel = targetUtc.relativePositionFrom(observerTT);
      expect(rel.vector.x, closeTo(800.0, 1e-6));
    });

    test('Validates epoch comparison tolerance argument in representsSameInstant()', () {
      final t1 = AstronomicalTime.fromUtcDateTime(
        DateTime.utc(2024, 1, 1, 12, 0, 0, 0, 0),
      );
      final t2 = AstronomicalTime.fromUtcDateTime(
        DateTime.utc(2024, 1, 1, 12, 0, 0, 0, 0),
      );
      // 1 microsecond later
      final t1Micros = AstronomicalTime.fromUtcDateTime(
        DateTime.utc(2024, 1, 1, 12, 0, 0, 0, 1),
      );
      // 5 microseconds later
      final t5Micros = AstronomicalTime.fromUtcDateTime(
        DateTime.utc(2024, 1, 1, 12, 0, 0, 0, 5),
      );

      // 1. Default tolerance (1 microsecond = 1e-6 s): accepted within microsecond resolution
      expect(t1.representsSameInstant(t2), isTrue);
      expect(
        t1.representsSameInstant(t1Micros, toleranceSeconds: 1.01e-6),
        isTrue,
      );
      expect(t1.representsSameInstant(t5Micros), isFalse);

      // 2. Positive finite tolerance: accepted
      expect(
        t1.representsSameInstant(t5Micros, toleranceSeconds: 10e-6),
        isTrue,
      );
      expect(
        t1.representsSameInstant(t5Micros, toleranceSeconds: 2e-6),
        isFalse,
      );

      // 3. Zero tolerance (toleranceSeconds == 0.0): accepted
      expect(t1.representsSameInstant(t2, toleranceSeconds: 0.0), isTrue);
      expect(
        t1.representsSameInstant(t1Micros, toleranceSeconds: 0.0),
        isFalse,
      );

      // 4. Negative tolerance: rejected with INVALID_TOLERANCE
      expect(
        () => t1.representsSameInstant(t2, toleranceSeconds: -1e-6),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'INVALID_TOLERANCE',
          ),
        ),
      );

      // 5. NaN tolerance: rejected with NON_FINITE_VALUE
      expect(
        () => t1.representsSameInstant(t2, toleranceSeconds: double.nan),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      // 6. Positive infinity: rejected with NON_FINITE_VALUE
      expect(
        () => t1.representsSameInstant(t2, toleranceSeconds: double.infinity),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      // 7. Negative infinity: rejected with NON_FINITE_VALUE
      expect(
        () => t1.representsSameInstant(
          t2,
          toleranceSeconds: double.negativeInfinity,
        ),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      // 8. Immutability verification: Neither instance was modified
      expect(t1.scale, TimeScale.utc);
      expect(t2.scale, TimeScale.utc);
      expect(t1.secondOfDay, closeTo(43200.0, 1e-9));
      expect(t2.secondOfDay, closeTo(43200.0, 1e-9));
    });
  });
}

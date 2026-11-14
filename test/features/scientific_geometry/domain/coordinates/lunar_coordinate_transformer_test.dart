import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/scientific_geometry.dart';

void main() {
  group('Phase 04C — Lunar Geographic Coordinates & Transformer Tests', () {
    const transformer = LunarCoordinateTransformer();
    final sphereSurface = ReferenceSurfaceId.lunarSphere1737400;
    final heightRef = HeightReferenceId.sphereRelative;
    final frame = ReferenceFrameId.moonMeDe421;

    // Tolerance for spherical floating-point operations:
    // With double precision (53 bits, machine epsilon ~ 1.11e-16),
    // evaluated over coordinates around R = 1.7374e6 m:
    // Expected numerical discretization error bound is <= 1e-9 m.
    const posTolerance = 1e-9; // meters

    group('A. Input Validation & Failures', () {
      test('Rejects non-finite latitude (NaN, +Infinity, -Infinity)', () {
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromRadians(double.nan),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromRadians(double.infinity),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromRadians(double.negativeInfinity),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );
      });

      test('Rejects latitude outside [-90.0°, +90.0°]', () {
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(90.0001),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'COORDINATE_OUT_OF_RANGE',
            ),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(-90.1),
            latitudeType: LatitudeType.planetocentric,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'COORDINATE_OUT_OF_RANGE',
            ),
          ),
        );
      });

      test('Rejects non-finite longitude (NaN, +Infinity, -Infinity) in symmetric180', () {
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromRadians(double.nan),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromRadians(double.infinity),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromRadians(double.negativeInfinity),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );
      });

      test('Rejects non-finite longitude (NaN, +Infinity, -Infinity) in positive360', () {
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromRadians(double.nan),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.positive360,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromRadians(double.infinity),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.positive360,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromRadians(double.negativeInfinity),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.positive360,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );
      });

      test('Rejects longitude outside declared symmetric180 domain', () {
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(180.1),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'COORDINATE_OUT_OF_RANGE',
            ),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(-180.1),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'COORDINATE_OUT_OF_RANGE',
            ),
          ),
        );
      });

      test('Rejects longitude outside declared positive360 domain', () {
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(-0.01),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.positive360,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'COORDINATE_OUT_OF_RANGE',
            ),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(360.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.positive360,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'COORDINATE_OUT_OF_RANGE',
            ),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(365.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.positive360,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'COORDINATE_OUT_OF_RANGE',
            ),
          ),
        );
      });

      test('Rejects non-finite height', () {
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: double.nan,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: double.infinity,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );
      });

      test('Rejects incompatible height reference surface', () {
        final incompatibleRef = HeightReferenceId(
          name: 'OBLATE_SPHEROID',
          referenceSurface: ReferenceSurfaceId(
            name: 'OBLATE_1738_1736',
            equatorialRadius: Distance.fromMeters(1738000.0),
            polarRadius: Distance.fromMeters(1736000.0),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: incompatibleRef,
            frame: frame,
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

      test(
        'Rejects same-radius but incorrectly identified reference surface',
        () {
          final rogueSurface = ReferenceSurfaceId(
            name: 'CUSTOM_SPHERE_1737400',
            semiMajorAxisA: Distance.fromMeters(1737400.0),
            semiIntermediateAxisB: Distance.fromMeters(1737400.0),
            semiMinorAxisC: Distance.fromMeters(1737400.0),
          );
          final rogueRef = HeightReferenceId(
            name: 'CUSTOM_HEIGHT_REF',
            referenceSurface: rogueSurface,
          );

          expect(
            () => LunarGeographicCoordinates(
              latitude: Angle.fromDegrees(0.0),
              latitudeType: LatitudeType.planetodetic,
              longitude: Angle.fromDegrees(0.0),
              longitudeDirection: LongitudeDirection.eastPositive,
              longitudeDomain: LongitudeDomain.symmetric180,
              heightMeters: 0.0,
              heightReference: rogueRef,
              frame: frame,
            ),
            throwsA(
              isA<ScientificComputationException>().having(
                (e) => e.code,
                'code',
                'INCOMPATIBLE_HEIGHT_REFERENCE',
              ),
            ),
          );
        },
      );

      test(
        'Rejects unknown height-reference identity even with approved surface',
        () {
          final rogueRef = HeightReferenceId(
            name: 'UNAPPROVED_DATUM',
            referenceSurface: ReferenceSurfaceId.lunarSphere1737400,
          );

          expect(
            () => LunarGeographicCoordinates(
              latitude: Angle.fromDegrees(0.0),
              latitudeType: LatitudeType.planetodetic,
              longitude: Angle.fromDegrees(0.0),
              longitudeDirection: LongitudeDirection.eastPositive,
              longitudeDomain: LongitudeDomain.symmetric180,
              heightMeters: 0.0,
              heightReference: rogueRef,
              frame: frame,
            ),
            throwsA(
              isA<ScientificComputationException>().having(
                (e) => e.code,
                'code',
                'INCOMPATIBLE_HEIGHT_REFERENCE',
              ),
            ),
          );
        },
      );

      test('Rejects effective-radius arithmetic overflow (R + h overflows to infinity)', () {
        final hugeSurface = ReferenceSurfaceId(
          name: 'HUGE_SURFACE',
          semiMajorAxisA: Distance.fromMeters(1.0e308),
          semiIntermediateAxisB: Distance.fromMeters(1.0e308),
          semiMinorAxisC: Distance.fromMeters(1.0e308),
        );
        final hugeRef = HeightReferenceId(
          name: 'HUGE_DATUM',
          referenceSurface: hugeSurface,
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 1.0e308,
            heightReference: hugeRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'ARITHMETIC_OVERFLOW',
            ),
          ),
        );
      });

      test('Rejects non-positive effective radius (R + h <= 0)', () {
        // R = 1,737,400 m, so h = -1,737,400 results in r = 0 m
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: -1737400.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_POSITIVE_EFFECTIVE_RADIUS',
            ),
          ),
        );

        // h = -1,800,000 results in r = -62,600 m
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: -1800000.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_POSITIVE_EFFECTIVE_RADIUS',
            ),
          ),
        );
      });

      test('ReferenceSurfaceId constructor safety and validation', () {
        // Empty or whitespace name rejected
        expect(
          () => ReferenceSurfaceId(
            name: '',
            equatorialRadius: Distance.fromMeters(1737400.0),
            polarRadius: Distance.fromMeters(1737400.0),
          ),
          throwsArgumentError,
        );
        expect(
          () => ReferenceSurfaceId(
            name: '   ',
            equatorialRadius: Distance.fromMeters(1737400.0),
            polarRadius: Distance.fromMeters(1737400.0),
          ),
          throwsArgumentError,
        );

        // Missing A axis
        expect(
          () => ReferenceSurfaceId(
            name: 'MISSING_A',
            polarRadius: Distance.fromMeters(1737400.0),
          ),
          throwsArgumentError,
        );

        // Missing C axis
        expect(
          () => ReferenceSurfaceId(
            name: 'MISSING_C',
            equatorialRadius: Distance.fromMeters(1737400.0),
          ),
          throwsArgumentError,
        );

        // Zero axis rejected in primary constructor
        expect(
          () => ReferenceSurfaceId(
            name: 'ZERO_A',
            equatorialRadius: Distance.fromMeters(0.0),
            polarRadius: Distance.fromMeters(1737400.0),
          ),
          throwsArgumentError,
        );

        expect(
          () => ReferenceSurfaceId(
            name: 'ZERO_C',
            equatorialRadius: Distance.fromMeters(1737400.0),
            polarRadius: Distance.fromMeters(0.0),
          ),
          throwsArgumentError,
        );

        // Note on Distance validation boundary vs ReferenceSurfaceId validation:
        // - Distance constructor enforces that distance values are finite and non-negative (>= 0).
        // - Negative values (-100.0) and non-finite values (NaN, Infinity) are rejected at the Distance layer.
        // - Zero distance (0.0 m) is valid for Distance, but strictly rejected by ReferenceSurfaceId
        //   which requires strictly positive semi-axes (> 0).
        expect(
          () => Distance.fromMeters(-100.0),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NEGATIVE_DISTANCE',
            ),
          ),
        );
        expect(
          () => Distance.fromMeters(double.nan),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );
        expect(
          () => Distance.fromMeters(double.infinity),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );

        // Valid canonical sphere
        final canonical = ReferenceSurfaceId.lunarSphere1737400;
        expect(canonical.name, 'LUNAR_SPHERE_1737400');
        expect(canonical.semiMajorAxisA.meters, 1737400.0);
        expect(canonical.semiIntermediateAxisB.meters, 1737400.0);
        expect(canonical.semiMinorAxisC.meters, 1737400.0);
        expect(canonical.isSpherical, isTrue);

        // Valid explicitly defined non-canonical surface is constructible as a domain object
        final nonCanonical = ReferenceSurfaceId(
          name: 'MARS_SPHERE',
          equatorialRadius: Distance.fromMeters(3396190.0),
          polarRadius: Distance.fromMeters(3396190.0),
        );
        expect(nonCanonical.name, 'MARS_SPHERE');
        expect(nonCanonical.equatorialRadius.meters, 3396190.0);
        // But rejected when validated against Phase 04C spherical baseline
        expect(
          () => nonCanonical.validateSphericalBaseline(),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'INCOMPATIBLE_HEIGHT_REFERENCE',
            ),
          ),
        );
      });

      test('ReferenceSurfaceId.triaxial constructor invariant enforcement', () {
        final dValid = Distance.fromMeters(1737400.0);
        final dZero = Distance.fromMeters(0.0);

        // Empty/whitespace name rejected
        expect(
          () => ReferenceSurfaceId.triaxial(
            name: '  ',
            semiMajorAxisA: dValid,
            semiIntermediateAxisB: dValid,
            semiMinorAxisC: dValid,
          ),
          throwsArgumentError,
        );

        // Zero in individual positions rejected
        expect(
          () => ReferenceSurfaceId.triaxial(
            name: 'ZERO_A',
            semiMajorAxisA: dZero,
            semiIntermediateAxisB: dValid,
            semiMinorAxisC: dValid,
          ),
          throwsArgumentError,
        );
        expect(
          () => ReferenceSurfaceId.triaxial(
            name: 'ZERO_B',
            semiMajorAxisA: dValid,
            semiIntermediateAxisB: dZero,
            semiMinorAxisC: dValid,
          ),
          throwsArgumentError,
        );
        expect(
          () => ReferenceSurfaceId.triaxial(
            name: 'ZERO_C',
            semiMajorAxisA: dValid,
            semiIntermediateAxisB: dValid,
            semiMinorAxisC: dZero,
          ),
          throwsArgumentError,
        );

        // Valid triaxial surface succeeds
        final tri = ReferenceSurfaceId.triaxial(
          name: 'VALID_TRIAXIAL',
          semiMajorAxisA: Distance.fromMeters(1738000.0),
          semiIntermediateAxisB: Distance.fromMeters(1737500.0),
          semiMinorAxisC: Distance.fromMeters(1736000.0),
        );
        expect(tri.name, 'VALID_TRIAXIAL');
        expect(tri.semiMajorAxisA.meters, 1738000.0);
        expect(tri.semiIntermediateAxisB.meters, 1737500.0);
        expect(tri.semiMinorAxisC.meters, 1736000.0);
        expect(tri.isSpherical, isFalse);
      });

      test('HeightReferenceId constructor invariant enforcement', () {
        // Empty/whitespace name rejected
        expect(
          () => HeightReferenceId(
            name: '',
            referenceSurface: ReferenceSurfaceId.lunarSphere1737400,
          ),
          throwsArgumentError,
        );
        expect(
          () => HeightReferenceId(
            name: '   ',
            referenceSurface: ReferenceSurfaceId.lunarSphere1737400,
          ),
          throwsArgumentError,
        );

        // Valid custom height reference succeeds
        final customRef = HeightReferenceId(
          name: 'CUSTOM_DATUM',
          referenceSurface: ReferenceSurfaceId.lunarSphere1737400,
        );
        expect(customRef.name, 'CUSTOM_DATUM');
        expect(
          customRef.referenceSurface,
          ReferenceSurfaceId.lunarSphere1737400,
        );
      });

      test('ReferenceSurfaceId and HeightReferenceId value equality and hashCode contract', () {
        // Canonical lunar reference surface
        final s1 = ReferenceSurfaceId.lunarSphere1737400;
        final s2 = ReferenceSurfaceId.triaxial(
          name: 'LUNAR_SPHERE_1737400',
          semiMajorAxisA: Distance.fromMeters(1737400.0),
          semiIntermediateAxisB: Distance.fromMeters(1737400.0),
          semiMinorAxisC: Distance.fromMeters(1737400.0),
        );
        final s3 = ReferenceSurfaceId(
          name: 'LUNAR_SPHERE_1737400',
          equatorialRadius: Distance.fromMeters(1737400.0),
          polarRadius: Distance.fromMeters(1737400.0),
        );

        // Value equality across independently constructed equivalent instances
        expect(s1 == s2, isTrue);
        expect(s2 == s1, isTrue);
        expect(s1 == s3, isTrue);
        expect(s1.hashCode, equals(s2.hashCode));
        expect(s1.hashCode, equals(s3.hashCode));

        // Separately constructed instance satisfies approved baseline validation
        expect(() => s2.validateSphericalBaseline(), returnsNormally);
        expect(() => s3.validateSphericalBaseline(), returnsNormally);

        // Differing only by name
        final diffName = ReferenceSurfaceId.triaxial(
          name: 'DIFFERENT_NAME',
          semiMajorAxisA: Distance.fromMeters(1737400.0),
          semiIntermediateAxisB: Distance.fromMeters(1737400.0),
          semiMinorAxisC: Distance.fromMeters(1737400.0),
        );
        expect(s1 == diffName, isFalse);

        // Differing only in axis A
        final diffA = ReferenceSurfaceId.triaxial(
          name: 'LUNAR_SPHERE_1737400',
          semiMajorAxisA: Distance.fromMeters(1737401.0),
          semiIntermediateAxisB: Distance.fromMeters(1737400.0),
          semiMinorAxisC: Distance.fromMeters(1737400.0),
        );
        expect(s1 == diffA, isFalse);

        // Differing only in axis B
        final diffB = ReferenceSurfaceId.triaxial(
          name: 'LUNAR_SPHERE_1737400',
          semiMajorAxisA: Distance.fromMeters(1737400.0),
          semiIntermediateAxisB: Distance.fromMeters(1737401.0),
          semiMinorAxisC: Distance.fromMeters(1737400.0),
        );
        expect(s1 == diffB, isFalse);

        // Differing only in axis C
        final diffC = ReferenceSurfaceId.triaxial(
          name: 'LUNAR_SPHERE_1737400',
          semiMajorAxisA: Distance.fromMeters(1737400.0),
          semiIntermediateAxisB: Distance.fromMeters(1737400.0),
          semiMinorAxisC: Distance.fromMeters(1737401.0),
        );
        expect(s1 == diffC, isFalse);

        // HeightReferenceId value equality
        final h1 = HeightReferenceId.sphereRelative;
        final h2 = HeightReferenceId(
          name: 'SPHERE_RELATIVE_1737400',
          referenceSurface: s2,
        );
        expect(h1 == h2, isTrue);
        expect(h1.hashCode, equals(h2.hashCode));
        expect(() => h2.validateApprovedBaseline(), returnsNormally);

        // Height references differing only by name
        final hDiffName = HeightReferenceId(
          name: 'OTHER_NAME',
          referenceSurface: ReferenceSurfaceId.lunarSphere1737400,
        );
        expect(h1 == hDiffName, isFalse);

        // Height references differing only by reference surface
        final hDiffSurface = HeightReferenceId(
          name: 'SPHERE_RELATIVE_1737400',
          referenceSurface: diffName,
        );
        expect(h1 == hDiffSurface, isFalse);
      });

      test('Rejects unsupported reference frame realization', () {
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: ReferenceFrameId.moonMeDe440,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'UNSUPPORTED_REFERENCE_FRAME',
            ),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: ReferenceFrameId.j2000,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'UNSUPPORTED_REFERENCE_FRAME',
            ),
          ),
        );
      });
    });

    group('B. Cardinal & Equatorial Axis Directions', () {
      final r0 = sphereSurface.equatorialRadius.meters; // 1,737,400.0 m

      test('Equator / Prime Meridian (0°, 0°) points to +X', () {
        final coords = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(0.0),
          latitudeType: LatitudeType.planetocentric,
          longitude: Angle.fromDegrees(0.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );

        final p = transformer.toBodyFixedCartesian(coords);
        expect(p.vector.x, closeTo(r0, posTolerance));
        expect(p.vector.y, closeTo(0.0, posTolerance));
        expect(p.vector.z, closeTo(0.0, posTolerance));
        expect(p.unit, VectorUnit.meters);
        expect(p.frame, ReferenceFrameId.moonMeDe421);
        expect(p.origin, CoordinateOriginId.moonCenterOfMass);
      });

      test('Equator / 90° East points to +Y', () {
        final coords = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(0.0),
          latitudeType: LatitudeType.planetocentric,
          longitude: Angle.fromDegrees(90.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );

        final p = transformer.toBodyFixedCartesian(coords);
        expect(p.vector.x, closeTo(0.0, posTolerance));
        expect(p.vector.y, closeTo(r0, posTolerance));
        expect(p.vector.z, closeTo(0.0, posTolerance));
      });

      test('Equator / 180° East points to -X', () {
        final coords = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(0.0),
          latitudeType: LatitudeType.planetocentric,
          longitude: Angle.fromDegrees(180.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );

        final p = transformer.toBodyFixedCartesian(coords);
        expect(p.vector.x, closeTo(-r0, posTolerance));
        expect(p.vector.y, closeTo(0.0, posTolerance));
        expect(p.vector.z, closeTo(0.0, posTolerance));
      });

      test('Equator / 270° East (positive360 domain) points to -Y', () {
        final coords = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(0.0),
          latitudeType: LatitudeType.planetocentric,
          longitude: Angle.fromDegrees(270.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.positive360,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );

        final p = transformer.toBodyFixedCartesian(coords);
        expect(p.vector.x, closeTo(0.0, posTolerance));
        expect(p.vector.y, closeTo(-r0, posTolerance));
        expect(p.vector.z, closeTo(0.0, posTolerance));
      });

      test('Equator / -90° East (symmetric180 domain) points to -Y', () {
        final coords = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(0.0),
          latitudeType: LatitudeType.planetocentric,
          longitude: Angle.fromDegrees(-90.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );

        final p = transformer.toBodyFixedCartesian(coords);
        expect(p.vector.x, closeTo(0.0, posTolerance));
        expect(p.vector.y, closeTo(-r0, posTolerance));
        expect(p.vector.z, closeTo(0.0, posTolerance));
      });
    });

    group('C. Exact-Pole Numerical Contract & Validation (§7.3)', () {
      final r0 = sphereSurface.equatorialRadius.meters; // 1,737,400.0 m

      test('North Pole (+90°) produces exact +0.0 for X and Y and +r for Z across multiple longitudes', () {
        final longitudes = [0.0, 45.0, 90.0, 180.0, -160.0];

        for (final lon in longitudes) {
          final coords = LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(90.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(lon),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          );

          final p = transformer.toBodyFixedCartesian(coords);

          // Check exact values and signed-zero inspection
          expect(p.vector.x, equals(0.0));
          expect(p.vector.y, equals(0.0));
          expect(1 / p.vector.x, isPositive); // confirms +0.0, not -0.0
          expect(1 / p.vector.y, isPositive); // confirms +0.0, not -0.0
          expect(p.vector.z, equals(r0));
        }
      });

      test('North Pole (+90°) produces identical vector for west-positive longitude', () {
        final coordsEast = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(90.0),
          latitudeType: LatitudeType.planetodetic,
          longitude: Angle.fromDegrees(60.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );

        final coordsWest = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(90.0),
          latitudeType: LatitudeType.planetodetic,
          longitude: Angle.fromDegrees(300.0),
          longitudeDirection: LongitudeDirection.westPositive,
          longitudeDomain: LongitudeDomain.positive360,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );

        final pEast = transformer.toBodyFixedCartesian(coordsEast);
        final pWest = transformer.toBodyFixedCartesian(coordsWest);

        expect(pEast.vector, equals(pWest.vector));
        expect(pEast.vector, equals(Vector3(0.0, 0.0, r0)));
      });

      test('South Pole (-90°) produces exact +0.0 for X and Y and -r for Z across multiple longitudes', () {
        final longitudes = [0.0, 90.0, 180.0, -90.0, -160.0];

        for (final lon in longitudes) {
          final coords = LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(-90.0),
            latitudeType: LatitudeType.planetocentric,
            longitude: Angle.fromDegrees(lon),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          );

          final p = transformer.toBodyFixedCartesian(coords);

          expect(p.vector.x, equals(0.0));
          expect(p.vector.y, equals(0.0));
          expect(1 / p.vector.x, isPositive);
          expect(1 / p.vector.y, isPositive);
          expect(p.vector.z, equals(-r0));
        }
      });

      test(
        'Exact pole with height scaling evaluates to +/- effective radius',
        () {
          const h = 5000.0;
          final coordsNorth = LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(90.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: h,
            heightReference: heightRef,
            frame: frame,
          );

          final pNorth = transformer.toBodyFixedCartesian(coordsNorth);
          expect(pNorth.vector.x, equals(0.0));
          expect(pNorth.vector.y, equals(0.0));
          expect(pNorth.vector.z, equals(r0 + h));

          final coordsSouth = LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(-90.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: h,
            heightReference: heightRef,
            frame: frame,
          );

          final pSouth = transformer.toBodyFixedCartesian(coordsSouth);
          expect(pSouth.vector.x, equals(0.0));
          expect(pSouth.vector.y, equals(0.0));
          expect(pSouth.vector.z, equals(-(r0 + h)));
        },
      );

      test('No pole snapping for nearby non-polar latitudes', () {
        // Latitudes close to poles must use ordinary trigonometric equations
        final nearNorth = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(89.9999),
          latitudeType: LatitudeType.planetodetic,
          longitude: Angle.fromDegrees(0.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );

        final p = transformer.toBodyFixedCartesian(nearNorth);
        // At 89.9999°, cos(phi) != 0, so x is non-zero
        expect(p.vector.x, isNot(equals(0.0)));
        expect(p.vector.x, isPositive);
        expect(p.vector.z < r0, isTrue);
      });

      test('Exact poles strictly reject invalid longitude inputs', () {
        // Non-finite longitude at North Pole must be rejected
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(90.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromRadians(double.nan),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );

        // Non-finite longitude at South Pole must be rejected
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(-90.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromRadians(double.infinity),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'NON_FINITE_VALUE',
            ),
          ),
        );

        // Longitude outside symmetric180 domain at North Pole must be rejected
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(90.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(185.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'COORDINATE_OUT_OF_RANGE',
            ),
          ),
        );

        // Longitude outside positive360 domain at South Pole must be rejected
        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(-90.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(-5.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.positive360,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'COORDINATE_OUT_OF_RANGE',
            ),
          ),
        );
      });

      test('Exact poles enforce identical numerical safety checks on effective radius overflow', () {
        final hugeSurface = ReferenceSurfaceId(
          name: 'HUGE_SURFACE',
          semiMajorAxisA: Distance.fromMeters(1.0e308),
          semiIntermediateAxisB: Distance.fromMeters(1.0e308),
          semiMinorAxisC: Distance.fromMeters(1.0e308),
        );
        final hugeRef = HeightReferenceId(
          name: 'HUGE_DATUM',
          referenceSurface: hugeSurface,
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(90.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 1.0e308,
            heightReference: hugeRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'ARITHMETIC_OVERFLOW',
            ),
          ),
        );

        expect(
          () => LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(-90.0),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 1.0e308,
            heightReference: hugeRef,
            frame: frame,
          ),
          throwsA(
            isA<ScientificComputationException>().having(
              (e) => e.code,
              'code',
              'ARITHMETIC_OVERFLOW',
            ),
          ),
        );
      });
    });

    group('D. Height Variations', () {
      test('Positive radial height scales Cartesian magnitude', () {
        const h = 2500.0; // 2.5 km
        final coords = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(0.0),
          latitudeType: LatitudeType.planetodetic,
          longitude: Angle.fromDegrees(0.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: h,
          heightReference: heightRef,
          frame: frame,
        );

        final p = transformer.toBodyFixedCartesian(coords);
        expect(p.vector.x, closeTo(1737400.0 + h, posTolerance));
        expect(p.vector.magnitude, closeTo(1737400.0 + h, posTolerance));
      });

      test('Negative radial height with positive effective radius', () {
        const h = -3500.0; // -3.5 km (e.g. crater floor)
        final coords = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(0.0),
          latitudeType: LatitudeType.planetodetic,
          longitude: Angle.fromDegrees(0.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: h,
          heightReference: heightRef,
          frame: frame,
        );

        final p = transformer.toBodyFixedCartesian(coords);
        expect(p.vector.x, closeTo(1737400.0 + h, posTolerance));
        expect(p.vector.magnitude, closeTo(1737400.0 + h, posTolerance));
      });
    });

    group('E. Latitude Conventions Equivalence under Sphere', () {
      test('planetocentric and planetodetic produce identical result for spherical surface', () {
        final coordsCen = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(-45.0),
          latitudeType: LatitudeType.planetocentric,
          longitude: Angle.fromDegrees(60.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 1000.0,
          heightReference: heightRef,
          frame: frame,
        );

        final coordsDet = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(-45.0),
          latitudeType: LatitudeType.planetodetic,
          longitude: Angle.fromDegrees(60.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 1000.0,
          heightReference: heightRef,
          frame: frame,
        );

        final pCen = transformer.toBodyFixedCartesian(coordsCen);
        final pDet = transformer.toBodyFixedCartesian(coordsDet);

        expect(pCen.vector, equals(pDet.vector));
      });
    });

    group('F. Longitude Direction & Domain Equivalence', () {
      test('West-positive and East-positive representations produce identical Cartesian vector', () {
        // 60° West is equivalent to 300° East or -60° East
        final coordsEast = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(30.0),
          latitudeType: LatitudeType.planetodetic,
          longitude: Angle.fromDegrees(-60.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );

        final coordsWest = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(30.0),
          latitudeType: LatitudeType.planetodetic,
          longitude: Angle.fromDegrees(60.0),
          longitudeDirection: LongitudeDirection.westPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );

        final pEast = transformer.toBodyFixedCartesian(coordsEast);
        final pWest = transformer.toBodyFixedCartesian(coordsWest);

        expect(pEast.vector.x, closeTo(pWest.vector.x, posTolerance));
        expect(pEast.vector.y, closeTo(pWest.vector.y, posTolerance));
        expect(pEast.vector.z, closeTo(pWest.vector.z, posTolerance));
      });

      test('Symmetric180 and Positive360 domains produce identical Cartesian vector', () {
        // -160° East is equivalent to 200° East
        final coordsSymm = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(-20.0),
          latitudeType: LatitudeType.planetodetic,
          longitude: Angle.fromDegrees(-160.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );

        final coordsPos = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(-20.0),
          latitudeType: LatitudeType.planetodetic,
          longitude: Angle.fromDegrees(200.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.positive360,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );

        final pSymm = transformer.toBodyFixedCartesian(coordsSymm);
        final pPos = transformer.toBodyFixedCartesian(coordsPos);

        expect(pSymm.vector.x, closeTo(pPos.vector.x, posTolerance));
        expect(pSymm.vector.y, closeTo(pPos.vector.y, posTolerance));
        expect(pSymm.vector.z, closeTo(pPos.vector.z, posTolerance));
      });
    });

    group('G. Mandatory Canonical Project Regression Fixture (§10.4)', () {
      test(
        'Canonical fixture matches expected vector within justified tolerance',
        () {
          // Fixture specification:
          // - Latitude type: planetodetic
          // - Latitude: -88.45°
          // - Longitude: -160.0° east-positive (equivalent to 200°E)
          // - Height: 0 m relative to the Phase 04C spherical fixture (R = 1,737,400 m)
          // - Frame: MOON_ME_DE421
          final regressionCoords = LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(-88.45),
            latitudeType: LatitudeType.planetodetic,
            longitude: Angle.fromDegrees(-160.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: frame,
          );

          final p = transformer.toBodyFixedCartesian(regressionCoords);

          // Expected approximate position per specification (§10.4):
          // X: -44,161.287394 m
          // Y: -16,073.394118 m
          // Z: -1,736,764.286453 m
          const expectedX = -44161.287394;
          const expectedY = -16073.394118;
          const expectedZ = -1736764.286453;

          // Tolerance derivation per §10.4.1:
          // The expected values are given to 6 decimal places (micrometer resolution),
          // introducing at most 0.5e-6 m rounding uncertainty.
          // Binary64 arithmetic accumulates at most 0.4e-6 m discretization error.
          // Maximum theoretical deviation is bounded by Delta_max = 0.90e-6 m.
          // We test within the rigorous 1.0e-6 m (1.0 micrometer) error budget.
          const errorBudgetTolerance = 1.0e-6; // 1 micrometer
          expect(p.vector.x, closeTo(expectedX, errorBudgetTolerance));
          expect(p.vector.y, closeTo(expectedY, errorBudgetTolerance));
          expect(p.vector.z, closeTo(expectedZ, errorBudgetTolerance));

          // Exact metadata validation
          expect(p.frame, equals(ReferenceFrameId.moonMeDe421));
          expect(p.origin, equals(CoordinateOriginId.moonCenterOfMass));
          expect(p.unit, equals(VectorUnit.meters));
        },
      );
    });

    group('H. Phase 04C Transformation Provenance Contract', () {
      test('transformWithProvenance retains FramedVector3 and complete immutable source provenance', () {
        final coords = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(-88.45),
          latitudeType: LatitudeType.planetodetic,
          longitude: Angle.fromDegrees(-160.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 1250.0,
          heightReference: heightRef,
          frame: frame,
        );

        final result = transformer.transformWithProvenance(coords);

        // 1. Result contains the exact same FramedVector3 as toBodyFixedCartesian
        final directVector = transformer.toBodyFixedCartesian(coords);
        expect(result.framedVector, equals(directVector));
        expect(result.framedVector.unit, equals(VectorUnit.meters));
        expect(
          result.framedVector.origin,
          equals(CoordinateOriginId.moonCenterOfMass),
        );
        expect(result.framedVector.frame, equals(ReferenceFrameId.moonMeDe421));

        // 2. Result retains the exact source coordinate value object
        expect(result.sourceCoordinates, equals(coords));

        // 3. Provenance getters provide direct, immutable, typed access
        expect(result.sourceLatitude, equals(coords.latitude));
        expect(result.sourceLatitudeType, equals(LatitudeType.planetodetic));
        expect(result.sourceLongitude, equals(coords.longitude));
        expect(
          result.sourceLongitudeDirection,
          equals(LongitudeDirection.eastPositive),
        );
        expect(
          result.sourceLongitudeDomain,
          equals(LongitudeDomain.symmetric180),
        );
        expect(result.sourceHeightMeters, equals(1250.0));
        expect(result.sourceHeightReference, equals(heightRef));
        expect(
          result.sourceReferenceSurface,
          equals(ReferenceSurfaceId.lunarSphere1737400),
        );
        expect(result.sourceFrame, equals(ReferenceFrameId.moonMeDe421));

        // 4. Exact pole provenance behavior
        final northPoleCoords = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(90.0),
          latitudeType: LatitudeType.planetocentric,
          longitude: Angle.fromDegrees(45.0),
          longitudeDirection: LongitudeDirection.westPositive,
          longitudeDomain: LongitudeDomain.positive360,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );
        final northPoleResult = transformer.transformWithProvenance(
          northPoleCoords,
        );
        expect(northPoleResult.framedVector.vector.x, equals(0.0));
        expect(northPoleResult.framedVector.vector.y, equals(0.0));
        expect(1 / northPoleResult.framedVector.vector.x, isPositive);
        expect(1 / northPoleResult.framedVector.vector.y, isPositive);
        expect(northPoleResult.framedVector.vector.z, equals(1737400.0));
        expect(northPoleResult.sourceLatitude.inDegrees, equals(90.0));
        expect(
          northPoleResult.sourceLongitudeDirection,
          equals(LongitudeDirection.westPositive),
        );

        // 5. Value equality of LunarCoordinateTransformationResult
        final duplicateResult = transformer.transformWithProvenance(coords);
        expect(result, equals(duplicateResult));
        expect(result.hashCode, equals(duplicateResult.hashCode));
      });

      test('Enforces provenance integrity: prevents same-frame incorrect vector construction', () {
        final coords = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(0.0),
          latitudeType: LatitudeType.planetocentric,
          longitude: Angle.fromDegrees(0.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: ReferenceFrameId.moonMeDe421,
        );

        // A deliberately incorrect Cartesian vector with the EXACT SAME frame (MOON_ME_DE421)
        final incorrectVectorSameFrame = FramedVector3(
          vector: Vector3(999.0, 888.0, 777.0),
          frame: ReferenceFrameId.moonMeDe421,
          origin: CoordinateOriginId.moonCenterOfMass,
          unit: VectorUnit.meters,
        );

        // 1. fromTransformation must reject same-frame incorrect vector
        expect(
          () => LunarCoordinateTransformationResult.fromTransformation(
            framedVector: incorrectVectorSameFrame,
            sourceCoordinates: coords,
          ),
          throwsArgumentError,
        );

        // 2. fromCoordinates derives the truthful vector and does not permit passing arbitrary vectors
        final truthfulResult =
            LunarCoordinateTransformationResult.fromCoordinates(coords);
        expect(
          truthfulResult.framedVector,
          equals(transformer.toBodyFixedCartesian(coords)),
        );
        expect(truthfulResult.sourceCoordinates, equals(coords));
      });

      test(
        'Enforces provenance integrity: prevents frame mismatch construction',
        () {
          final coords = LunarGeographicCoordinates(
            latitude: Angle.fromDegrees(0.0),
            latitudeType: LatitudeType.planetocentric,
            longitude: Angle.fromDegrees(0.0),
            longitudeDirection: LongitudeDirection.eastPositive,
            longitudeDomain: LongitudeDomain.symmetric180,
            heightMeters: 0.0,
            heightReference: heightRef,
            frame: ReferenceFrameId.moonMeDe421,
          );

          final mismatchedFrameVector = FramedVector3(
            vector: Vector3(1737400.0, 0.0, 0.0),
            frame: ReferenceFrameId.icrf, // Frame mismatch!
            origin: CoordinateOriginId.moonCenterOfMass,
            unit: VectorUnit.meters,
          );

          expect(
            () => LunarCoordinateTransformationResult.fromTransformation(
              framedVector: mismatchedFrameVector,
              sourceCoordinates: coords,
            ),
            throwsArgumentError,
          );
        },
      );

      test('LunarCoordinateTransformationResult public factory fromCoordinates binds provenance truthfully', () {
        final coords = LunarGeographicCoordinates(
          latitude: Angle.fromDegrees(-88.45),
          latitudeType: LatitudeType.planetodetic,
          longitude: Angle.fromDegrees(-160.0),
          longitudeDirection: LongitudeDirection.eastPositive,
          longitudeDomain: LongitudeDomain.symmetric180,
          heightMeters: 0.0,
          heightReference: heightRef,
          frame: frame,
        );

        final result = LunarCoordinateTransformationResult.fromCoordinates(
          coords,
        );

        expect(result.sourceCoordinates, equals(coords));
        expect(
          result.framedVector,
          equals(transformer.toBodyFixedCartesian(coords)),
        );
        expect(result.sourceLatitude, equals(coords.latitude));
        expect(result.sourceLongitude, equals(coords.longitude));
        expect(result.sourceFrame, equals(ReferenceFrameId.moonMeDe421));
      });
    });
  });
}

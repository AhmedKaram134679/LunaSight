import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/scientific_geometry.dart';

void main() {
  group('Angle', () {
    const epsilonTheta = 1e-12; // rad

    test('Construction from radians and accessors', () {
      final angle = Angle.fromRadians(math.pi / 2);
      expect(angle.inRadians, equals(math.pi / 2));
      expect(angle.inDegrees, closeTo(90.0, epsilonTheta * 180 / math.pi));
    });

    test('Construction from degrees and accessors', () {
      final angle = Angle.fromDegrees(180.0);
      expect(angle.inRadians, closeTo(math.pi, epsilonTheta));
      expect(angle.inDegrees, closeTo(180.0, 1e-12));
    });

    test('Degrees to radians conversion test matrix', () {
      final cases = [
        (180.0, math.pi),
        (90.0, math.pi / 2),
        (45.0, math.pi / 4),
        (0.0, 0.0),
        (-90.0, -math.pi / 2),
      ];

      for (final (deg, rad) in cases) {
        final a = Angle.fromDegrees(deg);
        expect(a.inRadians, closeTo(rad, epsilonTheta));
      }
    });

    test('Radians to degrees conversion test matrix', () {
      final cases = [
        (math.pi, 180.0),
        (2 * math.pi, 360.0),
        (-math.pi / 4, -45.0),
      ];

      for (final (rad, deg) in cases) {
        final a = Angle.fromRadians(rad);
        expect(a.inDegrees, closeTo(deg, epsilonTheta * 180 / math.pi));
      }
    });

    test(
      'Preserves raw signed angle value without silent wrapping or clamping',
      () {
        final a1 = Angle.fromDegrees(-720.0);
        final a2 = Angle.fromDegrees(1080.0);

        expect(a1.inDegrees, closeTo(-720.0, 1e-12));
        expect(a2.inDegrees, closeTo(1080.0, 1e-12));
        expect(a1.inRadians, closeTo(-4 * math.pi, epsilonTheta));
        expect(a2.inRadians, closeTo(6 * math.pi, epsilonTheta));
      },
    );

    test('Rejects non-finite values upon construction', () {
      expect(
        () => Angle.fromRadians(double.nan),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      expect(
        () => Angle.fromRadians(double.infinity),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      expect(
        () => Angle.fromRadians(double.negativeInfinity),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      expect(
        () => Angle.fromDegrees(double.nan),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      expect(
        () => Angle.fromDegrees(double.infinity),
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );
    });

    test('Angle arithmetic: addition, subtraction, negation', () {
      final a1 = Angle.fromRadians(math.pi / 4);
      final a2 = Angle.fromRadians(math.pi / 2);

      final sum = a1 + a2;
      expect(sum.inRadians, closeTo(3 * math.pi / 4, epsilonTheta));

      final diff = a2 - a1;
      expect(diff.inRadians, closeTo(math.pi / 4, epsilonTheta));

      final neg = -a1;
      expect(neg.inRadians, closeTo(-math.pi / 4, epsilonTheta));
    });

    test('Angle arithmetic: scalar multiplication and division', () {
      final a = Angle.fromRadians(math.pi / 4);

      final prod = a * 2.0;
      expect(prod.inRadians, closeTo(math.pi / 2, epsilonTheta));

      final quot = a / 2.0;
      expect(quot.inRadians, closeTo(math.pi / 8, epsilonTheta));
    });

    test('Rejects division by zero', () {
      final a = Angle.fromRadians(math.pi);

      expect(
        () => a / 0.0,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'DIVISION_BY_ZERO',
          ),
        ),
      );

      expect(
        () => a / -0.0,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'DIVISION_BY_ZERO',
          ),
        ),
      );
    });

    test('Rejects non-finite scalar multipliers or divisors', () {
      final a = Angle.fromRadians(math.pi);

      expect(
        () => a * double.nan,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      expect(
        () => a * double.infinity,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      expect(
        () => a / double.nan,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );

      expect(
        () => a / double.infinity,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'NON_FINITE_VALUE',
          ),
        ),
      );
    });

    test('Detects arithmetic overflow', () {
      final huge = Angle.fromRadians(1.7e308);

      expect(
        () => huge + huge,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );

      expect(
        () => huge * 2.0,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );

      expect(
        () => huge / 0.1,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );

      // inDegrees overflow check
      expect(
        () => huge.inDegrees,
        throwsA(
          isA<ScientificComputationException>().having(
            (e) => e.code,
            'code',
            'ARITHMETIC_OVERFLOW',
          ),
        ),
      );
    });

    test('Equality, hashCode, and Comparable', () {
      final a1 = Angle.fromRadians(1.234);
      final a2 = Angle.fromRadians(1.234);
      final a3 = Angle.fromRadians(2.345);

      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2.hashCode));
      expect(a1, isNot(equals(a3)));

      expect(a1.compareTo(a2), equals(0));
      expect(a1.compareTo(a3), isNegative);
      expect(a3.compareTo(a1), isPositive);
    });
  });
}

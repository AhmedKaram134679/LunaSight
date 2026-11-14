import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';

/// Immutable representation of a planar angle with double-precision floating-point arithmetic.
///
/// Canonical internal representation is radians.
/// Rejects non-finite values (NaN, +Infinity, -Infinity).
/// Angles are NOT silently wrapped or clamped upon construction to preserve rotation accumulation
/// and raw input fidelity.
@immutable
class Angle implements Comparable<Angle> {
  /// The canonical value of this angle in radians.
  final double radians;

  /// Creates an [Angle] from radians.
  ///
  /// Throws [ScientificComputationException] with code `NON_FINITE_VALUE` if [radians] is not finite.
  Angle.fromRadians(this.radians) {
    if (!radians.isFinite) {
      throw ScientificComputationException(
        message: 'Angle radians must be finite. Got: $radians',
        code: 'NON_FINITE_VALUE',
        context: {'input_state': radians.isNaN ? 'NaN' : 'infinity'},
      );
    }
  }

  /// Creates an [Angle] from degrees.
  ///
  /// Throws [ScientificComputationException] with code `NON_FINITE_VALUE` if [degrees] is not finite
  /// or if the resulting radians computation is not finite.
  factory Angle.fromDegrees(double degrees) {
    if (!degrees.isFinite) {
      throw ScientificComputationException(
        message: 'Angle degrees must be finite. Got: $degrees',
        code: 'NON_FINITE_VALUE',
        context: {'input_state': degrees.isNaN ? 'NaN' : 'infinity'},
      );
    }
    final rad = degrees * (math.pi / 180.0);
    if (!rad.isFinite) {
      throw ScientificComputationException(
        message:
            'Angle radians computed from degrees must be finite. Got: $rad',
        code: 'NON_FINITE_VALUE',
        context: {
          'degrees': degrees,
          'result_state': rad.isNaN ? 'NaN' : 'infinity',
        },
      );
    }
    return Angle.fromRadians(rad);
  }

  /// The value of this angle in radians.
  double get inRadians => radians;

  /// The value of this angle in degrees.
  ///
  /// Throws [ScientificComputationException] with code `ARITHMETIC_OVERFLOW` if the degree computation overflows.
  double get inDegrees {
    final deg = radians * (180.0 / math.pi);
    if (!deg.isFinite) {
      throw ScientificComputationException(
        message:
            'Angle conversion to degrees overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {'radians': radians, 'operation': 'inDegrees'},
      );
    }
    return deg;
  }

  /// Adds another [Angle] to this angle.
  ///
  /// Throws [ScientificComputationException] with code `ARITHMETIC_OVERFLOW` if the sum overflows.
  Angle operator +(Angle other) {
    final res = radians + other.radians;
    if (!res.isFinite) {
      throw ScientificComputationException(
        message: 'Angle addition overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {'lhs_radians': radians, 'rhs_radians': other.radians},
      );
    }
    return Angle.fromRadians(res);
  }

  /// Subtracts another [Angle] from this angle.
  ///
  /// Throws [ScientificComputationException] with code `ARITHMETIC_OVERFLOW` if the difference overflows.
  Angle operator -(Angle other) {
    final res = radians - other.radians;
    if (!res.isFinite) {
      throw ScientificComputationException(
        message: 'Angle subtraction overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {'lhs_radians': radians, 'rhs_radians': other.radians},
      );
    }
    return Angle.fromRadians(res);
  }

  /// Unary negation of this angle.
  Angle operator -() => Angle.fromRadians(-radians);

  /// Multiplies this angle by a scalar.
  ///
  /// Throws [ScientificComputationException] with code `NON_FINITE_VALUE` if [scalar] is not finite,
  /// or `ARITHMETIC_OVERFLOW` if the product overflows.
  Angle operator *(double scalar) {
    if (!scalar.isFinite) {
      throw ScientificComputationException(
        message: 'Scalar multiplier must be finite. Got: $scalar',
        code: 'NON_FINITE_VALUE',
        context: {
          'radians': radians,
          'scalar_state': scalar.isNaN ? 'NaN' : 'infinity',
        },
      );
    }
    final res = radians * scalar;
    if (!res.isFinite) {
      throw ScientificComputationException(
        message: 'Angle multiplication overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {'radians': radians, 'scalar': scalar},
      );
    }
    return Angle.fromRadians(res);
  }

  /// Divides this angle by a scalar.
  ///
  /// Throws [ScientificComputationException] with code `NON_FINITE_VALUE` if [scalar] is not finite,
  /// `DIVISION_BY_ZERO` if [scalar] is zero, or `ARITHMETIC_OVERFLOW` if the quotient overflows.
  Angle operator /(double scalar) {
    if (!scalar.isFinite) {
      throw ScientificComputationException(
        message: 'Scalar divisor must be finite. Got: $scalar',
        code: 'NON_FINITE_VALUE',
        context: {
          'radians': radians,
          'divisor_state': scalar.isNaN ? 'NaN' : 'infinity',
        },
      );
    }
    if (scalar == 0.0 || scalar == -0.0) {
      throw ScientificComputationException(
        message: 'Cannot divide Angle by zero.',
        code: 'DIVISION_BY_ZERO',
        context: {'radians': radians, 'divisor': scalar},
      );
    }
    final res = radians / scalar;
    if (!res.isFinite) {
      throw ScientificComputationException(
        message: 'Angle division overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {'radians': radians, 'divisor': scalar},
      );
    }
    return Angle.fromRadians(res);
  }

  @override
  int compareTo(Angle other) => radians.compareTo(other.radians);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Angle && radians == other.radians);

  @override
  int get hashCode => radians.hashCode;

  @override
  String toString() => 'Angle($radians rad)';
}

import 'package:meta/meta.dart';
import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';

/// Immutable representation of a physical distance or geometric magnitude.
///
/// Canonical internal storage is meters.
/// Strictly non-negative: negative distances are rejected upon construction and arithmetic.
/// Rejects non-finite values (NaN, +Infinity, -Infinity).
@immutable
class Distance implements Comparable<Distance> {
  /// The canonical value of this distance in meters.
  final double meters;

  /// Creates a [Distance] from meters.
  ///
  /// Throws [ScientificComputationException] with code `NON_FINITE_VALUE` if [meters] is not finite,
  /// or `NEGATIVE_DISTANCE` if [meters] is negative.
  Distance.fromMeters(this.meters) {
    if (!meters.isFinite) {
      throw ScientificComputationException(
        message: 'Distance meters must be finite. Got: $meters',
        code: 'NON_FINITE_VALUE',
        context: {'input_state': meters.isNaN ? 'NaN' : 'infinity'},
      );
    }
    if (meters < 0.0) {
      throw ScientificComputationException(
        message: 'Distance meters cannot be negative. Got: $meters',
        code: 'NEGATIVE_DISTANCE',
        context: {'meters': meters},
      );
    }
  }

  /// Creates a [Distance] from kilometers.
  ///
  /// Throws [ScientificComputationException] with code `NON_FINITE_VALUE` if [kilometers] is not finite,
  /// `NEGATIVE_DISTANCE` if [kilometers] is negative, or `ARITHMETIC_OVERFLOW` if conversion overflows.
  factory Distance.fromKilometers(double kilometers) {
    if (!kilometers.isFinite) {
      throw ScientificComputationException(
        message: 'Distance kilometers must be finite. Got: $kilometers',
        code: 'NON_FINITE_VALUE',
        context: {'input_state': kilometers.isNaN ? 'NaN' : 'infinity'},
      );
    }
    if (kilometers < 0.0) {
      throw ScientificComputationException(
        message: 'Distance kilometers cannot be negative. Got: $kilometers',
        code: 'NEGATIVE_DISTANCE',
        context: {'kilometers': kilometers},
      );
    }
    final m = kilometers * 1000.0;
    if (!m.isFinite) {
      throw ScientificComputationException(
        message:
            'Distance conversion to meters overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {'kilometers': kilometers, 'operation': 'fromKilometers'},
      );
    }
    return Distance.fromMeters(m);
  }

  /// Distance in meters.
  double get inMeters => meters;

  /// Distance in kilometers.
  double get inKilometers => meters / 1000.0;

  /// Adds another [Distance] to this distance.
  ///
  /// Throws [ScientificComputationException] with code `ARITHMETIC_OVERFLOW` if the sum overflows.
  Distance operator +(Distance other) {
    final res = meters + other.meters;
    if (!res.isFinite) {
      throw ScientificComputationException(
        message: 'Distance addition overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {'lhs_meters': meters, 'rhs_meters': other.meters},
      );
    }
    return Distance.fromMeters(res);
  }

  /// Subtracts another [Distance] from this distance.
  ///
  /// Throws [ScientificComputationException] with code `NEGATIVE_DISTANCE` if [other] is greater than this distance.
  Distance operator -(Distance other) {
    if (other.meters > meters) {
      throw ScientificComputationException(
        message:
            'Distance subtraction would result in negative distance: $meters - ${other.meters}',
        code: 'NEGATIVE_DISTANCE',
        context: {'lhs_meters': meters, 'rhs_meters': other.meters},
      );
    }
    final res = meters - other.meters;
    return Distance.fromMeters(res);
  }

  /// Multiplies this distance by a scalar.
  ///
  /// Throws [ScientificComputationException] with code `NON_FINITE_VALUE` if [scalar] is not finite,
  /// `NEGATIVE_DISTANCE` if [scalar] is negative, or `ARITHMETIC_OVERFLOW` if the product overflows.
  Distance operator *(double scalar) {
    if (!scalar.isFinite) {
      throw ScientificComputationException(
        message: 'Scalar multiplier must be finite. Got: $scalar',
        code: 'NON_FINITE_VALUE',
        context: {
          'meters': meters,
          'scalar_state': scalar.isNaN ? 'NaN' : 'infinity',
        },
      );
    }
    if (scalar < 0.0) {
      throw ScientificComputationException(
        message: 'Cannot multiply Distance by a negative scalar: $scalar',
        code: 'NEGATIVE_DISTANCE',
        context: {'scalar': scalar, 'meters': meters},
      );
    }
    final res = meters * scalar;
    if (!res.isFinite) {
      throw ScientificComputationException(
        message: 'Distance multiplication overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {'meters': meters, 'scalar': scalar},
      );
    }
    return Distance.fromMeters(res);
  }

  /// Divides this distance by a scalar.
  ///
  /// Unambiguous error hierarchy:
  /// 1. If [scalar] is non-finite: throws `NON_FINITE_VALUE`.
  /// 2. If [scalar] is zero: throws `DIVISION_BY_ZERO`.
  /// 3. If [scalar] is negative: throws `NEGATIVE_DISTANCE`.
  /// 4. If the quotient overflows: throws `ARITHMETIC_OVERFLOW`.
  Distance operator /(double scalar) {
    if (!scalar.isFinite) {
      throw ScientificComputationException(
        message: 'Scalar divisor must be finite. Got: $scalar',
        code: 'NON_FINITE_VALUE',
        context: {
          'meters': meters,
          'divisor_state': scalar.isNaN ? 'NaN' : 'infinity',
        },
      );
    }
    if (scalar == 0.0 || scalar == -0.0) {
      throw ScientificComputationException(
        message: 'Cannot divide Distance by zero.',
        code: 'DIVISION_BY_ZERO',
        context: {'meters': meters, 'divisor': scalar},
      );
    }
    if (scalar < 0.0) {
      throw ScientificComputationException(
        message: 'Cannot divide Distance by a negative scalar: $scalar',
        code: 'NEGATIVE_DISTANCE',
        context: {'scalar': scalar, 'meters': meters},
      );
    }
    final res = meters / scalar;
    if (!res.isFinite) {
      throw ScientificComputationException(
        message: 'Distance division overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {'meters': meters, 'divisor': scalar},
      );
    }
    return Distance.fromMeters(res);
  }

  @override
  int compareTo(Distance other) => meters.compareTo(other.meters);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Distance && meters == other.meters);

  @override
  int get hashCode => meters.hashCode;

  @override
  String toString() => 'Distance($meters m)';
}

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';

/// Immutable, unit-neutral three-dimensional Cartesian vector.
///
/// Features:
/// - Mandatory runtime validation for all public constructions (rejects NaN, +Infinity, -Infinity).
/// - Safe canonical constants (`zero`, `unitX`, `unitY`, `unitZ`) instantiated via private constructor.
/// - Scaled Euclidean magnitude (Blue's algorithm) to avoid unnecessary overflow and underflow in sum of squares.
/// - Scaled normalization to avoid underflow/overflow while rejecting exact zero vectors ($0, 0, 0$).
/// - Strict detection and exception reporting for intermediate and final arithmetic overflows.
@immutable
class Vector3 {
  /// X component of the vector.
  final double x;

  /// Y component of the vector.
  final double y;

  /// Z component of the vector.
  final double z;

  /// Public validating constructor.
  ///
  /// Rejects non-finite component values (NaN, +Infinity, -Infinity), throwing
  /// [ScientificComputationException] with code `NON_FINITE_VALUE`.
  Vector3(this.x, this.y, this.z) {
    if (!x.isFinite || !y.isFinite || !z.isFinite) {
      throw ScientificComputationException(
        message:
            'Vector3 components must be finite numeric values. Got: ($x, $y, $z)',
        code: 'NON_FINITE_VALUE',
        context: {
          if (x.isFinite) 'x': x else 'x_state': x.isNaN ? 'NaN' : 'infinity',
          if (y.isFinite) 'y': y else 'y_state': y.isNaN ? 'NaN' : 'infinity',
          if (z.isFinite) 'z': z else 'z_state': z.isNaN ? 'NaN' : 'infinity',
        },
      );
    }
  }

  /// Private const constructor for verified invariants and canonical constants.
  const Vector3._internal(this.x, this.y, this.z);

  /// Canonical zero vector $(0, 0, 0)$.
  static const Vector3 zero = Vector3._internal(0.0, 0.0, 0.0);

  /// Canonical unit X axis vector $(1, 0, 0)$.
  static const Vector3 unitX = Vector3._internal(1.0, 0.0, 0.0);

  /// Canonical unit Y axis vector $(0, 1, 0)$.
  static const Vector3 unitY = Vector3._internal(0.0, 1.0, 0.0);

  /// Canonical unit Z axis vector $(0, 0, 1)$.
  static const Vector3 unitZ = Vector3._internal(0.0, 0.0, 1.0);

  /// Evaluates Euclidean magnitude using Blue's scaled magnitude algorithm.
  ///
  /// Prevents premature intermediate overflow when squaring large components ($|c| \gtrsim \sqrt{\Omega}$)
  /// and premature underflow when squaring small components ($|c| \lesssim \sqrt{2^{-1022}}$).
  ///
  /// Throws [ScientificComputationException] with code `MAGNITUDE_OVERFLOW` if the final
  /// magnitude multiplication exceeds the finite binary64 range.
  double get magnitude {
    final ax = x.abs();
    final ay = y.abs();
    final az = z.abs();
    final m = math.max(ax, math.max(ay, az));

    if (m == 0.0) {
      return 0.0;
    }

    final sx = x / m;
    final sy = y / m;
    final sz = z / m;

    final scaledSum = math.sqrt(sx * sx + sy * sy + sz * sz);
    final mag = m * scaledSum;

    if (!mag.isFinite) {
      throw ScientificComputationException(
        message:
            'Vector3 magnitude calculation overflowed finite binary64 range.',
        code: 'MAGNITUDE_OVERFLOW',
        context: {'x': x, 'y': y, 'z': z, 'max_component': m},
      );
    }

    return mag;
  }

  /// Returns the normalized unit vector $\hat{v} = \vec{v} / \|\vec{v}\|$ using scaled normalization.
  ///
  /// Prevents intermediate squaring overflow and scaled magnitude underflow.
  /// Rejects an exact zero vector ($x == 0 \land y == 0 \land z == 0$), throwing
  /// [ScientificComputationException] with code `ZERO_VECTOR_NORMALIZATION`.
  Vector3 normalize() {
    final ax = x.abs();
    final ay = y.abs();
    final az = z.abs();
    final m = math.max(ax, math.max(ay, az));

    if (m == 0.0) {
      throw ScientificComputationException(
        message: 'Cannot normalize a zero vector (0.0, 0.0, 0.0).',
        code: 'ZERO_VECTOR_NORMALIZATION',
        context: {'x': x, 'y': y, 'z': z},
      );
    }

    final sx = x / m;
    final sy = y / m;
    final sz = z / m;

    final scaledMag = math.sqrt(sx * sx + sy * sy + sz * sz);

    final nx = sx / scaledMag;
    final ny = sy / scaledMag;
    final nz = sz / scaledMag;

    return Vector3(nx, ny, nz);
  }

  /// Adds another [Vector3] to this vector.
  ///
  /// Throws [ScientificComputationException] with code `ARITHMETIC_OVERFLOW` if any component sum overflows.
  Vector3 operator +(Vector3 other) {
    final rx = x + other.x;
    final ry = y + other.y;
    final rz = z + other.z;

    if (!rx.isFinite || !ry.isFinite || !rz.isFinite) {
      throw ScientificComputationException(
        message: 'Vector3 addition overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {
          'lhs_x': x,
          'lhs_y': y,
          'lhs_z': z,
          'rhs_x': other.x,
          'rhs_y': other.y,
          'rhs_z': other.z,
          'overflow_component': !rx.isFinite ? 'x' : (!ry.isFinite ? 'y' : 'z'),
        },
      );
    }

    return Vector3(rx, ry, rz);
  }

  /// Subtracts another [Vector3] from this vector.
  ///
  /// Throws [ScientificComputationException] with code `ARITHMETIC_OVERFLOW` if any component difference overflows.
  Vector3 operator -(Vector3 other) {
    final rx = x - other.x;
    final ry = y - other.y;
    final rz = z - other.z;

    if (!rx.isFinite || !ry.isFinite || !rz.isFinite) {
      throw ScientificComputationException(
        message: 'Vector3 subtraction overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {
          'lhs_x': x,
          'lhs_y': y,
          'lhs_z': z,
          'rhs_x': other.x,
          'rhs_y': other.y,
          'rhs_z': other.z,
          'overflow_component': !rx.isFinite ? 'x' : (!ry.isFinite ? 'y' : 'z'),
        },
      );
    }

    return Vector3(rx, ry, rz);
  }

  /// Unary negation of this vector.
  Vector3 operator -() => Vector3(-x, -y, -z);

  /// Multiplies this vector by a scalar.
  ///
  /// Throws [ScientificComputationException] with code `NON_FINITE_VALUE` if [scalar] is not finite,
  /// or `ARITHMETIC_OVERFLOW` if any resulting component overflows.
  Vector3 operator *(double scalar) {
    if (!scalar.isFinite) {
      throw ScientificComputationException(
        message: 'Scalar multiplier must be finite. Got: $scalar',
        code: 'NON_FINITE_VALUE',
        context: {
          'x': x,
          'y': y,
          'z': z,
          'scalar_state': scalar.isNaN ? 'NaN' : 'infinity',
        },
      );
    }

    final rx = x * scalar;
    final ry = y * scalar;
    final rz = z * scalar;

    if (!rx.isFinite || !ry.isFinite || !rz.isFinite) {
      throw ScientificComputationException(
        message:
            'Vector3 scalar multiplication overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {
          'scalar': scalar,
          'x': x,
          'y': y,
          'z': z,
          'overflow_component': !rx.isFinite
              ? 'rx'
              : (!ry.isFinite ? 'ry' : 'rz'),
        },
      );
    }

    return Vector3(rx, ry, rz);
  }

  /// Divides this vector by a scalar.
  ///
  /// Throws [ScientificComputationException] with code `NON_FINITE_VALUE` if [scalar] is not finite,
  /// `DIVISION_BY_ZERO` if [scalar] is zero ($0.0$ or $-0.0$), or `ARITHMETIC_OVERFLOW` if any component overflows.
  Vector3 operator /(double scalar) {
    if (!scalar.isFinite) {
      throw ScientificComputationException(
        message: 'Scalar divisor must be finite. Got: $scalar',
        code: 'NON_FINITE_VALUE',
        context: {
          'x': x,
          'y': y,
          'z': z,
          'divisor_state': scalar.isNaN ? 'NaN' : 'infinity',
        },
      );
    }
    if (scalar == 0.0 || scalar == -0.0) {
      throw ScientificComputationException(
        message: 'Cannot divide Vector3 by zero.',
        code: 'DIVISION_BY_ZERO',
        context: {'scalar': scalar, 'x': x, 'y': y, 'z': z},
      );
    }

    final rx = x / scalar;
    final ry = y / scalar;
    final rz = z / scalar;

    if (!rx.isFinite || !ry.isFinite || !rz.isFinite) {
      throw ScientificComputationException(
        message: 'Vector3 scalar division overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {
          'scalar': scalar,
          'x': x,
          'y': y,
          'z': z,
          'overflow_component': !rx.isFinite
              ? 'rx'
              : (!ry.isFinite ? 'ry' : 'rz'),
        },
      );
    }

    return Vector3(rx, ry, rz);
  }

  /// Evaluates the vector dot product $\vec{u} \cdot \vec{v} = u_x v_x + u_y v_y + u_z v_z$.
  ///
  /// Checks pairwise products for intermediate overflow: if any product $u_i v_i$ or their summation
  /// is not finite, throws [ScientificComputationException] with code `ARITHMETIC_OVERFLOW`.
  double dot(Vector3 other) {
    final px = x * other.x;
    final py = y * other.y;
    final pz = z * other.z;

    if (!px.isFinite || !py.isFinite || !pz.isFinite) {
      throw ScientificComputationException(
        message: 'Vector3 dot product intermediate multiplication overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {
          'lhs_x': x,
          'lhs_y': y,
          'lhs_z': z,
          'rhs_x': other.x,
          'rhs_y': other.y,
          'rhs_z': other.z,
          'overflow_component': !px.isFinite
              ? 'px'
              : (!py.isFinite ? 'py' : 'pz'),
        },
      );
    }

    final sum = px + py + pz;
    if (!sum.isFinite) {
      throw ScientificComputationException(
        message:
            'Vector3 dot product summation overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {'px': px, 'py': py, 'pz': pz, 'operation': 'dot_summation'},
      );
    }

    return sum;
  }

  /// Evaluates the vector cross product $\vec{u} \times \vec{v}$.
  ///
  /// Checks pairwise component products and subtractions for intermediate and final overflow.
  /// Throws [ScientificComputationException] with code `ARITHMETIC_OVERFLOW` if any product or subtraction
  /// exceeds the finite binary64 range.
  Vector3 cross(Vector3 other) {
    final p1x = y * other.z;
    final p2x = z * other.y;
    if (!p1x.isFinite || !p2x.isFinite) {
      throw ScientificComputationException(
        message: 'Vector3 cross product X-component multiplication overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {
          'component': 'x',
          'y': y,
          'rhs_z': other.z,
          'z': z,
          'rhs_y': other.y,
          'overflow_product': !p1x.isFinite ? 'p1x' : 'p2x',
        },
      );
    }
    final rx = p1x - p2x;

    final p1y = z * other.x;
    final p2y = x * other.z;
    if (!p1y.isFinite || !p2y.isFinite) {
      throw ScientificComputationException(
        message: 'Vector3 cross product Y-component multiplication overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {
          'component': 'y',
          'z': z,
          'rhs_x': other.x,
          'x': x,
          'rhs_z': other.z,
          'overflow_product': !p1y.isFinite ? 'p1y' : 'p2y',
        },
      );
    }
    final ry = p1y - p2y;

    final p1z = x * other.y;
    final p2z = y * other.x;
    if (!p1z.isFinite || !p2z.isFinite) {
      throw ScientificComputationException(
        message: 'Vector3 cross product Z-component multiplication overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {
          'component': 'z',
          'x': x,
          'rhs_y': other.y,
          'y': y,
          'rhs_x': other.x,
          'overflow_product': !p1z.isFinite ? 'p1z' : 'p2z',
        },
      );
    }
    final rz = p1z - p2z;

    if (!rx.isFinite || !ry.isFinite || !rz.isFinite) {
      throw ScientificComputationException(
        message: 'Vector3 cross product subtraction overflowed finite binary64 range.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {
          'p1x': p1x,
          'p2x': p2x,
          'p1y': p1y,
          'p2y': p2y,
          'p1z': p1z,
          'p2z': p2z,
          'overflow_component': !rx.isFinite
              ? 'rx'
              : (!ry.isFinite ? 'ry' : 'rz'),
        },
      );
    }

    return Vector3(rx, ry, rz);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Vector3 && x == other.x && y == other.y && z == other.z);

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vector3($x, $y, $z)';
}

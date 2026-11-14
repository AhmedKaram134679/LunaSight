import 'package:meta/meta.dart';
import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/coordinate_origin_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/reference_frame_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/vector3.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/vector_unit.dart';

/// Immutable spatial 3D vector bound to its physical coordinate metadata:
/// - Reference frame orientation and realization ([ReferenceFrameId])
/// - Coordinate origin location ([CoordinateOriginId])
/// - Physical component unit ([VectorUnit])
///
/// NOTE on Epoch:
/// [FramedVector3] is not epoch-tagged in Phase 04B. It represents purely spatial
/// geometric metadata. Time-dependent ephemeris state representations must carry their
/// observation epoch and time scale explicitly in dedicated contracts (Phase 04C/04D).
///
/// NOTE on Arithmetic:
/// Direct arithmetic operators (+, -, *) are intentionally NOT supported on [FramedVector3]
/// because coordinate shifts and rotation matrices are required across differing frames/origins.
@immutable
class FramedVector3 {
  /// The underlying unit-neutral 3D mathematical vector.
  final Vector3 vector;

  /// The reference frame orientation and realization.
  final ReferenceFrameId frame;

  /// The physical coordinate origin.
  final CoordinateOriginId origin;

  /// The physical unit of the vector components.
  final VectorUnit unit;

  const FramedVector3({
    required this.vector,
    required this.frame,
    required this.origin,
    required this.unit,
  });

  /// Converts this framed vector to a target [VectorUnit].
  ///
  /// Supported conversions:
  /// - `meters` to `kilometers`: divides components by 1,000.0.
  /// - `kilometers` to `meters`: multiplies components by 1,000.0. Throws `ARITHMETIC_OVERFLOW` on overflow.
  /// - `dimensionless` to `dimensionless`: returns identical instance.
  ///
  /// Reject conversions between `dimensionless` and dimensional distance units (`meters`, `kilometers`),
  /// throwing [ScientificComputationException] with code `UNIT_MISMATCH`.
  FramedVector3 toUnit(VectorUnit targetUnit) {
    if (unit == targetUnit) {
      return this;
    }

    if (unit == VectorUnit.dimensionless ||
        targetUnit == VectorUnit.dimensionless) {
      throw ScientificComputationException(
        message: 'Cannot convert between dimensionless unit and dimensional distance units.',
        code: 'UNIT_MISMATCH',
        context: {'source_unit': unit.name, 'target_unit': targetUnit.name},
      );
    }

    if (unit == VectorUnit.meters && targetUnit == VectorUnit.kilometers) {
      final convertedVector = Vector3(
        vector.x / 1000.0,
        vector.y / 1000.0,
        vector.z / 1000.0,
      );
      return FramedVector3(
        vector: convertedVector,
        frame: frame,
        origin: origin,
        unit: targetUnit,
      );
    }

    if (unit == VectorUnit.kilometers && targetUnit == VectorUnit.meters) {
      final rx = vector.x * 1000.0;
      final ry = vector.y * 1000.0;
      final rz = vector.z * 1000.0;

      if (!rx.isFinite || !ry.isFinite || !rz.isFinite) {
        throw ScientificComputationException(
          message: 'FramedVector3 unit conversion to meters overflowed finite binary64 range.',
          code: 'ARITHMETIC_OVERFLOW',
          context: {
            'source_x': vector.x,
            'source_y': vector.y,
            'source_z': vector.z,
            'target_unit': targetUnit.name,
          },
        );
      }

      return FramedVector3(
        vector: Vector3(rx, ry, rz),
        frame: frame,
        origin: origin,
        unit: targetUnit,
      );
    }

    throw ScientificComputationException(
      message:
          'Unsupported unit conversion from ${unit.name} to ${targetUnit.name}.',
      code: 'UNIT_MISMATCH',
      context: {'source_unit': unit.name, 'target_unit': targetUnit.name},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FramedVector3 &&
          vector == other.vector &&
          frame == other.frame &&
          origin == other.origin &&
          unit == other.unit);

  @override
  int get hashCode => Object.hash(vector, frame, origin, unit);

  @override
  String toString() =>
      'FramedVector3($vector, frame: $frame, origin: $origin, unit: ${unit.name})';
}

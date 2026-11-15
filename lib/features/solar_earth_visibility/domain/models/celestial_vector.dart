import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/coordinate_origin_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/framed_vector3.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/reference_frame_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/vector3.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/vector_unit.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/astronomical_time.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/leap_second_provider.dart';

/// Strongly typed celestial state vector representing 3D position (and optional velocity)
/// of a target celestial body (Sun, Earth, Moon) bound to its exact epoch, reference frame,
/// and coordinate origin.
///
/// Implements the Phase 06 Milestone 02 celestial vector contract:
/// - Explicit [AstronomicalTime] epoch tagging.
/// - Encapsulates underlying spatial [FramedVector3].
/// - Enforces coordinate frame consistency (e.g. `MOON_ME_DE421`, `ICRF`, `J2000`).
/// - Rejects arithmetic operations across differing reference frames, origins, or epochs.
class CelestialVector {
  /// The spatial position vector bound to its reference frame, origin, and unit.
  final FramedVector3 position;

  /// The observation or integration epoch of this vector.
  final AstronomicalTime epoch;

  /// Optional velocity vector in the same reference frame and unit/second.
  final FramedVector3? velocity;

  CelestialVector({
    required this.position,
    required this.epoch,
    this.velocity,
  }) {
    if (velocity != null) {
      if (velocity!.frame != position.frame ||
          velocity!.origin != position.origin) {
        throw ScientificComputationException(
          message: 'Velocity must share the same reference frame and origin as position.',
          code: 'INCOMPATIBLE_VELOCITY_METADATA',
          context: {
            'position_frame': position.frame.name,
            'velocity_frame': velocity!.frame.name,
            'position_origin': position.origin.name,
            'velocity_origin': velocity!.origin.name,
          },
        );
      }
    }
  }

  /// Reference frame of this celestial vector.
  ReferenceFrameId get frame => position.frame;

  /// Coordinate origin of this celestial vector.
  CoordinateOriginId get origin => position.origin;

  /// Distance unit of this celestial vector.
  VectorUnit get unit => position.unit;

  /// Underlying 3D vector components.
  Vector3 get vector => position.vector;

  /// Calculates the relative position vector pointing from [observer] to this celestial body.
  ///
  /// Invariants:
  /// - Both vectors must share the identical [ReferenceFrameId].
  /// - Both vectors must share the identical [CoordinateOriginId].
  /// - Both vectors must represent the same physical instant within [epochToleranceSeconds] (default $10^{-6}\text{ s}$).
  ///
  /// Throws [ScientificComputationException] with code:
  /// - `INCOMPATIBLE_REFERENCE_FRAME` if frames differ.
  /// - `INCOMPATIBLE_COORDINATE_ORIGIN` if origins differ.
  /// - `INCOMPATIBLE_EPOCHS` if epochs represent different physical instants.
  FramedVector3 relativePositionFrom(
    CelestialVector observer, {
    double epochToleranceSeconds = 1e-6,
    LeapSecondProvider leapSecondProvider = const LeapSecondProvider(),
    bool allowExtrapolation = false,
  }) {
    if (frame != observer.frame) {
      throw ScientificComputationException(
        message: 'Cannot compute relative celestial vector across differing reference frames.',
        code: 'INCOMPATIBLE_REFERENCE_FRAME',
        context: {
          'target_frame': frame.name,
          'observer_frame': observer.frame.name,
        },
      );
    }

    if (origin != observer.origin) {
      throw ScientificComputationException(
        message: 'Cannot compute relative celestial vector across differing coordinate origins.',
        code: 'INCOMPATIBLE_COORDINATE_ORIGIN',
        context: {
          'target_origin': origin.name,
          'observer_origin': observer.origin.name,
        },
      );
    }

    final sameInstant = epoch.representsSameInstant(
      observer.epoch,
      toleranceSeconds: epochToleranceSeconds,
      leapSecondProvider: leapSecondProvider,
      allowExtrapolation: allowExtrapolation,
    );
    if (!sameInstant) {
      throw ScientificComputationException(
        message:
            'Cannot compute relative celestial vector across differing epochs: '
            '$epoch vs ${observer.epoch}.',
        code: 'INCOMPATIBLE_EPOCHS',
        context: {
          'target_epoch': epoch.toString(),
          'observer_epoch': observer.epoch.toString(),
          'tolerance_seconds': epochToleranceSeconds,
        },
      );
    }

    // Convert both to meters if needed:
    final targetMeters = position.toUnit(VectorUnit.meters);
    final observerMeters = observer.position.toUnit(VectorUnit.meters);

    final relVector = targetMeters.vector - observerMeters.vector;

    return FramedVector3(
      vector: relVector,
      frame: frame,
      origin: observer.origin,
      unit: VectorUnit.meters,
    );
  }

  @override
  String toString() =>
      'CelestialVector(${position.vector}, epoch: $epoch, frame: ${frame.name}, origin: ${origin.name})';
}

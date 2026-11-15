import 'dart:math' as math;

import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_geographic_coordinates.dart';
import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/distance.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/coordinate_origin_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/reference_frame_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/vector_unit.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/celestial_vector.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/leap_second_provider.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/local_horizon_basis.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/topocentric_position.dart';

/// Service converting Moon-centered body-fixed celestial vectors into local topocentric
/// SEZ coordinates (South-East-Zenith, Azimuth, Elevation, Slant Range) relative to a lunar surface observer.
///
/// Implements the Phase 06 Milestone 03 transformation contract.
class LocalTopocentricConverter {
  const LocalTopocentricConverter();

  /// Converts target [targetVector] into a [TopocentricPosition] as viewed by [observerVector]
  /// located at [observerCoordinates].
  ///
  /// Invariants & Validation:
  /// - Both [targetVector] and [observerVector] must strictly use `MOON_ME_DE421`.
  ///   Any unsupported frame (even if shared by both vectors) is rejected with `UNSUPPORTED_REFERENCE_FRAME`
  ///   or `INCOMPATIBLE_REFERENCE_FRAME`.
  /// - Both vectors must originate from `CoordinateOriginId.moonCenterOfMass`.
  /// - Both vectors must represent the same physical instant within [epochToleranceSeconds] (default $10^{-6}\text{ s}$).
  ///   Vectors representing different physical instants are rejected with `INCOMPATIBLE_EPOCHS`.
  /// - Zero relative range throws [ScientificComputationException] with code `ZERO_RELATIVE_RANGE`.
  /// - Directly overhead (Zenith, $+90^\circ$) or directly below (Nadir, $-90^\circ$) targets
  ///   where horizontal range $H < 10^{-6}\text{ m}$ produce an explicit `null` azimuth.
  TopocentricPosition toTopocentric({
    required CelestialVector targetVector,
    required CelestialVector observerVector,
    required LunarGeographicCoordinates observerCoordinates,
    double epochToleranceSeconds = 1e-6,
    LeapSecondProvider leapSecondProvider = const LeapSecondProvider(),
    bool allowExtrapolation = false,
  }) {
    // 1. Strict Reference Frame Validation:
    // Both vectors must be MOON_ME_DE421.
    if (targetVector.frame != ReferenceFrameId.moonMeDe421 ||
        observerVector.frame != ReferenceFrameId.moonMeDe421) {
      if (targetVector.frame != observerVector.frame) {
        throw ScientificComputationException(
          message: 'Target and observer celestial vectors must belong to the same reference frame.',
          code: 'INCOMPATIBLE_REFERENCE_FRAME',
          context: {
            'target_frame': targetVector.frame.name,
            'observer_frame': observerVector.frame.name,
            'required_frame': ReferenceFrameId.moonMeDe421.name,
          },
        );
      } else {
        throw ScientificComputationException(
          message:
              'Unsupported reference frame for local topocentric conversion: ${targetVector.frame.name}. '
              'Both vectors must use ${ReferenceFrameId.moonMeDe421.name}.',
          code: 'UNSUPPORTED_REFERENCE_FRAME',
          context: {
            'frame': targetVector.frame.name,
            'required_frame': ReferenceFrameId.moonMeDe421.name,
          },
        );
      }
    }

    // 2. Strict Origin Validation:
    if (targetVector.origin != CoordinateOriginId.moonCenterOfMass ||
        observerVector.origin != CoordinateOriginId.moonCenterOfMass) {
      throw ScientificComputationException(
        message: 'Celestial vectors must be Moon-centered to compute topocentric position.',
        code: 'INCOMPATIBLE_COORDINATE_ORIGIN',
        context: {
          'target_origin': targetVector.origin.name,
          'observer_origin': observerVector.origin.name,
          'required_origin': CoordinateOriginId.moonCenterOfMass.name,
        },
      );
    }

    // 3. Strict Epoch Compatibility Validation:
    // Verify that both vectors represent the same physical instant.
    final sameInstant = targetVector.epoch.representsSameInstant(
      observerVector.epoch,
      toleranceSeconds: epochToleranceSeconds,
      leapSecondProvider: leapSecondProvider,
      allowExtrapolation: allowExtrapolation,
    );
    if (!sameInstant) {
      throw ScientificComputationException(
        message:
            'Target and observer celestial vectors represent different physical epochs: '
            '${targetVector.epoch} vs ${observerVector.epoch}.',
        code: 'INCOMPATIBLE_EPOCHS',
        context: {
          'target_epoch': targetVector.epoch.toString(),
          'observer_epoch': observerVector.epoch.toString(),
          'tolerance_seconds': epochToleranceSeconds,
        },
      );
    }

    // 4. Relative position vector (target - observer) in meters:
    final targetMeters = targetVector.position.toUnit(VectorUnit.meters).vector;
    final observerMeters = observerVector.position
        .toUnit(VectorUnit.meters)
        .vector;

    final rho = targetMeters - observerMeters;

    final slantRangeMeters = rho.magnitude;
    if (slantRangeMeters < 1e-9) {
      throw ScientificComputationException(
        message: 'Cannot compute topocentric coordinates for target at zero relative range.',
        code: 'ZERO_RELATIVE_RANGE',
        context: {'slant_range': slantRangeMeters},
      );
    }

    // 5. Local SEZ basis at observer coordinates:
    final basis = LocalHorizonBasis.fromCoordinates(
      latitude: observerCoordinates.latitude,
      longitude: observerCoordinates.longitude,
    );

    // 6. Projection onto SEZ axes:
    // S = -rho . uN
    // E =  rho . uE
    // Z =  rho . uZ
    final s = -rho.dot(basis.north);
    final e = rho.dot(basis.east);
    final z = rho.dot(basis.zenith);

    final horizontalRangeMeters = math.sqrt(s * s + e * e);

    // 7. Elevation angle: atan2(Z, H) in [-pi/2, +pi/2]
    final elRad = math.atan2(z, horizontalRangeMeters);
    final elevation = Angle.fromRadians(elRad);

    // 8. Azimuth angle: atan2(E, -S) clockwise from North:
    // If H is effectively zero (e.g. < 1e-6 meters), azimuth is mathematically degenerate.
    Angle? azimuth;
    if (horizontalRangeMeters >= 1e-6) {
      var azRad = math.atan2(e, -s);
      if (azRad < 0.0) {
        azRad += 2.0 * math.pi;
      }
      azimuth = Angle.fromRadians(azRad);
    }

    return TopocentricPosition(
      azimuth: azimuth,
      elevation: elevation,
      slantRange: Distance.fromMeters(slantRangeMeters),
      horizontalRange: Distance.fromMeters(horizontalRangeMeters),
      southMeters: s,
      eastMeters: e,
      zenithMeters: z,
      epoch: targetVector.epoch,
      frame: targetVector.frame,
    );
  }
}

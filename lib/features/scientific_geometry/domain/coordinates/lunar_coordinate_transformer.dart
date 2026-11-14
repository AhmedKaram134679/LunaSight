import 'dart:math' as math;

import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_coordinate_transformation_result.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_geographic_coordinates.dart';
import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/coordinate_origin_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/framed_vector3.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/vector3.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/vector_unit.dart';

/// Forward coordinate transformation engine from lunar geographic coordinates
/// to body-fixed Cartesian position vectors.
///
/// Implements the Phase 04C forward transformation contract:
/// `Lunar Geographic Coordinates → Body-Fixed Cartesian Position`
///
/// Features:
/// - Explicit spherical model forward transformation ($x = r\cos\varphi\cos\lambda$, $y = r\cos\varphi\sin\lambda$, $z = r\sin\varphi$)
/// - Exact-pole numerical contract: returns exact $+0.0$ for X and Y, and $\pm r$ for Z at exact poles ($\pm 90^\circ$)
/// - No pole snapping or artificial clamping for non-polar coordinates
/// - Strict validation and rejection of non-finite results or arithmetic overflow
/// - Output encapsulation in [FramedVector3] preserving frame identity (`MOON_ME_DE421`), lunar center of mass origin, and meter units
/// - Full diagnostic traceability via [transformWithProvenance] yielding [LunarCoordinateTransformationResult]
final class LunarCoordinateTransformer {
  const LunarCoordinateTransformer();

  /// Transforms [coords] into a Cartesian position [FramedVector3] expressed in meters.
  FramedVector3 toBodyFixedCartesian(LunarGeographicCoordinates coords) {
    final r = coords.effectiveRadiusMeters;

    // Exact-pole numerical contract (§7.3):
    // Prevents non-zero floating-point machine residuals in cos(pi/2) from contaminating polar X/Y.
    // Follows the same strict finite-vector and arithmetic-safety contract as ordinary coordinates.
    if (coords.isExactNorthPole) {
      if (!r.isFinite) {
        throw ScientificComputationException(
          message: 'North Pole transformation resulted in non-finite component values.',
          code: 'ARITHMETIC_OVERFLOW',
          context: {
            'effective_radius': r,
            'latitude_deg': coords.latitude.inDegrees,
            'longitude_deg': coords.longitude.inDegrees,
          },
        );
      }
      return FramedVector3(
        vector: Vector3(0.0, 0.0, r),
        frame: coords.frame,
        origin: CoordinateOriginId.moonCenterOfMass,
        unit: VectorUnit.meters,
      );
    }

    if (coords.isExactSouthPole) {
      final z = -r;
      if (!z.isFinite) {
        throw ScientificComputationException(
          message: 'South Pole transformation resulted in non-finite component values.',
          code: 'ARITHMETIC_OVERFLOW',
          context: {
            'effective_radius': r,
            'latitude_deg': coords.latitude.inDegrees,
            'longitude_deg': coords.longitude.inDegrees,
          },
        );
      }
      return FramedVector3(
        vector: Vector3(0.0, 0.0, z),
        frame: coords.frame,
        origin: CoordinateOriginId.moonCenterOfMass,
        unit: VectorUnit.meters,
      );
    }

    // Standard spherical transformation equations for non-polar coordinates:
    final phi = coords.latitude.inRadians;
    final lambda = coords.normalizedEastLongitudeRadians;

    final cosPhi = math.cos(phi);
    final sinPhi = math.sin(phi);
    final cosLambda = math.cos(lambda);
    final sinLambda = math.sin(lambda);

    final x = r * cosPhi * cosLambda;
    final y = r * cosPhi * sinLambda;
    final z = r * sinPhi;

    if (!x.isFinite || !y.isFinite || !z.isFinite) {
      throw ScientificComputationException(
        message: 'Cartesian coordinate transformation resulted in non-finite component values.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {
          'effective_radius': r,
          'latitude_deg': coords.latitude.inDegrees,
          'longitude_deg': coords.longitude.inDegrees,
          if (x.isFinite) 'x': x,
          if (y.isFinite) 'y': y,
          if (z.isFinite) 'z': z,
        },
      );
    }

    return FramedVector3(
      vector: Vector3(x, y, z),
      frame: coords.frame,
      origin: CoordinateOriginId.moonCenterOfMass,
      unit: VectorUnit.meters,
    );
  }

  /// Transforms [coords] into a [LunarCoordinateTransformationResult] pairing the Cartesian
  /// position [FramedVector3] with its complete source-coordinate provenance and reference geometry.
  LunarCoordinateTransformationResult transformWithProvenance(
    LunarGeographicCoordinates coords,
  ) {
    return LunarCoordinateTransformationResult.fromCoordinates(
      coords,
      transformer: this,
    );
  }
}

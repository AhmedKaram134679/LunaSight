import 'package:meta/meta.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/coordinate_conventions.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/reference_surface_id.dart';
import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/reference_frame_id.dart';

/// Immutable domain value object representing validated lunar surface geographic coordinates.
///
/// Requires explicit declaration of:
/// - [latitude] and [latitudeType] (`planetocentric` or `planetodetic`)
/// - [longitude], [longitudeDirection] (`eastPositive` or `westPositive`), and [longitudeDomain] (`symmetric180` or `positive360`)
/// - Signed radial [heightMeters] and [heightReference]
/// - Target lunar [frame] realization (e.g. `MOON_ME_DE421`)
@immutable
class LunarGeographicCoordinates {
  /// Surface latitude as an [Angle]. Must be within [-90°, +90°].
  final Angle latitude;

  /// Explicit geometric latitude convention.
  final LatitudeType latitudeType;

  /// Surface longitude as an [Angle].
  final Angle longitude;

  /// Direction in which longitude increases positively.
  final LongitudeDirection longitudeDirection;

  /// Declared input boundary domain for longitude.
  final LongitudeDomain longitudeDomain;

  /// Signed radial height in meters relative to [heightReference].
  final double heightMeters;

  /// Explicit height datum defining the reference surface.
  final HeightReferenceId heightReference;

  /// Target lunar body-fixed reference frame realization.
  final ReferenceFrameId frame;

  LunarGeographicCoordinates({
    required this.latitude,
    required this.latitudeType,
    required this.longitude,
    required this.longitudeDirection,
    required this.longitudeDomain,
    required this.heightMeters,
    required this.heightReference,
    required this.frame,
  }) {
    // 1. Validate latitude finiteness and range [-90°, +90°]
    final latDeg = latitude.inDegrees;
    if (latDeg < -90.0 || latDeg > 90.0) {
      throw ScientificComputationException(
        message: 'Latitude must be within [-90.0°, +90.0°]. Got: $latDeg°',
        code: 'COORDINATE_OUT_OF_RANGE',
        context: {'latitude_deg': latDeg, 'latitude_type': latitudeType.name},
      );
    }

    // 2. Validate longitude domain boundaries
    final lonDeg = longitude.inDegrees;
    if (longitudeDomain == LongitudeDomain.symmetric180) {
      if (lonDeg < -180.0 || lonDeg > 180.0) {
        throw ScientificComputationException(
          message:
              'Longitude for symmetric180 domain must be within [-180.0°, +180.0°]. Got: $lonDeg°',
          code: 'COORDINATE_OUT_OF_RANGE',
          context: {
            'longitude_deg': lonDeg,
            'longitude_domain': longitudeDomain.name,
            'longitude_direction': longitudeDirection.name,
          },
        );
      }
    } else if (longitudeDomain == LongitudeDomain.positive360) {
      if (lonDeg < 0.0 || lonDeg >= 360.0) {
        throw ScientificComputationException(
          message:
              'Longitude for positive360 domain must be within [0.0°, 360.0°). Got: $lonDeg°',
          code: 'COORDINATE_OUT_OF_RANGE',
          context: {
            'longitude_deg': lonDeg,
            'longitude_domain': longitudeDomain.name,
            'longitude_direction': longitudeDirection.name,
          },
        );
      }
    }

    // 3. Validate height finiteness
    if (!heightMeters.isFinite) {
      throw ScientificComputationException(
        message:
            'Height meters must be a finite numeric value. Got: $heightMeters',
        code: 'NON_FINITE_VALUE',
        context: {
          'height_state': heightMeters.isNaN ? 'NaN' : 'infinity',
          'height_reference': heightReference.name,
        },
      );
    }

    // 4. Validate effective radius finite arithmetic before reference validation: r = R + h
    final r0 = heightReference.referenceSurface.equatorialRadius.meters;
    final effectiveRadius = r0 + heightMeters;
    if (!effectiveRadius.isFinite) {
      throw ScientificComputationException(
        message: 'Effective radius calculation (R + h) overflowed to non-finite value.',
        code: 'ARITHMETIC_OVERFLOW',
        context: {'reference_radius_meters': r0, 'height_meters': heightMeters},
      );
    }

    // 5. Validate height reference identity against Phase 04C approved baseline
    heightReference.validateApprovedBaseline();

    // 6. Validate effective radius strictly positive value: r = R + h > 0
    if (effectiveRadius <= 0.0) {
      throw ScientificComputationException(
        message:
            'Effective radius (R + h) must be strictly positive. Got: $effectiveRadius m',
        code: 'NON_POSITIVE_EFFECTIVE_RADIUS',
        context: {
          'radius_meters': r0,
          'height_meters': heightMeters,
          'effective_radius': effectiveRadius,
        },
      );
    }

    // 6. Validate frame realization (Phase 04C requires explicit MOON_ME_DE421)
    if (frame != ReferenceFrameId.moonMeDe421) {
      throw ScientificComputationException(
        message:
            'Unsupported or unresolved reference frame. Phase 04C requires MOON_ME_DE421. Got: ${frame.name}',
        code: 'UNSUPPORTED_REFERENCE_FRAME',
        context: {
          'frame_name': frame.name,
          if (frame.naifId != null) 'naif_id': frame.naifId,
          if (frame.ephemerisVersion != null)
            'ephemeris_version': frame.ephemerisVersion,
        },
      );
    }
  }

  /// Returns normalized east-positive longitude in radians within [-π, +π].
  double get normalizedEastLongitudeRadians {
    var deg = longitude.inDegrees;
    if (longitudeDirection == LongitudeDirection.westPositive) {
      deg = -deg;
    }
    // Normalize into [-180, +180]
    while (deg > 180.0) {
      deg -= 360.0;
    }
    while (deg < -180.0) {
      deg += 360.0;
    }
    return Angle.fromDegrees(deg).inRadians;
  }

  /// Whether latitude is exactly at the North Pole (+90.0°).
  bool get isExactNorthPole => latitude.inDegrees == 90.0;

  /// Whether latitude is exactly at the South Pole (-90.0°).
  bool get isExactSouthPole => latitude.inDegrees == -90.0;

  /// Effective radius $r = R + h$ in meters.
  double get effectiveRadiusMeters =>
      heightReference.referenceSurface.equatorialRadius.meters + heightMeters;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LunarGeographicCoordinates &&
          latitude == other.latitude &&
          latitudeType == other.latitudeType &&
          longitude == other.longitude &&
          longitudeDirection == other.longitudeDirection &&
          longitudeDomain == other.longitudeDomain &&
          heightMeters == other.heightMeters &&
          heightReference == other.heightReference &&
          frame == other.frame);

  @override
  int get hashCode => Object.hash(
    latitude,
    latitudeType,
    longitude,
    longitudeDirection,
    longitudeDomain,
    heightMeters,
    heightReference,
    frame,
  );

  @override
  String toString() =>
      'LunarGeographicCoordinates(lat: ${latitude.inDegrees}°, lon: ${longitude.inDegrees}° ${longitudeDirection.name}, h: ${heightMeters}m, frame: ${frame.name})';
}

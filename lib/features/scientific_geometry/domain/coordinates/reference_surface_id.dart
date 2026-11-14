import 'package:meta/meta.dart';
import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/distance.dart';

/// Strongly typed value object representing a geometric reference surface.
///
/// Phase 04C specifically utilizes an explicitly declared spherical reference surface
/// with equatorial and polar radii equal to 1,737,400 meters ($a = b = c = R$).
@immutable
class ReferenceSurfaceId {
  /// Descriptive name or identifier of the reference surface model.
  final String name;

  /// The equatorial radius $a$ in meters.
  final Distance equatorialRadius;

  /// The polar radius $c$ in meters.
  final Distance polarRadius;

  const ReferenceSurfaceId({
    required this.name,
    required this.equatorialRadius,
    required this.polarRadius,
  });

  /// The canonical LOLA / lunar mean spherical reference model ($R = 1,737,400\text{ m}$).
  static final ReferenceSurfaceId lunarSphere1737400 = ReferenceSurfaceId(
    name: 'LUNAR_SPHERE_1737400',
    equatorialRadius: Distance.fromMeters(1737400.0),
    polarRadius: Distance.fromMeters(1737400.0),
  );

  /// Whether this reference surface is an exact sphere ($a == c$).
  bool get isSpherical => equatorialRadius == polarRadius;

  /// Validates that this surface matches the required spherical reference surface for Phase 04C.
  void validateSphericalBaseline() {
    if (!isSpherical || equatorialRadius.meters != 1737400.0) {
      throw ScientificComputationException(
        message:
            'Unsupported reference surface. Phase 04C requires a spherical surface of radius 1,737,400 m. Got: $name',
        code: 'INCOMPATIBLE_HEIGHT_REFERENCE',
        context: {
          'surface_name': name,
          'equatorial_radius': equatorialRadius.meters,
          'polar_radius': polarRadius.meters,
        },
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferenceSurfaceId &&
          name == other.name &&
          equatorialRadius == other.equatorialRadius &&
          polarRadius == other.polarRadius);

  @override
  int get hashCode => Object.hash(name, equatorialRadius, polarRadius);

  @override
  String toString() =>
      'ReferenceSurfaceId($name, R=${equatorialRadius.meters}m)';
}

/// Strongly typed value object defining the height reference datum.
///
/// Ensures that height values explicitly declare their reference surface datum
/// and prevents terrain-relative or unreconciled datums from being treated as sphere-relative.
@immutable
class HeightReferenceId {
  /// Descriptive name of the height datum.
  final String name;

  /// The reference surface against which height is measured.
  final ReferenceSurfaceId referenceSurface;

  const HeightReferenceId({required this.name, required this.referenceSurface});

  /// Height defined radially relative to the canonical lunar reference sphere ($1,737,400\text{ m}$).
  static final HeightReferenceId sphereRelative = HeightReferenceId(
    name: 'SPHERE_RELATIVE_1737400',
    referenceSurface: ReferenceSurfaceId.lunarSphere1737400,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HeightReferenceId &&
          name == other.name &&
          referenceSurface == other.referenceSurface);

  @override
  int get hashCode => Object.hash(name, referenceSurface);

  @override
  String toString() => 'HeightReferenceId($name, surface: $referenceSurface)';
}

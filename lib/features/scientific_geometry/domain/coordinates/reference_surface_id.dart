import 'package:meta/meta.dart';
import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/distance.dart';

/// Strongly typed value object representing a geometric reference surface.
///
/// Phase 04C specifically utilizes an explicitly declared spherical reference surface
/// with equatorial and polar semi-axes equal to 1,737,400 meters ($a = b = c = R$).
@immutable
class ReferenceSurfaceId {
  /// Descriptive name or identifier of the reference surface model.
  final String name;

  /// Semi-major / equatorial semi-axis $a$ in meters.
  final Distance semiMajorAxisA;

  /// Semi-intermediate / equatorial semi-axis $b$ in meters ($a = b$ for axisymmetric/spherical).
  final Distance semiIntermediateAxisB;

  /// Polar semi-axis $c$ in meters.
  final Distance semiMinorAxisC;

  /// Primary constructor supporting three-axis ($a, b, c$) models as well as two-radius models.
  ///
  /// If [semiMajorAxisA] is omitted, [equatorialRadius] must be provided.
  /// If [semiIntermediateAxisB] is omitted, it defaults to the equatorial radius.
  /// If [semiMinorAxisC] is omitted, [polarRadius] must be provided.
  ReferenceSurfaceId({
    required this.name,
    Distance? semiMajorAxisA,
    Distance? semiIntermediateAxisB,
    Distance? semiMinorAxisC,
    Distance? equatorialRadius,
    Distance? polarRadius,
  }) : semiMajorAxisA = semiMajorAxisA ?? equatorialRadius!,
       semiIntermediateAxisB =
           semiIntermediateAxisB ?? semiMajorAxisA ?? equatorialRadius!,
       semiMinorAxisC = semiMinorAxisC ?? polarRadius!;

  /// Constant constructor explicitly specifying all three semi-axes ($a, b, c$).
  const ReferenceSurfaceId.triaxial({
    required this.name,
    required this.semiMajorAxisA,
    required this.semiIntermediateAxisB,
    required this.semiMinorAxisC,
  });

  /// Backward-compatible constructor for two-radius surface specifications.
  ReferenceSurfaceId.twoRadius({
    required String name,
    required Distance equatorialRadius,
    required Distance polarRadius,
  }) : this(
         name: name,
         semiMajorAxisA: equatorialRadius,
         semiIntermediateAxisB: equatorialRadius,
         semiMinorAxisC: polarRadius,
       );

  /// Backward-compatible getter for equatorial radius ($a$).
  Distance get equatorialRadius => semiMajorAxisA;

  /// Backward-compatible getter for polar radius ($c$).
  Distance get polarRadius => semiMinorAxisC;

  /// The canonical LOLA / lunar mean spherical reference model ($a = b = c = 1,737,400\text{ m}$).
  static final ReferenceSurfaceId lunarSphere1737400 =
      ReferenceSurfaceId.triaxial(
        name: 'LUNAR_SPHERE_1737400',
        semiMajorAxisA: Distance.fromMeters(1737400.0),
        semiIntermediateAxisB: Distance.fromMeters(1737400.0),
        semiMinorAxisC: Distance.fromMeters(1737400.0),
      );

  /// Whether this reference surface is an exact sphere ($a == b == c$).
  bool get isSpherical =>
      semiMajorAxisA == semiIntermediateAxisB &&
      semiIntermediateAxisB == semiMinorAxisC;

  /// Validates that this surface matches the approved spherical reference surface for Phase 04C.
  void validateSphericalBaseline() {
    if (this != lunarSphere1737400) {
      throw ScientificComputationException(
        message:
            'Unsupported reference surface. Phase 04C requires the approved spherical baseline LUNAR_SPHERE_1737400 ($name).',
        code: 'INCOMPATIBLE_HEIGHT_REFERENCE',
        context: {
          'surface_name': name,
          'semi_major_axis_a': semiMajorAxisA.meters,
          'semi_intermediate_axis_b': semiIntermediateAxisB.meters,
          'semi_minor_axis_c': semiMinorAxisC.meters,
        },
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferenceSurfaceId &&
          name == other.name &&
          semiMajorAxisA == other.semiMajorAxisA &&
          semiIntermediateAxisB == other.semiIntermediateAxisB &&
          semiMinorAxisC == other.semiMinorAxisC);

  @override
  int get hashCode =>
      Object.hash(name, semiMajorAxisA, semiIntermediateAxisB, semiMinorAxisC);

  @override
  String toString() =>
      'ReferenceSurfaceId($name, a=${semiMajorAxisA.meters}m, b=${semiIntermediateAxisB.meters}m, c=${semiMinorAxisC.meters}m)';
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

  /// Validates that this height reference matches the approved canonical datum for Phase 04C.
  void validateApprovedBaseline() {
    if (this != sphereRelative) {
      throw ScientificComputationException(
        message:
            'Unsupported height reference. Phase 04C requires the approved baseline SPHERE_RELATIVE_1737400 ($name).',
        code: 'INCOMPATIBLE_HEIGHT_REFERENCE',
        context: {
          'height_reference_name': name,
          'surface_name': referenceSurface.name,
        },
      );
    }
    referenceSurface.validateSphericalBaseline();
  }

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

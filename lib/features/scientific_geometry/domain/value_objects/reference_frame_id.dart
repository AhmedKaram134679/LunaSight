import 'package:flutter/foundation.dart';

/// Strongly typed value object representing the orientation and realization of spatial axes.
///
/// Distinguishes between reference frame orientations and realization models (such as DE421 vs DE440),
/// preventing accidental equivalence between differing dynamical realizations.
@immutable
class ReferenceFrameId {
  /// The descriptive standard name of the reference frame.
  final String name;

  /// Optional NAIF SPICE integer identifier associated with this frame definition.
  final int? naifId;

  /// Optional ephemeris kernel or integration release version (e.g. 'DE421', 'DE440').
  final String? ephemerisVersion;

  const ReferenceFrameId({
    required this.name,
    this.naifId,
    this.ephemerisVersion,
  });

  /// International Celestial Reference Frame (ICRF).
  ///
  /// Kinematically non-rotating celestial frame realized by extragalactic radio sources.
  static const ReferenceFrameId icrf = ReferenceFrameId(name: 'ICRF');

  /// Dynamical equator and equinox of J2000.0 (FK5).
  ///
  /// NAIF frame ID 1. Distinct from ICRF.
  static const ReferenceFrameId j2000 = ReferenceFrameId(
    name: 'J2000',
    naifId: 1,
  );

  /// Moon Mean Earth / Polar Axis frame tied to DE421 ephemeris.
  ///
  /// NAIF frame ID 31007 per NAIF lunar text kernel `moon_080317.tf`.
  static const ReferenceFrameId moonMeDe421 = ReferenceFrameId(
    name: 'MOON_ME_DE421',
    naifId: 31007,
    ephemerisVersion: 'DE421',
  );

  /// Moon Principal Axes frame tied to DE421 ephemeris.
  ///
  /// NAIF frame ID 31006 per NAIF lunar text kernel `moon_080317.tf`.
  static const ReferenceFrameId moonPaDe421 = ReferenceFrameId(
    name: 'MOON_PA_DE421',
    naifId: 31006,
    ephemerisVersion: 'DE421',
  );

  /// Moon Mean Earth frame tied to DE440 ephemeris (`MOON_ME_DE440_ME421`).
  ///
  /// NAIF frame ID 31009 per NAIF lunar text kernel `moon_de440_220930.tf`.
  static const ReferenceFrameId moonMeDe440 = ReferenceFrameId(
    name: 'MOON_ME_DE440_ME421',
    naifId: 31009,
    ephemerisVersion: 'DE440',
  );

  /// Moon Principal Axes frame tied to DE440 ephemeris (`MOON_PA_DE440`).
  ///
  /// NAIF frame ID 31008 per NAIF lunar text kernel `moon_de440_220930.tf`.
  static const ReferenceFrameId moonPaDe440 = ReferenceFrameId(
    name: 'MOON_PA_DE440',
    naifId: 31008,
    ephemerisVersion: 'DE440',
  );

  /// Moon Principal Axes frame default tied to DE440 ephemeris (`MOON_PA`).
  ///
  /// NAIF frame ID 31010 per NAIF lunar text kernel `moon_de440_220930.tf`.
  static const ReferenceFrameId moonPa = ReferenceFrameId(
    name: 'MOON_PA',
    naifId: 31010,
    ephemerisVersion: 'DE440',
  );

  /// Moon Mean Earth frame default tied to DE440 ephemeris (`MOON_ME`).
  ///
  /// NAIF frame ID 31011 per NAIF lunar text kernel `moon_de440_220930.tf`.
  static const ReferenceFrameId moonMe = ReferenceFrameId(
    name: 'MOON_ME',
    naifId: 31011,
    ephemerisVersion: 'DE440',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferenceFrameId &&
          name == other.name &&
          naifId == other.naifId &&
          ephemerisVersion == other.ephemerisVersion);

  @override
  int get hashCode => Object.hash(name, naifId, ephemerisVersion);

  @override
  String toString() {
    final extra = [
      if (naifId != null) 'naifId: $naifId',
      if (ephemerisVersion != null) 'ephemeris: $ephemerisVersion',
    ].join(', ');
    return extra.isEmpty
        ? 'ReferenceFrameId($name)'
        : 'ReferenceFrameId($name, $extra)';
  }
}

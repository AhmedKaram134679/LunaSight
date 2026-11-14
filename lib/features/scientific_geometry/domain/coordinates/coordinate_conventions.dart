/// Coordinate conventions for lunar geographic coordinates.
library;

/// The geometric latitude definition type.
enum LatitudeType {
  /// Latitude defined by the direction of the position vector from the body's center of mass.
  planetocentric,

  /// Latitude defined relative to a reference model / spheroid (as used in JPL Horizons GEODETIC inputs).
  planetodetic,
}

/// The directional convention for longitude values.
enum LongitudeDirection {
  /// Longitude increases positively towards the East.
  eastPositive,

  /// Longitude increases positively towards the West.
  westPositive,
}

/// The declared input domain range for longitude values.
enum LongitudeDomain {
  /// Longitude bounded within [-180°, +180°].
  symmetric180,

  /// Longitude bounded within [0°, 360°).
  positive360,
}

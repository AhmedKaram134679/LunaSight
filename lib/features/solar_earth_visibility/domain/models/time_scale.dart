/// Enumeration of recognized astronomical time scales.
enum TimeScale {
  /// Coordinated Universal Time (civil atomic timescale with leap seconds).
  utc,

  /// International Atomic Time (uniform atomic timescale, continuous without leap seconds).
  tai,

  /// Terrestrial Time (uniform dynamical timescale for apparent geocentric ephemerides).
  /// Defined as: TT = TAI + 32.184s.
  tt,

  /// Barycentric Dynamical Time (uniform dynamical timescale for solar system ephemerides).
  /// Differs from TT by periodic relativistic variations (|TDB - TT| < 0.0017s).
  tdb,
}

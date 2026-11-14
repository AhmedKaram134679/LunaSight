import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';

/// Embedded, authoritative IERS / USNO leap-second provider.
///
/// Records the cumulative difference $\Delta\text{AT} = \text{TAI} - \text{UTC}$ in integer seconds.
///
/// Coverage Scope:
/// - Begins: 1972-01-01 00:00:00 UTC ($\Delta\text{AT} = 10\text{ s}$, start of UTC leap second system).
/// - Current: 2017-01-01 through present / 2026+ ($\Delta\text{AT} = 37\text{ s}$).
///
/// Scientific Limitations:
/// - Dates prior to 1972-01-01: UTC used frequency offsets rather than step adjustments;
///   queries before 1972-01-01 throw [ScientificComputationException] with `TIME_SCALE_OUT_OF_RANGE`.
/// - Future dates: The IERS Bulletin C issues leap-second announcements 6 months in advance.
///   Dates beyond the guaranteed validity horizon (currently 2027-01-01) can be evaluated
///   under explicitly configured extrapolation or checked with `isWithinGuaranteedRange`.
class LeapSecondProvider {
  const LeapSecondProvider();

  /// The earliest date supported by this step-based table (start of modern UTC standard).
  static final DateTime minSupportedUtc = DateTime.utc(1972, 1, 1);

  /// The guaranteed validity horizon confirmed by IERS Bulletin C (no leap seconds announced through at least 2026-12-31).
  static final DateTime guaranteedUntilUtc = DateTime.utc(2027, 1, 1);

  /// Table of UTC transition epochs and resulting cumulative (TAI - UTC) offset in seconds.
  /// Sourced from IERS Bulletins and USNO `tai-utc.dat`.
  static const List<(int year, int month, int day, int offsetSeconds)> _table =
      [
        (1972, 1, 1, 10),
        (1972, 7, 1, 11),
        (1973, 1, 1, 12),
        (1974, 1, 1, 13),
        (1975, 1, 1, 14),
        (1976, 1, 1, 15),
        (1977, 1, 1, 16),
        (1978, 1, 1, 17),
        (1979, 1, 1, 18),
        (1980, 1, 1, 19),
        (1981, 7, 1, 20),
        (1982, 7, 1, 21),
        (1983, 7, 1, 22),
        (1985, 7, 1, 23),
        (1988, 1, 1, 24),
        (1990, 1, 1, 25),
        (1991, 1, 1, 26),
        (1992, 7, 1, 27),
        (1993, 7, 1, 28),
        (1994, 7, 1, 29),
        (1996, 1, 1, 30),
        (1997, 7, 1, 31),
        (1999, 1, 1, 32),
        (2006, 1, 1, 33),
        (2009, 1, 1, 34),
        (2012, 7, 1, 35),
        (2015, 7, 1, 36),
        (2017, 1, 1, 37),
      ];

  /// Returns the offset $\Delta\text{AT} = \text{TAI} - \text{UTC}$ in seconds for a given [utcDateTime].
  ///
  /// Throws [ScientificComputationException] with code `TIME_SCALE_OUT_OF_RANGE` if [utcDateTime]
  /// is before [minSupportedUtc].
  ///
  /// If [utcDateTime] is after [guaranteedUntilUtc], [allowExtrapolation] must be true (default: true,
  /// assuming no leap seconds added past 2017), otherwise throws `TIME_SCALE_UNCONFIRMED_FUTURE`.
  int getTaiMinusUtcSeconds(
    DateTime utcDateTime, {
    bool allowExtrapolation = true,
  }) {
    if (!utcDateTime.isUtc) {
      throw ScientificComputationException(
        message: 'Leap second lookup requires DateTime in UTC timezone.',
        code: 'TIME_SCALE_INVALID_TIMEZONE',
        context: {'input_is_utc': false},
      );
    }

    if (utcDateTime.isBefore(minSupportedUtc)) {
      throw ScientificComputationException(
        message: 'UTC dates prior to 1972-01-01 are not supported by the step leap-second table.',
        code: 'TIME_SCALE_OUT_OF_RANGE',
        context: {
          'input_utc': utcDateTime.toIso8601String(),
          'min_supported_utc': minSupportedUtc.toIso8601String(),
        },
      );
    }

    if (utcDateTime.isAfter(guaranteedUntilUtc) && !allowExtrapolation) {
      throw ScientificComputationException(
        message: 'UTC date is beyond the guaranteed IERS leap-second horizon.',
        code: 'TIME_SCALE_UNCONFIRMED_FUTURE',
        context: {
          'input_utc': utcDateTime.toIso8601String(),
          'guaranteed_until_utc': guaranteedUntilUtc.toIso8601String(),
        },
      );
    }

    // Binary / linear search through historical table:
    // Finds the latest transition epoch that is <= utcDateTime
    var offset = _table.first.$4;
    for (final entry in _table) {
      final transitionUtc = DateTime.utc(entry.$1, entry.$2, entry.$3);
      if (utcDateTime.isBefore(transitionUtc)) {
        break;
      }
      offset = entry.$4;
    }

    return offset;
  }
}

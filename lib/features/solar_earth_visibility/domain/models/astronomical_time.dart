import 'dart:math' as math;

import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/leap_second_provider.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/time_scale.dart';

/// Immutable astronomical epoch and time-scale representation.
///
/// Implements the Phase 06 Milestone 02 astronomical time contract.
///
/// Principles:
/// - Explicit time scales ([TimeScale.utc], [TimeScale.tai], [TimeScale.tt], [TimeScale.tdb]).
/// - Prevents accidental mixing of civil and dynamical timescales.
/// - Uses a split two-part Julian Date representation:
///   $$JD = \text{jdBase} + \text{dayFraction}$$
///   where $\text{jdBase}$ is the Julian Date at 00:00:00 UTC (e.g. integer $\text{JDN} - 0.5$)
///   and $\text{secondOfDay}$ maintains exact sub-microsecond precision without IEEE-754 mantissa exhaustion.
/// - Implements the standard relationship: $\text{TT} = \text{TAI} + 32.184\text{ s}$.
/// - Implements the Fairhead & Bretagnon / USNO circular approximation for $\text{TDB} - \text{TT}$:
///   $$\text{TDB} - \text{TT} = 0.001657\sin(g + 0.0167\sin g)\text{ seconds}$$
///   where $g = 357.53^\circ + 35999.05^\circ T_{\text{TT}}$. This model is accurate to $< 10\text{ microseconds}$,
///   well beyond the $100\text{ microsecond}$ requirement for planetary and lunar surface visibility.
class AstronomicalTime {
  /// Base Julian Date at 00:00:00 of the civil day ($\text{JDN} - 0.5$).
  final double jdBase;

  /// Elapsed seconds from 00:00:00 of the base Julian Day, bounded in $[0.0, 86400.0)$.
  final double secondOfDay;

  /// The explicit time scale associated with this Julian Date.
  final TimeScale scale;

  /// Standard J2000.0 epoch in TT: 2000-01-01 12:00:00 TT (JD 2451545.0 TT).
  static const double j2000Epoch = 2451545.0;

  /// Number of seconds in a standard astronomical day.
  static const double secondsPerDay = 86400.0;

  /// Fixed offset between Terrestrial Time and International Atomic Time: $\text{TT} - \text{TAI} = 32.184\text{ s}$.
  static const double ttMinusTaiSeconds = 32.184;

  const AstronomicalTime._({
    required this.jdBase,
    required this.secondOfDay,
    required this.scale,
  });

  /// Factory creating an [AstronomicalTime] directly from a single floating-point Julian Date and explicit [TimeScale].
  factory AstronomicalTime.fromJulianDate(
    double jd, {
    required TimeScale scale,
  }) {
    if (!jd.isFinite) {
      throw ScientificComputationException(
        message: 'Julian Date must be finite numeric value.',
        code: 'NON_FINITE_VALUE',
        context: {'scale': scale.name},
      );
    }

    final z = (jd + 0.5).floorToDouble();
    final base = z - 0.5;
    final frac = jd - base; // [0.0, 1.0)
    final sec = frac * secondsPerDay;

    return AstronomicalTime._(jdBase: base, secondOfDay: sec, scale: scale);
  }

  /// Factory creating an [AstronomicalTime] in UTC from a standard [DateTime].
  ///
  /// The input [dateTime] must be in UTC (`dateTime.isUtc == true`).
  factory AstronomicalTime.fromUtcDateTime(DateTime dateTime) {
    if (!dateTime.isUtc) {
      throw ScientificComputationException(
        message: 'AstronomicalTime constructor requires DateTime in UTC.',
        code: 'TIME_SCALE_INVALID_TIMEZONE',
        context: {'dateTime': dateTime.toIso8601String()},
      );
    }

    final year = dateTime.year;
    final month = dateTime.month;
    final day = dateTime.day;
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final second = dateTime.second;
    final millisecond = dateTime.millisecond;
    final microsecond = dateTime.microsecond;

    // Calculate Julian Day number from Gregorian calendar:
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;

    final jdn =
        day +
        ((153 * m + 2) ~/ 5) +
        365 * y +
        (y ~/ 4) -
        (y ~/ 100) +
        (y ~/ 400) -
        32045;

    // Base JD is at 00:00:00 on this date: JDN - 0.5
    final base = jdn.toDouble() - 0.5;

    // Exact elapsed seconds from 00:00:00:
    final daySec =
        hour * 3600.0 +
        minute * 60.0 +
        second +
        millisecond / 1000.0 +
        microsecond / 1000000.0;

    return AstronomicalTime._(
      jdBase: base,
      secondOfDay: daySec,
      scale: TimeScale.utc,
    );
  }

  /// Total Julian Date as a double floating-point number.
  double get julianDate => jdBase + (secondOfDay / secondsPerDay);

  /// Julian centuries elapsed since J2000.0 in this time scale:
  /// $$T = \frac{JD - 2451545.0}{36525.0}$$
  double get julianCenturiesSinceJ2000 => (julianDate - j2000Epoch) / 36525.0;

  /// Converts this astronomical time to Terrestrial Time ([TimeScale.tt]).
  AstronomicalTime toTerrestrialTime({
    LeapSecondProvider leapSecondProvider = const LeapSecondProvider(),
  }) {
    if (scale == TimeScale.tt) {
      return this;
    }

    if (scale == TimeScale.tai) {
      // TT = TAI + 32.184s
      return _addSeconds(ttMinusTaiSeconds, TimeScale.tt);
    }

    if (scale == TimeScale.utc) {
      final utcDt = toUtcDateTime();
      final taiMinusUtc = leapSecondProvider
          .getTaiMinusUtcSeconds(utcDt)
          .toDouble();
      final totalOffsetSeconds = taiMinusUtc + ttMinusTaiSeconds;
      return _addSeconds(totalOffsetSeconds, TimeScale.tt);
    }

    if (scale == TimeScale.tdb) {
      // Reverse TDB to TT:
      // TDB - TT = delta, so TT = TDB - delta(TT).
      // Since delta < 0.0017s, evaluating delta at TDB yields < 1e-10s error.
      final tdbCenturies = julianCenturiesSinceJ2000;
      final gRad = (357.53 + 35999.05 * tdbCenturies) * (math.pi / 180.0);
      final deltaSec = 0.001657 * math.sin(gRad + 0.0167 * math.sin(gRad));
      return _addSeconds(-deltaSec, TimeScale.tt);
    }

    throw ScientificComputationException(
      message: 'Unsupported source time scale for TT conversion.',
      code: 'UNSUPPORTED_TIME_SCALE',
      context: {'scale': scale.name},
    );
  }

  /// Converts this astronomical time to Barycentric Dynamical Time ([TimeScale.tdb]).
  AstronomicalTime toBarycentricDynamicalTime({
    LeapSecondProvider leapSecondProvider = const LeapSecondProvider(),
  }) {
    if (scale == TimeScale.tdb) {
      return this;
    }

    final tt = toTerrestrialTime(leapSecondProvider: leapSecondProvider);
    final tCenturies = tt.julianCenturiesSinceJ2000;

    // USNO / Fairhead & Bretagnon circular approximation for TDB - TT:
    final gRad = (357.53 + 35999.05 * tCenturies) * (math.pi / 180.0);
    final deltaSec = 0.001657 * math.sin(gRad + 0.0167 * math.sin(gRad));

    return tt._addSeconds(deltaSec, TimeScale.tdb);
  }

  /// Converts this astronomical time to UTC [DateTime].
  ///
  /// If the current scale is not UTC, it is converted to UTC using [leapSecondProvider].
  DateTime toUtcDateTime({
    LeapSecondProvider leapSecondProvider = const LeapSecondProvider(),
  }) {
    if (scale != TimeScale.utc) {
      if (scale == TimeScale.tdb) {
        final tt = toTerrestrialTime(leapSecondProvider: leapSecondProvider);
        return tt.toUtcDateTime(leapSecondProvider: leapSecondProvider);
      }

      if (scale == TimeScale.tt) {
        // Approximate reverse to TAI:
        final tai = _addSeconds(-ttMinusTaiSeconds, TimeScale.tai);
        return tai.toUtcDateTime(leapSecondProvider: leapSecondProvider);
      }

      if (scale == TimeScale.tai) {
        // For TAI to UTC, we must find the leap-second offset.
        // We estimate initial UTC date using approximate offset (37s), look up offset, then refine.
        final roughUtc = _splitToDateTime(jdBase, secondOfDay - 37.0);
        final offset = leapSecondProvider
            .getTaiMinusUtcSeconds(roughUtc)
            .toDouble();
        return _splitToDateTime(jdBase, secondOfDay - offset);
      }
    }

    return _splitToDateTime(jdBase, secondOfDay);
  }

  AstronomicalTime _addSeconds(double seconds, TimeScale targetScale) {
    var newSec = secondOfDay + seconds;
    var baseShift = 0.0;

    while (newSec < 0.0) {
      newSec += secondsPerDay;
      baseShift -= 1.0;
    }
    while (newSec >= secondsPerDay) {
      newSec -= secondsPerDay;
      baseShift += 1.0;
    }

    return AstronomicalTime._(
      jdBase: jdBase + baseShift,
      secondOfDay: newSec,
      scale: targetScale,
    );
  }

  static DateTime _splitToDateTime(double base, double seconds) {
    var effBase = base;
    var effSec = seconds;

    while (effSec < 0.0) {
      effSec += secondsPerDay;
      effBase -= 1.0;
    }
    while (effSec >= secondsPerDay) {
      effSec -= secondsPerDay;
      effBase += 1.0;
    }

    // Integer Julian Day number:
    final jdn = (effBase + 0.5).round();

    // Gregorian calendar inversion:
    final z = jdn;
    int a;
    if (z < 2299161) {
      a = z;
    } else {
      final alpha = ((z - 1867216.25) / 36524.25).floor();
      a = z + 1 + alpha - (alpha ~/ 4);
    }

    final b = a + 1524;
    final c = ((b - 122.1) / 365.25).floor();
    final d = (365.25 * c).floor();
    final e = ((b - d) / 30.6001).floor();

    final day = b - d - (30.6001 * e).floor();
    final month = e < 14 ? e - 1 : e - 13;
    final year = month > 2 ? c - 4716 : c - 4715;

    // Convert seconds to exact time components:
    final totalMicroseconds = (effSec * 1000000.0).round();
    final hours = (totalMicroseconds ~/ 3600000000) % 24;
    final remAfterHours = totalMicroseconds % 3600000000;
    final minutes = remAfterHours ~/ 60000000;
    final remAfterMinutes = remAfterHours % 60000000;
    final secs = remAfterMinutes ~/ 1000000;
    final micros = remAfterMinutes % 1000000;

    return DateTime.utc(
      year,
      month,
      day,
      hours,
      minutes,
      secs,
      micros ~/ 1000,
      micros % 1000,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AstronomicalTime &&
          scale == other.scale &&
          (julianDate - other.julianDate).abs() < 1e-11);

  @override
  int get hashCode => Object.hash(scale, (julianDate * 1e7).round());

  @override
  String toString() =>
      'AstronomicalTime(${julianDate.toStringAsFixed(6)} ${scale.name.toUpperCase()})';
}

import 'dart:math' as math;

import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/astronomical_time.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/models/local_horizon_basis.dart';

/// Topocentric illumination state of the lunar surface observer.
enum SolarIlluminationState {
  /// Sun disc fully above local terrain horizon (continuous direct solar power available).
  directSunlight,

  /// Sun disc partially occluded or within 0.5° of horizon plane (grazing penumbral illumination).
  grazingTwilight,

  /// Sun disc completely below local horizon (lunar night or deep crater floor permanent shadow).
  totalShadow,
}

/// Earth direct-to-Earth (DTE) communication line-of-sight state.
enum EarthVisibilityState {
  /// Earth is above horizon with clear line-of-sight to Deep Space Network.
  directLineOfSight,

  /// Earth is near horizon (0° to 1.5°), subject to severe multipath or terrain grazing.
  marginalVisibility,

  /// Earth is below the local horizontal plane or occulted by topography.
  occulted,
}

/// Instantaneous celestial visibility and lighting state for an observer location.
class CelestialVisibilityState {
  /// Observation epoch.
  final AstronomicalTime epoch;

  /// Topocentric solar elevation angle above local horizontal plane in degrees.
  final double sunElevationDegrees;

  /// Topocentric solar azimuth angle measured clockwise from South/North in degrees [0, 360).
  final double sunAzimuthDegrees;

  /// Solar illumination category.
  final SolarIlluminationState illuminationState;

  /// Incident solar flux at top of lunar atmosphere / surface in W/m^2 (nominal 1361 W/m^2 * sin(elev)).
  final double solarFluxWattsPerM2;

  /// Topocentric Earth elevation angle above local horizontal plane in degrees.
  final double earthElevationDegrees;

  /// Topocentric Earth azimuth angle in degrees [0, 360).
  final double earthAzimuthDegrees;

  /// Earth communication visibility category.
  final EarthVisibilityState earthVisibilityState;

  /// Estimated X/Ka-band direct-to-Earth communication link margin in decibels (dB).
  final double commLinkMarginDb;

  /// Evaluated local horizon orthonormal basis triad.
  final LocalHorizonBasis horizonBasis;

  /// Whether the celestial body vectors are operating in illustrative demonstration mode
  /// pending full offline JPL DE421 ephemeris vector interpolation.
  final bool isDemonstrationEphemeris;

  const CelestialVisibilityState({
    required this.epoch,
    required this.sunElevationDegrees,
    required this.sunAzimuthDegrees,
    required this.illuminationState,
    required this.solarFluxWattsPerM2,
    required this.earthElevationDegrees,
    required this.earthAzimuthDegrees,
    required this.earthVisibilityState,
    required this.commLinkMarginDb,
    required this.horizonBasis,
    this.isDemonstrationEphemeris = true,
  });
}

/// Time interval describing a solar or Earth visibility window.
class VisibilityTimeWindow {
  /// Start time offset in hours from mission epoch.
  final double startHours;

  /// End time offset in hours from mission epoch.
  final double endHours;

  /// Duration of the window in hours.
  double get durationHours =>
      (endHours - startHours).clamp(0.0, double.infinity);

  /// Whether this window has daylight illumination.
  final bool hasSunlight;

  /// Whether this window has direct Earth line of sight.
  final bool hasEarthLineOfSight;

  /// Window classification label.
  final String label;

  const VisibilityTimeWindow({
    required this.startHours,
    required this.endHours,
    required this.hasSunlight,
    required this.hasEarthLineOfSight,
    required this.label,
  });
}

/// Production domain service computing solar illumination, Earth topocentric visibility,
/// and communication link windows for lunar south pole landing sites.
///
/// Combines the rigorously verified [LocalHorizonBasis] and [AstronomicalTime] engines
/// with astronomical polar trigonometric models.
class CelestialVisibilityService {
  const CelestialVisibilityService();

  /// Synodic lunar day duration in hours (~29.530589 days).
  static const double synodicDayHours = 708.734;

  /// Lunar equator inclination to the ecliptic (~1.543°).
  static const double lunarObliquityDeg = 1.5427;

  /// Nominal solar constant at 1 AU in W/m^2.
  static const double solarConstantWPerM2 = 1361.0;

  /// Evaluates instantaneous celestial state for a given selenographic location and time.
  ///
  /// [latitudeDeg]: Selenographic latitude in degrees (e.g. -89.9°).
  /// [longitudeDeg]: Selenographic longitude in degrees (e.g. 0.0°).
  /// [elevationMeters]: Surface elevation relative to mean radius (1,737,400 m).
  /// [epochHours]: Elapsed hours from reference new moon epoch.
  CelestialVisibilityState computeVisibility({
    required double latitudeDeg,
    required double longitudeDeg,
    double elevationMeters = 0.0,
    required double epochHours,
    DateTime? calendarDate,
  }) {
    // 1. Compute rigorous Local Horizon Basis SEZ Triad via Phase 06 M03 domain engine
    final horizonBasis = LocalHorizonBasis.fromCoordinates(
      latitude: Angle.fromDegrees(latitudeDeg),
      longitude: Angle.fromDegrees(longitudeDeg),
    );

    // 2. Evaluate Astronomical Time via Phase 06 M01 engine
    final date =
        calendarDate ??
        DateTime.utc(
          2026,
          9,
          15,
          12,
          0,
        ).add(Duration(milliseconds: (epochHours * 3600 * 1000).round()));
    final utcTime = AstronomicalTime.fromUtcDateTime(date);
    final astroTime = utcTime.toTerrestrialTime(allowExtrapolation: true);

    // 3. Solar kinematics in lunar south polar coordinates:
    // The Moon rotates once in 708.734 hours.
    // Solar longitude increases ~0.508°/hour.
    final solarPhaseAngleRad = (epochHours / synodicDayHours) * 2.0 * math.pi;
    final solarSubLongitudeDeg =
        (epochHours * (360.0 / synodicDayHours)) % 360.0;

    // Sub-solar latitude oscillates by +/- 1.543° over the nodal period
    final solarDeclinationDeg =
        lunarObliquityDeg * math.sin(solarPhaseAngleRad);

    // Relative solar azimuth angle relative to observer's meridian
    final relSolarLonDeg =
        (solarSubLongitudeDeg - longitudeDeg + 360.0) % 360.0;
    final relSolarLonRad = relSolarLonDeg * math.pi / 180.0;
    final latRad = latitudeDeg * math.pi / 180.0;
    final decRad = solarDeclinationDeg * math.pi / 180.0;

    // Spherical trigonometry for topocentric solar elevation:
    // sin(elev) = sin(lat)*sin(dec) + cos(lat)*cos(dec)*cos(H)
    final sinElev =
        math.sin(latRad) * math.sin(decRad) +
        math.cos(latRad) * math.cos(decRad) * math.cos(relSolarLonRad);
    final elevRad = math.asin(sinElev.clamp(-1.0, 1.0));
    final sunElevationDeg = elevRad * 180.0 / math.pi;

    // Azimuth measured from South clockwise towards East
    final cosAz =
        (math.sin(decRad) - math.sin(latRad) * sinElev) /
        (math.cos(latRad) * math.cos(elevRad));
    final sinAz =
        math.cos(decRad) * math.sin(relSolarLonRad) / math.cos(elevRad);
    var azRad = math.atan2(sinAz, cosAz);
    if (azRad < 0) azRad += 2.0 * math.pi;
    final sunAzimuthDeg = azRad * 180.0 / math.pi;

    // Determine illumination state:
    final SolarIlluminationState illumState;
    if (sunElevationDeg >= 0.5) {
      illumState = SolarIlluminationState.directSunlight;
    } else if (sunElevationDeg >= -0.5) {
      illumState = SolarIlluminationState.grazingTwilight;
    } else {
      illumState = SolarIlluminationState.totalShadow;
    }

    final solarFlux = illumState == SolarIlluminationState.totalShadow
        ? 0.0
        : (solarConstantWPerM2 * math.max(0.0, math.sin(elevRad))).clamp(
            0.0,
            solarConstantWPerM2,
          );

    // 4. Earth kinematics in lunar south polar coordinates:
    // Earth hovers at approximately 0° longitude with optical libration (~6.7° in lat, ~8.0° in lon).
    final librationLatDeg =
        6.68 * math.sin(epochHours / (27.21 * 24.0) * 2.0 * math.pi);
    final librationLonDeg =
        7.92 * math.sin(epochHours / (27.55 * 24.0) * 2.0 * math.pi);

    final subEarthLatDeg = librationLatDeg;
    final subEarthLonDeg = librationLonDeg;

    final relEarthLonDeg = (subEarthLonDeg - longitudeDeg + 360.0) % 360.0;
    final relEarthLonRad = relEarthLonDeg * math.pi / 180.0;
    final earthDecRad = subEarthLatDeg * math.pi / 180.0;

    final sinEarthElev =
        math.sin(latRad) * math.sin(earthDecRad) +
        math.cos(latRad) * math.cos(earthDecRad) * math.cos(relEarthLonRad);
    final earthElevRad = math.asin(sinEarthElev.clamp(-1.0, 1.0));
    final earthElevationDeg = earthElevRad * 180.0 / math.pi;

    final cosEarthAz =
        (math.sin(earthDecRad) - math.sin(latRad) * sinEarthElev) /
        (math.cos(latRad) * math.cos(earthElevRad));
    final sinEarthAz =
        math.cos(earthDecRad) *
        math.sin(relEarthLonRad) /
        math.cos(earthElevRad);
    var earthAzRad = math.atan2(sinEarthAz, cosEarthAz);
    if (earthAzRad < 0) earthAzRad += 2.0 * math.pi;
    final earthAzimuthDeg = earthAzRad * 180.0 / math.pi;

    // Determine Earth visibility & comm margin:
    final EarthVisibilityState earthState;
    final double commMargin;
    if (earthElevationDeg >= 2.0) {
      earthState = EarthVisibilityState.directLineOfSight;
      commMargin = 12.0 + (earthElevationDeg * 0.8).clamp(0.0, 6.0); // 12-18 dB
    } else if (earthElevationDeg >= 0.0) {
      earthState = EarthVisibilityState.marginalVisibility;
      commMargin = (earthElevationDeg * 5.0).clamp(0.0, 10.0); // 0-10 dB
    } else {
      earthState = EarthVisibilityState.occulted;
      commMargin = 0.0; // Link blocked
    }

    return CelestialVisibilityState(
      epoch: astroTime,
      sunElevationDegrees: sunElevationDeg,
      sunAzimuthDegrees: sunAzimuthDeg,
      illuminationState: illumState,
      solarFluxWattsPerM2: solarFlux,
      earthElevationDegrees: earthElevationDeg,
      earthAzimuthDegrees: earthAzimuthDeg,
      earthVisibilityState: earthState,
      commLinkMarginDb: commMargin,
      horizonBasis: horizonBasis,
      isDemonstrationEphemeris: true,
    );
  }

  /// Generates a series of time intervals over a duration (e.g. 14 Earth days / 336 hours)
  /// identifying solar daylight and Earth communication coverage windows.
  List<VisibilityTimeWindow> generateMissionWindows({
    required double latitudeDeg,
    required double longitudeDeg,
    double totalDurationHours = 336.0,
    double timeStepHours = 4.0,
  }) {
    final List<VisibilityTimeWindow> windows = [];
    double currentStart = 0.0;
    bool currentSun = false;
    bool currentEarth = false;
    bool isFirst = true;

    for (double t = 0.0; t <= totalDurationHours; t += timeStepHours) {
      final state = computeVisibility(
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg,
        epochHours: t,
      );
      final hasSun =
          state.illuminationState != SolarIlluminationState.totalShadow;
      final hasEarth =
          state.earthVisibilityState != EarthVisibilityState.occulted;

      if (isFirst) {
        currentSun = hasSun;
        currentEarth = hasEarth;
        currentStart = t;
        isFirst = false;
      } else if (hasSun != currentSun || hasEarth != currentEarth) {
        final label = (currentSun && currentEarth)
            ? 'Optimal Operations Window (Sun + Earth Comm)'
            : currentSun
            ? 'Solar Daylight Only (No Direct Earth Comm)'
            : currentEarth
            ? 'Earth Comm Available (Night Shadow)'
            : 'Occulted Shadow (Battery Only)';

        windows.add(
          VisibilityTimeWindow(
            startHours: currentStart,
            endHours: t,
            hasSunlight: currentSun,
            hasEarthLineOfSight: currentEarth,
            label: label,
          ),
        );
        currentSun = hasSun;
        currentEarth = hasEarth;
        currentStart = t;
      }
    }

    if (!isFirst && currentStart < totalDurationHours) {
      final label = (currentSun && currentEarth)
          ? 'Optimal Operations Window (Sun + Earth Comm)'
          : currentSun
          ? 'Solar Daylight Only'
          : currentEarth
          ? 'Earth Comm Available'
          : 'Occulted Shadow';

      windows.add(
        VisibilityTimeWindow(
          startHours: currentStart,
          endHours: totalDurationHours,
          hasSunlight: currentSun,
          hasEarthLineOfSight: currentEarth,
          label: label,
        ),
      );
    }

    return windows;
  }
}

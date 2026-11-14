import 'dart:math' as math;

import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_coordinate_transformer.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_geographic_coordinates.dart';
import 'package:luna_sight/features/scientific_geometry/domain/failures/scientific_computation_exception.dart';
import 'package:luna_sight/features/scientific_geometry/domain/quantities/angle.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/vector3.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/elevation_sample.dart';
import 'package:luna_sight/features/terrain_horizon/domain/models/horizon_profile.dart';

/// Abstract interface for a terrain provider (in-memory tile, mosaic, or DEM cache).
abstract interface class TerrainDataProvider {
  /// Samples elevation in meters at the given geographic coordinates.
  ElevationSample getElevation(Angle latitude, Angle longitude);

  /// Reference sphere radius in meters.
  double get sphereRadiusMeters;
}

/// Scientific engine for computing lunar terrain horizon profiles around an observer.
///
/// Implements rigorous lunar geometric ray-casting taking into account:
/// 1. Lunar spherical curvature ($R = 1,737,400\text{ m}$).
/// 2. Observer instrument height above local terrain ($h_{\text{inst}}$).
/// 3. Geodetic distance and azimuth marching along great circle arcs.
/// 4. Line-of-sight elevation angles calculated in the observer's local topocentric horizon frame:
///    - $\vec{U}$ = Local Zenith unit vector (pointing outward along surface normal).
///    - $\vec{N}$ = Local North unit vector (tangent to meridian towards North pole).
///    - $\vec{E}$ = Local East unit vector ($\vec{N} \times \vec{U}$).
///    - Horizon elevation angle $\theta = \arcsin\left(\frac{\vec{r}_{\text{rel}} \cdot \vec{U}}{\|\vec{r}_{\text{rel}}\|}\right)$.
final class TerrainHorizonEngine {
  final TerrainDataProvider terrainProvider;
  final LunarCoordinateTransformer coordinateTransformer;

  const TerrainHorizonEngine({
    required this.terrainProvider,
    this.coordinateTransformer = const LunarCoordinateTransformer(),
  });

  /// Calculates the 360-degree terrain horizon profile for [request].
  HorizonProfile calculateHorizon(HorizonProfileRequest request) {
    final obsCoords = request.observerCoordinates;
    final r0 = terrainProvider.sphereRadiusMeters;

    // Validate observer coordinate height reference datum against baseline
    obsCoords.heightReference.validateApprovedBaseline();

    // 1. Sample observer local surface elevation
    final obsSample = terrainProvider.getElevation(
      obsCoords.latitude,
      obsCoords.longitude,
    );

    if (!obsSample.isValid) {
      throw ScientificComputationException(
        message:
            'Observer surface elevation cannot be determined from DEM: '
            '${obsSample.status == ElevationSampleStatus.outsideCoverage ? "outside DEM coverage" : "NoData cell at observer coordinates"}.',
        code: obsSample.status == ElevationSampleStatus.outsideCoverage
            ? 'OBSERVER_TERRAIN_OUTSIDE_COVERAGE'
            : 'OBSERVER_TERRAIN_NODATA',
        context: {
          'latitude_deg': obsCoords.latitude.inDegrees,
          'longitude_deg': obsCoords.longitude.inDegrees,
          'sample_status': obsSample.status.name,
        },
      );
    }

    final obsSurfaceElev = obsSample.elevationMeters;
    final obsTotalHeight = obsSurfaceElev + request.instrumentHeightMeters;

    // 2. Compute 3D Cartesian observer position in MOON_ME_DE421
    // Effective radius r = R + h
    final obsEffectiveRadius = r0 + obsTotalHeight;
    final obsGeographic = LunarGeographicCoordinates(
      latitude: obsCoords.latitude,
      latitudeType: obsCoords.latitudeType,
      longitude: obsCoords.longitude,
      longitudeDirection: obsCoords.longitudeDirection,
      longitudeDomain: obsCoords.longitudeDomain,
      heightMeters: obsTotalHeight,
      heightReference: obsCoords.heightReference,
      frame: obsCoords.frame,
    );

    final obsVector = coordinateTransformer
        .toBodyFixedCartesian(obsGeographic)
        .vector;

    // 3. Construct local topocentric horizon frame at observer:
    // Local Up unit vector (radial outward from lunar center of mass):
    final upVec = obsVector.normalize();

    // Local North unit vector:
    // If observer is at South pole or North pole, pick prime meridian direction as North/reference
    Vector3 northVec;
    final latDeg = obsCoords.latitude.inDegrees;
    if (latDeg.abs() > 89.9999) {
      // Polar singularity: project (1, 0, 0) orthogonal to upVec
      final proj =
          Vector3(1.0, 0.0, 0.0) - upVec * Vector3(1.0, 0.0, 0.0).dot(upVec);
      northVec = proj.magnitude > 1e-6
          ? proj.normalize()
          : Vector3(0.0, 1.0, 0.0);
    } else {
      // Towards North pole (0, 0, 1):
      final zAxis = Vector3(0.0, 0.0, 1.0);
      final proj = zAxis - upVec * zAxis.dot(upVec);
      northVec = proj.normalize();
    }

    // Local East unit vector: East = North x Up (in right-handed ENU, East x North = Up)
    final eastVec = northVec.cross(upVec).normalize();

    // 4. Trace radial rays across requested azimuths
    final points = <HorizonPoint>[];
    bool profileComplete = true;

    final numAzimuths = request.azimuthCount;
    final azStep = 360.0 / numAzimuths;

    for (var i = 0; i < numAzimuths; i++) {
      final azDeg = (request.startAzimuth.inDegrees + i * azStep) % 360.0;
      final azRad = azDeg * math.pi / 180.0;

      // Azimuth vector in horizontal plane (clockwise from North):
      // az = 0° -> North, az = 90° -> East, az = 180° -> -North (South), az = 270° -> -East (West)
      final cosAz = math.cos(azRad);
      final sinAz = math.sin(azRad);
      final horizDir = (northVec * cosAz + eastVec * sinAz).normalize();

      var maxElevationAngleRad = -math.pi / 2.0; // Start at -90° (nadir)
      var controllingDistance = 0.0;
      var controllingObstacleElev = obsSurfaceElev;
      var controllingLat = obsCoords.latitude;
      var controllingLon = obsCoords.longitude;
      var rayFullCoverage = true;

      // March along great-circle arc from observer
      final maxDist = request.maxSearchDistanceMeters;
      final stepDist = request.radialStepSizeMeters;

      var currentDist = stepDist;
      while (currentDist <= maxDist) {
        final delta = currentDist / r0;
        final cosDelta = math.cos(delta);
        final sinDelta = math.sin(delta);

        // Position on lunar sphere along geodesic tangent to horizDir:
        final uVec = (upVec * cosDelta + horizDir * sinDelta).normalize();

        // Convert uVec to selenocentric latitude and longitude:
        final phi2 = math.asin(uVec.z.clamp(-1.0, 1.0));
        final lam2 = math.atan2(uVec.y, uVec.x);

        final targetLat = Angle.fromRadians(phi2);
        final targetLon = Angle.fromRadians(lam2);

        // Sample terrain elevation at (targetLat, targetLon)
        final sample = terrainProvider.getElevation(targetLat, targetLon);

        if (!sample.isValid) {
          rayFullCoverage = false;
        } else {
          final terrElev = sample.elevationMeters;
          final terrRadius = r0 + terrElev;

          // 3D Cartesian position of terrain point:
          final terrVector = uVec * terrRadius;

          // Relative position vector from observer to terrain point:
          final relVector = terrVector - obsVector;
          final relDistance = relVector.magnitude;

          if (relDistance > 0.0) {
            // Elevation angle relative to local horizon:
            // sin(theta) = (relVector . upVec) / relDistance
            final sinEl = (relVector.dot(upVec) / relDistance).clamp(-1.0, 1.0);
            final elAngleRad = math.asin(sinEl);

            if (elAngleRad > maxElevationAngleRad) {
              maxElevationAngleRad = elAngleRad;
              controllingDistance = currentDist;
              controllingObstacleElev = terrElev;
              controllingLat = targetLat;
              controllingLon = targetLon;
            }
          }
        }

        currentDist += stepDist;
      }

      if (!rayFullCoverage) {
        profileComplete = false;
      }

      // If no obstacle was higher than geometric depression of horizon over smooth sphere:
      // Geometric dip angle of smooth sphere horizon:
      // cos(dip) = r0 / (r0 + h_inst)
      if (maxElevationAngleRad < -math.pi / 2.0 + 1e-4) {
        // Fallback to geometric horizon dip
        final dipRad = math.acos((r0 / obsEffectiveRadius).clamp(-1.0, 1.0));
        maxElevationAngleRad = -dipRad;
        controllingDistance = math.sqrt(
          obsEffectiveRadius * obsEffectiveRadius - r0 * r0,
        );
      }

      points.add(
        HorizonPoint(
          azimuth: Angle.fromDegrees(azDeg),
          elevationAngle: Angle.fromRadians(maxElevationAngleRad),
          distanceMeters: controllingDistance,
          obstacleElevationMeters: controllingObstacleElev,
          obstacleLatitude: controllingLat,
          obstacleLongitude: controllingLon,
          hasFullCoverage: rayFullCoverage,
        ),
      );
    }

    return HorizonProfile(
      request: request,
      observerSurfaceElevationMeters: obsSurfaceElev,
      observerTotalElevationMeters: obsTotalHeight,
      points: points,
      isComplete: profileComplete,
    );
  }
}

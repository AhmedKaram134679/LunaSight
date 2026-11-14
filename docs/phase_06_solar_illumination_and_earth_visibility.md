# Phase 06 — Solar Illumination and Earth Visibility Engine
## Scientific Architecture, Requirements & Implementation Roadmap

**Project:** LunaSight  
**Repository:** `AhmedKaram134679/LunaSight`  
**Target Branch:** `main`  
**Phase Baseline:** Phase 05 Verified (`6db86bd4c728167dbabc4465059250659f8da80a`)  
**Document Status:** Approved Engineering Design & Implementation Specification  

---

## 1. Executive Summary & Mission Objective

Phase 06 of LunaSight introduces two critical, scientifically rigorous subsystems:
1. **Solar Illumination Engine**: Computes high-precision solar vectors, local topocentric solar azimuth/elevation, geometric vs. terrain-obstructed solar visibility, and sunrise/sunset event intervals across the lunar surface.
2. **Earth Visibility Engine**: Computes topocentric Earth vectors, apparent orientation, finite-disk angular diameter, geometric vs. terrain-obstructed Earth visibility, and Earth-rise/Earth-set communication windows.

This subsystem provides the scientific foundation for mission planning:
- **Surface Power Planning**: Quantifying direct solar irradiance periods and prolonged shadow / cryogenic eclipse intervals.
- **Direct-to-Earth (DTE) Communications**: Predicting geometric line-of-sight and terrain occultation of Earth ground stations from candidate landing sites (e.g., Shackleton crater rim, Malapert Mountain, Connecting Ridge).

All algorithms build upon the verified Phase 04 Scientific Geometry Engine (`MOON_ME_DE421` body-fixed frame) and the Phase 05 Terrain Horizon Engine without compromising or modifying established contracts.

---

## 2. Existing Repository Architecture & Reusability Assessment

### 2.1 Reusable Components
- **`LunarGeographicCoordinates`** (`lib/features/scientific_geometry/domain/coordinates/`): Standard representation of lunar latitude, longitude, datum radius, and height above reference surface.
- **`LunarCoordinateTransformer`** (`lib/features/scientific_geometry/domain/coordinates/`): Deterministic transformation from selenographic coordinates to body-fixed Cartesian position vectors $\mathbf{r}_{\text{obs}} \in \mathbb{R}^3$ in `MOON_ME_DE421`.
- **`Vector3` & `FramedVector3`** (`lib/features/scientific_geometry/domain/value_objects/`): Overflow-safe 3D vector arithmetic, dot/cross products, scaled magnitude/normalization.
- **`Angle` & `Distance`** (`lib/features/scientific_geometry/domain/quantities/`): Strongly typed SI quantity wrappers preventing unit confusion.
- **`HorizonProfile` & `TerrainHorizonEngine`** (`lib/features/terrain_horizon/domain/`): High-resolution terrain horizon profile generator yielding elevation angle $\theta_{\text{terrain}}(\alpha)$ for azimuth $\alpha \in [0^\circ, 360^\circ)$.
- **`ScientificComputationException`**: Typed error handling mechanism with standardized failure codes.

### 2.2 Preserved Scientific Contracts (Phase 04 & 05)
1. **Body-Fixed Selenocentric Reference Frame**: `MOON_ME_DE421` (Mean Earth / Polar Axis frame at J2000 epoch).
2. **Reference Surface**: Spherical lunar datum $R_{\text{moon}} = 1,737,400.0\text{ m}$ (`ReferenceSurfaceId.lunarSphere1737400`).
3. **Observer Height Invariant**: Option A observer height semantics ($r_{\text{obs}} = R_{\text{moon}} + h_{\text{DEM}} + h_{\text{inst}}$). Non-zero coordinate heights ($> 10^{-4}\text{ m}$) remain strictly rejected.
4. **Half-Open Tile Ownership**: $[X_k, X_{k+1}) \times [Y_k, Y_{k+1})$ in Polar Stereographic projection.

---

## 3. Authoritative Scientific References & Coordinate Foundations

### 3.1 Primary Scientific References
1. **NASA / JPL NAIF SPICE Toolkit**:
   - *Lunar Body-Fixed Frames*: `MOON_ME` (Mean Earth/Polar Axis) and `MOON_PA` (Principal Axes).
   - *Ephemerides*: JPL Development Ephemerides (DE421, DE440/DE441).
   - *Solar & Planetary Radii*: IAU Working Group on Cartographic Coordinates and Rotational Elements (Archinal et al., 2018).
2. **Meeus, Jean**: *Astronomical Algorithms* (2nd ed., 1998) — High-accuracy planetary and solar ephemeris series, obliquity, nutation, and coordinate transformations.
3. **NASA SP-8005**: *Solar Electromagnetic Radiation* — Solar constant, angular radius of the Sun at 1 AU ($R_\odot \approx 695,700\text{ km}$, nominal angular radius $\approx 15.96'$).
4. **IERS Technical Note 36**: Conventions for Terrestrial and Celestial Reference Systems.

### 3.2 Time Systems & Scales
Astronomical calculations strictly separate civil time from dynamical time:
- **UTC (Coordinated Universal Time)**: Standard civil time input from user scenarios.
- **TAI (International Atomic Time)**: $\text{TAI} = \text{UTC} + \Delta\text{AT}$ (leap seconds table).
- **TT (Terrestrial Time)**: $\text{TT} = \text{TAI} + 32.184\text{ s}$.
- **TDB (Barycentric Dynamical Time)**: Used for solar system ephemerides; related to TT by relativistic periodic terms ($|\text{TDB} - \text{TT}| < 0.0017\text{ s}$, negligible for topocentric surface pointing, but evaluated for ephemeris evaluation).
- **Julian Date**: $\text{JD}_{\text{TT}}$ and Julian Centuries $T = (\text{JD}_{\text{TT}} - 2451545.0) / 36525.0$.

---

## 4. Mathematical & Geometric Contracts

### 4.1 Local Topocentric Horizon Frame (SEZ Frame)
At observer selenographic coordinates $(\varphi, \lambda)$ with surface normal unit vector $\hat{\mathbf{u}}_{\text{up}}$:
- **Up ($\hat{\mathbf{u}}_Z$)**: Local zenith unit vector pointing outward along the geodetic/spherical normal:
  $$\hat{\mathbf{u}}_Z = (\cos\varphi\cos\lambda, \; \cos\varphi\sin\lambda, \; \sin\varphi)$$
- **North ($\hat{\mathbf{u}}_X$ or $\hat{\mathbf{u}}_N$)**: Unit vector tangent to meridian pointing North:
  $$\hat{\mathbf{u}}_N = (-\sin\varphi\cos\lambda, \; -\sin\varphi\sin\lambda, \; \cos\varphi)$$
- **East ($\hat{\mathbf{u}}_Y$ or $\hat{\mathbf{u}}_E$)**: Unit vector tangent to latitude parallel pointing East:
  $$\hat{\mathbf{u}}_E = (-\sin\lambda, \; \cos\lambda, \; 0)$$
- **Exact Pole Handling**: For exact South Pole ($\varphi = -90^\circ$), define $\hat{\mathbf{u}}_N = (1, 0, 0)$ ($0^\circ$ Prime Meridian) and $\hat{\mathbf{u}}_E = (0, 1, 0)$ ($90^\circ\text{E}$ meridian), consistent with Phase 05 polar cardinal azimuth definitions.

### 4.2 Topocentric Direction Vector Transformation
Given target position $\mathbf{r}_{\text{target}}$ (Sun or Earth center) and observer position $\mathbf{r}_{\text{obs}}$ in `MOON_ME_DE421`:
1. **Relative Position Vector**:
   $$\boldsymbol{\rho} = \mathbf{r}_{\text{target}} - \mathbf{r}_{\text{obs}}$$
2. **Topocentric Coordinates**:
   $$\rho_N = \boldsymbol{\rho} \cdot \hat{\mathbf{u}}_N, \quad \rho_E = \boldsymbol{\rho} \cdot \hat{\mathbf{u}}_E, \quad \rho_Z = \boldsymbol{\rho} \cdot \hat{\mathbf{u}}_Z$$
3. **Local Azimuth ($\alpha$)**: Clockwise from North:
   $$\alpha = \operatorname{atan2}(\rho_E, \; \rho_N) \pmod{360^\circ}$$
4. **Local Elevation Angle ($\theta$)**: Angle above local horizontal plane:
   $$\theta = \arcsin\left(\frac{\rho_Z}{\|\boldsymbol{\rho}\|}\right) = \operatorname{atan2}\left(\rho_Z, \; \sqrt{\rho_N^2 + \rho_E^2}\right)$$

### 4.3 Finite-Disk Angular Geometry
Neither the Sun nor Earth is a mathematical point. At topocentric distance $\rho = \|\boldsymbol{\rho}\|$:
- **Target Physical Radius**: $R_{\text{body}}$ ($R_\odot = 695,700\text{ km}$, $R_\oplus = 6,378.137\text{ km}$).
- **Apparent Angular Radius**:
  $$\theta_{\text{semi}} = \arcsin\left(\frac{R_{\text{body}}}{\rho}\right)$$
- **Center Elevation**: $\theta_{\text{center}}$
- **Upper Limb Elevation**: $\theta_{\text{upper}} = \theta_{\text{center}} + \theta_{\text{semi}}$
- **Lower Limb Elevation**: $\theta_{\text{lower}} = \theta_{\text{center}} - \theta_{\text{semi}}$

### 4.4 Terrain Occlusion Integration
From the Phase 05 `HorizonProfile`, let $\theta_{\text{terrain}}(\alpha)$ be the terrain horizon elevation angle interpolated at azimuth $\alpha$:
- **Full Visibility**: $\theta_{\text{lower}} \ge \theta_{\text{terrain}}(\alpha)$ (Entire disk is clear of local terrain).
- **Partial Visibility**: $\theta_{\text{lower}} < \theta_{\text{terrain}}(\alpha) < \theta_{\text{upper}}$ (Disk is partially occulted by terrain).
- **Total Occultation / Shadow**: $\theta_{\text{upper}} \le \theta_{\text{terrain}}(\alpha)$ (Disk is completely occluded).
- **Geometric vs. Terrain Elevation Margin**:
  $$\Delta\theta_{\text{margin}}(\alpha) = \theta_{\text{center}} - \theta_{\text{terrain}}(\alpha)$$

---

## 5. Architectural Design & Module Boundaries

The engine follows Clean Architecture with strict separation between astronomical ephemeris models, local coordinate transformations, and visibility event analyzers.

```
lib/features/solar_earth_visibility/
├── domain/
│   ├── models/
│   │   ├── astronomical_time.dart           # Julian dates, TT, UTC, TDB representations
│   │   ├── body_state_vector.dart           # 3D position/velocity in Moon-centered frame
│   │   ├── solar_position_result.dart       # Solar azimuth, elevation, distance, angular radius
│   │   ├── earth_position_result.dart       # Earth azimuth, elevation, distance, angular radius
│   │   ├── visibility_state.dart            # Full, Partial, Occulted, BelowHorizon enums
│   │   ├── illumination_interval.dart       # Continuous illumination & darkness time windows
│   │   └── visibility_window.dart           # Earth communication line-of-sight time windows
│   ├── services/
│   │   ├── celestial_ephemeris_provider.dart # Abstract contract for planetary positions
│   │   ├── local_topocentric_converter.dart # Body-fixed to SEZ azimuth/elevation math
│   │   ├── solar_illumination_engine.dart   # Solar position, terrain occlusion & events
│   │   └── earth_visibility_engine.dart     # Earth position, disk occultation & DTE events
│   └── failures/
│       └── visibility_computation_failure.dart # Typed domain exceptions
├── data/
│   ├── ephemeris/
│   │   ├── analytic_lunar_solar_ephemeris.dart # High-precision Meeus/Brown ephemeris provider
│   │   └── spice_sampled_ephemeris_provider.dart # Precomputed SPICE oracle table provider
│   └── repositories/
│       └── visibility_analysis_repository_impl.dart
└── presentation/ (Future milestone)
```

---

## 6. Implementation Roadmap

### Milestone 01 — Scientific Requirements & Reference Research (Current Deliverable)
- Authoritative documentation of coordinate systems, time conversions, ephemeris specifications, and geometric contracts.
- Explicit acceptance criteria and validation strategy.

### Milestone 02 — Shared Astronomical Infrastructure & Time Models
- Implement `AstronomicalTime` (UTC $\leftrightarrow$ Julian Date $\leftrightarrow$ TT $\leftrightarrow$ TDB).
- Implement `CelestialEphemerisProvider` interface and verified high-precision analytical solar/lunar ephemerides.
- Unit test suite comparing analytical ephemerides against NASA Horizons / SPICE reference vectors.

### Milestone 03 — Local Topocentric Coordinate Transformation
- Implement `LocalTopocentricConverter` transforming `MOON_ME_DE421` vectors to SEZ local horizon frame.
- Validate azimuth/elevation transformations across equator, mid-latitudes, and exact lunar poles.

### Milestone 04 — Solar Geometry & Illumination Engine
- Implement `SolarIlluminationEngine` computing geometric solar coordinates and semi-diameter.
- Integrate with Phase 05 `TerrainHorizonEngine` to evaluate terrain occlusion and solar margin.
- Implement sunrise and sunset event root-finding over configurable time spans.

### Milestone 05 — Earth Geometry & Finite-Disk Visibility Engine
- Implement `EarthVisibilityEngine` computing Earth topocentric vector, distance, and angular diameter.
- Implement finite-disk limb clipping against the terrain horizon profile.
- Distinguish complete, partial, and occulted Earth states for DTE communication analysis.

### Milestone 06 — Time-Series Illumination & Visibility Windows
- Implement interval aggregators for continuous sunlight, shadowed cryogenic storage, and Earth visibility passes.
- Optimize search step sizing and bisection root-finding for transition event boundaries.

### Milestone 07 — Comprehensive SPICE Validation & Milestone Closure
- Run automated verification against SPICE test vectors covering critical lunar exploration sites (South Pole, Shackleton, Malapert).
- Full regression testing, static analysis, and Phase 06 closure documentation.

---

## 7. Validation Strategy & Numerical Test Oracle

### 7.1 Independent Reference Oracle (NASA SPICE)
To guarantee scientific defensibility:
- Generate independent test vectors using NASA NAIF SPICE (`spicelib` / `spiceypy`) with kernels:
  - Ephemeris: `de440.bsp` / `de421.bsp`
  - Planetary constants: `pck00010.tpc`
  - Lunar frame: `moon_pa_de421_1900-2050.bpc` and `moon_080317.tf`
- Test vectors will encompass:
  1. **Shackleton Rim** ($89.9^\circ\text{S}, 0.0^\circ\text{E}$): Low solar grazing angles ($< 2^\circ$), permanent shadow pockets.
  2. **Equatorial Mare Tranquillitatis** ($0.67^\circ\text{N}, 23.47^\circ\text{E}$): Full $0^\circ \to 90^\circ$ solar transit, overhead Earth disk.
  3. **South Pole Connecting Ridge**: Long-duration solar illumination windows.

### 7.2 Numerical Acceptance Tolerances
- **Time Conversion Invariants**: $|\text{JD}_{\text{computed}} - \text{JD}_{\text{reference}}| < 10^{-7}\text{ days}$ ($< 0.01\text{ s}$).
- **Solar Position**: Topocentric azimuth and elevation within $0.05^\circ$ ($3'$) of SPICE DE421 over the operational epoch range 2024–2035.
- **Earth Position & Libration**: Topocentric position within $0.05^\circ$ of SPICE DE421.
- **Finite-Disk Angular Diameter**: Within $0.001^\circ$ ($3.6''$).
- **Sunrise / Sunset Timing**: Event detection within $60\text{ seconds}$ of numerical bisection ground truth.

---

## 8. Risk Assessment & Unresolved Questions

| Risk / Question | Impact | Mitigation Strategy |
| :--- | :--- | :--- |
| **Lunar Physical Libration Complexity** | Libration alters Earth pointing by up to $\sim 8^\circ$ in latitude and longitude, directly affecting Earth visibility near the limbs. | Must use an ephemeris model that incorporates lunar libration (e.g. Meeus Chapter 53 or sampled DE421 orientation matrix) rather than a mean tidally-locked sphere. |
| **Ephemeris Data Volume in Mobile App** | Full SPICE BSP kernels are tens of megabytes, undesirable for lightweight app bundles. | Implement a dual-layer strategy: compact high-order analytical Chebyshev polynomials / truncated planetary series for core mobile runtime; validated against SPICE reference tables. |
| **Horizon Profile Angular Resolution** | Phase 05 default is 360 rays ($1^\circ$ azimuth resolution). The Sun's diameter is $\sim 0.53^\circ$. | Interpolate between horizon rays using linear or cubic spline interpolation to prevent stepped horizon artifacts during solar transit. |
| **Refraction on the Moon** | Negligible ($< 10^{-12}\text{ atm}$). | Document explicitly that atmospheric refraction is exactly zero on the lunar surface. |

---

## 9. Conclusion & Immediate Next Implementation Task

Phase 06 scientific requirements, mathematical contracts, and Clean Architecture modular boundaries have been established.

**Immediate Next Task (Milestone 02)**:
Implement the core astronomical time conversion engine (`AstronomicalTime`) and high-precision celestial vector contracts in `lib/features/solar_earth_visibility/domain/models/astronomical_time.dart`, accompanied by independent unit tests verifying Julian Date, TT, and century epoch transformations.

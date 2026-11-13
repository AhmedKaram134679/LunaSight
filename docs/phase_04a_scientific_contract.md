# Phase 04A — Scientific Geometry Engine: Scientific Contract & Architectural Specification

**Document Version:** 1.0.0  
**Phase:** Phase 04A (Specification & Scientific Architecture)  
**Status:** DRAFT / UNDER REVIEW (Documentation & Contract Specification Only — Zero Runtime Implementation)  
**Approved Baseline Commit:** `5df85aab120e314e0e8db195a87fd22f8f4f14af` (Phase 02 Approved)  
**Phase 03 Base Commit:** `ede270cddbed7fe8f43e738550d9667e1c20f7fb`

---

## 1. Purpose and Scope

### 1.1 Purpose
This document establishes the implementation-independent scientific contract, coordinate reference definitions, time-scale semantics, quantity units, and architectural boundaries for **Phase 04 — Scientific Geometry Engine** of LunaSight.

The Scientific Geometry Engine is responsible for the astrodynamic and selenodetic modeling required to evaluate lunar south pole surface exploration constraints. Its future responsibilities include:
1. Planetary ephemeris ingestion and query abstraction (Sun and Earth positions relative to the Moon).
2. Rigorous transformation between celestial ephemeris reference frames, lunar body-fixed frames, and topocentric local horizon coordinates.
3. Astrometric and geometric vector transformations without false precision or silent unit confusion.
4. Construction of topocentric East-North-Up (ENU) bases at verified or user-defined lunar landing locations.

### 1.2 Scope of Phase 04A
Phase 04A is strictly restricted to **scientific specification, data contract definition, and architectural design**. 
- Zero algorithmic implementation (no vector math classes, no trigonometric transforms, no SPICE bindings).
- Zero runtime code modification.
- Zero mutation of existing approved Phase 01, Phase 02, or Phase 03 components.

---

## 2. Non-Goals

The following activities are strictly out of scope for Phase 04A and Phase 04 generally:

1. **Terrain Horizon Ray-Tracing:** Raycasting against digital elevation models (DEMs) or computing obstructed horizon profile elevation angles is deferred to **Phase 05 (Terrain Horizon Engine)**.
2. **Solar Illumination Time-Series:** Generating illumination persistence windows, shadow fractions, or power generation availability curves is deferred to **Phase 06 (Solar Illumination Analysis)**.
3. **Earth Visibility & Comm Windows:** Direct-to-Earth line-of-sight occultation by regional topography and comms relay windows is deferred to **Phase 07 (Earth Visibility Analysis)**.
4. **Mission Planning & Traverse Routing:** Evaluating landing epochs, battery discharge margins, and surface traverses is deferred to **Phase 08 (Mission Planning)**.
5. **Site Comparison & Multi-Criteria Scoring:** Ranking landing sites against operational thresholds is deferred to **Phase 09 (Site Comparison & Scoring)**.
6. **GeoTIFF Raster Decoding:** Parsing raster bytes, TIFF tags, or floating-point DEM elevation matrices from disk is prohibited in Phase 04.
7. **Ad-Hoc Astrodynamic Approximations:** Implementing simplified Keplerian orbits, circular coplanar Moon approximations, or hardcoded solar position formulas without formal ephemeris provenance is strictly prohibited.

---

## 3. Authoritative Resources

The following official scientific resources, portals, and standards form the authoritative baseline for this contract:

1. **NASA JPL Horizons System:**
   - Portal: [https://ssd.jpl.nasa.gov/horizons/](https://ssd.jpl.nasa.gov/horizons/)
   - Horizons User Manual: [https://ssd.jpl.nasa.gov/horizons/manual.html](https://ssd.jpl.nasa.gov/horizons/manual.html)
   - Horizons API Documentation: [https://ssd-api.jpl.nasa.gov/doc/horizons.html](https://ssd-api.jpl.nasa.gov/doc/horizons.html)
   - *Authority:* NASA Jet Propulsion Laboratory / Solar System Dynamics Group.
2. **NASA Planetary Geodesy Data Archive (PGDA):**
   - Product 81 (South Pole LOLA DEM Mosaic 87°S–90°S, 5 m/pix): [https://pgda.gsfc.nasa.gov/products/81](https://pgda.gsfc.nasa.gov/products/81)
   - Product 78 (High-Resolution LOLA Topography for Lunar South Pole Sites): [https://pgda.gsfc.nasa.gov/products/78](https://pgda.gsfc.nasa.gov/products/78)
   - *Authority:* NASA Goddard Space Flight Center (GSFC) Planetary Geodynamics Laboratory.
3. **USGS Lunar Data Interoperability Standards:**
   - Standards Portal: [https://psdi.astrogeology.usgs.gov/moon/standards/data_standards/](https://psdi.astrogeology.usgs.gov/moon/standards/data_standards/)
   - *Authority:* USGS Astrogeology Science Center / Planetary Spatial Data Infrastructure (PSDI).
4. **IAU/IAG Working Group on Cartographic Coordinates and Rotational Elements (WGCCRE):**
   - Arch et al., 2018 / 2024 Reports on cartographic coordinates and rotational elements of the Moon and planets.
   - *Authority:* International Astronomical Union (IAU) & International Association of Geodesy (IAG).
5. **NASA Moon Trek & LROC Quickmap:**
   - NASA Moon Trek: [https://trek.nasa.gov/moon/](https://trek.nasa.gov/moon/) (NASA Solar System Treks / JPL / SSERVI).
   - QuickMap: [https://quickmap.lroc.asu.edu/](https://quickmap.lroc.asu.edu/) (Applied Physics Laboratory / Arizona State University / NASA LRO).
   - *Provenance Note:* Datasets accessible via Moon Trek and Quickmap originate from diverse instrument teams (e.g., LOLA from GSFC, LROC from ASU/MSSS, Kaguya TC/LALT from JAXA). Every ingested layer must cite its specific producer, dataset ID, and reference frame rather than generic portal attribution.
6. **Canadian Space Agency (CSA) Moon Exploration:**
   - Portal: [https://www.asc-csa.gc.ca/eng/astronomy/moon-exploration/](https://www.asc-csa.gc.ca/eng/astronomy/moon-exploration/)
   - *Authority:* Canadian Space Agency (CSA-ASC) science objectives and rover exploration operational contexts.

---

## 4. Existing Approved Scientific Contracts

Phase 04A preserves and builds upon the previously approved Phase 02 and Phase 03 data contracts without modification:

| Parameter / Contract | Approved Phase 02 Baseline (`ldem_87s_5mpp`) | Approved Phase 03 Baseline (`lunar_sites`) | Status |
|:---|:---|:---|:---:|
| **Planetary Body** | Moon (Earth's Moon, NAIF ID `301`) | Moon (Earth's Moon, NAIF ID `301`) | **PROJECT CONTRACT** |
| **Product Identifier** | `ldem_87s_5mpp` (NASA PGDA Product 81) | NASA PGDA Product 78 Catalog (27 regions) | **PROJECT CONTRACT** |
| **Reference Frame** | `MOON_ME` (Mean Earth/Polar Axis) | `MOON_ME` aligned reference | **PROJECT CONTRACT** |
| **Ephemeris Association**| `DE421` (JPL Planetary & Lunar Ephemeris DE421) | `DE421` (Barker et al., 2016, 2021) | **PROJECT CONTRACT** |
| **Horizontal Projection**| South Polar Stereographic | Selenographic Latitude / Longitude | **PROJECT CONTRACT** |
| **Horizontal Coordinates**| Meters ($X, Y$), Generic Mapping Tools convention | Degrees (°), explicit directional convention | **PROJECT CONTRACT** |
| **Pixel Registration**| `PixelRegistration.pixelRegistered` (pixel center) | Bounding box / Footprint (`coordinates: null`) | **PROJECT CONTRACT** |
| **Vertical Measurement**| Surface height $Z$ in meters | Surface elevation $Z$ in meters (optional) | **PROJECT CONTRACT** |
| **Reference Datum** | Mean Lunar Sphere ($R = 1,737,400\text{ m}$) | Mean Lunar Sphere ($R = 1,737,400\text{ m}$) | **PROJECT CONTRACT** |
| **Spatial Resolution** | 5.0 meters/pixel | 5.0 meters/pixel (Product 78 regional sets) | **PROJECT CONTRACT** |

---

## 5. Units and Quantity Semantics

### 5.1 Canonical Internal Units
To prevent catastrophic unit confusion (such as adding kilometers to meters or treating degrees as radians), the LunaSight geometry engine defines **strict, canonical internal representations**:

- **Distance / Length:** Meter ($\text{m}$)
- **Position Vector Components:** Meter ($\text{m}$)
- **Velocity Vector Components:** Meter per second ($\text{m/s}$)
- **Plane Angle:** Radian ($\text{rad}$)
- **Time:** Continuous elapsed seconds since standard epoch ($\text{s}$) with explicit time scale.

### 5.2 Strongly-Typed Quantities
Never allow a bare, unadorned Dart `double` to represent an ambiguous physical quantity across architectural boundaries. The domain model shall encapsulate physical dimensions into explicit immutable value classes:
- `Distance`: Internal value in meters; factory constructors for `Distance.fromMeters(double)` and `Distance.fromKilometers(double)`.
- `Angle`: Internal value in radians; factory constructors for `Angle.fromRadians(double)` and `Angle.fromDegrees(double)`.
- `Velocity`: Internal value in meters/second; factory constructors for `Velocity.fromMetersPerSecond(double)` and `Velocity.fromKilometersPerSecond(double)`.

### 5.3 Conversion Boundary Invariants
All I/O boundaries (JPL Horizons REST responses, user input forms, PDS labels) must perform immediate typed conversion:
- Kilometer inputs from Horizons vectors ($\text{km}$) $\rightarrow \times 1,000.0 \rightarrow$ canonical meters ($\text{m}$).
- Degree inputs from Horizons observer tables (AZ/EL in degrees) $\rightarrow \times \frac{\pi}{180.0} \rightarrow$ canonical radians ($\text{rad}$).
- Output display to operators must explicitly re-format to user units (e.g. degrees, km) using dedicated formatters with explicit unit symbols.

*Status: **PROJECT CONTRACT***

---

## 6. Reference Frames and Origins

### 6.1 Frame Identity Contract
A reference frame is **never** defined by a simple string name alone. Compatibility between physical vectors requires identical origin, orientation, ephemeris association, and epoch:

```dart
/// Architectural specification for reference frame identity.
abstract class ReferenceFrameIdentity {
  /// Standard identifier (e.g., 'MOON_ME', 'MOON_PA', 'J2000', 'ICRF').
  String get frameId;

  /// Physical origin / center body (e.g., Lunar Center of Mass '301', Solar System Barycenter '0').
  String get centerBodyId;

  /// Planetary ephemeris generating the frame orientation (e.g., 'DE421', 'DE440').
  String get ephemerisId;

  /// Frame type: inertial or body-fixed rotating.
  FrameDynamics get dynamics;

  /// Fundamental reference epoch (e.g., J2000.0).
  TimeEpoch get referenceEpoch;
}
```

### 6.2 Key Astrodynamic and Selenodetic Frames
1. **`ICRF` / `J2000` (Inertial):**
   - Origin: Solar System Barycenter (`SSB`, NAIF `0`) or Lunar Center of Mass (`Moon`, NAIF `301`).
   - Axes: Space-fixed, non-rotating inertial frame aligned with the International Celestial Reference Frame.
   - Status: **VERIFIED** (JPL Horizons standard inertial output).
2. **`MOON_ME` (Mean Earth / Polar Axis Body-Fixed):**
   - Origin: Lunar Center of Mass (NAIF `301`).
   - $Z$-axis: Mean lunar axis of rotation.
   - $X$-axis: Direction toward the mean center of the Earth-facing lunar disc (mean sub-Earth meridian).
   - $Y$-axis: Completes the right-handed orthogonal system ($Z \times X$), pointing toward 90° East longitude.
   - Association: Used by LOLA DEM products (`ldem_87s_5mpp`, Product 78, Barker et al., 2016, 2021).
   - Status: **VERIFIED** (NASA GSFC PGDA Product 81 specification).
3. **`MOON_PA` (Principal Axes Body-Fixed):**
   - Origin: Lunar Center of Mass (NAIF `301`).
   - Axes: Defined by the Moon's principal axes of inertia.
   - Offset: Rotated relative to `MOON_ME` by approximately 0.04° to 0.05° (~800 meters on the surface).
   - Invariant: `MOON_ME` and `MOON_PA` **cannot be used interchangeably**. Vector operations combining them without explicit rotation are strictly invalid.
   - Status: **VERIFIED** (Arch et al., 2018 WGCCRE report).
4. **Topocentric Local Horizon (SEU / ENU):**
   - Origin: Surface location at specified selenographic latitude $\phi$, longitude $\lambda$, and radial distance $r$.
   - Basis:
     - East ($\hat{E}$): Unit vector tangent to the local parallel, pointing eastward.
     - North ($\hat{N}$): Unit vector tangent to the local meridian, pointing toward the north rotational pole.
     - Up ($\hat{U}$): Unit vector normal to the reference surface (or radial from lunar center), pointing toward the local zenith.
   - Status: **VERIFIED** (Standard topocentric geodetic definition).

---

## 7. Epochs and Time Scales

### 7.1 Time Scale Disambiguation
Astronomical and planetary calculations involve four distinct time scales that must never be conflated:

1. **UTC (Coordinated Universal Time):**
   - Atomic time synchronized with Earth's irregular rotation via discrete leap seconds.
   - Discontinuous across leap seconds.
   - Standard for human calendar time and civil mission schedules.
2. **UT / UT1 (Universal Time):**
   - Direct measure of Earth rotation angle; non-uniform due to tidal friction and core interactions.
3. **TT (Terrestrial Time):**
   - Theoretical uniform time scale of an idealized clock on the geoid.
   - Strict continuous offset from International Atomic Time (TAI): $\text{TT} = \text{TAI} + 32.184\text{ s}$.
4. **TDB (Barycentric Dynamical Time):**
   - Relativistic coordinate time scale evaluated at the Solar System Barycenter.
   - Differs from TT only by periodic relativistic variations ($< 2\text{ ms}$).
   - **Primary independent time variable used by JPL Horizons ephemerides (DE421, DE440, DE441)**.

### 7.2 Time Representation Contract
Dart's built-in `DateTime` represents system clock UTC or local time with microsecond resolution. It has no conception of leap seconds, TDB relativistic corrections, or continuous ephemeris seconds ($ET$).

```dart
/// Pure domain representation of an astronomical calculation epoch.
abstract class TimeEpoch {
  /// Original ISO-8601 string representation from source (e.g. '2026-07-20T12:00:00Z').
  String get sourceTimestamp;

  /// Time scale in which [sourceTimestamp] is defined.
  TimeScale get sourceTimeScale;

  /// Julian Date in TDB (Barycentric Dynamical Time).
  double get julianDateTdb;

  /// Ephemeris seconds past J2000.0 (TDB seconds past 2000-01-01 12:00:00 TDB).
  double get ephemerisSecondsPastJ2000;
}
```

*Status: **PROJECT CONTRACT***

---

## 8. Geometric vs Astrometric vs Apparent Data

When evaluating solar illumination or direct-to-Earth visibility, mixing geometric, astrometric, and apparent vectors introduces systematic angular errors that invalidate terrain horizon analysis.

### 8.1 Data Types Defined
1. **Geometric State Vectors:**
   - Pure instantaneous 3D Cartesian coordinates $(\vec{r}, \vec{v})$ of target relative to observer at epoch $t$.
   - **Zero light-time correction applied.**
   - Physical Euclidean separation: $\Delta \vec{r} = \vec{r}_{\text{target}}(t) - \vec{r}_{\text{obs}}(t)$.
2. **Astrometric Directions (Light-Time Corrected):**
   - Accounts for the finite speed of light ($c$).
   - The observer at epoch $t$ sees the target at the position it occupied at retarded time $t - \tau$, where $\tau = \frac{\|\vec{r}_{\text{target}}(t - \tau) - \vec{r}_{\text{obs}}(t)\|}{c}$.
   - Earth-Moon light time: $\approx 1.25\text{ to }1.35\text{ seconds}$ ($\sim 1\text{ km}$ Earth orbital displacement).
   - Sun-Moon light time: $\approx 499\text{ seconds}$ ($\sim 8.3\text{ minutes}$, $\approx 20.5\text{ arcseconds}$ apparent solar displacement).
3. **Apparent Observer Directions (Light-Time + Stellar Aberration):**
   - Accounts for both light-time delay ($\tau$) and the observer's instantaneous velocity vector relative to the solar system barycenter (stellar aberration).
   - Yields the exact apparent optical vector as observed from the site.
4. **Local Topocentric Angles (Azimuth / Elevation):**
   - Coordinate projection of either geometric, astrometric, or apparent vector onto the observer's local topocentric horizon basis $(\hat{E}, \hat{N}, \hat{U})$.
   - **Azimuth ($\text{AZ}$):** Measured clockwise from True North: North = 0°, East = 90°, South = 180°, West = 270°.
   - **Elevation ($\text{EL}$):** Angle above the local tangent plane: Zenith = +90°, Horizon = 0°, Nadir = -90°.

*Rule:* Never compare apparent topocentric AZ/EL directly against purely geometric vector angles without documented light-time and aberration reconciliation.

*Status: **VERIFIED** (JPL Horizons User Manual §3.2).*

---

## 9. Horizons Input/Output Contract

### 9.1 JPL Horizons Query Parameters
When acquiring ephemerides for the Moon, Sun, and Earth via the NASA JPL Horizons REST API (`https://ssd-api.jpl.nasa.gov/horizons.api`), the query specification must be strictly recorded:

| Parameter | Type / Target | Allowed Values / Configuration | Provenance Rationale |
|:---|:---|:---|:---|
| `COMMAND` | Target Body | `'10'` (Sun), `'399'` (Earth) | Explicit NAIF body ID |
| `CENTER` | Observer / Center | `'coord@301'` (Topocentric site on Moon) or `'@301'` (Moon Center of Mass) | Distinguishes topocentric vs selenocentric |
| `EPHEM_TYPE` | Ephemeris Output | `'VECTORS'` (Cartesian state) or `'OBSERVER'` (Angles/quantities) | Explicit semantic mode |
| `REF_PLANE` | Coordinate Plane | `'FRAME'` (Body-fixed/inertial) or `'ECLIPTIC'` | Prevents equatorial/ecliptic mixing |
| `REF_SYSTEM` | Reference System | `'ICRF'` or `'MOON_ME'` | Explicit frame identity |
| `VEC_CORR` | Vector Corrections | `'NONE'` (geometric), `'LT'` (light-time), `'LT+S'` (light-time + aberration) | Explicit aberration tracking |
| `TIME_TYPE` | Time System | `'UT'` or `'TDB'` | Ephemeris time scale |
| `STEP_SIZE` | Step Interval | User-specified interval (e.g. `'10m'`, `'1h'`) | Calculation resolution |

### 9.2 Horizons Vector Record Contract
Every ingested Horizons vector must capture:
- `targetBodyId`: NAIF integer string (e.g. `'10'`).
- `centerBodyId`: NAIF integer string (e.g. `'301'`).
- `epoch`: `TimeEpoch` (TDB Julian date and ISO-8601 string).
- `positionMeters`: $(X, Y, Z)$ converted from km to meters.
- `velocityMetersPerSecond`: $(\dot{X}, \dot{Y}, \dot{Z})$ converted from km/s to m/s.
- `lightTimeSeconds`: One-way light time $\tau$.
- `correctionSetting`: Enum (`none`, `lightTime`, `lightTimeAndAberration`).
- `referenceFrame`: Resolved frame identity.

*Status: **PROJECT CONTRACT***

---

## 10. Lunar Coordinate and Vertical Datum Contract

### 10.1 Horizontal Coordinates
Selenographic coordinates $(\phi, \lambda)$ represent:
- **Latitude ($\phi$):** Angle measured from the lunar equator, positive North, negative South: $[-90.0°, +90.0°]$.
- **Longitude ($\lambda$):** Angle measured along the equator, with explicit convention:
  - **`eastPositive` (IAU Standard):** Increases eastward from the Prime Meridian ($0° \le \lambda \le 360°$ or $-180° \le \lambda \le +180°$).
  - **`westPositive`:** Used in historical or specific cartographic contexts.
  - Invariant: Longitude convention must be strongly typed using `LongitudeConvention`.

### 10.2 Vertical Datums & Reference Radii
1. **Lunar Reference Sphere (Datum Radius $R_L$):**
   - $R_L = 1,737,400.0\text{ meters}$ ($1,737.4\text{ km}$).
   - Established by IAU/IAG and utilized across LOLA DEM processing (Barker et al., 2016, 2021).
2. **Surface Height ($Z$ / Elevation):**
   - Local surface height relative to the reference sphere:
     $$h = r - R_L$$
     where $r$ is the radial distance from the lunar center of mass (`MOON_ME` origin).
   - Positive $h$: Surface above $1,737.4\text{ km}$ sphere (e.g. Malapert Massif, $+5,000\text{ m}$).
   - Negative $h$: Surface below $1,737.4\text{ km}$ sphere (e.g. Shackleton crater floor, $-3,000\text{ m}$).
3. **Cartesian Selenocentric Position Vector ($\vec{P}_{\text{site}}$ in `MOON_ME`):**
   Assuming a spherical datum with surface elevation $h$:
   $$\vec{P}_{\text{site}} = (R_L + h) \begin{pmatrix} \cos\phi \cos\lambda \\ \cos\phi \sin\lambda \\ \sin\phi \end{pmatrix}$$
   *Note:* South pole regions have $\phi \approx -90°$, so $\sin\phi \approx -1$, $\cos\phi \approx 0$, directing $\vec{P}_{\text{site}}$ strongly along $-Z$.

*Status: **VERIFIED** (NASA PGDA Product 81 & USGS PSDI Lunar Standards).*

---

## 11. Local Horizon Basis Contract

At any lunar landing site with coordinates $(\phi, \lambda)$, a local orthonormal right-handed topocentric basis $\{\hat{E}, \hat{N}, \hat{U}\}$ is defined in `MOON_ME` coordinates:

### 11.1 Basis Vector Definitions
1. **Up Vector ($\hat{U}$):**
   Unit normal to the reference sphere pointing outward toward the local zenith:
   $$\hat{U} = \begin{pmatrix} \cos\phi \cos\lambda \\ \cos\phi \sin\lambda \\ \sin\phi \end{pmatrix}$$
2. **East Vector ($\hat{E}$):**
   Unit vector pointing in the direction of increasing East longitude:
   $$\hat{E} = \begin{pmatrix} -\sin\lambda \\ \cos\lambda \\ 0 \end{pmatrix}$$
   *(Orthogonal to $\hat{U}$: $\hat{E} \cdot \hat{U} = -\sin\lambda \cos\phi \cos\lambda + \cos\lambda \cos\phi \sin\lambda + 0 = 0$)*.
3. **North Vector ($\hat{N}$):**
   Unit vector pointing along the meridian toward the North pole ($Z > 0$):
   $$\hat{N} = \hat{U} \times \hat{E} = \begin{pmatrix} -\sin\phi \cos\lambda \\ -\sin\phi \sin\lambda \\ \cos\phi \end{pmatrix}$$

### 11.2 Polar Singularity Boundary Condition
At the exact rotational South Pole ($\phi = -90.0°$):
- $\cos\phi = 0$, $\sin\phi = -1$.
- $\hat{U} = (0, 0, -1)^T$.
- Meridians converge: Longitude $\lambda$ is undefined.
- **Contract Requirement:** The engine must enforce an explicit singularity check. If $|\phi| \ge 90.0° - \epsilon_{\text{pole}}$ (e.g. $\epsilon_{\text{pole}} = 10^{-7}\text{ rad}$), azimuth reference must either lock to a designated reference meridian (e.g. Prime Meridian $\lambda = 0°$) or raise an explicit domain exception rather than generating `NaN` or dividing by zero.

*Status: **VERIFIED** (Standard geodesy & differential geometry).*

---

## 12. Numerical Safety

Scientific code executing in client or embedded environments must never fail silently, enter infinite loops, or produce contaminated floating-point states.

### 12.1 Floating-Point Non-Finites
- **Strict NaN / Infinity Rejection:** Every method constructing or consuming vectors, distances, angles, or epochs must immediately reject `double.nan`, `double.infinity`, and `double.negativeInfinity`.
- Any non-finite value encountered triggers an immediate `ScientificComputationException` detailing the failed parameter and operation.

### 12.2 Vector Normalization & Degeneracy
- **Zero-Length Vector:** Attempting to normalize a vector with Euclidean norm $\|\vec{v}\| < \epsilon_{\text{zero}}$ must **not** produce $(\text{NaN}, \text{NaN}, \text{NaN})$.
- **Machine Epsilon Threshold:**
  $$\epsilon_{\text{zero}} = 1.0 \times 10^{-12}\text{ meters}$$
- When $\|\vec{v}\| < \epsilon_{\text{zero}}$, the normalization operation must throw an explicit `DegenerateVectorException` stating that a unit direction is undefined for a zero-magnitude vector.

### 12.3 Angular Domain Clamping
- When calculating dot products for angle extraction ($\theta = \arccos(\hat{a} \cdot \hat{b})$), floating-point rounding errors can cause $\hat{a} \cdot \hat{b} = 1.0000000000000002$ or $-1.0000000000000002$, which causes standard math libraries to return `NaN`.
- **Contract Requirement:** All cosine inputs must be strictly clamped to $[-1.0, +1.0]$ before calling `acos`:
  $$\text{dot}_{\text{clamped}} = \max(-1.0, \min(1.0, \hat{a} \cdot \hat{b}))$$

### 12.4 Zenith / Nadir Azimuth Indeterminacy
- When elevation angle approaches $+90°$ (Zenith) or $-90°$ (Nadir), horizontal projection norm approaches zero: $\|\vec{r}_{\text{horiz}}\| \to 0$.
- Azimuth angle is mathematically undefined at the zenith and nadir.
- **Contract Requirement:** If $\cos(\text{EL}) < 1.0 \times 10^{-6}$, azimuth calculation must return an explicit `AzimuthIndeterminate` result or fall back to a documented convention (e.g. $0.0°$), accompanied by an explicit status flag.

*Status: **PROJECT CONTRACT***

---

## 13. Data Provenance

To guarantee verifiable repeatability in mission planning calculations, all geometry data ingested or computed in LunaSight must record full provenance:

1. **Source Attribution:** Exact origin system (e.g. `JPL_HORIZONS_API_V1`, `NASA_PGDA_PRODUCT_81`).
2. **Ephemeris Version:** Specific ephemeris release used (e.g. `DE421`, `DE440`, `DE441`).
3. **Retrieval Timestamp:** ISO-8601 UTC timestamp of data retrieval.
4. **Digest / Checksum:** Cryptographic SHA-256 hash of raw upstream API payloads stored for auditability.
5. **Zero Fabrication Policy:** If ephemeris data for an epoch or target is missing or network connectivity is unavailable, the engine must return a structured failure (`EphemerisUnavailableFailure`), never an interpolated or fabricated vector.

*Status: **PROJECT CONTRACT***

---

## 14. Independent Verification Strategy

Before any runtime geometry algorithm in Phase 04B is accepted, it must be verified against independent golden datasets:

1. **JPL Horizons Benchmark Tests:**
   - Pre-computed golden test cases queried directly from the live JPL Horizons system for verified epochs (e.g. Lunar South Pole Solstice epochs, Artemis mission milestones).
   - Compare LunaSight's topocentric AZ/EL against Horizons observer tables.
   - Target tolerance: $\Delta\theta \le 0.01°$ ($36\text{ arcseconds}$), accounting for documented light-time and frame conventions.
2. **Analytical Geometric Invariants:**
   - Orthonormality of local basis: $\hat{E} \cdot \hat{N} = 0$, $\hat{E} \cdot \hat{U} = 0$, $\hat{N} \cdot \hat{U} = 0$, $\|\hat{E}\| = \|\hat{N}\| = \|\hat{U}\| = 1$.
   - Right-handed orientation: $\hat{E} \times \hat{N} = \hat{U}$.
   - Equator / Pole invariant vectors: Known analytical vectors at $(0°, 0°)$ and $(-90°, 0°)$.
3. **Frame Rotation Integrity:**
   - Round-trip transformations ($\text{Frame A} \to \text{Frame B} \to \text{Frame A}$) must yield the original vector within $\Delta r < 10^{-6}\text{ m}$.

*Status: **PROPOSED***

---

## 15. Open Scientific Decisions

The following items cannot be settled by guessing and require explicit resolution during future technical reviews:

1. **Ephemeris Generation Reconciliation (DE421 vs DE440):**
   - *Status:* **UNRESOLVED**
   - *Issue:* LOLA DEM products (`ldem_87s_5mpp` and Product 78) are tied to ephemeris `DE421` (Barker et al., 2016, 2021). Current JPL Horizons default ephemerides use `DE440` / `DE441` (Folkner et al., 2020). The positional difference between DE421 and DE440 for lunar orientation and Earth-Moon vectors is typically tens of meters.
   - *Resolution Required:* Determine whether LunaSight will explicitly request `DE421` in Horizons queries (`EPHEM=DE421`) for exact DEM consistency, or ingest `DE440` and apply a documented frame transformation.
2. **Offline Ephemeris Cache Architecture:**
   - *Status:* **UNRESOLVED**
   - *Issue:* LunaSight operates in offline/field environments. Generating accurate Sun/Earth vectors without active internet access requires either:
     a) Caching pre-computed ephemeris tables for discrete mission windows.
     b) Embedding low-degree Chebyshev polynomial approximations (JPL SPK format subset).
   - *Resolution Required:* Architectural selection between pre-computed discrete tabular caching vs compact polynomial evaluation.
3. **Libration & Sub-Earth Vector Modeling:**
   - *Status:* **UNRESOLVED**
   - *Issue:* Lunar optical and physical libration causes the apparent Earth position in the lunar sky to oscillate by up to $\pm 8°$ in latitude and longitude over the draconic and anomalistic months.
   - *Resolution Required:* Confirm whether topocentric Earth elevation angle calculation requires high-order physical libration angles or whether direct difference of Horizons state vectors $(\vec{r}_{\text{Earth}} - \vec{r}_{\text{site}})$ projected onto $(\hat{E}, \hat{N}, \hat{U})$ completely bypasses the need for explicit libration angle series.

---

## 16. Acceptance Criteria

Phase 04A shall be considered complete when:
1. The scientific contract document (`docs/phase_04a_scientific_contract.md`) is fully drafted, internally consistent, and traceable to official NASA/JPL/USGS standards.
2. Every scientific claim is categorized as `VERIFIED`, `PROJECT CONTRACT`, `PROPOSED`, or `UNRESOLVED`.
3. Canonical units, coordinate boundaries, numerical tolerances, and frame identities are comprehensively specified.
4. The project roadmap in `lib/features/home/data/repositories/local_system_module_repository.dart` accurately identifies `Phase 04A` as in-progress specification without altering the approved status of Phases 01, 02, or 03.
5. All automated test suites (`flutter test`) continue to pass with 100% success and zero regressions across Phases 01, 02, and 03.
6. Zero runtime algorithmic code, vector math classes, or ephemeris calculation logic is committed in Phase 04A.


# Phase 04A — Scientific Geometry Engine: Scientific Contract & Architectural Specification

**Document Version:** 1.1.0
**Phase:** Phase 04A (Specification & Scientific Architecture)  
**Status:** DRAFT / UNDER REVIEW (Documentation & Contract Specification Only — Zero Runtime Implementation)  
**Approved Baseline Commit:** `5df85aab120e314e0e8db195a87fd22f8f4f14af` (Phase 02 Approved)  
**Phase 03 Base Commit:** `ede270cddbed7fe8f43e738550d9667e1c20f7fb`

---

## 1. Purpose and Scope

### 1.1 Purpose
This document establishes the implementation-independent scientific contract, coordinate reference definitions, time-scale semantics, quantity units, and architectural boundaries for **Phase 04 — Scientific Geometry Engine** of LunaSight.

The Scientific Geometry Engine is responsible for the astrodynamic and selenodetic modeling required to evaluate lunar south pole surface exploration constraints. Its future responsibilities include:
1. Ingesting planetary ephemeris data (Sun and Earth positions relative to the Moon) with verified provenance and time-scale integrity.
2. Formulating transformations between celestial ephemeris reference frames, lunar body-fixed frames, and topocentric local horizon coordinates.
3. Distinguishing geometric state vectors, astrometric directions, and apparent observer directions without false precision or silent unit confusion.
4. Constructing topocentric East-North-Up (ENU) bases at verified or user-defined lunar landing locations.

### 1.2 Scope of Phase 04A
Phase 04A is strictly restricted to **scientific specification, data contract definition, and architectural design**. 
- Zero algorithmic implementation (no vector math classes, no trigonometric transforms, no SPICE bindings).
- Zero runtime code modification in `lib/`.
- Zero test code modification in `test/` or `integration_test/`.
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

1. **NASA JPL Horizons Ephemeris System:**
   - Web System Portal: [https://ssd.jpl.nasa.gov/horizons/](https://ssd.jpl.nasa.gov/horizons/)
   - Horizons User Manual: [https://ssd.jpl.nasa.gov/horizons/manual.html](https://ssd.jpl.nasa.gov/horizons/manual.html)
   - Official API Documentation: [https://ssd-api.jpl.nasa.gov/doc/horizons.html](https://ssd-api.jpl.nasa.gov/doc/horizons.html)
   - Official API REST Endpoint: `https://ssd.jpl.nasa.gov/api/horizons.api`
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
5. **NASA NAIF / SPICE Lunar Frame Specifications:**
   - Lunar SPICE Kernels Documentation & `moon_de440_220930.tf` Frame Kernel.
   - *Authority:* NASA Navigation and Ancillary Information Facility (NAIF).
6. **NASA Moon Trek & LROC Quickmap:**
   - NASA Moon Trek: [https://trek.nasa.gov/moon/](https://trek.nasa.gov/moon/) (NASA Solar System Treks / JPL / SSERVI).
   - QuickMap: [https://quickmap.lroc.asu.edu/](https://quickmap.lroc.asu.edu/) (Applied Physics Laboratory / Arizona State University / NASA LRO).
   - *Provenance Note:* Datasets accessible via Moon Trek and Quickmap originate from diverse instrument teams (e.g., LOLA from GSFC, LROC from ASU/MSSS, Kaguya TC/LALT from JAXA). Every ingested layer must cite its specific producer, dataset ID, and reference frame rather than generic portal attribution.
7. **Canadian Space Agency (CSA) Moon Exploration:**
   - Portal: [https://www.asc-csa.gc.ca/eng/astronomy/moon-exploration/](https://www.asc-csa.gc.ca/eng/astronomy/moon-exploration/)
   - *Authority:* Canadian Space Agency (CSA-ASC) science objectives and rover exploration operational contexts.

---

## 4. Existing Approved Scientific Contracts

Phase 04A strictly preserves and builds upon the previously approved Phase 02 and Phase 03 data contracts without modification:

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

*Invariant:* The Phase 02 DEM contract (`MOON_ME`, `DE421`, $R = 1,737,400\text{ m}$) remains authoritative for all elevation grid alignments and shall not be silently modified or replaced.

---

## 5. Units and Quantity Semantics

### 5.1 Canonical Internal Units
To prevent unit confusion (such as adding kilometers to meters or treating degrees as radians), the LunaSight geometry engine defines **strict, canonical internal representations**:

- **Distance / Length:** Meter ($\text{m}$)
- **Position Vector Components:** Meter ($\text{m}$)
- **Velocity Vector Components:** Meter per second ($\text{m/s}$)
- **Plane Angle:** Radian ($\text{rad}$)
- **Time:** Continuous elapsed seconds since standard epoch ($\text{s}$) with explicit time scale.

### 5.2 Strongly-Typed Quantities
Never allow an untyped numeric value (`double`) to silently represent a physical quantity across architectural boundaries. The domain model shall encapsulate physical dimensions into explicit immutable value classes:
- `Distance`: Internal value in meters; factory constructors for `Distance.fromMeters(double)` and `Distance.fromKilometers(double)`.
- `Angle`: Internal value in radians; factory constructors for `Angle.fromRadians(double)` and `Angle.fromDegrees(double)`.
- `Velocity`: Internal value in meters/second; factory constructors for `Velocity.fromMetersPerSecond(double)` and `Velocity.fromKilometersPerSecond(double)`.

### 5.3 Conversion Boundary Invariants
All I/O boundaries (JPL Horizons REST responses, user input forms, PDS labels) must perform explicit typed conversion:
- Kilometer inputs from Horizons vectors ($\text{km}$) $\rightarrow \times 1,000.0 \rightarrow$ canonical meters ($\text{m}$).
- Degree inputs from Horizons observer tables (AZ/EL in degrees) $\rightarrow \times \frac{\pi}{180.0} \rightarrow$ canonical radians ($\text{rad}$).
- Output display to operators must format to user units using dedicated formatters with explicit unit symbols.

*Status: **PROJECT CONTRACT***

---

## 6. Reference Frames, Origins, and Realizations

### 6.1 Disambiguation of Frame Identity Concepts
A reference frame is not defined by a simple name string alone. To prevent physical inconsistency, the architecture distinguishes four separate geometric concepts:
1. **Reference Frame Orientation:** The tri-orthogonal spatial directions of the axes (e.g. ICRF space-fixed axes, B1950, or body-fixed axes rotating with the Moon).
2. **Coordinate Origin:** The physical reference point representing $(0, 0, 0)$ (e.g. Solar System Barycenter `0`, Lunar Center of Mass `301`, or a specific topocentric surface station).
3. **Planetary Ephemeris:** The underlying numerical integration of planetary and lunar orbits (e.g. `DE421`, `DE440`, `DE441`).
4. **Reference Epoch:** The epoch at which frame axes are defined (e.g. J2000.0) or of-date.

*Note on ICRF vs J2000:* ICRF (International Celestial Reference Frame) and J2000 (dynamical or FK5 equator and equinox of J2000.0) are **not identical**. ICRF is a radio-source-based kinematically non-rotating celestial frame adopted by the IAU. While the J2000 frame aligns closely with ICRF, they differ at the sub-arcsecond level (~20 mas). Horizons specifies celestial inertial vectors relative to `REF_SYSTEM=ICRF` (or historical `B1950`).

### 6.2 Lunar Body-Fixed Frames and Realizations
1. **Mean Earth / Polar Axis (`MOON_ME`):**
   - $Z$-axis: Mean lunar rotation axis.
   - $X$-axis: Direction toward the mean Earth-facing disc center (mean sub-Earth meridian at 0° longitude).
   - $Y$-axis: Completes right-handed system ($Z \times X$), pointing toward 90° East longitude.
   - Cartographic standard for LOLA DEM products (`ldem_87s_5mpp`, Product 78).
2. **Principal Axes (`MOON_PA`):**
   - Axes aligned with the principal moments of inertia of the Moon.
   - Used natively for dynamical lunar orbit propagation and lunar laser ranging (LLR).
   - Dynamically offset from `MOON_ME` by small, ephemeris-dependent orientation angles.
3. **Ephemeris-Dependent Frame Realizations (`DE421` vs `DE440`):**
   - The Moon's physical orientation depends on the planetary ephemeris integration and physical libration parameters fitted to LLR data.
   - In NAIF SPICE specifications, the DE421 orientation realization is designated `MOON_ME_DE421` (or historical `MOON_ME`).
   - For `DE440`, NAIF defines `MOON_PA_DE440` and `MOON_ME_DE440_ME421` (a Mean Earth frame adjusted by constant rotation offsets to maintain alignment with the DE421 Mean Earth frame).
   - *Status:* **UNRESOLVED** (The exact rotation matrix between DE440 ME realizations and the Phase 02 DE421 DEM frame must be verified before runtime integration).

### 6.3 Frame Transformation Requirements
Vector operations combining coordinates across different origins or frames are strictly prohibited unless a documented transformation is explicitly applied:
- Vectors with different origins must apply translational offset $\vec{r}_{B} = \vec{r}_{A} - \vec{r}_{\text{origin}}$.
- Vectors with different orientations must apply a documented 3x3 rotation matrix $R_{A \to B}$: $\vec{v}_B = R_{A \to B} \vec{v}_A$.
- In the absence of a verified transformation model, the engine must reject cross-frame vector operations.

*Status: **PROJECT CONTRACT***

---

## 7. Epochs and Time Scales

### 7.1 Time Scale Definitions
Astronomical and planetary calculations involve distinct time scales that must never be conflated:

1. **UTC (Coordinated Universal Time):** Civil atomic time with leap seconds; discontinuous at leap second transitions.
2. **UT / UT1 (Universal Time):** Measure of Earth's rotation angle; non-uniform.
3. **TT (Terrestrial Time):** Uniform theoretical time scale of a clock on the geoid: $\text{TT} = \text{TAI} + 32.184\text{ s}$.
4. **TDB (Barycentric Dynamical Time):** Relativistic coordinate time scale evaluated at the Solar System Barycenter; independent time argument of JPL planetary ephemerides (DE421, DE440, DE441). Differs from TT by small periodic variations ($< 2\text{ ms}$).

### 7.2 Time Contract across Horizons Output Types
According to the official JPL Horizons API documentation:
- **`EPHEM_TYPE=OBSERVER`:** The time parameter `TIME_TYPE` accepts **`UT`** (default for Earth/ground observers) or **`TT`**.
- **`EPHEM_TYPE=VECTORS`:** The time parameter `TIME_TYPE` accepts **`TDB`** (default) or **`UT`**.
- **`EPHEM_TYPE=ELEMENTS`:** Outputs are referenced in **`TDB`**.

*Rule:* Every ingested Horizons record must explicitly preserve both the source timestamp string and the specific time scale indicated in the response header (`TDB`, `TT`, or `UT`), without assuming universal TDB conversion.

*Status: **PROJECT CONTRACT***

---

## 8. Geometric vs Astrometric vs Apparent Data

### 8.1 Data Types Defined
1. **Geometric State Vectors:**
   - Instantaneous 3D Cartesian coordinates $(\vec{r}, \vec{v})$ of target relative to observer/center at epoch $t$.
   - Zero light-time correction applied (`VEC_CORR=NONE`).
   - Represents the physical Euclidean separation in space at instant $t$.
2. **Astrometric Directions (Light-Time Corrected):**
   - Target position evaluated at the retarded epoch $t - \tau$, where $\tau = \frac{\Delta r}{c}$ (`VEC_CORR=LT`).
3. **Apparent Observer Observables:**
   - Direction of target as observed by a topocentric station, incorporating:
     - One-way light-time delay ($\tau$).
     - Gravitational deflection of light rays by intervening solar system bodies.
     - Stellar aberration due to observer motion.
     - Precession and nutation of the reference frame, where applicable.
     - Atmospheric refraction (applicable only for observers on planetary bodies with atmospheres; zero for airless lunar surface stations).
   - In Horizons, apparent topocentric angles (Quantity #4: Apparent Azimuth & Elevation) represent these corrected apparent directions.
4. **Local Topocentric Angles (Azimuth / Elevation):**
   - **Azimuth ($\text{AZ}$):** Measured clockwise from True North: North = 0°, East = 90°, South = 180°, West = 270°.
   - **Elevation ($\text{EL}$):** Angle relative to the local horizontal plane: Zenith = +90°, Horizon = 0°, Nadir = -90°.

*Rule:* Apparent AZ/EL observables from Horizons Observer tables cannot be compared directly with purely geometric topocentric vectors unless light-time, aberration, and gravitational deflection corrections are documented and reconciled.

*Status: **VERIFIED** (JPL Horizons User Manual §3.2 & API Specification).*

---

## 9. Horizons Input/Output Contract

### 9.1 Official JPL Horizons API Query Parameters
All automated ephemeris queries must target the official REST endpoint:
`https://ssd.jpl.nasa.gov/api/horizons.api`

The query parameter mapping is governed strictly by the official API specification (`https://ssd-api.jpl.nasa.gov/doc/horizons.html`):

| API Parameter | Role / Definition | Allowed Values in API | LunaSight Architectural Mapping |
|:---|:---|:---|:---|
| `format` | Response encoding | `'json'`, `'text'` | Always `'json'` |
| `COMMAND` | Target body designation | Small-body name, SPK ID, or NAIF ID (e.g. `'10'` for Sun, `'399'` for Earth) | Strongly-typed NAIF target ID |
| `EPHEM_TYPE` | Ephemeris mode | `'OBSERVER'`, `'VECTORS'`, `'ELEMENTS'`, `'SPK'` | `'VECTORS'` for Cartesian states; `'OBSERVER'` for topocentric AZ/EL |
| `CENTER` | Origin / Observer location | Body ID (e.g. `'@301'` for Moon center, `'500@399'` for geocenter) or `'coord@301'` for custom topocentric surface site | Explicit center identifier |
| `COORD_TYPE` | Coordinate type for site | `'GEODETIC'` or `'CYLINDRICAL'` | Required when `CENTER='coord@...'` |
| `SITE_COORD` | Surface site coordinates | Comma-separated string `'<lon>,<lat>,<alt>'` | Longitude (° East), Latitude (°), Altitude ($\text{km}$) relative to reference spheroid |
| `REF_SYSTEM` | Reference system | `'ICRF'` (default) or `'B1950'` | Always `'ICRF'`. *Note: `MOON_ME` is NOT a valid `REF_SYSTEM` parameter.* |
| `REF_PLANE` | Reference plane for vectors | `'FRAME'`, `'ECLIPTIC'`, or `'BODY EQUATOR'` | `'FRAME'` for ICRF-aligned; `'BODY EQUATOR'` for body equator and equinox |
| `VEC_CORR` | Vector correction level | `'NONE'` (geometric), `'LT'` (light-time), `'LT+S'` (light-time + aberration) | Explicitly captured per vector request |
| `TIME_TYPE` | Time scale interpretation | For Observer: `'UT'`, `'TT'`. For Vectors: `'TDB'`, `'UT'` | Explicitly specified and tracked |
| `QUANTITIES` | Observer table quantities | Comma-separated integer codes (e.g. `'4'` for Apparent AZ/EL, `'20'` for range) | Used exclusively for `EPHEM_TYPE=OBSERVER` |
| `START_TIME`, `STOP_TIME`, `STEP_SIZE` | Epoch interval specification | ISO-8601 or Julian date strings; step syntax (e.g. `'1h'`, `'10m'`) | Ephemeris query interval |

*Correction Note:* Previous draft incorrectly suggested `REF_SYSTEM='MOON_ME'` and an unverified parameter `EPHEM=DE421`. The official Horizons API only supports `REF_SYSTEM` as `ICRF` or `B1950`, does not support `MOON_ME` in `REF_SYSTEM`, and has no `EPHEM` parameter.

### 9.2 Topocentric Site Definition in Horizons (`coord@301`)
When querying topocentric quantities from a lunar landing site:
1. `CENTER` must be set to `'coord@301'`.
2. `COORD_TYPE` must be specified as `'GEODETIC'` (or `'CYLINDRICAL'`).
3. `SITE_COORD` must provide three comma-separated numeric values:
   $$\text{SITE\_COORD} = '\lambda, \phi, h_{\text{km}}'$$
   - $\lambda$: Selenographic Longitude in degrees East ($0° \le \lambda \le 360°$ or $-180° \le \lambda \le +180°$).
   - $\phi$: Selenographic Latitude in degrees ($[-90°, +90°]$).
   - $h_{\text{km}}$: Altitude in **kilometers** above the reference body datum.
4. *Source Units Note:* Horizons requires altitude in kilometers ($\text{km}$), while LunaSight internal units are meters ($\text{m}$). Conversion boundary must divide internal meters by $1,000.0$ before constructing the `SITE_COORD` parameter.

*Status: **VERIFIED** (NASA JPL Horizons API Documentation).*

---

## 10. Lunar Coordinate and Vertical Datum Contract

### 10.1 Horizontal Coordinates
Selenographic coordinates $(\phi, \lambda)$ represent:
- **Latitude ($\phi$):** Angle measured from the lunar equator, positive North, negative South: $[-90.0°, +90.0°]$.
- **Longitude ($\lambda$):** Angle measured along the equator with explicit directional convention:
  - **`eastPositive` (IAU Standard):** Increases eastward from the Prime Meridian.
  - **`westPositive`:** Increases westward.
  - Invariant: Longitude convention must be strongly typed using `LongitudeConvention`.

### 10.2 Vertical Datums & Reference Radii
1. **Lunar Reference Sphere (Datum Radius $R_L$):**
   - $R_L = 1,737,400.0\text{ meters}$ ($1,737.4\text{ km}$).
   - Established by IAU/IAG and utilized across LOLA DEM processing (Barker et al., 2016, 2021).
2. **Surface Height ($Z$ / Elevation):**
   - Local surface height relative to the reference sphere:
     $$h = r - R_L$$
     where $r$ is the radial distance from the lunar center of mass (`MOON_ME` origin).
   - Positive $h$: Surface above $1,737.4\text{ km}$ sphere.
   - Negative $h$: Surface below $1,737.4\text{ km}$ sphere.
3. **Cartesian Selenocentric Position Vector ($\vec{P}_{\text{site}}$ in `MOON_ME`):**
   Under a spherical datum approximation with surface elevation $h$:
   $$\vec{P}_{\text{site}} = (R_L + h) \begin{pmatrix} \cos\phi \cos\lambda \\ \cos\phi \sin\lambda \\ \sin\phi \end{pmatrix}$$

*Status: **VERIFIED** (NASA PGDA Product 81 & USGS PSDI Lunar Standards).*

---

## 11. Local Horizon Basis Contract

At any lunar landing site with coordinates $(\phi, \lambda)$, a local orthonormal topocentric basis $\{\hat{E}, \hat{N}, \hat{U}\}$ is formulated in `MOON_ME` coordinates:

### 11.1 Basis Vector Definitions
1. **Up Vector ($\hat{U}$):**
   Radial unit vector normal to the reference sphere pointing outward toward local zenith:
   $$\hat{U} = \begin{pmatrix} \cos\phi \cos\lambda \\ \cos\phi \sin\lambda \\ \sin\phi \end{pmatrix}$$
2. **East Vector ($\hat{E}$):**
   Unit vector pointing in the direction of increasing East longitude:
   $$\hat{E} = \begin{pmatrix} -\sin\lambda \\ \cos\lambda \\ 0 \end{pmatrix}$$
3. **North Vector ($\hat{N}$):**
   Unit vector pointing along the meridian toward the North rotational pole ($Z > 0$):
   $$\hat{N} = \hat{U} \times \hat{E} = \begin{pmatrix} -\sin\phi \cos\lambda \\ -\sin\phi \sin\lambda \\ \cos\phi \end{pmatrix}$$

### 11.2 Polar Singularity Boundary Condition
At the exact rotational South Pole ($\phi = -90.0°$):
- $\cos\phi = 0$, $\sin\phi = -1$.
- $\hat{U} = (0, 0, -1)^T$.
- Meridians converge: Longitude $\lambda$ is geometrically undefined.
- **Contract Requirement:** The engine must enforce an explicit singularity check when $|\phi|$ approaches $90.0°$. The exact numerical angular threshold $\epsilon_{\text{pole}}$ and meridian tie convention are classified as **PROPOSED** until verified with numerical test cases.

*Status: **VERIFIED** (Standard geodesy).*

---

## 12. Numerical Safety and Verification Evidence Requirements

Scientific calculations must never fail silently or produce undefined floating-point states.

### 12.1 Mandatory Invariants
1. **Strict Non-Finite Rejection [PROJECT CONTRACT]:**
   - Every class, constructor, and method handling physical quantities must reject `double.nan`, `double.infinity`, and `double.negativeInfinity`.
   - Violations immediately throw a structured domain failure (`ScientificComputationException`).
2. **Angular Domain Clamping [PROJECT CONTRACT]:**
   - Floating-point dot products between normalized vectors can slightly exceed $[-1.0, +1.0]$ due to precision roundoff (e.g. $1.0000000000000002$), causing `acos` to return `NaN`.
   - All dot products passed to `acos` must be clamped to $[-1.0, +1.0]$:
     $$\text{clamped} = \max(-1.0, \min(1.0, \hat{a} \cdot \hat{b}))$$

### 12.2 Numerical Thresholds Status & Verification Evidence
Previous draft listed arbitrary thresholds without documented derivations. All numerical threshold values are categorized below with their required verification evidence:

| Threshold / Parameter | Proposed Value | Category | Required Verification Evidence |
|:---|:---:|:---:|:---|
| **Zero-Vector Norm Threshold** ($\epsilon_{\text{zero}}$) | $1.0 \times 10^{-12}\text{ m}$ | **PROPOSED** | Derive against 64-bit IEEE 754 precision for lunar scale ($\sim 2 \times 10^6\text{ m}$) and verify that vectors smaller than this produce explicit exceptions without underflow. |
| **Polar Singularity Angle** ($\epsilon_{\text{pole}}$) | $1.0 \times 10^{-7}\text{ rad}$ | **PROPOSED** | Compare topocentric basis stability within $0.2\text{ meters}$ of true pole against IAU polar cartographic standards. |
| **Zenith Azimuth Indeterminacy** ($\cos\text{EL}$) | $1.0 \times 10^{-6}$ | **PROPOSED** | Evaluate angular resolution limits where horizontal projection norm loss produces numerical jitter in $\text{atan2}(E, N)$. |
| **Horizons Acceptance Tolerance** ($\Delta\theta$) | $0.01°$ ($36''$) | **UNRESOLVED** | Perform empirical benchmark comparison between Horizons topocentric observer tables and local vector projections across varying light-time and aberration modes. |
| **Round-Trip Frame Transform Loss** ($\Delta r$) | $1.0 \times 10^{-6}\text{ m}$ | **PROPOSED** | Test matrix inversion precision $R^T R = I$ across 10,000 random spatial rotations using IEEE 754 double precision. |

*Rule:* None of the above proposed thresholds shall become locked project contracts until the specified verification tests have been executed and documented.

---

## 13. Data Provenance

To guarantee repeatability in mission planning calculations, all geometry data ingested or computed in LunaSight must record full provenance:

1. **Source Attribution:** Exact origin system (e.g. `JPL_HORIZONS_API_V1`, `NASA_PGDA_PRODUCT_81`).
2. **Ephemeris Version:** Specific ephemeris release noted in source headers (e.g. `DE440`, `DE441`, `DE421`).
3. **Retrieval Timestamp:** ISO-8601 UTC timestamp of data retrieval.
4. **Digest / Checksum:** Cryptographic SHA-256 hash of raw upstream API payloads stored for auditability.
5. **Zero Fabrication Policy:** If ephemeris data for an epoch or target is missing or network connectivity is unavailable, the engine must return a structured failure (`EphemerisUnavailableFailure`), never an interpolated or fabricated vector.

*Status: **PROJECT CONTRACT***

---

## 14. Independent Verification Strategy

Before any runtime geometry algorithm in Phase 04B is accepted, it must be verified against independent golden datasets:

1. **JPL Horizons Benchmark Tests [PROPOSED]:**
   - Query Horizons REST API for verified epochs (e.g. Lunar South Pole Solstice epochs, Artemis III candidate illumination windows).
   - Compare LunaSight topocentric AZ/EL against Horizons Observer Table Quantity #4.
2. **Analytical Geometric Invariants [PROPOSED]:**
   - Orthonormality of local basis: $\hat{E} \cdot \hat{N} = 0$, $\hat{E} \cdot \hat{U} = 0$, $\hat{N} \cdot \hat{U} = 0$, $\|\hat{E}\| = \|\hat{N}\| = \|\hat{U}\| = 1$.
   - Right-handed orientation: $\hat{E} \times \hat{N} = \hat{U}$.
   - Equator and Pole analytical vectors: Known analytical vectors at $(0°, 0°)$ and $(-90°, 0°)$.
3. **Frame Rotation Invariants [PROPOSED]:**
   - Round-trip transformation matrix verification: $\|R^T R - I\| < \epsilon_{\text{ortho}}$.

---

## 15. Open Scientific Decisions

The following items cannot be settled by guessing and require explicit resolution during future technical reviews:

1. **Ephemeris Generation Reconciliation (DE421 vs DE440):**
   - *Status:* **UNRESOLVED**
   - *Issue:* LOLA DEM products (`ldem_87s_5mpp` and Product 78) are tied to ephemeris `DE421` (Barker et al., 2016, 2021). Current JPL Horizons default ephemerides use `DE440` / `DE441`. Horizons does not provide a query parameter to select `DE421` dynamically.
   - *Resolution Required:* Determine whether LunaSight will ingest DE440 vectors from Horizons and apply a documented rotation to align with the DE421 `MOON_ME` frame, or quantify the maximum angular error introduced at the lunar south pole.
2. **Offline Ephemeris Cache Architecture:**
   - *Status:* **UNRESOLVED**
   - *Issue:* LunaSight operates in offline/field environments. Generating accurate Sun/Earth vectors without active internet access requires either:
     a) Caching pre-computed ephemeris tables for discrete mission windows.
     b) Embedding low-degree Chebyshev polynomial approximations (JPL SPK format subset).
   - *Resolution Required:* Architectural selection between pre-computed discrete tabular caching vs compact polynomial evaluation.
3. **Topocentric Vector Formulation (Vector Subtraction vs Observer Tables):**
   - *Status:* **UNRESOLVED**
   - *Issue:* Topocentric apparent AZ/EL from Horizons observer tables incorporates light-time, gravitational deflection, and stellar aberration. Pure Cartesian vector subtraction $(\vec{r}_{\text{target}} - \vec{r}_{\text{site}})$ yields geometric directions.
   - *Resolution Required:* Quantify whether solar radiation and direct-to-Earth line-of-sight calculations require apparent observables or whether geometric light-time corrected vectors are sufficient for the $5\text{ m/pixel}$ spatial resolution of the DEM.

---

## 16. Acceptance Criteria

Phase 04A shall be considered complete when:
1. The scientific contract document (`docs/phase_04a_scientific_contract.md`) is fully audited, internally consistent, and traceable to official NASA/JPL/USGS standards.
2. Every scientific claim is categorized as `VERIFIED`, `PROJECT CONTRACT`, `PROPOSED`, or `UNRESOLVED`.
3. Canonical units, coordinate boundaries, numerical tolerances, and frame identities are comprehensively specified.
4. The project roadmap in `lib/features/home/data/repositories/local_system_module_repository.dart` continues to show **Phase 04 as planned** (`ModuleStatus.planned`) until runtime implementation is developed and approved in Phase 04B.
5. All automated test suites (`flutter test`) continue to pass with 100% success and zero regressions across Phases 01, 02, and 03.
6. Zero runtime algorithmic code, vector math classes, or ephemeris calculation logic is committed in Phase 04A.

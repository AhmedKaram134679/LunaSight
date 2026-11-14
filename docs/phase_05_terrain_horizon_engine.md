# Phase 05 — Terrain Horizon Engine Specification and Technical Architecture

## 1. Overview & Scientific Mission

The **Terrain Horizon Engine** provides a rigorous, computationally robust, and scientifically defensible subsystem for calculating the lunar terrain horizon as viewed by an observer located on or near the lunar surface.

Calculating terrain horizons is critical for lunar landing site evaluation, surface mission planning, optical line-of-sight analysis, and solar illumination and Earth visibility profiling.

### Key Capabilities & Scope Boundaries
1. **Regional Ingestion via Pre-Decoded Tiles**: The engine currently loads and samples pre-decoded IEEE 754 Float32 binary tiles derived from NASA GSFC LOLA Product 81 (`ldem_87s_5mpp`, 5 meters per pixel, South Polar Stereographic projection).
   > [!NOTE]
   > The application loads offline pre-decoded binary tile slices; direct in-engine parsing and decompression of multi-gigabyte Deflate BigTIFF containers is not implemented in the mobile/desktop runtime.
2. **Polar Georeferencing**: Mathematically exact forward and inverse South Polar Stereographic map projections for the canonical spherical Moon ($R = 1,737,400\text{ m}$).
3. **Rigorous Horizon Ray-Casting**: 3D Cartesian spherical ray evaluation taking into account lunar curvature, local terrain elevation, and observer instrument height ($h_{\text{inst}}$) across discrete radial and azimuth steps.
4. **Local Topocentric Horizon Frames**: Evaluation of line-of-sight elevation angles in the observer's local East-North-Up (ENU) horizon frame using a deterministic polar tangent basis ($\vec{N}$ pointing along the prime meridian at the South Pole).
5. **Deterministic Observer Elevation & NoData Handling**: Missing observer terrain or NoData at the observer coordinates strictly throws typed domain exceptions (`ScientificComputationException`) rather than assuming zero elevation. Bilinear and nearest-neighbor interpolation qualities are tracked explicitly.

---

## 2. Remote Sensing Elevation Data Sources & Tile Pipeline

### Primary Dataset: LOLA Product 81 (`ldem_87s_5mpp`)
- **Origin**: NASA Goddard Space Flight Center (GSFC) Planetary Geodynamics Data Archive (PGDA).
- **Product ID**: LOLA Product 81 (`ldem_87s_5mpp.tif`).
- **Spatial Coverage**: Lunar South Pole ($87^\circ\text{S}$ to $90^\circ\text{S}$).
- **Horizontal Resolution**: $5.0\text{ m/pixel}$ at the pole.
- **Grid Dimensions**: $40,000 \times 40,000$ pixels ($200\text{ km} \times 200\text{ km}$ projected extent).
- **Projection**: Polar Stereographic (South Pole), Center Longitude $0^\circ$, Standard Parallel $90^\circ\text{S}$.
- **Vertical Datum**: Radial distances relative to reference sphere radius $R = 1,737,400.0\text{ m}$. Elevations are signed values in meters ($r - R$).
- **GeoTIFF Raster Metadata**:
  - `ModelPixelScaleTag`: $(5.0, 5.0, 0.0)$
  - `ModelTiepointTag`: $(0.0, 0.0, 0.0, -100000.0, 100000.0, 0.0)$
  - `GTRasterTypeGeoKey`: `RasterPixelIsArea` (value 1)
  - `ProjCoordTransGeoKey`: `CT_PolarStereographic` (value 15)
  - `SemiMajorAxis`: $1,737,400.0\text{ m}$
- **BigTIFF Tile Architecture**: BigTIFF (version 43), $256 \times 256$ pixel tiles ($157 \times 157$ tile grid), Deflate (zlib) compression, TIFF horizontal differencing floating-point predictor (Tag 317 = 3).
- **Offline Extraction vs Runtime Ingestion**:
  - *Offline Extraction*: A dedicated pre-processing pipeline fetches requested tile offsets via HTTP Range requests from NASA PGDA, decompresses the zlib streams, undifferences the floating-point byte planes, and outputs raw Float32 little-endian tile binaries ($256 \times 256 \times 4 = 262,144$ bytes).
  - *Runtime Ingestion*: `DemTileLoader` reads local pre-decoded binary tile files, validates file sizes, and populates `DemTile` instances into `TiledTerrainDataProvider`. Direct BigTIFF parsing is NOT performed at application runtime.
- **Authoritative South Pole Test Fixture**:
  - *Location*: `test/fixtures/terrain/lola_south_pole_tile_78_78.bin` (262,144 bytes, 65,536 Float32 samples).
  - *SHA-256*: `ae72c611bb4435c41c7f984dc695aedabdbdd75d22c452afa7fb15963d02ff1e`.
  - *Exact Source Specification*: Tile column 78, Tile row 78 (linear tile index $78 \times 157 + 78 = 12,324$).
  - *BigTIFF Tag Metadata & Correct Array Offsets*:
    - Tag 324 (`TileOffsets`): type 16 (`LONG8`, 8 bytes/element), count 24,649, value-array offset: 197,624 bytes.
      Entry offset for tile index 12,324:
      $$197,624 + (12,324 \times 8) = 296,216\text{ bytes} \implies \text{Value: } 1,259,787,516$$
    - Tag 325 (`TileByteCounts`): type 16 (`LONG8`, 8 bytes/element), count 24,649, value-array offset: 432 bytes.
      Entry offset for tile index 12,324:
      $$432 + (12,324 \times 8) = 99,024\text{ bytes} \implies \text{Value: } 137,823$$
    *(Note on previous discrepancy: The previously reported offset 98,976 corresponds to tile index 12,318, i.e., $432 + 12,318 \times 8 = 98,976$, which held value 160,416. Tile index 12,324 correctly resides at offset 99,024).*
  - *Fixture Verification Status*:
    The committed binary fixture has a verified SHA-256 checksum and sample count.
    Full byte-level provenance has been established: extracting tile index 12,324 (tile column 78, row 78) from the authoritative NASA GSFC BigTIFF (`ldem_87s_5mpp.tif`) at byte offset 1,259,787,516 (137,823 compressed bytes) and decoding via standard Deflate and libtiff-compliant TIFF Predictor 3 floating-point horizontal differencing reproduces the committed binary fixture bit-for-bit (SHA-256: `ae72c611bb4435c41c7f984dc695aedabdbdd75d22c452afa7fb15963d02ff1e`).
    The verification script `tool/verify_lola_fixture.py` provides offline fixture-integrity checks and verified source-to-fixture extraction via `--source <path>`.
    Under `RasterPixelIsArea` georeferencing, cell centers are offset by half a pixel; the exact South Pole $(0, 0)\text{ m}$ is located at pixel $(31.5, 31.5)$ within tile $(78, 78)$, yielding a continuous bilinear elevation of $1,289.478\text{ m}$.

### Raster Pixel Registration & Tile Border Interpolation Semantics
- **Pixel Registration (`RasterPixelIsArea`)**:
  - In NASA LOLA Product 81 GeoTIFF, pixels represent area cells with pixel size $s_x = s_y = 5.0\text{ m}$.
  - The continuous array column and row coordinate mapping for point $(x, y)$ is:
    $$c = \frac{x - x_{\min}}{s_x} - 0.5,\quad r = \frac{y_{\max} - y}{s_y} - 0.5$$
  - Cell centers fall at integer continuous indices ($c \in \{0, 1, \dots, \text{width}-1\}$).
- **Convex Hull Bilinear Interpolation & Tile Edge Fallback**:
  - Valid bilinear interpolation requires all four bounding grid points to enclose the query point within their convex hull: $c \in [0, \text{width}-1]$ and $r \in [0, \text{height}-1]$.
  - If a query point falls in the outer half-pixel border ($c < 0$, $c > \text{width}-1$, $r < 0$, or $r > \text{height}-1$), interpolation weights would extrapolate outside $[0, 1]$ (negative weights).
  - The engine strictly detects this condition and falls back to nearest-neighbor sampling, assigning `ElevationSampleStatus.validNearestNeighbor` to avoid artificial slope or elevation ringing at tile boundaries.
- **Provider Shared Tile Boundary Policy**:
  - Multi-tile spatial indexing uses floor division on projected coordinates:
    $$\text{tileCol} = \lfloor x / \text{tileWidthMeters} \rfloor,\quad \text{tileRow} = \lfloor y / \text{tileHeightMeters} \rfloor$$
  - Half-open intervals $[X_0, X_1)$ govern tile ownership: a query on the shared boundary $X = X_1$ is deterministically routed to the adjacent tile $[X_1, X_2)$.
  - Tile loading order invariance is proven by multi-tile tests verifying identical sample retrieval regardless of ingestion order. In the absence of a neighboring tile, sampling at the boundary returns `ElevationSampleStatus.outsideCoverage` without throwing exceptions.

### Secondary Global Dataset: LOLA Product 78 (`ldem_128`)
- **Origin**: PDS Geosciences Node / NASA GSFC.
- **Resolution**: 128 pixels per degree ($\approx 237\text{ m/pixel}$ at equator).
- **Projection**: Equirectangular (cylindrical plate carrée).

---

## 3. Projection Mathematics: South Polar Stereographic

For a spherical planetary body of radius $R = 1,737,400\text{ m}$ with projection center at the South Pole ($\phi_0 = -90^\circ$, $\lambda_0 = 0^\circ$):

### Forward Projection ($(\phi, \lambda) \to (x, y)$)
Let $\phi$ be latitude, $\lambda$ be east-positive longitude.
The colatitude or polar distance is:
$$\theta_p = \frac{\pi}{2} + \phi \quad (\text{since } \phi \le 0)$$
The stereographic scaling factor is:
$$\rho = 2 R \tan\left(\frac{\theta_p}{2}\right) = 2 R \tan\left(\frac{\pi/2 + \phi}{2}\right)$$
The projected coordinates in meters are:
$$x = \rho \sin(\lambda)$$
$$y = -\rho \cos(\lambda)$$

At the exact South Pole ($\phi = -\pi/2$):
$$\rho = 0 \implies x = 0,\ y = 0$$

### Inverse Projection ($(x, y) \to (\phi, \lambda)$)
Given projected coordinates $(x, y)$ in meters:
$$\rho = \sqrt{x^2 + y^2}$$
If $\rho = 0$:
$$\phi = -\frac{\pi}{2} \ (-90^\circ),\quad \lambda = 0$$
If $\rho > 0$:
$$\theta_p = 2 \arctan\left(\frac{\rho}{2 R}\right)$$
$$\phi = \theta_p - \frac{\pi}{2}$$
$$\lambda = \operatorname{atan2}(x, -y)$$
where $\lambda$ is normalized to $[0, 2\pi)$ or $[-\pi, \pi]$.

---

## 4. Horizon Calculation & Ray-Marching Engine

### 1. Observer Positioning, Height Contract & Local Topocentric Frame
Given observer geographic coordinates $(\phi_{\text{obs}}, \lambda_{\text{obs}})$ and instrument height $h_{\text{inst}}$:
- **Observer Height Contract (Option A — Horizontal Location Only)**:
  `request.observerCoordinates` specifies the horizontal position on the lunar body. The Phase 04C `heightMeters` property must equal $0.0\text{ m}$ within a strict tolerance of $|h| \le 10^{-4}\text{ m}$ ($0.1\text{ mm}$); any coordinate height exceeding this tolerance is strictly rejected with a typed `ScientificComputationException(code: 'OBSERVER_NONZERO_HEIGHT_METERS')`. The observer's surface elevation $H_{\text{obs}}$ is queried authoritatively from the DEM provider, preventing unverified or duplicate height definitions.
- If $H_{\text{obs}}$ is outside coverage or NoData, computation is halted with an explicit `ScientificComputationException` (`OBSERVER_TERRAIN_OUTSIDE_COVERAGE` or `OBSERVER_TERRAIN_NODATA`).
- Total observer height relative to the reference sphere:
  $$h_{\text{total}} = H_{\text{obs}} + h_{\text{inst}}$$
  $$r_{\text{obs}} = R + h_{\text{total}} = R + H_{\text{obs}} + h_{\text{inst}}$$
- The 3D Cartesian position vector of the observer in Moon-centered body-fixed coordinates (`MOON_ME_DE421`) is:
  $$\vec{r}_{\text{obs}} = \begin{pmatrix} r_{\text{obs}} \cos\phi_{\text{obs}} \cos\lambda_{\text{obs}} \\ r_{\text{obs}} \cos\phi_{\text{obs}} \sin\lambda_{\text{obs}} \\ r_{\text{obs}} \sin\phi_{\text{obs}} \end{pmatrix}$$

The local East-North-Up (ENU) topocentric reference frame is defined by:
- **Up vector (Zenith)**:
  $$\vec{U} = \frac{\vec{r}_{\text{obs}}}{\|\vec{r}_{\text{obs}}\|}$$
- **North vector**:
  $$\vec{N} = \begin{cases} \frac{\hat{z} - (\hat{z} \cdot \vec{U})\vec{U}}{\|\hat{z} - (\hat{z} \cdot \vec{U})\vec{U}\|}, & \text{if } |\phi_{\text{obs}}| < 89.9999^\circ \\ \begin{pmatrix} 1 \\ 0 \\ 0 \end{pmatrix}, & \text{if } \phi_{\text{obs}} \le -89.9999^\circ \text{ (South Pole, prime meridian reference)} \end{cases}$$
- **East vector**:
  $$\vec{E} = \vec{N} \times \vec{U}$$
  (Satisfies right-handed topocentric triad: $\vec{E} \times \vec{N} = \vec{U}$).

### 2. Great-Circle Marching along Azimuth $A$
For each azimuth angle $A \in [0, 2\pi)$ (clockwise from North):
The horizontal ray unit tangent vector is:
$$\hat{T}(A) = \vec{N} \cos A + \vec{E} \sin A$$

At surface distance $s$, the angular distance along the lunar sphere is $\sigma = s / R$.
The unit position vector on the spherical Moon along the geodesic is:
$$\hat{u}(\sigma) = \vec{U} \cos\sigma + \hat{T} \sin\sigma$$

The geographic latitude $\phi_t$ and longitude $\lambda_t$ are directly extracted:
$$\phi_t = \arcsin(\hat{u}_z)$$
$$\lambda_t = \operatorname{atan2}(\hat{u}_y, \hat{u}_x)$$

This 3D vector geodesic construction guarantees mathematical consistency across all latitudes and eliminates polar coordinate singularities.

### 3. Terrain Height and Line-of-Sight Elevation Angle
At $(\phi_t, \lambda_t)$, the elevation $H_{\text{terr}}$ is queried from the DEM provider:
$$r_{\text{terr}} = R + H_{\text{terr}}$$
$$\vec{r}_{\text{terr}} = r_{\text{terr}} \hat{u}(\sigma)$$

The relative line-of-sight vector from the observer to the terrain obstacle is:
$$\vec{\rho} = \vec{r}_{\text{terr}} - \vec{r}_{\text{obs}}$$

The elevation angle $\theta$ in the topocentric horizon frame is:
$$\theta = \arcsin\left(\frac{\vec{\rho} \cdot \vec{U}}{\|\vec{\rho}\|}\right)$$

### 4. Lunar Curvature & Horizon Dip
As distance $s$ increases over the spherical Moon, the geometric horizon falls away due to curvature by approximately:
$$\Delta h_{\text{curv}} \approx \frac{s^2}{2 R}$$
Because $\vec{r}_{\text{terr}}$ and $\vec{r}_{\text{obs}}$ are evaluated directly in 3D Cartesian space, the lunar curvature is represented with full geometric rigor without flat-Moon approximations.
For a smooth sphere with observer instrument height $h$, the geometric horizon dip is:
$$\theta_{\text{dip}} = -\arccos\left(\frac{R}{R + h}\right) \approx -\sqrt{\frac{2h}{R}}$$

---

## 5. Software Architecture

```
lib/features/terrain_horizon/
├── domain/
│   ├── models/
│   │   ├── geographic_extent.dart     // Geographic & projected bounding boxes
│   │   ├── dem_metadata.dart          // DEM metadata, pixel scale, tie points, datums
│   │   ├── elevation_sample.dart      // ElevationSample, DemTile, bilinear & detailed sampling
│   │   └── horizon_profile.dart       // HorizonProfileRequest, HorizonPoint, HorizonProfile
│   ├── projections/
│   │   └── south_polar_stereographic.dart // Forward & inverse polar stereographic formulas
│   └── services/
│       └── terrain_horizon_engine.dart    // TerrainDataProvider, TerrainHorizonEngine
├── data/
│   ├── providers/
│   │   └── tiled_terrain_data_provider.dart // In-memory DEM tile cache & spatial lookup
│   └── services/
│       └── dem_tile_loader.dart            // Local binary DEM tile decoding service
└── terrain_horizon.dart               // Public API library export
```

---

## 6. Verification and Validation Matrix

| Test Suite | File | Tests | Coverage | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Projection Math** | `south_polar_stereographic_test.dart` | 3 | South Pole (0,0), cardinal quadrants, forward-inverse roundtrip | Passed |
| **Elevation Sampling** | `elevation_sample_test.dart` | 9 | Bilinear interpolation, nearest neighbor, sampleDetailed quality status, non-finite floats, NoData rejection, out of bounds | Passed |
| **Horizon Ray-Casting** | `terrain_horizon_engine_test.dart` | 10 | Analytical curvature dip $\theta \approx -\sqrt{2h/R}$, isolated peak, obstacle occlusion, instrument height, observer outside coverage/NoData rejection, Option A observer heightMeters rejection, height reference validation, polar azimuth basis invariance | Passed |
| **Real LOLA Data & Boundary Tests** | `tiled_terrain_data_provider_test.dart` | 10 | Ingestion of real NASA LOLA South Pole Tile 78_78 fixture, pixel registration at South Pole (0,0), corrupt file rejection, provider getElevation inside Tile A and B, exact South Pole boundary ownership, boundary approach before/after, A/B vs B/A loading order invariance, missing neighboring tile, NoData propagation | Passed |
| **Phase 01–04 Regression**| `test/features/scientific_geometry/` | 106 | Complete preservation of scientific geometry invariants | Passed |
| **Full Repository** | `flutter test` | 240 | All unit, widget, compile-time, and integration tests across entire repository | Passed |

---

## 7. Known Scientific Limitations & Operational Boundaries

1. **Discrete Sampling vs Continuous Terrain**:
   - The engine performs ray-marching with discrete radial steps ($\Delta s$) and discrete azimuth steps ($\Delta A$). It does not perform continuous analytic ray-surface intersection; sub-step peaks between radial samples or between azimuth spokes can be missed if step sizes exceed terrain feature frequencies.
2. **Pre-Decoded Tile Scope**:
   - The runtime application currently ingests pre-decoded IEEE 754 Float32 binary tiles. It does not parse or decompress raw TIFF/BigTIFF containers at runtime.
3. **Regional vs Global Coverage**:
   - High-resolution LOLA Product 81 ($5\text{ m/pixel}$) covers the South Pole region ($87^\circ\text{S}\text{–}90^\circ\text{S}$).
   - Mid-latitude and equatorial horizon calculations currently require lower-resolution global DEM mosaics (e.g., LOLA Product 78, $128\text{ pixels/degree}$, $\approx 237\text{ m/pixel}$) or SLDEM2015 ($60\text{ m/pixel}$).
4. **Ephemeris Realization (DE421 vs DE441)**:
   - Phase 04 and Phase 05 domain coordinates operate in `MOON_ME_DE421` (Mean Earth / Polar Axis frame realized by DE421).
   - Higher-order sub-meter lunar physical libration models realized by JPL DE440/DE441 introduce minor orientation differences ($\approx 10\text{–}30\text{ cm}$ at lunar radius) that will be addressed in future astrometric phases.
5. **Atmospheric Refraction**:
   - The Moon possesses no substantial atmosphere ($P < 10^{-10}\text{ Pa}$); optical refraction is identically zero ($\mu = 1.0$), ensuring pure geometric line-of-sight ray propagation.

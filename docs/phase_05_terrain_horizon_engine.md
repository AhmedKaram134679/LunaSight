# Phase 05 — Terrain Horizon Engine Specification and Technical Architecture

## 1. Overview & Scientific Mission

The **Terrain Horizon Engine** provides a rigorous, computationally robust, and scientifically defensible subsystem for calculating the lunar terrain horizon as viewed by an observer located on or near the lunar surface.

Calculating terrain horizons is critical for lunar landing site evaluation, surface mission planning, optical line-of-sight analysis, and solar illumination and Earth visibility profiling.

### Key Capabilities
1. **Real Data Ingestion**: Direct integration and sampling of high-resolution digital elevation models (DEMs) produced by NASA GSFC LOLA (Lunar Orbiter Laser Altimeter), specifically LOLA Product 81 (`ldem_87s_5mpp`, 5 meters per pixel, South Polar Stereographic projection).
2. **Polar Georeferencing**: Mathematically exact forward and inverse South Polar Stereographic map projections for the canonical spherical Moon ($R = 1,737,400\text{ m}$).
3. **Rigorous Horizon Ray-Casting**: 3D Cartesian spherical ray evaluation taking into account lunar curvature, local terrain elevation, and observer instrument height ($h_{\text{inst}}$) across $360^\circ$ azimuth.
4. **Local Topocentric Horizon Frames**: Evaluation of line-of-sight elevation angles in the observer's local East-North-Up (ENU) horizon frame.
5. **NoData & Boundary Integrity**: Deterministic identification and handling of DEM boundaries, nodata samples, and invalid geometries without synthetic fallbacks.

---

## 2. Remote Sensing Elevation Data Sources

### Primary Dataset: LOLA Product 81 (`ldem_87s_5mpp`)
- **Origin**: NASA Goddard Space Flight Center (GSFC) Planetary Geodynamics Data Archive (PGDA).
- **Product ID**: LOLA Product 81 (`ldem_87s_5mpp.tif`).
- **Spatial Coverage**: Lunar South Pole ($87^\circ\text{S}$ to $90^\circ\text{S}$).
- **Horizontal Resolution**: $5.0\text{ m/pixel}$ at the pole.
- **Grid Dimensions**: $40,000 \times 40,000$ pixels ($200\text{ km} \times 200\text{ km}$ projected extent).
- **Projection**: Polar Stereographic (South Pole), Center Longitude $0^\circ$, Standard Parallel $90^\circ\text{S}$.
- **Vertical Datum**: Radial distances relative to the reference sphere radius $R = 1,737,400.0\text{ m}$. Elevations are signed values in meters ($r - R$).
- **Tile Architecture**: BigTIFF (version 43), $256 \times 256$ pixel tiles ($157 \times 157$ tile grid), Deflate (zlib) compression, TIFF horizontal differencing floating-point predictor (Tag 317 = 3).
- **Authoritative South Pole Test Fixture**: Decoded binary tile covering $(0, 0)\text{ m}$ (South Pole) stored at `test/fixtures/terrain/lola_south_pole_tile_78_78.bin` (262,144 bytes, 65,536 Float32 samples).

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

### 1. Observer Positioning & Local Topocentric Frame
Given observer geographic coordinates $(\phi_{\text{obs}}, \lambda_{\text{obs}})$ and instrument height $h_{\text{inst}}$ above local surface elevation $H_{\text{obs}}$:
$$r_{\text{obs}} = R + H_{\text{obs}} + h_{\text{inst}}$$
The 3D Cartesian position vector of the observer in Moon-centered body-fixed coordinates (`MOON_ME_DE421`) is:
$$\vec{r}_{\text{obs}} = \begin{pmatrix} r_{\text{obs}} \cos\phi_{\text{obs}} \cos\lambda_{\text{obs}} \\ r_{\text{obs}} \cos\phi_{\text{obs}} \sin\lambda_{\text{obs}} \\ r_{\text{obs}} \sin\phi_{\text{obs}} \end{pmatrix}$$

The local East-North-Up (ENU) topocentric reference frame is defined by:
- **Up vector (Zenith)**:
  $$\vec{U} = \frac{\vec{r}_{\text{obs}}}{\|\vec{r}_{\text{obs}}\|}$$
- **North vector**:
  $$\vec{N} = \begin{cases} \begin{pmatrix} -\sin\phi_{\text{obs}} \cos\lambda_{\text{obs}} \\ -\sin\phi_{\text{obs}} \sin\lambda_{\text{obs}} \\ \cos\phi_{\text{obs}} \end{pmatrix}, & \text{if } |\phi_{\text{obs}}| < 90^\circ \\ \begin{pmatrix} \cos\lambda_{\text{obs}} \\ \sin\lambda_{\text{obs}} \\ 0 \end{pmatrix}, & \text{if } \phi_{\text{obs}} = -90^\circ \text{ (South Pole)} \end{cases}$$
- **East vector**:
  $$\vec{E} = \vec{N} \times \vec{U}$$

### 2. Great-Circle Marching along Azimuth $A$
For each azimuth angle $A \in [0, 2\pi)$ (clockwise from North):
At radial distance $s$ along the surface of the sphere, the angular distance is $\sigma = s / R$.
The latitude $\phi_t$ and longitude $\lambda_t$ of the target terrain point are determined via spherical trigonometry:
$$\sin\phi_t = \sin\phi_{\text{obs}} \cos\sigma + \cos\phi_{\text{obs}} \sin\sigma \cos A$$
$$\cos\phi_t \sin(\Delta\lambda) = \sin\sigma \sin A$$
$$\cos\phi_t \cos(\Delta\lambda) = \cos\sigma \cos\phi_{\text{obs}} - \sin\sigma \sin\phi_{\text{obs}} \cos A$$
$$\lambda_t = \lambda_{\text{obs}} + \Delta\lambda$$

### 3. Terrain Height and Line-of-Sight Elevation Angle
At $(\phi_t, \lambda_t)$, the elevation $H_{\text{terr}}$ is queried from the DEM provider:
$$r_{\text{terr}} = R + H_{\text{terr}}$$
The 3D Cartesian position vector of the terrain point is:
$$\vec{r}_{\text{terr}} = \begin{pmatrix} r_{\text{terr}} \cos\phi_t \cos\lambda_t \\ r_{\text{terr}} \cos\phi_t \sin\lambda_t \\ r_{\text{terr}} \sin\phi_t \end{pmatrix}$$

The relative line-of-sight vector from the observer to the terrain obstacle is:
$$\vec{\rho} = \vec{r}_{\text{terr}} - \vec{r}_{\text{obs}}$$

The elevation angle $\theta$ in the topocentric horizon frame is:
$$\theta = \arcsin\left(\frac{\vec{\rho} \cdot \vec{U}}{\|\vec{\rho}\|}\right)$$

### 4. Lunar Curvature & Horizon Dip
As distance $s$ increases over the spherical Moon, the geometric horizon falls away due to curvature by approximately:
$$\Delta h_{\text{curv}} \approx \frac{s^2}{2 R}$$
Because $\vec{r}_{\text{terr}}$ and $\vec{r}_{\text{obs}}$ are evaluated directly in 3D Cartesian space, the lunar curvature is represented with full geometric rigor without approximations.
For a smooth sphere with observer height $h$, the geometric horizon dip is:
$$\theta_{\text{dip}} = -\arcsin\left(\frac{\sqrt{2Rh + h^2}}{R + h}\right) \approx -\sqrt{\frac{2h}{R}}$$

---

## 5. Software Architecture

```
lib/features/terrain_horizon/
├── domain/
│   ├── models/
│   │   ├── geographic_extent.dart     // Geographic & projected bounding boxes
│   │   ├── dem_metadata.dart          // DEM metadata, pixel scale, tie points, datums
│   │   ├── elevation_sample.dart      // ElevationSample, DemTile, bilinear sampling
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
| **Elevation Sampling** | `elevation_sample_test.dart` | 7 | Bilinear interpolation, nearest neighbor, NoData rejection, out of bounds | Passed |
| **Horizon Ray-Casting** | `terrain_horizon_engine_test.dart` | 4 | Analytical curvature dip $\theta \approx -\sqrt{2h/R}$, isolated peak, obstacle occlusion, instrument height | Passed |
| **Real LOLA Data** | `tiled_terrain_data_provider_test.dart` | 3 | Ingestion of real NASA LOLA South Pole Tile 78_78 fixture, South Pole elevation, corrupt file rejection | Passed |
| **Phase 01–04 Regression**| `test/features/scientific_geometry/` | 106 | Complete preservation of scientific geometry invariants | Passed |
| **Full Repository** | `flutter test` | 226 | All unit, widget, and integration tests across entire repository | Passed |

---

## 7. Known Scientific Limitations & Ephemeris Realization Boundaries

1. **Ephemeris Realization (DE421 vs DE441)**:
   - Phase 04 and Phase 05 domain coordinates operate in `MOON_ME_DE421` (Mean Earth / Polar Axis frame realized by DE421).
   - Higher-order sub-meter lunar physical libration models realized by JPL DE440/DE441 introduce minor orientation differences ($\approx 10\text{–}30\text{ cm}$ at lunar radius) that will be addressed in future astrometric phases.
2. **Regional vs Global Coverage**:
   - High-resolution LOLA Product 81 ($5\text{ m/pixel}$) covers the South Pole region ($87^\circ\text{S}\text{–}90^\circ\text{S}$).
   - Mid-latitude and equatorial horizon calculations currently require lower-resolution global DEM mosaics (e.g., LOLA Product 78, $128\text{ pixels/degree}$, $\approx 237\text{ m/pixel}$) or SLDEM2015 ($60\text{ m/pixel}$).
3. **Atmospheric Refraction**:
   - The Moon possesses no substantial atmosphere ($P < 10^{-10}\text{ Pa}$); optical refraction is identically zero ($\mu = 1.0$), ensuring pure geometric line-of-sight ray propagation.

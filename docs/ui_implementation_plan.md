# LunaSight UI Implementation Plan: Lunar Landing Site Exploration & Mission Planning

**Target:** LunaSight Android Application  
**Execution Mode:** Production-Grade Clean Architecture Implementation  
**Status:** In Progress  

---

## 1. Engine & Runtime Integration Boundaries Audit

| Scientific Engine / Service | Production Entry Point | Required Inputs | Runtime Data Availability | Computable Today? | Missing Prerequisites / Limitations |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Lunar Coordinate Transformer** (`Phase 04`) | `LunarCoordinateTransformer.toBodyFixedCartesian(coords)` | `LunarGeographicCoordinates` (Latitude, Longitude, Reference Surface Datum) | In-memory via `LunarCoordinates` entity | **YES** (for all sites with coordinates) | Requires point coordinates. Official Product 78 entries intentionally publish raster footprints without point coordinates (`coordinates == null`). |
| **Local Horizon Basis** (`Phase 06 M03`) | `LocalHorizonBasis.fromCoordinates(latitude, longitude)` | Latitude (`Angle`), Longitude (`Angle`) | In-memory via `LunarCoordinates` entity | **YES** (for all sites with coordinates) | Requires point coordinates. Evaluates SEZ unit triads ($\hat{\mathbf{u}}_S, \hat{\mathbf{u}}_E, \hat{\mathbf{u}}_Z, \hat{\mathbf{u}}_N$) with deterministic South Pole handling. |
| **Astronomical Time Infrastructure** (`Phase 06 M02`) | `AstronomicalTime.fromUtcDateTime(dt)` | UTC `DateTime`, explicit `TimeScale` | Self-contained leap second table (`LeapSecondProvider`) | **YES** | Evaluates UTC $\leftrightarrow$ TAI $\leftrightarrow$ TT $\leftrightarrow$ TDB transformations with verified accuracy. |
| **Local Topocentric Converter** (`Phase 06 M03`) | `LocalTopocentricConverter.toTopocentric(...)` | Observer `CelestialVector`, Target `CelestialVector`, Observer `LunarGeographicCoordinates` | Vector math available; requires Moon-fixed 3D celestial vectors for target/observer | **CONDITIONAL** (API ready, ephemeris data pending) | Planetary ephemeris engine (JPL DE421/SPICE Sun/Earth vectors) is planned for Phase 06 M04+. No mocked vectors will be fabricated. |
| **Terrain Horizon Engine** (`Phase 05`) | `TerrainHorizonEngine.calculateHorizon(request)` | `TiledTerrainDataProvider` + `HorizonProfileRequest` | DEM tiles (e.g. LOLA Product 81) | **CONDITIONAL** (Engine ready, dataset download pending) | LOLA Product 81 is a 3.3 GB GeoTIFF. On fresh mobile installs without cached DEM tiles, terrain ray-casting is honestly marked unavailable. |
| **Bundled Site Catalog** (`Phase 03`) | `LocalLunarSiteRepository.getAllSites()` | None (bundled in asset code) | 27 official NASA Product 78 sites + local storage for user custom sites | **YES** | Fully operational. Distinguishes high-priority landing sites (Sites 1, 4, 7, 11) from general catalog regions. |
| **NASA Data Repository** (`Phase 02`) | `NasaDataRepository.getAvailableProducts()` | None | Official metadata for Product 81 | **YES** | Inspects local cache status and manages background acquisition. |

---

## 2. Product Architecture & Navigation Hierarchy

```text
[App Launch]
    │
    ▼
[Mission Dashboard] (/)
    ├── Mission Identity & Artemis South Pole Overview
    ├── Real-Time Capability & Dataset Availability Status
    ├── Quick Candidate Sites Spotlight (Connecting Ridge, Shackleton Rim, etc.)
    ├── Navigation Action Cards:
    │     ├── [Explore Candidate Sites] ───► [/sites]
    │     ├── [Register Custom Candidate Site] ──► [/sites/custom]
    │     ├── [Site Comparison Matrix] ──► [/sites/compare]
    │     └── [NASA Datasets & Telemetry] ──► [/datasets]
    │
    ├── [Lunar Site Explorer] (/sites)
    │     ├── Search by name, code, or description
    │     ├── Classification filtering (High-Priority Landing Sites, Catalog Regions, User Candidates)
    │     ├── Coordinate availability filter
    │     └── Site Selection ───► [/sites/details]
    │
    ├── [Site Details & Scientific Analysis] (/sites/details)
    │     ├── Site Header (Name, Code, Classification Badge, Region)
    │     ├── Official Provenance & NASA Citation
    │     ├── Coordinate Card:
    │     │     ├── If null: Honest disclosure of Product 78 raster footprint
    │     │     └── If present: Exact Lat/Lon, body-fixed Cartesian (X,Y,Z), SEZ triad
    │     ├── Topocentric Horizon Basis:
    │     │     └── Computed Zenith, North, East, South vectors in MOON_ME_DE421
    │     ├── Scientific Conditions & Analysis Modules:
    │     │     ├── Terrain Horizon Profile (shows computed profile if DEM cached, else honest unavailable)
    │     │     ├── Solar Illumination (shows topocentric vector if ephemeris available, else honest unavailable)
    │     │     └── Earth Visibility / LOS (shows LOS status if ephemeris available, else honest unavailable)
    │     └── Linked NASA Product 81 Availability & Cache Inspector
    │
    └── [Site Comparison Matrix] (/sites/compare)
          ├── Select 2 or 3 candidate sites for side-by-side evaluation
          ├── Honest comparison of verified properties:
          │     ├── Classification & Mission Priority
          │     ├── Coordinate Availability & Provenance
          │     ├── Selenographic Latitude & Longitude
          │     ├── Proximity to Lunar South Pole
          │     ├── Datum Elevation / Altitude
          │     └── Dataset Caching Status
          └── Explicit notice rejecting fabricated suitability scores
```

---

## 3. Implementation Steps & Verification

1. **Mission Dashboard (`home_page.dart`):**
   - Replace placeholder roadmap cards with a functional Mission Dashboard.
   - Provide Artemis polar exploration context, actual telemetry status, and direct workflows to explore sites, compare sites, and inspect scientific availability.
2. **Landing Site Explorer (`lunar_site_explorer_page.dart`):**
   - Polish search, classification filtering, and distinction between high-priority landing sites and catalog regions.
3. **Site Details & Scientific Analysis (`lunar_site_details_page.dart`):**
   - When coordinates exist: invoke `LunarCoordinateTransformer` and `LocalHorizonBasis` in real-time to compute and render the 3D body-fixed Cartesian coordinates and SEZ unit vectors.
   - For incomplete engines (ephemeris, uncached DEM): provide clean, honest status cards explaining exact missing prerequisites without fake data.
4. **Site Comparison (`site_comparison_page.dart`):**
   - Create a clean side-by-side comparison screen comparing genuinely available attributes of candidate landing sites.
5. **App Router Updates:**
   - Add routes `/sites/compare` and ensure seamless navigation.
6. **Testing & Android Build:**
   - Run tests, static analysis, format check, and `flutter build apk --release`.
   - Install and launch on connected Android 14 device (`vivo V2207`).

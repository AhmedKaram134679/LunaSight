# NASA Resource & Provenance Verification — Phase 03: Lunar Site Explorer

## 1. Executive Summary

This document establishes the official data sources, scientific provenance, coordinate conventions, and engineering constraints for **Phase 03 — Lunar Site Explorer** in the LunaSight project.

In alignment with LunaSight's core architectural tenets:
1. **Zero Fabrication**: No coordinates, elevations, slope percentages, illumination parameters, or visibility metrics are fabricated or extrapolated.
2. **Provenance Traceability**: Every cataloged candidate site and reference region links directly to official NASA documentation or publications.
3. **Graceful Handling of Region Bounds**: Named reference regions that lack single-point landing coordinates in published literature are explicitly represented with `null` coordinates and marked as "Unavailable in source documentation".
4. **Separation of Concerns**: Product 78 regional high-resolution LOLA topography datasets are distinguished from Product 81 (the 87°S–90°S mosaic). Product 81 is linked as an associated regional reference only where appropriate, never conflated.
5. **No Raster or Scientific Computation**: Phase 03 strictly avoids GeoTIFF decoding, raster sampling, GIS re-projection, ray-tracing, and solar/Earth vector calculations.

---

## 2. Authoritative NASA Data Sources

### 2.1 Primary NASA PGDA Product: Product 78
- **Title**: High-Resolution LOLA Topography for Lunar South Pole Sites
- **Official NASA URL**: [https://pgda.gsfc.nasa.gov/products/78](https://pgda.gsfc.nasa.gov/products/78)
- **Publisher**: Planetary Geodynamics Laboratory / Planetary Geodesy Data Archive (PGDA), NASA Goddard Space Flight Center (GSFC)
- **Principal Investigators / Authors**: M. K. Barker, E. Mazarico, et al.
- **Instrument**: Lunar Orbiter Laser Altimeter (LOLA), Lunar Reconnaissance Orbiter (LRO)
- **Spatial Resolution**: 5 m/pixel
- **Projection**: South Polar Stereographic (Polar Stereographic centered at -90° latitude)
- **Planetary Reference Frame**: `MOON_ME` (Mean Earth / Polar Axis)
- **Ephemeris Association**: `DE421`
- **Units**: Meters (horizontal X, Y; vertical Z surface height)
- **Official Scientific Citations**:
  - Barker, M. K., Mazarico, E., Neumann, G. A., Zuber, M. T., Haruyama, J., & Smith, D. E. (2016). *A new lunar digital elevation model from the Lunar Orbiter Laser Altimeter and SELENE Terrain Camera*. Icarus, 273, 346–355.
  - Barker, M. K., et al. (2021). *High-Resolution LOLA Topography for Lunar South Pole Sites*. NASA GSFC PGDA Product 78.
  - Mazarico, E., et al. (2011). *Illumination conditions of the lunar polar regions using LOLA topography*. Icarus, 211(2), 1066–1081.

### 2.2 Secondary / Associated NASA PGDA Product: Product 81
- **Title**: South Pole LOLA DEM Mosaic (87°S to 90°S)
- **Official NASA URL**: [https://pgda.gsfc.nasa.gov/products/81](https://pgda.gsfc.nasa.gov/products/81)
- **Product Identifier**: `ldem_87s_5mpp` (implemented in Phase 02)
- **Publisher**: NASA GSFC PGDA
- **Scope**: Broad polar cap mosaic from 87°S to 90°S.
- **Relationship to Product 78**: Product 78 contains targeted local digital elevation models for 27 distinct candidate sites and regions of interest (ROIs), whereas Product 81 provides the contiguous regional polar cap mosaic.

---

## 3. Product 78 Named Regions Catalog & Classification

NASA PGDA Product 78 catalogs 27 specific south polar regions of interest. These regions are categorized based on their official nomenclature and scientific usage:

| Index | Code / Name | Official NASA Description | Classification | Coordinates Availability | Associated Products |
|:-----:|:------------|:--------------------------|:---------------|:-------------------------|:---------------------|
| 1 | `Site01` | Connecting ridge | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 2 | `Site04` | Shackleton rim | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 3 | `Site06` | Nobile rim 1 | Candidate Landing Site | Bounding box / Unavailable as point | None (outside 87°S) |
| 4 | `Site07` | Peak near Shackleton | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 5 | `Site11` | de Gerlache rim | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 6 | `Site20` | Leibnitz beta plateau | Candidate Landing Site | Bounding box / Unavailable as point | None (outside 87°S) |
| 7 | `Site20v2` | Leibnitz beta plateau, extended boundaries | Candidate Landing Site | Bounding box / Unavailable as point | None (outside 87°S) |
| 8 | `Site23` | Malapert massif | Candidate Landing Site | Bounding box / Unavailable as point | None (outside 87°S) |
| 9 | `Site42` | de Gerlache-Kocher massif | Candidate Landing Site | Bounding box / Unavailable as point | None (outside 87°S) |
| 10 | `Haworth` | Haworth crater region | Reference Region | Region / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 11 | `Shoemaker`| Shoemaker crater region | Reference Region | Region / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 12 | `DM1` | Amundsen rim | Candidate Landing Site | Bounding box / Unavailable as point | None (outside 87°S) |
| 13 | `DM2` | Nobile rim 2 | Candidate Landing Site | Bounding box / Unavailable as point | None (outside 87°S) |
| 14 | `SL2` | de Gerlache rim | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 15 | `SL3` | Connecting ridge extension | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 16 | `NPA` | Cabeus exterior wall 1 | Candidate Landing Site | Bounding box / Unavailable as point | None (outside 87°S) |
| 17 | `NPB` | Amundsen 1 | Candidate Landing Site | Bounding box / Unavailable as point | None (outside 87°S) |
| 18 | `NPC` | Idel'son L crater 1 | Candidate Landing Site | Bounding box / Unavailable as point | None (outside 87°S) |
| 19 | `NPD` | Malapert crater 1 | Candidate Landing Site | Bounding box / Unavailable as point | None (outside 87°S) |
| 20 | `LM1` | Shackleton Rim B | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 21 | `LM2` | Shoemaker Rim A | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 22 | `LM3` | Shoemaker Rim B | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 23 | `LM4` | Shoemaker Rim C | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 24 | `LM5` | Shoemaker Rim D | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 25 | `LM6` | Shoemaker Rim E | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 26 | `LM7` | Faustini Rim A | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |
| 27 | `LM8` | Shoemaker Rim F | Candidate Landing Site | Bounding box / Unavailable as point | `ldem_87s_5mpp` (Product 81) |

*Note on Point Coordinates:* In NASA PGDA Product 78 documentation and data distribution, each named region is provided as a South Polar Stereographic GeoTIFF raster raster footprint or polygon ROI (shapefile), without a single canonical center point. LunaSight represents these entities with `coordinates = null` and clear UI indicators indicating that coordinates are not published as a single point in the official source, preventing false precision or synthetic geolocation.

---

## 4. Coordinate System & Longitude Convention Standards

### 4.1 Selenographic Latitude
- Valid Range: `[-90.0°, +90.0°]`
- Polar regions are in the southern hemisphere (`< 0°` or `S`).
- Input validation strictly enforces numeric bounds and rejects non-numeric or out-of-range values.

### 4.2 Selenographic Longitude & Conventions
Selenographic longitude can be represented under distinct conventions in planetary literature:
1. **Positive East (`0°` to `+360°` or `-180°` to `+180°`)**:
   - IAU standard convention: Longitude increases eastward from the Prime Meridian.
2. **Positive West**:
   - Historical or specialized mission frames: Longitude increases westward.
3. **Engineering Standard in LunaSight**:
   - LunaSight requires explicit documentation of the `LongitudeConvention` (e.g. `eastPositive`, `westPositive`, or `unknown`).
   - For user-defined custom coordinates, the convention defaults to `eastPositive` (IAU standard) and is explicitly visible in the UI.

### 4.3 Provenance Tracking
Every coordinate record encapsulates its provenance:
- `CoordinateProvenance.nasaPublished`: Directly extracted from authoritative NASA publication (if published).
- `CoordinateProvenance.userEntered`: Created through the custom coordinate entry form by the operator.


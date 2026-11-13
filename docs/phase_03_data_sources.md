# NASA Resource & Provenance Verification — Phase 03: Lunar Site Explorer

## 1. Executive Summary

This document establishes the official data sources, scientific provenance, coordinate conventions, and engineering constraints for **Phase 03 — Lunar Site Explorer** in the LunaSight project.

In alignment with LunaSight's core architectural tenets:
1. **Zero Fabrication**: No coordinates, elevations, slope percentages, illumination parameters, or visibility metrics are fabricated or extrapolated.
2. **Provenance Traceability**: Every cataloged candidate site and reference region links directly to official NASA documentation or publications.
3. **Graceful Handling of Region Bounds**: Named reference regions that lack single-point landing coordinates in published literature are explicitly represented with `null` coordinates and marked as "Unavailable in source documentation".
4. **Strict Separation of Product 78 and Product 81**: Product 78 regional high-resolution LOLA topography datasets are distinguished from Product 81 (the 87°S–90°S mosaic). No undocumented or inferred `relatedProductIds` relationships exist between Product 78 regions and Product 81. Product 81 remains independently accessible through the core NASA data layer.
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
- **Official Documentation Citation**:
  - Barker, M. K., et al. (2021). *High-Resolution LOLA Topography for Lunar South Pole Sites*. NASA GSFC PGDA Product 78.

### 2.2 Secondary / Independent NASA PGDA Product: Product 81
- **Title**: South Pole LOLA DEM Mosaic (87°S to 90°S)
- **Official NASA URL**: [https://pgda.gsfc.nasa.gov/products/81](https://pgda.gsfc.nasa.gov/products/81)
- **Product Identifier**: `ldem_87s_5mpp` (implemented in Phase 02)
- **Publisher**: NASA GSFC PGDA
- **Scope**: Broad polar cap mosaic from 87°S to 90°S.
- **Relationship Policy**: Product 81 is maintained independently in the general application catalog. It is NOT linked to individual Product 78 sites in `relatedProductIds` because NASA documentation does not define an explicit regional association.

---

## 3. Official NASA Space Apps Challenge Resource Verification

- **Target Challenge URL**: `https://www.spaceappschallenge.org/2026/challenges/lunar-landing-site-navigator/?tab=resources`
- **Verification Attempt Date**: November 13, 2026
- **Status**: `UNVERIFIED` (Direct network access to the 2026 hackathon portal closed/restricted; SSL certificate validation boundary and hackathon portal cycle).
- **Archival Context (2024 Challenge Baseline)**:
  - Official challenge: NASA Space Apps "Lunar Landing Site Navigator".
  - Curated resources in the challenge ecosystem include NASA Moon Trek (`https://trek.nasa.gov/moon/`), PDS Geosciences Node (`https://pds-geosciences.wustl.edu/missions/lro/`), and LRO LOLA high-resolution elevation products.
- **Compliance Policy**: In adherence to challenge instructions, Global Awards resource compliance is not formally asserted without an active, verified match from the live Resources tab.

---

## 4. Product 78 Named Regions Catalog & Classification

NASA PGDA Product 78 explicitly notes that Sites 1, 4, 7, and 11 surround high-priority lunar south pole landing sites. The remaining 23 regions are regional LOLA topography datasets without explicit landing site designations in Product 78 documentation.

LunaSight applies a strict, conservative classification policy:
- **`highPriorityLandingSiteRegion`**: Exactly 4 sites (`Site01`, `Site04`, `Site07`, `Site11`).
- **`nasaCatalogRegion`**: Exactly 23 regions (`Site06`, `Site20`, `Site20v2`, `Site23`, `Site42`, `Haworth`, `Shoemaker`, `DM1`, `DM2`, `SL2`, `SL3`, `NPA`, `NPB`, `NPC`, `NPD`, `LM1` through `LM8`).
- **`userDefined`**: Dynamically added custom user locations.

### Complete 27 Product 78 Region Catalog
| Index | Code / Name | Official Published Name | Classification | Point Coordinates | Related Product IDs |
|:-----:|:------------|:------------------------|:---------------|:-----------------:|:-------------------:|
| 1 | `Site01` | Connecting ridge | `highPriorityLandingSiteRegion` | Unavailable (null) | None |
| 2 | `Site04` | Shackleton rim | `highPriorityLandingSiteRegion` | Unavailable (null) | None |
| 3 | `Site06` | Nobile rim 1 | `nasaCatalogRegion` | Unavailable (null) | None |
| 4 | `Site07` | Peak near Shackleton | `highPriorityLandingSiteRegion` | Unavailable (null) | None |
| 5 | `Site11` | de Gerlache rim | `highPriorityLandingSiteRegion` | Unavailable (null) | None |
| 6 | `Site20` | Leibnitz beta plateau | `nasaCatalogRegion` | Unavailable (null) | None |
| 7 | `Site20v2` | Leibnitz beta plateau, extended boundaries | `nasaCatalogRegion` | Unavailable (null) | None |
| 8 | `Site23` | Malapert massif | `nasaCatalogRegion` | Unavailable (null) | None |
| 9 | `Site42` | de Gerlache-Kocher massif | `nasaCatalogRegion` | Unavailable (null) | None |
| 10 | `Haworth` | Haworth crater region | `nasaCatalogRegion` | Unavailable (null) | None |
| 11 | `Shoemaker`| Shoemaker crater region | `nasaCatalogRegion` | Unavailable (null) | None |
| 12 | `DM1` | Amundsen rim | `nasaCatalogRegion` | Unavailable (null) | None |
| 13 | `DM2` | Nobile rim 2 | `nasaCatalogRegion` | Unavailable (null) | None |
| 14 | `SL2` | de Gerlache rim | `nasaCatalogRegion` | Unavailable (null) | None |
| 15 | `SL3` | Connecting ridge extension | `nasaCatalogRegion` | Unavailable (null) | None |
| 16 | `NPA` | Cabeus exterior wall 1 | `nasaCatalogRegion` | Unavailable (null) | None |
| 17 | `NPB` | Amundsen 1 | `nasaCatalogRegion` | Unavailable (null) | None |
| 18 | `NPC` | Idel'son L crater 1 | `nasaCatalogRegion` | Unavailable (null) | None |
| 19 | `NPD` | Malapert crater 1 | `nasaCatalogRegion` | Unavailable (null) | None |
| 20 | `LM1` | Shackleton Rim B | `nasaCatalogRegion` | Unavailable (null) | None |
| 21 | `LM2` | Shoemaker Rim A | `nasaCatalogRegion` | Unavailable (null) | None |
| 22 | `LM3` | Shoemaker Rim B | `nasaCatalogRegion` | Unavailable (null) | None |
| 23 | `LM4` | Shoemaker Rim C | `nasaCatalogRegion` | Unavailable (null) | None |
| 24 | `LM5` | Shoemaker Rim D | `nasaCatalogRegion` | Unavailable (null) | None |
| 25 | `LM6` | Shoemaker Rim E | `nasaCatalogRegion` | Unavailable (null) | None |
| 26 | `LM7` | Faustini Rim A | `nasaCatalogRegion` | Unavailable (null) | None |
| 27 | `LM8` | Shoemaker Rim F | `nasaCatalogRegion` | Unavailable (null) | None |

---

## 5. Coordinate System & Validation Standards

### 5.1 Selenographic Latitude
- Enforced Range: `[-90.0°, +90.0°]`.
- Must be a finite number (`double.isFinite`). `NaN`, `+Infinity`, and `-Infinity` are rejected with `FormatException` in JSON and validation errors in form fields.

### 5.2 Selenographic Longitude & Conventions
- Enforced Range: `[-180.0°, +360.0°]`.
- Must be a finite number (`double.isFinite`).
- Supported Conventions:
  - `eastPositive`: IAU standard convention where longitude increases toward the East.
  - `westPositive`: Directional convention where longitude increases toward the West.
  - `unknown`: Explicit indicator when convention is undetermined from source.

### 5.3 Surface Elevation / Altitude
- Reference Datum: Mean lunar spherical datum ($r = 1,737,400\text{ m}$).
- Negative values represent depression below mean spherical datum (e.g. crater floors).
- Positive values represent elevations above mean radius (e.g. massif ridges).
- Must be finite if present.

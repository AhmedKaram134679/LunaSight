# Phase 04C — Lunar Coordinate Geometry

**Document:** `docs/phase_04c_lunar_coordinate_geometry.md`  
**Status:** DRAFT — Pending Independent Scientific Review  
**Phase:** 04C  
**Scope:** Forward lunar geographic-coordinate to body-fixed Cartesian transformation  
**Implementation status:** Not started

---

## 1. Objective

Define a scientifically explicit and numerically safe transformation from lunar surface geographic coordinates to a Cartesian position vector expressed in a declared lunar body-fixed reference frame.

This phase is limited to the forward transformation:

`Lunar Geographic Coordinates → Body-Fixed Cartesian Position`

The transformation must preserve the source coordinate convention, reference-surface definition, height reference, and frame realization.

It must not silently reinterpret coordinates or perform an undocumented reference-frame conversion.

## 2. Scope

### 2.1 Included

- Explicit latitude type and convention.
- Explicit longitude direction and domain.
- A documented spherical reference surface.
- Explicit height and height-reference semantics.
- A declared lunar body-fixed reference frame and realization.
- Forward geographic-to-Cartesian transformation.
- Reuse of the existing Phase 04B geometry primitives.
- Input validation and numerical failure handling.
- Independent mathematical verification and regression tests.

### 2.2 Excluded

- Cartesian-to-geographic inverse transformation.
- South Polar Stereographic projection and inverse projection.
- LOLA GeoTIFF raster decoding or sampling.
- DEM height-datum reconciliation.
- MOON_ME ↔ MOON_PA frame transformation.
- DE421 ↔ DE440/DE441 transformation.
- SPICE or Horizons runtime integration.
- Epoch-dependent lunar orientation calculations.
- Local North/East/Up basis.
- Terrain normals and terrain horizon.
- Solar illumination and Earth visibility.
- UI and application presentation.

These exclusions must remain outside Phase 04C.

## 3. Scientific Source Basis

The implementation contract is based on the following distinctions:

1. NASA PGDA Products 78 and 81 describe LOLA products using South Polar Stereographic coordinates, with X/Y expressed in meters and a lunar reference-frame definition associated with `MOON_ME` and DE421. These projected X/Y values are not geographic latitude/longitude inputs.

2. NAIF distinguishes the lunar Mean Earth/rotation-axis system (`MOON_ME`) from the Principal Axes system (`MOON_PA`).

3. NAIF lunar frame definitions provide DE-specific realizations. The generic names `MOON_ME` and `MOON_PA` are aliases whose actual realizations depend on the loaded lunar frame kernel.

4. NAIF distinguishes planetocentric coordinates from planetodetic/geodetic coordinates. Planetodetic latitude is defined relative to a reference spheroid, whereas planetocentric latitude is defined using the direction from the body's center.

5. A spherical reference surface with equal radii is a special case in which the planetodetic and planetocentric latitude definitions produce the same geometric direction.

### Authoritative references

- NAIF, Lunar Frames Kernel Tutorial:  
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/Tutorials/pdf/individual_docs/23_lunar-earth_pck-fk.pdf

- NAIF, Frames Required Reading:  
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/FORTRAN/req/frames.html

- NAIF, `pgrrec` — Planetographic to Rectangular Coordinates:  
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/pgrrec_c.html

- NAIF, `latrec` / `srfrec` and coordinate APIs:  
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/info/mostused.html

- NASA PDS, Coordinate System Identification:  
  https://pds.nasa.gov/datastandards/documents/dd/v1/PDS4_PDS_DD_1K00/webhelp/all/ch15s22.html

- USGS, Lunar Consortium Data historical archive metadata:  
  https://astrogeology.usgs.gov/search/map/lunar_consortium_data_historical_archive

- NASA PGDA Product 78:  
  https://pgda.gsfc.nasa.gov/products/78

- NASA PGDA Product 81:  
  https://pgda.gsfc.nasa.gov/products/81

## 4. Reference Frame Contract

### 4.1 Project baseline

The project baseline uses the lunar Mean Earth/rotation-axis reference system:

- Logical frame: `MOON_ME`
- Required realization for the DE421-based baseline: `MOON_ME_DE421`
- Frame center: Moon
- Coordinate origin: lunar center of mass as defined by the selected frame/data contract.

The implementation must not treat an unspecified generic `MOON_ME` alias as proof that a particular realization is active.

### 4.2 Frame identity

Every transformation input must carry an explicit frame identity and, where applicable, its realization.

For the initial project baseline, the supported frame realization is:

`MOON_ME_DE421`

The transformer must preserve the input frame identity in its output.

This phase does not transform coordinates between different frames.

A frame mismatch must produce an explicit failure rather than silently changing the frame identifier.

### 4.3 Ephemeris separation

The use of `MOON_ME_DE421` for this baseline does not establish DE421 as a universal requirement for all future solar-system vectors or Horizons data.

Frame realization and ephemeris provenance must remain explicit metadata.

No epoch-dependent orientation transformation is implemented in this phase.

## 5. Coordinate Input Contract

### 5.1 Required fields

The logical input must contain:

| Field | Requirement |
|---|---|
| Latitude | Required finite angular value |
| Latitude type | Explicitly `planetocentric` or `planetodetic` |
| Longitude | Required finite angular value |
| Longitude direction | Explicitly east-positive or west-positive |
| Longitude domain | Explicitly declared |
| Height | Required finite distance value |
| Height reference | Explicit reference-surface identity |
| Reference frame | Required |
| Frame realization | Required where applicable |
| Units | Explicit angular and distance units |

Unknown or missing conventions must not be inferred.

### 5.2 Latitude

Supported latitude types:

- `planetocentric`
- `planetodetic`

Latitude must be within:

`[-90°, +90°]`

North is positive and south is negative.

The selected latitude type must be retained as input metadata.

The transformer must not silently convert planetodetic latitude to planetocentric latitude using an undocumented shape model.

### 5.3 Longitude

The input contract supports:

- East-positive longitude.
- West-positive longitude, provided that the direction is explicitly declared.

The accepted input representation may use either:

- `[-180°, +180°]`
- `[0°, 360°)`

The transformer must normalize the value into a documented internal representation without changing its geographic meaning.

Unknown longitude direction must be rejected.

At either pole, longitude does not identify a unique physical point and must not affect the resulting polar position.

### 5.4 Canonical project regression coordinate

The existing project regression location is retained:

- Body: Moon
- Logical frame: `MOON_ME`
- Latitude type: `planetodetic`
- Longitude: `−160°` east-positive, equivalent to `200°E`
- Latitude: `−88.45°`
- Height: `0 km` under the explicitly selected spherical-reference-surface fixture convention
- Frame realization for the Phase 04C regression fixture: `MOON_ME_DE421`

The zero-height fixture convention is a geometric test definition relative to the Phase 04C sphere. It must not be represented as proof that an arbitrary LOLA Z value or another source's altitude uses the same vertical datum.

## 6. Reference Surface Contract

### 6.1 Selected model

Phase 04C uses a spherical reference surface.

Reference radius:

`R = 1,737,400 meters`

The model is explicitly spherical:

`a = b = c = 1,737,400 m`

This is a geometric reference model for this transformation, not a claim that the physical Moon or local lunar terrain is a perfect sphere.

### 6.2 Height semantics

Height `h` is a signed radial distance from the selected spherical reference surface.

The effective radius is:

`r = R + h`

The input must identify the reference surface against which `h` is defined.

The transformer must reject:

- Unknown height datum.
- Height relative to an incompatible ellipsoid.
- Terrain-relative height presented as sphere-relative height.
- LOLA elevation values whose vertical reference has not been reconciled with this contract.

No implicit height-datum conversion is permitted.

### 6.3 Planetocentric and planetodetic behavior

For this spherical model, planetocentric and planetodetic latitude have the same geometric result.

This equivalence applies only when the declared reference surface is exactly the selected sphere.

It must not be generalized to an ellipsoidal or triaxial model.

## 7. Forward Transformation

### 7.1 Input quantities

Let:

- `φ` = latitude in radians.
- `λ` = east-positive longitude in radians.
- `R` = reference sphere radius in meters.
- `h` = signed radial height in meters.
- `r = R + h`.

West-positive longitude must first be converted into the equivalent east-positive representation.

### 7.2 Transformation equations

For the selected spherical model:

`x = r × cos(φ) × cos(λ)`

`y = r × cos(φ) × sin(λ)`

`z = r × sin(φ)`

Output:

`p = (x, y, z)`

All output components are expressed in meters.

### 7.3 Axis convention

The Cartesian axes follow the declared body-fixed frame:

- +X: the frame's zero-latitude, zero-east-longitude direction.
- +Z: the frame's north-pole direction.
- +Y: the right-handed cross-product direction, consistent with the declared frame.

The transformer must not assume that this frame is interchangeable with another lunar frame realization.

### 7.4 Output contract

The result must be represented using the existing Phase 04B geometry types:

- `Vector3`
- `FramedVector3`
- `ReferenceFrameId`
- `CoordinateOriginId`
- `Angle`
- `Distance`

The output must preserve:

- Reference frame identity.
- Frame realization.
- Lunar origin identity.
- Meter units.
- The source coordinate and reference-surface provenance needed for diagnostics.

No duplicate geometry primitives should be introduced.

## 8. Validation and Numerical Safety

The transformer must reject:

1. NaN or infinite latitude.
2. NaN or infinite longitude.
3. Latitude outside `[-90°, +90°]`.
4. NaN or infinite height.
5. Missing or unknown longitude direction.
6. Missing or unknown latitude type.
7. Missing reference-surface identity.
8. Incompatible height reference.
9. Unsupported frame or unresolved frame realization.
10. Non-positive effective radius.
11. Non-finite Cartesian output.
12. Arithmetic overflow.

Additional rules:

- Do not introduce arbitrary epsilon values to repair invalid coordinates.
- Do not silently clamp invalid latitude.
- Do not silently replace invalid height with zero.
- Do not relabel a vector to another frame without a mathematically defined transformation.
- Preserve the numerical-safety and exception conventions established in Phase 04B.
- Domain code must not import Flutter libraries.
- Diagnostic context must follow the finite-scalar validation contract established in Phase 04B.

Numerical tolerances for verification must be derived from the mathematical operation sequence and the established binary64 numerical contract. Arbitrary tolerances must not be introduced.

## 9. Architecture

Implementation, when authorized, must remain inside:

`lib/features/scientific_geometry/`

The design may add narrowly scoped types for:

- Lunar geographic coordinate input.
- Latitude and longitude conventions.
- Spherical reference-surface identity.
- Height-reference identity.
- Forward coordinate transformation.

The exact file layout must reuse existing Phase 04B primitives and avoid unnecessary abstraction.

The Domain layer must remain independent of Flutter.

No changes to approved Phase 04A or Phase 04B contracts are authorized by this specification.

## 10. Verification Requirements

### 10.1 Cardinal and axis cases

Tests must cover:

| Latitude | East longitude | Expected geometric direction |
|---:|---:|---|
| 0° | 0° | +X |
| 0° | 90° | +Y |
| 0° | 180° | −X |
| 0° | 270° | −Y |
| +90° | Any valid longitude | +Z |
| −90° | Any valid longitude | −Z |

Expected magnitudes must reflect the selected effective radius.

### 10.2 Height cases

- Zero height relative to the selected sphere.
- Positive radial height.
- Negative radial height where the effective radius remains positive.
- Non-positive effective radius rejection.
- Missing height-reference rejection.
- Incompatible height-reference rejection.

### 10.3 Convention cases

- East-positive longitude.
- West-positive longitude with equivalent geographic position.
- Equivalent longitude representations across the accepted domains.
- Longitude wraparound.
- Pole behavior independent of longitude.
- Both supported latitude types under the spherical reference model.

### 10.4 Canonical regression case

For the existing project regression coordinate:

- Latitude: −88.45°
- Longitude: −160° east-positive
- Height: 0 m relative to the Phase 04C spherical fixture
- Radius: 1,737,400 m
- Frame: `MOON_ME_DE421`

The expected approximate Cartesian position is:

- X: −44,161.287394 m
- Y: −16,073.394118 m
- Z: −1,736,764.286453 m

The final test comparison must use a mathematically justified numerical error bound, not a hardcoded arbitrary epsilon.

### 10.5 Independent verification

Verification must not merely duplicate the production implementation in test code.

Use independently derived reference cases and, where appropriate, a separately configured NAIF/SPICE reference calculation with the correct lunar frame and shape-model definitions.

Any comparison involving SPICE must record the exact frame, kernel realization, shape model, coordinate type, longitude convention, and height semantics.

A reference result with mismatched metadata is not a valid independent verification.

## 11. Regression and Change-Control Requirements

- Preserve Phase 01, Phase 02, and Phase 03 approved behavior.
- Preserve approved Phase 04A and Phase 04B specifications and implementation.
- Do not modify existing geometry primitives unless a demonstrated requirement is separately reviewed and approved.
- Do not modify the LOLA DEM baseline.
- Do not change existing scientific reference times or equations from earlier SPICE work.
- Do not mark Phase 04 as operational after completing Phase 04C alone.
- Do not begin Phase 04D or later phases as part of this work.

## 12. Acceptance Criteria

Phase 04C implementation can be considered for approval only when:

1. The final specification is independently approved.
2. The implementation follows the approved coordinate, height, surface, and frame contracts.
3. All required unit and regression tests pass.
4. Independent verification uses matching scientific metadata.
5. `flutter analyze` passes without issues.
6. Formatting and `git diff --check` pass.
7. No unrelated changes are introduced.
8. The published commit is independently reviewed.
9. CI evidence, if available, is reported separately from local test evidence.

## 13. Current Decision

The four Phase 04C scope decisions are:

| Decision | Approved scope proposal |
|---|---|
| A — Reference frame | Explicit `MOON_ME` realization; project baseline uses `MOON_ME_DE421` |
| B — Height | Included only with explicit spherical reference-surface semantics |
| C — Input types | Geographic coordinates only |
| D — Inverse transformation | Deferred |

**Current status:** DRAFT — PENDING INDEPENDENT SCIENTIFIC REVIEW.

No implementation is authorized until this specification is independently reviewed and explicitly approved.

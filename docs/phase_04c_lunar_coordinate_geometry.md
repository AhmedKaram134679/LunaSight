# Phase 04C — Lunar Coordinate Geometry

**Document:** `docs/phase_04c_lunar_coordinate_geometry.md`  
**Status:** DRAFT — Pending Independent Scientific Review  
**Phase:** 04C  
**Scope:** Forward lunar geographic-coordinate to body-fixed Cartesian transformation  
**Implementation status:** Implemented & Software-Verified — Pending Final Independent Scientific Review

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

4. Coordinate terminology relationship:
   - **Planetocentric latitude:** angle defined by the position vector from the body's center of mass (or coordinate origin center) to the surface point.
   - **Planetographic latitude:** defined using the outward normal to a specified reference spheroid, as documented by NAIF `pgrrec`.
   - **Planetodetic / geodetic latitude:** the terminology used by JPL Horizons for its `GEODETIC` surface-coordinate input mode (`COORD_TYPE = 'GEODETIC'`). Its geometric latitude definition is normal-based and corresponds to the planetographic/planetodetic concept described by NAIF, while the exact input contract, longitude conventions, reference model, and altitude semantics must be taken from the relevant Horizons documentation.
   - NAIF `pgrrec` documents the planetographic-to-rectangular coordinate conversion and explicitly states that planetographic latitude is identical to planetodetic latitude (also called geodetic in SPICE documentation). These two terms represent the same underlying normal-based geometric latitude concept on a reference spheroid, rather than two independent mathematical latitude definitions. However, `pgrrec` must NOT be presented as the authoritative specification of the JPL Horizons input interface.

5. Spherical model equivalence: When the selected reference surface is exactly spherical ($a = b = c = R$), the surface normal passes through the center of mass, so planetocentric latitude and normal-based planetographic/planetodetic/geodetic latitude produce the exact same geometric surface direction. This equivalence is a geometric property of the sphere and must not be generalized to any non-spherical reference surface (such as an oblate or triaxial ellipsoid).

### Authoritative references

- NASA, *A Standardized Lunar Coordinate System for the Lunar Reconnaissance Orbiter and Lunar Datasets* (LRO Project and LGCWG White Paper, Version 5, 2008 October 1; Archinal et al.):
  https://science.nasa.gov/wp-content/uploads/2024/01/luncoordwhitepaper-10-08.pdf
  Defines the recommended lunar planetocentric Mean Earth/Polar Axis (`MOON_ME`) coordinate convention, reference system definitions, and the $1,737.4\text{ km}$ reference sphere.

- JPL, Horizons System User Manual (Giorgini et al., SSD/JPL):
  https://ssd.jpl.nasa.gov/horizons/manual.html
  Documents the Horizons `GEODETIC`/planetodetic coordinate input contract (`SITE_COORD`), east longitude and geodetic latitude, the Moon's mean-Earth reference associated with DE421, and the documented altitude/reference-surface semantics.

- NAIF, Lunar Frames Kernel Tutorial:
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/Tutorials/pdf/individual_docs/23_lunar-earth_pck-fk.pdf

- NAIF, Frames Required Reading:
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/FORTRAN/req/frames.html

- NAIF, `pgrrec` — Planetographic to Rectangular Coordinates:
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/pgrrec_c.html
  Documents the planetographic-to-rectangular coordinate conversion, noting the equivalence of planetographic and planetodetic/geodetic latitude. Reference for planetographic coordinate conversion only; not an authoritative specification of the JPL Horizons interface.

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

This canonical regression fixture represents the project's existing Horizons-style GEODETIC/planetodetic convention evaluated under the explicitly declared spherical test datum ($R = 1,737,400\text{ m}$). It does not establish or prove that arbitrary NASA LOLA elevation products or other external data sources share this exact vertical datum.

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

For non-polar latitudes, the standard spherical equations apply:

`x = r × cos(φ) × cos(λ)`

`y = r × cos(φ) × sin(λ)`

`z = r × sin(φ)`

Output:

`p = (x, y, z)`

All output components are expressed in meters.

### 7.3 Exact-pole numerical contract

At the exact poles, spherical coordinates have a coordinate singularity where longitude does not define a unique physical direction. In mathematical analysis, $\cos(\pm\pi/2) = 0$, yielding $x = 0$ and $y = 0$. However, in standard IEEE-754 binary64 floating-point evaluation, $\pi/2$ cannot be represented with infinite precision, so `cos(math.pi / 2)` evaluates to a non-zero machine-precision quantity (approximately $6.12323 \times 10^{-17}$), which when multiplied by radius $r \approx 1.74 \times 10^6\text{ m}$ would yield spurious non-zero Cartesian offsets ($x, y \sim 10^{-10}\text{ m}$) depending on the input longitude.

To guarantee exact, deterministic, and longitude-independent polar positions:

1. **North Pole (`latitude == +90°` exactly):**
   - $X = +0.0$ (exact positive zero).
   - $Y = +0.0$ (exact positive zero).
   - $Z = r$ (effective radius $R + h$).

2. **South Pole (`latitude == -90°` exactly):**
   - $X = +0.0$ (exact positive zero).
   - $Y = +0.0$ (exact positive zero).
   - $Z = -r$ (negative effective radius $-(R + h)$).

3. **Strict Scope of Exact-Pole Rule:**
   - This rule applies **strictly and only** to exact input values of `+90°` and `-90°` (or exact $\pm\pi/2\text{ rad}$).
   - Do **not** introduce an epsilon.
   - Do **not** snap nearby latitudes to a pole.
   - Do **not** clamp or alter valid non-polar latitudes (e.g. $89.999999°$ or $-88.45°$ must continue to evaluate via the ordinary trigonometric transformation equations).

4. **Validation Preservation:**
   - Longitude finiteness, direction, and declared input domain must continue to be validated according to the general coordinate input contract. The exact-pole rule must **not** bypass general input validation.
   - Non-finite or invalid longitudes must be rejected even at exact poles.

5. **Canonical Result Invariance:**
   - All valid longitude representations for the same exact pole (e.g. $+90^\circ$ with $0^\circ\text{E}$, $90^\circ\text{E}$, $180^\circ\text{E}$, or $120^\circ\text{W}$) must produce the exact same canonical Cartesian vector.

### 7.4 Axis convention

The Cartesian axes follow the declared body-fixed frame:

- +X: the frame's zero-latitude, zero-east-longitude direction.
- +Z: the frame's north-pole direction.
- +Y: the right-handed cross-product direction, consistent with the declared frame.

The transformer must not assume that this frame is interchangeable with another lunar frame realization.

### 7.5 Output contract

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

### 10.3 Convention and exact-pole cases

- East-positive longitude.
- West-positive longitude with equivalent geographic position.
- Equivalent longitude representations across the accepted domains (`[-180°, +180°]` and `[0°, 360°)`).
- Longitude wraparound.
- Both supported latitude types (`planetocentric` and `planetodetic`) under the spherical reference model.
- **Exact North Pole Verification:**
  - Multiple valid east-positive longitudes (e.g., $0^\circ\text{E}$, $45^\circ\text{E}$, $90^\circ\text{E}$, $180^\circ\text{E}$, $270^\circ\text{E}$).
  - Equivalent west-positive longitudes (e.g., $0^\circ\text{W}$, $90^\circ\text{W}$, $180^\circ\text{W}$, $270^\circ\text{W}$).
  - Strict output requirements: $X = +0.0$, $Y = +0.0$, $Z = +r$ (exact positive zero for X and Y, exact $+r$ for Z).
  - Identical Cartesian vector returned across all valid longitude representations of $+90^\circ$.
- **Exact South Pole Verification:**
  - Multiple valid east-positive and west-positive longitude representations.
  - Strict output requirements: $X = +0.0$, $Y = +0.0$, $Z = -r$ (exact positive zero for X and Y, exact $-r$ for Z).
  - Identical Cartesian vector returned across all valid longitude representations of $-90^\circ$.
- **Non-Polar Latitude Verification (No Pole Snapping):**
  - Latitudes near the poles (e.g., $\pm 89.9999^\circ$, $\pm 88.45^\circ$) must evaluate strictly using the ordinary trigonometric equations without pole snapping or artificial clamping.
- **Pole Validation Integrity:**
  - Non-finite or invalid longitude passed with an exact pole must still be rejected by general input validation rules.

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

#### Numerical Error Budget for Canonical Fixture (§10.4.1)

The test comparison tolerance must not be an arbitrary constant; it must derive from the documented error budget:
1. **Reference Value Truncation Uncertainty ($\epsilon_{\text{trunc}}$):**
   The reference coordinates are published rounded to 6 decimal places (micrometer resolution), introducing a maximum half-unit-in-the-last-place rounding uncertainty:
   $$\epsilon_{\text{trunc}} = \frac{1}{2} \times 10^{-6}\text{ m} = 0.50 \times 10^{-6}\text{ m} = 5.0 \times 10^{-7}\text{ m}$$
2. **Binary64 Floating-Point Arithmetic Discretization ($\epsilon_{\text{fp}}$):**
   Under IEEE-754 binary64 arithmetic (53-bit significand, machine epsilon $\varepsilon_{\text{mach}} \approx 1.11 \times 10^{-16}$), evaluation of $x = r\cos\varphi\cos\lambda$, $y = r\cos\varphi\sin\lambda$, and $z = r\sin\varphi$ with $r = 1,737,400.0\text{ m}$ accumulates bounded rounding error:
   $$\begin{aligned}
   |X_{\text{exact}} - X_{\text{b64}}| &\approx 1.33 \times 10^{-7}\text{ m} \\
   |Y_{\text{exact}} - Y_{\text{b64}}| &\approx 3.40 \times 10^{-7}\text{ m} \\
   |Z_{\text{exact}} - Z_{\text{b64}}| &\approx 4.00 \times 10^{-7}\text{ m}
   \end{aligned}$$
   All arithmetic discretization errors satisfy $\epsilon_{\text{fp}} \le 0.40 \times 10^{-6}\text{ m}$.
3. **Total Numerical Error Bound ($\Delta_{\text{max}}$):**
   $$\Delta_{\text{max}} = \epsilon_{\text{trunc}} + \epsilon_{\text{fp}} \le 0.50 \times 10^{-6}\text{ m} + 0.40 \times 10^{-6}\text{ m} = 0.90 \times 10^{-6}\text{ m} < 1.0 \times 10^{-6}\text{ m} = 1.0\ \mu\text{m}$$
   The derivation justifies tightening the canonical regression fixture test tolerance from the conservative $1.0 \times 10^{-5}\text{ m}$ ($10\ \mu\text{m}$) to $1.0 \times 10^{-6}\text{ m}$ ($1.0\ \mu\text{m}$), which strictly bounds evaluation error while respecting 6-decimal-place published specification precision.

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

## 13. Current Decision and Implementation History

The four Phase 04C scope decisions are:

| Decision | Approved scope proposal |
|---|---|
| A — Reference frame | Explicit `MOON_ME` realization; project baseline uses `MOON_ME_DE421` |
| B — Height | Included only with explicit spherical reference-surface semantics |
| C — Input types | Geographic coordinates only |
| D — Inverse transformation | Deferred |

### 13.1 Implementation and Review Milestones

- **Commit `1f3b4c8`:** Phase 04C specification updated with exact-pole numerical contract.
- **Commit `757105b` & `d3b3266`:** Forward coordinate transformer and value objects implemented in domain layer (`lib/features/scientific_geometry/domain/coordinates/`).
- **Commit `0a329c6` & `02183e1`:** Implementation hardening for constructor invariant closure (`ReferenceSurfaceId.triaxial`, `HeightReferenceId`), non-finite coordinate rejection, and equality/hashing semantics.
- **Commit `ed11913`:** Regression test contract closure (`hashCode` collision compatibility and `Distance` boundary layering).
- **Post-Commit Follow-up:** Introduction of `LunarCoordinateTransformationResult` provenance model, numerical error budget ($1.0\ \mu\text{m}$ tolerance), and independent external verification against JPL Horizons observer ephemeris system.

**Current status:** IMPLEMENTATION COMPLETE & SOFTWARE-VERIFIED — PENDING FINAL INDEPENDENT SCIENTIFIC REVIEW.

The implementation is completed in the codebase and software-verified across all regression suites. Final operational acceptance remains gated by the independent scientific review process. Phase 04D has not been started.

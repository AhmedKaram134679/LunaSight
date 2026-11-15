# Phase 06 — Milestone 03: Local Topocentric Coordinate Transformation
## Scientific Implementation, Corrective Audit & Verification Report

**Project:** LunaSight  
**Repository:** `AhmedKaram134679/LunaSight`  
**Target Branch:** `main`  
**Baseline Commit:** `f64d6aac40bfd38d9f2132cc29513f787ee97f9b`  
**Milestones Covered:** Phase 06 Milestones 02 & 03 Corrective Scientific Audit  
**Status:** FULLY VERIFIED  

---

## 1. Executive Summary

Following the implementation of Phase 06 Milestone 03, a targeted scientific audit and corrective patch were conducted on the baseline at commit `f64d6aac40bfd38d9f2132cc29513f787ee97f9b`.

The audit evaluated and addressed four core scientific questions:
1. **Reference Frame Enforcement:** Rigorous verification that `LocalTopocentricConverter` strictly accepts only `MOON_ME_DE421` with `CoordinateOriginId.moonCenterOfMass`, systematically rejecting all unsupported frames (including cases where both vectors share an identical unsupported frame such as `ICRF` or `J2000`).
2. **Epoch Compatibility:** Defining and enforcing an explicit physical instant compatibility contract (`AstronomicalTime.representsSameInstant()`), ensuring relative celestial vectors are only evaluated across physically identical epochs regardless of whether civil (`UTC`) or dynamical (`TT`, `TDB`, `TAI`) scales are used.
3. **Leap-Second Validity Boundary:** Correcting upper-boundary exclusivity on the guaranteed IERS horizon $[1972-01-01\text{T}00:00:00\text{Z}, 2027-01-01\text{T}00:00:00\text{Z})$, ensuring the exact instant $2027-01-01\text{T}00:00:00\text{Z}$ is correctly identified as unconfirmed.
4. **TDB Dynamical Time Model Audit & Attribution:** Conducting a literature and numerical audit of the compact Keplerian relation $\text{TDB} - \text{TT} = 0.001657\sin(g + 0.0167\sin g)$, clarifying its attribution to USNO Circular No. 179 / Moyer 1981 / Fairhead & Bretagnon 1990 leading term, measuring its residual against multi-harmonic planetary series ($\approx 31\ \mu\text{s}$ over 1950–2050, $\le 54\ \mu\text{s}$ over 1900–2100), and confirming it satisfies the project's $100\ \mu\text{s}$ surface timing requirement.
5. **Topocentric Model Typing:** Promoting topocentric slant and horizontal ranges to strongly typed `Distance` quantities while preserving signed Cartesian SEZ projections and backward-compatible meter getters.

---

## 2. Confirmed Defects, Root Causes & Resolutions

| Defect ID | Component | Root Cause | Corrective Action |
| :--- | :--- | :--- | :--- |
| **Fix A** | `LocalTopocentricConverter.toTopocentric()` | Nested `if (target != moonMeDe421 || observer != moonMeDe421)` only threw if `target.frame != observer.frame`. Thus, two vectors sharing `ICRF` passed through unchecked. | Rewrote frame validation to enforce `targetVector.frame == moonMeDe421 && observerVector.frame == moonMeDe421`. If both vectors share an identical unsupported frame, throws `UNSUPPORTED_REFERENCE_FRAME`. If frames mismatch, throws `INCOMPATIBLE_REFERENCE_FRAME`. Enforced `CoordinateOriginId.moonCenterOfMass`. |
| **Fix B** | `CelestialVector` & `LocalTopocentricConverter` | `relativePositionFrom()` and `toTopocentric()` subtracted target and observer position vectors without asserting epoch physical equivalence. | Added `AstronomicalTime.representsSameInstant(other, toleranceSeconds: 1e-6)`. Both `relativePositionFrom()` and `toTopocentric()` now throw `INCOMPATIBLE_EPOCHS` if epochs represent different physical instants. If time scales differ (e.g. UTC vs TT), instances are converted to unified TT for exact comparison. Preserved target epoch in `TopocentricPosition`. |
| **Fix C** | `LeapSecondProvider` | The guaranteed IERS horizon $[1972-01-01, 2027-01-01)$ is upper-boundary exclusive. Using `!isAfter(2027-01-01)` incorrectly allowed the exact boundary instant $2027-01-01\text{T}00:00:00\text{Z}$. | Updated `isConfirmed()` to `!isBefore(minSupportedUtc) && isBefore(guaranteedUntilUtc)`. Updated `getTaiMinusUtcSeconds()` to reject `!isBefore(guaranteedUntilUtc)` with `TIME_SCALE_UNCONFIRMED_FUTURE` under default `allowExtrapolation: false`. |
| **Fix D** | `AstronomicalTime` | Class docstring attributed the compact expression $0.001657\sin(g + 0.0167\sin g)$ to Fairhead & Bretagnon and claimed $< 10\ \mu\text{s}$ accuracy. Full Fairhead & Bretagnon is a multi-harmonic series (127 to 787 terms). | Audited exact formulation: leading Keplerian term (Moyer 1981 / USNO Circular No. 179 / Fairhead & Bretagnon 1990 leading term). Quantified residual: maximum $\approx 31\ \mu\text{s}$ over 1950–2050 and $\le 54\ \mu\text{s}$ over 1900–2100. Updated documentation to transparently state accuracy bounds ($\text{RMS} \approx 20\ \mu\text{s}$, max $31\ \mu\text{s}$) and verify it satisfies the $100\ \mu\text{s}$ requirement. |
| **Audit E** | `TopocentricPosition` | Slant and horizontal ranges were stored as raw `double` fields instead of the existing typed `Distance` abstraction. | Updated `slantRange` and `horizontalRange` fields to `Distance`. Added backward-compatible getters `slantRangeMeters` and `horizontalRangeMeters`. Retained signed Cartesian components ($S, E, Z$) as `double` meters because `Distance` is strictly non-negative. |

---

## 3. Mathematical & Scientific Contracts

### 3.1 Local Horizon Orthonormal Basis (SEZ)
For observer selenographic latitude $\varphi$ and longitude $\lambda$:
$$\hat{\mathbf{u}}_Z = (\cos\varphi\cos\lambda, \; \cos\varphi\sin\lambda, \; \sin\varphi)$$
$$\hat{\mathbf{u}}_N = (-\sin\varphi\cos\lambda, \; -\sin\varphi\sin\lambda, \; \cos\varphi)$$
$$\hat{\mathbf{u}}_E = (-\sin\lambda, \; \cos\lambda, \; 0)$$
$$\hat{\mathbf{u}}_S = -\hat{\mathbf{u}}_N = (\sin\varphi\cos\lambda, \; \sin\varphi\sin\lambda, \; -\cos\varphi)$$

**Right-Handedness Invariant:**
$$\hat{\mathbf{u}}_S \times \hat{\mathbf{u}}_E = \hat{\mathbf{u}}_Z$$

### 3.2 South Pole Deterministic Meridian Convention
At $\varphi = -90^\circ$:
$$\hat{\mathbf{u}}_Z = (0, 0, -1)$$
$$\hat{\mathbf{u}}_N = (\cos\lambda, \; \sin\lambda, \; 0)$$
$$\hat{\mathbf{u}}_E = (-\sin\lambda, \; \cos\lambda, \; 0)$$
$$\hat{\mathbf{u}}_S = (-\cos\lambda, \; -\sin\lambda, \; 0)$$
For $\lambda = 0^\circ$ (Prime Meridian):
- $\hat{\mathbf{u}}_N = (1, 0, 0)$
- $\hat{\mathbf{u}}_E = (0, 1, 0)$
- $\hat{\mathbf{u}}_Z = (0, 0, -1)$

### 3.3 Topocentric Coordinate Formulas
Given relative vector $\boldsymbol{\rho} = \mathbf{r}_{\text{target}} - \mathbf{r}_{\text{obs}}$ in meters:
- $S = -\boldsymbol{\rho} \cdot \hat{\mathbf{u}}_N$
- $E = \boldsymbol{\rho} \cdot \hat{\mathbf{u}}_E$
- $Z = \boldsymbol{\rho} \cdot \hat{\mathbf{u}}_Z$
- Horizontal Range: $H = \sqrt{S^2 + E^2} \implies \text{Distance.fromMeters}(H)$
- Slant Range: $\rho = \sqrt{S^2 + E^2 + Z^2} \implies \text{Distance.fromMeters}(\rho)$
- Elevation: $\theta = \operatorname{atan2}(Z, H) \in [-90^\circ, +90^\circ]$
- Azimuth: $\alpha = \operatorname{atan2}(E, -S) \pmod{360^\circ}$ (measured clockwise from North)

### 3.4 Epoch Compatibility Contract
Two instances $t_1, t_2 \in \text{AstronomicalTime}$ represent the same physical instant within tolerance $\epsilon = 10^{-6}\text{ s}$ if:
- If $\text{scale}(t_1) = \text{scale}(t_2)$:
  $$|t_1.\text{differenceInSeconds}(t_2)| \le \epsilon$$
- If scales differ:
  $$|t_1.\text{toTerrestrialTime}().\text{differenceInSeconds}(t_2.\text{toTerrestrialTime}())| \le \epsilon$$

---

## 4. Test Suite Execution & Verification Matrix

All tests executed sequentially without concurrency instability:

| Test Suite | File Path | Tests | Exit Code | Result |
| :--- | :--- | :---: | :---: | :---: |
| **Milestone 02 Time & Vector Tests** | `test/features/solar_earth_visibility/domain/models/astronomical_time_test.dart` | 15 | 0 | **PASSED** |
| **Milestone 03 Topocentric Converter Tests** | `test/features/solar_earth_visibility/domain/services/local_topocentric_converter_test.dart` | 9 | 0 | **PASSED** |
| **Terrain Horizon Tests (Phase 05)** | `test/features/terrain_horizon/` | 33 | 0 | **PASSED** |
| **Scientific Geometry Tests (Phase 04)** | `test/features/scientific_geometry/` | 106 | 0 | **PASSED** |
| **Compile-Time Finality Tests** | `test/compile_time/` | 2 | 0 | **PASSED** |
| **App, Sites, NASA Data & Home Tests** | `test/app/ test/features/lunar_sites/ test/features/nasa_data/ test/core/ test/features/home_test.dart` | 101 | 0 | **PASSED** |
| **Total Test Count** | All 23 test files across repository | **266** | 0 | **266 / 266 PASSED** |
| **Dart Static Analysis** | `flutter analyze` | - | 0 | **0 issues found** |
| **Code Formatting** | `dart format --output=none --set-exit-if-changed lib/ test/` | - | 0 | **99 files clean** |
| **Git Diff Whitespace Check** | `git diff --check` | - | 0 | **Clean** |

---

## 5. Phase 04 and Phase 05 Protection Status

$$\mathbf{PHASE\; 04\; AND\; PHASE\; 05\; IMPLEMENTATION\; AND\; TESTS\; REMAIN\; 100\%\; UNTOUCHED.}$$

- Zero lines changed in `lib/features/terrain_horizon/` or `lib/features/scientific_geometry/`.
- All 33 Phase 05 tests and 106 Phase 04 tests pass without modification or regression.

---

## 6. Files Changed & Justification

1. `lib/features/solar_earth_visibility/domain/services/local_topocentric_converter.dart`:
   - Enforced explicit `MOON_ME_DE421` and `moonCenterOfMass` validation; rejected unsupported identical frames (`UNSUPPORTED_REFERENCE_FRAME`).
   - Enforced epoch compatibility via `representsSameInstant()`; rejects differing physical instants (`INCOMPATIBLE_EPOCHS`).
   - Constructed `TopocentricPosition` using strongly-typed `Distance` quantities.
2. `lib/features/solar_earth_visibility/domain/models/celestial_vector.dart`:
   - Enforced epoch compatibility in `relativePositionFrom()`; rejects differing physical instants (`INCOMPATIBLE_EPOCHS`).
3. `lib/features/solar_earth_visibility/domain/models/leap_second_provider.dart`:
   - Corrected exclusive upper-boundary check `isBefore(guaranteedUntilUtc)`.
4. `lib/features/solar_earth_visibility/domain/models/astronomical_time.dart`:
   - Added `representsSameInstant()` with scale unification to Terrestrial Time.
   - Corrected documentation and attribution for the compact TDB Keplerian approximation ($20\ \mu\text{s}$ RMS, $31\ \mu\text{s}$ max residual).
5. `lib/features/solar_earth_visibility/domain/models/topocentric_position.dart`:
   - Typed `slantRange` and `horizontalRange` as `Distance`.
   - Maintained backward-compatible `slantRangeMeters` and `horizontalRangeMeters` getters.
6. `test/features/solar_earth_visibility/domain/models/astronomical_time_test.dart`:
   - Added boundary test cases for `2026-12-31T23:59:59.999999Z`, `2027-01-01T00:00:00Z`, `2027-01-01T00:00:00.000001Z`, and future dates.
   - Added regression test for `CelestialVector.relativePositionFrom()` epoch compatibility.
7. `test/features/solar_earth_visibility/domain/services/local_topocentric_converter_test.dart`:
   - Added regression tests for unsupported identical frames (both `ICRF`, both `J2000`), frame mismatch, origin mismatch.
   - Added regression test for differing epochs and equivalent cross-scale epochs (UTC vs TT).

---

## 7. Final Decision

$$\mathbf{FULLY\; VERIFIED}$$

All critical contracts, reference-frame constraints, epoch compatibility policies, leap-second boundaries, and TDB accuracy claims have been demonstrated by independent numerical evidence and verified by 266 passing tests. The codebase is clean, formatted, and ready for future Phase 06 milestones.

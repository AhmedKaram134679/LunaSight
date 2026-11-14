# Phase 06 — Milestone 02: Shared Astronomical Infrastructure & Time Models
## Production-Grade Implementation & Verification Report

**Project:** LunaSight  
**Repository:** `AhmedKaram134679/LunaSight`  
**Target Branch:** `main`  
**Baseline Commit:** `e9a6b5606bc6301b555ec422fd2df0f6dea88d1d`  
**Milestone:** Phase 06 — Milestone 02  
**Status:** FULLY IMPLEMENTED & VERIFIED  

---

## 1. Executive Summary & Objective

Phase 06 Milestone 02 establishes the shared astronomical time infrastructure and celestial vector contracts required for high-precision lunar solar illumination and Earth visibility modeling.

Civil time (UTC) is fundamentally distinct from dynamical astronomical time scales (TAI, TT, TDB). Planetary ephemerides such as JPL DE421/DE440 are parametrized in Barycentric Dynamical Time (TDB). Prior to evaluating solar or Earth vectors, user scenario timestamps must be converted into dynamical time with sub-millisecond precision, accounting for leap seconds and general relativistic variations.

### Key Implemented Components
1. **`TimeScale`** (`time_scale.dart`): Strongly typed enumeration separating UTC, TAI, TT, and TDB.
2. **`LeapSecondProvider`** (`leap_second_provider.dart`): Authoritative step-based leap second table sourced from IERS Bulletins and USNO `tai-utc.dat` spanning 1972 through 2026+ ($\Delta\text{AT} = 10\text{ s}$ to $37\text{ s}$).
3. **`AstronomicalTime`** (`astronomical_time.dart`): Split two-part Julian Date representation ($\text{jdBase} + \text{secondOfDay}$) ensuring sub-microsecond precision across multi-century time spans without IEEE-754 mantissa exhaustion. Implements bidirectional conversions between Gregorian UTC calendar dates, Julian Dates, TT, and TDB.
4. **`CelestialVector`** (`celestial_vector.dart`): Strongly typed 3D celestial state vector binding spatial position [FramedVector3] with its exact observation epoch [AstronomicalTime]. Enforces frame and origin invariants during relative vector calculations.

---

## 2. Scientific Time Scales & Conversion Models

### 2.1 Leap Seconds ($\Delta\text{AT} = \text{TAI} - \text{UTC}$)
- Modern UTC leap second stepping began on 1972-01-01 ($\Delta\text{AT} = 10\text{ s}$).
- The table contains all 28 leap second adjustments declared by IERS Bulletin C through the latest adjustment on 2017-01-01 ($\Delta\text{AT} = 37\text{ s}$).
- Under IERS Bulletin C declarations, no leap seconds are scheduled through at least 2026-12-31.
- Dates before 1972-01-01 are explicitly rejected with `TIME_SCALE_OUT_OF_RANGE`.
- Dates past 2027-01-01 require explicit `allowExtrapolation` flag (defaults to true for forward planning, or throws `TIME_SCALE_UNCONFIRMED_FUTURE` if strict confirmation is requested).

### 2.2 Terrestrial Time (TT)
$$\text{TT} = \text{TAI} + 32.184\text{ s} = \text{UTC} + \Delta\text{AT} + 32.184\text{ s}$$
- J2000.0 epoch: 2000-01-01 12:00:00 TT (JD $2451545.0\text{ TT}$).
- At J2000.0 UTC, $\Delta\text{AT} = 32\text{ s} \implies \text{TT} - \text{UTC} = 64.184\text{ s} \implies \text{JD}_{\text{TT}} = 2451545.0007428704$.
- At 2024-01-01 00:00:00 UTC, $\Delta\text{AT} = 37\text{ s} \implies \text{TT} - \text{UTC} = 69.184\text{ s} \implies \text{JD}_{\text{TT}} = 2460310.5008007407$.

### 2.3 Barycentric Dynamical Time (TDB)
TDB accounts for relativistic time dilation caused by Earth's orbital eccentricity in the Sun's gravitational potential.
The implementation uses the Fairhead & Bretagnon / USNO circular approximation:
$$\text{TDB} - \text{TT} = 0.001657\sin(g + 0.0167\sin g)\text{ seconds}$$
where:
$$g = 357.53^\circ + 35999.05^\circ T_{\text{TT}}$$
and $T_{\text{TT}} = (\text{JD}_{\text{TT}} - 2451545.0) / 36525.0$.
This circular series is accurate to within $< 10\text{ microseconds}$ over the modern era ($\sim 1900–2100$), satisfying high-precision planetary and lunar surface visibility requirements.

---

## 3. Celestial Vector Invariants & Contracts

`CelestialVector` integrates directly with the Phase 04 `FramedVector3` and `ReferenceFrameId`:
- **Explicit Frame Identity**: Encapsulates spatial orientation (e.g. `ReferenceFrameId.moonMeDe421`, `ReferenceFrameId.icrf`, `ReferenceFrameId.j2000`).
- **Explicit Origin**: Separates `moonCenterOfMass`, `earthCenterOfMass`, and `topocentricSite`.
- **Relative Position Math**:
  $$\mathbf{r}_{\text{rel}} = \mathbf{r}_{\text{target}} - \mathbf{r}_{\text{observer}}$$
  Strictly validates that target and observer share the identical coordinate frame and coordinate origin, throwing `INCOMPATIBLE_REFERENCE_FRAME` or `INCOMPATIBLE_COORDINATE_ORIGIN` on violation.

---

## 4. Verification Test Results

| Test Target | Suite Path | Tests | Exit Code | Status |
| :--- | :--- | :---: | :---: | :---: |
| **Milestone 02 Time & Vector Tests** | `test/features/solar_earth_visibility/domain/models/astronomical_time_test.dart` | 13 | 0 | **PASSED** |
| **Terrain Horizon Tests (Phase 05)** | `test/features/terrain_horizon/` | 33 | 0 | **PASSED** |
| **Scientific Geometry Tests (Phase 04)** | `test/features/scientific_geometry/` | 106 | 0 | **PASSED** |
| **Compile-Time Finality Tests** | `test/compile_time/` | 2 | 0 | **PASSED** |
| **Dart Static Analysis** | `flutter analyze` | - | 0 | **PASSED (0 issues)** |
| **Code Formatting** | `dart format --output=none --set-exit-if-changed lib/ test/` | - | 0 | **PASSED (Clean)** |
| **Git Diff Whitespace Check** | `git diff --check` | - | 0 | **PASSED (Clean)** |

---

## 5. Phase 05 Protection Status

$$\mathbf{PHASE\; 05\; IMPLEMENTATION\; AND\; TESTS\; REMAIN\; 100\%\; UNTOUCHED.}$$

All 33 Terrain Horizon tests, 106 Scientific Geometry tests, and compile-time finality tests pass without regression. Zero modifications were made to Phase 04 or Phase 05 files.

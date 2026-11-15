# Phase 06 Milestones 02–03: Targeted Scientific Audit Report
## TDB Accuracy Verification and Epoch Tolerance Validation

**Project:** LunaSight  
**Repository:** `AhmedKaram134679/LunaSight`  
**Current Branch:** `main`  
**Baseline Commit:** `f36cc865cc0d7c2d43d32589ded235aff4d9207f`  
**Audit Type:** Targeted Scientific & Numerical Verification  
**Final Status:** **PASS**

---

## 1. Executive Summary

This targeted scientific audit investigated two specific numerical and architectural questions in the committed Phase 06 implementation:
1. **Independent Benchmark of the Existing TDB Approximation:** Rigorously tested LunaSight's implemented compact Keplerian $\text{TDB} - \text{TT}$ approximation against the canonical IAU SOFA / ERFA 787-term Fairhead & Bretagnon 1990 model over both 1950–2050 (36,890 daily samples) and 1900–2100 (73,414 daily samples).
2. **Validation and Hardening of the Epoch Comparison Tolerance API:** Enforced strict non-negative finite validation on `toleranceSeconds` in `AstronomicalTime.representsSameInstant()`, preventing invalid NaN, infinite, or negative tolerances while preserving exact zero-tolerance comparisons.

All 267 repository tests pass, static analysis is clean (`0 issues`), and Phase 04 and Phase 05 remain 100% untouched.

---

## 2. Baseline Status

- **Initial Branch:** `main`
- **Initial HEAD:** `f36cc865cc0d7c2d43d32589ded235aff4d9207f`
- **Initial Working Tree:** Clean (`git status --short` returned 0 modified files).
- **Inspected Files:**
  - `lib/features/solar_earth_visibility/domain/models/astronomical_time.dart`
  - `lib/features/solar_earth_visibility/domain/models/time_scale.dart`
  - `lib/features/solar_earth_visibility/domain/models/leap_second_provider.dart`
  - `lib/features/solar_earth_visibility/domain/models/celestial_vector.dart`
  - `lib/features/solar_earth_visibility/domain/services/local_topocentric_converter.dart`
  - `test/features/solar_earth_visibility/domain/models/astronomical_time_test.dart`
  - `test/features/solar_earth_visibility/domain/services/local_topocentric_converter_test.dart`

---

## 3. Objective A — TDB Approximation Independent Benchmark

### 3.1 Implemented Formula
LunaSight implements the compact Keplerian analytical formulation (USNO Circular No. 179 Eq. 2.6 leading term / Moyer 1981 / Fairhead & Bretagnon 1990):
$$\Delta t_{\text{TDB}-\text{TT}} = 0.001657 \sin\left(g + 0.0167 \sin g\right) \quad \text{seconds}$$
where:
$$T_{\text{TT}} = \frac{\text{JD}_{\text{TT}} - 2451545.0}{36525.0}$$
$$g = \left(357.53^\circ + 35999.05^\circ \, T_{\text{TT}}\right) \times \frac{\pi}{180^\circ} \quad \text{radians}$$

### 3.2 Independent Reference Standard
- **Library:** IAU SOFA / ERFA (Essential Routines for Fundamental Astronomy) C Library (release 2023-10-11).
- **Official Source:** `https://raw.githubusercontent.com/liberfa/erfa/master/src/dtdb.c`
- **Reference Routine:** `eraDtdb(date1, date2, ut, elong, u, v)` evaluated in the geocentric frame ($u = 0\text{ km}$, $v = 0\text{ km}$, topocentric clock correction $w_t = 0$).
- **Model Standard:** Full 787-term Poisson series from Fairhead & Bretagnon (1990) covering $T^0$ through $T^4$ harmonics, adjusted for JPL planetary masses.

### 3.3 Benchmark Execution & Numerical Results

The reproducible benchmark script (`tool/benchmark_tdb.py`) executed across both date intervals with daily temporal resolution:

| Metric | Range A: 1950–2050 | Range B: 1900–2100 |
| :--- | ---: | ---: |
| **Sample count** | 36,890 | 73,414 |
| **Sampling interval** | 1 day | 1 day |
| **RMS residual** | **$16.7850\ \mu\text{s}$** | **$16.9828\ \mu\text{s}$** |
| **Maximum absolute residual** | **$37.7448\ \mu\text{s}$** | **$40.0050\ \mu\text{s}$** |
| **Date of maximum residual** | 1960-10-12 00:00:00 UTC | 1901-10-06 00:00:00 UTC |
| **Minimum signed residual** | $-33.9947\ \mu\text{s}$ | $-36.3431\ \mu\text{s}$ |
| **Maximum signed residual** | $+37.7448\ \mu\text{s}$ | $+40.0050\ \mu\text{s}$ |

Sub-daily hourly evaluation confirmed that peak residuals remain strictly bounded ($37.7449\ \mu\text{s}$ on 1960-10-12 01:00 UTC; $40.0067\ \mu\text{s}$ on 1901-10-05 19:00 UTC).

### 3.4 Key Reference Dates Comparison

| Date & Time (UTC) | Julian Date (TT) | IAU SOFA `eraDtdb` | LunaSight Implemented | Residual |
| :--- | ---: | ---: | ---: | ---: |
| **1900-01-01 00:00:00** | 2415020.5000 | $-18.4602\ \mu\text{s}$ | $-30.2011\ \mu\text{s}$ | $-11.7409\ \mu\text{s}$ |
| **1901-10-06 00:00:00** | 2415663.5000 | $-1696.2251\ \mu\text{s}$ | $-1656.2201\ \mu\text{s}$ | $+40.0050\ \mu\text{s}$ |
| **1950-01-01 00:00:00** | 2433282.5000 | $-70.6983\ \mu\text{s}$ | $-58.6467\ \mu\text{s}$ | $+12.0516\ \mu\text{s}$ |
| **1960-10-12 00:00:00** | 2437219.5000 | $-1681.0684\ \mu\text{s}$ | $-1643.3236\ \mu\text{s}$ | $+37.7448\ \mu\text{s}$ |
| **2000-01-01 12:00:00 (J2000)** | 2451545.0000 | $-99.3072\ \mu\text{s}$ | $-72.6020\ \mu\text{s}$ | $+26.7052\ \mu\text{s}$ |
| **2000-02-29 00:00:00 (Leap Year)** | 2451603.5000 | $+1346.9487\ \mu\text{s}$ | $+1373.2818\ \mu\text{s}$ | $+26.3331\ \mu\text{s}$ |
| **2024-02-29 00:00:00 (Leap Year)** | 2460369.5000 | $+1343.6085\ \mu\text{s}$ | $+1369.5457\ \mu\text{s}$ | $+25.9372\ \mu\text{s}$ |
| **2026-11-15 00:00:00 (Current)** | 2461359.5000 | $-1249.0550\ \mu\text{s}$ | $-1269.7349\ \mu\text{s}$ | $-20.6799\ \mu\text{s}$ |
| **2050-12-31 00:00:00** | 2470171.5000 | $-111.8393\ \mu\text{s}$ | $-122.9810\ \mu\text{s}$ | $-11.1416\ \mu\text{s}$ |
| **2100-12-31 00:00:00** | 2488433.5000 | $-127.4891\ \mu\text{s}$ | $-151.3377\ \mu\text{s}$ | $-23.8487\ \mu\text{s}$ |

### 3.5 Scientific Evaluation & Decision Gate
- **Source of Residuals:** The compact formula captures the primary annual term ($1.657\text{ ms}$) and its semi-annual harmonic ($13.8\ \mu\text{s}$) generated by the Keplerian eccentricity term $0.0167\sin g$. The residual $\le 40\ \mu\text{s}$ matches the unmodeled planetary perturbations from Jupiter ($22.4\ \mu\text{s}$ at $5753\text{ rad/millennium}$) and Saturn ($4.8\ \mu\text{s}$ at $530\text{ rad/millennium}$).
- **Physical Significance:** At the lunar sidereal rotation rate ($\approx 0.55\text{ arcsec/s}$), a timing difference of $40\ \mu\text{s}$ causes a maximum topocentric solar/lunar position displacement of:
  $$\Delta \theta = 0.55''/\text{s} \times 40 \times 10^{-6}\text{ s} \approx 0.000022'' = 0.022\text{ milliarcseconds}$$
- **Decision:** Because the measured maximum residual ($40.01\ \mu\text{s}$) is well below the target precision threshold ($100\ \mu\text{s}$) and produces sub-milliarcsecond pointing error, **the existing compact formula is mathematically sound and retained without modification.** The documentation in `astronomical_time.dart` was updated to reflect the exact empirical numbers ($16.79\ \mu\text{s}$ RMS, $37.74\ \mu\text{s}$ max over 1950–2050; $16.98\ \mu\text{s}$ RMS, $40.01\ \mu\text{s}$ max over 1900–2100).

---

## 4. Objective B — Epoch Comparison Tolerance Validation

### 4.1 Validation Rules Implemented
In `AstronomicalTime.representsSameInstant()`:
- `toleranceSeconds.isFinite`: Rejects `NaN`, `+Infinity`, and `-Infinity` by throwing `ScientificComputationException` with code `NON_FINITE_VALUE`. Context values are serialized cleanly to prevent `ArgumentError` in exception context sanitization.
- `toleranceSeconds < 0.0`: Rejects negative values by throwing `ScientificComputationException` with code `INVALID_TOLERANCE`.
- `toleranceSeconds == 0.0`: Strictly accepted, enforcing exact numerical equality between epochs.

### 4.2 Test Coverage Added
1. **Default Tolerance:** $10^{-6}\text{ s}$ accepted.
2. **Positive Finite Tolerance:** Custom values ($10\ \mu\text{s}$, $2\ \mu\text{s}$) correctly discriminate epochs.
3. **Zero Tolerance:** Identical epochs return `true`; $1\ \mu\text{s}$ different epochs return `false`.
4. **Negative Tolerance:** Throws `INVALID_TOLERANCE`.
5. **NaN Tolerance:** Throws `NON_FINITE_VALUE`.
6. **Positive Infinity Tolerance:** Throws `NON_FINITE_VALUE`.
7. **Negative Infinity Tolerance:** Throws `NON_FINITE_VALUE`.
8. **Immutability Invariant:** Neither instance is modified during comparison.
9. **Converter Integration:** `LocalTopocentricConverter.toTopocentric()` propagates tolerance validation and rejects negative/NaN/infinite tolerances.

---

## 5. Verification Matrix & Test Counts

| Step | Test Suite / Check | Command | Count / Target | Status |
| :---: | :--- | :--- | :---: | :---: |
| 1 | **Time & Vector Models** | `flutter test test/features/solar_earth_visibility/domain/models/astronomical_time_test.dart` | 16 tests | **PASSED** |
| 2 | **Topocentric Converter** | `flutter test test/features/solar_earth_visibility/domain/services/local_topocentric_converter_test.dart` | 9 tests | **PASSED** |
| 3 | **All Solar & Earth Visibility** | `flutter test test/features/solar_earth_visibility/` | 25 tests | **PASSED** |
| 4 | **Scientific Geometry (Phase 04)** | `flutter test test/features/scientific_geometry/` | 106 tests | **PASSED** |
| 5 | **Terrain Horizon (Phase 05)** | `flutter test test/features/terrain_horizon/` | 33 tests | **PASSED** |
| 6 | **Compile-Time Tests** | `flutter test test/compile_time/` | 2 tests | **PASSED** |
| 7 | **Full Repository Test Suite** | `flutter test` | **267 tests (23 suites)** | **PASSED** |
| 8 | **Static Analysis** | `flutter analyze` | Full project | **0 issues** |
| 9 | **Formatting** | `dart format --output=none --set-exit-if-changed lib/ test/` | 99 files | **Clean** |
| 10 | **Git Diff Check** | `git diff --check` | Working tree | **Clean** |

---

## 6. Files Changed & Created

1. `lib/features/solar_earth_visibility/domain/models/astronomical_time.dart`:
   - Added finite and non-negative validation for `toleranceSeconds` in `representsSameInstant()`.
   - Updated documentation with exact independent benchmark metrics ($16.79\ \mu\text{s}$ RMS, $37.74\ \mu\text{s}$ max for 1950–2050; $16.98\ \mu\text{s}$ RMS, $40.01\ \mu\text{s}$ max for 1900–2100).
2. `test/features/solar_earth_visibility/domain/models/astronomical_time_test.dart`:
   - Added comprehensive tests for default, positive, zero, negative, NaN, $+$\infty, and $-$\infty tolerance parameters.
3. `test/features/solar_earth_visibility/domain/services/local_topocentric_converter_test.dart`:
   - Added validation test asserting that `toTopocentric()` rejects invalid tolerances.
4. `tool/benchmark_tdb.py`:
   - Reproducible standalone benchmark script evaluating LunaSight against IAU SOFA `eraDtdb`.
5. `tool/sofa_dtdb_cached.c`:
   - Cached reference source of IAU SOFA / ERFA `dtdb.c` for offline benchmark reproducibility.
6. `docs/phase_06_targeted_scientific_audit.md`:
   - Complete technical audit report.

---

## 7. Protection of Prior Phases

$$\mathbf{PHASE\; 04\; AND\; PHASE\; 05\; CODE\; AND\; TESTS\; REMAIN\; 100\%\; UNTOUCHED.}$$

- Zero changes in `lib/features/scientific_geometry/` or `lib/features/terrain_horizon/`.
- All 106 Phase 04 tests and 33 Phase 05 tests pass without modification.

---

## 8. Final Verdict

$$\mathbf{PASS}$$

Both objectives are completely verified and validated with reproducible empirical evidence:
- The existing TDB formula is independently benchmarked and mathematically justified.
- The epoch comparison tolerance parameter is fully hardened, rejects invalid inputs, and preserves existing APIs.
- The repository is clean, formatted, and fully green across all 267 tests.

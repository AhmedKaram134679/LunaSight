# Phase 06 Milestones 02–03: Targeted Scientific Audit Report
## Native ERFA `eraDtdb()` Benchmark Execution, Time-Scale Integrity, and Epoch Tolerance Validation

**Project:** LunaSight  
**Repository:** `AhmedKaram134679/LunaSight`  
**Current Branch:** `main`  
**Baseline Commit:** `69d558d60443e77266e78cc85b391c758d37250b`
**Audit Type:** Native Reference Execution & Numerical Verification
**Final Status:** **PASS**

---

## 1. Executive Summary

This targeted audit corrected the reference execution architecture of the TDB benchmark and independently evaluated LunaSight's astronomical time infrastructure:
1. **Direct Native C Reference Execution:** Eliminated intermediate Python/NumPy coefficient table re-evaluations. The benchmark now compiles the pinned upstream IAU SOFA / ERFA C implementation directly into a shared library/DLL and invokes the exported native `eraDtdb()` function via Python `ctypes`.
2. **Pinned Upstream Commit & Cryptographic Verification:** All required reference source and header files are pinned to commit `ec968fb295d3cf0572c4f024bf3c5357d9258b7b` of the canonical `liberfa/erfa` repository (SOFA release 2023-10-11) and cryptographically verified prior to compilation:
   - `tool/sofa_dtdb_cached.c` (LF SHA-256: `228bd7c7c1c88dda44c29a076f289c968f64d77a2dc389138b03ab5d1d442105`)
   - `tool/erfa.h` (LF SHA-256: `9549553b95ca2fbbcdcabcc69d82fb3cdd376c28b03c2793200138ff55727088`)
   - `tool/erfam.h` (LF SHA-256: `0da6313033aacf9c64533a7e74be49ecda97b4aaa87e134f98287e4ff279886f`)
3. **Documented ERFA Time-Scale Convention & Precision Preservation:** As explicitly documented in Note 1 of ERFA `dtdb.c`, while the date arguments are formally TDB, Terrestrial Time (TT) can be used with no practical effect on prediction accuracy. Each sample epoch is evaluated on a uniform TT timeline using a two-part Julian Date split ($date_1 = 2451545.0$, $date_2 = \text{days\_from\_J2000\_TT}$), completely avoiding cancellation errors.
4. **Native Reference Self-Tests:** Added five focused native execution self-tests covering symbol resolution, the official ERFA test vector (passed to $3.47 \times 10^{-18}$ absolute error against the $10^{-15}$ tolerance), geocentric zero-parameter behavior, explicit compiler failure without Python fallback, and cryptographic source tampering rejection.
5. **Measured Hourly Benchmark Results:** Evaluated the native C routine on true hourly grids:
   - **Range A (1950–2050, 885,360 hourly samples):** RMS $16.7850\ \mu\text{s}$, maximum observed absolute residual on the grid $37.7449\ \mu\text{s}$ (at 1960-10-12 01:00:00.0 TT).
   - **Range B (1900–2100, 1,761,936 hourly samples):** RMS $16.9828\ \mu\text{s}$, maximum observed absolute residual on the grid $40.0067\ \mu\text{s}$ (at 1901-10-05 19:00:00.0 TT).
6. **Hardened Epoch Tolerance Validation & Protected Phases:** Verified non-negative finite validation on `toleranceSeconds` in `AstronomicalTime.representsSameInstant()`. Phase 04 (`scientific_geometry`), Phase 05 (`terrain_horizon`), and production astronomical algorithms remain 100% untouched. All 269 repository tests pass with zero static analysis issues.

---

## 2. Baseline Status

- **Repository Branch:** `main`
- **Current HEAD Commit:** `69d558d60443e77266e78cc85b391c758d37250b`
- **Initial Working Tree:** Clean baseline before benchmark reference corrections.
- **Audited Production Files:**
  - `lib/features/solar_earth_visibility/domain/models/astronomical_time.dart` (Unmodified)
  - `lib/features/solar_earth_visibility/domain/models/time_scale.dart` (Unmodified)
  - `lib/features/solar_earth_visibility/domain/models/leap_second_provider.dart` (Unmodified)
  - `lib/features/solar_earth_visibility/domain/models/celestial_vector.dart` (Unmodified)
  - `lib/features/solar_earth_visibility/domain/services/local_topocentric_converter.dart` (Unmodified)
- **Audited Test Files:**
  - `test/features/solar_earth_visibility/domain/models/astronomical_time_test.dart` (Unmodified)
  - `test/features/solar_earth_visibility/domain/services/local_topocentric_converter_test.dart` (Unmodified)
- **Audited Benchmark Harness & References:**
  - `tool/benchmark_tdb.py` (Corrected to direct native C execution)
  - `tool/sofa_dtdb_cached.c` (Pinned C reference source)
  - `tool/erfa.h` (Pinned upstream header)
  - `tool/erfam.h` (Pinned upstream header)

---

## 3. Reference Execution Architecture & Root Cause Correction

### 3.1 Prior Defect Identified
The previous benchmark script parsed the static coefficient array `fairhd[787][3]` from the cached C source and evaluated the harmonic terms in Python/NumPy using vectorized array operations. While mathematically similar, this was not direct execution of the canonical IAU SOFA / ERFA C function. Checksumming the source file did not prove execution of the compiled native algorithm.

### 3.2 Corrected Architecture: Direct Native Invocation
The benchmark harness now invokes the actual compiled C function:
```c
double eraDtdb(double date1, double date2, double ut, double elong, double u, double v);
```
1. **Compilation Pipeline:** Discovers the local C compiler (MSVC `cl.exe`, `gcc`, or `clang`). On Windows, it integrates with Visual Studio Build Tools via `vcvars64.bat` to configure the 64-bit MSVC environment.
2. **Isolated Build:** Compiles `tool/sofa_dtdb_cached.c` with compiler optimization (`/O2` on MSVC, `-O3 -fPIC` on GCC/Clang) into a temporary shared library/DLL within an isolated directory (`tempfile.TemporaryDirectory()`).
3. **Direct Dynamic Binding:** Loads the resulting binary via `ctypes.CDLL` and explicitly declares argument types (`[ctypes.c_double] * 6`) and return type (`ctypes.c_double`).
4. **No Fallback Policy:** If no supported compiler is found or compilation fails, the script halts immediately with an actionable diagnostic. It never falls back to an alternate Python or NumPy implementation.
5. **Clean Resource Reclamation:** On Windows, `FreeLibrary` is invoked prior to exiting the context manager, ensuring all temporary DLLs and build artifacts are deleted cleanly without polluting the repository.

---

## 4. Time-Scale Methodology & Precision Preservation

### 4.1 Documented ERFA Time-Scale Convention
In Section 4 of the official routine documentation (`dtdb.c` Note 1):
> *"Although the date is, formally, barycentric dynamical time (TDB), the terrestrial dynamical time (TT) can be used with no practical effect on the accuracy of the prediction."*

Because the maximum difference between TDB and TT is $|\Delta t| \le 0.0017\text{ s}$ and the time derivative satisfies $|d(\Delta t)/dt| \le 1.2 \times 10^{-9}\text{ s/s}$, evaluating `eraDtdb` with TT instead of TDB shifts the returned value by at most:
$$0.0017\text{ s} \times 1.2 \times 10^{-9} \approx 2 \times 10^{-12}\text{ s} = 0.000002\ \mu\text{s}$$
This variation is negligible compared to microsecond-level residuals. Following this documented convention, the benchmark defines each sample epoch on an explicit, uniform TT timeline and calls `eraDtdb()` directly using the TT Julian Date.

### 4.2 Two-Part J2000 Julian Date Representation
To eliminate floating-point cancellation errors caused by large Julian Dates ($\approx 2.45 \times 10^6\text{ days}$), the benchmark adopts the official J2000 split recommendation:
- $date_1 = 2451545.0$ (Julian Date of J2000.0)
- $date_2 = \text{days\_from\_J2000\_TT}$

Inside `eraDtdb`, the internal time variable is computed as:
$$t = \frac{(date_1 - \text{ERFA\_DJ00}) + date_2}{\text{ERFA\_DJM}}$$
Because $date_1 = \text{ERFA\_DJ00}$, the difference $date_1 - \text{ERFA\_DJ00}$ is identically $0.0$, allowing $date_2$ to scale directly with zero precision loss.

LunaSight's production compact formula is similarly evaluated using the identical offset:
$$T_{\text{TT}} = \frac{\text{days\_from\_J2000\_TT}}{36525.0}$$
$$g = \left(357.53^\circ + 35999.05^\circ \, T_{\text{TT}}\right) \times \frac{\pi}{180^\circ}$$
$$\Delta t_{\text{proj}} = 0.001657 \sin\left(g + 0.0167 \sin g\right) \quad \text{seconds}$$

### 4.3 Geocentric Configuration
All benchmark evaluations use the geocentric configuration:
- Universal time: $ut = 0.0$
- Geocentric longitude: $elong = 0.0$
- Spin-axis distance: $u = 0.0\text{ km}$
- Equator distance: $v = 0.0\text{ km}$
This isolates the solar-system barycentric dynamical terms without topocentric diurnal clock effects.

---

## 5. Pinned Upstream Sources & Cryptographic Verification

| File | Upstream Source URL | Upstream Commit | Normalized LF SHA-256 |
| :--- | :--- | :---: | :---: |
| `tool/sofa_dtdb_cached.c` | `https://raw.githubusercontent.com/liberfa/erfa/ec968fb.../src/dtdb.c` | `ec968fb` | `228bd7c7c1c88dda44c29a076f289c968f64d77a2dc389138b03ab5d1d442105` |
| `tool/erfa.h` | `https://raw.githubusercontent.com/liberfa/erfa/ec968fb.../src/erfa.h` | `ec968fb` | `9549553b95ca2fbbcdcabcc69d82fb3cdd376c28b03c2793200138ff55727088` |
| `tool/erfam.h` | `https://raw.githubusercontent.com/liberfa/erfa/ec968fb.../src/erfam.h` | `ec968fb` | `0da6313033aacf9c64533a7e74be49ecda97b4aaa87e134f98287e4ff279886f` |

Each file retains its complete NumFOCUS / IAU SOFA 3-clause BSD copyright and permission notice.

---

## 6. Native Reference Self-Test Results

The benchmark harness executes five mandatory native self-tests prior to benchmarking:

1. **Symbol Resolution:** Confirmed that the loaded shared library exports `eraDtdb` and is callable via `ctypes`.
2. **Official ERFA Test Vector:**
   - Call: `eraDtdb(2448939.5, 0.123, 0.76543, 5.0123, 5525.242, 3190.0)`
   - Result: `-1.28036800593700245306e-03`
   - Expected: `-1.28036800593699898361e-03`
   - Measured Absolute Error: **$3.46945 \times 10^{-18}$** (Well below the official $10^{-15}$ tolerance).
3. **Geocentric Invocation Test:**
   - Call: `eraDtdb(2451545.0, 0.0, 0.0, 0.0, 0.0, 0.0)`
   - Result: $-99.3072\ \mu\text{s}$ (Verified finite and matches expected value).
4. **Deliberate Failure Handling:** Confirmed that an intentional compilation error in a temporary workspace raises `RuntimeError` and immediately halts execution without falling back to any secondary routine.
5. **Cryptographic Tamper Detection:** Confirmed that modified bytes in reference sources trigger a `ValueError` checksum mismatch and prevent compilation.

---

## 7. Newly Measured Native Benchmark Results

### 7.1 Exhaustive Hourly Sampling
Evaluated using the native compiled `eraDtdb()` C function on true 1-hour uniform grids:

| Metric | Range A: 1950–2050 | Range B: 1900–2100 |
| :--- | ---: | ---: |
| **Start Epoch (TT)** | 1950-01-01 00:00:00.0 TT | 1900-01-01 00:00:00.0 TT |
| **End Epoch (TT)** | 2050-12-31 23:00:00.0 TT | 2100-12-31 23:00:00.0 TT |
| **Sample Count** | **885,360 samples** | **1,761,936 samples** |
| **Sampling Interval** | **1 hour** ($3600\text{ s TT}$) | **1 hour** ($3600\text{ s TT}$) |
| **Execution Time** | 24.10 s (36,735 calls/s) | 48.38 s (36,421 calls/s) |
| **RMS Residual** | **$16.7850\ \mu\text{s}$** | **$16.9828\ \mu\text{s}$** |
| **Mean Signed Residual** | **$+1.5293\ \mu\text{s}$** | **$+1.5354\ \mu\text{s}$** |
| **Minimum Signed Residual** | **$-33.9951\ \mu\text{s}$** | **$-36.3465\ \mu\text{s}$** |
| **Maximum Signed Residual** | **$+37.7449\ \mu\text{s}$** | **$+40.0067\ \mu\text{s}$** |
| **Maximum Observed Absolute Residual** | **$37.7449\ \mu\text{s}$** | **$40.0067\ \mu\text{s}$** |
| **Peak Residual Epoch (TT)** | **1960-10-12 01:00:00.0 TT** | **1901-10-05 19:00:00.0 TT** |
| **Peak Julian Date (TT)** | JD 2437219.541667 TT | JD 2415663.291667 TT |

*Note: The maximum residual figures reflect the maximum values observed on the specified discrete hourly grid.*

### 7.2 Key Reference Epochs Verification

| Epoch (TT) | Julian Date (TT) | Native `eraDtdb()` | LunaSight Compact | Residual ($\text{LunaSight} - \text{ERFA}$) |
| :--- | ---: | ---: | ---: | ---: |
| **1900-01-01 00:00:00 TT** | 2415020.500000 | $-18.4602\ \mu\text{s}$ | $-30.2011\ \mu\text{s}$ | $-11.7409\ \mu\text{s}$ |
| **1901-10-05 19:00:00 TT** (Peak B) | 2415663.291667 | $-1696.3984\ \mu\text{s}$ | $-1656.3917\ \mu\text{s}$ | $\mathbf{+40.0067\ \mu\text{s}}$ |
| **1950-01-01 00:00:00 TT** | 2433282.500000 | $-70.6983\ \mu\text{s}$ | $-58.6467\ \mu\text{s}$ | $+12.0516\ \mu\text{s}$ |
| **1960-10-12 01:00:00 TT** (Peak A) | 2437219.541667 | $-1680.9155\ \mu\text{s}$ | $-1643.1706\ \mu\text{s}$ | $\mathbf{+37.7449\ \mu\text{s}}$ |
| **2000-01-01 12:00:00 TT** (J2000) | 2451545.000000 | $-99.3072\ \mu\text{s}$ | $-72.6020\ \mu\text{s}$ | $+26.7052\ \mu\text{s}$ |
| **2000-02-29 00:00:00 TT** | 2451603.500000 | $+1346.9487\ \mu\text{s}$ | $+1373.2818\ \mu\text{s}$ | $+26.3331\ \mu\text{s}$ |
| **2024-02-29 00:00:00 TT** | 2460369.500000 | $+1343.6085\ \mu\text{s}$ | $+1369.5457\ \mu\text{s}$ | $+25.9372\ \mu\text{s}$ |
| **2026-11-15 00:00:00 TT** | 2461359.500000 | $-1249.0550\ \mu\text{s}$ | $-1269.7349\ \mu\text{s}$ | $-20.6799\ \mu\text{s}$ |
| **2050-12-31 23:00:00 TT** | 2470172.458333 | $-84.5900\ \mu\text{s}$ | $-95.2704\ \mu\text{s}$ | $-10.6804\ \mu\text{s}$ |
| **2100-12-31 23:00:00 TT** | 2488434.458333 | $-99.4023\ \mu\text{s}$ | $-123.6632\ \mu\text{s}$ | $-24.2609\ \mu\text{s}$ |

---

## 8. Verification Matrix & Test Counts

| Step | Test Suite / Check | Command | Count / Scope | Status |
| :---: | :--- | :--- | :---: | :---: |
| 1 | **Native Self-Tests** | `python tool/benchmark_tdb.py --self-test` | 5 tests | **PASSED** |
| 2 | **Full Hourly Benchmark** | `python tool/benchmark_tdb.py` | 885,360 & 1,761,936 samples | **PASSED** |
| 3 | **Time & Vector Models** | `flutter test test/features/solar_earth_visibility/domain/models/astronomical_time_test.dart` | 18 tests | **PASSED** |
| 4 | **Topocentric Converter** | `flutter test test/features/solar_earth_visibility/domain/services/local_topocentric_converter_test.dart` | 9 tests | **PASSED** |
| 5 | **All Solar & Earth Visibility** | `flutter test test/features/solar_earth_visibility/` | 27 tests | **PASSED** |
| 6 | **Scientific Geometry (Phase 04)** | `flutter test test/features/scientific_geometry/` | 106 tests | **PASSED** |
| 7 | **Terrain Horizon (Phase 05)** | `flutter test test/features/terrain_horizon/` | 33 tests | **PASSED** |
| 8 | **Compile-Time Tests** | `flutter test test/compile_time/` | 2 tests | **PASSED** |
| 9 | **Full Repository Test Suite** | `flutter test` | **269 tests (23 suites)** | **PASSED** |
| 10 | **Static Analysis** | `flutter analyze` | Full project | **0 issues** |
| 11 | **Formatting** | `dart format --output=none --set-exit-if-changed lib/ test/` | 99 files | **Clean** |
| 12 | **Git Diff Check** | `git diff --check` | Working tree | **Clean** |

---

## 9. Protection of Prior Phases & Production Code

$$\mathbf{PHASE\; 04,\; PHASE\; 05,\; AND\; PRODUCTION\; CODE\; REMAIN\; 100\%\; UNTOUCHED.}$$

- Zero changes in `lib/features/scientific_geometry/` or `test/features/scientific_geometry/`.
- Zero changes in `lib/features/terrain_horizon/` or `test/features/terrain_horizon/`.
- Zero changes in production astronomical code (`astronomical_time.dart`, `time_scale.dart`, `celestial_vector.dart`, `local_topocentric_converter.dart`).
- All 106 Phase 04 tests and 33 Phase 05 tests pass without modification.

---

## 10. Final Verdict

$$\mathbf{PASS}$$

The TDB benchmark reference implementation has been successfully migrated to direct compiled native execution of the pinned IAU SOFA / ERFA `eraDtdb()` C routine. All numerical results, cryptographic hashes, and self-tests are fully verified and reproducible.

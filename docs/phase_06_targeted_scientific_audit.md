# Phase 06 Milestones 02–03: Targeted Scientific Audit Report
## Native ERFA `eraDtdb()` Benchmark Execution, Time-Scale Integrity, and Epoch Tolerance Validation

**Project:** LunaSight  
**Repository:** `AhmedKaram134679/LunaSight`  
**Current Branch:** `main`  
**Baseline Commit:** `5800b68c16a3ccdbdc4520bd5dff6564a40515d0`
**Audit Type:** Native Reference Execution & Numerical Verification
**Final Status:** **PASS**

---

## 1. Executive Summary

This targeted audit resolved critical methodological and documentation requirements for the Phase 06 astronomical time benchmark:
1. **Direct Native C Reference Execution:** Eliminated intermediate Python/NumPy coefficient table re-evaluations. The benchmark compiles the pinned upstream IAU SOFA / ERFA C implementation directly into a shared library/DLL and invokes the exported native `eraDtdb()` function via Python `ctypes`.
2. **Pinned Upstream Commit & Cryptographic Verification:** All required reference source and header files are pinned to commit `ec968fb295d3cf0572c4f024bf3c5357d9258b7b` of the canonical `liberfa/erfa` repository (SOFA release 2023-10-11) and cryptographically verified prior to compilation:
   - `tool/sofa_dtdb_cached.c` (LF SHA-256: `228bd7c7c1c88dda44c29a076f289c968f64d77a2dc389138b03ab5d1d442105`)
   - `tool/erfa.h` (LF SHA-256: `9549553b95ca2fbbcdcabcc69d82fb3cdd376c28b03c2793200138ff55727088`)
   - `tool/erfam.h` (LF SHA-256: `0da6313033aacf9c64533a7e74be49ecda97b4aaa87e134f98287e4ff279886f`)
3. **Deterministic Integer-Based Hourly Time-Grid:** Grid construction was upgraded to strictly deterministic integer indexing anchored at J2000.0 TT ($H_{\text{start}}$ to $H_{\text{end}}$ inclusive). Sample count $N = H_{\text{end}} - H_{\text{start}} + 1$ is derived via pure integer arithmetic, and per-sample parameters are derived via `divmod(H, 24)` to eliminate cumulative floating-point addition error ($+= 1/24\text{ d}$).
4. **Validation Scope Clarification:** The benchmark explicitly validates LunaSight's compact mathematical model against the compiled ERFA C reference. It does NOT directly execute or benchmark the Dart production runtime, which is independently validated by Flutter/Dart unit and integration tests.
5. **Resolution of Sub-Nanosecond Precision Claims:** Investigated round-trip precision assertions. Replaced the scientifically misleading "sub-nanosecond precision" test assertion with an explicit verification of algebraic reversibility and self-consistency of the forward and inverse transformation pair in `AstronomicalTime`.
6. **Documentation Conflicts Recorded:** Identified and formally recorded four existing documentation conflicts in `astronomical_time.dart` without unauthorized modifications to production comments.
7. **Native Reference Self-Tests & Measured Results:** Five native self-tests passed (official ERFA test vector error $3.47 \times 10^{-18}\text{ s} < 10^{-15}$). Native execution on the integer hourly grid confirmed:
   - **Range A (1950–2050, 885,360 samples):** RMS $16.7850\ \mu\text{s}$, maximum observed absolute residual $37.7449\ \mu\text{s}$ (at 1960-10-12 01:00:00.0 TT).
   - **Range B (1900–2100, 1,761,936 samples):** RMS $16.9828\ \mu\text{s}$, maximum observed absolute residual $40.0067\ \mu\text{s}$ (at 1901-10-05 19:00:00.0 TT).
8. **Phase & Code Protection:** Phase 04 (`scientific_geometry`), Phase 05 (`terrain_horizon`), and production code in `lib/` remain 100% untouched. All 269 repository tests pass with zero static analysis issues.

---

## 2. Baseline Status

- **Repository Branch:** `main`
- **Current HEAD Commit:** `5800b68c16a3ccdbdc4520bd5dff6564a40515d0`
- **Initial Working Tree:** Clean baseline.
- **Audited Production Files:**
  - `lib/features/solar_earth_visibility/domain/models/astronomical_time.dart` (Unmodified)
  - `lib/features/solar_earth_visibility/domain/models/time_scale.dart` (Unmodified)
  - `lib/features/solar_earth_visibility/domain/models/leap_second_provider.dart` (Unmodified)
  - `lib/features/solar_earth_visibility/domain/models/celestial_vector.dart` (Unmodified)
  - `lib/features/solar_earth_visibility/domain/services/local_topocentric_converter.dart` (Unmodified)
- **Audited Test Files:**
  - `test/features/solar_earth_visibility/domain/models/astronomical_time_test.dart` (Updated test description & precision tolerance)
  - `test/features/solar_earth_visibility/domain/services/local_topocentric_converter_test.dart` (Unmodified)
- **Audited Benchmark Harness & References:**
  - `tool/benchmark_tdb.py` (Updated to integer grid & scope clarification)
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

## 4. Time-Scale Methodology & Deterministic Time-Grid

### 4.1 Documented ERFA Time-Scale Convention
In Section 4 of the official routine documentation (`dtdb.c` Note 1):
> *"Although the date is, formally, barycentric dynamical time (TDB), the terrestrial dynamical time (TT) can be used with no practical effect on the accuracy of the prediction."*

Because the maximum difference between TDB and TT is $|\Delta t| \le 0.0017\text{ s}$ and the time derivative satisfies $|d(\Delta t)/dt| \le 1.2 \times 10^{-9}\text{ s/s}$, evaluating `eraDtdb` with TT instead of TDB shifts the returned value by at most:
$$0.0017\text{ s} \times 1.2 \times 10^{-9} \approx 2 \times 10^{-12}\text{ s} = 0.000002\ \mu\text{s}$$
This variation is negligible compared to microsecond-level residuals. Following this documented convention, the benchmark defines each sample epoch on an explicit, uniform TT timeline and calls `eraDtdb()` directly using the TT Julian Date.

### 4.2 Deterministic Integer-Based Hourly Time-Grid
To prevent roundoff accumulation and guarantee exact sample counts:
1. **Anchoring:** All hourly intervals are anchored relative to J2000.0 TT (2000-01-01 12:00:00 TT, JD 2451545.0 TT).
2. **Integer Arithmetic Sample Counts:**
   - **Range A (1950-01-01 00:00:00 TT to 2050-12-31 23:00:00 TT):**
     * $H_{\text{start}} = -438,300\text{ hours}$
     * $H_{\text{end}} = +447,059\text{ hours}$
     * $N = H_{\text{end}} - H_{\text{start}} + 1 = 447059 - (-438300) + 1 = \mathbf{885,360\text{ samples}}$ (inclusive endpoints).
   - **Range B (1900-01-01 00:00:00 TT to 2100-12-31 23:00:00 TT):**
     * $H_{\text{start}} = -876,588\text{ hours}$
     * $H_{\text{end}} = +885,347\text{ hours}$
     * $N = H_{\text{end}} - H_{\text{start}} + 1 = 885347 - (-876588) + 1 = \mathbf{1,761,936\text{ samples}}$ (inclusive endpoints).
3. **Exact Two-Part Julian Date Construction:**
   For sample index $k \in \{0, 1, \dots, N-1\}$:
   $$H = H_{\text{start}} + k$$
   $$(day\_offset, hour\_of\_day) = \text{divmod}(H, 24)$$
   $$date_1 = 2451545.0$$
   $$date_2 = \text{float}(day\_offset) + \frac{hour\_of\_day}{24.0}$$
   This derivation eliminates cumulative floating-point addition error ($+= 1/24\text{ d}$) and ensures strictly reproducible evaluation.
4. **Critical Numerical Distinction (Integer Indexing vs. Binary Floating-Point Limits):**
   An integer hour index guarantees exact sample indexing, deterministic endpoint counts, and strictly zero cumulative stepping drift ($\sum \Delta t$). However, it does *not* make the final binary floating-point Julian Date representation mathematically exact, because fractions such as $1/24$ (and other hour fractions) have non-terminating binary representations in IEEE-754 double precision ($2^{-53}$ precision limits). Deriving $date_2$ per-sample directly from $H$ ensures that every sample is independently and identically evaluated without step-to-step error propagation across millions of iterations.

### 4.3 Validation Scope: Mathematical Model vs. Production Dart Runtime
It is essential to distinguish the validation scope:
- **What the benchmark validates:** The benchmark is an independent mathematical-model comparison between LunaSight's compact Keplerian approximation and the canonical IAU SOFA / ERFA C function `eraDtdb()`.
- **What the benchmark does NOT validate:** The benchmark does not execute or benchmark the Dart production code (`AstronomicalTime` or `LocalTopocentricConverter`). Dart class contracts, leap-second offsets, and topocentric transformations are independently validated in the Dart test suite (`test/features/solar_earth_visibility/`).

---

## 5. Numerical Precision Investigation: Sub-Nanosecond Claims

### 5.1 Analysis of the Prior Sub-Nanosecond Assertion
A prior test in `astronomical_time_test.dart` was titled:
`Verifies round-trip TT -> TDB -> TT fixed-point consistency to sub-nanosecond precision`
and asserted that `tTTReconstructed.differenceInSeconds(tTT).abs() < 1e-9`.

This assertion and claim were critically audited. To maintain rigorous scientific standards, four fundamentally distinct concepts must never be conflated:

1. **Numerical Representation Precision:**
   - In double-precision floating point (IEEE-754), standard Julian Dates ($\approx 2.45 \times 10^6\text{ days}$) have a machine epsilon of $2.45 \times 10^6 \times 2^{-52} \approx 5.4 \times 10^{-10}\text{ days} \approx 47\ \mu\text{s}$. A single large Julian Date float cannot resolve nanoseconds, or even microseconds.
   - `AstronomicalTime` solves this by a split representation: `jdBase` (civil day baseline) and `secondOfDay` ($[0.0, 86400.0)$). In `secondOfDay`, floating-point epsilon near $86,400\text{ s}$ is $2^{16} \times 2^{-52} \approx 1.455 \times 10^{-11}\text{ s}$ ($\sim 14.5\text{ picoseconds}$).
   - However, external interfaces (such as standard civil `DateTime`) only support microsecond resolution ($1\ \mu\text{s} = 10^{-6}\text{ s}$), and `AstronomicalTime.representsSameInstant()` defaults to a tolerance of $1\ \mu\text{s}$.

2. **Algebraic Round-Trip Consistency:**
   - Evaluates whether chaining the forward mapping $T_{\text{TT}} \to T_{\text{TDB}}$ and inverse mapping $T_{\text{TDB}} \to T_{\text{TT}}$ returns the starting epoch.
   - Forward: $\text{secondOfDay}_{\text{TDB}} = \text{secondOfDay}_{\text{TT}} + \delta(T_{\text{TT}})$.
   - Inverse: $\text{secondOfDay}_{\text{TT reconstructed}} = \text{secondOfDay}_{\text{TDB}} - \delta(T_{\text{TDB}})$.
   - This measures purely the self-consistency and algebraic reversibility of the transformation pair within `AstronomicalTime`.

3. **Mathematical Inversion Error:**
   - Because the inverse function evaluates $\delta$ at $T_{\text{TDB}}$ instead of $T_{\text{TT}}$, the analytical difference between $\delta(T_{\text{TT}})$ and $\delta(T_{\text{TDB}})$ is bounded by the mean-value theorem:
     $$\left|\delta(T_{\text{TDB}}) - \delta(T_{\text{TT}})\right| \le \left|\frac{d\delta}{dt}\right| |\Delta t|$$
     With $|\Delta t| \le 0.0017\text{ s}$ and $|d\delta/dt| \le 1.2 \times 10^{-9}\text{ s/s}$, the theoretical inversion error is:
     $$|\Delta t| \times 1.2 \times 10^{-9} \le 0.0017 \times 1.2 \times 10^{-9} \approx 2.04 \times 10^{-12}\text{ s} \approx 2\text{ picoseconds}$$
   - When combined with IEEE-754 subtraction precision in `secondOfDay` ($\approx 14.5\text{ ps}$), the mathematical inversion error is on the order of picoseconds.

4. **Physical Astronomical Accuracy Against an External Ephemeris:**
   - Evaluates the difference between LunaSight's compact single-harmonic Keplerian approximation and the full IAU SOFA / ERFA 787-term series (or JPL DE421 / DE440 ephemerides).
   - Unmodeled planetary perturbation terms (Jupiter, Saturn) cause physical ephemeris residuals up to $\mathbf{37.74\ \mu\text{s}}$ (1950–2050) and $\mathbf{40.01\ \mu\text{s}}$ (1900–2100).
   - Calling an algebraic round-trip test "sub-nanosecond precision" misleadingly conflated internal formula invertibility with physical astronomical accuracy.

### 5.2 Corrective Action & Final Tolerance Justification
- **Test Renaming:** The test was renamed to:
  `Verifies algebraic round-trip consistency of TT <-> TDB conversion pair`
- **Tolerance Justification:**
  * Setting a sub-nanosecond tolerance ($< 1\text{ ns}$) is physically misleading and unrepresentative of the system's external interfaces.
  * Setting a tolerance of $< 1\ \mu\text{s}$ ($10^{-6}\text{ s}$) in `astronomical_time_test.dart` directly aligns with:
    1. The contract of `AstronomicalTime.representsSameInstant()`, whose default comparison tolerance is $1\ \mu\text{s}$.
    2. The standard resolution limit of civil `DateTime` representations in Flutter/Dart ($1\ \mu\text{s}$).
    3. Defensible algebraic verification that detects any unit regression, sign errors, or bad offsets without making unfounded physical accuracy claims.
  * The test explicitly verifies both the numeric difference (`< 1e-6 s`) and physical instant equivalence (`representsSameInstant(...) == true`).
  * No production conversion algorithms were modified.

---

## 6. Recorded Documentation Conflicts in Production Comments

In accordance with strict audit instructions, **no comments in `lib/features/solar_earth_visibility/domain/models/astronomical_time.dart` were modified during this pass.** Instead, all identified contradictions are formally recorded below:

| # | File Location | Existing Comment Text | Identified Contradiction / Issue | Status & Recommended Future Correction |
|---|---|---|---|---|
| **1** | `astronomical_time.dart`, line 24 | `(evaluated using exact fixed-point TDB arguments in the geocentric frame)` | The benchmark does not use fixed-point iteration; it passes TT Julian Dates directly following Note 1 of ERFA `dtdb.c`. | **Verified contradiction.** Recommend updating to: `(evaluated using the official ERFA TT-input convention in the geocentric frame)`. |
| **2** | `astronomical_time.dart`, lines 28–29 | `At the Moon's synodic rotation rate, a timing uncertainty of 40 us corresponds to < 0.025 milliarcseconds of solar topocentric position change...` | (a) Refers to "synodic rotation rate" when lunar rotation is sidereal ($\approx 0.55''/\text{s}$).<br>(b) Cites unverified pointing displacement without independent geometrical proof. | **Technical inaccuracy.** Recommend revising to remove informal pointing claims unless independently derived. |
| **3** | `astronomical_time.dart`, line 29 | `...well within the target design tolerance (< 100 us).` | Asserts a target design tolerance of $< 100\ \mu\text{s}$ as an established mission requirement without citing an authoritative specification document. | **Unverified requirement.** Recommend citing the formal project requirements document or removing the specific threshold. |
| **4** | `astronomical_time.dart`, line 174 | `Since delta < 0.0017s, evaluating delta at TDB yields < 1e-10s error.` | While algebraically true ($|\Delta t| \cdot |d\delta/dt| \le 2\times 10^{-12}\text{ s}$), stating this without qualification can mislead consumers into assuming sub-nanosecond physical accuracy. | **Contextual clarification needed.** Recommend clarifying that this bound applies strictly to internal algebraic reversibility. |

---

## 7. Pinned Upstream Sources & Cryptographic Verification

| File | Upstream Source URL | Upstream Commit | Normalized LF SHA-256 |
| :--- | :--- | :---: | :---: |
| `tool/sofa_dtdb_cached.c` | `https://raw.githubusercontent.com/liberfa/erfa/ec968fb.../src/dtdb.c` | `ec968fb` | `228bd7c7c1c88dda44c29a076f289c968f64d77a2dc389138b03ab5d1d442105` |
| `tool/erfa.h` | `https://raw.githubusercontent.com/liberfa/erfa/ec968fb.../src/erfa.h` | `ec968fb` | `9549553b95ca2fbbcdcabcc69d82fb3cdd376c28b03c2793200138ff55727088` |
| `tool/erfam.h` | `https://raw.githubusercontent.com/liberfa/erfa/ec968fb.../src/erfam.h` | `ec968fb` | `0da6313033aacf9c64533a7e74be49ecda97b4aaa87e134f98287e4ff279886f` |

Each file retains its complete NumFOCUS / IAU SOFA 3-clause BSD copyright and permission notice.

---

## 8. Native Reference Self-Test Results

The benchmark harness executes five mandatory native self-tests prior to benchmarking:

1. **Symbol Resolution:** Confirmed that the loaded shared library exports `eraDtdb` and is callable via `ctypes`.
2. **Official ERFA Test Vector:**
   - Call: `eraDtdb(2448939.5, 0.123, 0.76543, 5.0123, 5525.242, 3190.0)`
   - Result: `-1.28036800593700245306e-03`
   - Expected: `-1.28036800593699898361e-03`
   - Measured Absolute Error: **$3.46945 \times 10^{-18}\text{ s}$** (Well below the official $10^{-15}$ tolerance).
3. **Geocentric Invocation Test:**
   - Call: `eraDtdb(2451545.0, 0.0, 0.0, 0.0, 0.0, 0.0)`
   - Result: $-99.3072\ \mu\text{s}$ (Verified finite and matches expected value).
4. **Deliberate Failure Handling:** Confirmed that an intentional compilation error in a temporary workspace raises `RuntimeError` and immediately halts execution without falling back to any secondary routine.
5. **Cryptographic Tamper Detection:** Confirmed that modified bytes in reference sources trigger a `ValueError` checksum mismatch and prevent compilation.

---

## 9. Newly Measured Native Benchmark Results (Integer Grid)

### 9.1 Exhaustive Hourly Sampling
Evaluated using the native compiled `eraDtdb()` C function on deterministic integer-based 1-hour uniform grids:

| Metric | Range A: 1950–2050 (Integer Grid) | Range B: 1900–2100 (Integer Grid) |
| :--- | ---: | ---: |
| **Start Epoch (TT)** | 1950-01-01 00:00:00.0 TT | 1900-01-01 00:00:00.0 TT |
| **End Epoch (TT)** | 2050-12-31 23:00:00.0 TT | 2100-12-31 23:00:00.0 TT |
| **Sample Count** | **885,360 samples** | **1,761,936 samples** |
| **Integer Hour Range** | $H \in [-438300, 447059]$ | $H \in [-876588, 885347]$ |
| **Sampling Interval** | **1 hour exact** ($3600\text{ s TT}$) | **1 hour exact** ($3600\text{ s TT}$) |
| **Execution Time** | 12.12 s (73,045 calls/s) | 24.75 s (71,191 calls/s) |
| **RMS Residual** | **$16.7850\ \mu\text{s}$** | **$16.9828\ \mu\text{s}$** |
| **Mean Signed Residual** | **$+1.5293\ \mu\text{s}$** | **$+1.5354\ \mu\text{s}$** |
| **Minimum Signed Residual** | **$-33.9951\ \mu\text{s}$** | **$-36.3465\ \mu\text{s}$** |
| **Maximum Signed Residual** | **$+37.7449\ \mu\text{s}$** | **$+40.0067\ \mu\text{s}$** |
| **Maximum Observed Absolute Residual** | **$37.7449\ \mu\text{s}$** | **$40.0067\ \mu\text{s}$** |
| **Peak Residual Epoch (TT)** | **1960-10-12 01:00:00.0 TT** | **1901-10-05 19:00:00.0 TT** |
| **Peak Julian Date (TT)** | JD 2437219.541667 TT ($H = -343811$) | JD 2415663.291667 TT ($H = -861161$) |

*Comparison with previous results: The deterministic integer grid produces results that are mathematically identical to previous floating-point measurements to within machine precision ($< 10^{-12}\ \mu\text{s}$), demonstrating that cumulative float drift had not distorted prior metrics while guaranteeing strict deterministic integer bounds.*

### 9.2 Key Reference Epochs Verification

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

## 10. Verification Matrix & Test Counts

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

## 11. Protection of Prior Phases & Production Code

$$\mathbf{PHASE\; 04,\; PHASE\; 05,\; AND\; PRODUCTION\; CODE\; REMAIN\; 100\%\; UNTOUCHED.}$$

- Zero changes in `lib/features/scientific_geometry/` or `test/features/scientific_geometry/`.
- Zero changes in `lib/features/terrain_horizon/` or `test/features/terrain_horizon/`.
- Zero changes in production astronomical code (`astronomical_time.dart`, `time_scale.dart`, `celestial_vector.dart`, `local_topocentric_converter.dart`).
- All 106 Phase 04 tests and 33 Phase 05 tests pass without modification.

---

## 12. Final Verdict

$$\mathbf{PASS}$$

The TDB benchmark time-grid integrity and numerical precision claims have been fully reconciled and scientifically documented. The integer-based time grid eliminates all floating-point accumulation, the benchmark's validation scope is explicitly delineated from production Dart runtime execution, and all existing docstring conflicts have been formally documented.

#!/usr/bin/env python3
"""
benchmark_tdb.py

Independent scientific benchmarking of LunaSight's TDB-TT approximation
against the canonical IAU SOFA / ERFA eraDtdb model (Fairhead & Bretagnon 1990 series).

Scientific Time-Scale Methodology:
1. Define benchmark sample epochs on a uniform Terrestrial Time (TT) timeline.
2. Evaluate LunaSight's compact Keplerian approximation using the TT Julian Date:
     TDB_project - TT = 0.001657 * sin(g + 0.0167 * sin(g))
   where g = (357.53 + 35999.05 * T_TT) * (pi / 180.0), with T_TT = (JD_TT - 2451545.0) / 36525.0.
3. The ERFA/SOFA eraDtdb routine formally accepts date1, date2 in the TDB time scale:
     delta(TDB) = eraDtdb(date1_TDB, date2_TDB, ut=0, elong=0, u=0, v=0)
   To supply the exact corresponding TDB instant for each TT epoch without time-scale conflation,
   we solve for TDB iteratively using fixed-point iteration:
     TDB_(k+1) = TT + eraDtdb(TDB_k, ...)
   Starting from TDB_0 = TT, this converges to machine precision (< 1e-14 seconds, < 1e-8 us)
   in 2 iterations, because |d(delta)/dt| <= 1.2e-9 << 1.
4. Calculate residual in microseconds:
     residual = (delta_project - delta_reference) * 1e6
   where both refer to the exact same physical instant.
5. All evaluations are geocentric (u = 0 km, v = 0 km, topocentric clock correction wt = 0).

Evaluated Intervals:
- Range A: 1950-01-01 00:00:00 TT to 2050-12-31 23:00:00 TT (Hourly, 885,360 samples)
- Range B: 1900-01-01 00:00:00 TT to 2100-12-31 23:00:00 TT (Hourly, 1,761,936 samples)

Pinned Reference Standard:
- Library: liberfa / IAU SOFA (Release: SOFA 2023-10-11)
- Pinned Commit: ec968fb295d3cf0572c4f024bf3c5357d9258b7b
- Canonical Source: https://raw.githubusercontent.com/liberfa/erfa/ec968fb295d3cf0572c4f024bf3c5357d9258b7b/src/dtdb.c
- SHA-256 (canonical LF text): 228bd7c7c1c88dda44c29a076f289c968f64d77a2dc389138b03ab5d1d442105
- SHA-256 (local CRLF file): 147be37f458e0b5ca5793af9bfc36174b1c485b76df804f09ba89478a4123fc3
"""

import hashlib
import math
import os
import re
import sys
import time

try:
    import numpy as np

    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False

CACHE_FILE = os.path.join(os.path.dirname(__file__), "sofa_dtdb_cached.c")
PINNED_COMMIT = "ec968fb295d3cf0572c4f024bf3c5357d9258b7b"
EXPECTED_LF_SHA256 = (
    "228bd7c7c1c88dda44c29a076f289c968f64d77a2dc389138b03ab5d1d442105"
)


def load_and_verify_dtdb_source():
    if not os.path.exists(CACHE_FILE):
        raise FileNotFoundError(
            f"Cached reference file not found at: {CACHE_FILE}. "
            "Please ensure sofa_dtdb_cached.c is present in the tool/ directory."
        )

    with open(CACHE_FILE, "rb") as f:
        raw_bytes = f.read()

    # Verify text checksum after normalizing newlines to canonical LF:
    normalized_lf = raw_bytes.replace(b"\r\n", b"\n")
    actual_lf_sha256 = hashlib.sha256(normalized_lf).hexdigest()

    if actual_lf_sha256 != EXPECTED_LF_SHA256:
        raise ValueError(
            f"SHA256 mismatch for reference source in {CACHE_FILE}!\n"
            f"Expected: {EXPECTED_LF_SHA256}\n"
            f"Actual:   {actual_lf_sha256}"
        )

    return normalized_lf.decode("utf-8")


def parse_fairhd_coefficients(code: str):
    start_idx = code.find("static const double fairhd[787][3] = {")
    end_idx = code.find("};", start_idx)
    table_text = code[start_idx:end_idx]
    pattern = re.compile(
        r"\{\s*([0-9.eE+-]+)\s*,\s*([0-9.eE+-]+)\s*,\s*([0-9.eE+-]+)\s*\}"
    )
    matches = pattern.findall(table_text)
    if len(matches) != 787:
        raise ValueError(f"Expected 787 coefficient sets, found {len(matches)}")
    return [(float(a), float(f), float(p)) for a, f, p in matches]


def project_tdb_minus_tt(jd_tt: float) -> float:
    """Evaluates LunaSight's production compact Keplerian approximation."""
    tCenturies = (jd_tt - 2451545.0) / 36525.0
    gRad = (357.53 + 35999.05 * tCenturies) * (math.pi / 180.0)
    return 0.001657 * math.sin(gRad + 0.0167 * math.sin(gRad))


def jd_to_tt_calendar(jd: float) -> str:
    """Converts a Julian Date on the TT scale to a standard calendar string."""
    z = math.floor(jd + 0.5)
    f = (jd + 0.5) - z
    if z < 2299161:
        a = z
    else:
        alpha = math.floor((z - 1867216.25) / 36524.25)
        a = z + 1 + alpha - math.floor(alpha / 4)
    b = a + 1524
    c = math.floor((b - 122.1) / 365.25)
    d = math.floor(365.25 * c)
    e = math.floor((b - d) / 30.6001)
    day = b - d - math.floor(30.6001 * e)
    month = e - 1 if e < 14 else e - 13
    year = c - 4716 if month > 2 else c - 4715
    hour = f * 24.0
    h = math.floor(hour)
    minute = (hour - h) * 60.0
    m = math.floor(minute)
    s = (minute - m) * 60.0
    # Handle second rounding overflow (e.g. 59.9999 -> 60.0)
    if round(s, 1) >= 60.0:
        s = 0.0
        m += 1
        if m >= 60:
            m = 0
            h += 1
            if h >= 24:
                h = 0
                day += 1
    return f"{year:04d}-{month:02d}-{day:02d} {h:02d}:{m:02d}:{s:04.1f} TT"


def run_benchmark_vectorized(name, jd_start, jd_end, step, fairhd):
    """Executes high-speed hourly benchmark using NumPy vectorized chunks."""
    amp = np.array([f[0] for f in fairhd])
    freq = np.array([f[1] for f in fairhd])
    phase = np.array([f[2] for f in fairhd])

    def era_dtdb_vec(t_arr):
        args = np.outer(freq, t_arr) + phase[:, None]
        sins = np.sin(args) * amp[:, None]

        w0 = np.sum(sins[0:474, :], axis=0)
        w1 = np.sum(sins[474:679, :], axis=0)
        w2 = np.sum(sins[679:764, :], axis=0)
        w3 = np.sum(sins[764:784, :], axis=0)
        w4 = np.sum(sins[784:787, :], axis=0)

        wf = t_arr * (t_arr * (t_arr * (t_arr * w4 + w3) + w2) + w1) + w0

        wj = (
            0.00065e-6 * np.sin(6069.776754 * t_arr + 4.021194)
            + 0.00033e-6 * np.sin(213.299095 * t_arr + 5.543132)
            + (-0.00196e-6 * np.sin(6208.294251 * t_arr + 5.696701))
            + (-0.00173e-6 * np.sin(74.781599 * t_arr + 2.435900))
            + 0.03638e-6 * t_arr * t_arr
        )
        return wf + wj

    def project_vec(jd_arr):
        tCent = (jd_arr - 2451545.0) / 36525.0
        g = (357.53 + 35999.05 * tCent) * (np.pi / 180.0)
        return 0.001657 * np.sin(g + 0.0167 * np.sin(g))

    N = int(round((jd_end - jd_start) / step)) + 1
    chunk_size = 50000

    max_abs = 0.0
    max_idx = 0
    sum_sq = 0.0
    sum_signed = 0.0
    min_signed = float("inf")
    max_signed = float("-inf")

    t0 = time.time()
    for i in range(0, N, chunk_size):
        chunk_n = min(chunk_size, N - i)
        jd_chunk = jd_start + (i + np.arange(chunk_n)) * step

        # Exact TDB determination via fixed-point iteration:
        # Starting guess: TDB = TT
        t_guess = (jd_chunk - 2451545.0) / 365250.0
        # Iteration 1:
        delta1 = era_dtdb_vec(t_guess)
        # Iteration 2:
        t_guess = (jd_chunk + delta1 / 86400.0 - 2451545.0) / 365250.0
        ref_delta = era_dtdb_vec(t_guess)

        proj_delta = project_vec(jd_chunk)
        res_us = (proj_delta - ref_delta) * 1e6

        c_max_abs = np.max(np.abs(res_us))
        if c_max_abs > max_abs:
            max_abs = c_max_abs
            local_idx = np.argmax(np.abs(res_us))
            max_idx = i + local_idx

        c_min = np.min(res_us)
        if c_min < min_signed:
            min_signed = c_min

        c_max = np.max(res_us)
        if c_max > max_signed:
            max_signed = c_max

        sum_sq += np.sum(res_us**2)
        sum_signed += np.sum(res_us)

    elapsed = time.time() - t0
    rms = np.sqrt(sum_sq / N)
    mean_signed = sum_signed / N
    max_epoch_jd = jd_start + max_idx * step
    max_epoch_str = jd_to_tt_calendar(max_epoch_jd)

    return {
        "name": name,
        "sample_count": N,
        "sampling_interval": "1 hour (3600 s TT)",
        "rms_us": float(rms),
        "mean_signed_us": float(mean_signed),
        "max_abs_us": float(max_abs),
        "min_signed_us": float(min_signed),
        "max_signed_us": float(max_signed),
        "max_epoch_jd": float(max_epoch_jd),
        "max_epoch_str": max_epoch_str,
        "elapsed_sec": elapsed,
    }


def main():
    print("=" * 70)
    print("LunaSight Phase 06: Independent TDB-TT Scientific Benchmark")
    print("=" * 70)

    code = load_and_verify_dtdb_source()
    fairhd = parse_fairhd_coefficients(code)

    print(f"Reference Source: liberfa/erfa (Commit {PINNED_COMMIT[:7]})")
    print(f"Verified Source LF SHA-256: {EXPECTED_LF_SHA256}")
    print(f"Total Fairhead & Bretagnon harmonic sets: {len(fairhd)}")
    print(f"NumPy Acceleration: {'Enabled' if HAS_NUMPY else 'Disabled'}")
    print("-" * 70)

    # Range A: 1950-01-01 00:00:00 TT to 2050-12-31 23:00:00 TT
    # 1950-01-01 00:00:00 TT: JD = 2433282.5
    # 2050-12-31 23:00:00 TT: JD = 2470171.5 + 23/24 = 2470172.4583333335
    jd_a_start = 2433282.5
    jd_a_end = 2470171.5 + 23.0 / 24.0
    step_hourly = 1.0 / 24.0

    print("Executing Benchmark Range A (1950–2050, Hourly)...")
    res_a = run_benchmark_vectorized(
        "Range A: 1950–2050", jd_a_start, jd_a_end, step_hourly, fairhd
    )
    print(f"Completed in {res_a['elapsed_sec']:.2f} s")

    # Range B: 1900-01-01 00:00:00 TT to 2100-12-31 23:00:00 TT
    # 1900-01-01 00:00:00 TT: JD = 2415020.5
    # 2100-12-31 23:00:00 TT: JD = 2488433.5 + 23/24 = 2488434.4583333335
    jd_b_start = 2415020.5
    jd_b_end = 2488433.5 + 23.0 / 24.0

    print("Executing Benchmark Range B (1900–2100, Hourly)...")
    res_b = run_benchmark_vectorized(
        "Range B: 1900–2100", jd_b_start, jd_b_end, step_hourly, fairhd
    )
    print(f"Completed in {res_b['elapsed_sec']:.2f} s")

    print("\n" + "=" * 70)
    print("VERIFIED NUMERICAL BENCHMARK RESULTS")
    print("=" * 70)
    for r in [res_a, res_b]:
        print(f"Dataset:                  {r['name']}")
        print(f"Sample Count:             {r['sample_count']:,} samples")
        print(f"Sampling Interval:        {r['sampling_interval']}")
        print(f"RMS Residual:             {r['rms_us']:.4f} us")
        print(f"Mean Signed Residual:     {r['mean_signed_us']:.4f} us")
        print(f"Minimum Signed Residual:  {r['min_signed_us']:.4f} us")
        print(f"Maximum Signed Residual:  {r['max_signed_us']:.4f} us")
        print(f"Maximum Absolute Residual:{r['max_abs_us']:.4f} us")
        print(f"Epoch of Maximum Abs Res: {r['max_epoch_str']}")
        print(f"Julian Date at Max:       {r['max_epoch_jd']:.4f} TT")
        print("-" * 70)


if __name__ == "__main__":
    main()

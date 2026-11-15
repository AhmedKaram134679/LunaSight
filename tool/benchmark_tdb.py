#!/usr/bin/env python3
"""
benchmark_tdb.py

Independent scientific benchmarking of LunaSight's TDB-TT approximation
against the canonical IAU SOFA / ERFA eraDtdb model (Fairhead & Bretagnon 1990 series).

Date Ranges Evaluated:
- Range A: 1950-01-01 through 2050-12-31 (Daily, 36,890 samples)
- Range B: 1900-01-01 through 2100-12-31 (Daily, 73,414 samples)

Reference:
- Library: liberfa / IAU SOFA (2023-10-11 release)
- Source: https://raw.githubusercontent.com/liberfa/erfa/master/src/dtdb.c
- Function: eraDtdb (geocentric: u=0, v=0, wt=0)
"""

import math
import os
import re
import urllib.request
from datetime import datetime, timedelta

SOFA_DTDB_URL = "https://raw.githubusercontent.com/liberfa/erfa/master/src/dtdb.c"
CACHE_FILE = os.path.join(os.path.dirname(__file__), "sofa_dtdb_cached.c")


def fetch_or_load_dtdb():
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, "r", encoding="utf-8") as f:
            return f.read()
    print(f"Fetching reference dtdb.c from {SOFA_DTDB_URL}...")
    with urllib.request.urlopen(SOFA_DTDB_URL, timeout=15) as resp:
        content = resp.read().decode("utf-8")
    with open(CACHE_FILE, "w", encoding="utf-8") as f:
        f.write(content)
    return content


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


def era_dtdb_geocentric(date1: float, date2: float, fairhd):
    """
    Computes geocentric TDB - TT in seconds using the full 787-term
    Fairhead & Bretagnon 1990 model as implemented in IAU SOFA / ERFA eraDtdb.
    """
    # Time since J2000.0 in Julian millennia
    t = ((date1 - 2451545.0) + date2) / 365250.0

    w0 = sum(
        fairhd[j][0] * math.sin(fairhd[j][1] * t + fairhd[j][2])
        for j in range(473, -1, -1)
    )
    w1 = sum(
        fairhd[j][0] * math.sin(fairhd[j][1] * t + fairhd[j][2])
        for j in range(678, 473, -1)
    )
    w2 = sum(
        fairhd[j][0] * math.sin(fairhd[j][1] * t + fairhd[j][2])
        for j in range(763, 678, -1)
    )
    w3 = sum(
        fairhd[j][0] * math.sin(fairhd[j][1] * t + fairhd[j][2])
        for j in range(783, 763, -1)
    )
    w4 = sum(
        fairhd[j][0] * math.sin(fairhd[j][1] * t + fairhd[j][2])
        for j in range(786, 783, -1)
    )

    wf = t * (t * (t * (t * w4 + w3) + w2) + w1) + w0
    wj = (
        0.00065e-6 * math.sin(6069.776754 * t + 4.021194)
        + 0.00033e-6 * math.sin(213.299095 * t + 5.543132)
        + (-0.00196e-6 * math.sin(6208.294251 * t + 5.696701))
        + (-0.00173e-6 * math.sin(74.781599 * t + 2.435900))
        + 0.03638e-6 * t * t
    )
    return wf + wj


def project_tdb_minus_tt(jd_tt: float) -> float:
    """
    Evaluates LunaSight's implemented compact Keplerian TDB - TT approximation.
    """
    tCenturies = (jd_tt - 2451545.0) / 36525.0
    gRad = (357.53 + 35999.05 * tCenturies) * (math.pi / 180.0)
    return 0.001657 * math.sin(gRad + 0.0167 * math.sin(gRad))


def to_jd(dt: datetime) -> float:
    y = dt.year
    m = dt.month
    d = (
        dt.day
        + (dt.hour + (dt.minute + (dt.second + dt.microsecond * 1e-6) / 60.0) / 60.0)
        / 24.0
    )
    if m <= 2:
        y -= 1
        m += 12
    A = math.floor(y / 100)
    B = 2 - A + math.floor(A / 4)
    return (
        math.floor(365.25 * (y + 4716))
        + math.floor(30.6001 * (m + 1))
        + d
        + B
        - 1524.5
    )


def run_benchmark_range(start_dt, end_dt, step_days, name, fairhd):
    curr = start_dt
    residuals = []
    max_abs = 0.0
    max_dt = None
    min_signed = float("inf")
    max_signed = float("-inf")

    while curr <= end_dt:
        jd = to_jd(curr)
        ref = era_dtdb_geocentric(jd, 0.0, fairhd)
        proj = project_tdb_minus_tt(jd)
        res_us = (proj - ref) * 1e6
        residuals.append(res_us)
        if abs(res_us) > max_abs:
            max_abs = abs(res_us)
            max_dt = curr
        if res_us < min_signed:
            min_signed = res_us
        if res_us > max_signed:
            max_signed = res_us
        curr += timedelta(days=step_days)

    rms = math.sqrt(sum(r * r for r in residuals) / len(residuals))
    return {
        "name": name,
        "sample_count": len(residuals),
        "sampling_interval_days": step_days,
        "rms_us": rms,
        "max_abs_us": max_abs,
        "max_abs_dt": max_dt,
        "min_signed_us": min_signed,
        "max_signed_us": max_signed,
    }


def main():
    code = fetch_or_load_dtdb()
    fairhd = parse_fairhd_coefficients(code)

    print("Running Benchmark Range A (1950-01-01 to 2050-12-31, Daily)...")
    res_a = run_benchmark_range(
        datetime(1950, 1, 1), datetime(2050, 12, 31), 1, "1950-2050", fairhd
    )

    print("Running Benchmark Range B (1900-01-01 to 2100-12-31, Daily)...")
    res_b = run_benchmark_range(
        datetime(1900, 1, 1), datetime(2100, 12, 31), 1, "1900-2100", fairhd
    )

    print("\n" + "=" * 60)
    print("INDEPENDENT TDB BENCHMARK RESULTS")
    print("=" * 60)
    for r in [res_a, res_b]:
        print(f"Range: {r['name']}")
        print(f"  Sample count:             {r['sample_count']}")
        print(f"  Sampling interval:        {r['sampling_interval_days']} days")
        print(f"  RMS residual (us):        {r['rms_us']:.4f}")
        print(f"  Maximum abs residual(us): {r['max_abs_us']:.4f}")
        print(f"  Date of max residual:     {r['max_abs_dt']}")
        print(f"  Min signed residual (us): {r['min_signed_us']:.4f}")
        print(f"  Max signed residual (us): {r['max_signed_us']:.4f}")
        print("-" * 60)


if __name__ == "__main__":
    main()

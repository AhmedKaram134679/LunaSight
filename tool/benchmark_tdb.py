#!/usr/bin/env python3
"""
benchmark_tdb.py

Independent scientific benchmarking of LunaSight's production TDB-TT approximation
against direct execution of the actual compiled IAU SOFA / ERFA eraDtdb() C function
(Fairhead & Bretagnon 1990 series).

Reference Execution Architecture:
1. Pinned Reference C Source & Headers:
   - Upstream repository: liberfa/erfa
   - Pinned Commit: ec968fb295d3cf0572c4f024bf3c5357d9258b7b (Release: SOFA 2023-10-11)
   - Source files in tool/:
       * sofa_dtdb_cached.c (LF SHA-256: 228bd7c7c1c88dda44c29a076f289c968f64d77a2dc389138b03ab5d1d442105)
       * erfa.h             (LF SHA-256: 9549553b95ca2fbbcdcabcc69d82fb3cdd376c28b03c2793200138ff55727088)
       * erfam.h            (LF SHA-256: 0da6313033aacf9c64533a7e74be49ecda97b4aaa87e134f98287e4ff279886f)
2. Native Compilation & Invocation:
   - Automatically discovers MSVC (cl.exe), GCC, or Clang.
   - Compiles the actual C source into a temporary shared library/DLL in an isolated directory.
   - Loads the shared library via Python ctypes.CDLL.
   - Directly calls the exported native eraDtdb symbol with explicit c_double argument and return types.
   - Does NOT parse, copy, vectorize, or reimplement the harmonic algorithms in Python.
   - Deliberately refuses to fall back to any Python reimplementation if compilation fails.
   - Cleans up all temporary binaries, object files, and export libraries upon exit.

Scientific Time-Scale Methodology:
1. Official ERFA Convention:
   The official ERFA dtdb.c documentation states (Note 1):
     "Although the date is, formally, barycentric dynamical time (TDB),
      the terrestrial dynamical time (TT) can be used with no practical
      effect on the accuracy of the prediction."
   This benchmark evaluates every sample on an explicit, uniform TT timeline and passes
   the TT epoch directly to eraDtdb() as documented.
2. Two-Part Precision-Preserving Julian Date:
   Each epoch is represented using the J2000 split:
     * date1 = 2451545.0 (J2000.0)
     * date2 = days_from_J2000_TT
   Avoiding subtraction cancellation and preserving full sub-nanosecond precision.
3. LunaSight Compact Formula:
   Evaluated with the identical days_from_J2000_TT offset:
     * T_TT = days_from_J2000_TT / 36525.0
     * g = (357.53 + 35999.05 * T_TT) * (pi / 180.0)
     * delta_proj = 0.001657 * sin(g + 0.0167 * sin(g))
4. Residual Convention:
     residual = (delta_project - delta_reference) * 1e6  [microseconds]
5. Geocentric Configuration:
     ut = 0.0, elong = 0.0, u = 0.0, v = 0.0

Dependencies:
- Python 3.8+ standard library only (ctypes, math, time, os, sys, shutil, subprocess, hashlib, tempfile).
- A C compiler on PATH or installed via Visual Studio Build Tools / MinGW-w64.
"""

import os
import sys
import math
import time
import shutil
import ctypes
if sys.platform == "win32":
    import ctypes.wintypes
import hashlib
import tempfile
import subprocess
from contextlib import contextmanager

TOOL_DIR = os.path.dirname(os.path.abspath(__file__))
PINNED_COMMIT = "ec968fb295d3cf0572c4f024bf3c5357d9258b7b"

EXPECTED_HASHES = {
    "sofa_dtdb_cached.c": "228bd7c7c1c88dda44c29a076f289c968f64d77a2dc389138b03ab5d1d442105",
    "erfa.h": "9549553b95ca2fbbcdcabcc69d82fb3cdd376c28b03c2793200138ff55727088",
    "erfam.h": "0da6313033aacf9c64533a7e74be49ecda97b4aaa87e134f98287e4ff279886f",
}


class NativeErfaBuilder:
    """Manages integrity verification, discovery, compilation, and ctypes loading of native ERFA C code."""

    def __init__(self, tool_dir: str = TOOL_DIR):
        self.tool_dir = tool_dir

    def verify_checksums(self, override_dir: str = None):
        """Verifies cryptographic SHA-256 hashes for all required C reference files."""
        target_dir = override_dir or self.tool_dir
        for filename, expected_hash in EXPECTED_HASHES.items():
            path = os.path.join(target_dir, filename)
            if not os.path.exists(path):
                raise FileNotFoundError(f"Missing required reference file: {path}")
            with open(path, "rb") as f:
                content = f.read()
            normalized = content.replace(b"\r\n", b"\n")
            actual_hash = hashlib.sha256(normalized).hexdigest()
            if actual_hash != expected_hash:
                raise ValueError(
                    f"Integrity check failed for {filename}!\n"
                    f"Expected SHA-256: {expected_hash}\n"
                    f"Actual SHA-256:   {actual_hash}"
                )

    def _discover_msvc_env(self):
        """Discovers MSVC vcvars environment on Windows."""
        candidates = []
        vswhere_exe = r"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
        if os.path.exists(vswhere_exe):
            cmd = [
                vswhere_exe,
                "-latest",
                "-products", "*",
                "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
                "-property", "installationPath"
            ]
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0 and res.stdout.strip():
                vs_dir = res.stdout.strip()
                candidates.append(os.path.join(vs_dir, "VC", "Auxiliary", "Build", "vcvars64.bat"))
                candidates.append(os.path.join(vs_dir, "VC", "Auxiliary", "Build", "vcvarsall.bat"))

        common_roots = [
            r"C:\Program Files\Microsoft Visual Studio\18\Community",
            r"C:\Program Files\Microsoft Visual Studio\2022\Community",
            r"C:\Program Files\Microsoft Visual Studio\2022\Professional",
            r"C:\Program Files\Microsoft Visual Studio\2022\Enterprise",
            r"C:\Program Files\Microsoft Visual Studio\2022\BuildTools",
            r"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community",
            r"C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional",
            r"C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise",
            r"C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools",
        ]
        for r in common_roots:
            candidates.append(os.path.join(r, "VC", "Auxiliary", "Build", "vcvars64.bat"))
            candidates.append(os.path.join(r, "VC", "Auxiliary", "Build", "vcvarsall.bat"))

        for bat in candidates:
            if os.path.exists(bat):
                bat_arg = f'"{bat}"' if "vcvars64" in bat else f'"{bat}" x64'
                cmd = f"{bat_arg} >nul && set"
                res = subprocess.run(cmd, capture_output=True, text=True, shell=True)
                if res.returncode == 0:
                    env = {}
                    for line in res.stdout.splitlines():
                        if "=" in line:
                            k, v = line.split("=", 1)
                            env[k] = v
                    cl = shutil.which("cl.exe", path=env.get("PATH"))
                    if cl:
                        return cl, env
        return None, None

    def discover_compiler(self):
        """Finds a supported native C compiler (MSVC, GCC, or Clang)."""
        gcc = shutil.which("gcc")
        if gcc:
            return "gcc", gcc, os.environ.copy()
        clang = shutil.which("clang")
        if clang:
            return "clang", clang, os.environ.copy()
        cl = shutil.which("cl.exe")
        if cl:
            return "msvc", cl, os.environ.copy()
        if sys.platform == "win32":
            cl, env = self._discover_msvc_env()
            if cl and env:
                return "msvc", cl, env

        raise RuntimeError(
            "No suitable C compiler (MSVC cl.exe, gcc, or clang) found on this system.\n"
            "To build the native reference library, install Visual Studio C++ Build Tools or MinGW-w64,\n"
            "or run from a Developer Command Prompt for Visual Studio.\n"
            "Silent fallback to Python reimplementation is strictly prohibited."
        )

    @contextmanager
    def compiled_library(self):
        """Compiles sofa_dtdb_cached.c into a temporary shared library and yields the eraDtdb callable."""
        self.verify_checksums()
        compiler_type, compiler_bin, env = self.discover_compiler()
        c_src = os.path.join(self.tool_dir, "sofa_dtdb_cached.c")

        with tempfile.TemporaryDirectory() as tmp_dir:
            if compiler_type == "msvc":
                dll_path = os.path.join(tmp_dir, "sofa_dtdb.dll")
                cmd = [
                    compiler_bin,
                    "/O2",
                    "/LD",
                    "/nologo",
                    f"/I{self.tool_dir}",
                    c_src,
                    f"/Fe:{dll_path}",
                    "/link",
                    "/EXPORT:eraDtdb",
                ]
            else:
                ext = ".dll" if sys.platform == "win32" else ".so"
                dll_path = os.path.join(tmp_dir, f"libsofa_dtdb{ext}")
                cmd = [
                    compiler_bin,
                    "-O3",
                    "-shared",
                    "-fPIC",
                    f"-I{self.tool_dir}",
                    c_src,
                    "-o",
                    dll_path,
                ]

            res = subprocess.run(cmd, capture_output=True, text=True, env=env, cwd=tmp_dir)
            if res.returncode != 0:
                raise RuntimeError(
                    f"Compilation of ERFA C reference failed (exit code {res.returncode}):\n"
                    f"STDOUT: {res.stdout}\n"
                    f"STDERR: {res.stderr}\n"
                    "Silent fallback to Python reimplementation is strictly prohibited."
                )

            if not os.path.exists(dll_path):
                raise FileNotFoundError(f"Shared library output was not created at: {dll_path}")

            lib = ctypes.CDLL(dll_path)
            if not hasattr(lib, "eraDtdb"):
                raise AttributeError("Compiled library does not export required symbol 'eraDtdb'")

            eraDtdb = lib.eraDtdb
            eraDtdb.argtypes = [
                ctypes.c_double,  # date1
                ctypes.c_double,  # date2
                ctypes.c_double,  # ut
                ctypes.c_double,  # elong
                ctypes.c_double,  # u
                ctypes.c_double,  # v
            ]
            eraDtdb.restype = ctypes.c_double

            try:
                yield eraDtdb
            finally:
                if sys.platform == "win32":
                    ctypes.windll.kernel32.FreeLibrary.argtypes = [ctypes.wintypes.HMODULE]
                    ctypes.windll.kernel32.FreeLibrary(lib._handle)
                del lib


def run_self_tests(builder: NativeErfaBuilder) -> bool:
    """Executes focused validation suite proving native reference execution."""
    print("=" * 70)
    print("LunaSight Phase 06: Native Reference Self-Tests")
    print("=" * 70)

    # 1. Symbol Export & Execution
    print("[1/5] Verifying library compilation and symbol export...")
    with builder.compiled_library() as eraDtdb:
        assert callable(eraDtdb), "eraDtdb is not callable"
        print("      PASS: eraDtdb compiled, loaded, and exported successfully.")

        # 2. Official ERFA Test Vector
        print("[2/5] Running official ERFA test vector...")
        test_val = eraDtdb(2448939.5, 0.123, 0.76543, 5.0123, 5525.242, 3190.0)
        expected = -0.1280368005936998991e-2
        err = abs(test_val - expected)
        assert err < 1e-15, f"Test vector error {err} exceeds official tolerance 1e-15"
        print(f"      PASS: Output = {test_val:.20e}")
        print(f"            Error  = {err:.5e} (tolerance < 1e-15)")

        # 3. Geocentric Invocation Test
        print("[3/5] Running geocentric zero-topocentric parameter test...")
        geo_val = eraDtdb(2451545.0, 0.0, 0.0, 0.0, 0.0, 0.0)
        assert -0.002 < geo_val < 0.002, f"Geocentric result {geo_val} exceeds 2 ms bound"
        assert abs(geo_val * 1e6 - (-99.3072)) < 0.01, f"Unexpected J2000 value: {geo_val*1e6} us"
        print(f"      PASS: Geocentric value at J2000 = {geo_val*1e6:.4f} us (expected -99.3072 us)")

    # 4. Explicit Failure on Deliberate Compiler Error
    print("[4/5] Verifying explicit failure on compilation errors (no fallback)...")
    with tempfile.TemporaryDirectory() as tmp_dir:
        for fn in ["erfa.h", "erfam.h"]:
            shutil.copy(os.path.join(builder.tool_dir, fn), os.path.join(tmp_dir, fn))
        with open(os.path.join(tmp_dir, "sofa_dtdb_cached.c"), "w") as f:
            f.write("#include \"erfa.h\"\nINVALID_SYNTAX_ERROR;\n")
        bad_builder = NativeErfaBuilder(tool_dir=tmp_dir)
        bad_builder.verify_checksums = lambda override_dir=None: True
        failed_cleanly = False
        try:
            with bad_builder.compiled_library():
                pass
        except RuntimeError:
            failed_cleanly = True
        assert failed_cleanly, "Did not raise RuntimeError on compilation failure!"
        print("      PASS: Raised RuntimeError as required; refused to fall back.")

    # 5. Checksum Validation Rejection
    print("[5/5] Verifying cryptographic rejection of modified cached source...")
    with tempfile.TemporaryDirectory() as tmp_dir:
        for fn in ["erfa.h", "erfam.h"]:
            shutil.copy(os.path.join(builder.tool_dir, fn), os.path.join(tmp_dir, fn))
        with open(os.path.join(tmp_dir, "sofa_dtdb_cached.c"), "wb") as f:
            f.write(b"/* tampered source code */\n")
        tampered_builder = NativeErfaBuilder(tool_dir=tmp_dir)
        checksum_rejected = False
        try:
            tampered_builder.verify_checksums()
        except ValueError:
            checksum_rejected = True
        assert checksum_rejected, "Tampered source was not rejected!"
        print("      PASS: Checksum mismatch rejected prior to compilation.")

    print("\nALL 5 NATIVE REFERENCE SELF-TESTS PASSED!")
    print("=" * 70)
    return True


def jd_to_tt_calendar(days_from_j2000: float) -> str:
    """Converts a J2000-offset Julian Date on the TT scale to a standard calendar string."""
    jd = 2451545.0 + days_from_j2000
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


def run_benchmark_range(name: str, eraDtdb, start_jd: float, end_jd: float, step_days: float):
    """Executes full hourly sampling of production compact formula against native compiled eraDtdb()."""
    date1 = 2451545.0  # J2000.0 split
    d_start = start_jd - date1
    d_end = end_jd - date1
    N = int(round((d_end - d_start) / step_days)) + 1

    print(f"\nExecuting Benchmark: {name}")
    print(f"  Sample Count:      {N:,} samples")
    print(f"  Step Size:         {step_days * 86400.0:.0f} s (1 hour)")
    print(f"  Start Epoch (TT):  {jd_to_tt_calendar(d_start)} (JD {start_jd:.4f} TT)")
    print(f"  End Epoch (TT):    {jd_to_tt_calendar(d_end)} (JD {end_jd:.4f} TT)")

    pi_over_180 = math.pi / 180.0
    max_abs = 0.0
    max_idx = 0
    sum_sq = 0.0
    sum_signed = 0.0
    min_signed = float("inf")
    max_signed = float("-inf")

    t0 = time.time()
    for i in range(N):
        d2 = d_start + i * step_days

        # Call the actual native C function:
        ref = eraDtdb(date1, d2, 0.0, 0.0, 0.0, 0.0)

        # LunaSight production compact formula (evaluated from J2000 offset):
        t_centuries = d2 / 36525.0
        g = (357.53 + 35999.05 * t_centuries) * pi_over_180
        proj = 0.001657 * math.sin(g + 0.0167 * math.sin(g))

        res_us = (proj - ref) * 1e6

        sum_signed += res_us
        sum_sq += res_us * res_us
        if res_us < min_signed:
            min_signed = res_us
        if res_us > max_signed:
            max_signed = res_us
        abs_res = abs(res_us)
        if abs_res > max_abs:
            max_abs = abs_res
            max_idx = i

    dt = time.time() - t0
    mean_signed = sum_signed / N
    rms = math.sqrt(sum_sq / N)
    peak_d2 = d_start + max_idx * step_days
    peak_jd = date1 + peak_d2
    peak_cal = jd_to_tt_calendar(peak_d2)

    print(f"  Completed in:      {dt:.2f} s ({N/dt:.0f} samples/s)")
    print(f"  RMS Residual:      {rms:.4f} us")
    print(f"  Mean Signed:       {mean_signed:.4f} us")
    print(f"  Min Signed:        {min_signed:.4f} us")
    print(f"  Max Signed:        {max_signed:.4f} us")
    print(f"  Max Absolute:      {max_abs:.4f} us")
    print(f"  Peak Epoch:        {peak_cal} (JD {peak_jd:.4f} TT)")

    return {
        "name": name,
        "sample_count": N,
        "elapsed_sec": dt,
        "rms_us": rms,
        "mean_signed_us": mean_signed,
        "min_signed_us": min_signed,
        "max_signed_us": max_signed,
        "max_abs_us": max_abs,
        "peak_epoch": peak_cal,
        "peak_jd": peak_jd,
    }


def evaluate_reference_epochs(eraDtdb):
    """Evaluates canonical key epochs directly against the compiled native reference function."""
    date1 = 2451545.0
    key_epochs = [
        ("1900-01-01 00:00:00 TT", 2415020.500000),
        ("1901-10-05 19:00:00 TT (Peak B)", 2415663.291667),
        ("1950-01-01 00:00:00 TT", 2433282.500000),
        ("1960-10-12 01:00:00 TT (Peak A)", 2437219.541667),
        ("2000-01-01 12:00:00 TT (J2000)", 2451545.000000),
        ("2000-02-29 00:00:00 TT", 2451603.500000),
        ("2024-02-29 00:00:00 TT", 2460369.500000),
        ("2026-11-15 00:00:00 TT", 2461359.500000),
        ("2050-12-31 23:00:00 TT", 2470172.458333),
        ("2100-12-31 23:00:00 TT", 2488434.458333),
    ]

    print("\n" + "=" * 80)
    print("KEY REFERENCE EPOCHS EVALUATION (NATIVE eraDtdb)")
    print("=" * 80)
    print(f"{'Epoch (TT)':<35} {'JD (TT)':<16} {'IAU eraDtdb':<16} {'LunaSight':<16} {'Residual'}")
    print("-" * 80)

    pi_over_180 = math.pi / 180.0
    for label, jd in key_epochs:
        d2 = jd - date1
        ref = eraDtdb(date1, d2, 0.0, 0.0, 0.0, 0.0)
        t_centuries = d2 / 36525.0
        g = (357.53 + 35999.05 * t_centuries) * pi_over_180
        proj = 0.001657 * math.sin(g + 0.0167 * math.sin(g))
        res_us = (proj - ref) * 1e6
        print(f"{label:<35} {jd:<16.6f} {ref*1e6:>13.4f} us {proj*1e6:>13.4f} us {res_us:>+10.4f} us")
    print("=" * 80)


def main():
    builder = NativeErfaBuilder()

    if "--self-test" in sys.argv:
        run_self_tests(builder)
        return 0

    run_self_tests(builder)

    with builder.compiled_library() as eraDtdb:
        evaluate_reference_epochs(eraDtdb)

        # Range A: 1950-01-01 00:00:00 TT to 2050-12-31 23:00:00 TT
        # 1950-01-01 00:00:00 TT = JD 2433282.5
        # 2050-12-31 23:00:00 TT = JD 2470172.4583333335
        run_benchmark_range(
            "Range A: 1950–2050 (Hourly)",
            eraDtdb,
            start_jd=2433282.5,
            end_jd=2470172.4583333335,
            step_days=1.0 / 24.0,
        )

        # Range B: 1900-01-01 00:00:00 TT to 2100-12-31 23:00:00 TT
        # 1900-01-01 00:00:00 TT = JD 2415020.5
        # 2100-12-31 23:00:00 TT = JD 2488434.4583333335
        run_benchmark_range(
            "Range B: 1900–2100 (Hourly)",
            eraDtdb,
            start_jd=2415020.5,
            end_jd=2488434.4583333335,
            step_days=1.0 / 24.0,
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())

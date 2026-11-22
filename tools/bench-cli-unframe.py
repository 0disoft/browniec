"""Measure Windows CLI validation and byte transform in fresh processes."""

import argparse
import base64
import hashlib
import json
from pathlib import Path
from statistics import median
import subprocess
from tempfile import TemporaryDirectory
from time import perf_counter_ns


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "examples/projects/configured-output"


def measure(exe, path, samples):
    payload = b"\x00\xff\x0a" * 1366
    encoded = base64.b64encode(payload).decode("ascii")
    args = ["--project", PROJECT / "unframe.json", "--policy", PROJECT / "policy.json",
            "--run", PROJECT / "run.json", "--json-v2"]
    cases = (
        ("check", ["check", *args], None, None),
        ("reject", ["run", *args, "--input", path / "rejected.bin"], 0, ""),
        ("transform", ["run", *args, "--input", path / "accepted.bin"], 1, encoded),
        ("isolated_transform", ["run", *args, "--input", path / "accepted.bin", "--isolated"],
         1, encoded),
    )
    (path / "accepted.bin").write_bytes(b"\x01" + payload)
    (path / "rejected.bin").write_bytes(b"\x02" + payload)
    timings = {name: [] for name, *_ in cases}
    for _ in range(samples):
        for name, arguments, returned, output in cases:
            start = perf_counter_ns()
            proc = subprocess.run([exe, *arguments], capture_output=True, timeout=15)
            elapsed = perf_counter_ns() - start
            assert proc.returncode == 0 and not proc.stderr and len(proc.stdout.splitlines()) == 1, proc
            expected = {
                "schema": "browniec.result/v2", "profile": "brownie.m2-reference/1",
                "command": arguments[0], "status": "checked" if returned is None else "completed",
                "return_i32": returned, "error": None,
            }
            if output is not None:
                expected["output_b64"] = output
            result = json.loads(proc.stdout)
            assert result == expected and type(result["return_i32"]) is type(returned), (name, result)
            timings[name].append(elapsed)
    return timings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", required=True, type=Path)
    parser.add_argument("--samples", type=int, default=41)
    args = parser.parse_args()
    if args.samples < 20:
        parser.error("at least 20 samples are required for a p95")
    exe = args.exe.resolve(strict=True)
    print(f"cli_sha256={hashlib.sha256(exe.read_bytes()).hexdigest()}", flush=True)
    with TemporaryDirectory(prefix="browniec-unframe-bench-") as directory:
        timings = measure(exe, Path(directory), args.samples)
    print("process samples median_ms p95_ms")
    for name, elapsed in timings.items():
        elapsed.sort()
        p95 = (95 * len(elapsed) + 99) // 100 - 1
        print(f"{name} {len(elapsed)} {median(elapsed) / 1e6:.3f} {elapsed[p95] / 1e6:.3f}")


if __name__ == "__main__":
    main()

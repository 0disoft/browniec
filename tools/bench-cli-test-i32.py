"""Compare 1,000 shipping-rule checks in single CLI calls and one batch."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory
from time import perf_counter_ns


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "examples/shipping-fee.brc"
FUEL = 256
ORDERS = range(29500, 30500)


def invoke(exe, directory, environment, arguments, stdout=None, stderr=b""):
    start = perf_counter_ns()
    result = subprocess.run([exe, *arguments], cwd=directory, env=environment,
                            capture_output=True, timeout=15)
    elapsed = perf_counter_ns() - start
    if result.returncode != 0 or result.stderr != stderr or (stdout is not None and result.stdout != stdout):
        raise ValueError(f"Unexpected CLI outcome: {result}")
    return result.stdout, elapsed


def measure(exe, directory):
    cases = [(order, 3000 if order < 30000 else 0) for order in ORDERS]
    policy = directory / SOURCE.name
    policy.write_bytes(SOURCE.read_bytes())
    csv = directory / "shipping-fee.csv"
    csv.write_bytes("".join(f"{order},{fee}\n" for order, fee in cases).encode("ascii"))
    windows = Path(os.environ["SystemRoot"])
    environment = {"SystemRoot": str(windows), "WINDIR": str(windows),
                   "PATH": os.pathsep.join(map(str, (windows / "System32", windows))),
                   "TMP": str(directory), "TEMP": str(directory)}

    single_ns = 0
    for order, fee in cases:
        raw, elapsed = invoke(exe, directory, environment,
                              ["eval-i32", policy, str(order), "--fuel", str(FUEL), "--json"])
        expected = {"schema": "browniec.result/v1", "profile": "brownie.m1-scalar/1",
                    "command": "eval-i32", "status": "completed", "return_i32": fee, "error": None}
        result = json.loads(raw)
        if result != expected or type(result["return_i32"]) is not int:
            raise ValueError(f"Unexpected fee for order {order}: {result}")
        single_ns += elapsed

    _, batch_ns = invoke(exe, directory, environment,
                         ["test-i32", policy, csv, "--fuel", str(FUEL)], stdout=b"",
                         stderr=f"test-i32: {len(cases)} cases passed\n".encode("ascii"))
    return {"cases": len(cases), "fuelPerCase": FUEL,
            "sourceSha256": hashlib.sha256(policy.read_bytes()).hexdigest(),
            "csvSha256": hashlib.sha256(csv.read_bytes()).hexdigest(),
            "single": {"processes": len(cases), "elapsedNs": single_ns},
            "batch": {"processes": 1, "elapsedNs": batch_ns}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", required=True, type=Path)
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("Windows is required")
    exe = args.exe.resolve(strict=True)
    with TemporaryDirectory(prefix="browniec-batch-bench-") as directory:
        result = measure(exe, Path(directory))
    result["cliSha256"] = hashlib.sha256(exe.read_bytes()).hexdigest()
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

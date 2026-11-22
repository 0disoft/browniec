"""Measure retained project outputs across successive locked Windows builds."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import shutil
from stat import S_ISREG
import subprocess
from tempfile import mkdtemp
from threading import Event
from time import perf_counter


ROOT = Path(__file__).resolve().parents[1]
COMPILER = ROOT / "build/toolchain/fairyc.exe"
TARGET_BYTES = 32 * 1024 * 1024
FAILURE_MARKER = "BROWNIEC_RETAINED_BUILD_FIXTURE"
SCRATCH_SAMPLE_SECONDS = 0.25


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def files(root):
    return {path.relative_to(root).as_posix(): path.stat().st_size
            for path in root.rglob("*") if path.is_file()}


def sample_scratch(scratch, other_owner, stop):
    peak = 0
    symbol_peak = 0
    samples = 0
    while not stop.is_set():
        total = 0
        symbols = 0
        for owner in scratch.iterdir():
            if owner == other_owner:
                continue
            for path in owner.rglob("*") if owner.is_dir() else (owner,):
                try:
                    info = path.stat()
                except FileNotFoundError:
                    continue
                if S_ISREG(info.st_mode):
                    total += info.st_size
                    if path.suffix.lower() in (".pdb", ".ilk", ".dbg"):
                        symbols += info.st_size
        peak = max(peak, total)
        symbol_peak = max(symbol_peak, symbols)
        samples += 1
        stop.wait(SCRATCH_SAMPLE_SECONDS)
    return dict(scratchSamples=samples, sampledScratchPeakBytes=peak,
                sampledSymbolPeakBytes=symbol_peak)


def write_receipt(directory, receipt):
    pending = directory / "receipt.tmp"
    pending.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8", newline="\n")
    pending.replace(directory / "receipt.json")


def verify(directory, count, profile, receipt):
    project = directory / "project"
    project.mkdir()
    for name in ("src", "native"):
        shutil.copytree(ROOT / name, project / name)
    for name in ("fairy.toml", "fairy.windows.json", "fairy.lock", "examples/answer.brc"):
        dest = project / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, dest)
    original_files = set(files(project))
    receipt["inputs"] = {name: sha(project / name) for name in sorted(original_files)}

    scratch = directory / "scratch"
    other_owner = scratch / "other-owner"
    other_owner.mkdir(parents=True)
    sentinel = other_owner / "active.txt"
    sentinel.write_bytes(b"another build's scratch\n")
    environment = dict(os.environ, TEMP=str(scratch), TMP=str(scratch))
    source = project / "src/main.fy"
    baseline = source.read_bytes()
    marker = b"Brownie C experimental:"
    if baseline.count(marker) != 1:
        raise ValueError("Could not identify the CLI version string to edit")
    executable = project / "build/browniec.exe"
    options = ["build", "--locked", *(["--release"] if profile == "release" else [])]

    def invoke(*args, timeout=900):
        return subprocess.run(args, cwd=project, env=environment, capture_output=True, timeout=timeout)

    def measured_build():
        stop = Event()
        with ThreadPoolExecutor(max_workers=1) as pool:
            sampling = pool.submit(sample_scratch, scratch, other_owner, stop)
            try:
                start = perf_counter()
                result = invoke(COMPILER, *options)
                elapsed = perf_counter() - start
            finally:
                stop.set()
            return result, elapsed, sampling.result()

    def check_build_outputs():
        if set(scratch.iterdir()) != {other_owner} or sentinel.read_bytes() != b"another build's scratch\n":
            raise ValueError("Build left invocation scratch or altered the other scratch owner")
        current = files(project)
        if not original_files.issubset(current):
            raise ValueError("Build removed a source or configuration file")
        output = {name: size for name, size in current.items() if name not in original_files}
        if set(output) != {"build/browniec.exe"}:
            raise ValueError(f"Unexpected retained build files: {output}")
        return output["build/browniec.exe"]

    for step in range(1, count + 1):
        version = f"Brownie C retained build {step:03d}:".encode("ascii")
        source.write_bytes(baseline.replace(marker, version))
        checked = invoke(COMPILER, "check")
        checked.check_returncode()
        built, elapsed, measured = measured_build()
        if built.returncode:
            raise RuntimeError(built.stderr.decode("utf-8", "replace"))
        retained = check_build_outputs()
        observed = invoke(executable, "--version", timeout=15)
        answer = invoke(executable, "run", "examples/answer.brc", "--json", timeout=15)
        observed.check_returncode()
        answer.check_returncode()
        data = json.loads(answer.stdout)
        if (observed.stderr or not observed.stdout.startswith(version) or answer.stderr or
                data.get("status") != "completed" or data.get("return_i32") != 77 or
                data.get("schema") != "browniec.result/v1" or data["error"] is not None):
            raise ValueError("Built output did not execute the current edit and the example")
        receipt["builds"].append(dict(edit=step, seconds=round(elapsed, 3),
                                      retainedBytes=retained, sha256=sha(executable), **measured))
        write_receipt(directory, receipt)
        print(f"{profile} {step}/{count}: {retained:,} retained bytes in {elapsed:.1f}s", flush=True)

    bridge = project / "native/windows-scalar-broker.c"
    bridge.write_bytes(bridge.read_bytes() + f"\n#error {FAILURE_MARKER}\n".encode("ascii"))
    invoke(COMPILER, "check").check_returncode()
    failed, _, measured = measured_build()
    if failed.returncode == 0 or FAILURE_MARKER.encode("ascii") not in failed.stderr:
        raise ValueError(f"Expected a native compilation failure: {failed.stderr!r}")
    check_build_outputs()
    if sha(executable) != receipt["builds"][-1]["sha256"]:
        raise ValueError("Failed build modified the last successful executable")
    receipt["failedBuild"] = dict(exit=failed.returncode, scratchRemoved=True,
                                  previousImagePreserved=True, **measured)
    receipt["peakRetainedBytes"] = max(row["retainedBytes"] for row in receipt["builds"])
    if receipt["peakRetainedBytes"] > TARGET_BYTES:
        raise ValueError(f"Retained build output exceeds {TARGET_BYTES:,} bytes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--builds", type=int, choices=range(1, 101), metavar="1..100", default=100)
    parser.add_argument("--profile", choices=("development", "release"), default="release")
    args = parser.parse_args()
    if os.name != "nt" or {"CL", "_CL_", "LINK"}.intersection(k.upper() for k in os.environ):
        parser.error("Windows and default compiler/linker options are required")
    compiler_pin = json.loads((ROOT / "toolchain.json").read_bytes())["platforms"]["windows/amd64"]["sha256"]
    if sha(COMPILER) != compiler_pin:
        parser.error("The installed compiler must match the Windows toolchain pin")
    directory = Path(mkdtemp(prefix="retained-builds-", dir=ROOT / "build"))
    receipt = dict(status="incomplete", profile=args.profile, requestedBuilds=args.builds,
                   compilerSha256=compiler_pin, compilerBytes=COMPILER.stat().st_size,
                   targetBytes=TARGET_BYTES, scratchSampleSeconds=SCRATCH_SAMPLE_SECONDS, builds=[])
    print(f"Artifacts: {directory}", flush=True)
    try:
        verify(directory, args.builds, args.profile, receipt)
        receipt["status"] = "passed"
    finally:
        write_receipt(directory, receipt)


if __name__ == "__main__":
    main()

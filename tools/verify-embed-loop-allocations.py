"""Relink a verified Windows embed build with the SDK heap observer."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from tempfile import mkdtemp

from importlib import import_module


ROOT = Path(__file__).resolve().parents[1]


def verify(image):
    receipt = json.loads((image / "receipt.json").read_bytes())
    output = Path(mkdtemp(prefix="embed-allocations-", dir=ROOT / "build"))
    print(f"Artifacts: {output}", flush=True)
    observer = (ROOT / "tools/runtime-engine/heap-observer.c").read_bytes()
    runtime = output / "runtime.c"
    runtime.write_bytes(observer + b"\n" + (image / "runtime.c").read_bytes())
    probe = import_module("verify-runtime-store-probe")
    cl, env, _ = probe.native_environment(subprocess.check_output)
    for profile, option in (("development", "/Od"), ("optimized", "/O2")):
        source = image / profile
        digest = hashlib.sha256((source / "brownie-preview.dll").read_bytes()).hexdigest()
        if receipt["dllSha256"].get(profile) != digest:
            raise ValueError(f"{profile} DLL differs from its build receipt")
        folder = output / profile
        folder.mkdir()

        def native(*args):
            subprocess.run([cl, "/nologo", *args], cwd=folder, env=env, check=True, timeout=120)

        options = ("/std:c11", "/MT", "/Gy", option)
        native(*options, "/c", runtime, "/Foruntime.obj")
        names = ("preview", "registry", "thread", "project", "input", "adapter")
        native(*(source / f"{name}.obj" for name in names), "runtime.obj", "/LD",
               "/Febrownie-preview.dll", "/link", "/OPT:REF", "/EXPORT:probe_attempts",
               "/EXPORT:probe_live", "bcrypt.lib", "ntdll.lib")
        native(*options, "/W4", "/WX", "/DBC_BENCH_ALLOCATIONS", "/I" + str(ROOT / "include"),
               ROOT / "tools/bench-embed-reuse.c", "/Febench-embed-reuse.exe",
               "/link", "brownie-preview.lib")
        for fixture in ("policy.json", "run.json"):
            shutil.copyfile(source / fixture, folder / fixture)
        result = subprocess.run(
            [folder / "bench-embed-reuse.exe", "policy.json", "run.json", "--loop"],
            cwd=folder, check=True, capture_output=True, timeout=60,
        )
        if result.stderr or b"step_sdk_allocations=0 final_live_sdk_allocations=0" not in result.stdout:
            raise ValueError(f"{profile} allocation probe did not pass: {result}")
        (folder / "report.txt").write_bytes(result.stdout)
        print(f"{profile}: base DLL {digest}\n{result.stdout.decode()}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path, help="build-embed-preview.py output with both profiles")
    args = parser.parse_args()
    verify(args.image.resolve(strict=True))


if __name__ == "__main__":
    main()

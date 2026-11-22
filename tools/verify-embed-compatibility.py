"""Test Windows x64 embedding upgrade and rollback with two recorded ZIPs."""

import argparse
from importlib import import_module
from io import BytesIO
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from tempfile import mkdtemp

package = import_module("package-windows")
native = import_module("verify-runtime-store-probe")
ROOT = Path(__file__).resolve().parents[1]
HOST = ROOT / "tests/embed/compatibility_host.c"
FIXTURES = ROOT / "tools/runtime-policy/reference"


def extract(archive, digest, destination):
    snapshot = archive.read_bytes()
    if package.sha256(snapshot) != digest:
        raise ValueError(f"ZIP digest mismatch: {archive}")
    if not package.unpack_verified(BytesIO(snapshot), destination, {}):
        raise ValueError(f"Embedding payload is required: {archive}")
    return destination / "embed"


def verify(output, archives, receipt):
    products = {name: extract(archive, digest, output / name)
                for name, (archive, digest) in archives.items()}
    cl, env, receipt["msvc"] = native.native_environment(subprocess.check_output)
    for linked, files in products.items():
        host = output / f"{linked}-host.exe"
        subprocess.run(
            [cl, "/nologo", "/std:c11", "/MT", "/O2", "/W4", "/WX",
             f"/I{files / 'include'}", HOST, f"/Fo{host.with_suffix('.obj')}", f"/Fe{host}",
             "/link", files / "brownie-preview.lib"],
            cwd=output, env=env, check=True, timeout=60,
        )
        host_digest = package.sha256(host.read_bytes())
        for loaded, runtime in products.items():
            session = output / f"{linked}-on-{loaded}"
            session.mkdir()
            shutil.copyfile(host, session / host.name)
            shutil.copyfile(runtime / "brownie-preview.dll", session / "brownie-preview.dll")
            shutil.copyfile(FIXTURES / "policy.pure.json", session / "policy.json")
            shutil.copyfile(FIXTURES / "run-base.json", session / "run.json")
            result = subprocess.run(
                [session / host.name], cwd=session, env=package.runtime_environment(session),
                capture_output=True, timeout=30,
            )
            (session / "stdout.txt").write_bytes(result.stdout)
            (session / "stderr.txt").write_bytes(result.stderr)
            receipt["runs"].append(dict(linked=linked, loaded=loaded, hostSha256=host_digest,
                                        dllSha256=package.sha256((session / "brownie-preview.dll").read_bytes()),
                                        exit=result.returncode))
            if result.returncode or result.stderr or result.stdout.splitlines() != [b"PASS ABI revision 2: 77"]:
                raise ValueError(f"{linked} host could not run on {loaded} DLL: {result}")
            print(f"PASS {linked} host on {loaded} DLL: 77", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("previous", "candidate"):
        parser.add_argument(f"--{name}", type=Path, required=True)
        parser.add_argument(f"--{name}-sha256", required=True)
    args = parser.parse_args()
    if os.name != "nt" or {"CL", "_CL_", "LINK"}.intersection(k.upper() for k in os.environ):
        parser.error("Windows and default compiler/linker options are required")
    archives = {
        name: (getattr(args, name).resolve(strict=True), getattr(args, f"{name}_sha256").lower())
        for name in ("previous", "candidate")
    }
    if any(not re.fullmatch("[0-9a-f]{64}", digest) for _, digest in archives.values()):
        parser.error("Both recorded SHA-256 values must contain 64 hex digits")
    if archives["previous"][1] == archives["candidate"][1]:
        parser.error("Provide two distinct candidate archives")
    output = Path(mkdtemp(prefix="embed-compatibility-", dir=ROOT / "build"))
    receipt = dict(status="incomplete", archives={
        name: dict(path=str(path), sha256=digest) for name, (path, digest) in archives.items()
    }, inputs={
        path.relative_to(ROOT).as_posix(): package.sha256(path.read_bytes())
        for path in (HOST, FIXTURES / "policy.pure.json", FIXTURES / "run-base.json")
    }, runs=[])
    print(f"Artifacts: {output}", flush=True)
    try:
        verify(output, archives, receipt)
        receipt["status"] = "passed"
    finally:
        (output / "receipt.json").write_text(
            json.dumps(receipt, indent=2) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()

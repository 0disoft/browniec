"""Assemble and smoke-test a local Windows x64 Brownie C CLI candidate."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
from tempfile import TemporaryDirectory
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parents[1]
CHECKSUMS = "SHA256SUMS.txt"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def require_windows_x64_exe(data):
    if len(data) < 64 or data[:2] != b"MZ":
        raise ValueError("Expected a Windows PE image")
    offset = struct.unpack_from("<I", data, 0x3C)[0]
    if offset < 64 or offset + 26 > len(data) or data[offset:offset + 4] != b"PE\0\0":
        raise ValueError("Invalid Windows PE header")
    machine = struct.unpack_from("<H", data, offset + 4)[0]
    flags, magic = struct.unpack_from("<HH", data, offset + 22)
    if machine != 0x8664 or magic != 0x20B or flags & 0x2000:
        raise ValueError("Expected a Windows x64 executable")


def checksums(files):
    return "".join(f"{sha256(data)}  {name}\n" for name, data in sorted(files.items())).encode("ascii")


def write_archive(archive, files):
    with ZipFile(archive, "x") as bundle:
        for name, data in sorted(files.items()):
            member = ZipInfo(name)
            member.create_system = 0
            bundle.writestr(member, data, compress_type=ZIP_DEFLATED, compresslevel=9)


def unpack_verified(archive, names, destination):
    with ZipFile(archive) as bundle:
        if sorted(bundle.namelist()) != sorted([*names, CHECKSUMS]):
            raise ValueError("Unexpected Windows candidate ZIP entries")
        files = {name: bundle.read(name) for name in names}
        if checksums(files) != bundle.read(CHECKSUMS):
            raise ValueError("Windows candidate ZIP checksum mismatch")
    for name, data in files.items():
        path = destination / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def runtime_environment(directory):
    windows = Path(os.environ["SystemRoot"])
    return {
        "SystemRoot": str(windows),
        "WINDIR": str(windows),
        "PATH": os.pathsep.join(map(str, (windows / "System32", windows))),
        "TEMP": str(directory),
        "TMP": str(directory),
    }


def smoke(directory):
    exe = directory / "browniec.exe"
    env = runtime_environment(directory)
    for command, status in (("check", "checked"), ("run", "completed")):
        result = subprocess.run(
            [exe, command, "examples/answer.brc", "--json"],
            cwd=directory, env=env, capture_output=True, timeout=15,
        )
        if result.returncode != 0 or result.stderr or len(result.stdout.splitlines()) != 1:
            raise ValueError(f"Packaged {command} failed: {result}")
        payload = json.loads(result.stdout)
        if (not isinstance(payload, dict) or payload.get("schema") != "browniec.result/v1"
                or payload.get("command") != command or payload.get("status") != status
                or "error" not in payload or payload["error"] is not None):
            raise ValueError(f"Unexpected packaged {command}: {payload}")
        value = payload.get("return_i32")
        if command == "run" and (type(value) is not int or value != 77):
            raise ValueError(f"Unexpected packaged {command}: {payload}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("Windows is required to verify the candidate")
    output = args.output.absolute()
    if output.exists():
        parser.error(f"Output already exists: {output}")
    files = {
        "browniec.exe": args.exe.read_bytes(),
        "examples/answer.brc": (ROOT / "examples/answer.brc").read_bytes(),
    }
    require_windows_x64_exe(files["browniec.exe"])
    output.parent.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix="browniec-candidate-", dir=output.parent) as temporary:
        directory = Path(temporary)
        archive = directory / "candidate.zip"
        write_archive(archive, {**files, CHECKSUMS: checksums(files)})
        installed = directory / "installed"
        unpack_verified(archive, files, installed)
        smoke(installed)
        digest = sha256(archive.read_bytes())
        archive.rename(output)
    print("PASS Windows CLI candidate: check and run (77), exit 0, empty stderr")
    print(f"{digest}  {output}")


if __name__ == "__main__":
    main()

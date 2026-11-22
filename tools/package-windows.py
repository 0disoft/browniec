"""Assemble or verify a Windows x64 Brownie C candidate."""

import argparse
import hashlib
from io import BytesIO
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
from tempfile import TemporaryDirectory
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parents[1]
CHECKSUMS = "SHA256SUMS.txt"
CLI_FILES = {"browniec.exe", "examples/answer.brc"}
EMBED_HEADERS = ("brownie.h", "brownie_preview.h")
EMBED_FILES = {"embed/brownie-preview.dll", "embed/brownie-preview.lib",
               *(f"embed/include/{name}" for name in EMBED_HEADERS)}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def require_windows_x64(data, *, dll=False):
    if len(data) < 64 or data[:2] != b"MZ":
        raise ValueError("Expected a Windows PE image")
    offset = struct.unpack_from("<I", data, 0x3C)[0]
    if offset < 64 or offset + 26 > len(data) or data[offset:offset + 4] != b"PE\0\0":
        raise ValueError("Invalid Windows PE header")
    machine = struct.unpack_from("<H", data, offset + 4)[0]
    flags, magic = struct.unpack_from("<HH", data, offset + 22)
    if machine != 0x8664 or magic != 0x20B or bool(flags & 0x2000) != dll:
        raise ValueError("Unexpected Windows x64 PE image kind")


def checksums(files):
    return "".join(f"{sha256(data)}  {name}\n" for name, data in sorted(files.items())).encode("ascii")


def write_archive(archive, files):
    with ZipFile(archive, "x") as bundle:
        for name, data in sorted(files.items()):
            member = ZipInfo(name)
            member.create_system = 0
            bundle.writestr(member, data, compress_type=ZIP_DEFLATED, compresslevel=9)


def unpack_verified(archive, destination, expected_embed):
    with ZipFile(archive) as bundle:
        members = bundle.namelist()
        names = set(members) - {CHECKSUMS}
        if (len(members) != len(names) + 1 or CHECKSUMS not in members or
                names not in (CLI_FILES, CLI_FILES | EMBED_FILES)):
            raise ValueError("Unexpected Windows candidate ZIP entries")
        files = {name: bundle.read(name) for name in names}
        if checksums(files) != bundle.read(CHECKSUMS):
            raise ValueError("Windows candidate ZIP checksum mismatch")
    require_windows_x64(files["browniec.exe"])
    embedded = names & EMBED_FILES
    if embedded:
        require_windows_x64(files["embed/brownie-preview.dll"], dll=True)
    if expected_embed and {name: files[name] for name in embedded} != expected_embed:
        raise ValueError("Packaged embedding payload does not match the selected build")
    for name, data in files.items():
        path = destination / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return bool(embedded)


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


def embed_files(profile):
    receipt = json.loads((profile.parent / "receipt.json").read_bytes())
    if "importLibrarySha256" not in receipt or "headerSha256" not in receipt:
        raise ValueError("Rebuild the embedding preview to obtain a receipt for the import library and headers")
    dll = (profile / "brownie-preview.dll").read_bytes()
    require_windows_x64(dll, dll=True)
    if receipt["dllSha256"].get(profile.name) != sha256(dll):
        raise ValueError("Embedding DLL does not match its build receipt")
    library = (profile / "brownie-preview.lib").read_bytes()
    if receipt["importLibrarySha256"].get(profile.name) != sha256(library):
        raise ValueError("Embedding import library does not match its build receipt")
    files = {"embed/brownie-preview.dll": dll, "embed/brownie-preview.lib": library}
    for name in EMBED_HEADERS:
        header = (profile.parent / "include" / name).read_bytes()
        if receipt["headerSha256"].get(name) != sha256(header):
            raise ValueError(f"Embedding header {name} does not match its build receipt")
        files[f"embed/include/{name}"] = header
    return files


def smoke_embed(profile, directory):
    # The x64 host built and linked for this profile loads the extracted DLL
    # from its own directory. Its executable and fixtures are local test inputs.
    for name in ("preview-host.exe", "policy.json", "run.json", "policy-output.json",
                 "run-output.json", "policy-host.json", "run-host.json"):
        shutil.copyfile(profile / name, directory / name)
    result = subprocess.run(
        [directory / "preview-host.exe"], cwd=directory, env=runtime_environment(directory),
        capture_output=True, timeout=30,
    )
    if result.returncode != 0 or result.stderr:
        raise ValueError(f"Packaged embedding DLL failed: {result}")


def verify_candidate(archive, destination, profile, expected_embed):
    embedded = unpack_verified(archive, destination, expected_embed)
    smoke(destination)
    if profile:
        smoke_embed(profile, destination / "embed")
    return embedded


def assemble(exe, output, profile, expected_embed):
    files = {
        "browniec.exe": exe.read_bytes(),
        "examples/answer.brc": (ROOT / "examples/answer.brc").read_bytes(),
        **expected_embed,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix="browniec-candidate-", dir=output.parent) as temporary:
        directory = Path(temporary)
        archive = directory / "candidate.zip"
        write_archive(archive, {**files, CHECKSUMS: checksums(files)})
        embedded = verify_candidate(archive, directory / "installed", profile, expected_embed)
        digest = sha256(archive.read_bytes())
        archive.rename(output)
    return digest, embedded


def verify_existing(archive, digest, profile, expected_embed):
    snapshot = archive.read_bytes()
    if sha256(snapshot) != digest:
        raise ValueError("Windows candidate ZIP differs from the expected SHA-256")
    with BytesIO(snapshot) as stream, TemporaryDirectory(prefix="browniec-candidate-") as temporary:
        return verify_candidate(stream, Path(temporary), profile, expected_embed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--exe", type=Path, help="assemble a ZIP from a local executable")
    source.add_argument("--verify", type=Path, metavar="ZIP", help="verify an existing ZIP")
    parser.add_argument("--output", type=Path, help="destination for assembly")
    parser.add_argument("--sha256", help="expected ZIP SHA-256 for verification")
    parser.add_argument("--embed", type=Path, metavar="PROFILE_DIR",
                        help="include or verify a profile from tools/build-embed-preview.py")
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("Windows is required to verify the candidate")
    if args.verify:
        if args.output or not re.fullmatch("[0-9a-fA-F]{64}", args.sha256 or ""):
            parser.error("--verify requires --sha256 with 64 hex digits and takes no --output")
        archive = args.verify.resolve(strict=True)
        digest = args.sha256.lower()
    else:
        if not args.output or args.sha256:
            parser.error("--exe requires --output and takes no --sha256")
        archive = args.output.absolute()
        if archive.exists():
            parser.error(f"Output already exists: {archive}")
    expected_embed = embed_files(args.embed) if args.embed else {}
    if args.verify:
        embedded = verify_existing(archive, digest, args.embed, expected_embed)
    else:
        digest, embedded = assemble(args.exe, archive, args.embed, expected_embed)
    print("PASS Windows CLI candidate: check and run (77), exit 0, empty stderr")
    if args.embed:
        print("PASS Windows embedding candidate: extracted DLL passed its C host")
    elif embedded:
        print("PASS Windows embedding payload: verified archive entries, checksums and DLL architecture")
    print(f"{digest}  {archive}")


if __name__ == "__main__":
    main()

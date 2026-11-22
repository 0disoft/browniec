# Release

- Status: Draft

## Contract

Promote a known artifact through a deliberate release sequence and report what was actually published, activated, and verified.

Project-wide decisions: docs/ops/00-operational-contract.md

## Local Windows candidate

Build the locked Windows release first. Assemble a candidate from that binary:

```powershell
python -B tools/package-windows.py --exe build/browniec.exe --output build/browniec-windows-x64.zip
```

The ZIP contains the x64 executable, `examples/answer.brc`, and
`SHA256SUMS.txt`. The assembler reads back the archived files, checks each
digest, and runs `check` and `run` from a fresh extraction. Both commands
must exit 0 with empty stderr, and the run must return 77. The subprocesses
receive only Windows system directories on PATH. The assembler prints the
ZIP SHA-256 after the checks pass.

For a two-file deployment rehearsal, copy `browniec.exe` and a trusted
single-file rule to a fresh directory. The archive's example can be copied as
`app.brc`. In PowerShell on the target machine, run:

```powershell
.\browniec.exe check .\app.brc --json
.\browniec.exe run .\app.brc --json
```

Check that both commands exit 0 with empty stderr and that the run emits one
JSON object containing `return_i32: 77`. Record the exact ZIP digest and byte
length and time the first run on the target machine.

The local rehearsal on `f179c086` extracted a 3,568,640-byte /O2 executable
from a 1,523,063-byte ZIP. The two-file run returned 77 in 159.8 ms from
launch through output capture and process exit, with a system-only PATH.
Local receipt: `build/cli-two-file-5h8g1gl8/receipt.json`. A disconnected
Windows VM without developer tools remains a separate verification target.

To include the embedding preview, pass `--embed` with a profile directory
produced by `python -B tools/build-embed-preview.py`. The candidate adds the DLL,
MSVC import library and the exact header copies used to compile the DLL and
its C host. The assembler checks all four files against the build receipt
and runs the profile's C host against the extracted DLL with the same
system-only PATH. Rebuild older profiles to get a receipt with all four
hashes. The host and its test configurations stay outside the ZIP.

This checks local execution on the packaging machine. Clean-machine
verification and the license/dependency notices are separate delivery
requirements. Candidate assembly uploads nothing.

## Verify an existing candidate

Use the ZIP digest recorded at candidate assembly or in the approved release
record. Verify the candidate before selecting it for promotion or rollback:

```powershell
python -B tools/package-windows.py --verify $candidateZip --sha256 $recordedZipSha256
```

Verification checks the exact ZIP digest, the expected member names and each
member digest. It runs the same quickstart from a fresh temporary extraction
and leaves the ZIP untouched. For candidates with embedding, pass the matching
build profile directory via `--embed` to verify and run its C host. The
profile receipt must match the DLL, import library and both headers in the ZIP.
Without the profile directory, verification covers the embedded files'
integrity and the DLL architecture.

Keep each candidate in its own directory and record its source revision, ZIP
digest, and whether it contains the embedding preview. The CLI delivery unit
includes the executable, example and checksum manifest. The embedding preview
adds one DLL, its matching import library and both headers as a single payload.
Keep the previous verified ZIP and its record until the updated candidate
passes the consumer's smoke checks. To restore the previous version, verify
that ZIP with its recorded digest, extract it to a fresh directory, and point
the consumer to the previous executable or matching set of embedding files.
For embedding, stop processes using the current DLL before switching the set.

The local Windows rehearsal verified the new optimized candidate and then the
previous one. Each ZIP passed the CLI quickstart and its matching embedding C
host, and both ZIP digests were unchanged by verification. A CLI-only ZIP also
passed. Six rejection cases covered the wrong ZIP digest, wrong or absent
embedding payload, changed member content, duplicate members and unexpected
members. Evidence: `build/package-recheck-blwf0uqu/receipt.json`.

## Check embedding consumer compatibility

Run the same revision-2 C consumer against both recorded Windows x64 ZIPs:

```powershell
python -B tools/verify-embed-compatibility.py `
  --previous $previousZip --previous-sha256 $previousSha256 `
  --candidate $candidateZip --candidate-sha256 $candidateSha256
```

The check verifies each ZIP digest and member manifest. It compiles one
consumer with the headers and import library from each ZIP. Each executable
then runs unchanged against both DLLs in fresh processes with a system-only
PATH and the same policy and run configuration. All four combinations must
accept the revision-2 layouts, compile and run the rule, return 77, and release
the Instance and Engine. The local optimized ZIP rehearsal passed all four
combinations, including the previous consumer on the candidate DLL and the
candidate consumer on the previous DLL. Evidence:
`build/embed-compatibility-5dxjf8b0/receipt.json`.

Use the application's own compatibility checks before switching a consumer
that uses other features or a different configuration. The scalar rehearsal
covers process restart with fresh handles and that fixture's policy and run
configuration.

## Required Decisions

- Public promotion: UNDECIDED. Define the version, destination, and owner of the promotion decision.
- Compatibility and ordering: UNDECIDED. Identify consumer, configuration, and data compatibility requirements and dependencies that constrain the release sequence.
- Promotion evidence: UNDECIDED. Name required checks, artifact validation, and user-visible acceptance criteria tied to the exact candidate.
- Activation and observation: UNDECIDED. Define rollout stages, health windows, stop conditions, communication, and how published artifacts differ from active runtime state.
- Partial release recovery: UNDECIDED. Record possible mixed-version or partially activated states, rollback limits, forward-fix options, and evidence of recovery.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md

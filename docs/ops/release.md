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

## Required Decisions

- Release unit: UNDECIDED. Define the version, artifact identity, included changes, destination, and owner of the promotion decision.
- Compatibility and ordering: UNDECIDED. Identify consumer, configuration, and data compatibility requirements and dependencies that constrain the release sequence.
- Promotion evidence: UNDECIDED. Name required checks, artifact validation, and user-visible acceptance criteria tied to the exact candidate.
- Activation and observation: UNDECIDED. Define rollout stages, health windows, stop conditions, communication, and how published artifacts differ from active runtime state.
- Partial release recovery: UNDECIDED. Record possible mixed-version or partially activated states, rollback limits, forward-fix options, and evidence of recovery.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md

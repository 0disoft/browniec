# Validation

- Status: accepted evidence policy; M0 and first M1 scalar slice verified
- Current implementation: M0 primitives and experimental M1 scalar source CLI/VM

## Validation source of truth

This file defines evidence expectations for Brownie C. `tools/verify-m0.ps1` verifies
the native M0 primitives. `tools/verify-m1.ps1` builds and verifies the experimental
scalar `browniec` CLI, native compiler/verifier/VM, and black-box source cases.

Do not report a proposed command as executed. Do not treat a design package, static
link check, Python model, or source fixture as proof of the Brownie VM.

## Evidence levels

| Level | What it can establish |
| --- | --- |
| Document check | Links, required sections, terminology, and status consistency |
| Independent model | Small expected examples for layout, quota, ordering, or codec rules |
| Native unit probe | A shim or VM primitive behaves under recorded inputs |
| Source end-to-end | .brc source compiles, verifies, runs, and publishes as specified |
| OS integration | Actual Windows isolation, cancellation, IPC, and cleanup behavior |
| Performance measurement | A named workload meets or misses a measured budget |

Higher-level behavior requires its own evidence. A passing lower level is useful
context, never automatic acceptance of the next level.

## Current documentation checks

No link checker or Markdown linter is configured. A reviewer may run
git diff --check for whitespace and patch integrity. Markdown links and status
language should be checked without claiming a product test.

Historical design-package note: the external package reported 746 passing design
checks on Windows with Python 3.14.6. C/C++ header syntax and layout checks were
skipped because cc and c++
were unavailable. That result is design-package evidence only.

The package contains 29 .brc examples and 32 acceptance cases recorded as not
executed. None proves parser, compiler, verifier, VM, allocator, ABI, or sandbox behavior.

## Required milestone evidence

M0 has recorded native primitive evidence for:

- fallible storage and rollback;
- signed little-endian codec including i64 MIN and MAX;
- checked arithmetic including i64 MIN/MAX edge cases;
- generation reuse rejection without pointer dereference;
- runtime status return instead of a Fairy native trap;
- a one-shot real-target allocator failure with no leaked target heap allocation;
- typed owner rejection before payload access, including stale and retired tokens;
- scalar array frame copies and exclusive view updates.

The expanded run passed six native executions: development and release normal
baselines, development and release instrumented normal runs, and development and
release instrumented allocator-failure runs plus leak checks. It also produced the four exact
negative compiler diagnostics:

| Fixture | Diagnostic |
| --- | --- |
| use after move | `E1101` |
| grow with a live shared view | `E2101` |
| escape a local view | `E2102` |
| exclusive alias | `E2101` |

The run used Fairy source `4ce1264273be6051ee560173e94690e1b99c9eaf`, SDK
`0.0.0-stage0.86`, language `fairyc-language/20`, MSVC tools `14.51.36231`, `cl`
`19.51.36248.0`, Windows SDK `10.0.26100.0`, and Go `1.27.1`. The compiler build
identity is SHA-256
`572395f7f1e425d613c5a69f50b30ed177cda37ca2b1638bd0c11cf79fcbcc77`.
Exact transcript and artifact details belong to `build/m0/receipt.json` and
`docs/evidence/m0-windows-20261023.json`.

Full M1 remains partial; M2 through M5 remain not started. M0's empty runtime-`PATH` execution does not
establish clean-machine packaging or Windows isolation.

M1 has scalar expressions, initialized let/var locals, and direct i32 functions.
Twelve native test groups and 143 CLI
cases passed in each of development and release using the M0 compiler artifact.
The corpus verifies arithmetic traps, malformed source/code, Fuel, Program reuse,
resource ceilings, local copy/assignment semantics, argument order, function/frame
isolation, bounded recursion, private call metadata, JSON/exit behavior, and tool-free
runtime PATH execution.
See [implemented subset](docs/engineering/m1-scalar-slice.md) and
[dated receipt](docs/evidence/m1-functions-windows-20261023.json). Branches/loops, Option/Result,
and their control-flow/ownership analysis are still pending. M0 was not
rerun for unchanged inputs. No new CI job or performance measurement was added.
M2 must cover arrays, structs, borrows, Buffer, input, output, and UTF-8.
M3 must use a fake in-memory typed host adapter without live keys or network services.
M4 requires real Windows AppContainer, Job, bounded IPC, I/O leases, and the broker
publication barrier. Compile untrusted source only inside the restricted worker.
M5 requires actual DLL export/call, clean-machine packaging, and full metrics.

## Review obligations

Three reviewed counterexamples must remain explicit acceptance tests:

1. Before cancellation, broker messages must obey the protocol phase. Reject the
   illegal sequence RESULT, HOST_REQUEST, exit 0, EOF. After cancellation, only
   bounded legitimate late messages may be drained, without adapter dispatch or
   output publication.
2. Structural depth, tagged wrapper depth, and total traversal budget are tested
   independently. A 16-level struct accepted alone must not become invalid only
   because it is wrapped twice in Option.
3. Buffer growth computes a rounded preferred candidate, then retries the minimum
   rounded requirement when that candidate exceeds any applicable reservation
   ceiling, while still reserving old plus new peak and owner metadata.

## Reporting and release

Every final report must list executed checks, actual results, skipped checks and
reasons, artifact/toolchain identity, and remaining risk. Acceptance of a design does
not mean implementation. Release evidence must be tied to the shipped binary and its
supported profile.

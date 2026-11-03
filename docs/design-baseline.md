# Design Baseline

- Status: Accepted for design, 2026-10-23
- Implementation status: Reconciled 2026-11-03; bounded M1 and public M2 subsets; private Buffer/returned-origin foundations; M3-M5 pending
- Provenance role: this file records the reviewed baseline; source material is not vendored

## Current reconciliation: 2026-11-03

M0 feasibility and the bounded M1 checkpoint have scoped native evidence. Public
M2 now includes arrays, nominal scalar/nested records, aggregate parameters/results,
fixed-array UTF-8 checks and shared/exclusive scalar-slice CALL arguments, including
ranges and temporary arrays. Returned signatures/body-origin analysis and Buffer
resources/leases/scanners are private foundations; guest Buffer and executable
returned borrows remain unavailable. M3-M5, full-profile conformance and performance
are not completed. Use the [remaining-work audit](product/04-remaining-work.md) and
[current roadmap](product/01-roadmap.md); the evidence sections below are historical.

## Baseline decisions

| Area | Accepted baseline |
| --- | --- |
| Language | Static typed, explicit Fairy-like syntax and a restricted source profile |
| Implementation | Fairy C parser, type/Flow analysis, verifier, and dispatch |
| Allowed shims | Small explicit allocator, scalar codec, and OS boundary only |
| Execution | JIT-free typed register bytecode VM |
| Memory | Ownership and whole-value moves; no guest GC or RC |
| First target | Windows x64 first, not a permanent all-platform exclusion |
| Program | Immutable and explicitly reusable |
| Instance | One-shot execution state |
| Engine | Owner-thread bound |
| Source form | .brc source only; bytecode is private, with no external bytecode or disk code cache |
| Build split | Go-based fairyc bootstrap does not imply Go in the produced Brownie VM |

Initial workloads are application data validation, byte transforms, and rule
evaluation. They are design assumptions, not a proven market requirement or a claim
that Brownie C replaces Python.

## M0 native implementation evidence

M0 is implemented in Fairy C under `probes/m0`. It provides checked signed i32/i64
and unsigned u8/u32/usize arithmetic in wide registers, with failures returned as
`Result`; exact 8-byte little-endian signed i64 and usize codecs; storage planning
and rollback; typed owners; and copied scalar frames.

Storage keeps the old and new capacities plus each owner's 64-byte logical charge during
rebuild, requests exactly the planned capacity from `Buffer.with_capacity`, and
retries the minimum 64-byte-rounded requirement when preferred 1.5-times growth
exceeds an object, Instance, or Engine limit. The owner fixture has four slots as an
M0 test bound, not a production capacity policy. Generation checks reject stale,
free, reused, and retired-maximum tokens before payload access.

The expanded Windows x64 run passed six native executions and four negative compiler
checks: `E1101` use after move, `E2101` grow with a live shared view, `E2102` local
view escape, and `E2101` exclusive alias. Exact evidence is in
`build/m0/receipt.json` and `docs/evidence/m0-windows-20261023.json`.

This does not implement `.brc` source parsing, a browniec CLI, the VM, a Windows
worker, or a DLL. Empty runtime `PATH` coverage does not prove packaging or isolation.

## Source provenance

The design review source is the external package brownie-c-design-v0.3.0 dated
2026-10-23. Its original ZIP SHA-256 is:

9786d2d2a0d0cd9048a47d17f6fd5c4574cdbcaeec00d17570602fa541b7dc5e

The source package contains 26 design documents, contracts, Python reference models,
29 .brc examples, and 32 acceptance cases. Its MANIFEST.json, contracts/README.md,
verification/REPORT.md, findings.json, and m0-not-executed.json own detailed external
metadata. Those files were reviewed read-only and are not imported into this repository.

The package cites Fairy C commit 4f779868 (2026-10-21) as a compatibility snapshot.
A later review inspection saw fairyc HEAD 0885e20b on 2026-10-23. The checkout moved
during review; neither hash is declared latest, permanent, or an adopted Brownie
toolchain baseline. Build adoption requires a dated artifact and compatibility record.

M0 later selected Fairy source `4ce1264273be6051ee560173e94690e1b99c9eaf`, SDK
`0.0.0-stage0.86`, and language `fairyc-language/20`, built on Windows x64 MSVC with
a compiler recorded as SHA-256
`572395f7f1e425d613c5a69f50b30ed177cda37ca2b1638bd0c11cf79fcbcc77`.
That is dated M0 identity. It is not a permanent pin; the harness validates the
requested checkout against the compiler build identity.

The adopted build baseline is now recorded in [toolchain.json](../toolchain.json):

| Identity | Adopted value |
| --- | --- |
| Fairy source | `eb274643bfcfe746617121ddc6f130b018978b53` |
| Compiler version | `v0.0.0-20261031093456-eb274643bfcf` |
| SDK | `0.0.0-stage0.87` |
| SDK source digest | `fysrc1-sha256-c531e88e52b684a34cf9688eda19e5cafcc5788e7a4bbf7e5121e86874a7246a` |
| Language | `fairyc-language/20` |
| Windows compiler SHA-256 | `9651623adbb6e05e0f948b826431853df310050387c955aee77ac0b12a81ab7a` |
| Linux compiler | Cross-build-only; no Brownie Linux execution claim |

These identities supersede the earlier build selection without rewriting M0
provenance. Pre-stable adoption still needs focused compatibility evidence; neither
the old package snapshot nor the adopted identity is a permanent freeze or a claim
about current upstream HEAD.

Historical Fairy language/adapter inspection did not establish a public Brownie C
export. Callable Fairy functions are insufficient: M5 must prove the actual DLL
export and C-host call on its adopted toolchain.

## Historical design-package evidence

The design package reported 746 checks passing locally on Windows with Python 3.14.6.
The checks covered documents, schemas, policy relationships, reference models, source
inventory, and package metadata.

C and C++ were unavailable, so header syntax and layout checks were skipped. This is
not a native header pass. The 29 .brc files and 32 source cases were recorded as not
executed. No Brownie parser, verifier, VM, allocator, Windows isolation, ABI, or
performance result follows from the package check.

The review reproduced the broker and layout findings in separate Python probes and
identified the Buffer growth fallback requirement. These are review
obligations and negative acceptance cases for the future implementation. They were
not repaired in imported production code because no source package code is imported.

## Historical design-review obligations

1. Broker phase validation

The model's BrokerTrace accepts RESULT, then HOST_REQUEST, then exit 0, then EOF,
and permits publication despite that illegal ordering. The production broker must reject illegal
pre-cancel phase messages. After cancellation, only bounded legitimate late messages
may be drained; they must never dispatch an adapter or publish output.

2. Separate layout budgets

The model mixes structural nesting and tagged-wrapper depth: a 16-level struct can be
accepted by itself but Option<Option<that struct>> is rejected. The implementation
must define and test plain-struct nesting, Option/Result wrapper depth, and total
traversal budget separately. This does not claim the source compiler reproduced it.

3. Buffer growth fallback

The candidate capacity is max(required capacity, 1.5 times current capacity), rounded
up to 64 bytes. If that preferred candidate exceeds any object, Instance, or Engine
reservation ceiling, retry the minimum rounded required capacity before declaring a
quota failure. Keep the old-plus-new peak and owner metadata reservations.

Example: old capacity 256, required 257, minimum 320, preferred 384, spare 352. The
minimum candidate fits and must be attempted. Allocator OOM remains a separate retry
decision. External effects never receive a silent automatic retry.

Current disposition: M0 storage checks now exercise the Buffer growth fallback and
ownership accounting, and the negative corpus exercises move and view rules. The
broker phase and separate layout budgets remain obligations for M4 and M1/M2. These
historical findings are retained as review context, not current implementation claims.

## Claim boundaries

M0 native arithmetic, codec, storage, allocator, owner, and frame primitives have
recorded Windows evidence. The bounded M1 checkpoint and scoped public M2
array/record/scalar-slice increments have their own historical native evidence;
full-profile VM/lifecycle/host behavior, Windows isolation, ABI, clean-machine
packaging, performance and broad security claims remain incomplete or unverified. The design package's
models are not production parsers, race-free native code, pointer-safety proofs, or
Windows scheduling evidence.

The initial performance budgets are unmeasured. Benchmark small real workloads first,
separate VM work from native-host offloading, and label build cache, binaries, process
RAM, VM ledgers, and startup independently.

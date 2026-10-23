# Design Baseline

- Status: Accepted for design, 2026-10-23
- Implementation status: M0 verified; first experimental M1 scalar source/VM slice verified
- Provenance role: this file records the reviewed baseline; source material is not vendored

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

Fairy C language document 0007 and ADR0481 state that the pub/callback adapter does
not export public C symbols. Brownie therefore has no approved generic C export today.
M0 inspected the Buffer and native primitive signatures used by its probes. It did
not establish a public C export; M5 must prove the final export and call.

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
recorded Windows evidence. The first M1 i32 expression pipeline also has native
execution evidence; full-profile VM behavior, Windows isolation, ABI, clean-machine
packaging, performance, and security claims remain unverified. The design package's
models are not production parsers, race-free native code, pointer-safety proofs, or
Windows scheduling evidence.

The initial performance budgets are unmeasured. Benchmark small real workloads first,
separate VM work from native-host offloading, and label build cache, binaries, process
RAM, VM ledgers, and startup independently.

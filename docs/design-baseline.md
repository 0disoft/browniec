# Design Baseline

- Status: Accepted for design, 2026-10-23
- Implementation status: absent
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

Fairy C language document 0007 and ADR0481 state that the pub/callback adapter does
not export public C symbols. Brownie therefore has no approved generic C export today.
M0 must inspect actual callable signatures, and M5 must prove the final export and call.

## Review evidence

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

## Required review findings

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

## Claim boundaries

All VM, native allocator, Windows isolation, ABI, performance, and security claims are
unverified. The design package's models are not production parsers, race-free native
code, pointer-safety proofs, or Windows scheduling evidence.

The initial performance budgets are unmeasured. Benchmark small real workloads first,
separate VM work from native-host offloading, and label build cache, binaries, process
RAM, VM ledgers, and startup independently.

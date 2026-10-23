# Roadmap

- Status: Accepted delivery sequence; M0 verified; M1 bool/branch, loop, tagged, propagation, switch-expression, and i64 slices verified, 2026-10-23
- Current progress: M0 and the named M1 slices passed; i64 records 49 native groups and 760 CLI cases in each profile; full M1 partial; M2-M5 not started

This roadmap orders learning and evidence. It is not a release promise. M0 has a
native harness and recorded evidence. The scalar CLI/VM now exist; the worker
and DLL do not.

## Guiding rules

Build the smallest real native path before expanding documents or platform support.
M0 and M1 must not wait for the Windows restricted worker or DLL milestones.

Every milestone must produce a runnable artifact, observed evidence, skipped checks,
and a short record of unresolved risk. A model or fixture does not satisfy a native gate.

## M0: native feasibility probes

Goal: prove that the smallest required Fairy native boundary is real and safe enough
to continue.

M0 now has Fairy C sources for checked signed i32/i64 and unsigned u8/u32/usize
arithmetic, exact 8-byte little-endian i64/usize codecs, storage planning and quota
rollback, typed owner generations, and scalar frame copies. The test allocator forces
the target allocator to return `NULL` and checks for leaked target allocations at exit.

The harness builds development and release variants and executes them with an empty
runtime `PATH` and cleared environment. The final expanded run passed six native
executions and four negative compiler checks: `E1101` use after move, `E2101` grow
with a live shared view, `E2102` local view escape, and `E2101` exclusive alias.
Exact inputs, outputs, and artifact identity are in `build/m0/receipt.json` and
`docs/evidence/m0-windows-20261023.json`.

M0 is native primitive evidence only. It does not implement `.brc` parsing, a VM, a
public CLI, a Windows worker, a DLL, or clean-machine packaging. An empty runtime
`PATH` is a harness condition, not proof of sandboxing.

Exit condition is met for the named scalar and storage boundary. M1 starts from an
unimplemented Brownie language pipeline.

## M1: scalar source to native VM

Status: partial. The first [scalar slice](../engineering/m1-scalar-slice.md) runs i32
expressions, initialized locals/assignment, and direct functions through the native
source pipeline. The [bool/branch slice](../engineering/m1-branches.md) adds canonical
bool values, short-circuit operators, if/else chains, standalone blocks, early
returns, typed var slots, forward-only jumps, and definite initialization at CFG
joins. Its [dated receipt](../evidence/m1-branches-windows-20261023.json) records 20
native groups and 248 CLI cases in each of development and release and remains
historical. The [loop slice](../engineering/m1-loops.md) adds `while`, classic `for`,
`break`/`continue`, and metered backedges. Its
[receipt](../evidence/m1-loops-windows-20261023.json) records 26 native groups and
332 CLI cases in each profile and remains historical. The
[tagged slice](../engineering/m1-tagged.md) adds shallow `Option<i32|bool>`,
`Result<i32|bool, i32|bool>`, and exhaustive `switch` statements. Its historical
[receipt](../evidence/m1-tagged-windows-20261023.json) records 33 native groups and
423 CLI cases in each profile. The [propagation slice](../engineering/m1-propagation.md)
adds postfix `?` for those wrappers, with payload success and enclosing-wrapper
failure. Its [receipt](../evidence/m1-propagation-windows-20261023.json)
uses 37 native groups and 510 CLI cases per profile;
verification passed and the receipt is now historical. The
[switch-expression slice](../engineering/m1-switch-expressions.md) adds exhaustive
expression-position arms, restricted value-arm statements, typed joins, and direct
returns. Its [receipt](../evidence/m1-switch-expressions-windows-20261023.json)
records 41 native groups and 580 CLI cases per profile and remains historical. The
[i64 slice](../engineering/m1-i64.md) adds checked full-width signed scalars in the
existing source positions. Its [receipt](../evidence/m1-i64-windows-20261023.json)
records 49 native groups and 760 CLI cases in each profile. Remaining M1 work
includes the remaining scalar types and richer value-arm statements.

Goal: run real .brc source through lexer, parser, type checking, Flow analysis,
private code generation, independent verification, and the native VM.

The first usable slice includes i32/i64/bool functions, branches, loops, shallow scalar
Option/Result, switch statements, question-mark propagation, checked arithmetic,
and bounded Fuel. It produces a small CLI path for local engineering use.

Exit condition: the same source and input produce the expected guest value through
the actual native binary. Guest nonzero is data. Compile or runtime failure returns
an explicit diagnostic and does not crash the host.

## M2: aggregates, borrows, and bytes

Status: not started. Goal: connect arrays, plain structs, borrows, Buffer, input,
output, and UTF-8.

Required evidence includes independent array copies, complete record construction,
root conflict rejection, mutable views, returned borrows, Buffer growth and movement,
staged output, and chunked UTF-8 validation.

Exit condition: source end-to-end cases exercise normal and rejected paths without
using a Python model as the product runtime.

## M3: typed host suspension

Status: not started. Goal: run a fake in-memory host adapter with request and reply,
grants, timeouts,
pending state, and cancellation.

No live service credential or network call is needed. Tests cover malformed replies,
allocation failure before copy, late replies, duplicate replies, Engine poisoning,
and terminal snapshot stability.

## M4: restricted Windows worker

Status: not started. Goal: compile and run untrusted source inside an independently
tested worker.

Use actual Windows AppContainer and Job controls, private bounded IPC, a parent
broker, I/O leases, a publication barrier, and bounded cleanup. Preparation failure
must stop; it must not fall back to an unrestricted process.

Required negative cases include cancellation before late RESULT delivery, HOST_REQUEST
after cancellation, exit/EOF ordering, pending I/O completion, and output rejection.

## M5: embed and clean-machine delivery

Status: not started. Goal: expose the planned DLL ABI to a trusted native host and
verify packaging.

The milestone must prove actual symbol export and calls, public handle validation,
clean-machine execution without developer compilers, and full startup, allocation,
latency, and artifact measurements. The current Fairy pub path is not a public C export.

## First workload experiments

Before fixing performance targets, benchmark small data validation, byte transform,
and rule-evaluation workloads. Report reuse separately from cold compile, process
startup, host serialization, and build-cache cost.

Initial unmeasured targets are:

- reused small Instance setup p95 at or below 1 ms;
- 10 KiB pure compile plus verify p95 at or below 10 ms;
- empty Instance accounted memory at or below 32 KiB;
- zero heap allocation in a warm scalar loop;
- 100 retained edit builds at or below 32 MiB for project outputs.

These targets guide measurement; they are not current results or universal guarantees.

## Stop or revise

Narrow or stop a milestone if the native boundary cannot return failures without a
trap, a stale token can be dereferenced, quotas cannot be reserved before allocation,
cancellation can publish output, or the worker cannot be isolated on the actual OS.

Do not trade away these boundaries to meet a performance target or schedule.

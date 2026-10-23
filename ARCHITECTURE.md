# Architecture

- Status: accepted design baseline
- Decision date: 2026-10-23
- Implementation: M0 verified; experimental M1 scalar pipeline and VM implemented; bool/branch, loop, and tagged slices historically verified; scalar `?` propagation historically verified; switch expressions verified

## Intent

Brownie C separates source semantics, private typed bytecode, execution state, and
host capabilities. The architecture should make the valid execution path small and
make trust crossings explicit.

The system is not a C interpreter and does not expose C memory layout to source.
Its explicit Fairy-like syntax is its own safe profile.

The implemented [M1 scalar slice](docs/engineering/m1-scalar-slice.md) runs real `.brc`
expressions through lexing/parsing, i32/bool type checks, private IR, verifier, and
VM. Immutable parameters and `let` names use single-definition registers; `var`
names use typed storage slots in the same bounded register file. Structured if/else
and standalone blocks lower to forward-only jumps, and short-circuit operators skip
their right operand. `while` and classic `for` add a control head, a forward exit
branch, and metered backward edges. The verifier intersects definite initialization
on the forward graph and checks each backedge against its target's first-entry
invariant; it does not solve a cyclic fixed point or prove termination. For return
completeness, the compiler conservatively treats every loop as possibly zero-trip,
so a following function return remains required. Direct calls use verified function
ranges and bounded VM frames. The loop slice is verified
by the [loop receipt](docs/evidence/m1-loops-windows-20261023.json), which remains
historical after the tagged increment. A shallow Option/Result occupies one i64
cell with a packed scalar payload and variant; exhaustive `switch` lowers to `CASE`
tests, normal arm joins, and an internal unreachable `MATCH_FAIL` fallback. The
verifier tracks both paths and defines the payload only on a match. It checks
wrapper type/variant agreement without a separate tag array. The tagged slice remains
verified by its [historical receipt](docs/evidence/m1-tagged-windows-20261023.json).
Postfix `?` reuses `CASE` and `JUMP` on success; a mismatch enters a second
`CASE`, builds the enclosing function's declared `Option`/`Result` with `MAKE`,
and returns, with the negative CASE path targeting `MATCH_FAIL`. The compiler keeps
that function return type separate from the expected type of the surrounding
expression. Propagation is implemented for shallow scalar wrappers and its receipt
is historical after the switch-expression increment. A switch expression reuses
the same exhaustive `CASE` dispatch. Each value arm stores its final result into one
lazy typed join slot and jumps forward to a shared `LOAD`; direct-return arms emit
their function return and do not join. A final variant mismatch targets
`MATCH_FAIL`, and the existing verifier proves the join slot is initialized before
`LOAD`. No VM opcode or guest heap allocation is added. The current switch-expression
[receipt](docs/evidence/m1-switch-expressions-windows-20261023.json) records 41
native groups and 580 CLI cases in each profile. Ownership, lifecycle APIs, Engine, host calls, workers, and DLLs
remain designs; full M1, richer value-arm statements, and other scalar types remain
unverified or unimplemented. M0
separately exercises native arithmetic, codec, storage, allocator, owner, and frame
primitives.

## Main path

The intended pipeline is:

1. Read a bounded UTF-8 source snapshot.
2. Parse and resolve the explicit module graph.
3. Type check and compute ownership, loan, and return-origin facts.
4. Emit private typed register bytecode and transfer templates.
5. Verify structure, control flow, layout, registers, ownership, and metering.
6. Create an immutable Program.
7. Create a one-shot Instance with explicit input, grants, and limits.
8. Step the VM with bounded work until completion, host suspension, or termination.

Source, compiler, verifier, VM, and simple platform shims are primarily Fairy C.
Allocator, scalar codec, and OS access may use narrow shims with recorded preconditions.
M0 implements the first allocator and scalar checks in Fairy C and a test-only C
allocator header; it does not make the pipeline below executable.

## Ownership model

- Program owns immutable code, constants, layouts, source maps, and catalog bindings.
- Engine owns compile state and coordinates instances on one owner thread.
- Instance owns frames, input, owners, loans, pending work, grants, and staged output.
- Buffer owns fallible dynamic bytes and moves as one value.
- Guest references use opaque typed tokens and descriptor ledgers, never native pointers.

Program reuse is explicit. There is no runtime Program cache. Bytecode is private
and cannot be loaded from disk or supplied by a caller. Guest recursion uses VM
frames and never the Fairy native call stack.

## Host boundary

The VM does not call host callbacks directly. Guest host operations suspend through
typed request and reply records. Reachable requirements must fit declared
requirements, run grants, and the Engine policy ceiling.

The core embed path is for trusted native hosts in the same process. Arbitrary
external source belongs in a restricted process with AppContainer access limits,
Job resource limits, a bounded parent broker, and independently verified Windows
IPC. Preparation failure must not fall back to an unrestricted child.

The ABI is planned, not present. Current Fairy C documentation states that its
pub/callback adapter does not export public C symbols. An actual DLL export and call
belong to the embed milestone.

## Failure and publication

Guest arithmetic, quota, cancellation, and deadline failures are explicit Instance
outcomes. A guest i32 return is data, not the Brownie CLI process exit code.
Output remains staged until successful completion and publication checks.

Internal ownership or ledger invariant failures poison the Engine. Detected native
memory corruption is not proven recoverable in process; restricted execution contains
it at the worker boundary.

## Change impact

Changing source semantics requires corpus review. Changing value layout requires
updates to compiler, verifier, VM, and independent expected vectors. Changing the
host boundary requires caller, capability, cancellation, and packaging review.

Detailed decisions live in docs/adr/. Product behavior lives in
docs/product/02-spec.md. Validation evidence rules live in VALIDATION.md.

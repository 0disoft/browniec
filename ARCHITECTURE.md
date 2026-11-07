# Architecture

- Status: accepted design baseline
- Decision date: 2026-10-23
- Implementation: Reconciled 2026-11-03; native scalar/array/record/scalar-slice subsets; private Buffer/return-origin foundations; M3-M5 pending

## Intent

Brownie C separates source semantics, private typed bytecode, execution state, and
host capabilities. The architecture should make the valid execution path small and
make trust crossings explicit.

The system is not a C interpreter and does not expose C memory layout to source.
Its explicit Fairy-like syntax is its own safe profile.

## Current implementation boundary

The public native frontend/verifier/VM also handles six-scalar arrays, nominal
scalar/nested records, aggregate parameters/results, shared/exclusive scalar slices
and whole/ranged/temporary CALL borrows. Private Buffer resources/leases/UTF-8
sessions and returned-origin analysis are foundations; guest Buffer and actual
returned references remain unavailable. The
[remaining-work audit](docs/product/04-remaining-work.md) owns the complete gap list.

The scalar foundation below explains the M1 checkpoint. Its dated receipts remain
historical; later M2 contracts extend the implementation. The ownership/lifecycle/
host/publication sections describe the target where not specifically implemented.

The implemented [M1 scalar slice](docs/engineering/m1-scalar-slice.md) runs real `.brc`
expressions through lexing/parsing, i32/i64/u8/u32/usize/bool type checks, private IR, verifier,
and VM. Immutable parameters and `let` names use single-definition registers; `var`
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
`LOAD`. The switch-expression receipt remains historical at 41 native groups and
580 CLI cases. The i64 increment uses scalar tag 9, checked arithmetic, and the
existing i64 constants and register cells; it adds no opcode, guest heap allocation,
or Fuel policy. Its [receipt](docs/evidence/m1-i64-windows-20261023.json) is
historical and records 49 native groups and 760 CLI cases in each development and
release profile. The unsigned increment adds `u8` tag 10, `u32` tag 11, and 64-bit
guest `usize` tag 12. It retains the existing `i64[128]` constant and `i64[4096]`
VM register arrays. `src/cells.fy` stores values below 2^63 unchanged and the upper
half as negative bit patterns through checked conversions split at 2^63.
`src/arithmetic.fy` applies the M0 unsigned guards before native operations. The
unsigned slice added no opcode, guest heap allocation, frame, cap, or Fuel change. Its
development and release runs each passed 59 native groups and 1,159 CLI cases,
recorded in the [unsigned receipt](docs/evidence/m1-unsigned-windows-20261023.json).
The explicit widening increment adds opcode 26, `WIDEN`. The destination is a new
value register whose type metadata holds the target tag; operand A is the source
register index, and operand B and every reserved byte are zero. Compiler and
verifier enforce the same seven domain-preserving integer pairs.
The verifier additionally requires a readable initialized non-slot source in the
same function and a unique destination. The VM copies the encoded i64 cell, which
already represents every admitted source domain. Each executed cast costs one Fuel
and consumes one instruction and one value register; casts are not elided. It
adds no guest heap or frame growth and keeps existing caps. The
[widening receipt](docs/evidence/m1-widening-windows-20261023.json) records
67 native groups and 1,272 CLI cases in each development and release profile.
The [integer-operator increment](docs/engineering/m1-integer-operators.md) adds
opcodes 27 through 32 for complement, bitwise AND/XOR/OR, and checked left/right
shift. Unsigned bit patterns, explicit i32 sign extension, count checks, and
prechecked left-shift ranges avoid host signed shifts and overflow. Signed right
shift uses explicit sign fill. Every operation costs one Fuel and keeps the
existing register and frame bounds.
The [integer-operator receipt](docs/evidence/m1-integer-operators-windows-20261023.json)
records 75 native groups and 1,898 CLI cases in each development and release profile.
The [arm-statement increment](docs/engineering/m1-switch-arm-statements.md) reuses
the statement compiler in value arms, threading structural/expression depth and
the active loop state through all expression calls. Terminal return/break/continue
paths bypass the typed value join. While conditions enter their own loop before
compilation so their transfers target that loop. No opcode or VM change is added.
The [arm-statement receipt](docs/evidence/m1-switch-arm-statements-windows-20261023.json)
records 81 native groups and 1,969 CLI cases in each development and release profile.
The bounded scalar M1 checkpoint is verified and public M2 arrays, records and
scalar slices extend it. Full-profile ownership/lifecycle, Engine/host APIs,
worker, DLL, clean-machine delivery and performance remain incomplete or unverified.
M0 separately exercises native arithmetic, codec, storage, allocator, owner and
frame primitives.

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
M0 implements separate allocator/scalar probes and a test-only C allocator header.
The narrow single-source pipeline is executable; explicit module/project/authority,
Instance stepping, host suspension and publication above are target integration.

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

The [Windows ABI bootstrap](docs/engineering/abi-bootstrap.md) now exports a real
`bc_get_abi_info_v2` query with Fairy-compiled validation/metadata and a small native
layout shim. Actual C-host calls, C/C++ layout checks and output boundaries are
verified for that query. Engine/Program/Instance/handle/VM exports, full E01 and
embedding availability remain incomplete; the CLI keeps embed=false. Historical
Fairy pub/callback visibility alone is still not Brownie export evidence. The
adopted toolchain remains recorded in `toolchain.json`.

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

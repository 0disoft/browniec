# Private native typed-value execution

The [predicate successor](value-predicates.md) now adds non-consuming typed
Option/Result inspection through TAG_TEST98, including move-only Buffer wrappers.
Propagation, must-use, typed value-expression joins, loops and public integration
remain separate work.

`vm::run_values` connects independently verified [typed IR](value-ir.md) to the
[native value frames](value-frames.md), Buffer roots and existing ordinary VM
loop. It is a private native integration entry, not guest syntax, external
bytecode loading, an Engine/Instance API or a public capability.

## Retained admission and invocation state

`value_program::Program` is a single-owned resource with private fields. Retention
re-runs complete scalar, aggregate, loan, selected-place and exact initialized/
Dead value analysis, derives an immutable frame layout, and copies the admitted
code and reborrow forest. Getters provide only immutable borrows. Changing or
destroying the candidate cannot change the retained executable snapshot. Failed
analysis preserves the original diagnostic kind and offset.

The retained resource owns one heap snapshot behind a reserved single-element
vector. Large code/layout values no longer travel through every owning Program
return. This replaces the development build's overflowing by-value retention
path; it does not increase the native stack, weaken verification or change the
getter API. Allocation failure reports the existing allocation error kind15.
Fallible slot derivation also runs outside the owning layout's scope, avoiding
repeated large cleanup temporaries on its error exits. In diagnostic MSVC 19.51
`/Od` listings, `value_frame_layout::retain` allocates 185864 stack bytes versus
333192 before that split: 147328 bytes (44.2 percent) less. The same diagnostic
retention path's summed allocations decrease from 742312 to 594984 bytes. These
are emitted frame allocations, not a whole-invocation bound or RAM benchmark.
The original combined VM tag regression stays combined without a stack override.

One invocation keeps that exact Program together with its fresh frame State,
root State, value backing, reusable staging and two owning root vectors. These
native records are not guest handles; a caller must not transplant or restore
their parts. Ordinary scalar/array/record/loan/place storage stays in its existing
domain. Legacy entry points pass empty typed vectors and allocate no typed
backing. Ordinary, image and returned-reference admissions keep their own gates.

MOVE88, COPY89, DROP90, TAG_BUILD91, CASE92, EMPTY_BUFFER95, SCALAR_READ96 and
SCALAR_VALUE97 execute through the checked frame primitives. CASE uses its exact
forward mismatch PC. Matching move-only wrappers are consumed even for an
inactive or scalar alternative. Failed matches preserve the wrapper. Scalar
register indices and typed slot IDs remain different namespaces.

## CALL and RETURN publication

CALL93 can mix typed arguments with ordinary scalar, array, record and borrowed
arguments. Typed actuals encode `208 + slot`; typed formals reserve ordinary
argument positions but never read or publish scalar cells. The callee has a
fresh activation generation even for recursive calls. Ordinary CALL9 inside a
typed invocation also enters an empty typed activation.

Before any typed source moves, `value_call_vm` checks the complete map, exact
types, actual initialized masks, Dead formals, native backing/root bindings and
staging. It simulates arguments in source order: repeated move-only actuals
reject; repeated whole-type-copyable actuals are allowed. A typed result
destination must be Dead after argument consumption, so it may reuse a consumed
actual. All typed charges and the ordinary CALL charge are admitted before frame
allocation and argument inspection.

The ordinary CALL transaction then completes its full scalar/aggregate/loan
preflight and publication. Only after success does typed publication perform the
prechecked transfers, using reserved staging and prepaid Fuel. There is no guest
callback, reentry or typed/root mutation between preparation and publication.
Failed ordinary admission moves no typed actual; invocation failure drains the
empty callee and remaining native roots. Existing canonical transactions retain
exclusive-parent suspension/restoration and owned-argument copy semantics.

A typed result records return destination `208 + slot`. RETURN94 requires the
sole live callee slot, the function's exact result type, a Dead parent destination
and authenticated root/backing. It prepays inspection and transfer, closes the
ordinary callee, publishes the value handoff, releases the empty typed activation
and restores the parent PC. Scalar, void, array and record returns also release
their matching typed activation. Entry still returns an ordinary i32.

## Fuel, quotas and terminal cleanup

Existing ordinary opcode prices, public default256 and cap16000000 do not change.
This private route adds an explicit controller charge of 65536 logical bytes and
65536 Fuel, plus the existing root/frame setup and entry templates. This is a
policy allowance, not native `sizeof`, allocator overhead or measured process RAM.
Ordinary aggregate backing counts at its admitted arena extent. The remaining
instance/Engine allowance is shared by native frames, scratch and root usage;
the per-Buffer object limit keeps its existing meaning.

CALL prepays frame entry, an 8192 inspection allowance and twice the operation
template for each typed argument, alongside its unchanged ordinary CALL charge.
RETURN prepays 8192 plus twice the returned value's operation template. One copy
of each template covers pure inspection and the other publication. This private
schedule is not a public source cost promise.

Every terminal execution outcome reaches native frame/root abort, including
zero-Fuel failures with live wrapper-owned roots. Cleanup uses owning vectors and
native ledgers rather than guest bytes or masks. It preserves the original
execution error; a cleanup error replaces only a successful outcome. Normal
frame exit and failure draining require no additional guest Fuel. Ordinary
place abort and canonical owner/loan cleanup keep their existing outer ordering.

## Verification scope

`python -B tools/verify-value-execution.py --profile development --public-fuel-cli`
and the release counterpart use fresh locked, byte-identical production mirrors
with only the selected test modules. The runner discovers exact native identities,
checks report profile/lock/streams, and hashes inputs, commands, outputs and CLI
artifacts. The optional public Fuel phase runs the existing 105 CLI boundary
cases with a tool-free runtime PATH. It uses no native override or old result.

Windows development and release each passed 26 native groups (14 new and 12
regression) and 105 CLI cases on implementation `d025c6f`. All 210 inputs match
checkout bytes and Git canonical bytes. Of these, 208 match Git raw bytes;
two unchanged historical test modules use checkout CRLF versus Git LF. All 190
production modules match Git raw bytes and are LF. Native mirrors preserve exact
checkout bytes; no LF runtime-mirror pass is implied. The static inventory is
319 test files / 1887 annotations. See the
[Windows evidence](../evidence/value-execution-windows-20261107.json) and
[input manifest](../evidence/value-execution-inputs-windows-20261107.json).

The [source foundation](value-source.md) now provides canonical type/signature
parsing and lexical COPY/MOVE/DROP preparation. Executable Buffer/wider-wrapper
body lowering now has a [private successor](value-body.md) for empty Buffer/nested
wrapper constructors, immutable locals and mixed CALL/RETURN. The
[control successor](value-control.md) adds mutable assignment and statement joins.
Typed value-expression joins, loops, wider operations and public promotion remain next. Full L04/L05/D01-D04, Engine/Instance/host/isolation/platform/delivery,
the complete language/native Fuel matrices, Linux, LF runtime mirrors, OOM,
general stack containment and performance remain separate work.

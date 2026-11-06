# Independent owned-array place IR analysis

Date: 2026-11-06. Successor to the
[native scalar-location prerequisite](array-selected-place.md). This increment
proves private IR; executable admission stays gated until dispatch integration.

## Instructions and namespaces

The existing eight-byte encoding gains four private analysis operations. Bytes
4..7 remain zero, and array IDs must belong to the containing function.

| Opcode | Operation | Operands |
| --- | --- | --- |
| 83 | SELECT_PLACE | dst=place ID, a=owned array ID, b=defined usize index |
| 84 | PLACE_READ | dst=fresh exact scalar, a=place ID, b=array ID |
| 85 | PLACE_STORE | dst=place ID, a=array ID, b=defined exact scalar |
| 86 | END_PLACE | dst=place ID, a=b=0 |

Each frame has a separate sixteen-ID place namespace. SELECT/STORE/END allocate
no guest value register. The repeated array operands on READ/STORE are independently
checked against the actual SELECT; they are not authority supplied by a builder.
Builder success never substitutes for admission. Sequential statements may reuse
an ended ID and are not limited to sixteen SELECT instruction sites.

## Complete analysis path

`verifier::inspect` and `inspect_reborrow_calls` combine the existing canonical
scalar/type/owner/loan graph with `place_ir::step` and the independent place graph.
SELECT requires a live mutable unborrowed owned array and a defined usize value.
READ defines a fresh scalar of the exact element type; STORE requires a defined
matching scalar and current writable ownership. Index words cannot be slots,
aggregate parameters or slice descriptors. Bounds remain a runtime obligation.

The separate graph reconstructs the selecting PC and one of four phases for each
place: dead, selected, old scalar read, or stored. Optional READ occurs once before
STORE; STORE occurs at most once. END can abandon a selected place on a normal
nonlocal-exit path or finish a committed one. It cannot end a dead place.
Re-selecting a live ID, using another root, repeated READ/STORE, READ after STORE,
owner DROP before END, or a normal return with an active place fails admission.
An abort instruction uses the existing runtime failure-cleanup rule instead.

Forward joins and backedges require identical selecting PCs and phases. A common
selection may survive an RHS branch or loop; a loop may also select/end once per
iteration. Different branch-local selections cannot be merged merely because
they happen to use the same root, index register or place ID. Recursive functions
have separate place graphs even when both use ID zero. Unreachable place
instructions still receive structural/index/type/reserved-byte checks.

This is scalar replacement, with a separately evaluated scalar operand and no
source-region memcpy. Multiple pending scalar locations may alias; their ordered
stores do not transfer or copy owner storage. Generic aggregate selected-place
assignment and its copy-overlap proof remain separate work.

The graph stores 4096 one-byte SELECT origins, 256 phase words and 256 seen flags
per analyzed function. SELECT PC+1 fits a byte because SELECT must have a following
instruction. The graph helper is called only when place instructions are present;
pre-existing programs do not acquire its stack frame or a larger Program layout.
All existing source/register/function/frame/arena bounds remain unchanged.

## Execution boundary and remaining work

`verifier::verify_sites`, executable Static/returned-reference admission and the
ordinary VM reject these operations before Fuel/backing allocation. No public
syntax/capability or runtime operation price changes here. Analysis acceptance
must not be described as runtime execution, dynamic owner pinning, or a Fuel pass.

Next: frame-local snapshots across ordinary and retained CALL/RETURN, precharged
selection/read/store/end work, runtime identity/extent/generation checks, terminal
cleanup and exact Fuel boundaries. Then connect ordered source assignment and
compound operators, exclusive slice/record/scalar-local places and grouped lvalues.
Returned-view dependency guards and recipe scalar-use analysis must recognize the
new operations before executable retained admission is promoted.

Run `python -B tools/verify-static-execution.py --profile development
--selection array-place-ir`, then repeat for release. It selects the new proof
suite and the complete existing array-IR and void-execution suites. See
[Windows evidence](../evidence/array-place-ir-windows-20261106.json).

Windows development and release each passed **16 native groups**: eight new
place-proof groups, five existing array-IR groups and three void-execution groups.
Both profiles used the same 169 input hashes, 162 LF production modules and
280-file discovery; both locked LF mirrors passed. All executed input hashes
match the staged Git blobs. Forty-one unselected discovery fixtures differ from
Git only by CRLF/LF, with both hashes retained separately.

The final checks include all six scalar domains, malformed operands/reserved
bytes, future scalar use, repeated or missing phases, owner DROP/return, exact
join/backedge identity, frame separation, all sixteen live IDs, forty selections
with ID reuse, selecting PC 254, unreachable mutation and rejection before
runtime Fuel/backing preparation. Existing void execution still passes its
ordinary/retained exact Fuel boundaries and full 128-register case.
An initial development run found a bool fixture using the integer-only builder;
it was corrected to use the bool builder before both final fresh runs.

No public CLI/full language/Fuel matrix, Linux, OOM injection, general stack or
performance characterization, worker isolation or delivery checks were rerun.
No VM execution of the new operations or complete L04 implementation is claimed.

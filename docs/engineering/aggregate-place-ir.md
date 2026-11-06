# Independent aggregate-place IR proof

The [execution successor](aggregate-place-execution.md) now connects complete
aggregate-place admission, both drivers and retained dependency/scalar-use guards.
The [metered native successor](aggregate-place-vm.md) supplies invocation snapshots
and all five final stores. Execution gates below describe this analysis-only
checkpoint; ordered guest source lowering remains next.

Date: 2026-11-06. Analysis successor to the
[native destination snapshots](aggregate-selected-place.md) and
[copy-strategy proof](aggregate-copy-ir.md).

## Complete assignment operand forms

The existing eight-byte encoding gains analysis-only place kinds 3 (whole scalar
array) and 4 (nominal record subtree), and `PLACE_REPLACE` opcode 87. Place IDs
share the existing sixteen-entry frame-local namespace. They are never scalar
registers, owners or source values. Aggregate READ is forbidden.

| Operation | Ordinary operands | Remaining bytes |
| --- | --- | --- |
| SELECT83, kind3 | dst=place, a=array root, b=0 | byte4=3; bytes5..7=0 |
| SELECT83, kind4 | dst=place, a=record site, b=nominal | byte4=4; byte5=target first scalar ordinal; bytes6..7=0 |
| STORE85, kind3 | dst=place, a=array root, b=source array | byte4=3; bytes5..7=0 |
| STORE85, kind4 | dst=place, a=record site, b=source record site | byte4=4; byte5=target ordinal; byte6=nominal; byte7=source ordinal |
| REPLACE87, array fill | dst=place, a=array root, b=scalar | byte4=3; bytes5..7=0 |
| REPLACE87, array list | dst=place, a=array root, b=pool start low byte | byte4=3; byte5=1; byte6=pool start high byte; byte7=0 |
| REPLACE87, record constructor | dst=place, a=record site, b=first scalar | byte4=4; byte5=target ordinal; byte6=nominal; byte7=0 |
| END86 | dst=place, a=b=0 | bytes4..7=0, shared with every existing place kind |

Array-list spans use the original dense 4096-entry scalar-register operand pool.
Their exact length comes from the destination catalog. Canonical pool analysis
reconstructs one dense nonoverlapping source-ordered sequence across old LIST80,
REPLACE_LIST81 and new list REPLACE87 instructions. Gaps, overlaps, forged starts,
unclaimed pool entries and nonzero unused tails fail admission. The existing list
builder validates inputs and reserves the pool once, then the new builder encodes
that actual span. No second pool or guest allocation is introduced.

Record constructor replacement reads the complete selected nominal subtree's
ordered scalar leaves from existing consecutive value registers. All tags and
scalar roles are independently rechecked against the prepared root catalog;
slots, aggregate/formal markers and future or foreign scalar definitions fail.
SELECT, STORE, REPLACE and END define no scalar register. A full 128-register
constructor therefore needs no extra register for its pending destination.

## Structural and lifetime composition

`aggregate_place_ir` derives exact shapes and copy strategies through the shared
`copy_ir` operand proof. Both source and destination belong to the current
function. Nominal identity cannot be replaced by structural/physical similarity;
each subtree's first ordinal must resolve to that exact nominal node. Arrays
retain exact scalar tag/length. Array self-copy is only an identity candidate;
record self-copy retains a canonical snapshot. Native storage must still prove
actual token generations and physical backing windows before execution.

Canonical reachable scalar/owner/loan CFG checks require a live mutable
destination without active array loans. Source owners must be live; shared array
source loans remain readable, exclusive source loans do not. Fill/list/constructor
operands must be defined exact scalar values at the instruction. These stores
preserve the owner live set and all scalar definitions. CALLs and ordinary result
definitions retain their existing complete proof.

The independent common place graph records selecting PC and phase, not a
compiler claim or repeated root operand. STORE and REPLACE must repeat the exact
selected kind/root and, for records, nominal and destination ordinal. Each pending
place may store once; reselecting a live ID, READ, double store, dead use or END,
and dropping its root before END fail. END may abandon a selected destination on
normal nonlocal cleanup. Normal returns require no pending places. Abort uses
the existing terminal cleanup contract.

Forward joins and backedges compare exact selecting PCs and phases. Equal root
IDs or equal shapes cannot merge independently selected branch locations. A
common selection may span an RHS branch/CALL; a loop may select/store/end each
iteration. Each function has its own graph, including recursive CALLs with the
same place ID. Scalar-array, exclusive-slice, record-scalar and aggregate locations
share IDs while retaining distinct root namespaces and root-drop obligations.

The graph retains its existing 4096 origin bytes, 256 phase words and 256 seen
flags per analyzed function. SELECT PC+1 still fits one byte; SELECT must have a
following instruction. No Program field, scalar register, owner, pool bound,
function/frame limit or unconditional metadata allocation is added.

## Analysis entry and executable gates

`verifier::inspect_aggregate_places` combines the canonical whole-Program catalog,
function partition, scalar/owner/loan/CALL proof with aggregate kind/operand checks
and the independent place graph. Builder success and isolated graph inspection
never grant executable authority. Metadata checks also apply to place instructions
visited by independent graph inspection, including unreachable locations.

Every existing ordinary/image/returned-reference admission path retains its
maximum executable place kind of 2. The original native array/slice/record
adapters reject kinds 3/4 before snapshot preparation or operation charging.
Ordinary `vm::run` rejects them as invalid IR even with zero Fuel; its Fuel/backing
entry work does not begin. Static/returned-reference recipe admission also keeps
its existing dialect gates. Both actual VM drivers still require subsequent
metered aggregate snapshot/dispatch integration, retained dependency guards and
source lowering. No public syntax, capability, price/default256/cap16000000 or
execution claim changes at this analysis checkpoint.

## Verification and next integration

Run `python -B tools/verify-aggregate-place-ir.py --profile development` and repeat
for release. `--batch core` selects eight new proof/gate groups; `--batch regression`
selects seven existing scalar-array, exclusive-slice, record and list groups.
The full fifteen-group selection includes actual legacy list/record execution
and exact Fuel, plus the complete new five-form analysis and refusal boundaries.

Next, connect metered native invocation snapshots and all five final-store forms
to both VM drivers and retained guards, then emit the new ordered source lowering
with existing nonlocal cleanup. Resource/tag move rules, full L04/C05 and
Engine/Instance/host/isolation/delivery remain open. Full language/native Fuel,
LF mirrors, Linux, OOM injection and general stack/performance or clean-machine
delivery are outside this focused selection.

Windows development/release each passed **15 native identities and 105 tool-free
public Fuel CLI cases** on the same production inputs at `2d36f3f`. The final
196-path union matches checkout and Git raw bytes; all 175 production modules
are LF, with 302-file/1808-test discovery. Development retains thirteen unchanged
same-turn cases and reruns two affected cases. The initial report had fourteen
passes and one failure: a truncated abort fixture retained an old kind tail and
an unused register declaration. The fixture now clears both; the two reruns also
cover equal-byte distinct nominal identities and mixed aggregate IDs. Only the
core test file and native runner selector changed after the initial run, with
both hashes recorded. Release runs all fifteen groups fresh. No historical
result or compiler/linker/stack override was used. See
[Windows evidence](../evidence/aggregate-place-ir-windows-20261106.json).

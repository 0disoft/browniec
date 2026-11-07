# Resumable record creation, copy and replacement

Implementation: `0a73d08` (2026-11-08). Windows development/O2 each pass five
kernel/five Engine groups plus existing regressions, with default stacks and
zero SDK heap at exit. The
[Windows evidence](../evidence/runtime-record-chunks-windows-20261108.json)
records commands and exact source/artifact identities.

## Operations and selected places

The [record bridge](../../src/struct_work_execution.fy) routes six record operations
through [struct_work](../../src/struct_work.fy):

| Opcode | Operation | Input | Destination |
| --- | --- | --- | --- |
| 41 | CREATE | Scalar field cells | New whole record owner |
| 42 | COPY | Existing whole record | New whole record owner |
| 46 | ASSIGN | Existing whole record | Existing whole record |
| 47 | Child COPY | Nominal source subtree | Nominal target subtree |
| 48 | REPLACE | Scalar field cells | Existing whole record |
| 49 | Child REPLACE | Scalar field cells | Nominal target subtree |

Whole operations require ordinal zero and exact root nominal identity; equal
physical layouts do not establish nominal compatibility. Child operations resolve
both applicable ranges through `struct_range::offset_prepared` against the checked
catalog plan. Root and selected subtree extents are each bounded by 128 bytes.

Actual selected STORE85 with record kind 4 normalizes to recipe 47; selected
REPLACE87 with record kind 4 normalizes to 49. The saved PC still identifies the
original selected instruction. The parent retains the SELECT snapshot, root token,
ordinal, ticket and selected-place price, reauthenticates them on every advance,
and consumes the selection only on completion. The later END clears it.

## One complete canonical admission unit

`measure(catalog, nominal, fields)` reads metadata only. Let S be the selected
record size including padding, L its depth-first scalar leaf count, B the sum of
scalar widths, and Q the number of bool leaves:

- Field construction/replacement costs `S + 8*L + B`, at most 1280 bytes.
- Source copy/assignment costs `S + B + Q`, at most 384 bytes.

S accounts for zeroing exact-size encoded scratch. Each field cell read counts
eight bytes, encoding counts its scalar width, and a scalar snapshot transfer
counts once for its read/write pair. Each bool validation read counts separately.
The shared iterator proves `Q <= L <= B <= S <= 128` for accepted records.

The parent requires the WHOLE admission measure to fit the remaining allowance
`4096 - array.last - output.last` before calling `begin`. Otherwise it returns
Pending at the same PC without charging an instruction unit or Fuel, and without
staging or destination writes. The canonical admission unit is never split.
The byte allowance is shared with array fills, copies, element lists and output.

`begin` fully stages canonical bytes in the existing shared recipe. Field input
is encoded through `encode_into`; copy input uses `snapshot_into` and requires an
empty fields slice. Both zero the exact selected scratch before populating scalar
bytes. Invalid field values or source bools fail before any destination byte,
including allocation padding, is touched. No owner or arena prefix is published.

Source padding is never read into the snapshot. Exact source/target identity
still writes normalized padding and never becomes a NoOp. A complete disjoint
scratch snapshot also permits legal overlapping source/target windows; later
chunks read only this snapshot, never a partly overwritten source.

## Shared state and bounded destination writes

[array_fill_cursor::State](../../src/array_fill_cursor.fy) appends five `usize`
words: `record`, `nominal`, `ordinal`, `source_record`, `source_ordinal`, plus
`u8[128] record_encoded`. All start at zero. Existing `encoded[8]` and other
fields keep their meanings for existing recipes. Both native profiles measure
State at 360 bytes (+168), Cursor 432 (+168), Machine 880 (+168), and unchanged
Core 120880. Vec8 work adds 2880 bytes (+1344); existing native layout accounting
charges this storage before allocation.
There is no additional persistent cursor, heap buffer or backing bank.

For record recipes, `base/end/mark/length/stride` retain the target ROOT extent,
allocation mark, byte size and alignment. Slot, generation and table depth are
captured. Source fields retain the source token, ROOT nominal and ROOT extent;
ordinals identify selected subtrees without replacing root metadata.

On admission, `written=0` and `total=last=measure`. The parent carries previous
instruction counters into the installed recipe and resets `last` once per batch.
`advance` copies only allocation padding and selected canonical bytes, bounded by
its allowance. `written` counts final destination bytes; `total/last` additionally
include admission. Total recipe work is admission plus S and, for 41/42 only,
alignment padding. Existing-owner operations never write outside the selection.

Before writes, advance checks allowance, shared batch capacity, progress and
counter headroom. It never gathers fields, reencodes or rescans source payload.
The final copy may split a scalar encoding across caller-visible batches.

## Metadata authority and publication

[Owner helpers](../../src/array_owners.fy) expose `prepare_record`,
`validate_record_work` and `publish_record_work`; `RecordWork` carries transient
checked byte windows. COPY42 authenticates its source and exact nominal before
free-slot lookup/reservation. Assignment authenticates the target first.

Every advance rechecks catalog planning, table validity, source/target tokens and
generations, whole-root metadata, nominal subranges, reservation and table depth.
Saved fields are comparison facts, not guest authority. These metadata checks
remain atomic; bounding payload bytes does not bound every metadata visit, native
execution time or wall-clock latency. Existing atomic owner/storage APIs remain.

CREATE41/COPY42 reserve without publishing. Only after the final destination byte
does completion publish arena usage, owner/order/depth and the destination token.
Cancellation before completion leaves only unreachable spare bytes. ASSIGN and
REPLACE preserve the existing root token, generation and arena usage. Their writes
are incremental after staging, with no rollback after a later cancellation/error.

## Frozen execution, Fuel and remaining work

The parent pins catalog, field values, table and backing. PC, frame, destination,
source and selection remain fixed; every other guest opcode is frozen while the
recipe is active. The instruction unit and full operation price are charged once
on successful admission, retaining selected pricing. Continuations run before the
zero-Fuel gate, consume byte allowance and dispatch visits, and do not recharge
Fuel or reevaluate source expressions. The PC advances once on completion.
Spent Fuel remains spent; teardown discards private partial state and staged
output. External effects are neither rolled back nor replayed.

## Native verification

Five [kernel groups](../../tools/runtime-engine/struct_work_tests.fy) pass in both
profiles: six-operation/six-scalar atomic parity, self/same-owner snapshots and
padding normalization, admission failures before writes, late metadata/generation/
loan/budget/overflow rejection, and maximum 128-bool/depth16 boundaries. Destination
commits split at one/seven bytes. Maximum staging measures exactly 1280 field bytes and
384 copy bytes; source padding is normalized rather than copied.

Five [Engine groups](../../tools/runtime-engine/engine_struct_work_tests.fy) pass
nine actual-source modes: new construction/copy, whole/child copy and constructor
replacement, bool/padded identity, same-owner sibling copy and constructor-field
swaps with exactly-once expression evaluation. They verify shared admission
fits/deferral before Fuel, staged and partial-commit cancellation/refunds, fixed
quanta 1/7/4096 and mixed 1/7/3/4096/2, exact/one-less Fuel, zero-Fuel continuation,
interleaving, Engine moves and released Program pins. Every actual resume denies
the next SDK allocation and records zero attempts.

Both profiles exit with zero SDK heap and default 1048576-byte stack reserve/
4096-byte commit. All 260 receipt inputs match checkout and committed Git; the
transport review covers 33 typed bindings and 30 layouts, including explicit
8-byte scalar/128-byte record scratch array widths. Root locked check passes
266 sources/2992 MIR; all 258 production modules retain LF. Separate OS I/O,
metered-output, full M2 and public CLI matrices were not repeated. No wall-clock
throughput or latency benchmark is claimed.

## Remaining accepted work

CALL/RET, setup/compile proof, seal/cleanup, deadlines, in-flight cancellation/
poison containment and full public lifecycle/ABI/CLI remain in the
[accepted inventory](../product/04-remaining-work.md). R03-R05 remain incomplete.

# Native aggregate selected destinations

Date: 2026-11-06. Native prerequisite after the
[independent copy IR proof](aggregate-copy-ir.md).

## Captured identity and range

`aggregate_places` captures a complete scalar-array owner or an exact nominal
record subtree before RHS evaluation. Its Place contains the original owner
token/generation, root shape/alignment/reservation, selected nominal record and
first scalar ordinal, relative byte offset and complete selected size. Element
zero denotes a record; array-only fields have canonical zero record metadata.
No raw pointer, source payload or mutable descriptor is retained.

Array selection authenticates the existing writable owner without reading old
elements. Record selection authenticates the complete root and independently
resolves a nominal subtree in the current layout plan. Scalar lookalikes, invalid
ordinals, foreign value domains, malformed ledgers and live array loans fail
before a caller can begin its RHS. A corrupt old bool does not prevent selection:
ordinary assignment may replace it without reading its invalid old value.

Every store reselects through the captured token and compares the complete shape
and byte reservation with the snapshot. RHS descriptor rebinding or ordinal
changes cannot redirect the destination. In-place payload changes and additional
owners may coexist with the original snapshot. Completed loans can restore
availability; active loans, released/reused/cleared generations and changed
reservations fail before publication.

The coordinator must bind the snapshot to one unchanged catalog and one
owner-table/backing lifetime. The native metadata does not pin a root, establish
source-language mutability, authenticate another table or create an IR lifetime
obligation. Those are requirements of the subsequent admission/VM connection.

## Atomic publication paths

| Destination | Supported final store |
| --- | --- |
| Whole fixed array | Existing exact-shape owner copy or authenticated self copy |
| Whole fixed array | One checked repeated scalar fill |
| Whole fixed array | Complete ordered scalar list in disjoint caller scratch |
| Nominal record root or subtree | Existing exact-nominal owner/subtree snapshot |
| Nominal record root or subtree | Complete ordered constructor scalar values |

All paths delegate to the existing authenticated owner/storage transactions.
Array and record source payload validation still precedes the first backing
write. Records retain full canonical snapshots, including padding normalization
on identical windows. Same-owner sibling copies work in either direction.
Array list scratch is caller-owned, disjoint storage, enforced by native Fairy C
borrowing. The adapter uses its selected-size prefix, so one larger scratch can
serve different scalar widths; insufficient capacity fails before publication.
Record snapshots remain bounded by 128 bytes. No new guest owner,
extent, allocation, generation or owner-order change is needed, even at capacity.

Failure leaves the payload as it was at store entry. Effects performed during RHS
evaluation remain; no rollback or replay is introduced. Invalid source bools,
late scalar encoding errors and insufficient scratch cannot publish a prefix.

## Verification and execution frontier

Run `python -B tools/verify-aggregate-places.py --profile development` and repeat
for release. `--batch core` selects seven destination tests; `--batch windows`
selects the three independent existing byte-window tests. The complete selection
has ten native groups. Cases cover all six array scalar domains, descriptor/RHS
effects, active/completed loans, stale generations, metadata/domain corruption,
both same-owner record copy directions, canonical padding and atomic failures.
Maximum cases cover a 32768-byte array, 128 record leaves/bytes, depth 16 and all
sixteen owner slots with exact full backing. No stack/compiler/linker overrides
are required.

This is private native storage, not a new guest feature or executable selected-
aggregate opcode. Independent aggregate-place IR identity/phase/lifetime proof,
metered invocation snapshots, both VM drivers, returned-view/recipe guards and
source lowering remain to be connected. Existing source/IR behavior, public
capabilities, operation prices, default 256 and CLI ceiling 16000000 are unchanged.
Resource/tag copy-versus-move, complete L04/C05/Engine/Instance/host/isolation and
delivery remain open. Public CLI, full language/native Fuel, LF mirrors, Linux,
OOM injection, general stack/performance and clean-machine delivery are outside
this native selection.

Windows development/release each passed **10 native groups** on the same 180
checkout/Git-raw-matching inputs, with 174 LF production modules and discovery of
301 files/1800 tests. Both final selections ran fresh on implementation `7403e9f`.
An initial six-pass/one-failure core report is preserved: a reusable scratch larger
than the current array was passed to the exact-size encoder. The new adapter now
checks capacity and passes only the selected-size prefix. No historical result,
compiler/linker/stack override or public CLI pass is claimed. See
[Windows evidence](../evidence/aggregate-selected-place-windows-20261106.json).

The [independent IR successor](aggregate-place-ir.md) now proves all five final
store forms, common identity/phases and canonical scalar/owner/loan lifetimes.
It preserves the executable gate pending metered snapshots, both drivers,
retained guards and source lowering; the native snapshot remains metadata only.

The [metered native successor](aggregate-place-vm.md) now wraps those snapshots
in invocation-local storage and prepays all five final stores. Both VM drivers,
retained guards and ordered source lowering remain the executable frontier.

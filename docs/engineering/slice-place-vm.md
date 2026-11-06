# Metered exclusive-slice selected-place storage

Date: 2026-11-06. Successor to [independent slice-place analysis](slice-place-ir.md)
and [native exclusive-slice locations](slice-selected-place.md).

## Implemented boundary

`src/slice_place_vm.fy` provides invocation-private requirement, preparation,
cost and single-step adapters for already independently analysed immutable IR.
It does not issue executable admission. Existing ordinary and retained drivers,
validators, public source capabilities and CLI Fuel limits remain unchanged.
Kind-one slice places remain rejected by the existing executable entry points.

The caller supplies the actual function, frame and canonical current binding.
Slice SELECT/READ/STORE check the containing function range and exact scalar
shape reconstructed from its site metadata. Rooted SELECT also checks the
frame's live owner token and declared root length; rootless exclusive formals
need no owned-root token table. Both forms retain the selected original location.

SELECT authenticates range/session, bounds and backing without reading payload.
READ captures the old scalar once. STORE accepts selected/read phases and
publishes its stored phase only after canonical validation and atomic encoding.
Fuel shortfall precedes any snapshot, register or payload publication. No
operation allocates another owner, ticket, guest site or payload reservation.

CALL and lexical reborrow restoration may rotate tickets. READ/STORE require
the caller's authoritative restored ticket; they never search for a newer pooled
ticket or reuse the captured parent while a child is active. The original
owner/session, range, reservation, relative index and byte offset must agree.
Changing descriptors, frame-token bindings or index registers cannot redirect
the captured target. Root/session reuse, stale tickets, narrowed children,
invalid scalar encoding and malformed snapshots fail before publication.

## Explicit storage format

One native Vec is reserved/initialized per invocation, with no fixed snapshot
array on the native stack and no per-instruction allocation. Width W is zero
for no places, otherwise the highest place ID plus one, bounded to 1..16.
There are exactly 32 frame regions, each with one live counter and W rows.

| Format | Row words | Prefix | Total usize words | Bytes on amd64 |
| --- | --- | --- | --- | --- |
| Existing array only | 9 | none | 32*(9*W+1), 320..4640 | 2560..37120 |
| Slice or mixed | 14 | 14336+W | 1+32*(14*W+1), 481..7201 | 3848..57608 |

Empty array-only state has zero words. Extended width zero is invalid. Legacy
lengths are divisible by 32; extended lengths have remainder one and require an
exact prefix. Length alone never selects a potentially ambiguous row width.
Invalid extents, prefixes, frames, IDs, phases and active counts fail boundedly.

A slice row stores root slot/generation, root length, original start/end,
exclusive-session generation, captured ticket slot/generation, allocation
mark/base/end, relative index and byte offset. Word13 packs scalar tag in
bits0..3, site in bits4..7, phase in bits8..9 and slice kind in bit10. Array rows
in an extended vector keep their original eight data words, require words8..12
zero, and place their kind-zero packed word at word13. Common END uses the
selected row and format; it clears 9 or 14 words without needing a live ticket.
Array/slice kinds share IDs, so a live same-ID selection cannot be overwritten.
`place_vm::empty_frame` recognizes both formats.

## Fuel schedule

All prices below include ordinary dispatch. These are private adapter prices;
retained driver integration and its existing additive dispatch are still open.

| Operation | Array-only legacy | Slice or mixed |
| --- | --- | --- |
| Setup, W=0 | 0 | invalid |
| Setup, W=1..16 | 257+10*32*(9*W+1), 3457..46657 | 257+10*(1+32*(14*W+1)), 5067..72267 |
| Array SELECT | 65 | 65 |
| Array READ | 65+stride | 65+stride |
| Array STORE | 65+2*stride | 65+2*stride |
| Slice SELECT | unavailable | 4129 |
| Slice READ | unavailable | 4162+stride |
| Slice STORE | unavailable | 4162+2*stride |
| Common END | 17 | 22 |

Setup prices cover initialization and publication/destruction visits for every
word. `prepare` validates the bounded plan but does not itself debit a Fuel
balance; its future driver must reserve the complete plan cost before allocation.
Slice operations share the bounded existing session/pool authentication envelope
and add 32 visits for snapshot/frame decoding and publication. END's five-unit
extension covers its five extra cleared words. Work does not scan array payload
length; only READ/STORE touch one scalar of stride at most eight bytes.

The old `place_vm::requirement/cost` continue rejecting slice-tagged instructions.
Only the new adapter requests extended storage. Existing guest instruction
prices, public default256/ceiling16000000 and capability metadata remain.

## Executable gate and next work

Both drivers still lack a coherent canonical binding source for these new
instructions: their slice-site operand cannot simultaneously name a restored
current ticket. Integration must use actual frame/binding state and preserve
CALL/lexical restoration; guessing a ticket or silently changing an operand,
opcode or public price contract is not acceptable.

Remaining: ordinary/retained driver admission and cleanup, returned/image-view
and recipe guards, source bounds-before-RHS and slice compounds, record/scalar
places, grouped lvalues, generic aggregate overlap and complete
L04/C05/Instance/host/delivery. This native adapter is not executable guest support.

## Verification

Focused Windows development/release checks use `tools/verify-static-execution.py --selection slice-place-vm`; public CLI regressions use
`tools/verify-public-fuel.py --phase cli` in each profile. The native selection
covers the new adapter, all legacy array snapshot groups, native slice
restoration/full capacity and existing CALL/reborrow restoration.

See [Windows evidence](../evidence/slice-place-vm-windows-20261106.json) for actual
commands, executed counts, hashes, locked LF mirrors and skipped scopes.
Full language/original native Fuel matrices, Linux, OOM, general stack/timing,
worker isolation and packaging/clean-machine delivery are outside this check.

Development and release each passed **20 native groups** (eight new adapter
and twelve legacy array/slice/restoration groups) and **57 tool-free public Fuel
CLI cases**. Their 186-path input union matches the checkout and staged Git raw
bytes. Native receipts each cover 176 inputs; CLI receipts each cover 180. Both
locked LF mirrors pass, with 167 LF production modules and common 287-file
discovery. 40 unselected legacy fixtures differ only by CRLF/LF; both hashes
are recorded. These results do not establish executable guest slice places or
renew the skipped full language/Fuel/platform/isolation/delivery scopes.

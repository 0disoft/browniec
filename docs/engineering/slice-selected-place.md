# Native exclusive-slice selected locations

Date: 2026-11-06. This is the exclusive-slice runtime prerequisite for L04,
following [owned-array source assignment](array-place-assignment.md).

## Implemented boundary

`src/slice_places.fy` captures one scalar element relative to a live exclusive
slice's current range. Selection authenticates the pool, owner and session,
checks bounds and calculates the original byte offset without reading payload.
Empty ranges fail element selection. A noncanonical bool can be selected for
plain replacement; an explicit old-value read still rejects that encoding.

The private snapshot retains the original owner token/generation, full view,
exclusive-session epoch, pool slot and ticket generation, allocation mark/base/end,
relative index and byte offset. It allocates no backing, owner, pool slot or heap
object and copies no payload or complete owner/pool table. It is valid only in
its original invocation, owner table, pool and backing lifetime. It is not a
guest value, serialized capability or proof of affine single use.

`read` and `store` require the current authoritative ticket from the canonical
binding coordinator. A completed CALL or lexical reborrow may advance ticket
generations while restoring the same view and session. Those operations remain
valid after restoration. The primitive never guesses a newer ticket from pool
metadata. Stale tickets, a different slot, a still narrowed child, an ended or
reopened session, a released/reused root, changed reservation/shape and short
backing all fail before accessing payload. A different descriptor or index
variable cannot redirect the captured target.

Full-range child and parent authority are distinguished by the canonical
coordinator, not by comparing byte ranges. Trusted native callers must supply
only the binding whose authority has resumed, retain snapshots linearly, and
never clone/mutate sessions or move snapshots across invocation tables. The
[independent IR proof](slice-place-ir.md) now enforces static authority and
location phases. The [metered storage adapter](slice-place-vm.md) retains the
snapshot and requires the canonical restored current ticket. The [execution successor](slice-place-execution.md) now connects both VM
drivers to canonical frame/site bindings after complete admission; this
primitive alone does not enforce guest authority.

An old scalar must be read and retained before the RHS for compounds. A later
read observes current payload. Store revalidates metadata and uses the existing
scalar codec, which stages at most eight bytes before publication. Failed
validation or encoding preserves all bytes. Owner, pool and snapshot metadata
remain unchanged on both success and failure; RHS effects are not rolled back.
Work is bounded by the existing sixteen owner slots and sixteen pool slots;
there is no array-length-dependent payload scan.

## Still open

The [analysis-only IR successor](slice-place-ir.md) now proves exclusive-slice
SELECT/READ/STORE/END identity, lifetime, phase and available authority in ordinary
IR. Executable admission, metered invocation storage and both VM adapters,
image/returned-view integration, source bounds-before-RHS and compound lowering
remain to be connected. Existing plain slice source writes
still use their preceding contract. No opcode, operation price, public feature
flag, CLI default 256 or ceiling 16000000 changes in this prerequisite. Record
and scalar-local places, grouped lvalues, generic aggregate overlap and full
L04/C05/Instance/host/delivery also remain open.

## Verification

Run `python -B tools/verify-static-execution.py --profile development
--selection slice-places`, then repeat with `--profile release`. The selection
includes nine native snapshot groups and four focused existing lexical
reborrow/CALL handoff groups. The verifier captures compiler/input
identities, checks a locked LF mirror and rejects native build overrides.

See [Windows evidence](../evidence/slice-selected-place-windows-20261106.json)
for executed coverage, profile counts, input hashes and skipped work. These
native results do not establish guest IR/source admission, public Fuel behavior,
full language conformance, Linux, OOM injection, general stack/performance,
worker isolation or clean-machine delivery.

Snapshot coverage includes all six scalar domains, captured index/descriptor
changes, old values across RHS writes, corrupt bool encoding, staged failures,
empty/nonzero/4096/host-maximum ranges, short backing, restored CALL/lexical
tickets, stale tickets, a narrowed child whose index is still in bounds, closed
and reopened sessions, reused/cleared roots, malformed snapshots/ledgers and
successful stores with all sixteen owners/tickets and backing quota full.

Development and release each passed **13 native groups** (nine new snapshots,
four existing restoration regressions), on 172 identical executed input hashes,
165 LF production modules and common 285-file discovery. Both locked LF mirrors
passed. Every selected input matches staged Git bytes and the checkout. No
historical test result is reused for this final selection. Public opcode prices,
default 256 and ceiling 16000000 remain unchanged; no public CLI/Fuel result is
renewed by this native prerequisite.

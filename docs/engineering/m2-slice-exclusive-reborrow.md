# Private exclusive subrange suspension and restoration

`slice_reborrow` adds an invocation-private native foundation for exclusive
subranges. It narrows the existing active pool slot and rotates its generation;
the parent ticket becomes stale immediately. A retained linear `Loan` receipt
records the original range and write session. Restoration validates the latest
child ticket, reinstates the original range and issues another fresh generation.

Implementation: `ab85195`.

This stage does not add guest syntax, IR construction or independent lifetime
proof, opcode dispatch, Fuel prices, VM cleanup wiring or a public capability.
Existing public mutable parameters and owned/readonly scalar slices keep their
current behavior. In particular, `let ref mut Tag[] q = ref mut p[lo..hi];` is
still rejected by the source compiler.

## Native transaction

`begin` validates the entire pool/owner state through the existing ticket
resolver, requires an exclusive parent, checks relative bounds and reserves
generation headroom before publishing either field. If the current absolute
range is `[a,b)`, relative `[lo,hi)` becomes `[a+lo,a+hi)`. The checks
`lo <= hi <= b-a` prove both additions fit within the original owner length.
Empty and full ranges use the same exclusive protocol; no shared coercion is
introduced.

Only the selected slot's view and generation change. Owner metadata, write epoch,
arena position, payload and all other pool slots remain unchanged. The child
uses existing checked relative read/write/length/u8 UTF-8 operations. Parent
read/write/length/close fail with the old ticket. Ordinary root access remains
locked throughout the child lifetime, even for an empty range.

`restore` checks an active receipt, slot and monotonic generation, the original
owner/session, selected range containment, exact current range/type/shape and
generation headroom. Every failure precedes publication and preserves the
receipt and pool. Success reinstates the original range, rotates the generation
and clears the receipt. Both the original parent ticket and the former child
ticket remain stale; only the returned parent ticket is authoritative. Previous
child writes remain visible in the restored range.

## Coordinator trust and bounds

Receipts are native control state, not guest-supplied descriptors. The trusted
coordinator must retain authentic receipts without cloning or modifying them,
restore in reverse nesting order and supply the current child ticket after any
nested restoration. Structural and session checks are not cryptographic receipt
authentication or an independent borrow checker. Identical full-range nested
views in particular require the coordinator to enforce stack order.

`depth` counts all enclosing authority restorations along this ticket's chain,
including any CALLs, rather than only VM CALL depth. Independent peer roots do
not add ancestors to one another; a global conservative count is also safe. Admission accepts depths 0..30 and reserves
`depth + 2` generation increments; restoration reserves `depth + 1`. No counter
wraps. Native tests create 31 nested loans and unwind them to fresh parent
authority. Exhausted generations fail without mutation; closing a terminal
ticket retires its slot instead of resurrecting an old generation.

The current CALL handoff coordinator counts VM frames and is not connected to
this protocol. Combined CALL/reborrow depth admission, receipt ownership and
independent suspended-parent flow proof must be designed together before guest
integration. Direct session mutation, receipt duplication and incorrect depth
or stack order are outside this private native contract.

`finish` is invocation abort, not lexical close. It atomically drains the existing
pool before clearing at most 32 supplied receipts. The active narrowed slot is
sufficient to end the root write session; suspended parents require no additional
pool slots. Failed drain retains metadata for diagnosis. Successful drain keeps
earlier payload writes and does not release or copy owned arrays. Native callers
retain responsibility for propagating the original execution outcome.

## Structural costs and verification

No Program, signature, owner, pool-slot or shared CALL-frame fields grow. Each
pending lexical restoration has one private receipt. A reborrow uses the same
single pool slot and owner as its parent, copies no payload and creates no new
payload extent. It works with all sixteen slots occupied. Admission/restoration
use the existing bounded pool validation; no guest Fuel price or measured
allocation, native memory, stack or timing claim is introduced.

```text
python -B tools/verify-m2-slice-elements.py --profile development --exclusive-reborrow
python -B tools/verify-m2-slice-elements.py --profile release --exclusive-reborrow
```

The selection runs six new reborrow groups, six existing CALL-handoff groups and
six exclusive-pool groups. Cases cover all six scalar tags and actual relative
writes, stale parents/children, exact restored ranges, empty ranges, 31 nested
loans, invalid bounds/capacity, malformed session/range receipts, generation
exhaustion and unchanged state on failures. A full sixteen-root pool exercises
abort failure preservation and successful drain while preserving earlier writes.
Public CLI regression runs 74 mutable-parameter, 222 owned mutable, 192 readonly
scalar and 2007 M1 cases on Windows.

Development and release each passed all 18 selected native groups and 2,495 CLI
cases, with 374 matching current input hashes. Compiler, retained CLI and all
matrix/M1 receipt identities were rechecked. Program/signature declarations,
owner/pool modules, CALL handoff, shared CALL frames, public VM, execution core,
verifier and CLI entry remain unchanged from `80adbb7`. Both profiles accept
parser depth32 in check/run and reject depths33/64 with `compile_limit`. See the
[Windows evidence](../evidence/m2-slice-exclusive-reborrow-windows-20261102.json).

The [IR successor](m2-slice-reborrow-ir.md) now proves active children,
suspended/restored parents and exit/join/backedge paths. Next is combined
CALL/reborrow depth admission and receipt ownership. Metering, executable VM
integration and source/public promotion remain separate deliveries.

Full native, other M2, Linux, M0, isolation, packaging, allocator and timing checks
are outside this selection. Local commits only; no push, publication, packaged
release or deployment.

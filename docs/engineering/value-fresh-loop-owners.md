# Fresh anonymous owners retained across loop iterations

This private retained-value source slice extends [loop-header owners](value-loop-header-owners.md)
from pre-existing anonymous seeds to fresh anonymous exact Buffers installed into
loop-carried shared byte views. The public CLI admission gates are unchanged.

```c
module main;
fn ref u8[] id(ref u8[] v) { return v; }
fn i32 main() {
    let seed = bytes::empty();
    var ref u8[] r = bytes::view(ref seed);
    for (var n = 0; n < 3; n += 1) {
        r = id(ref bytes::view(ref bytes::empty()));
    }
    if (r.len == 0) { return 42; }
    return 0;
}
```

## Evaluate first, then transfer the actual owner

Each retained singleton anonymous RHS evaluated while loop tracking is active
uses a distinct static Buffer carrier slot. The RHS allocation and selected CALL
finish before the lexical destination closes. The compiler then emits explicit
DROP_IF_LIVE115 for the carrier and MOVE88 from the RHS scratch into that carrier.
Every descriptor referencing that exact source owner follows the move; its
identity, endpoints, retention and lexical mutability remain unchanged. This
also allows aliases that rebind together on later iterations.

A carrier is physically Dead on its first visit. It contains the previous actual
owner only on paths that reached its assignment. There is no dummy initializer,
early RHS retirement, payload clone, static-slot rewind or source/effect replay.
The old and new real allocations overlap during RHS evaluation and remain
subject to the existing sixteen-owner and quota limits.

The source fixed point now carries definite/possible exact Buffer initialization
alongside candidate origins and missing-retention masks. Zero-trip exits may
therefore have absent carriers. Header descriptor identities remain exact. Named
owning header loss and unhandled Result obligations still reject. Rechecking the
converged origins also rejects a carrier cleanup if any surviving alias pins it.

Earlier source returns can precede a later assignment site in source order, yet
be reached after its owner crossed a backedge. Once the IR converges, the compiler
completes those returns with explicit forward cleanup islands. Only recognized
compiler carrier slots still possibly live at that terminal are added; the
original return encoding and source offset move intact after reverse-slot
DROP_IF_LIVE instructions. The full extra instruction capacity is checked before
any return is redirected. Existing CLOSE/DROP instructions are preserved.

The compiler table remains heap-backed: at most 256 rows of 34 usize words
(69632 payload bytes on 64-bit hosts). Its work cap is
256 * (1 + 2 * 16 * 24 + 2 * 16) = 205056 visits. The independent canonical owner
CFG uses a separate bounded worklist, capped at 256 * (1 + 2 * 16) = 8448 visits.
CALL-map uniqueness is checked once statically rather than treating a worklist
revisit as a second CALL site. Non-Buffer uncertainty still rejects.

## Native lease handoff

The MOVE88 connection in value_runtime delegates to value_view_runtime. Ordinary
unleased moves retain the existing frame transfer. A pinned move authenticates
every source alias, rejects stale destination aliases and foreign-frame aliases,
and calls the pure `value_frames::inspect_buffer_move` API. The exact Buffer,
native activation, canonical serial, destination, root token/backing, shared
lease and settled ledger must all authenticate.

`value_frames::move_read_buffer` pays the actual existing 2080 Fuel once. It
stages only the eight canonical serial bytes, authenticates the dead destination
and invokes `value_roots::rebind_read`. That native coordinator API validates
the real read-leased root and destination binding before its single metadata
write. It keeps the actual backing, serial, token, generation, read lease and
ledger continuously unchanged. After that publication, only infallible writes
to authenticated disjoint frame slots/liveness/order and descriptor bindings
remain. There is no end_read, shadow Fuel, fallible native transfer after lease
release, rollback or recovery assertion. Every error precedes publication.

These two native APIs are necessary because ordinary root/frame MOVE requires
exclusive access; weakening that existing gate would bypass the descriptor
registry. Only the descriptor coordinator can select the shared-read path after
validating all affected aliases. The additional core changes are value_runtime,
value_frames and value_roots. They are internal APIs, never guest entrypoints.

The independent view CFG models the same exact Buffer-slot rename. Mutations,
DROP, aggregate extraction and owning CALL arguments keep their pin checks.
No new opcode, runtime frame field, price, public gate or public Fuel default
256 / ceiling 16000000 is introduced. The bounds remain 32 frames, 256
instructions and 16 native owners, on default stacks without compiler overrides.

## Focused native evidence

Run `python -B tools/verify-value-fresh-loop-owners.py --profile all` after
refreshing the local lock with the pinned `build/toolchain/fairyc.exe check`.
The verifier selects five new source groups, two independent native/IR groups
and four predecessor/depth regressions. It uses disjoint locked native mirrors
and records every exact input digest, compiler identity, argv, report and output
hash under `build/value-fresh-loop-owners/{development,release}/receipt.json`.

Source guests cover actual populated bytes, nested and selected-CALL ranges,
while and classic-for continue, zero-trip, break, nesting, aliases, executed early
return/Option failure, bounds and
overflow failures followed by fresh-invocation recovery. Every positive source
program independently verifies before VM execution. Negative cases preserve
named owner and Buffer pin rejection. The unchanged combined admitted32 /
rejected33 fixture runs as one selected predecessor group.

The independent native fixture observes unchanged root serial, owner token,
descriptor tickets and windows across a pinned MOVE. It exercises 2079 / 2080
Fuel, occupied destination, old-destination/foreign-frame alias, mismatched
serial, corrupt root generation, unsettled/closed store, zero-quota allocation
and stale activation rejection, actual byte reads,
and zero-Fuel failure drain with cleared frame/backing/lease state and zero
root-ledger usage. Separate corrupted IR cases reject occupied recreation,
pinned DROP and stale/dead MOVE sources.

An exploratory source batch passed six of eight groups before canonical owner
admission caught two early-return leaks from later carrier sites. The return
cleanup islands fix that defect; the isolated rerun passed both cases. These
exploratory receipts are not final acceptance evidence.

Final Windows AMD64 development and release runs both passed all eleven selected
groups with default stacks and no native overrides. Their 228 frozen inputs
match the final mirror raw bytes; all 217 production modules retain LF. The
separate delivery manifest pins both receipts, the exact input set, compiler,
local mirror commit and exported patch. Shared lock/checkpoint/evidence files
are excluded from that patch; integration owns its final checkout lock refresh.

## Limits

Fresh normalization currently selects a fully retained singleton anonymous exact
Buffer RHS. A union of conditionally allocated fresh roots is not generalized by
this slice. A surviving alias that pins an assignment site's old carrier can
still cause conservative source rejection; owners are never overwritten to
force admission. Static carrier slots share the existing sixteen-slot limit.

The final focused receipt is Windows AMD64 native evidence only. Linux/macOS,
public CLI, general references, host/I/O, all fresh Option/Result propagation
combinations and broader release/runtime acceptance remain separate. The native
failure-drain fixture proves its concrete ledger cleanup; source fresh-invocation
recovery alone does not establish every lifecycle counter or leak obligation.

Main integrated this slice in `cbdfdbe`. [Recorded evidence](../evidence/value-fresh-loop-owners-windows-20261107.json)
retains both eleven-group worker runs and explicit input differences. Only the
unreached version encoder changed in the test diagnostic renderer; its used
error-rendering prefix remains byte-identical. The [final root release check](parallel-integration.md)
separately composes the populated-owner, native identity/drain and depth fixtures.

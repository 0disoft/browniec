# Evolving shared-view origins in source loops

Private retained-value source now permits live loop-header byte views to select
different already-live Buffer or formal roots on later iterations. Repeated
ranges, aliases, selected shared CALL results, while conditions, nested loops and
classic-for continue/post paths participate in the same inference.

```c
module main;
fn i32 main() {
    let a = bytes::empty();
    let b = bytes::empty();
    var ref u8[] r = bytes::view(ref a);
    for (var n = 0; n < 2; n += 1) { r = bytes::view(ref b); }
    if (r.len == 0) { return 42; }
    return 0;
}
```

The source checker protects every possible candidate until the last descriptor
closes. Native views still retain their actual concrete root. Zero-trip paths
remain possible to analysis even when a source condition is a literal constant.

## Fixed-point analysis without source replay

Loop cleanup projects the reached roots onto the exact header descriptor shape.
Function identity, live/dead shape, names and reservations stay exact. General
view equality and expression temporary cleanup retain their stricter contracts.
Owning live/maybe backedges still match the header exactly.

Before lowering exit trampolines, a compiler-heap table analyzes the already
emitted loop IR. Each PC has sixteen candidate-root masks and sixteen masks of
origins observed without retention. Both planes union monotonically. An origin
absent from an edge loses no retention; any unretained occurrence revokes it.
This handles alias chains needing multiple rounds around a backedge.

The worklist follows real branch targets, nested loop code and shared for-post
edges. It exports converged state to condition-false and break snapshots. No
source/body replay, typed-ID rewind, owner restoration or runtime effect replay
is used. Loops without a live header view skip the inference allocation.

With at most 256 PCs and 24 origins, processing is capped at
`256 * (1 + 2 * 16 * 24) = 196864` visits. On 64-bit targets the table payload is
at most `256 * 32 * sizeof(usize) = 65536` bytes, plus vector bookkeeping. It is
not a recursive parser-frame array. These bounds do not establish full compiler
RAM or timing conformance.

## Recheck operations before publishing exits

After convergence, the compiler audits every earlier Buffer mutation/growth,
owning CALL argument, move and DROP90/DROP_IF_LIVE115 against the widened roots.
Code safe on the first visit may be unsafe on a later visit; it rejects as a
source type/lifetime error rather than relying on eventual VM rejection.

The audit also checks descriptor use and return cleanup. Shared returns still
select exactly one formal origin. Publishing inferred roots preserves exact
descriptor identity and requires every local candidate owner to remain live or
possibly live. Malformed shapes and lost retention reject before metadata writes.
The independent canonical CFG verifier remains unchanged and mandatory.

No runtime opcode, dummy owner, payload copy, early root retirement, public
admission gate, existing price or Fuel default/cap changes.

## Remaining owner and language limits

Retained anonymous seeds may participate while another header descriptor keeps
their owning live/maybe state exact. A break may retire a seed and merge with
the zero-trip possible-owner path. Retiring its last alias on a repeating edge
still rejects: existing rebinding would emit a DROP and violate the exact owner
header. General support requires separate root-retention/cleanup deferral.

Bottom control conditions, unreachable continuation diagnostics, general
mutable/non-byte/Buffer-object references, public reference admission,
methods/AllocError, runtime/host/I/O and platform/delivery remain separate work.

## Verification

`tools/verify-value-view-loop-origins.py` selects seven new groups (including
metadata and two real bottom/loop-composition guests) and eight focused
bottom/loop/conditional-owner/depth regressions. Profiles use disjoint locked
mirrors, default stacks and no compiler overrides. The old 32/33 depth fixture
is preserved verbatim. No broader existing suite is rerun by this command.

Implementation `9d7712b` passed all 15 selected groups in each Windows native
profile with fresh locked mirrors and exact final inputs. Seven new groups execute
fourteen positive guests including two bottom/loop composition cases, nine source
rejections and exact metadata checks. Eight existing groups cover loop semantics,
bottom cleanup/short-circuiting, conditional owners and the unchanged admitted32/
rejected33 fixture. All 228 union inputs match checkout and Git raw bytes;
all 216 production modules are LF. See [focused evidence](../evidence/value-view-loop-origins-windows-20261107.json).


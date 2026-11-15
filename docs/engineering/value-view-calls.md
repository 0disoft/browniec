# Native Buffer view argument and return handoff

This increment provides the native lifetime transaction for shared Buffer-backed
byte views across authenticated caller/callee frames. It is a prerequisite for
general reference formals/results. It does not yet admit reference signatures,
new CALL/RETURN IR, source syntax or public CLI capabilities. The complete
reference objective remains open; a native pass is not a guest execution pass.

## Shared argument aliases

`value_buffer_views::aliases` accepts at most eight source/destination binding
pairs in an existing invocation registry. Source bindings may repeat; destination
bindings must be distinct and vacant. All source rows, actual root tokens,
initialized windows and available rows are validated before publication. One
small bounded metadata candidate is staged and published together; it contains
no copied payload and acquires no additional physical root lease. A late bad
argument, missing row, exhausted registry or insufficient Fuel publishes nothing.
Root bytes, generation, serial and ledger remain unchanged. Charged Fuel is not
refunded. Successful preparation costs the existing512 Fuel per alias; an empty
batch has zero price. Existing single-view operations retain their prices.
Within a batch, `lookup` authenticates each original source row once. Its ticket
is consumed immediately to read that same row from the unchanged source Pool;
only the separate staged candidate is modified until the final publication.

The frame adapter authenticates both generation-checked frame tokens, requires
adjacent caller/callee activations with the callee current, and rejects any
callee view left from an earlier activation. Caller/formal local IDs map to the
separate `frame*16+id` binding lane. Canonical owning slots and guest scalar
registers never contain these tickets or bindings. The caller's source aliases
stay live while the callee owns its new aliases.

## Selected returned window

A returned descriptor must refer to the same exact root serial, logical owner
binding and owner token as the selected caller-origin descriptor. Its window
must lie wholly within that actual origin window; root equality alone cannot
authorize bytes outside an argument. Subtraction checks admit empty end windows
and exclude overflow before endpoint addition. The destination is vacant.

The native handoff prepays the existing256 move price, authenticates both rows,
then moves only the descriptor binding. Its generation and physical root lease
remain unchanged. Closing the caller's original alias afterward cannot release
the root while the returned descriptor survives. Only its last alias permits
root mutation/drop. Independent source/IR origin selection must eventually
choose the allowed input; supplied native metadata is not guest authority.

The frame return adapter additionally requires no live canonical owned callee
slots and no callee view other than the selected returned descriptor. It rejects
leaks instead of hiding cleanup. Stale/nonadjacent tokens, malformed IDs, wrong
origins/windows, occupied destinations and failed admission publish no transfer.
After a successful handoff, frame leave and caller-argument cleanup are explicit
coordinator steps. The future VM integration must admit all surrounding cleanup
before publication and preserve the first failure during invocation teardown.
The existing prepaid registry shutdown still closes views before root drain.

## Bounds and next integration

The existing16 local view IDs,32 invocation rows,512 native bindings and32-frame
ceiling remain. Pool/root/plan metadata belong to their exact native invocation;
trusted coordinators must not clone/transplant ownership or treat a numeric
binding as independently authenticated authority. No extra heap-backed payload,
escaped native view, public handle, external bytecode, cache, GC or JIT is added.
Existing opcode prices and public Fuel default256/ceiling16000000 stay unchanged.

`tools/verify-value-view-calls.py` selects disjoint core and regression batches
for development/release in locked byte-identical native mirrors. Windows development/release each passed twelve native groups (six new),
recorded in [the focused evidence](../evidence/value-view-calls-windows-20261107.json).
Follow-on work connects independent reference signature/origin/CFG
proof, retained CALL/RETURN dispatch and source lifetime/inference. General
mutable/non-byte references, view-valued joins, public AllocError/admission,
text/I/O, Engine/Instance/host/cancellation, isolation and platform/delivery also
remain in the complete objective.

## Executed verification

Implementation: `4c8c84d`. Both native profiles passed six new groups covering
atomic aliases, contained/empty returns, stale/occupied/capacity/Fuel rejection,
recursive same-function frame separation and exact state/byte preservation.
Six existing owning-copy/view-copy regression groups also passed per profile.
All 223 union inputs match checkout and Git raw bytes; all 214 production modules
are LF. Builds used the pinned compiler with no native stack overrides.

Reproduce each batch with `python tools/verify-value-view-calls.py --batch core`
and `python tools/verify-value-view-calls.py --batch regression`; each defaults
to both profiles. Core and regression use distinct native build directories.
Source/public CLI checks, general reference IR/dispatch and Linux/macOS were not
run for this native increment. The unchanged admitted32/rejected33 conditional
fixture was hash-checked against the predecessor, not re-executed.

## Source authentication reuse (2026-11-16)

`aliases` previously called `lookup` and then `resolve` for each argument.
Successful `lookup` already performs that complete resolver: it validates the
whole registry, ticket generation/binding, root store/token/backing, physical
read lease and initialized window. The second resolver read identical metadata
through immutable Pool/store/vector borrows. Only the separate candidate changes
inside the loop. The original Pool is published once after every source and
destination succeeds.

The second call now reads `get(pool, source.slot)` immediately after successful
lookup. This accepts no caller-provided proof or ticket and adds no API, cache,
state, allocation or mutable backing access. Initial registry validation, every
source lookup and staged destination validation remain. State/Binding/Stale/
Capacity/Fuel precedence, exact charges and late-failure atomicity are unchanged.

For A successful aliases, source resolver/root authentications fall from 2A to A.
The complete header count, including initial admission and staged destinations,
falls from 1+3A to 1+2A. At eight arguments this is 25 to 17 header scans and
16 to 8 root authentications. With 24 original live rows packed first, the eight
discarded source scans remove 2208 live-pair comparisons (8*24*23/2) and 256
outer-row visits. The staged headers for live counts 24..31 remain, reducing
total header live-pair comparisons from 7628 to 5420. No asymptotic improvement
is claimed: the header remains quadratic in live rows and fixed caps (8 args,
32 views, 16 roots) bound the complete operation. Auxiliary state is unchanged.
Counts describe source operations; throughput and physical peaks were not measured.

Run `build/toolchain/fairyc.exe check`, followed by
`python -B tools/verify-value-view-alias-validation.py --profile all`. Six native
groups cover a 24-to-32-row batch with eight repeated arguments over two actual
leases, original-row/window/generation preservation, exact and short Fuel,
zero-Fuel cleanup, existing late source/destination/capacity rejections and
independent root byte/ledger checks. The existing native frame adapter exercises
eight actuals and a selected returned range; the frozen lookup oracle preserves
healthy-size, metadata-corruption and root-fault diagnostics.

The new pool test is also enrolled in the existing CALL core (seven groups) and
CALL-program regression (29 groups) selectors. Discovery-only checks verify
those entry points and the unchanged six-group CALL regression; their full
native batches were not rerun. See the
[Windows evidence](../evidence/value-view-alias-validation-windows-20261116.json).
Full Engine transport, retained/source CALL integration, public CLI, standalone
memory and full release gates are outside this focused change. Known legacy
Static integration and source-test failures were not retested or claimed fixed.
Broader completion remains paused; local delivery only.

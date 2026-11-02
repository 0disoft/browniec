# Private shared-argument canonical CALL coordination

The private canonical execution entry now accepts readonly scalar slices and
CALLs mixing scalar, shared and exclusive formals. It extends the
[scalar CALL coordinator](m2-slice-scalar-call-authority.md) using the same shared
execution loop, scalar/control preflight and mandatory invocation finish.
Public paths and the op61/62 guest/public execution gates are unchanged.

## Admission and publication

CALL shape inspection counts readers and writers separately. Scalar-only price
remains `1 + arity`; any borrowed formal adds `65537*(1 + readers + 2*writers)`.
These match the existing readonly/mutable CALL prices. Shared-only calls use an
empty canonical Batch, consuming VM frame and combined restoration depth without
rotating caller tickets. Writer generation reserves still count every pending
event. There are at most eight arguments, 16 pool slots, 32 VM frames and 31
combined pending events.

Every original argument is authenticated before any staged retain or rotation.
Readonly authentication reuses `slice_call_vm::checked`, whose body is unchanged
and is now exported to the private adapter. Shared tickets must match the source
root, scalar tag, owner session and original array shape. Multiple shared formals
may reference the same caller ticket; each receives a distinct retained handle
covering the same selected range. Shared derived sources retain existing support.
Exclusive derived/suspended CALL sources remain rejected.

Shared retention runs against a local pool snapshot. Canonical writer admission
then runs against that staged pool as the last fallible step. Only afterward are
pool slots, CALL PC, child tickets and formal origins published; scalar/control
publication remains in the existing coordinator. A late shared capacity failure
or writer generation-reserve failure leaves all original bindings, authority,
owner sessions, payload and control state unchanged.

## Return and abort

Mapped inspection authenticates readonly child origins against the immutable
CALL argument source and the caller's retained root binding. Origin cells survive
formal close and allow derived shared handles to remain usable. Detached cells
and canonical lease ordinals continue to describe exclusive formals only; shared
arguments do not shift writer indices or add a receipt collection.

Normal return authenticates exclusive current/detached tickets and rejects
remaining owned values. It stages readonly child cleanup in reverse static-site
order, including any retained derived handles, against local pool and owner
metadata. Canonical writer restoration is the last fallible operation. Successful
return publishes the staged tables, restores caller writers and clears child
bindings. A late stale child handle or invalid origin cannot partially close a
reader or pop the authority frame. Caller shared handles keep their generations.

Abort uses the existing combined drain. It preserves earlier payload writes and
the original error/outcome after successful cleanup. A failed drain preserves
CALL, origin and ticket maps for diagnosis. No automatic replay is introduced.

No persistent Program, signature, owner, pool, shared-frame or binding field is
added. The temporary CALL description gains a reader count. Admission adds a local
pool staging value; return adds local pool and owner staging values. There is no
new payload allocation or payload clone in these adapters. Native size, stack,
allocator and timing have not been measured; fixed snapshots are not a measured
memory improvement. Existing inert-view backing remains.

## Verification and remaining work

```text
python -B tools/verify-m2-slice-elements.py --profile development --shared-call-authority
python -B tools/verify-m2-slice-elements.py --profile release --shared-call-authority
```

The selection includes six shared-CALL groups plus the existing scalar-CALL,
canonical-CALL, shared reborrow-execution and formal-reborrow groups. Focused cases
cover all six scalar tags, eight duplicate shared arguments, empty ranges/UTF-8,
shared derived forwarding after formal close, recursion, mixed argument positions,
scalar helpers, exact/one-short Fuel, late writer reserve failure, late shared pool
exhaustion, staged return failure, corrupt origins and abort write/error retention.
Public regression selects 74 mutable-parameter, 222 owned-mutable, 192 readonly
and 2,007 M1 CLI cases per profile.

Owned arguments, aggregate results, suspended/derived exclusive CALL admission
and guest/public reborrow promotion remain gated. Next is canonical owned scalar
array argument copying as a separate transaction slice. Full native, other M2,
Linux, M0, isolation, packaging, native size/stack, allocator and timing are outside
this selection. Local commits only; no push, publication, release or deployment.

Implemented at `29d7dda`. Development and release each passed 30 selected native
groups and 2,495 CLI cases, with 390 identical current input hashes. Compiler,
retained executable, original receipt and matrix/M1 identities were rechecked.
Both profiles accept parser depth32 in check/run and reject depths33/64 with
`compile_limit`. Fifteen core/public/native modules match `d0d66a1`, including
IR, verifier, compiler, VM/core/control, formal reborrow and native primitives.
The readonly CALL module changes only `checked` visibility; its body and the
canonical CALL binding declaration match the baseline. See the
[Windows evidence](../evidence/m2-slice-shared-call-authority-windows-20261102.json).

# Private owned scalar-array arguments in canonical CALLs

The canonical coordinator now accepts immutable scalar-array value arguments,
including calls mixing arrays, scalars, shared slices and exclusive formals. It
extends the [shared argument coordinator](m2-slice-shared-call-authority.md).
Record arguments, aggregate results, suspended/derived exclusive CALL sources
and guest/public reborrow promotion remain gated. Public VM/CLI paths, source
syntax, opcodes and existing logical prices are unchanged.

## Preparation, copying and publication

Immutable CALL inspection validates the caller/function partitions, unique array
formal destinations, exact scalar tags and lengths, immutable source/destination
descriptors and encoded owned sources. Repeated owned sources are legal. Complete
Fuel includes `1 + arity`, the existing `array_call_vm::cost`, and the existing
`65537*(1 + readers + 2*writers)` reserve when any slice is passed. Scalar-only,
shared-only and writer-only prices remain unchanged; copy work is charged once.

Scalar/control preflight remains in `call_frame_vm`. Canonical admission checks
the original frame, maps, tickets and child destinations before staging shared
retention and writer handoff against a local pool. Native authority now exposes
`prepare_call` and `publish_call`; the existing `enter_call` wraps those phases.
Preparation produces one fresh unpublished `Entry` without changing authority.
Publication writes that entry into the existing canonical stack without failure.
State layout, receipt columns, restoration and abort primitives are unchanged.

The invocation-local `Admission` retains the staged pool, fresh entry, retained
shared handles, origins and checked CALL metadata. It does not clone authority or
add a persistent receipt collection. After preparation, unchanged
`array_call_vm::enter` and `array_owners::copy_arguments` perform the last fallible
work. The copier validates all original owners, shapes, bool payloads, descriptor
slots and reservations before writing any byte. Fresh destinations are disjoint
and preserve every existing root/session. Only infallible authority/pool/binding
and scalar/control publication follows success.

These are trusted native, single-use prepare/publish plans. Authority, original
root sessions and inspected IR must stay unchanged between phases; only the
atomic owned copier may intervene. Never retain or reuse a plan across another
loan mutation, callback, invocation or publication. This is not an interface for
untrusted receipt construction. The older readonly-backing `enter` still rejects
owned signatures; `enter_owned` requires mutable owner state and backing.

No payload snapshot or new payload allocation is added to the adapter. Existing
value semantics copy each owned argument into fresh owner storage, including
duplicate sources. A failed late quota/bool/token/descriptor check discards all
staged loans and leaves original payload, owners, tickets, authority, maps and
control state unchanged. Pool exhaustion and writer-generation exhaustion fail
before owned copying starts. This includes a late second shared retain failure.

## Return, abort and bounds

Owned parameters use existing body operations and source-lowered reverse cleanup.
Canonical return continues to reject remaining child-owned tokens before shared
cleanup or writer restoration. Copied parameters must be dropped first; their
storage is reclaimed through the existing owner arena. Shared caller handles and
writer sessions retain the prior coordinator's rules. Owned-only CALLs use empty
Batches while consuming VM and combined restoration depth.

Abort drains loans through the existing mandatory finish, preserving earlier
writes and original outcomes or failed-cleanup metadata. It does not roll back
copied owners or free caller-owned storage. Native callers remain responsible for
disposing owned roots/backing after the outcome, as before. Tests authenticate
retained copied values and prior writer mutations after successful drain.

Program/signature, owner, pool, shared-frame, CALL binding and authority State
declarations do not grow. A temporary CALL description gains an owned count;
one unpublished Admission/Entry stages metadata. The fixed bounds remain eight
arguments, 16 owner descriptors/pool slots, 32 VM frames and 31 combined pending
events. Native size/stack, allocator and performance are unmeasured; prior
inert-view backing remains. Fixed staging is not a memory-improvement claim.

## Verification and next step

```text
python -B tools/verify-m2-slice-elements.py --profile development --owned-call-authority
python -B tools/verify-m2-slice-elements.py --profile release --owned-call-authority
```

The selection covers six new owned-CALL groups plus shared-CALL, scalar-CALL,
canonical-CALL and native authority regression groups. New cases cover all six
scalar tags and wide edges, eight repeated sources, recursive copies/frame reuse,
mixed readers/writers, actual independent storage, exact/one-short Fuel, short
control spans, dirty destinations, late quota/bool/stale-token/owner failures,
late shared capacity and writer generation failure, return cleanup ordering,
unsupported record/result shapes, and abort value/write/error preservation.
Public regression selects 74 mutable-parameter, 222 owned-mutable, 192 readonly
and 2,007 M1 CLI cases per profile.

Next is owned record argument coordination as a separate transaction slice,
before aggregate results and suspended CALL proof. Full native, other M2, Linux,
M0, isolation, packaging, native size/stack, allocator and timing are outside this
selection. Local commits only; no push, publication, release or deployment.

Implemented at `29ddc4a`. Development and release each passed 30 selected native
groups and 2,495 CLI cases, with 391 identical current input hashes. Compiler,
retained executable, original receipt and matrix/M1 identities were rechecked.
Both profiles accept parser depth32 in check/run and reject depths33/64 with
`compile_limit`. Eighteen core/public/native modules match `18d2a87`, including IR,
signatures, verifier, compiler, public VM, shared execution loop, array copier,
readonly adapter, formal reborrow and invocation admission/cleanup. Authority
State and canonical CALL binding declarations, existing scalar/control helpers,
and canonical release/return/abort bodies also match the baseline.
See the [Windows evidence](../evidence/m2-slice-owned-call-authority-windows-20261102.json).

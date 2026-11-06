# Native owning value roots

`value_roots` supplies actual native Buffer ownership for the
[canonical value bytes](value-codec.md). It creates roots internally from borrowed
native input, binds each monotonic nonzero serial to one descriptor and one
invocation-local value location (0..511), and resolves that binding to the retained
allocation in its owning vector. A decoded value word never selects a caller's
Buffer merely because its length/capacity happen to match.

This is a trusted native coordinator interface, not an Engine handle or guest
capability. The coordinator owns the two `Vec<Buffer>` instances and their matching
`State` throughout one invocation. It must not transplant, duplicate, restore or
edit their contents/metadata independently. The copyable State and snapshots do
not confer authority. Existing guest entry points do not admit this domain.

The [native value-buffer kernel](value-buffer.md) adds length/read, initialized-byte
write, reserve and append over these roots. Length/read allow legitimate shared
read leases; every mutation, including no-ops, requires writable ownership.
Successful length/capacity changes refresh the owner and root-row generation while
preserving serial and logical binding; content-only writes preserve generation.
These native coordinator operations do not yet expose a source Buffer API.

The pinned compiler rejects mutable field projection from a resource, so an
opaque resource containing both vectors cannot currently implement this adapter.
The actual roots remain native resources in named coordinator locals. No raw
pointer, unchecked storage, external runtime or Fairy checkout modification is
used. A separate compiler limitation requires the scalar-field Row type used by
the public State's fixed array to be public; a private Row caused an internal
compiler invariant error. This does not make metadata guest authority.

## Movement, retirement and bounds

Both root and removal vectors reserve sixteen elements during setup. Root creation
stages owner admission, allocation, initialized bytes and accounting before
publishing the row. Rejection drops unpublished allocations and changes no live
row/usage/serial. Empty Buffers still cost one 64-byte owner. All subsequent
vector push/pop operations fit the original reservations.

MOVE transfers the actual owning Buffer through `buffer_transfer::handoff` and
restores its vector position before publishing the new value binding. It preserves
serial, descriptor slot/generation, allocation/content, logical usage and peak.
An occupied destination, wrong binding, stale serial or exhausted Fuel cannot
publish another owner. Serial exhaustion retires the allocator instead of
wrapping, including after the final root is dropped.

DROP retires through `buffer_close::begin`, removes the exact owning allocation,
destroys it and only then finishes the charge refund. A bounded secondary vector
preserves the order and identity of every other root when removing a middle
entry. Removal needs at most fifteen tail transfers in each direction and one
selected pop. Global drain removes roots from the tail in reverse creation order,
so it never shifts surviving roots. Repeated drain is idempotent.

Admission checks the full descriptor table, settled ledger, exact root/metadata
charge coverage, unique serials/bindings/token slots, live descriptor coverage and
canonical unused rows before selecting native backing. The selected token and
native initialized length/capacity must also match. These checks detect corrupt
native metadata; they do not authenticate a deliberately transplanted same-shaped
native allocation supplied in violation of the coordinator lifetime contract.

## Private Fuel and accounting

Setup prepays 32768 Fuel, including bounded sixteen-root failure cleanup, before
metadata/quota/backing work. Logical metadata is 4096 bytes, separate from each
Buffer's existing capacity plus 64-byte owner charge. This is policy accounting,
not `sizeof`, allocator overhead or process RAM measurement. Whole Engine/shared
accounting is still pending.

Creation prepays `2048 + 4*N`, checked before multiplication/addition. MOVE and
DROP each prepay 1024. Copy-out prepays `256 + N`. For these prepaid templates,
insufficient Fuel leaves Fuel and all backing unchanged; an admitted invalid
operation spends its template without changing live ownership. The handoff's existing 128-unit template is
included in creation/MOVE, not charged twice. Drain needs no additional guest
Fuel, and native vector destruction frees retained roots on an early coordinator
exit even without an explicit drain. Explicit drain also settles the local
ledger and closes the state. No guest cleanup callback is invoked.

These private templates do not change existing opcode prices, default 256 or
CLI ceiling 16000000. Public source, capability and executable admission remain.

## Verification and integration

Run `python -B tools/verify-value-roots.py --profile development` and the release
counterpart. Five new native groups cover real data/token/charge-preserving moves,
all sixteen roots with distinct payloads, full-table handoff, middle/first removal
and reuse, exact Fuel boundaries and failure drain, quotas, invalid destinations,
maximum serial/exhaustion, stale/double drop and corrupt metadata. Four existing
native handoff groups cover read leases, pending replacement/close, undercounting
and maximum descriptor generations. The runner records exact identities, input
hashes, pinned compiler/profile and captured streams without result reuse or
native compiler overrides.

The [frame successor](value-frames.md) now connects initialized/Dead slots and
activations to these roots; [private execution](value-execution.md) supplies
metered tag/CALL/RETURN. The [source successors](value-source.md) also cover typed
body/control lowering, propagation, conditional values and loops. Source Buffer
byte operations and general aggregate/reference/module/public composition remain
next. Full L04/L05/D01-D04, broader language/runtime/Engine/Instance/host/isolation/
platform/delivery and broad validation remain open.
This root-storage slice alone does not execute typed value IR or expose Buffer
guest source. Local commits only; no push, release or deployment.

Windows development and release each passed all nine final native groups on
`249218f`. All 190 inputs match checkout and Git raw bytes; all 184 production
modules are LF. The static test inventory is 312 files / 1861 annotations. See
the [Windows evidence](../evidence/value-roots-windows-20261107.json) and
[input manifest](../evidence/value-roots-inputs-windows-20261107.json).
Both profiles ran fresh, without native overrides or historical result reuse.
Public CLI/full language/native Fuel matrices, LF mirror builds, Linux, OOM
injection, general stack/performance/RAM and clean-machine delivery were not run.

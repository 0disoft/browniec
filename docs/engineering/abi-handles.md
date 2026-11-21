# ABI handle registry kernel (E02 prerequisite)

This is an implemented internal Fairy kernel, independent of VM/native object
lifecycles and public exports. It is **not full E02**. There is no process-wide
singleton, lazy page allocator, OS lock or TLS identity provider in this slice.
No CLI/embedding gate, opcode, Fuel schedule or existing VM capacity changes.

The accepted baseline is design v0.3.0, chapter 24 (archive SHA-256
`9786d2d2a0d0cd9048a47d17f6fd5c4574cdbcaeec00d17570602fa541b7dc5e`),
[the implementation inventory](../product/04-remaining-work.md),
[the specification](../product/02-spec.md) and revision-2
[header](../../include/brownie.h). The original archive was read as data only;
no reference-model implementation or archive instructions were imported.

## Bounds and identity

`src/abi_handles.fy` stores 64 slots in a caller-owned `Table`. This is a bounded
prerequisite kernel, not a change to the accepted production ceiling of 65,536
slots / 4 MiB including page/index/lock overhead. Fixed initialization of this
small table does not implement the accepted lazy process table. Do not combine
independent kernel tables as pages: their slot namespaces would collide.

A handle uses an x64 `usize`: low32 is a one-based slot, high32 is generation.
Both zero fields, slots beyond 64, free slots and stale generations are rejected
before object access. Kind is stored in the slot (1 Engine, 2 Program, 3 Instance).
Release increments generation; releasing generation UINT32_MAX permanently
retires the slot with generation zero. Free and retired slots retain their
history. There is no clearing, compaction or reset API. A next-unused cursor
and a linked list of reusable rows give constant-time allocation. Free rows
store the next one-based free index in their object field. Each Engine row
records its live child count, so removal checks one count. Retired rows never
enter the free list.

Each live child stores its exact Engine token, including generation. Resolution
requires the expected kind, exact association, a live Engine and the Engine's
thread identity. The kernel returns a nonzero coordinator object **ID**, never
a pointer, and never dereferences native storage. The coordinator owns and must
validate its object-ID mapping; this kernel does not authenticate that mapping,
allocate/free objects or implement Program pins and Instance state.

## Required native coordinator contract

- Own one Table for the DLL lifetime. Do not copy, transplant, reset, serialize
  or recreate live metadata or generation tombstones. `empty()` is first-use
  construction, not recovery. Unload/reload stale-handle checking is unsupported.
- Compute `Identity` internally on every call, never from C/guest arguments.
  `thread` is the actual current OS thread ID; `lifetime` is a nonzero TLS ticket
  unique to that thread lifetime for this registry lifetime, with no wrap/reuse.
  OS ID reuse alone cannot recover ownership. Zero components are rejected.
  The kernel compares these values; it does not obtain or verify OS identity,
  observe thread exit, transfer ownership or adopt dead-owner objects.
- Protect **all** Table reads and writes, including creation, admission,
  publication, leave and removal, with one process-wide OS lock. Hold it only
  for these bounded metadata operations; never run guest code, user callbacks,
  allocation of native objects or OS I/O under it. This slice has no lock and
  no cross-thread/process race evidence. A Fairy `ref mut` is not an OS lock.
- Keep the Engine busy admission across unlocked native/VM work. Every normal
  or failed coordinator exit must either `leave` or successfully `remove`.
  An invalid request/foreign caller must not resolve or free a native object.
  An asynchronous host failure/unwind still needs its coordinator cleanup path.
- Admissions are trusted, copyable, internal receipts. Do not expose, forge,
  modify or transplant them. The kernel rechecks live identity, object ID and
  epoch; it does not turn receipts or the public mutable Table into unforgeable
  capabilities. C callers supply only opaque handle integers.

Until these contracts have real native implementations, calling the kernel with
arbitrary external identities or concurrently is unsupported. The separate [Windows guard/TLS primitive](abi-thread-identity.md) now supplies
real OS identity and synchronization. The [internal coordinator](abi-registry.md)
now wires this exact kernel to it; actual native object lifecycles remain separate.

## APIs for lifecycle integration

All fallible APIs return `Result<T, Error>`. `status` maps BadArgument=1,
InvalidHandle=2, Busy=3, State=7 (internal error), ResourceLimit=8,
WrongThread=10. These internal helpers are not `bc_*` success stubs or exports.

| API | Behavior |
| --- | --- |
| `empty`, `capacity`, `*_kind`, `generation_max` | Construction and kernel constants |
| `slot_index(handle)` | Bounds/zero-field decoding only; **not** live-handle validation |
| `create_engine(table, caller, object)` | Publish an already-prepared Engine object ID into a free slot |
| `enter(table, target, kind, engine, caller)` | Validate target/kind/exact Engine/lifetime; acquire Engine busy guard and return Admission |
| `enter_instance(table, instance, caller)` | Infer the stored Engine for Instance APIs, then use the same admission path |
| `insert_child(table, admission, kind, object, caller)` | Publish Program under Engine admission, or Instance under Program admission; retain admission |
| `leave(table, admission, caller)` | End exactly the active epoch; release busy on success or coordinator rollback |
| `remove(table, admission, caller)` | Invalidate target, advance/retire generation, consume admission and return its object ID |

Kind/generation/association/thread validation precedes busy checks. Reentering
any target of the same Engine returns Busy; separate Engines can be admitted
independently. Foreign lifetime on a busy Engine returns WrongThread. Failed
operations do not change any slot, busy guard or counter. A failed child insert
retains the original admission so the caller can roll back native preparation
and leave. Successful child insertion also retains it until leave/remove.

Admission epochs are table-wide nonwrapping x64 serials. A completed receipt
cannot clear a later admission, and duplicate leave/remove fails. The last
serial UINT64_MAX may complete; subsequent admissions return ResourceLimit
without mutation. This extreme limit fails closed, including new cleanup
admissions: no reset/recovery is provided. The coordinator must treat exhaustion
as a process-lifetime limit, rather than recycling receipts or bypassing checks.

For Engine creation, construct the native object first outside the registry
lock, then publish with `create_engine` under the lock. If registry publication
fails, destroy the unpublished object outside the lock and issue no C handle.
For compile/Instance creation, admit the Engine/Program first, prepare native
object/pins/quota outside the lock, publish under the lock, then leave. On native
OOM or rejected publication, undo unpublished resources and leave. C out handles
must stay zero until the complete coordinator commit; do not expose provisional
objects. These are follow-on integration rules, not exercised native OOM claims.

`remove` is registry metadata invalidation, not native destruction. The caller
must enforce Program/Instance pin dependencies and prepare safe native cleanup.
Engine removal fails Busy while any live child remains; it does not cascade.
Remove children explicitly after native cleanup obligations are satisfied, then
remove the Engine. Removal clears only the target and its Engine admission.
The API does not implement E03 Program pin/release semantics or Engine poison.

## Focused native verification

After integrating the four new files, refresh only the integration checkout's
source lock once. The following commands reproduce standalone verification:

```text
build/toolchain/fairyc.exe check
python tools/verify-abi-handles.py --profile development
python tools/verify-abi-handles.py --profile release
```

The verifier checks the pinned compiler SHA-256, refuses compiler/linker
injections, runs root `check --locked`, and freezes raw hashes for every
production module, the single test file, manifest/lock/toolchain and verifier.
It constructs a byte-identical selected-test workspace under its own build
output because the compiler otherwise checks all tests before selecting them.
The whole production tree is frozen for provenance, but this kernel imports no
other production module. If integration adds only disjoint modules (for example
`host_wire`) and refreshes the root lock, retain the delivered kernel native
receipts and run the integration root check. A duplicate native run is needed
only if the kernel/test code, compiler/SDK/target or native build assumptions
change, or a concrete integration failure calls that evidence into question.

Ten native groups run per profile, requiring exact identities, verified lock,
no traps and empty process streams. Receipts/logs are in
`build/abi-handles/{development,release}`. Native test executables are temporary
compiler artifacts; receipts do not claim persistent PE hashes or stack probes.

Coverage includes malformed wire fields, wrong kind, stale/reused handles,
exact/wrong/stale Engine, OS-ID/lifetime mismatches (synthetic), same-Engine
reentry and independent Engine admission, receipt reuse/duplicate leave,
wrong-thread release, payload/epoch tampering, zero object/identity, exact
capacity and failed-publication rollback, UINT32_MAX retirement/tombstone
retention, child-blocked Engine removal, and admission serial exhaustion.

The rollback tests compare every slot field and the admission counter. Native
OOM before publication is modeled by leaving an admitted operation without
insertion; real allocation injection is outside this allocation-free kernel.
OS thread/exit/reuse/race tests, process lazy paging/budget accounting, native
object lifetimes, VM/public DLL calls, full test tree, Linux and packaging are
not verified by this suite. Earlier ABI bootstrap evidence retains its scope.

### Executed mirror evidence

On the archive-derived `8ef789ab334b80d54bb4a549ef61e3a88806403d` mirror,
Windows x64/MSVC development and release each passed all ten native groups.
`fairyc check --locked` passed 226 sources / 2472 MIR functions. Each receipt
freezes 223 raw inputs (218 production modules), with compiler SHA-256
`9651623adbb6e05e0f948b826431853df310050387c955aee77ac0b12a81ab7a`.
The refreshed **mirror-only** lock SHA-256 is
`30c4f58a096b7ff5fea43e1fa9b47d4494eee1f96c079e3ed41871debf469f03`.
The integration patch deliberately excludes that lock and all shared checkpoint
files; the integration owner keeps its disjoint module/lock changes.

| Profile | Native result | Elapsed | Raw receipt SHA-256 |
| --- | --- | --- | --- |
| development | 10 passed, 0 failed | 70.115 s | `e07a41326e4dcf879ad8c932538b0017838c5749508c373830f707e4c02fc236` |
| release | 10 passed, 0 failed | 75.468 s | `2f8f28ed2566b74a7116236ae3b5d62e72dfbd4cbbfc77fe3b6abd0b0efbe40b` |

The delivery manifest beside the mirror's build outputs records exact new-file,
patch, source-lock and native-log/receipt hashes. These are local native kernel
results, not full E02, OS synchronization or public ABI execution evidence.

Main integrated the unchanged kernel/tests/verifier in `fef9fd3` and refreshed the
root lock. The root check passed 227 sources / 2487 MIR functions. All 218 worker
production modules remain byte-identical; only the disjoint `host_wire` module
and resulting lock differ. The [recorded kernel evidence](../evidence/abi-handles-windows-20261107.json)
retains both ten-group native reports without duplicating import-free tests.

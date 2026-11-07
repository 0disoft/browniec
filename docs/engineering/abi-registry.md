# Internal Windows ABI registry coordinator

The internal C coordinator now calls the actual compiled Fairy handle kernel
under the real Windows guard/TLS identity helper. It owns one bounded, lazy,
nonresettable module registry. This is executable coordinator evidence, not an
Engine/VM implementation, public E01 ABI or completion of full E02.

The starting checkout is `f83436ee555b558aee02ed68d263c179c365a68c`.
Before freezing or running native tests, the identity helper was replaced with
the reviewed successor from `5618726e537f14c2db6c2eb925297a3db4c17b25`.
That successor checks the current TLS ticket again on guard leave. The patch
does not include the helper changes or alter the existing Fairy kernel.

## Ownership and bounds

`native/abi_registry.c` owns one static pointer to a 3,080-byte Fairy Table.
The first create-Engine attempt allocates and commits 4,096 bytes with
`VirtualAlloc`, initializes the Table through compiled `abi_handles::empty`,
and publishes it under the identity helper's exclusive SRW guard. Even a
subsequent rejected object ID may leave this one-time metadata allocation in
place; it does not publish a handle. Other operations before that first attempt
return InvalidHandle without constructing a Table. Inspection does not allocate
a Table, although it may initialize the OS helper's TLS identity machinery.

Exactly 64 slots share one namespace. Initialization happens once; allocation,
free-slot selection, generations, retirement, kind, exact Engine association,
caller identity, busy epochs and child-blocked Engine removal are decided by
compiled Fairy. C does not reproduce those algorithms. Releasing the final
handle never frees/reinitializes the Table or discards tombstones. There is no
reset, native generation accessor/injector or state-mutation test hook.

The 4,096 figure is committed metadata, not whole-process RAM or reserved virtual
address space. Windows reservation granularity can reserve a larger region
(normally 64 KiB), and OS helper/CRT/image/thread overhead is separate. Native
slot size is 48 bytes; the generated transport asserts all relevant sizes and
offsets. Coordinator trap bookkeeping is bounded static data protected by the
same guard; it adds no separate per-thread TLS allocation. There is no complete
4 MiB process accounting ledger or 65,536-slot lazy page implementation here.
The accepted production ceiling is unchanged; this is the existing 64-slot
kernel connected to real serialized module ownership.

Link exactly one registry object and one identity-helper object into the owning
module. Every caller of this coordinator shares that state. Independent copies
in different DLLs do not become a single process registry; cross-module sharing
must route calls to the same owner. Unload/reload stale-handle validation,
thread-owner adoption, teardown recovery and abandoned-owner reclamation are
unsupported. The host must end in-flight calls and retire its objects before
unload. Tests with deliberately exited owners terminate their isolated process;
they do not claim a safe recovery/destruction path.

## Internal API

The header is an internal C boundary, with no public export annotations and no
planned `bc_engine_create` or other E01 success stubs. Object IDs are nonzero
trusted coordinator integers, never cast to or followed as object pointers.
The native host tests UINT64_MAX and other invalid-address-shaped IDs end to end.
The caller owns real object preparation, object-ID mapping, pins and cleanup.
These wrappers do not create, execute or destroy a native Engine/Program/Instance.

| Function | Result on success |
| --- | --- |
| `bc_abi_registry_create_engine(object, out_handle)` | Publish a prepared Engine object ID |
| `bc_abi_registry_enter(target, kind, engine, out_admission)` | Admit the exact target/Engine and hold Engine busy |
| `bc_abi_registry_enter_instance(instance, out_admission)` | Resolve/admit the stored owner of an Instance handle |
| `bc_abi_registry_insert(admission, kind, object, out_handle)` | Publish Program under Engine admission, or Instance under Program admission |
| `bc_abi_registry_leave(admission)` | End the exact busy epoch; retain all handles |
| `bc_abi_registry_remove(admission, out_object)` | Invalidate target, advance/retire generation and consume admission |
| `bc_abi_registry_inspect(out_info)` | Read capacity, Table size, committed metadata and allocation count only |

`bc_abi_registry_admission` contains target/engine/epoch u64 words, kind u32,
reserved u32 and object u64, with size 40 and object offset 32. Reserved must be
zero, and successful marshalling initializes it to zero. This receipt is trusted
internal metadata, not an externally forgeable capability. Do not modify or
transplant it; saved copies cannot end later epochs. No caller can supply thread
identity: each operation obtains the real OS ID and nonreused TLS lifetime from
`bc_abi_guard_enter`. Zero/wrong/stale arguments reach the same Fairy checks as
the kernel except for C null/reserved-field marshalling and an absent lazy table.

Results use the existing numeric meanings: OK=0, BadArgument=1,
InvalidHandle=2, Busy=3, AllocationError=6, internal invariant=7,
ResourceLimit=8, WrongThread=10. SRW contention and same-thread guard reentry
return Busy immediately; wrappers never wait or retry. The test host alone
retries contention outside the guard when it expects a non-Busy result.

Trusted callers provide readable input receipts and writable output storage.
Arbitrary C pointers cannot be made valid by this registry. Every ordinary
failure leaves all supplied output bytes untouched; inputs are snapshotted and
results are marshalled into local candidates, published only after success and
OS guard release. There is no public out-handle-zero-on-entry contract here.
No C output pointer or opaque object ID is stored in the Table.

## Guard release and native work

Every successful OS guard acquisition reaches the shared `finish` path on
normal return, including missing Table, allocation failure and Fairy errors.
Pre-acquisition failures own no guard. `finish` releases only the OS guard:
**it does not leave the Engine admission**. Busy remains set while callers do
unlocked native work. Foreign-thread and stale receipts cannot clear it.

Hold the guard only for bounded metadata, its one-time allocation/initialization,
and compiled Fairy calls. Never run VM code, invoke a callback, wait for an
application operation or perform host I/O under it. The native tests yield while
an Engine admission is active and let other Engines advance concurrently.
For creation, prepare real native objects outside this guard, publish their IDs,
then leave the admission. On preparation/publication failure, roll back native
resources outside the guard and leave the original admission. Failed insertion
and child-blocked removal preserve that admission. Program pins and safe native
cleanup are still the calling lifecycle layer's responsibility.

Unexpected generated traps release the guard when the native state remains
healthy enough, then fail fast at process level. A failed guard-release invariant
also terminates the process. This is not an exception/unwind recovery guarantee
for native corruption, thread termination or asynchronous faults. Ordinary
argument/resource failures take the normal released-guard return path.
The kernel's nonwrapping admission-epoch exhaustion still fails closed,
including new cleanup admissions; this coordinator does not reset that limit.

## Private generated C binding

Only `src/abi_handles.fy` plus the explicit retention root
`tools/abi-registry/main.fy` enter the isolated Fairy package. Its manifest uses
`browniec.abi-registry`; the package lock has one package, no dependencies and no
stdlib or CLI modules. The retention main exists only to retain helper roots and
is not invoked by the C coordinator or native host.

`tools/abi-registry/transport.json` records all 23 private function bindings,
result tags and generated types/layouts. The builder verifies pinned compiler,
raw kernel/retention/helper bytes and the complete generated 81,874-byte unit:

```text
compiler SHA-256: 9651623adbb6e05e0f948b826431853df310050387c955aee77ac0b12a81ab7a
transport SHA-256: c424daab534cc50130704dc824970802915cded8265820403478b49a76e3a5bb
TLS helper C SHA-256: a81ff7c986ed7c2c1ade2e7506ed253bd5ec78602da53e5df92d4ffdb0953cad
TLS helper H SHA-256: 982becbdcc9310ba557a6e8e52861ffd8e24de19a9ec8125786d4199fcb08e6a
```

Do not silently rebind `fy_fn_*` names after a compiler/kernel/retention change.
Regenerate and review the whole transport and binding. Compiler-internal C is
neither a stable public ABI nor a freestanding public compiler product.

## Commands and executed evidence

```text
python tools/build-abi-registry.py --output build/abi-registry-final
python tools/abi-registry/test_rejections.py --output build/abi-registry-rejections
```

Use fresh output directories. Optional repeated `--kernel-receipt PATH` retains
prior native generation-exhaustion evidence after checking compiler, raw kernel
and raw test hashes; it does not rerun or mutate those tests. The delivered run
retains the development/release ten-group kernel receipts. No production
mutation hook is added to force generation exhaustion at the coordinator layer.

The native builder freezes eleven inputs, generates/checks only its own package
lock, then compiles separate coordinator, production identity helper and C-host
objects using MSVC 14.51.36231 / SDK 10.0.26100.0. Both `/Od` and `/O2` passed four
fresh-process scenarios each with a cleared environment and empty tool PATH:

- Basic: every wrapper, malformed/stale/wrong-kind/Engine arguments, real foreign
  thread rejection, same-Engine reentry across unlocked work, independent Engine
  admission, stale/duplicate receipts, child-blocked removal, untouched failure
  outputs, reserved-field admission, success canaries and opaque object IDs.
- Capacity: exactly 64 slots, rejected insertion/creation without output
  publication, rollback leave, complete release and generation reuse while the
  one metadata allocation remains.
- Concurrent: eight actual threads race first creation and complete 128
  Engine/Program/Instance cycles. Exactly one lazy allocation remains; admission
  work outside the guard does not prevent other Engines advancing.
- Lifetimes: 32 sequential exited owners remain inaccessible to later threads
  and the main thread. Numeric Windows thread ID reuse observed in this run was
  **zero**; no claim of forced/reproduced OS ID reuse follows. TLS successor unit
  evidence and unchanged kernel lifetime tests retain their separate scopes.

Both retained host PEs use default stack reserve 1,048,576 / commit 4,096.
`dumpbin` on every compiled object confirms absence of identity-test mutation
controls. The builder's three negative controls reject an altered full transport,
changed kernel bytes and an empty LINK override before any native object exists.

Final native receipt SHA-256:
`def1aabcbaae41b1abb8a8492d352585046adf815eae4bc898897f2e77513cf6`.
The delivery manifest records each new file, patch, source/helper identity,
retained PE/object, native log/receipt and build-control hash.
No root source/Git/lock/checkpoint was written. The patch contains only the new
coordinator/header, builder, retention/binding/control files, C host and this doc.

Not verified/implemented here: allocator/TLS failure injection, actual native
object cleanup/pins, Engine poison, VM/public DLL execution, accepted-scale page
allocation/accounting, multiple DLL copies as one process registry, Linux,
clean-machine packaging or full E02/E01 availability. Existing CLI gates,
opcodes, Fuel schedules and VM capacities are unchanged.

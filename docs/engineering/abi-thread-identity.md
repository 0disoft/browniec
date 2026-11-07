# Windows registry guard and thread identity

`native/abi_thread_identity.c` is an internal OS primitive for the future ABI
coordinator. It supplies short serialized registry access and authenticated
current-thread identity. It does not implement a registry, Engine lifecycle or
public DLL export, and is not yet connected to `abi_handles.fy`.

`bc_abi_guard_enter` uses `TryAcquireSRWLockExclusive`: contention or same-thread
reentry returns Busy immediately. The first admitted call lazily allocates one
Windows TLS slot under the guard. Every new thread lifetime receives a unique
nonzero u64 ticket, stored as an opaque TLS value without allocating or following
an object pointer. Calls on the same thread retain their ticket. New threads
receive new tickets even if Windows reuses their numeric thread ID.

TLS values disappear with the thread. The process/module lifetime counter never
wraps or resets: UINT64_MAX is usable once, then new identities return
ResourceLimit. Existing identities remain usable. A failed TLS write consumes
its ticket before returning AllocationError; it never makes that identity
available again. TLS allocation failure releases the guard. Every failed enter
leaves caller output untouched. NULL output returns BadArgument.

Successful enter returns the real OS thread ID and TLS lifetime ticket and owns
the guard until `bc_abi_guard_leave`. Leave checks the current thread and live
guard identity through atomic OS operations before releasing; foreign-thread,
wrong-ticket and duplicate leave reject without releasing another owner's guard.
This is a trusted coordinator API: call leave only after a successful enter and
do not reuse identity values as public authority or unforgeable admission epochs.
The Fairy registry separately validates handle generations and admission epochs.

The protected interval must cover bounded registry metadata access only. Do not
run guest code, allocate native objects, invoke callbacks, perform host I/O or
wait for another operation while holding it. Native object creation/cleanup and
Engine busy admissions must be coordinated outside this guard. Abandoning a
thread while it owns the guard is not a recoverable lifecycle mechanism.

The one TLS slot and monotonic state remain until process/module teardown.
Unload/reload with live handles or in-flight calls is unsupported. A single
future DLL coordinator must own the single registry and guard; independently
copying this source into several modules does not make their registries shared.
Lazy Fairy table allocation/accounting and actual API integration remain open.

`python tools/verify-abi-thread-identity.py` compiles production and test objects
using standard MSVC/SDK paths and default stacks, in development and optimized
profiles. The test-only exhaustion control is absent from each production object.
The native host checks eight concurrent threads with 1024 deliberately ordinary
guarded counter increments, 32 sequential terminated-thread lifetimes, stable
current identity, distinct tickets, reentry/contention, rejected leaves, untouched
failure outputs and final-ticket exhaustion. Sequential-thread evidence does not
claim that Windows happened to reuse an OS thread ID during this run.

Both profiles execute with an empty tool PATH. This is real OS thread/lock
evidence for the shim; synthetic kernel identity tests remain separate. No full
E02 synchronization, public embedding, cancellation or Engine/Instance execution
availability follows until the actual coordinator connects them.

Implementation `f83436e` passed both native profiles. The [recorded OS evidence](../evidence/abi-thread-identity-windows-20261107.json)
binds all five feature inputs to checkout/Git bytes, production/test objects,
actual host commands and default PE stack metadata.

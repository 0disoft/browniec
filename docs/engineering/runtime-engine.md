# Private owning Engine lifecycle

`src/runtime_engine.fy` now owns real immutable executable
Programs and one-shot Instances. This succeeds the [owning Store probe](runtime-store-probe.md).
`compile` consumes an admitted selected source Entry and invokes the existing
complete `module_program::compile`; execution invokes `module_program::run` on
that retained executable with fresh VM state. It does not launch build tools.
The explicit native module location keeps this private transport outside the
ordinary CLI, which does not yet link or expose Engine operations.

[Control-storage accounting](runtime-engine-control-memory.md) now preflights
actual fixed backing and reserves vectors for the admitted counts. Its evidence
supersedes earlier fixed-64 storage and transport counts.

[Retained-program admission](runtime-engine-program-memory.md) now also preflights
actual source/IR/image storage, preserves released pins and enforces individual,
set and combined control/Program limits. Total Engine accounting remains incomplete.

## Implemented lifetime

An Engine owns its Program vectors and Instance vector, bound to the actual
Windows thread ID and nonwrapping TLS lifetime ticket. A Program owns its real
compiled code, source context and any immutable image backing. Instances pin that
Program. Release hides the Program from new Instance creation; the last Instance
destruction reclaims a released Program. Unreleased Programs require explicit
release. Destroy rejects live Programs or Instances. Successful destroy returns
the seven empty vector allocations immediately, before the owning scope ends.
Normal owning-scope cleanup also releases live children. Child IDs are scoped
to this exact Engine; they are not public handles
and cannot authenticate an association with another Engine.

An Instance starts Ready. `execute_once` runs it synchronously and retains a
Done or guest-error event. A terminal Instance cannot execute again (status 11).
`cancel_ready` changes only a Ready Instance to terminal Cancelled; observing or
cancelling a terminal Instance preserves its first event. Destroying an Instance
releases its pin. This does not yet implement resumable execution, cancellation
during guest work, host suspension or deadline delivery. The
[current input successor](runtime-engine-inputs.md) adds actual owning input
Programs and Instance Snapshots to the same lifecycle.

Program and Instance limits are independently admitted in 1..64; they are count
ceilings, not complete memory quotas. The admitted Fuel ceiling is 1..16000000;
an Instance may request zero Fuel, with normal guest exhaustion on execution.
Object IDs and admission epochs use their final nonzero value once, then reject
further allocation/work admission with status 8 rather than wrapping. Exhausted
admission still permits bounded release/destroy/observe/cancel/inspect under the
native guard, without issuing or reusing an epoch. Compilation, new Instances
and guest execution remain denied. Existing terminal results and teardown survive.
Private statuses also distinguish bad argument 1, missing/released/closed 2,
busy 3, source diagnostic 4, Fuel limit 5, native allocation 6, integrity 7 and
wrong thread/lifetime 10. These are private transport results, not new ABI values.

## Teardown containment

Program release checks its recorded pin count against the live Instances.
Immediate reclamation and last-pin destruction also reconcile the Program
ledger and check the reserved scratch slots. Instance destruction validates
the combined payload ledger, input and output associations, and input capacity
before changing any pin or moving an owner. The scans are bounded by the
Engine's 64-Program and 64-Instance limits.

An invariant failure returns status 14, preserves existing terminal events and
quarantines further guest work. Teardown operations can still reclaim owners
whose preconditions hold. The owning Engine scope can drop the remaining
resources if a persistent invariant fault prevents explicit teardown.

The native verifier injected a pin mismatch during release, a missing empty
Snapshot during Instance destruction, and a Program charge mismatch during
last-pin reclamation. All three returned 14 without allocating, altering
pins or debiting current charges. A prior successful result remained stable.
Teardown succeeded after each injection cleared. Development and /O2 both
exited with zero live SDK allocations. Local receipt:
`build/runtime-engine/20261120T230400658164Z/receipt.json`.

## Typed native boundary

The pinned compiler cannot safely project a mutable nested resource field using
ordinary Fairy syntax. The synchronous `bridge.inc` projects actual emitted
fields and calls typed Fairy helpers. Fairy owns admission, compilation,
publication, pins, execution, cleanup and all lifecycle decisions. No manually
copied resource layout or byte offset is used. The existing
[OS identity guard](abi-thread-identity.md) protects admission and the exhausted
maintenance path; it is released during compile/run. An active epoch rejects
concurrent/reentrant entry without inspecting incoming source storage. Completion
checks the actual current OS thread against its captured admitted owner, then
authenticates that lifetime and exact epoch without reacquiring the global guard.
This synchronous no-callback interval cannot transfer its thread lifetime. Thus
contention from another Engine cannot turn a committed operation into Busy or
strand its active epoch. Wrong-thread admission reads immutable owner fields and
returns before mutable state; all dispatch/completion mutation is owner-only.
No native pointer/borrow escapes an operation.

`retain_native_bindings` is the dedicated fixture's typed-helper retention root;
its markers do not publish objects or execute guests. The test host, exhaustion
seeding and heap observation are separate from `bridge.inc`. The private C entry
points require valid live Fairy-owned pointers; hostile raw-pointer validation
belongs to the still-open outer handle/ABI layer.

`transport.json` freezes the reviewed source closure, pinned compiler, complete emitted
C hash, reviewed helper/type mappings and seven exact runtime Git objects. Any
closure/compiler/source change fails before native build until those mappings
are deliberately reviewed. This is an internal compiler transport, not a stable
C ABI. The root compiler/lock, normal public gates, capacities and Fuel prices
are unchanged.

## Focused verification

Run `python tools/verify-runtime-engine.py` on Windows AMD64. Both development
`/Od` and release `/O2` run by default; `--profile` selects one. The pinned
`build/toolchain/fairyc.exe`, MSVC/Windows SDK, Python and Git are required.
`--fairyc-repository` can locate the repository containing the exact pinned
runtime objects. The verifier never modifies or builds that repository.

The actual native fixture verifies:

- One source Program reused by two Instances, each returning 42 from its own
  initialized and incremented array; another Instance traps at zero Fuel.
- Release while pinned, new-Instance rejection, non-last and last-pin destruction,
  stale IDs, terminal replay rejection, cancellation before division and stable
  terminal observation.
- Real source-error diagnostics without publication, count/Fuel rejection and
  successful subsequent compile/cleanup.
- A byte-image Program released while pinned, whole-Engine move, actual byte
  access returning 42 and final image/code cleanup.
- Real Windows wrong-thread calls, busy entry before a poisoned incoming pointer
  can be inspected, stale/live epochs, completion while another thread holds the
  global guard, and live-child maintenance after admission exhaustion.
- Four Programs, middle/front removal through scratch, execution of surviving
  relocated byte images (42/43), and scope destruction with a live image/Instance.
- Immediate empty-storage release and zero live SystemHeap allocations at exit.

The [recorded evidence](../evidence/runtime-engine-windows-20261107.json) passed
both profiles with empty tool PATH and the actual default 1MiB/4KiB PE stacks.
Logs, complete commands, emitted C, runtime objects, binaries and receipt remain
under `build/runtime-engine/<UTC-run>/`. Input hashes are checked before and after
execution; the isolated lock and root lock are unchanged.

R01 remains partial: public generation-handle association, complete policy/run
binding and the accepted runtime API remain open. R02-R05 still need complete
reservation/accounting and OOM injection, bounded VM steps, OS deadlines,
in-flight cancellation, poison containment and host/output integration.
This check is native lifecycle evidence, not an independent model or completion
of those obligations. Broader unchanged CLI/language suites were not rerun.

## Input-VM compatibility successor (2026-11-07)

The [input execution integration](module-input-execution.md) adds the private
input-window module to this Engine's import closure. The reviewed transport now
covers 185 modules, `Engine = fy_resource_16` and incoming Entry vector
`fy_resource_28`. All eight bound C declarations, Engine/meta/vector/Entry field
projections and vector element resources were compared against the unchanged
pinned compiler's actual emitted C. Logical types and `bridge.inc` are unchanged.

Both native profiles passed the existing real source/reuse/image, OS guard and
exhaustion/teardown fixture with default stacks, empty tool PATH and zero live
heap allocations. Integration reused those hash-matching mirror results rather
than rebuilding identical inputs; all 195 executed inputs match final root.
See [current compatibility evidence](../evidence/runtime-engine-input-execution-windows-20261107.json).
This preserves the existing zero-argument Engine path; associating input Programs
and Snapshots to Instances remains the next implementation, not a completed ABI.

## Instance-owned input successor (2026-11-07)

The [input lifecycle](runtime-engine-inputs.md) now retains separately admitted
input Programs, consumes exact immutable Snapshots into owning Instances and
executes their real bytes synchronously. Windows disk/pipe input reaches the VM
after original handles close, through the explicit
[Fairy Snapshot adoption API](runtime-input-adoption.md). Input terminal events
retain [actual committed remaining Fuel](module-input-completion.md) on both
success and failure. Wrong execution APIs preserve Ready, and released pins,
move/relocation, cancellation and owning teardown retain their lifecycle rules.
The public CLI/C ABI, complete accounting and bounded runtime remain open.

The [current executed evidence](../evidence/runtime-engine-owned-input-windows-20261107.json)
passes development and O2, 12 reviewed typed bindings over 189 modules, eleven
new logical groups plus the unchanged lifecycle fixture and zero SDK heap leaks.

## Guest-output successor (2026-11-07)

[Engine output ownership](runtime-engine-outputs.md) now separately admits
output Programs, binds input and output configuration to Instances, executes
canonical guest emit with the actual shared Fuel balance, and retains or moves
successful immutable output once. Failed execution carries no published prefix.
Its development/O2 evidence supersedes earlier transport/module counts: 17 typed
bindings, 195 closure modules, eight new output groups plus the existing input/
lifecycle/OS fixtures and zero live SDK heap allocations. Seven vectors are now
reserved and reclaimed. Full policy/public association and bounded runtime remain.

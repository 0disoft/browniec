# Engine-owned guest output

The private owning Engine now integrates the separately admitted
[guest-output Program](module-output-execution.md). It compiles exact selected
zero-argument or shared-byte input entries, executes the real VM once, retains
its terminal result and moves immutable successful output to the caller.
Public CLI/C handles, policy loading and sinks remain separate work.

## Admission and execution

`compile_output` and `compile_input_output` consume the corresponding owning
Entry. They do not relabel ordinary/input Programs as output-capable code.
`create_output_instance` supplies budget, byte limit and an explicit native grant;
`create_input_output_instance` additionally consumes the exact input Snapshot.
The limit is at most 1 MiB. A denied grant still allows code with no emit; an
empty emit requires the grant. Full immutable policy/run/grant binding remains
open; source metadata cannot enable emission.

`execute_once` borrows the Instance's exact input owner and retained Program,
changes Ready to Running, then records the original terminal value/diagnostic
and actual remaining Fuel. It retains an owning `Execution` for either VM
success or guest failure. Only success plus final seal carries published bytes.
No failed prefix, staging transaction or seal authority escapes. Observe and
cancel preserve the first terminal event; no second invocation reconstructs
Fuel or output. Wrong execution API rejects before consuming Ready.

## Ownership and extraction

`take_output(engine, instance)` first reserves the caller's single result slot.
An allocation failure changes no Engine association, terminal event or bytes.
Ready returns status 11; a missing, cancelled or already-taken record returns 2.
It then moves the complete `Output` resource once, without copying payload or
allocating after detachment. Removing a middle/front record uses preallocated
scratch and restores all peer owners. The terminal Instance can still be
observed after extraction.

`output_completion`, `output_available` and `output_view` borrow the retained
Output. The view is tied to this exact resource, including its empty case.
Failed execution has a transferable completion but no available output and an
empty view. Successful empty publication is available and distinct from failure.
The caller's Output survives Program release, Instance destruction, Engine move
and Engine destruction; its own owning cleanup ultimately reclaims the bytes.
Untaken output is reclaimed with the Instance or Engine scope.

Output extraction remains bounded owner maintenance after admission epochs are
exhausted; it cannot run guest work or reuse an epoch. Owner-thread, reentry and
closed-state checks precede native incoming/outgoing storage inspection. No
callback is introduced. This is a synchronous private API, not public pointer
validation, in-flight cancellation or restricted-worker output delivery.

## Reserved storage and native evidence

Engine creation now reserves seven vectors: Programs and scratch, Instances,
inputs and scratch, outputs and scratch. Each is bounded to 64 entries. Successful
empty Engine destruction releases all seven immediately. These are count caps
and reserved descriptor storage, not complete Engine memory/work accounting.
The focused creation seam fails all seven allocations and requires zero leaks.

`python tools/verify-runtime-engine.py` checks the pinned compiler and closure,
locked generation, emitted transport hash and all 17 reviewed C declarations.
The native bridge uses actual emitted Engine, Entry, Snapshot and Output-vector
types and typed field projections. It does not forge an owning descriptor.

[Executed evidence](../evidence/runtime-engine-outputs-windows-20261107.json)
records development/O2 native execution, 195 closure modules, 17 bindings and
default 1 MiB / 4 KiB stacks. Both images execute eight new output groups, eleven
existing input/allocation/OS groups and the unchanged original lifecycle fixture.
Every output group and final scope require zero live SDK heap allocations.

The new groups cover take-once/detached lifetime, denied versus granted/no-emit
execution, exact owning input and moved Engine, middle/front record removal,
failed prefix and cancelled absence, exhausted-admission extraction, outgoing
allocation rollback, and implicit cleanup with live children/untaken results.
Wrong-thread and busy native calls also use deliberately invalid storage pointers
to prove admission precedes projection. Existing disk/pipe and OS guard tests
remain in the same executable.

All 207 executable/source/tool/config inputs match their executed identities.
One additional transport JSON input has an explicit post-run metadata review:
its unused documentary `outputType` was corrected from BoundInput to the actual
emitted Output type. Bridge typedefs, all declarations and generated/native code
are unchanged; the evidence preserves both JSON hashes and the actual declaration.
No native rerun is claimed for that documentary correction.

Full peak accounting, bounded resumable steps, deadlines, in-flight cancellation,
poison containment, public handles/policy, host dispatch, sinks, restricted
workers and embedding remain in [the inventory](../product/04-remaining-work.md).
External effects are not rolled back or replayed by staged-output failure.

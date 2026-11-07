# Input Programs and Instance-owned snapshots

The private owning Engine can retain both real zero-argument Programs and
separately admitted `module_input_program::Program` resources. They share one
Program count, object-ID sequence, pin/release policy and owner-thread guard.
Their owning vectors are distinct; no input signature is relabelled as an
ordinary Program, array lease or literal-image authority.

`compile_input` consumes the exact selected `module_input_entry::InputEntry`,
invokes its complete compiler/verifier and retains its original source context.
Admission precedes inspection of native incoming storage. Compilation failure
publishes no Program and preserves the original source diagnostic.

## Owning input lifecycle

`create_input_instance(engine, program, snapshot, budget)` consumes an immutable
`runtime_input::Snapshot` into an association with that exact Instance ID. It
requires a live input Program, count/Fuel admission and an unused nonwrapping ID.
The Snapshot keeps its actual owning Buffer; the operation neither copies the
payload nor stores a pointer into caller-owned storage. Admission failures
destroy the consumed incoming owner without publishing an Instance or pin.

`execute_once` borrows the associated Snapshot throughout the synchronous native
invocation. Ready becomes Running before entering the VM, then terminal only
after VM ownership cleanup. The input cannot be substituted by passing another
Snapshot. Program release prevents new Instances while existing pins remain
executable. Engine move and Program/input-vector relocation preserve owners.
Instance destruction drops the input even after cancellation or guest failure;
normal owning-scope destruction also drops all live children. Destroying the
empty Engine immediately returns all five reserved vector allocations.

A separately explicit convenience path, `create_instance` followed by
`execute_input_once`, borrows the caller's Snapshot synchronously and retains no
input pointer. It rejects an already-bound input Instance. Using the wrong
execution API rejects status 1 before changing Ready or consuming guest Fuel.
This convenience path is private; the accepted owning lifecycle is the API above.

## Terminal events and Fuel

Events include `remaining` and `fuel_known`. Input completions carry the actual
terminal remainder on both success and guest error, supplied by
`module_input_program::complete`. Failure is not replayed to reconstruct a cost.
The first terminal event, value, diagnostic and remainder remain stable under
observation and cancellation. Ready cancellation retains the initial budget.

The existing zero-argument executor still lacks terminal metering; its completed
events explicitly set `fuel_known=false`. A zero value in that inactive field
must not be interpreted as exhaustion. This does not complete full Engine Fuel
or memory/work accounting. Existing opcode and metadata prices, default 256,
ceiling 16000000, frame/instruction/owner capacities and public gates are unchanged.

## Native transport and validation

`native/runtime-engine/bridge.inc` projects only actual emitted typed fields.
Fairy owns compilation, input association, phase changes, execution and cleanup.
The incoming Snapshot vector and shared Snapshot borrow have different reviewed
types. OS thread/lifetime/epoch admission precedes dereferencing either incoming
argument; native completion authenticates the same synchronous ticket.

Run `python tools/verify-runtime-engine.py` for development and release/O2.
The input fixture adds real binary/NUL and full 1MiB execution, exact last bytes,
wrong-API preservation, pinned release, move/relocation, original diagnostics,
exact/one-less Fuel, exhausted-admission maintenance and owning input teardown.
The existing real OS guard and zero-argument fixture remains in the same image.
After warming both OS I/O kinds, six measured disk/byte-pipe cases execute OS bytes at lengths 0/4/4097/1MiB after
closing the original handles and deleting the disk fixtures. Their adopted Fairy
Snapshot moves into an owning Instance before the VM reads its exact final byte.
Both SDK heap cleanup and native process handle counts are checked.
Focused allocator failures cover all five Engine vector reservations, incoming
Program/Snapshot staging and VM metadata preparation. The final native host
requires zero live SDK heap allocations. No compiler overrides or stack-size
changes are allowed; the executable runs with an empty tool PATH.

The native fixture retains only explicit Windows TEMP/TMP paths needed to create
its files, alongside SystemRoot/WINDIR. An initial test-harness failure omitted
TEMP/TMP and could not create its temporary file; its failed receipt remains in
ignored build history and does not support a pass. A separate initial handle
baseline check included Windows first-use I/O bookkeeping; the final fixture
warms disk and pipe paths before measuring all six cases.

The committed evidence records executed profiles and exact input identities.
Full policy/run binding, complete peak accounting, resumable steps/deadlines,
in-flight cancellation, poison containment, guest output, host dispatch,
restricted workers and public CLI/C ABI delivery remain open in
[the accepted inventory](../product/04-remaining-work.md).

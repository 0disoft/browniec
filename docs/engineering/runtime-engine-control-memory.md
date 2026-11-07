# Engine control storage and preallocation

The private owning Engine now reserves its seven descriptor vectors for the
admitted Program/Instance counts instead of always requesting 64 slots. A
control-storage budget is checked before any SDK allocation. This is an actual
Engine creation/lifecycle integration, not an independent accounting model.
It completes this fixed-control-storage increment of R02; full R02 remains open.

## Exact fixed-storage reservation

`required_control_bytes(limits)` validates the existing 1..64 Program/Instance
counts and Fuel ceiling, then returns the inline Engine size plus the payload
bytes of its seven initially empty vectors. Native code supplies only `sizeof`
facts for Engine, Program, Instance, BoundInput and Output. Checked quota and
capacity arithmetic stays in `runtime_control_layout.fy`.

The pinned SDK starts an empty vector at eight slots and doubles to the requested
capacity. Define `cap(n)` as the first of 8/16/32/64 at least n. The reservation is:

```
sizeof(Engine)
+ 2 * cap(programs)  * sizeof(Program)
+     cap(instances) * sizeof(Instance)
+ 2 * cap(instances) * sizeof(BoundInput)
+ 2 * cap(instances) * sizeof(Output)
```

The two extra Program/input/output vectors are removal scratch, not additional
initialized objects. Admitted counts bound every push; their allocated storage
is sufficient before compilation or execution starts. Smaller admitted counts
remain logical ceilings even when the SDK rounds capacity upward.

`create_with_control_budget(limits, bytes)` accepts 1..4 MiB of control budget.
An insufficient reservation returns private resource-limit status 8 before any
SDK allocation. Actual allocator failure returns status 6 and reclaims all
partial owning vectors. `create(limits)` retains its existing signature and
uses the 4 MiB private control ceiling. This is not immutable policy binding.

The fixed-size `runtime_control_budget` records limit, reserved bytes and peak.
Reserve/release reject overflow, excess release and closed-state mutations
without changing observations. Release preserves peak. The trusted Engine owns
this ledger; it is not a guest authority or automatic heap tracer.

`control_memory(ref engine)` checks the actual owner thread and rejects reentry
before returning a detached observation. It does not consume an admission epoch,
so maintenance remains available after epoch exhaustion. It also permits an
owner-thread observation after explicit destroy: reserved is zero, closed is
true and the historical peak remains. Destroy first rejects live children,
then closes the control reservation and releases all seven empty vectors.
Moves preserve the reservation. Implicit owning-scope cleanup still drops the
vectors even without explicit destroy.

## Native evidence and measured improvement

Run `python tools/verify-runtime-engine.py`. The test adapter only changes the
original six control-budget tests' module name and visibility; each complete body
runs in the same native image as the real Engine/control and existing input/output
lifecycle fixtures. Production sources are copied unchanged.

[Recorded evidence](../evidence/runtime-engine-control-memory-windows-20261107.json)
contains the executed receipt hash, exact inputs, emitted transport, 18 reviewed
bindings, both PE identities and default 1 MiB reserve / 4 KiB commit stacks.
Six real Engine cases use counts (1,1), (8,8), (9,9), (64,64), (1,64) and (64,1).
For each, native instrumentation checks all seven actual vector block sizes,
SDK-requested live/peak bytes and the inline Engine size against the reservation.
One-less-budget rejection occurs with zero allocator attempts even when native
allocation is armed to fail. An exact budget then reaches the allocator and
reports OOM. A subsequent successful retry has exactly seven allocations and
releases all of them. Existing seven creation-OOM seams and owner/reentry guards
remain in the same fixture.

The one-Program/one-Instance case requests 6,592 heap bytes, versus 52,736 for
64-slot backing: an eightfold reduction (87.5 percent), with seven allocations
in both cases. The current inline Engine is 600 bytes, so those control
reservations are respectively 7,192 and 53,336 bytes. These are measured SDK
requests and layout bytes, not a latency benchmark or process-memory claim.

Instrumentation adds separate aligned test headers; those bytes, CRT allocator
bookkeeping, OS heap capacity, temporary native stack copies, shared thread/TLS
and ABI infrastructure are not silently represented as SDK control payload.
The logical inline Engine charge ends at explicit destroy although its closed
host-language wrapper may remain on the caller's stack until scope exit.

## Retained-program successor

[Program memory admission](runtime-engine-program-memory.md) now adds exact
retained source/IR/image charges and combined control/Program ceilings. Its extra
ledger and per-Program charge metadata change current control layout; the older
600-byte / 6,592-byte measurements above remain this control-only checkpoint's
historical results. Current measurements belong to the successor's receipt.

## Remaining R02 integration

Compile working storage, per-Instance
VM frames and owner/loan/descriptor tables, input/output payloads, pending host
state, simultaneous Instances and cross-Engine/process resources still require
aggregate ceiling enforcement and peak reservations. The control observation
must not be reported as total Engine memory. Full preallocation, bounded work,
resumable steps, deadlines/poison and public policy/ABI delivery also remain open.

# Engine retained input memory admission

The private owning Engine charges actual immutable input backing while its
Instance owns it. The tracked Engine ceiling now includes that backing during
compilation and Program publication as well as input admission. Execution
scratch and retained output were separate work at this checkpoint. The
[execution/output successor](runtime-engine-execution-memory.md) now implements
their scoped heap admission and ownership. Native stacks and complete Engine
accounting remain separate work.

## Limits and observations

`create_with_instance_memory` adds positive per-Instance and simultaneous-Instance
heap limits of at most 268,435,456 and 536,870,912 bytes respectively. The first
must not exceed the second. Existing constructors retain those defaults.
`instance_memory` exposes current owning bytes and the admitted reservation peak;
`program_memory.external_bytes` includes those same owning bytes exactly once in
`tracked_bytes`. These are named reservations and SDK payload bytes, not RSS.

For retained input capacity B, current simultaneous input charge X, fixed control
C, retained Programs P and incoming Snapshot transport T:

```text
B + T <= instance_limit
X + B + T <= instances_limit
C + P + X + B + T <= engine_limit
```

The reviewed Snapshot is 40 bytes. SDK Vec8 transport reserves 320 bytes, even
for an empty input. The Snapshot Buffer's actual capacity, rather than its
logical length or charged Fuel, supplies B. Output-only and ordinary creation
need no incoming Snapshot allocation and retain zero input bytes. A borrowed
input remains caller-owned and is not relabelled as an Engine payload.

## Ownership transaction

The native preflight authenticates owner/reentry and Fairy validates lifecycle,
Program kind, Fuel, output configuration and remaining counts before reading
Snapshot capacity. All quota decisions and overflow proofs stay in Fairy. It
records admitted historical reservation pressure before any incoming allocation,
without issuing an epoch or object ID. The typed operation independently rechecks
using actual SDK incoming backing bytes before moving the Snapshot into its
pre-reserved owning slot. Only successful Instance publication commits both
ledgers and advances the ID. No fallible allocation follows that publication.

Rejection destroys the supplied owner but leaves existing owners, counts, current
charges, pins and IDs intact. Incoming allocation OOM maps to status 6; quota to
status 8. An admitted reservation peak can survive allocation failure. Cancellation,
terminal completion and Program release preserve the input charge. Engine moves
preserve its ledger. Instance destruction first drops actual input/output owners,
then returns the input charge once; peer inputs remain charged. Closing refuses
outstanding owners, and preserves historical peaks after current bytes reach zero.

## Next execution slice: static heap audit

A read-only review of pinned SDK 0.0.0-stage0.87 and the preceding emitted native
transport found the following additional payload reservations. These are static
source/layout calculations, not new execution measurements or implemented quotas.
Let C(n) be zero for n=0, otherwise the first 8*2^k capacity at least n. Let n/b
be maximum list elements/encoded bytes, and q the selected place descriptor count:

```text
S = optional 65,536-byte arena + 8*C(n) + b + 8*C(q)
ordinary: S
input: S + 24,576
output: S + 616 + output_limit
input-output: S + 24,576 + 616 + output_limit
```

For maximum place ID plus one w, q is zero when w is zero. Otherwise the selected
array/slice/record/aggregate encoding uses `32*(9*w+1)`, `1+32*(14*w+1)`,
`2+32*(14*w+1)` or `3+32*(18*w+1)` respectively. Only one descriptor Vec is live.
Planning must inspect immutable IR without allocating before dispatch admission.

Input descriptors use capacity 1024 of 24-byte Cell, including empty input.
The output preparation adds a 576-byte Published Vec, a 40-byte transaction
header and reserved output capacity. After successful completion, 576 plus the
full reserved output capacity remains. After a failure following transaction
open, the empty 576-byte vector can remain. `take_output` separately reserves
1,088 bytes, after execution scratch has ended. Execution planning must avoid
double-counting these retained and transient classes. Inline owners, loans,
registers and 32 call frames are stack/control values, not fresh heap per call.

## Verification and limitations

[Windows evidence](../evidence/runtime-engine-input-memory-windows-20261107.json)
records implementation `6db179e`: development/O2 each pass nine new Engine
groups, seven live-budget groups, thirteen combined-budget groups (four new)
and all existing input/output/control/retention/compile/OS/depth fixtures. Exact
and one-less per-Instance, simultaneous and combined Engine limits, no allocation
on early rejection, incoming reserve OOM, unchanged epoch/ID, peers, cancellation,
moves, empty input, output transfer and owning teardown pass. Native fixtures use
the public Snapshot constructor, whose capacity currently equals length.

All 224 executed source/config/tool inputs match checkout and committed Git;
seven pinned SDK runtime inputs match their reviewed Git objects. The transport
pins 23 typed bindings and 18 emitted layouts, including the actual Snapshot and
its vector. SDK live allocations/bytes return to zero. Both images use default
1MiB/4KiB native stacks, with no compiler overrides. Inline Engine is now 736
bytes; Instance is 128 bytes. The one-slot control heap is 6,784 bytes, compared
with 54,272 at all-64 counts. Fixed control counts the inline owner once in
addition to that heap; this is not a heap allocation of the owner itself.

Root `check --locked` passes 252 sources/2875 MIR functions; all 244 production
modules retain LF. The standalone compiler/public CLI were not rebuilt for this
accounting slice. Existing public gates, VM capacities, opcode prices and Fuel limits
remain unchanged. Immutable public policy binding, execution/output quotas,
bounded steps, deadlines, poison recovery, worker isolation and embedding remain
in the accepted inventory.

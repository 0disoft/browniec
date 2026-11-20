# Engine compilation memory admission

The owning Engine now uses `module_budgeted_compile` for ordinary, input, output
and input-output Programs. It enforces a separate compilation working ceiling
and the remaining tracked Engine ceiling before allocating its incoming Entry
vector. Existing Index backing stays charged while the compiler owns it. This
extends [persistent retention](runtime-engine-program-memory.md) and the
[bounded compiler](compile-memory.md); Instance/input/output/host accounting and
native stack containment are still incomplete.

## Accounted classes

The reviewed native bridge reports emitted type widths and actual SDK vector
backing bytes. Fairy performs checked arithmetic and all quota decisions.

| Class | Ordinary/output | Input/input-output |
| --- | ---: | ---: |
| Existing Index Vec8 backing | 173,760 | 173,760 |
| Incoming owning Entry Vec8 | 640 | 1,024 |
| Conservative lowering heap, including scratch and old/new growth | 66,630,144 | 66,630,144 |
| Required working allowance | 66,804,544 | 66,804,928 |

Entry is 80 bytes and InputEntry 128 bytes. Index contains one immutable Stored
in an eight-element backing block; Stored is 21,720 bytes. The 48-byte vector
descriptor and inline Snapshot/Table are not added again as separate heap
allocations. The caller constructed Index before transferring Entry: denial
does not undo that earlier external allocation. It consumes/destroys the supplied
Entry without allocating an additional incoming block.

The lowering reservation includes three staged evaluation scratch vector kinds;
the [bound proof](compile-memory.md#working-bound) and emitted-width checks own
its assumptions. All four modes still fit the 67,108,864-byte policy.
This is a conservative reservation, not observed physical heap consumption.

`create_with_compilation(count_limits, control_limit, retained_limits,
working_limit)` accepts a positive working limit up to 268,435,456 bytes. Existing
creation functions use that maximum, matching the accepted compile-policy ceiling.
This is private configuration; immutable public policy binding remains separate.

Let C be fixed control, P existing retained Programs, H Index plus incoming
backing, W the lowering bound and R the next persistent Program reservation:

```text
working check: H + W <= working_limit
tracked check: C + P + H + max(W, R) <= engine_limit
```

The separate per-Program and Program-set limits still apply to R. Input/output
payloads and live Instance execution costs are not yet part of C or P. These
equations cover the named classes, not every Engine allocation or process RSS.

## Preparation and commit

The early native guard authenticates owner/reentry, then calls Fairy B21 with
zero facts to reject closed, exhausted, count-limited or impossible fixed
retention states before observing the supplied source owner. It then observes
actual backing/type-width facts and calls B21 again under the same OS guard.
Admitted preflight records historical reservations but spends no epoch or ID.
Working/combined rejection and incoming reserve OOM therefore allocate no
incoming block or consume an admission epoch.

The wrapper invokes no guest or host callback before ordinary operation admission.
SDK reserve cannot reenter the Engine. Another Engine may still cause Busy at
that later guard acquisition; preparation does not promise later admission.
Actual compile independently rechecks current budgets, measures incoming backing
and uses a new phase-0 Plan. The selected compiler's exact pre-freeze check is
narrowed to the remaining combined budget. Lowering scratch and persistent storage
are exclusive, while Index and incoming backing remain conservatively charged.

An admitted image/Stored/outer-handle OOM preserves the reservation peak, destroys
all unpublished owners and publishes no Program/ID. Source failure preserves
original diagnostics. Private quota maps to status 8 and SDK OOM to status 6.
Only successful owning publication advances the object ID. Once ordinary
admission has begun, source/compile failure still consumes its operation epoch.

## Observations and typed transport

`program_memory` adds `working_limit` and `working_peak`. `program_peak` remains
the Program-only reservation high-water mark. `tracked_bytes` is current fixed
control plus actually retained Program backing; no scoped compile is observable
during synchronous nonreentrant preparation. `tracked_peak` is the historical
maximum combined reservation, including compilation. It is no longer the sum of
independent control and Program peaks. Destroy/owner moves preserve historical
peaks; released pins remain charged until actual final-owner reclamation.

The current transport pins 36 typed bindings and compares all 51 reviewed layouts
against actual emitted declarations. Entry/InputEntry and a new Instance witness
fix the concrete types used for backing facts and sizeof. Instance is 120 bytes;
using an old numerical generated type ID can otherwise select an unrelated
struct after metadata changes. Current inline Engine is 736 bytes; control heap
is 7,872 bytes for one slot and 62,976 at all-64 counts.

## Configured compile deadlines

The private Engine takes the duration from its owned Policy and samples
Windows interrupt time. The same absolute deadline crosses project collection,
entry selection and executable compilation. Retained host compilation carries
it across lowering, verification and retention. Expiry at a checked boundary
returns a deadline diagnostic with no source location. The publication check
precedes adding the Program to the Engine or advancing its ID.

Configured Windows project collection samples the same deadline before
root reinspection, before opening each declared member, before final
revalidation and before publishing the native snapshot. An expired collection
closes its member and root handles, produces no Snapshot, and returns the
source-less deadline diagnostic before compiling or assigning a Program ID.
The collector uses synchronous OS I/O. A file operation already in progress
returns to the next checkpoint before expiry is delivered.

The Windows Engine verifier set an exact deadline between the first source
read and a missing second member. Without expiry the same project reported
acquisition failure. With expiry it reported a deadline, left the process
handle count and SDK heap unchanged, and preserved the next Program ID.
Both profiles also passed the separate final publication control. Local
Engine receipt: `build/runtime-engine/20261120T231632275851Z/receipt.json`.
The native collector tested expired and future deadlines using the real OS
clock in both profiles: `build/anchored-sources/20261120T231507642754Z/receipt.json`.

Output and input-output compilation sample the same absolute deadline before
each source-context advance. An advance copies up to 64 source bytes, packs
one metadata row, checks one sealed name, or moves to the next phase. Expiry
discards the incomplete context before signature or body lowering. The
compiler samples again after lowering and before freezing the literal image. The proof driver then
samples once before each bounded proof advance. Expiry ends the compile with
the source-less deadline diagnostic and releases the image and any active
reservation. Only a complete proof can enter Program retention. The final
publication check still covers the synchronous work after proof.

The Windows verifier advanced the clock to the exact deadline in the first
source copy for both output entry modes. Each compile copied exactly 64 bytes
and entered zero proof stages. The tracked Program ledger and SDK heap returned
to baseline, and the next successful compile still received Program ID 1.
Development and /O2 both passed with zero live SDK allocations on exit.
Local receipt: `build/runtime-engine/20261120T234128105707Z/receipt.json`.

The Windows verifier advanced the clock to the exact deadline inside the
canonical proof for both profiles that admit output. Each compile stopped
before the next Program storage allocation, left the retained ledger and SDK
heap at baseline, and preserved the next Program ID. One tick before expiry
the same configured compiler admitted the Program. Development and /O2 both
passed with zero live SDK allocations at exit. Local receipt:
`build/runtime-engine/20261120T233149911244Z/receipt.json`.

Source lowering, work between checkpoints, and cleanup remain synchronous.
Public Pending compilation, in-flight cancellation, and a latency bound for
the complete compiler remain open.

Windows development and /O2 verify rejection at the exact publication deadline
on all four module profiles and after anchored project collection. Publication
one tick before the deadline succeeds. Rejections retain no Program or SDK
allocation and leave the next Program ID available. Local receipt:
`build/runtime-engine/20261120T113808949152Z/receipt.json`.

## Executed verification and remaining work

[Windows evidence](../evidence/runtime-engine-compile-memory-windows-20261107.json)
records native development/O2 success, seven new Engine groups, nine scalar
budget groups and all retained control/input/output/OS/retention fixtures. Tests
cover four-mode exact/one-less working and combined limits, zero incoming
allocation and unchanged epoch/ID on early rejection, real allocation-ordinal
failure sweeps, source rollback, peer pins, moves, closed/exhausted observations,
and Engine compilation/execution at captured-call depth 32 with rejection at 33.
SDK live allocations/bytes return to zero; default stacks are 1MiB/4KiB without
compiler overrides. The original standalone combined 32/33 fixture is unchanged.

The later [evaluation checkpoint](../evidence/compiler-evaluation-source-windows-20261113.json)
records the expanded lowering reservation, 28 standalone memory groups per
profile and final Engine integration. Test-only constructor scopes and admission
callbacks separate named retention faults from the global compile allocation
sweep. Combined runtime boundaries use real simultaneous owners whose bytes
exceed the preserved compilation high-water mark, within the existing 64-owner
limit; exact/one-less denial, pins, rollback and physical cleanup remain checked.

Per-Instance frames/input/owners/loans/descriptors/output, simultaneous Instance
peaks, pending host state, native stacks and the remaining combined Engine quota
are open. Bounded compilation, cancellation/poison and public delivery remain
in [the accepted inventory](../product/04-remaining-work.md). Public gates, VM
capacities, opcode prices and Fuel defaults/ceiling are unchanged.

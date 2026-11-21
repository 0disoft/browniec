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

All four module compile modes sample the same absolute deadline before each
source-context advance. An advance copies up to 64 source bytes, packs
one metadata row, checks one sealed name, or moves to the next phase. Expiry
discards the incomplete context before signature or body lowering. The
ordinary and output-only syntax classifier uses the staged source-context and
token scanners with a deadline check before each advance and before observing a
complete token.
Literal collection samples before every bounded advance and before assigning the
finished candidate to the image Builder. An expired collection leaves the
Builder untouched and returns the source-less deadline diagnostic. Indexed
signature scans sample before each advance and before returning the complete
Table. This covers the initial scan in all four modes and the reference
signature rescan for retained ordinary and output-only compilation. Advisory
returned-slice origin inference samples before and after each function-body
walk within its fixed point. This covers preparation of returned-reference
bodies and post-body reference binding in both retained ordinary and output-only
compilation. Scoped record preparation checks before each
declaration, field resolution or layout validation advance and again before
returning the completed table. The compiler also checks before body
preparation, before each function, and before
each control advance or pending semantic child. A child already running returns
to the next checkpoint before expiry is delivered. The compiler samples again
after lowering and before freezing the literal image or entering ordinary
admission. Ordinary verification samples the same deadline between proof
phases and before each instruction in canonical CFG, recipe flow and origin,
executable CALL, and returned-reference lifetime scans. The legacy route
carries the deadline through both its scalar verifier and its subsequent
reference admission. Timed ordinary verification uses the staged literal
image proof and samples before each catalog or payload stage and before
accepting the complete image. Each UTF-8 stage validates at most 259 bytes.
Reference recipe definition scans sample before each instruction and each
formal-coverage register. Timed ordinary verification also reuses staged
reference root preparation, which samples before each site or round
transition and before returning the complete plan. A site can scan up to
256 call or return instructions. The ordinary selected-place proof checks
before and after its presence scan and before each graph instruction. This
includes the structural checks for unreachable instructions. Other metadata
calls return to their surrounding checkpoint. The staged input and output proof drivers
sample once before each bounded proof advance. Input-only compilation uses its
separate proof with the output gate closed and checks again before returning
the completed proof. Expiry ends the compile with
the source-less deadline diagnostic and releases the image and any active
reservation. After a complete output proof, the compiler checks the same
deadline before list, place, CALL cost, execution heap and capture planning,
and again before allocating the retained Program. Both place-requirement
scans sample before each instruction and before returning a plan, including
the scans inside execution heap accounting in all four compile modes.
Array-list scratch planning checks before scanning, before each instruction,
and before returning a complete plan. The final Engine publication check
precedes registration.

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

The Windows Engine verifier expired the compile while its first body request
was pending in each output entry mode. The driver entered zero semantic
children and zero proof stages. Program retention and the SDK heap returned to
baseline, and the subsequent successful compile received Program ID 1. Windows
development and /O2 passed with zero live SDK allocations at exit.
Local receipt: `build/runtime-engine/20261120T235052748018Z/receipt.json`.

The standalone body-lowering comparison passed 30 development groups. Its
30-group release invocation hit the Fairy C 60-second MSVC command limit.
A single /O2 image passed four selected comparison and default-stack depth
groups. Local receipts: `build/body-lowering-deadline-regression/development/receipt.json` and
`build/body-lowering-single-image/receipt.json`.

The Windows verifier expired collection after its first staged literal in both
output entry modes. No further collection advance or proof stage ran. A direct
collector case also preserved a prepopulated Builder. The Engine kept its next
Program ID and returned the SDK heap and retained Program charge to baseline.
Windows development and /O2 passed with zero live SDK allocations at exit.
Local receipt: `build/runtime-engine/20261121T000534935666Z/receipt.json`.

The Windows verifier expired each indexed signature scan after accepting the
first of two function signatures. It covered the initial scan in both output
modes and the post-body reference signature rescan in output-only mode. No
further scan advance or proof stage ran. The SDK heap and retained Program
charge returned to baseline, and the next successful compile received Program
ID 1. Windows development and /O2 passed with zero live SDK allocations at
exit. Local receipt: `build/runtime-engine/20261121T001507901261Z/receipt.json`.

The Windows verifier expired the deadline after the first successful origin
body walk. It covered body preparation in both output modes and the output-only
post-body reference binding pass. Each rejection reported a source-less deadline
before another walk or a proof advance, restored the Engine ledger and SDK heap,
and preserved the next Program ID. Development and /O2 passed with zero live
SDK allocations at exit. Local receipt:
`build/runtime-engine/20261121T002541558630Z/receipt.json`.

The Windows verifier expired both output modes after resolving the first
record's fields. Each compile avoided further record advances and proof work,
preserved the next Program ID and restored the retained Program charge and
SDK heap. A direct scanner case accepted the layout one tick before the
deadline and rejected it at the deadline after the final layout check.
Development and /O2 passed with zero live SDK allocations at exit. Local
receipt: `build/runtime-engine/20261121T003403167586Z/receipt.json`.

The Windows verifier advanced the clock to the exact deadline during the
first batch of an unfinished block comment in the output-only syntax
classifier. No subsequent lexer advance, literal collection or proof ran.
Program retention and SDK heap returned to baseline and the next
successful compile still used Program ID 1. Windows development and /O2
passed with zero live SDK allocations at exit. Local receipt:
`build/runtime-engine/20261121T004315648470Z/receipt.json`.

The Windows verifier expired input-only compilation independently during
source-context collection, literal collection, signature scanning, origin
inference, record scanning, body lowering and canonical proof. At proof
expiry only one proof advance ran and no subsequent retention allocation
was attempted. Each rejection restored the SDK heap and Program charge.
The same input-only source compiled one tick before expiry with Program ID 1.
Windows development and /O2 passed with zero live SDK allocations at exit.
Local receipt: `build/runtime-engine/20261121T005147394912Z/receipt.json`.

The Windows verifier expired ordinary module compilation during source-context
collection, syntax classification, literal collection, signature scanning,
both origin inference passes, record scanning and body lowering. The
rejections restored the SDK heap and Program ledger. Both ordinary source
profiles were retained one tick before expiry. Windows development and /O2
passed with zero live SDK allocations at exit. Local receipt:
`build/runtime-engine/20261121T010442458057Z/receipt.json`.

The Windows verifier advanced to the exact deadline inside the first CFG,
recipe-flow or reference-lifetime instruction of each ordinary profile. Six
cases stopped before a second proof instruction or retention allocation,
restored the SDK heap and Program charge, and preserved the next Program ID.
Both Windows profiles passed with zero live SDK allocations at exit. Local
receipt: `build/runtime-engine/20261121T011508635459Z/receipt.json`.

The Windows verifier expired each of six post-proof checkpoints in both
output-capable compile modes. Each rejection skipped the next preparation
stage and made zero further SDK allocation attempts. The SDK heap and Program
charge returned to baseline, and the next successful compile used Program ID 1.
Windows development and /O2 passed with zero live SDK allocations at exit.
Local receipt: `build/runtime-engine/20261121T012309774139Z/receipt.json`.

The Windows verifier advanced to the exact deadline during each available
place scan across the four compile modes. In all 12 cases, compilation stopped
before a second instruction in the target scan or another SDK allocation.
The SDK heap and Program charge returned to baseline, and the next successful
compile used Program ID 1. Windows development and /O2 passed with zero live
SDK allocations at exit. Local receipt:
`build/runtime-engine/20261121T013738359375Z/receipt.json`.

The Windows verifier advanced to the exact deadline during array-list scratch
planning in ordinary, input-only, output-only, and input-output compilation.
The six cases include both planning passes in each output-capable mode. No
later instruction or SDK allocation was attempted, and the heap and Program
charge returned to baseline without consuming a Program ID. Both Windows
profiles passed with zero live SDK allocations at exit. Local receipt:
`build/runtime-engine/20261121T014545022819Z/receipt.json`.

The Windows verifier advanced to the exact deadline after validating the
first 258 bytes of a text literal whose three-byte scalar crossed the
256-byte cut. The next image chunk and further proof did not run. The Program
ledger and heap returned to baseline without consuming a Program ID. The same
source compiled one tick before expiry. Windows development and /O2 passed
with zero live SDK allocations at exit. Local receipt:
`build/runtime-engine/20261121T015538551853Z/receipt.json`.

The Windows verifier advanced to the exact deadline on the first recipe
definition instruction or the first root-round transition in both ordinary
source profiles. All four cases stopped before a second probe or a new SDK
allocation and restored the ledger and heap without consuming a Program ID.
Windows development and /O2 passed with zero live SDK allocations at exit.
Local receipt: `build/runtime-engine/20261121T020446164516Z/receipt.json`.

The Windows verifier advanced to the exact deadline on the first graph
instruction for a source with selected-place assignment in each ordinary
profile. Both cases stopped before another graph instruction or SDK allocation
and restored the ledger and heap without consuming a Program ID. Windows
development and /O2 passed with zero live SDK allocations at exit.
Local receipt: `build/runtime-engine/20261121T021252854530Z/receipt.json`.

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

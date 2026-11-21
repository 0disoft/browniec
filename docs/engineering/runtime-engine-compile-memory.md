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
includes the structural checks for unreachable instructions. Timed ordinary
record metadata preparation reuses the staged layout and binding traversal,
sampling before each advance and before returning the prepared metadata.
Timed ordinary array-list metadata checks before each span visit, every
batch of at most 256 padding entries, and before returning the result.
Copy metadata checks before each instruction and before returning, including
unreachable instructions. Individual copy validation is synchronous. Timed
slice parameter metadata checks each function partition, site, formal
register, and origin-coverage row. Reborrow metadata checks before each
instruction and each parent-site validation. Both check again before returning
their result. Array and record signature metadata check before each parameter
register or function result row and before returning the completed plan.
The staged input
and output proof drivers
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

The Windows verifier advanced to the exact deadline during layout and binding
traversal for nested records in both ordinary profiles. All four cases stopped
before another metadata stage or SDK allocation. The ledger and heap returned
to baseline without consuming a Program ID. Windows development and /O2
passed with zero live SDK allocations at exit. Local receipt:
`build/runtime-engine/20261121T022614858583Z/receipt.json`.

The Windows verifier advanced to the exact deadline after the first list
padding batch or the first copy in both ordinary source profiles. All four
cases stopped before the next verification phase or another SDK allocation.
The ledger and heap returned to baseline without consuming a Program ID.
Windows development and /O2 passed with zero live SDK allocations at exit.
Local receipt: `build/runtime-engine/20261121T023418260264Z/receipt.json`.

The Windows verifier advanced to the exact deadline during the slice formal
register scan, reborrow instruction scan, or reborrow site traversal. All six
cases, using mutable parent and child slices in both ordinary source profiles,
stopped without an SDK allocation after expiry or a Program ID advance.
The ledger and heap returned to baseline. Windows development and /O2 passed
with zero live SDK allocations at exit. Local receipt:
`build/runtime-engine/20261121T024344600629Z/receipt.json`.

The Windows verifier advanced to the exact deadline on an array or record
parameter or return row, using both ordinary profiles with calls that pass
and return both aggregates. All eight cases stopped before further proof or
SDK allocation. The ledger and heap returned to baseline without consuming a
Program ID. Windows development and /O2 passed with zero live SDK allocations
at exit. Local receipt: `build/runtime-engine/20261121T025153342542Z/receipt.json`.

Source lowering, work between checkpoints, and cleanup remain synchronous.
Public Pending compilation, in-flight cancellation, and a latency bound for
the complete compiler remain open.

Windows development and /O2 verify rejection at the exact publication deadline
on all four module profiles and after anchored project collection. Publication
one tick before the deadline succeeds. Rejections retain no Program or SDK
allocation and leave the next Program ID available. Local receipt:
`build/runtime-engine/20261120T113808949152Z/receipt.json`.

## Compile source charges

Ordinary Engine compilation now holds a separate charge for the selected
Index and its incoming vector while the synchronous compiler owns the
selection. Source ownership counts against the working and combined limits.
It also reduces the combined headroom for retained Programs and Instance
payloads. The ordinary compile refunds the source charge when the compiler
returns, before publication. Working and combined peaks remain historical.
The Windows x64 inline Engine layout grows from 792 to 800 bytes.

Windows development and /O2 verified exact admission, one-byte-short
rejection, refusal of mismatched and duplicate refunds, and preservation of
other owners' charges. The native tests ended with zero live SDK allocations.
The locked /O2 CLI returned 77. Local receipt:
`build/runtime-engine/20261121T033444048057Z/receipt.json`.

The Engine-owned ordinary compile described below uses the same ledger
across caller returns.

## Engine-owned ordinary compile

The private Engine can start one ordinary compile, step it, observe its
status, cancel it and detach its terminal status. The Engine owns the selected
Index and the source preparation cursor. Each Preparing step advances one
source batch. Prepared returns before IR lowering. The following step lowers
and independently admits the Program, with the existing deadline checks.
Program IDs are assigned only on publication. A terminal status remains
observable until detached, including after a repeated step or cancel.

At each step or cancel the Engine compares the original absolute deadline.
Cancellation before the deadline and expiry at the deadline both release the
selected Index. Program publication and failed admission also release that
source charge. The Engine's fixed work and Entry vectors are charged at
creation and freed at destruction. Destruction refuses a live compile so the
owner can cancel it first. The public CLI continues to use synchronous
compilation.

Windows development and /O2 verified one batch per Preparing call, distinct
Prepared observation, execution of the resulting Program, stale ID rejection,
and stable cancellation and expiry causes with exact source refunds. Both
profiles ended with zero live SDK allocations at default stack settings. The
fixed vectors charge 42,944 bytes and the inline Engine grows by 96 bytes.
An earlier inline cursor caused Windows development exit `0xC00000FD`.
Moving the cursor to the charged fixed vector resolved that failure. Local
receipt: `build/runtime-engine/20261121T035836301837Z/receipt.json`.
The locked /O2 CLI build returned 77 and passed its contract checks.

Lowering and verification within the Prepared step still run synchronously.
The remaining compile profiles, bounded steps through those phases and
in-flight cancellation remain open.

## Engine-owned lowering handoff

An ordinary compile now returns Lowered after IR lowering. The Engine owns
that candidate and its literal builder until a later step independently
verifies and admits the Program. Source data and the candidate backing are
both charged while Lowered is observable. Admission checks combined headroom
with the candidate still live. Program IDs are assigned only after proof
and publication. Cancellation, expiry, candidate allocation failure, and
failed Program admission release the unpublished backing.

The candidate vector allocates on the Prepared step and returns its backing
on the terminal transition. Its descriptor adds 48 bytes to the inline
Engine. Lowering and proof each still drain synchronously within a step.
The remaining compile profiles and in-flight cancellation remain open.

Windows development and /O2 verified that Lowered has no Program ID, its
charge matches live SDK bytes, and successful admission produces an executable
Program. The same checks covered cancellation and exact-deadline expiry from
Lowered, allocation failure before lowering, and literal-image quota rejection
during admission. Both profiles ended with zero live SDK allocations. Local
receipt: `build/runtime-engine/20261121T041047288327Z/receipt.json`.
The locked /O2 CLI build returned 77 in the quick start.

## Resumable ordinary literal collection

The Engine advances one literal collection batch per step while the ordinary
compile reports Prepared. The existing 4,096-unit metadata allowance applies
to each advance. The source and builder stay pinned across calls. A fresh,
private builder needs no copy from an existing image. The next stage consumes
the completed literal index and its matching builder.

The fixed compile-work vector adds 43,328 bytes (42,304 to 85,632 bytes).
The candidate backing is allocated and charged once. Cancellation during the
literal pass returns its full charge and the source charge. Program publication
still follows independent admission. Indexed signatures, body lowering,
reference-signature binding, and proof still drain within their respective
steps.

Windows development and /O2 verified the incremental batch counts, cancellation
during collection, candidate OOM, image quota failure, and execution returning
77 after successful admission. Both profiles ended with zero live SDK
allocations. Local receipt:
`build/runtime-engine/20261121T043355613653Z/receipt.json`.
The locked /O2 CLI returned 77 and passed its contract suite, including the
Windows process adapter.

## Resumable ordinary indexed signatures

Once source preparation and any required literal collection complete, each
Engine call advances the indexed signature cursor under the existing
4,096-unit metadata allowance. Compile remains Prepared until body lowering
finishes. The exact selected Entry and source context stay pinned. The
signature cursor lives in the charged candidate backing and adds no fixed
Engine control charge. Cancellation or expiry discards the unpublished
candidate and source; there is no Program ID before final admission.

Body lowering consumes the completed signature table. The pending reference
route binds parameters, results and inferred origins from that same pass.
The synchronous routes keep their existing deadline and admission sequence.
Body lowering, origin inference and independent verification still drain
inside their respective steps.

Windows development and /O2 verified monotonic per-call batch counts on scalar
and literal-bearing source, exact-deadline expiry before signature completion,
candidate and source refunds, and execution returning 77 after admission.
Both profiles ended with zero live SDK allocations. Local receipt:
`build/runtime-engine/20261121T045048395849Z/receipt.json`.
The locked /O2 CLI returned 77 in the quick start.

## Resumable ordinary body control

The private Engine reports Lowering after signatures finish. It preserves the
current function, lexer, lexical bindings, loop state, body control cursor and
partial IR across calls. Each call advances one control batch, completes one
requested semantic child, or handles a setup or finalization stage. Control
batches use the existing 4,096-unit allowance. Aggregate and origin preparation,
first-token setup, semantic children and finalization still run synchronously
at their respective boundaries. Lowered becomes visible after all bodies and
reference metadata are complete; independent Program admission follows.

The candidate uses one SDK allocation of 39,920 bytes. The default eight
slots would require 319,360 bytes. Together with the 173,760-byte adopted Index
and conservative scratch reservation, that would exceed the 64 MiB compile
policy by 14,400 bytes. The Engine charges the exact backing before allocation
and returns the charge together with the Index on a terminal transition.

Windows development and /O2 verified multiple body control batches, expiry
at the exact deadline while Lowering, stable terminal diagnostics, and full
source and candidate refunds. Both profiles ended with zero live SDK
allocations. Local receipt:
`build/runtime-engine/20261121T051002326671Z/receipt.json`.
The locked /O2 CLI returned 77 in the quick start.

## Resumable ordinary canonical proof

The staged canonical verifier now accepts the ordinary zero-argument entry
contract and rejects EMIT. Input-only mode still requires one shared-byte
argument, and output modes retain their separate gate. The same 4,096-unit
allowance bounds each staged advance. The resulting proof remains analysis
data. The owning Engine still admits Programs through the synchronous path.

The Windows Engine harness executes the canonical proof fixtures with the
runtime clock and native companions linked. The ordinary fixture compares
the staged and synchronous proofs for a source-derived shared-byte return,
then checks that both reject EMIT. All five canonical proof groups and the
existing Engine suite passed in development and /O2 with zero live SDK
allocations. Local receipt:
`build/runtime-engine/20261121T052244123543Z/receipt.json`.

## Engine canonical proof

The private ordinary compile job now enters Proving after lowering. It retains
the exact candidate IR and frozen literal image and advances the canonical
proof under the 4,096-unit metadata allowance. Each step contributes at most
one proof batch. A Program ID is issued only after proof completion and
publication. Scalar admission still runs the legacy verifier when opening
the proof. Image construction and final Program retention remain synchronous.

The proof cursor has one SDK-owned heap slot allocated at proof open.
Embedding it in the lowering candidate overflowed the default 1 MiB stack
during candidate construction in the Windows development build. The Engine
preflights the proof slot, image descriptor backing and literal payload before
allocation. Cancellation, expiry, and allocation failure drop unpublished
owners and refund the working charge. On success the literal payload moves
to the retained Program and is counted once across the transfer.

Windows development and /O2 validated proof progression, cancellation and exact
deadline while Proving, failure at both proof owner allocations, and ordinary
and literal-bearing Programs returning 77. The Engine ended with zero live
SDK allocations. The locked /O2 CLI quick start returned 77. Local receipt:
`build/runtime-engine/20261121T055327896002Z/receipt.json`.

## Engine-owned input source preparation

The private Engine accepts an owning InputEntry into the single compile job.
It steps the shared source-context cursor under the 4,096-unit allowance
without ordinary syntax classification. The Prepared state pins the exact
input Index so the next call can lower it without collecting source again.
That call still drains literals, signatures, bodies, and proof before
publishing an input Program. The owning InputEntry is cleared on failure,
cancellation, and completion. A compiler deadline applies across both steps.

The input slot reserves eight 128-byte records and adds a 48-byte Engine
descriptor. This raises fixed control from 944 to 992 bytes for the owner
and from 640 to 1,664 bytes for both entry vectors together. The compile-work
vector remains 85,632 bytes. The adopted Index is tracked separately as
compile-source bytes and is released before Program publication.

Windows development and /O2 verified cancellation during preparation, stale
job rejection, the exact source charge, Program reuse through an input Instance
returning 77, and zero live SDK allocations on teardown. The locked /O2 CLI
quick start and contract checks passed. Local receipt:
`build/runtime-engine/20261121T062132846379Z/receipt.json`.

## Resumable input-only lowering

The owning input job now advances the ordinary compile candidate through
literal collection, indexed signatures, and body lowering. It selects
reference-aware lowering for the input ABI and keeps the exact InputEntry
and its Index for diagnostic mapping. Caller returns expose Prepared,
Lowering, and Lowered with no Program ID. After Lowered, one call runs
independent input proof and Program publication.

The Engine charges the same single candidate slot used by ordinary compile
before allocation. Candidate and source storage are released together after
cancellation, failure, or admission. The retained image is built from the
candidate's literal builder, and the retained Program uses the candidate IR
directly after verification.

Windows development and /O2 verified cancellation during literal collection,
expiry while Lowering, and an input Program that combines a literal byte with
guest input to return 77. Both profiles ended with zero live SDK allocations.
The locked /O2 CLI quick start also returned 77. Local receipt:
`build/runtime-engine/20261121T063323552300Z/receipt.json`.

## Resumable input-only canonical proof

After lowering, the input job freezes its literal image and opens the same
heap-backed canonical coordinator used by ordinary compilation. Its proof mode
accepts one read-only byte input and retains the input-only output gate.
Caller steps advance at most one 4,096-unit proof batch; the Program ID stays
zero until a separate step transfers the proved image into an input Program.
Literal freezing, final retention, and execution-scratch planning are
synchronous.

The Engine checks both retained and working limits before opening proof.
It accounts for the proof cursor, image descriptor backing and payload until
publication or cleanup. The input job tag stays attached through terminal state
and detach, so native dispatch does not infer a job's route from the remaining
Entry owners. The extra tag adds 64 bytes to the eight-slot compile-work vector.

Windows development and /O2 passed cancellation and expiry during proof,
exact in-flight SDK byte accounting, stale job rejection, and input execution
returning 77. Both native artifacts exited with zero live SDK allocations.
The native profiles in local receipt
`build/runtime-engine/20261121T065804242427Z/receipt.json` passed. Its final
worktree hash check detected edits for the subsequent CI repair, so all 400
receipt inputs were checked against this change's staged snapshot.

## Shared output body lowering

The deadline-aware output and input-output compiler routes drain the same
body cursor as input-only compilation. They keep output enabled in the
prepared signatures and retain the source index for diagnostics. Output-only
compilation now scans indexed signatures and infers returned-view origins once
each instead of twice. The synchronous adapters still return only after
candidate verification and retention.

Windows development and /O2 passed both output modes, deadline injection at
body and proof boundaries, and the single-pass signature and origin checks.
Both profiles ended with zero live SDK allocations. The locked /O2 CLI build
returned 77 and passed all 15 CLI contract checks. Local receipt:
`build/runtime-engine/20261121T072706702610Z/receipt.json`.

## Engine-owned output-only lowering

A private Engine job can retain an ordinary Entry for output compilation
and resume source preparation, literals, signatures, and body control.
The output mode enables emit lowering while preserving output-specific
admission and storage. A Lowered candidate has no Program ID. The final
step still runs output proof and publication synchronously.

Windows development and /O2 passed cancellation during lowering with
exact SDK byte accounting, successful publication followed by execution
returning 77 and emitting two bytes, and zero live SDK allocations at
teardown. The locked /O2 CLI quick start returned 77. Local receipt:
`build/runtime-engine/20261121T073632686896Z/receipt.json`.

## Engine-owned output-only proof

Output-only compilation now freezes the literal image and charges the frozen
payload, image vector and a single heap slot for the proof and normalized scratch.
The Engine drives the existing output proof coordinator one stage per step under
a fresh 4096-unit allowance. The Program ID becomes visible only after proof,
execution preparation, retention and publication. Image freeze, final preparation
and publication remain synchronous steps.

The Windows native development and /O2 suite checked cancellation in lowering
and partial proof, expiry before publication, stale job rejection, and exact
refunds against the SDK heap. Successful execution returned 77 and emitted
`ok`. Both process exits were 0 with zero live SDK allocations. Local receipt:
`build/runtime-engine/20261121T075807085872Z/receipt.json`.

## Engine-owned input-output compile

The private Engine accepts an InputEntry for resumable input-output compilation.
The job enables both input-reference and output lowering and uses the output proof
coordinator with input enabled. It transfers the verified image to retained
output Program storage and binds configured entry metadata at publication.
Final execution preparation and publication are synchronous steps.

The Windows development and /O2 suite verified that partial proof leaves the
Program ID at zero, expiry releases the exact charged bytes, and successful
execution returns 77 and emits the supplied byte. Both native processes exited
with zero live SDK allocations. The locked /O2 CLI quick start returned 77.
Local receipt: `build/runtime-engine/20261121T081316707472Z/receipt.json`.

## Engine-owned project compile

The private Engine starts ordinary and input-only project jobs from the
selected immutable project source. Requirement and attached-job checks precede
file collection. Acquisition and entry selection are synchronous, and the
same absolute deadline covers acquisition, lowering, proof, and publication.
The job uses the same retained Program and Instance paths as selected sources.

Windows development and /O2 verified rejection before file collection,
multi-module compilation, no Program before publication, and execution through
two Instances. Rewriting a member after the ordinary job started left its
result at 77, while a fresh compilation returned 42. Input Instances returned
77 and 42 from different snapshots. Both native processes exited with zero
live SDK allocations. Local receipt:
`build/runtime-engine/20261121T082229339823Z/receipt.json`.

## Engine-owned project output compile

Configured rooted and anchored projects now reuse the private input-output job.
The Engine keeps the checked manifest output mode through publication. It
rejects reachable emit without a matching declaration and preserves an explicit
declaration even when the selected entry does not emit. A busy job is rejected
before consuming an anchor. File acquisition and entry selection are synchronous.

The development suite reproduced Windows exit `0xC00000FD` at output proof
initialization. Initializing the proof and normalized scratch fields directly
in the reserved heap slot removes the whole-value stack construction and Vec
push. The original regression now passes with the default stacks in development
and /O2. Both profiles also verify authority before acquisition, rejected emit
without publication, two independently bound Instances and zero live SDK
allocations at teardown. The locked /O2 CLI quick start returned 77. Local
receipt: `build/runtime-engine/20261121T084904682045Z/receipt.json`.

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

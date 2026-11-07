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
| Conservative lowering heap, including old/new growth | 262,144 | 262,144 |
| Required working allowance | 436,544 | 436,928 |

Entry is 80 bytes and InputEntry 128 bytes. Index contains one immutable Stored
in an eight-element backing block; Stored is 21,720 bytes. The 48-byte vector
descriptor and inline Snapshot/Table are not added again as separate heap
allocations. The caller constructed Index before transferring Entry: denial
does not undo that earlier external allocation. It consumes/destroys the supplied
Entry without allocating an additional incoming block.

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

The transport pins 22 typed bindings and now compares all 16 reviewed layouts
against actual emitted declarations. Entry/InputEntry and a new Instance witness
fix the concrete types used for backing facts and sizeof. Instance is 120 bytes;
using an old numerical generated type ID can otherwise select an unrelated
struct after metadata changes. Current inline Engine is 688 bytes; control heap
remains 6,720 bytes for one slot and 53,760 at all-64 counts.

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

Per-Instance frames/input/owners/loans/descriptors/output, simultaneous Instance
peaks, pending host state, native stacks and the remaining combined Engine quota
are open. Bounded steps, deadlines, cancellation/poison and public delivery remain
in [the accepted inventory](../product/04-remaining-work.md). Public gates, VM
capacities, opcode prices and Fuel defaults/ceiling are unchanged.

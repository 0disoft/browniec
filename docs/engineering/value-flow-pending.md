# Sparse pending PCs in view ownership proof

`value_view_flow` independently checks view origins and pinned Buffer owners in
the private typed/value verifier. A backedge can widen a header's origins and
require earlier instructions and already processed exits to be checked again.
This change only replaces the pending-PC scheduler. Transfer, merge, validation,
step limits, preflight and unreachable-code rejection are unchanged.

The original scheduler scans every PC in ascending order on every sweep,
including a final empty sweep. For N instructions and R sweeps its pending-flag
poll count is N*R, even when few PCs change. The replacement stores the 256
pending flags in four 64-bit words. It skips empty words and locates the first
set bit with six binary tests. An immediately pending successor uses one direct
bit test and skips the search. Otherwise a take examines at most four words,
six binary tests and one direct bit test. A wrap can add four empty-word tests
and one direct bit test. These are structural scheduling bounds, not elapsed-time measurements; dense worklists
use the direct-successor path, though bit manipulation and call overhead remain.

For U processed PCs, selection takes at most 16*U+10 word/bit tests rather than
N*R flag polls. Under the existing 256-PC admission, a sparse scheduling trace
that repeatedly requeues only PC255 for 1,000 sweeps requires 256,000 old flag
polls, versus 4,000 nonempty/empty word tests, 6,000 binary tests and 1,000 direct
bit tests. The final empty selection adds at most ten word/bit tests. The old
scheduler adds 256 flag polls for its final empty sweep. This synthetic
scheduler trace is an operation-count illustration, not a measured compiler speedup or a claim
that that trace is an admitted guest CFG.

The pending payload shrinks from 256 bool cells to four usize cells: 256 to 32
logical bytes on the pinned Windows x64 transport (87.5% less). No heap
allocation, ledger field, compiler scratch carrier or public API is added.
The existing 32 KiB origin table is unchanged; no native stack peak is claimed.

The caller retains the ascending cursor. Forward insertions run in this sweep;
insertions at or behind the current PC wait for the next sweep. Duplicate
insertions coalesce. Range-excluded bits remain pending. Thus processing order,
iteration count, first error kind/offset and convergence behavior are preserved.

`tools/verify-value-flow-pending.py` selects six native groups. Scheduler tests
cover every PC (including 63/64, 127/128, 191/192 and 255/256 boundaries), all
256 eight-bit masks in four words, and a 10,000-step deterministic trace with
duplicate, backward and same-PC insertions against the original flag scheduler.
A frozen copy of the original verifier compares results and exact errors for
scalar, joined-root, borrowed-CALL and loop programs, with corrupt extended
instructions and injected pinned drops. Existing multi-round widening IR
groups recheck earlier writes and already processed exits; a view-join source group verifies actual loop/terminal cleanup
and VM execution.

Run development and release individually, using the pinned compiler and default
native stacks, with no compiler, optimization or timeout overrides. Receipts
are written to `build/value-flow-pending/<profile>/receipt.json`. This is private
typed/value support, not public CLI admission. Full Engine, memory, public CLI
and release gates are outside this focused change.

Development and O2 each passed all six native groups with byte-identical locked
inputs. See the [evidence](../evidence/value-flow-pending-windows-20261114.json).
The initial broader build was stopped and remains incomplete, not a pass.

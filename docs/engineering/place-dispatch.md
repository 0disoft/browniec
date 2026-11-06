# Shared native place dispatch

Date: 2026-11-06. Successor to [metered aggregate snapshots](aggregate-place-vm.md).

The [execution successor](aggregate-place-execution.md) now connects this adapter
to both VM drivers, complete executable admission and retained guards. The
frontier and verification below retain this native dispatch checkpoint's scope;
ordered guest aggregate-place source lowering is next.

## One allocation and one namespace

`place_dispatch` plans and prepares one invocation-owned place vector. A Program
with kinds 3/4 uses the aggregate-capable format for every place kind, with width
derived from the highest ID across all kinds. It shares one active counter per
frame. A scalar array, exclusive slice, record scalar, whole array and nominal
record subtree therefore cannot independently reserve the same live ID.

Programs without aggregate places delegate to the original record-capable
planner/preparation. Their row widths (9 or 14), prefixes (0, 1 or 2), setup
prices, operation prices and empty-vector behavior remain unchanged. An aggregate
invocation retains the existing eighteen-word format and its one allocation:
at most 9251 initialized words / 74008 bytes, not one vector per location kind.

The common format recognizer authenticates prefix 3, marker, row size, serial
and exact length. Legacy adapters can now operate on its rows while keeping
their own IR-kind gates. Array snapshots use words 0..7, slices 0..12 and scalar
records 0..9; remaining words through 16 must be zero. Word 17 retains their
original packed scalar tag/root/kind/phase. Aggregate rows retain thirteen
destination words, root, SELECT PC, kind, ticket and plain phase. The two phase
encodings and reserved words reject cross-kind reselection before publication.

Only aggregate selection advances the invocation-local serial. Legacy SELECT,
READ, STORE and END cannot erase/reset it. Ordinary END routing uses the active
row's kind rather than its untagged instruction or a later destination binding.
It clears all eighteen words and decrements the shared counter exactly once.
CALL/frame reuse and normal-return callers can check the same counter through
the common empty-frame helper.

## Prices, bindings and cleanup

The dispatcher prices before reading array/slice binding maps or authenticating
native owners. Current record SELECT/source bindings come from the coordinator
after its matching preflight, just as in the existing record adapter. Native
transactions still validate actual owner tokens, restored slice tickets, original
reservations/windows, scalar codecs and atomic staging. No binding-map copy,
payload preparation or instruction-time allocation is introduced.

Legacy scalar SELECT/READ/STORE prices remain their original values even in a
mixed invocation. END costs 26 only in the eighteen-word format; existing
nine-/fourteen-word invocations keep 17/22. Aggregate setup and all five aggregate
store prices remain those of the predecessor. The common abort helper needs no
remaining Fuel: setup already covers bounded metadata destruction. It clears
rows/counters and keeps each format's prefix, including the aggregate serial.
Neither abort nor END changes payload or owner/loan metadata.

The aggregate `bound` adapter consumes complete immutable admission directly;
it needs no per-instruction Prepared catalog allocation/copy. The older native
`step` entry retains its prepared-leaf check and price/transaction behavior.
Actual layouts are still independently replanned by native owner transactions
after prepayment. Neither entry by itself issues executable admission.

## Driver and admission frontier

This common native dispatcher is the prerequisite for connecting both ordinary
and retained coordinators. Those drivers still call their legacy dispatch at
this checkpoint, and executable admission still permits kinds 0..2. Existing
source syntax, capability metadata, prices/default256/cap16000000 are unchanged.

Next, replace the two drivers' split planning/dispatch with this shared adapter,
preflight total setup before backing/owner entry, and drain place metadata on
every failure at zero Fuel. Preserve current frame reuse and every scalar,
aggregate, reference and void return check. Before promoting executable admission,
update the retained guards together: kind3 names an array owner; kind4 names a
record site and nominal ID, never an array/slice root or scalar input. SELECT's
aggregate metadata and STORE's source owner are not scalar reads. REPLACE87 must
track its fill scalar, dense list operands or consecutive constructor inputs.
Ordered source lowering follows complete execution/admission verification.

Run `python -B tools/verify-place-dispatch.py --profile development` and repeat
for release. The core tests exercise simultaneous kinds0..4, all twenty directed
cross-kind collisions, frame31, independent exact scalar/read/store/END prices,
Fuel-before-binding preflight, abort/serial preservation and legacy no-allocation
behavior. Native aggregate and legacy price/gate regressions are selected
separately; public Fuel CLI regression remains a separate runner.

Full language/native Fuel matrices, LF mirrors, Linux, OOM injection, general
stack/performance and clean-machine delivery are outside this selection.

Windows development/release each passed **19 native groups and 105 tool-free
public Fuel CLI cases** on implementation `fa33853`. Development combines four
same-turn core groups and fifteen regression groups. Only the regression selector
in the runner changed after the core check; all production and test inputs stayed
unchanged, and the original/final runner hashes are recorded. Release runs all
nineteen groups fresh. The current 198-input union matches checkout and Git raw
bytes, with 177 LF production modules, 304 test-source files and 1821 annotations.
The test-source inventory is not a full-suite pass. No historical result or native
compiler/linker/stack override was used. See
[Windows evidence](../evidence/place-dispatch-windows-20261106.json).

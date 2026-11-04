# Executing lexical returned CALL bindings

Date: 2026-11-04. This connects the [source bridge](m2-slice-result-call-source.md)
and independently proved [binding IR](m2-slice-result-call-ir.md) to the canonical
private VM. The [full objective](completion-plan.md), other B04 requirements and
public promotion remain open.

## Dispatch and returned authority

Private VM admission now runs the complete independent result verifier for
CALL_BIND/END_CAPTURE/BIND_RESULT instead of rejecting those instructions before
verification. Public compilation, ordinary Program admission and capability
metadata retain their existing returned-reference gate.

CALL_BIND (66) uses the existing scalar/array/record argument transaction. It
passes `160 + byte5` as its caller frame destination. Its byte4 mask marks only
proved anonymous exclusive captures for native handoff close; other arguments
keep their existing flags and lexical cleanup. Native handoff restores these
caller children in reverse acquisition order before creating the returned Held.
It preserves the actual selected range rather than using the zero proof witness.

On return, the frame coordinator rebinds each masked argument's fresh resumed
ticket to that argument's surviving parent and clears the dead anonymous site.
For the selected writer the parent remains suspended until the new result closes.
The retained Held's parent location is byte6's proved caller site, which can
itself be another retained returned binding. It is not the dead argument child.
Unmasked arguments retain the old exact-site publication path.

END_CAPTURE (68) verifies that native handoff already cleared its child site.
BIND_RESULT (67) verifies the returned receipt is retained at its result site.
Both consume normal instruction dispatch but never acquire/close another loan or
truncate the returned range. Subsequent guest reads, writes, lengths and UTF-8
operations use the canonical ticket and actual view. Later CLOSE/END consumes
the prepaid Held finalizer and publishes a fresh parent ticket. The existing
sparse 47-entry registry supports nested same-slot writer receipts.

Source-retained anonymous parent/owner names now drive actual lexical cleanup:
returned result first, then anonymous parent, then owner. Unselected temporary
views/arrays/records still clean up immediately after the call. Native value
inputs remain independent copies. Returning a bound reference from another
reference-returning function uses the existing terminal handoff and consumes
that frame's old receipts rather than closing transferred authority twice.

## Fuel, failure and bounded work

The later [public Fuel/limit contract](public-fuel-limits.md) supersedes this
increment's 1000000 CLI ceiling discussion with an explicit 16000000 ceiling.
Its default remains 256 and the prices described below are unchanged.

The existing schedule and public CLI Fuel default/cap are unchanged. CALL_BIND
pays the existing dispatch, arity, metadata/abort reserve and aggregate-copy work.
Borrowed return prepays final close. Ghost markers pay one dispatch each; masked
END work belongs to the funded native handoff, not a second slice-operation fee.

Rebinding at most eight masked arguments scans at most 8 * 256 = 2048 instruction
records to recover their independently proved BEGIN parents. The sparse receipt
lookup scans at most 47 records (retain uses two bounded passes). These additions
fit the existing 32768 fixed handoff allowance alongside bounded root/pending
scans and frame publication. They add no persistent per-frame map or payload copy.
See the [updated bounded audit](m2-slice-result-fuel.md). These are conservative
work bounds, not native instruction, stack-size or elapsed-time measurements.

Exact-budget completion may return zero Fuel. A one-short budget preserves the
first Fuel trap and drains invocation metadata at zero. Errors after successful
initial entry drain invocation owners/loans while preserving prior payload writes.
Admission and initial-entry failure preserve supplied native inputs. Native callers
must revalidate their tokens after execution failure, as in the original entry
contract; private receipts are linear coordinator values, not a public C ABI.

Simple single-result examples for all scalar/access modes fit 1000000 native Fuel.
Complex ranges, nested/recursive results and mixed owned calls use explicit larger
native budgets in the tests. They are not evidence that every program fits the
public CLI's 1000000 cap. C05 must deliberately reconcile full-profile limits and
public returned-reference execution budgets before capability promotion.

## Evidence and remaining work

The focused [Windows record](../evidence/m2-slice-result-call-execution-windows-20261104.json)
records 25 development groups (seven new execution, nine IR/admission and nine
existing returned-view execution groups), and eight release groups (the seven new
groups plus native-input IR preservation). All 123 captured inputs and the
aggregate identity of all 210 test-discovery files match. All 117 production
modules use LF; an LF mirror passed `check --locked`. Native selections and
exclusions are retained. Standalone CLI and broader/full-profile/platform/
delivery/performance checks were not run. Cases cover all six scalar/access modes, actual
range composition, parent reuse, nested/recursive forwarding, selected literals
and owned CALL results, mixed array/record copies, native owned entry, zero-Fuel
close, exact/one-short/initial-short Fuel, bounds traps and prior writes. The
formerly gated raw-IR case now proves execution plus invalid-recipe input preservation.
Its input-construction scratch is in a separate function from the live VM call,
so temporary pool/table snapshots do not overlap that call's development stack.
Final verification uses the default compiler/stack settings.

No public result flags or ordinary Program layout are promoted. Next finish
borrowed-result arguments/projections and Static backing, deliberate public
Program/CLI admission/dispatch and Fuel-limit reconciliation. General references,
Buffer, Engine/Instance, host exchange, restricted delivery, DLL/packaging and full
conformance/performance evidence remain in the accepted completion inventory.

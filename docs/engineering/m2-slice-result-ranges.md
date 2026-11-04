# Returned scalar-slice ranges

This B04 increment accepts `return ref [mut] parent[lo..hi];` in the separately
admitted returned-view dialect. It also accepts omitted lower/upper bounds,
whole and empty ranges. Bounds are relative to the parent's current view.
The public compiler's declaration gate remains until general result bindings
and ordinary execution admission are connected; this is not B04 completion.

## Lowering and lifetime

The lower endpoint is evaluated and captured before the upper endpoint. Both
must be exact `usize`. No child is acquired before both evaluations succeed.
Endpoint calls use the existing CALL transaction and restore their borrowed
actuals before range acquisition; a failure preserves their earlier writes and
drains the invocation under the existing zero-Fuel abort contract.

`slice_result_range_source` creates an anonymous site with existing immutable
origin metadata. Shared views use SUBSLICE; exclusive views use BEGIN. Length
preparation selects that site, followed by CLOSE/END before the visible parent
cleanup and terminal return. Independent origin/CFG/loan proof sees the ordinary
lexical recipe, including the same exact access mode and scalar type.

Private IR normalization converts the preparation into PREPARE_VIEW and the
terminal into RETURN_VIEW. The VM defers the terminal recipe to its existing
handoff transaction, so the selected subview survives caller restoration. Native
Held finalization uses its prepaid cleanup and may run with zero remaining Fuel.
No new opcode, Program field, authority ledger, payload copy or public flag is
introduced. Existing prices apply to endpoint work, SUB/BEGIN and handoff.

Returning a view of a local/by-value root, wrong scalar/access modes, non-usize
bounds or a malformed cleanup recipe remains invalid. Reversed/out-of-bounds
ranges fail at execution before child publication. Static backing and general
result locals/arguments/projections remain separate B04 work.

## Focused validation

`tests/m2/slice_result_ranges.fy` covers all six scalar types in both access modes,
open/empty/dynamic/relative ranges, forwarding, exactly-once endpoint order,
endpoint traps and bounds errors, origin/type rejection and independent cleanup
mutation. Native execution and regression results are recorded with the increment.

Windows development passed 27 native groups: four range groups, eight existing
origin groups, six Fuel groups and nine returned-view execution groups. The
native CLI additionally passed 36 lexical cases and 208 existing origin/temporary
borrow cases. Release, Linux, the full M1/M2 suites, isolation, ABI, allocator and
performance measurement were not run for this increment. Full-runtime test
execution requires the native backend; the semantic interpreter cannot execute
std::text::validate_utf8's byte-slice operations.

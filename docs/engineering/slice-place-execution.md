# Exclusive-slice places in both VM drivers

Date: 2026-11-06. Successor to [metered native storage](slice-place-vm.md)
and [independent slice-place proof](slice-place-ir.md).

## Admission and execution

Complete ordinary, image, generic-reference and returned-reference admission now
accepts kind-one exclusive-slice SELECT/READ/STORE after canonical scalar, owner,
loan, function, CALL, CFG and common location identity/phase/lifetime proof.
Analysis-only inspection still confers no executable receipt by itself. Existing
executable CALL-shape admission remains mandatory in every function.

Both ordinary and retained drivers use `slice_place_vm::bound`. It preflights the
actual stored format and complete operation cost, then resolves the exact
frame/site entry from the invocation coordinator's 512-ticket binding map.
Ordinary execution uses `slice_vm::State.tickets`; retained execution uses
`slice_result_frames::Frames.sites`. These are the maps already published by
canonical OPEN, CALL entry/return and lexical BEGIN/END. No opcode, ticket
register, guessed pool ticket, new root/loan owner or public source capability
is introduced. END and array operations do not need a current slice ticket.

The existing snapshot adapter authenticates the current ticket, original owner,
session, range, reservation, index and byte offset before accessing a scalar.
Parent and child frames may use the same place ID; snapshots and counters remain
frame-local. READ retains the old scalar across RHS operations. Completed CALL
and lexical restoration update the binding map before a pending parent STORE.
Suspended-parent use and closing a selected child are rejected by the independent
proof, including equal-range children.

## Setup, cleanup and retained guards

Both public wrappers preflight complete list/place/backing/entry costs before
allocating backing or transferring owners. Both drivers reserve the extended
snapshot cost exactly once and allocate one bounded invocation vector. Array-only
programs retain their old layout and prices. Every normal scalar, owned array,
record, reference and void return checks that frame's place counter is empty;
CALL checks the child frame before reuse. Common END clears the active kind's
row. Any error discards the vector and runs existing canonical abort cleanup,
retaining earlier payload effects and the first error. There is no automatic
replay. A caller may explicitly start another invocation after cleanup.

Static recipes accept only kind0/1 on SELECT/READ/STORE, with remaining reserved
bytes zero. Their complete ordinary proof still establishes shape and authority.
Existing recipe scalar-use checks include SELECT's index and STORE's scalar;
prepared returned identities cannot be used as ordinary scalars. READ's exact
scalar destination and shared END cleanup retain their existing proof rules.

Returned-reference lifetime guards now interpret each place operand according
to its kind: arrays name zero-based owners, slices name sites whose one-based
root is reconstructed from canonical metadata. Rootless formals carry no local
owner dependency. A same-numbered slice on an unrelated owner remains usable
while a returned view protects another owner. Opening exclusive access on the
protected actual root still fails before runtime allocation or payload effects.

## Fuel

Private operation and setup prices are unchanged from the storage prerequisite.
Retained execution adds its existing one-unit dispatch per place/slice/aggregate
operation. Public default 256 and ceiling 16000000 remain unchanged.

The exact fixture initializes i32[2] with 20, selects index 0 through an exclusive
slice, reads the old scalar, adds 22, stores, ends the place and returns the actual
slice element. Four scalar constants and checked addition/return cost 6; array
initialization/drop cost 72/49; OPEN/CLOSE cost 65537/4097; SELECT/READ/STORE/END cost
4129/4166/4170/22; the final slice READ costs 4134. The ordinary body costs 86382.

| Entry | Required Fuel |
| --- | ---: |
| Ordinary native with eight backing bytes | 91458 |
| Ordinary public with 65536 backing bytes | 156986 |
| Retained native over caller-owned eight-byte backing | 435522 |
| Retained public with 65536 backing bytes | 501059 |

These include extended preparation 5067. Retained native adds 147456 initial entry,
196608 final leave and nine extra dispatch units. Exact and one-short ordinary/
retained public boundaries are tested independently; a native retained boundary
also requires remaining Fuel 0. At native retained Fuel 230607, STORE has published
42 but the following END cannot start: abort must retain those bytes and drain
metadata before an explicit fresh invocation.

## Verification and remaining work

`tools/verify-static-execution.py --selection slice-place-execution` covers both
profiles: exact costs, all six scalar types, caller/formal same-ID selections
across CALL and lexical restoration, observable RHS writes, post-store Fuel abort
and explicit retry, malformed early admission, returned-owner mapping, existing
slice proof/array execution and original ordinary/retained 32/33 CALL boundaries.
Public CLI Fuel regressions run with `tools/verify-public-fuel.py --phase cli`.
Actual executed scope and input identities are in the
[Windows evidence](../evidence/slice-place-execution-windows-20261106.json).

The [source successor](slice-place-assignment.md) now connects bounds-before-RHS
selection and ten checked integer compounds, sharing pending IDs and nonlocal
cleanup with owned-array assignments. Its new source IR changes total Fuel and
adds two version flags; the execution evidence below retains its original scope.
Record/scalar-local places, grouped lvalues, generic aggregate overlap and full
L04/C05/Instance/host/delivery remain open. Full language/original native Fuel
matrices, Linux, OOM, general stack/performance characterization, isolation and
packaging/clean-machine delivery are outside this check.

Development and release each passed **22 native groups** (six new execution
and sixteen existing proof/array/lifetime/CALL groups) and **57 tool-free public
Fuel CLI cases**. Each native receipt covers 176 matching inputs; each CLI receipt
covers 180. The 186-path union matches the checkout and staged Git raw bytes.
Both locked LF mirrors pass, with 167 LF production modules and common
288-file discovery. 40 unselected legacy discovery fixtures differ only by
CRLF/LF; both hashes are recorded. No historical results or stack overrides
were reused. Skipped scopes above remain unverified by this check.

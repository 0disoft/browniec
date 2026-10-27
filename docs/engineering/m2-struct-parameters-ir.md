# M2 Private Record Parameter IR and Verification

The historical availability gate described here is superseded by the
[metered record-call VM](m2-struct-call-vm.md). Source record parameters stay gated.

- Status: implemented at `9b43e0d`; development and release aggregate verification passed.
- Scope: `record_parameters` metadata, its builder, independent verification,
  the record slot of the existing eight-argument `CALL`, parameter lifetimes and
  the VM gate. Owner copying, VM call entry and source record parameters remain
  unavailable.
- Implementation: [metadata and arguments](../../src/struct_parameters.fy),
  [IR builder](../../src/ir.fy), [call checks](../../src/array_parameters.fy),
  [struct instructions](../../src/struct_verifier.fy),
  [verification](../../src/verifier.fy) and [VM gate](../../src/vm.fy).
- Tests: [IR cases](../../tests/m2/struct_parameters_ir.fy). Selection:
  `python -B tools/verify-m2-struct-values.py --parameter-ir`
  (`--profile development|release`). Evidence:
  [Windows receipt](../evidence/m2-struct-parameters-ir-windows-20261027.json).

## Metadata

`ir::Program` adds one 128-byte `u8[128] record_parameters`, indexed by register.
Zero means scalar or array; otherwise it is an immutable callee record site ID
plus one, in 1..16. `ir::record_parameter` reserves one site through
`record_in(..., false, ...)` and one register at `p.registers`;
rejection changes neither count. The formal's `types` and `array_parameters`
entries stay zero. Scalar operand checks reject the placeholder, entry
definitions skip it, and only record ownership instructions name the site.

## Independent validation

`struct_parameters::metadata` walks all 128 registers after function and catalog
partitions are checked. An entry must be below `p.registers`, inside its
function's formal span, and within `p.records.count`; it must not be a mutable
slot, `array_parameters` and `types` must be zero, the site immutable, and
`record_functions` must match. One site backs one formal; `array_parameters`
rejects the reverse overlap, and other registers need a type and a write.

## Calls

The existing eight-argument `CALL` (9) uses scalar registers 0..127, array
128+site (128..143), and record 144+site (144..159). A record argument
must be live, caller-owned, immutable and an exact nominal match for the formal.
Mutable records require an explicit immutable `SCOPY` (42) snapshot. The verifier
checks these inputs; executing the call's copy remains unavailable.

`array_parameters::arguments` runs these checks for ordinary and array-result
calls; tests cover mixed scalar, array and record positions, an array result,
self-recursion, joins and backedges, with edited violations failing as expected.

## Lifetimes

`struct_parameters::initial` sets bits 16..31 for each function's formals. A
parameter is live at entry: a drop clears it, both join arms must agree, and a
backedge must preserve its target's live set. `RET` requires no live owner and
`ARET` the sole live callee array, so every formal must be dropped first.

`SINIT` and `SCOPY` reject a formal destination even after a drop, using the
function's initial parameter mask. `SWRITE`, `SASSIGN`, `SSUBASSIGN`,
`SREPLACE` and `SSUBREPLACE` require a mutable site, so every write fails.

## Runtime boundary

After verification, `vm::run_with_array_limit` scans `record_parameters` before
Fuel subtraction, payload preparation or call entry. Any nonzero entry returns
`unavailable` (kind 11) at offset 0; malformed metadata fails verification first
with kind 5. At this IR checkpoint no record owner copy or VM call entry exists, so verified
record-parameter IR cannot execute; source record parameters stay gated before IR
or body lowering. The slice adds no opcode, Fuel charge, source form, profile or
version capability. The array is metadata; no payload, allocation, stack or speed
change is measured. Limits stay at 16 sites, 32 nominal types, 128-byte roots, 128 registers, 256 instructions, 16 owners and 65,536 payload bytes; tests reach
register 127, formal site 15 and live bit 31, and reject site 16.

## Verification

The seven-group native smoke passed. Each development/release profile passed 28
native groups (7 new, 9 `array_calls`, 6 `struct_function_ir`, 6
`struct_parameter_signatures`) and 2,226 CLI cases (88 signature gate, 89 helper
record, 80 array parameter, 1,969 M1). The default two-profile aggregate
completed without result reuse. All 182 input hashes, matching native identities,
the compiler hash and current release executable were rechecked before archival.
Compiler `4ce1264273be` and SDK lock identity are unchanged. Earlier receipts are
historical for changed IR, verifier, VM preflight, root-lock, test and harness inputs.
Full native suites, other CLI matrices, M0, Linux, packaging, DLL, isolation,
allocation instrumentation and performance were not run.

## Status summary

Record formals are immutable callee sites in register metadata, with exact-nominal
live sources through `CALL`, live bits 16..31 and mandatory drops. The VM reports
unavailable before Fuel and source parameters stay gated. Development and release
each passed 28 native groups and 2,226 CLI cases.

The [mixed argument-copy successor](m2-call-argument-copies.md) adds private
transactional owner copies and changes owner/storage, root-lock and harness
inputs. The receipt above remains evidence for `9b43e0d`; record-parameter VM
entry is supplied by the metered successor; source calls remain unavailable.

# M2 Private Record Result VM Ownership Transfer

- Status: implemented at `68552f0`; verified in development and release
- Scope: metered `SRET` (50) execution and caller-owned record-result destination transfer
- Source: unchanged; record returns remain behind the compilation gate
- Predecessor: [record-result IR and verifier](m2-struct-results-ir.md)
- Implementation: [struct_result_vm.fy](../../src/struct_result_vm.fy),
  [vm.fy](../../src/vm.fy), and [array_owners.fy](../../src/array_owners.fy)
- Tests and harness: [struct_result_vm.fy](../../tests/m2/struct_result_vm.fy) and
  [verify-m2-struct-result-vm.py](../../tools/verify-m2-struct-result-vm.py)
- Evidence: [Windows receipt](../evidence/m2-struct-result-vm-windows-20261028.json)

This slice connects the verified record-result IR to native frame transfer. A
record-result call declares a caller-owned destination at `144 + site`; `SRET`
selects one live exact-nominal callee record and moves its existing owner token
to that destination. No source record-return form is enabled.

## Charge and dispatch

`struct_result_vm::cost` returns 42,113 Fuel:

```text
2 * 18432 + 4096 + 1024 + 129 = 42113
```

The charge covers two complete layout plans, one bounded scalar snapshot,
scratch/codec work, both child token sets, and owner metadata. `step` checks the
full charge before any frame, token, owner, or payload work. Insufficient Fuel
reports kind 8 at the `SRET` offset.

The VM handles opcode 50 before the generic `>= 41` record dispatch. It obtains
the result shape from the active call site, the source token from operand `a`, and
the destination from the saved CALL destination. The frame and return PC are
updated only after `step` succeeds.

## Preflight and transfer

Independent verification establishes caller ownership and rejects formal sites
as destinations. After the Fuel check, transfer requires a bounded frame, valid
function and record counts, target/source/destination bounds, active exact metadata, zero scalar and
array results, matching function ownership, and the same planned nominal shape for
the callee source and caller destination.

The parent destination token must be dead. Every array token in the child frame
must be dead, and every record slot other than the source must be empty. The
source must then resolve to one live record owner with valid metadata and the
complete declared layout. `owners::validate_record_result` stages every scalar
leaf, including canonical nested bool validation, through a 128-byte scratch buffer.
This bounded validation reads payload and writes no payload bytes.

After every fallible check succeeds, `step` clears the child record token and
publishes that same token in the parent. The owner descriptor, arena order,
generation, and payload bytes remain unchanged. Transfer reserves no additional
owner or payload extent and performs no payload copy. Scratch use is bounded work;
these fixtures do not establish a no-copy performance benchmark.

A failed preflight leaves parent and child tokens, owner fields, and payload bytes
unchanged. The VM does not publish the return frame or PC on failure. Runtime
failure aborts the invocation as before; external effects are not rolled back.

## Result value and caller storage

The verifier controls which caller record site receives the result. Whether that
caller-owned destination is mutable follows its IR catalog flag, so returning a
record does not decide how the caller later uses its storage.

Returning a record parameter transfers the existing independent callee copy made
when the call entered. Changing the returned record therefore does not modify the
original caller argument. Source record returns remain gated in this slice.

The existing 16 record sites, 16 shared owner descriptors, 32 VM frames, 65,536-byte
payload cap, and 256-instruction bound are unchanged. New record-result pricing
leaves existing scalar or array charges unchanged. The source version/profile selection and
`--version --json` capabilities are also unchanged.

## Verification

```text
python -B tools/verify-m2-struct-result-vm.py --phase core
```

Development and release each passed 34 native groups: 8
`struct_result_vm`, 8 `struct_results_ir`, 6 `array_result_vm`, 8
`struct_call_vm`, and 4 `functions`. The harness also built the CLI and passed 2,317 cases per
development/release profile: 72 record-result-signature, 66
record-formal-signature, 114 source-parameter, 96 array-result-signature, and
1,969 M1 cases. The [receipt](../evidence/m2-struct-result-vm-windows-20261028.json)
records the actual commands, compiler/SDK and artifact identities, and inputs.

The eight new native groups cover six scalar edge values with flat and nested
layouts at their exact quotas; 24 repeated and deferred-hole returns; one 4-byte
owner across all 32 frames and the frame-limit failure; mixed scalar, array, and
record arguments with parameter independence; 18 failed-transfer rollback
variants; rejection of nominal mismatches and array tokens as record results; a
direct transfer with a full 16-owner table, a 128-byte payload arena, padding,
and site 15; and exact
Fuel boundaries. The simple i32 factory completes with 129,616 total Fuel; 129,615
reports kind 8. Fuel 88,265 stops at the `SRET` annotated with source offset 73.

Implementation: `68552f0`. All 215 input hashes, the compiler, SDK and final release CLI
were rechecked before archival. The initial native development attempt passed
33 of 34 groups; the exact-Fuel fixture had a 100-Fuel expected-total error.
After correcting that fixture, the complete harness passed both profiles without
reusing that failed attempt. The IR slice's gate and evidence remain historical
for their original inputs.

Full native/CLI suites, M0, Linux, worker isolation, DLL, packaging, allocation
instrumentation and performance were not run. This evidence executes private IR;
source record returns remain unavailable.

# M2 Private Record Call Execution

- Status: implemented at `97bf1e2`; verified in development and release in two phases.
- Scope: CALL (9) pricing and execution through `struct_call_vm`, the mixed
  record and array argument transaction, and the VM-side scalar binding and
  frame publication for calls with record parameters.
- Implementation: [call charge and transaction](../../src/struct_call_vm.fy) and
  [CALL routing](../../src/vm.fy).
- Related contracts: [mixed call-argument copies](m2-call-argument-copies.md),
  [record-parameter IR](m2-struct-parameters-ir.md),
  [array CALL execution](m2-array-calls.md), and
  [frame-local record VM](m2-struct-function-vm.md).
- Tests: [struct-call cases](../../tests/m2/struct_call_vm.fy); the
  [record-parameter IR cases](../../tests/m2/struct_parameters_ir.fy) now assert
  execution of a verified record-parameter program instead of the removed
  availability gate.
- Harness: [tools/verify-m2-struct-call-vm.py](../../tools/verify-m2-struct-call-vm.py),
  with `core` and `regressions` phases.

Verified IR programs can now pass record parameters to a callee. A CALL copies a
caller owner snapshot for every aggregate argument before the child frame runs.
Source record parameters stay rejected. This slice adds no opcode, source
profile or version field; record calls gain the Fuel charges below.

## Charge

`struct_call_vm::cost` rejects a target with more than eight formals, a register
window start above 128, or an arity that leaves the 128-register window, then
delegates array pricing to `array_call_vm::cost`. A call with no record formal
returns that array price unchanged, so scalar-only calls add nothing here and
array-only calls keep their existing exact prices.

A call with `n` record formals costs `2048 + n * 43008 + array_work`. The
2,048 Fuel batch charge covers the 1024-byte record scratch slices and metadata
publication. Each record's 43,008 covers two full catalog plans
(2 * 18,432), a bounded 4,096 snapshot traversal, and 2,048 for scalar
staging, copy, and owner scans. Array work is charged once for the whole call
over the arguments that are arrays.

`struct_call_vm::step` charges `1 + call_arities[site] + cost`, so the whole
CALL is prepaid before frame admission, child token scans, source resolution,
scratch use, or owner and payload mutation. Insufficient Fuel reports kind 8 at
the CALL offset; a parent frame at or beyond 31 reports kind 12 after that
charge check. A call site outside the call catalog, or one carrying more than
eight encoded arguments, reports kind 5 before any charge.

## Transaction order

When a call has record formals, private `enter` runs as one transaction.
Array-only calls continue through the existing array helper:

1. Every array and record slot of the child frame must be dead; a live token
   reports kind 5.
2. Each formal resolves through its parameter encoding. Array arguments encode
   caller slots 128..143 and record arguments 144..159; the source token is read
   in the parent frame. Catalog count, site bounds, and the encoded slot are
   rechecked, records must name a planned record, and arrays carry their
   declared element and length.
3. `array_owners::copy_call_arguments` validates the dense batch against the
   original owner table, plans provisional slots and aligned extents, stages
   record snapshots and bool payload checks, and commits only after every
   argument passes. An owner error is reported at the CALL offset.
4. The returned tokens are bound in argument order, array tokens into the array
   state and record tokens into the record state.

The VM then copies each scalar formal from the parent frame, records the return
pc and destination, and enters the child frame. A failure in any step leaves
child tokens, owner descriptors, payload bytes, registers, and return slots
unchanged. External effects of earlier statements are not rolled back.

## Lifetimes and limits

Callee record parameters use the shared sixteen owner descriptors and the single
payload arena, with one sixteen-slot record group and one sixteen-slot array
group per frame across 32 frames, the unchanged 65,536-byte payload ceiling, and
the existing eight-argument call bound. Entering a frame allocates no separate
table or arena.

The verifier keeps record lifetimes in bits 16..31 beside array bits 0..15.
`RET` requires no live owner and `ARET` the callee's sole live array, so a
callee must drop every record parameter before either return. Generation checks
reject a token left in a released child frame, and one transaction cannot bind
the same child slot twice.

## Unchanged surface

The old kind 11 scan that refused every program carrying record-parameter
metadata before Fuel or payload preparation is gone; the verifier and VM handle
those programs now, so a verified program reaches preparation and reports kind 8
with zero Fuel and kind 13 with an over-cap payload limit. `compile` still
rejects every record-parameter declaration with kind 3 at the parameter offset,
including unused and forward helpers, so no source form became available.
Opcodes, the other opcode charges, aggregate preparation
(`1 + array_limit`), owner and payload limits, profiles, and `--version --json`
are unchanged.

## Verification

Executed separately:

```text
python -B tools/verify-m2-struct-call-vm.py --phase core
python -B tools/verify-m2-struct-call-vm.py --phase regressions
```

Development and release each passed 47 unique native groups: 21 core followed by
26 regressions. This is stepwise verification across the implementation commit,
not a single combined aggregate invocation. The
[core receipt](../evidence/m2-struct-call-vm-core-windows-20261027.json) and
[regression receipt](../evidence/m2-struct-call-vm-regressions-windows-20261027.json)
have identical 58 input hashes, compiler and SDK identities. Native selections
match across profiles and are disjoint across phases. All inputs and the current
compiler hash were rechecked before archival; the SDK is unchanged. Compiler
revision: `4ce1264273be`. Native images are tool-managed; no guest CLI artifact
was built. The original receipts retain their baseline commit and commands.

The core selection contains 8 new call groups, 7 record-parameter IR groups and
6 source signature-gate groups. It covers all six scalar bit patterns, repeated
calls, mixed scalar/array/record arguments, array-owner returns, recursive record
frames, shared owner/payload limits, exact CALL Fuel, underfuel snapshots, late
bad bools, quota and stale-token failures, dirty child slots, frame admission,
eight record formals and full 16-owner capacity. An obsolete gate expectation
was replaced by verified execution and preparation/metadata-order checks.

The regression selection contains 9 array-call, 6 array-result VM, 7 frame-local
record VM and 4 scalar-function groups. Existing array and scalar prices remain
unchanged. Earlier receipts are historical for changed VM, root-lock, test and
harness inputs. No CLI build or matrix, full native suite, M0, Linux, isolation,
DLL, packaging, allocation instrumentation or performance measurement was run.

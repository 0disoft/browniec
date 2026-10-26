# M2 Atomic Subrecord Assignment

- Status: implemented and verified in development and release.
- Integration commit: `5589803`.
- Evidence: [final combined receipt](../evidence/m2-struct-subassign-atomic-windows-20261027.json),
  [foundation receipt](../evidence/m2-struct-atomic-foundation-windows-20261027.json).
- Predecessor: [per-leaf subrecord assignment](m2-struct-subassign.md).
- Storage foundation commit: `2b5917c`.
- Native tests: [owner ranges](../../tests/m2/struct_subassign_owners.fy),
  [atomic verifier/VM](../../tests/m2/struct_atomic_source.fy).
- Combined selection: `python -B tools/verify-m2-struct-values.py --atomic`.

## Observable behavior

Source syntax remains `p.i = q.i`, `p.i = i`, or `i = p.i` with exact nominal
types and a mutable existing destination. The compiler now emits one `SSUBASSIGN`
instead of scalar reads and writes. All 16 source scalar leaves can be copied
within the existing CLI Fuel allowance, including a 128-byte selected record.
Immutable sources, self-assignment, sibling copies, deeper paths, and existing
owner/site saturation remain supported. Whole bare-binding assignment retains
`SASSIGN`.

The operation snapshots canonical scalar bytes into a fixed 128-byte local
buffer and publishes the selected destination bytes only after every check
succeeds. Padding within the selected record is zeroed; neighboring fields and
padding are untouched. Owners, generations, sites, arena use, and scalar
registers are unchanged. No guest allocation or temporary owner is introduced.

Fuel exhaustion, malformed metadata, invalid nominal ranges, stale tokens, and
invalid source bool bytes leave destination bytes unchanged. This guarantee is
for this one assignment. Earlier statements and external effects are not rolled
back, and fatal runtime errors still abort the invocation.

## Private instruction and verification

Opcode 47 uses the existing eight-byte instruction width:

| Byte | Meaning |
| --- | --- |
| 0 | 47 (`SSUBASSIGN`) |
| 1 | Destination binding ID |
| 2 | Source binding ID |
| 3 | Nominal selected record ID |
| 4 | Destination's first scalar leaf ordinal |
| 5 | Source's first scalar leaf ordinal |
| 6..7 | Reserved zero |

The independent verifier requires both bindings live in entry, a mutable
destination, and exact nominal record nodes at both ordinals. Matching scalar
tags or physical layout alone do not establish nominal identity. A bounded
iterative resolver checks node identity and byte ranges against a fresh complete
layout plan. Ordinals are not trusted byte offsets. Scalar SSA definitions and
live owner sets do not change. Only this opcode may use byte 5; byte 4 retains
its existing guarded-case meaning for opcode 24. All other reserved-byte rules
remain enforced.

Runtime dispatch prepays the complete 131,072 Fuel charge before any validation
or mutation. This ceiling covers five complete layout plans, four bounded
4,096-visit walks, byte staging, and owner scans. Owner lookup rechecks generation,
metadata, backing bounds, and alignment. Existing nested storage assignment then
validates and stages the entire selected record before its first target write.
There is no fallible step or additional Fuel debit during the final byte commit.

## Cost and limits

Assignment instructions decrease from 2*k to one and consume zero new scalar
registers instead of k. At k=16, assignment Fuel decreases from 1,320,992 to
131,072. This is a work-budget comparison, not a measured speed or RAM claim.
For k=1 the conservative atomic charge is higher than the former 82,562 charge.
The program's other operations retain their charges.

The source limits remain 16 leaves, depth 16, a 128-byte selected root, 16 record
sites, the shared 16-owner table, a 65,536-byte arena, 128 registers, and 256
instructions. Private IR remains internal; no bytecode loader or ABI is added.
Programs retain `brownie.m2-struct-nested/1`. Version JSON adds
`"struct_subrecord_assignment_atomic": true` alongside the existing assignment
capability. Constructor RHSs, aggregate calls, helper records, struct parameters
and results, and borrows remain unsupported.

## Verification

The foundation passed nine native groups per development/release profile,
including three new owner-range and six existing owner-copy groups. These results
belong to commit `2b5917c`, before VM integration, and are separate from the
final combined selection.

The complete `--atomic` invocation passed in development and release without
reusing prior results. Each profile passed 26 native groups: 4 atomic, 5 source
assignment, 8 existing VM, and 9 existing IR. Each passed 3,046 CLI cases:
131 assignment, 117 extraction, 88 child, 128 nested, 110 copy, 120 write,
144 values, 124 declarations, 115 array-literal assignment, and 1,969 scalar.
The receipt records 99 input hashes, compiler/artifact identities, commands, and
outcomes. All input and compiler hashes were rechecked before archival. The final
release binary matches its CLI hash; both profiles select the same 26 native
identities.
CLI cases cover 16-leaf u8 and 128-byte usize records with observed copied fields.

Full native suites, full array CLI matrices, M0, Linux, isolation, DLL, packaging,
allocation instrumentation, and performance measurements are outside this slice.

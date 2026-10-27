# Validate the original owner table once per copy batch

`array_owners::copy_arguments` and `copy_call_arguments` preflight a complete
batch against the original owner table. Reservations and provisional owners are
written only to the separate `planned` table. Backing bytes and the original
table are published only after every fallible operation succeeds.

Previously each batch validated the full original table at entry, then again
through each `resolve`/`resolve_any`. Record arguments additionally called
`resolve_record`, which repeated the same token lookup and table validation.

The batch now keeps its initial full validation and uses a private `lookup` for
each token's slot bounds, nonzero generation, occupancy, liveness and generation
match. A separate private `record_metadata` retains full catalog planning and
exact owner length/alignment checks. Record snapshot validation, canonical bool
checks, nominal identity, array shape checks, reservation admission and atomic
publication are unchanged.

Public operations still use `resolve_any`: token checks precede the full table
check just as before. The lighter lookup does not prove table integrity and is
not exported. Batch entry still validates corrupt tables even with no arguments.
Sources are always looked up in the original table, so a later argument cannot
refer to a provisional destination. There are no callbacks or original-table
mutations between initial validation and publication.

## Derived work counts

For a successful batch of A aggregate arguments, R of them records:

| Path | Full original-table checks before | After |
| --- | ---: | ---: |
| Array-only `copy_arguments` | 1 + A | 1 |
| Mixed `copy_call_arguments` | 1 + A + R | 1 |
| Eight arrays | 9 | 1 |
| Eight records | 17 | 1 |

One table validation traverses D allocation-order entries and all 16 slots.
Original owner validation plus token lookup therefore changes from
O((1 + A + R) * (D + 16) + A) to O(D + 16 + A). Record layout planning, staged
reservations and payload work are unchanged. These are source-derived counts,
not elapsed-time measurements. No workspace, heap allocation, opcode, capability
or VM Fuel price is added or changed.

## Focused verification

Development and release each passed 27 native groups and 194 CLI cases (80 array
parameter and 114 source record parameter cases), with locked checks and builds.

The native selections are `array_argument_copies`, `call_argument_copies`,
`array_owners` and `struct_owners`. Existing tests cover stale and provisional
tokens, corrupt tables, nominal and shape mismatch, late invalid bools,
quota/owner failure rollback, deferred holes, eight arguments, all sixteen slots
and normal public owner operations. CLI coverage uses the array-parameter and
source record-parameter matrices.

The [Windows receipt](../evidence/call-owner-validation-windows-20261028.json)
records actual commands, outcomes, input hashes and compiler/SDK/artifact
identities. Full suites, Linux, M0, packaging, isolation and elapsed-time
benchmarks are outside this focused refactor. Earlier receipts remain evidence
for their original inputs.

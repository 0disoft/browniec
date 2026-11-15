# Share subrecord assignment owner-table validation

`array_owners::assign_subrecord` authenticated the complete owner table for
both destination and source. The destination check already covers every slot,
allocation-order entry, arena reservation and loan. The catalog, table and
backing length remain immutable until the final checked storage copy.

The source now uses the existing private `record_owner_prepared` helper after
destination table, catalog and owner-shape validation. It still checks source
token identity, live generation, record kind and exact catalog shape. No public
unchecked lookup, external Plan, cache or persistent proof is introduced.

Diagnostic order remains destination identity, whole-table integrity, destination
kind, full catalog and destination shape, source identity/kind/shape, nominal
ranges, checked extents and canonical source payload. A corrupt catalog still
wins over a stale source; corrupt unrelated table entries still fail before
source identity is examined. Retained dead owners remain valid reservations,
but their old tokens cannot be used as sources.

The two full catalog plans, both range walks and raw staged storage assignment
are unchanged. All source bools are checked before any backing write. Identical
source/destination still validates payload and normalizes selected padding.
No owner, arena, quota, Fuel, public admission or 128-byte scratch change.

## Structural cost

For successful assignments, complete owner-table validations fall from two
to one. With D retained owners, loop entries fall from 2D+32 to D+16; each
validation walks D allocation entries and all sixteen owner slots. At D=16,
entries fall from 64 to 32 and layout/reservation checks from 32 to 16.
For 4096 full-table assignments, entries fall from 262144 to 131072 and
reservation checks from 131072 to 65536. These are source-level counts; total
asymptotic complexity is unchanged, and throughput or physical peaks were not
measured. Other assignment paths are outside this change.

## Focused verification

Run `python -B tools/verify-subrecord-assign-preflight.py --profile all`.
The verifier uses locked byte-identical production mirrors and the pinned
compiler, without native stack/compiler overrides. It selects seven groups:
the two existing differential groups, a new 33-input proof-reuse group, three
owner regressions and the existing direct VM exact/one-less Fuel regression.

The unchanged old five-plan oracle independently resolves both owners. There
are 1358 differential inputs in total: the existing 1325 plus 33 for allocation
ledger faults, competing source faults, source shapes, retained holes and bool
replacement. Each compares successful sizes, exact error codes and all 256
backing bytes; failed operations must preserve the original bytes. Existing
groups include full sixteen-owner pressure, 128 leaves, depth sixteen, mixed
scalar boundaries, siblings, self-assignment and padding normalization.

Receipts are under `build/subrecord-assign-preflight/<profile>`. Full Engine,
public CLI, standalone memory, Linux and full release gates are not rerun.
The known legacy source-test failure is not retested or claimed fixed.
See [the earlier layout change](subrecord-assign-plan.md) for its history.

Development and O2 each passed all seven groups. All 376 receipt inputs match tested working bytes; implementation 8412f8f.
Git comparison: 376 exact byte matches and 0 line-ending-only differences, normalized and hashed in the evidence.
Root check: 375 source files / 4094 MIR functions; the lock update is included.
All other production code, the old oracle and the agent guidance body are unchanged.
See [evidence](../evidence/subrecord-assign-preflight-windows-20261115.json).

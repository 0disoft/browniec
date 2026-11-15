# Reuse each record-work validation plan

`array_owners::validate_record_work` previously constructed a fresh full catalog
plan for reservation and saved-owner validation, then `struct_nested_storage::staging`
constructed the same plan again to measure admission work. This repeated in
`struct_work::begin`, every `advance`, and final publication.

The validator now passes its local plan to `staging_prepared`, an internal
metadata-composition entry following the existing `struct_range::offset_prepared`
convention. The caller must have freshly planned the exact immutable catalog
in this operation. No plan is stored in the work cursor or carried into another
chunk. The raw `staging` entry still independently plans its catalog before
delegating to the same scalar iterator and accounting body.

## Ordering and bounded work

The initial active/element/list guards still precede catalog planning. Full
catalog validation still precedes table, token, nominal, reservation and saved
state checks. Admission accounting remains after those checks, including
written/total/last bounds. Every validation still authenticates all 32 record
rows and 512 field slots, including unused slots and unrelated records.

The helper performs metadata accounting only. It cannot read payload, reserve
storage or publish owners. The canonical scalar iterator, bool count, byte
measure, 128-byte staging bank, 4096-unit chunk limit, owner generations and
Fuel prices are unchanged. No public Brownie admission or persistent cache is
introduced.

## Structural cost

For each successful validation, full catalog plans fall from 2 to 1, fixed
field-slot inspections from 1024 to 512, and record-row inspections from 64
to 32. One dependency/offset planning pass is also removed. Scalar-leaf
accounting still executes once. Asymptotic complexity is unchanged; these
are source-level counts rather than measured throughput or CPU instructions.

A 128-byte copy advanced in one-byte chunks invokes this validator 130 times:
once in begin, once per advance, and once again for final publication. Within
those validations, plans fall from 260 to 130 and fixed field-slot inspections
from 133120 to 66560. Other preparation/staging plans are outside these counts.
No new heap allocations or retained plan storage are introduced; physical
peak memory and wall-clock throughput were not measured.

## Focused verification

Run `python -B tools/verify-record-work-plan.py --profile all`. Eight native
groups cover staging equivalence across all six scalar tags, nominal depths
1..16, the 128-leaf bound, oversized and missing selected records; 1024 field
slot mutations, 32 row mutations, all 16 owner occupancy slots, 25 saved-state
mutations and diagnostic precedence; all six record recipes in one-byte
chunks; and a 128-byte bool copy with delayed owner publication.

Existing independent return-accounting/mask checks and direct record VM tests
cover full Fuel versus one-less Fuel and rejection before mutation. Production
mirrors use the pinned compiler, locked inputs, default native stacks and no
overrides. An initial test-authoring attempt failed Fairy loan checking in a
fixture assignment; its incomplete output is retained separately and is not
used as evidence.

Full Engine, public CLI, standalone memory, Linux and full release gates were
not rerun. The known legacy source-test failure was not retested or claimed
fixed. Changes are local commits; no push, release, deployment or version bump.

Development and O2 each passed eight groups. All 376 input hashes match working bytes and implementation 19281f9 exactly, including Git blobs.
Root check: 375 sources / 4097 MIR. The extracted accounting body and
guidance body match baseline; production LF is retained.
See [evidence](../evidence/record-work-plan-windows-20261115.json).

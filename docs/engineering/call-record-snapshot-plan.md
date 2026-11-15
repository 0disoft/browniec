# Plan each mixed CALL record snapshot once

`array_owners::copy_call_arguments` previously planned the full catalog for
record-owner shape validation, then planned it again in `snapshot_into`. This
repeated for every record argument, including duplicate sources in one CALL.

The wrapper now supplies expected size/alignment to checked storage
`snapshot_into_bound`. This entry builds one fresh full plan, authenticates the
binding, checks the root extent and exact scratch size, then stages canonical
scalar bytes. Binding remains metadata, not authority; no caller Plan, cache
or persistent proof is accepted. Each record argument revalidates the current
full catalog, including unused slots and unrelated layouts.

## Diagnostics and publication

Arity and full owner-table integrity are checked first. Each argument retains
source token, write-loan, element kind, descriptor length and nominal identity
checks before catalog/owner shape, root extent, canonical bools and destination
reservation. The loop is not reordered: an earlier invalid bool still precedes
a later bad catalog, stale token or exhausted reservation. Array-only and empty
calls continue to ignore unused invalid record catalogs.

Raw `snapshot_into` retains its signature and diagnostic order. Its extent,
scratch-size, zeroing and snapshot body now lives in a private helper shared by
the two freshly planned entries. The canonical scalar iterator is unchanged.
Scratch may be partial on a scalar error and remains private. All record
snapshots, source bool checks and reservations still finish before any backing
write or owner publication; failed batches preserve backing and table state.

The existing 1024-byte snapshot bank, original-source rule, owner slots,
generations, quota, allocation padding, array handling and Fuel prices remain
unchanged. The checked native entry does not expand public Brownie admission.

## Structural cost

With A record arguments (0..8), full catalog plans fall from 2A to A. For eight
record arguments, plans fall 16 to 8, fixed field-slot inspections 8192 to 4096
and record-row inspections 512 to 256. Eight dependency/offset planning passes
are also removed. Across 4096 such calls, field-slot inspections fall from
33554432 to 16777216, removing 16777216 inspections and 32768 plans.

Asymptotic complexity is unchanged. Table validation and payload work are
unchanged; only redundant catalog work is removed. These are source-level
counts, not measured throughput, CPU instructions or physical peak memory.

## Focused verification

Run `python -B tools/verify-call-record-snapshot-plan.py --profile all`. It
selects nine native groups in locked byte-identical production mirrors, with
the pinned compiler and default native stacks. Two new groups cover 1069
metadata/binding/extent/quota rejections with untouched scratch, and 149 raw vs
bound snapshot comparisons, including all 128 invalid bool positions, all
six scalar tags, nominal depths 1..16 and depth-17 rejection. Comparison checks
exact results and all 128 scratch bytes, including partial scratch on errors.

Six existing owner groups cover mixed nested copies, source independence,
padding, late bool and descriptor failures, quota/alignment, retired slots,
retained holes, zero/eight/nine arguments and eight 128-byte records filling
all sixteen owners and 2048 backing bytes. The existing direct mixed VM group
covers exact/one-less Fuel and combined owned/borrowed publication.

An initial attempt was stopped after the oversized fixture was corrected from
a 64-byte flat record to a 256-byte nested record. Its incomplete outputs remain
under `build/call-record-snapshot-plan-initial-fixture`; no result is reused.
Receipts for the corrected inputs are under `build/call-record-snapshot-plan`.
Full Engine, public CLI, standalone memory, Linux and full release gates are
not rerun; the known legacy source-test failure is not claimed fixed.

Development and O2 each passed all nine groups. All 376 receipt inputs match tested working bytes and implementation 7fe905c.
Git identity: 376 exact matches and 0 line-ending-only differences, normalized and hashed in the evidence.
Root check: 375 sources / 4096 MIR. The extracted private snapshot body
matches baseline; other storage functions and the guidance body are unchanged.
See [evidence](../evidence/call-record-snapshot-plan-windows-20261115.json).

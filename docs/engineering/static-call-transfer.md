# Static CALL transfer through the canonical VM

Date: 2026-11-05. This follows [complete Static CALL analysis](static-call-admission.md).
The native coordinator now executes PARAM 77, CALL 78 and RETURN 79 against the
same retained immutable image. This is private IR execution, not source CALL
lowering, ordinary public admission or a host-visible returned-view API.

## Retention and one coordinator

`program_image::CallProgram` owns a completely proved `static_call_ir::Program`
and its consumed image behind private resource fields. `retain_calls` checks the
exact recipe/image and canonical scalar/owner/loan proof before freezing that
snapshot; image quota covers logical image metadata and payload only. Changing
the caller's candidate afterward cannot rewrite retained code. Both successful
and rejected retention consume the supplied owning image.

`run_call_scalar` borrows the entire resource while executing. Native direct
`execute_static_scalar` also independently checks the exact code/image before
entry. External entry remains scalar-only: a host cannot supply Static words or
receive one as a scalar result. Legacy `Program` retention/admission continues
to reject the new dialect. These are storage-specific private recipes, not new
guest reference types or exported C ABI handles.

The common coordinator now borrows the body and result-origin tables separately
instead of constructing another complete IR wrapper. Existing scalar, array,
record, runtime-loan and returned-loan execution still uses the same coordinator,
entry/leave transactions and prepaid invocation abort.

## Publication and actual words

An unpublished sixteen-word argument plan checks each live caller word against
its proved kind/root bounds and the exact future PARAM site. Logical scalar
prefixes and repeated shared actuals keep their positions. The plan retains the
actual range, not the union of possible image roots. Complete Static, native
entry, logical-arity and owned-copy Fuel is checked before child frame words are
published. Static positions are never read or copied as scalar register cells.
PARAM then validates the already-staged word before publishing its live bit.

RETURN validates the sole live selected word, exact caller CALL/callee/kind,
fresh destination and recipient image window. Native ordinary leave first
restores ownership/loan state. Only after it succeeds does the driver publish
the caller word/live bit and clear the consumed child's words. The transfer
copies no image payload. Packed zero remains a valid empty byte span; liveness
is separate. Each recursive frame has its own words even for the same site IDs.

The existing 32x16 u32 table remains 2048 logical descriptor bytes. Argument
plans add a bounded sixteen-word temporary, not another payload allocation.
This does not establish total Program/Engine/process accounting or a general
native stack/RAM bound; those remain R02 obligations.

## Complete private prices

| Work | Charge |
| --- | ---: |
| PARAM including dispatch | 17 |
| Static CALL metadata | 32 + 32*N, for 0..8 Static actuals |
| Static RETURN including dispatch | 49 |

CALL additionally pays its dispatch unit, logical arity, existing aggregate-copy
work and native entry reserve. RETURN additionally pays native ordinary leave.
Two bounded root scans and consumed-frame word clearing are included. The
metadata-only predecessor used smaller plan-only prices; the complete protocol
now prepays both validation and publication. Existing 69..76/public instruction
prices, native phase reserves, CLI default 256 and explicit cap 16000000 remain.
These are abstract work units, not timings or machine instruction counts.

Independent complete-invocation oracles are 688431 for a narrowed byte argument,
688338 for exact text, 688398 for a callee literal origin without an argument,
688788 for eight shared actuals and 688432 with one logical scalar prefix. Two
native enters and leaves contribute 688128 units in each example. Each checks
one-short/exact/one-more budgets, zero guest backing and zero remaining Fuel at
exact. Two image bytes require logical image quota 578, not total process RAM.

## Verification and remaining work

Run `python -B tools/verify-static-execution.py --profile development --selection
call-transfer`, then repeat for release. The selection contains eight transfer/
VM groups, nine range groups and seven canonical scalar-entry groups. Public
Fuel CLI-only phases run separately with `tools/verify-public-fuel.py --phase cli`
and serialized development/release builds.

The focused cases cover actual byte/text/literal returns, empty zero words,
scalar prefixes, eight shared actuals, differing recursive spans, frame-limit
abort, entry/CALL/RETURN Fuel shortage, retained-code immutability, legacy gates
and mixed Static plus owned-array argument copying/drop. Existing range and
scalar-entry tests cover affected canonical scalar/array/record/loan cleanup.
At the original `a1b555a` checkpoint, new mixed-Static record/loan arguments and
aggregate results reused those adapters without a new mixed runtime fixture.
The subsequent [mixed-call evidence](../evidence/static-call-mixed-windows-20261105.json)
now records three groups per Windows development/release profile on 134 matching
inputs and a 231-file discovery identity. Five examples combine Static formals
with record values, shared/exclusive loans and array/record results. They retain
canonical cleanup and measured exact/one-short Fuel boundaries; a kind-confused
actual rejects. All 129 production modules are unchanged and LF, with locked
mirrors passing. Source signatures were not enabled by those private fixtures.

Final results and committed input identities are recorded in the
[focused Windows evidence](../evidence/static-call-vm-windows-20261105.json).
Windows development and release each passed all 24 native groups and 33 tool-free
CLI cases. The phases match on 136 native inputs and 141 CLI inputs, the same
230-file discovery identity and pinned compiler. All 129 production modules are
LF; both locked LF mirrors pass. No compiler/stack overrides or historical result
reuse. Implementation commit: `a1b555a`; earlier checker/development probes are
excluded from these final counted results.
The original public Fuel native selection, full profiles, general stack/RAM,
allocator/OOM/timing, Linux, restricted delivery and ABI/package checks were not
rerun. Native module APIs alone do not establish an embedding ABI or isolation.

The metadata-only predecessor at `39f4688` passed four native groups per Windows
profile on 134 matching inputs, 129 LF modules and a 230-file discovery identity.
Its [historical evidence](../evidence/static-call-transfer-core-windows-20261105.json)
records that narrower implementation and its earlier plan-only prices.

The [byte-access successor](reference-access.md) now shares canonical READ/LEN
across image sites and runtime byte loans with existing authentication/prices.
Next unify guest reference formals and lower source signatures, actuals and
returns with full origin/lifetime checking. Complete
ordinary public admission and host-visible returned-image lifetime APIs before
promoting capabilities. Buffer/input views, Engine/Instance, host exchange,
restricted delivery, packaging and the complete inventory remain open.

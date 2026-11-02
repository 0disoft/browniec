# Private canonical record results

Canonical CALLs admit exact-nominal record results alongside scalar and array
results, with the existing scalar, owned array/record, shared and exclusive
arguments. This extends the [array-result coordinator](m2-slice-array-result-authority.md).
Suspended/derived exclusive CALL sources and guest/public reborrow promotion
remain gated. Public syntax, capabilities, opcodes and logical prices do not change.

## Exact admission and return transaction

CALL inspection validates the result anchor and destination bounds, callee/caller
function ownership, zero scalar return type, absence of an array-result marker,
and exact nominal identity. Equal-sized distinct records cannot substitute for
one another. Preparation checks an empty caller record destination before any
argument copy or loan publication. Existing scalar/control preflight is unchanged.

`struct_result_vm::prepare` factors the legacy validation without mutation:
source/anchor function, exact nominal identity, empty destination, both child
token sets, unique writable owner, layout/size/alignment/generation and bounded
nested bool validation. Existing fixed 128-byte validation scratch remains; no
additional payload snapshot is introduced. Its native `Transfer` contains only
the existing token and two indices. Legacy `step` still prepays first, then
prepares/publishes and returns the same remaining Fuel.

Canonical `return_record` prepays before inspection or payload access. It
authenticates the actual mapped CALL target and destination, prepares the
transfer, and invokes canonical leave with only that result record retained.
All child arrays and other child records must already be cleaned. Readonly
cleanup stages metadata as before; canonical authority restoration is the last
fallible operation. Only then does infallible publication clear the child token
and assign the same token to the caller. Failure preserves ownership and maps.

Array returns use the same leave body with no retained record; scalar returns
retain neither aggregate. No persistent field, authority clone, receipt collection,
extra extent, or result payload copy is added. Existing pool/owner staging is
unchanged; the result plan is additional bounded local scratch. Native stack,
allocation counts and elapsed-time performance remain unmeasured.

Transfer plans are trusted native, single-use values. No callbacks, unrelated
mutation or invocation boundary may intervene; only canonical restoration
preserving the prepared unique result owner is permitted between phases.

## Prices, ownership and abort

SRET remains 42,113 Fuel, charged once before metadata traversal or payload reads.
CALL copy/loan prices are unchanged. The single-i32-record fixture needs 129,611
execution Fuel; the public wrapper needs 129,616 including five Fuel for backing
preparation. Exact and one-short budgets retain their previous outcomes.

Returned owners retain their generation, descriptor and backing bytes, including
padding. Recursion forwards one owner through VM frames; source cleanup reclaims
storage, including deferred holes. Existing limits remain 128 bytes per record,
depth 16, 16 owner/pool slots, 32 VM frames and 31 combined pending events.

Abort drains loans while preserving earlier writes, transferred/copied owned
values and original outcomes, or retains failed-cleanup diagnostics. Native
callers dispose owned storage/backing after abort. Return and abort never roll
back payload writes or external effects.

## Verification

```text
python -B tools/verify-m2-slice-elements.py --profile development --record-result-authority --record-result-phase core
python -B tools/verify-m2-slice-elements.py --profile release --record-result-authority --record-result-phase core
python -B tools/verify-m2-slice-elements.py --profile development --record-result-authority --record-result-phase regression
python -B tools/verify-m2-slice-elements.py --profile release --record-result-authority --record-result-phase regression
```

Core selects seven canonical record-result groups and eight unchanged legacy
record-result groups. Cases cover all scalar edges, nested bools, depth 16,
128-byte values at one-extent quotas, repeated/deferred-hole returns, 32-frame
recursion, exact/short Fuel, parameter/constructor/child-path results, mixed
arguments and alternating array/record results. Rejections cover stale, dirty,
invalid-bool, wrong-nominal, layout/alignment/token-table and mapped-CALL state,
short control spans, live destinations, and Fuel exhaustion before validation.
Late restoration failure preserves a pending result and staged readonly cleanup;
retry moves the same owner once. Abort after SRET retains the result/write/error.
Legacy coverage includes a full owner table and unchanged padding.

Regression selects seven existing canonical array-result groups, six record
argument groups and six shared CALL groups. Public CLI regression selects 74
mutable-parameter, 222 mutable-slice, 192 readonly and 2,007 M1 cases per profile.
Core and regression do not repeat native groups. Full native, other M2, Linux,
M0, isolation, packaging, native size/stack, allocator and timing are outside
this selection.

Development and release core each passed 15 native groups, with 395 identical
current input hashes. Canonical CALL/public CLI regression is pending.
Local commits only; no push, publication, packaged release or deployment.
Next is suspended/derived exclusive CALL proof.

# Private canonical scalar-array results

Canonical CALLs admit exact-shape scalar-array results alongside the existing
scalar, owned array/record, shared and exclusive arguments. This extends the
[record argument coordinator](m2-slice-record-call-authority.md). Record results,
suspended/derived exclusive CALL sources and guest/public reborrow promotion
remain gated. Public syntax, capabilities, opcodes and logical prices do not change.

## Admission and return transaction

CALL admission checks the result anchor's function, scalar tag, return type and
length (1..4096). Its destination must belong to the caller with the exact tag
and length. Runtime preparation requires an empty destination token before
argument copying or loan publication. Existing scalar/control preflight remains
unchanged, including short Fuel, frame and control-span rejection.

`array_result_vm::prepare` performs the existing return checks without mutation:
valid source/destination functions and shape, an empty caller destination, no
other child array tokens, a live unique writable owner, and every bool byte.
The small unpublished `Transfer` stores the existing token, two token indices
and the validated byte count. The legacy `leave` entry now composes this prepare
and infallible publish, preserving its interface and validation order.

Canonical `return_array` authenticates the mapped CALL target and destination,
prepares that transfer, and invokes the shared canonical leave transaction.
Only the validated result array may remain in the child frame; record tokens
and all other array tokens must already be cleaned. Readonly child cleanup is
staged as before. Canonical authority restoration is the last fallible operation.
Only after it succeeds does publication clear the child token and assign the
same token to the caller. Failure preserves the result token and loan/maps.

This moves ownership without allocating, copying payload, changing the owner
descriptor/generation, or reserving another extent. No persistent state fields,
authority clones or receipt collections are added. Existing temporary pool/owner
metadata staging remains; the transfer is additional bounded local scratch.
Native stack size, allocation counts and elapsed-time performance are unmeasured.

Plans are trusted native, single-use values, not a guest API. No callbacks,
unrelated state changes or invocation boundaries may intervene. The only permitted
intervening mutation is canonical restoration preserving the prepared unique owner.

## Prices, execution and abort

The existing ARET price remains `65 + length` for bool and `65` otherwise.
The shared core prepays it once before validation/restoration. CALL copy/loan
prices remain unchanged. Native sufficient-Fuel execution excludes the public
VM's separate backing preparation charge: the one-element fixture needs 227
execution Fuel, or 232 including the public wrapper's five-Fuel preparation.

Successful return moves the existing owner through recursive frames, retaining
the same payload peak. Source-lowered drops eventually reclaim it. Abort drains
loans and preserves earlier writes, transferred/copied owned values and the
original outcome, or retains failed-cleanup diagnostics. Native callers remain
responsible for disposing owned storage and backing after abort.

## Verification

Run each phase once per profile, using `development` and `release`:

```text
python -B tools/verify-m2-slice-elements.py --profile development --array-result-authority --array-result-phase core
python -B tools/verify-m2-slice-elements.py --profile release --array-result-authority --array-result-phase core
python -B tools/verify-m2-slice-elements.py --profile development --array-result-authority --array-result-phase regression
python -B tools/verify-m2-slice-elements.py --profile release --array-result-authority --array-result-phase regression
```

Core selects seven canonical result groups and six unchanged legacy array-result
groups. Cases cover all six tags and signed/unsigned edges, maximum lengths,
one-extent quotas, exact/short Fuel, repeated returns, 32-frame limits, owned
parameter results, mixed record/array/shared/exclusive arguments, a native lexical
child before ARET, stale/dirty/invalid-bool results, malformed result/control
metadata, late restoration failure with a staged reader close, successful retry,
single-use publication and abort after transfer. Private child IR still fails
public admission; no new guest reborrow grammar is introduced.

Regression separately selects six existing record, six shared and six scalar
canonical CALL groups plus 74 mutable-parameter, 222 mutable-slice, 192 readonly
and 2,007 M1 CLI cases per profile. Phases share input hashes and do not repeat
native groups. Full native, other M2, Linux, M0, isolation, packaging, allocator,
native size/stack and timing are outside this selection.

Development and release core verification each passed 13 native groups, with
394 matching current input hashes. Canonical CALL/public CLI regression is
pending. Local commits only; no push, publication, packaged release or deployment.
Next is canonical record results, then suspended CALL proof.

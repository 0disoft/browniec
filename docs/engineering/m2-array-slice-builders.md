# Private borrow-aware slice IR builders

Implementation: `d776d1d`. This checkpoint adds construction
helpers for the [borrowed parameter metadata](m2-array-slice-parameters.md).
It does not enable guest slice signatures, borrowed VM instructions or CALL
execution. The existing verifier gate remains in place.
The [instruction-builder successor](m2-array-slice-borrow-ir.md) adds rootless
UTF-8, length, read, close and subslice emission behind the same gate.

## Shared site reservation

`ir.slice_site` finds a free ID without mutating Program. A site is available
only when its `slice_roots`, `slice_origins` and `slice_functions` entries are
all zero. Both the existing owned-array `ir.slice` builder and the new borrowed
builders use this lookup. Interleaved owned, formal and derived declarations
therefore share the same sixteen-site ceiling without overwriting each other.
A partial nonzero origin/function marker also reserves its ID; reservation does
not certify malformed metadata. Independent metadata validation still applies.

## Declaration helpers

`slice_builders.parameter` requires the function count, non-entry function,
register start and arity to be declared first. It appends one formal position
within the existing eight-argument and 128-register limits, with no scalar type,
mutable slot, array shape or record shape. The position and new site name the
same self-anchored origin. The builder returns the slice site, matching owned
aggregate parameter helpers; it does not update the declared arity or close the
function's register partition. The next position must have empty kind metadata.

`slice_builders.derived` reserves a rootless site from a formal or derived parent
belonging to the specified function. Its origin points directly to the formal,
even for repeated derivation. The formal positions must already be constructed.
Admission checks the parent, self-anchored origin and exactly one matching
formal of the correct kind. It allocates no register, code instruction, runtime
ticket or array owner. Liveness and control-flow proofs remain verifier work.

All checks, free-site lookup and checked byte conversions finish before a
declaration publishes any metadata. Invalid declarations return kind 3;
register/site exhaustion returns kind 4, at the supplied source offset. Failed
declarations preserve the existing metadata, registers and code/call counts.
Builders operate on coherent in-progress Program declarations; they do not
replace whole-Program validation or repair arbitrary malformed inputs.

## Argument encoding and execution boundary

After successful whole-Program metadata validation,
`slice_builders.argument` takes a destination formal register, source slice ID,
caller function and verified live mask. It delegates to the independent
parameter argument checker and returns the existing byte encoding `160 + site`
for the CALL argument table. Local u8 sources require a live array root and
slice; borrowed derived sources require their own live slice, without a live
anchor ticket. Foreign/dead/wrong-kind sources fail with kind 5 at the supplied
offset. The helper is read-only and emits no CALL or runtime borrow.

Existing CALL builders can store these bytes, but this checkpoint does not
change their arity/signature validation or general failure-publication contract.
The core verifier continues rejecting declared borrowed formals before VM
allocation, Fuel preparation or dispatch. Source syntax, borrowed-root open, frame integration, mixed owned
and borrowed argument transactions, forwarding/recursion execution and metering
remain pending. Slice results remain unavailable. No capability or Fuel price
changes.

## Bounds and focused verification

Site lookup examines at most sixteen entries, O(S). Formal declaration is O(S);
derived declaration is O(A+S), A<=8; argument encoding uses O(1) metadata
lookups. No new Program fields, payload copy, runtime allocation or unbounded
origin-chain traversal is introduced. Timing and allocator usage are unmeasured.

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --slice-builders`
and repeat with `--profile release`. The selection contains fifteen native
groups: five builder groups, four parameter-metadata groups, three subslice VM
groups and three source alias groups. CLI regression covers 252 invocations:
120 aliases, 124 subslices and eight scalar/array/record/unsupported-Buffer
sentinels. Both profiles passed with 326 matching input hashes. Exact checkout
bytes match both receipts; committed text matches after CRLF-to-LF normalization.
Tests cover interleaving, flattened origins, sixteen-site exhaustion,
eight-formal limits, failed-admission preservation, invalid/foreign/orphan
origins, partial reservation markers and exact argument bytes.

See the [Windows evidence](../evidence/m2-array-slice-builders-windows-20261031.json)
for matching input hashes, compiler/SDK identity and retained artifacts. Full
suites, other CLI matrices, M0, Linux, DLL embedding, isolation, packaging,
allocator instrumentation and timing benchmarks are outside this selection.

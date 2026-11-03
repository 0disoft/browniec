# Scalar-slice result signatures

Implemented at `1ced18e`, following temporary-array borrows at `8983737`.

This is a private signature-analysis stage. `functions::scan` describes scalar
slice result declarations; `compiler::compile` rejects every such declaration
before IR/result preparation, even in unreachable functions. No returned borrow
can execute, and no public capability or VM format changes.

## Declaration metadata

The declaration forms are `fn ref T[] name(...)` and
`fn ref mut T[] name(...)`, for the six existing exact scalar types. Fixed-length
borrowed results, records, wrappers, nested slices and borrowed entry results
remain outside this stage. `main` still requires zero arguments and an owned
scalar i32 result.

Each of the 16 signature slots has two additional u8 fields:

- `return_slice_elements`: zero for existing result kinds, otherwise the exact
  scalar tag with bit 128 for exclusive access, matching parameter encoding.
- `return_slice_candidates`: one bit per argument position (0 through 7), set
  only for borrowed inputs with the exact same scalar type and access mode.

Scalar/wrapper type, owned array length and nominal record result fields stay
zero for borrowed results. Existing result kinds and unused signature slots keep
both new fields zero. Candidate collection is bounded by eight parameters per
function and adds 32 logical field bytes to the source-only signature table;
this is not a native struct size or stack measurement.

A declaration needs at least one candidate in this initial subset. A by-value
array, scalar, local or temporary owner is not an input borrow. No implicit
scalar/mode conversion or Static origin is admitted. Static storage remains an
accepted broader design option, requiring its own future representation/proof.

## Candidates are not a lifetime proof

Several exact input borrows may be candidates. Their mask is an upper bound, not
a union lifetime or a selected origin. A function with one candidate can still
return a local array or another unsafe reference; signature analysis deliberately
does not trust the body. A candidate set never authorizes compilation or VM
execution. The compiler rejects at the first borrowed-result function name before
ordinary lowering can interpret its zero scalar/array/record fields.

The next body-analysis stage must prove one exact input origin across every
reachable return, CFG join, forwarding call and recursive summary. Multiple
possible origins must reject rather than selecting the first matching input.
Returning callee-owned locals, by-value arguments, literal roots or producer
results must reject. A subview must preserve the input origin and exact mode.

Executable promotion also needs an independently checked result descriptor and
CALL/return handoff. The caller must retain the selected actual argument's owner
and loan through the returned view's lifetime, including a selected anonymous
literal or producer result; all unselected argument captures may end normally.
Current CALL capture cleanup closes every capture and cannot be reused unchanged
for escaping results. Exclusive returns must keep caller parents suspended until
the returned child ends, rather than restoring them at ordinary CALL return.

All fallible validation, quota/generation checks and Fuel admission must precede
result/ticket publication. Failure must preserve original errors and earlier
writes without replay. Source syntax admission, independent body/IR proof,
runtime handoff, cleanup/metering and public execution are separate next stages.

## Verification

Development and release each passed **12 native groups and 902 CLI cases**.
Eight new native groups check six scalar result types in both modes, candidate
filtering and argument bit seven, several/absent candidates, unsafe bodies,
malformed results, all 16 function slots, zero sentinels and the public compiler
gate. Four existing groups check scalar/array/record and borrowed-parameter
signature behavior. These are real Fairy C signature/compiler checks, not guest
returned-reference execution or a Python reference model.

CLI coverage is 90 new declaration/depth checks plus the existing 812 borrow
cases: 120 temporary-array, 102 named-range, 108 owned-range, 82 whole-array,
74 mutable-parameter, 74 readonly-parameter and 252 scalar slice cases. Every new
borrowed-result source is rejected by both check/run, including with zero Fuel;
parenthesis depths 32/33/64 complete/reject/reject under the existing guard.
All CLI matrices use a cleared environment and tool-free PATH at the unchanged
1M Fuel and 64KiB backing limits.

All 459 final input hashes match across profiles; each input also matches the
implementation commit under Git LF normalization. Compiler, native report,
retained CLI artifact and receipt identities were rechecked. Only signature
metadata/parser and the explicit compiler gate differ in production; 98 other
source files match `d0924f8`. Development started before the implementation
commit, with the same final inputs as release. See the
[Windows evidence](../evidence/m2-slice-result-signatures-windows-20261103.json).

No native lifetime transfer, returned-reference execution, Static storage,
full native/full M1/other M2/Linux/isolation/packaging/allocator/native size-stack/
timing verification is claimed. Local only; no push, release or deployment.

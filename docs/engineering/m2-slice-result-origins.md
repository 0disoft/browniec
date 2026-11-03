# Private scalar-slice return-origin analysis

Implemented at `0d1a8cb`, following result signatures at `1ced18e`.

`compiler::inspect_slice_results` analyzes real source bodies and returns only a
bounded summary: zero for ordinary functions, otherwise a one-based selected
borrowed input position. Public `compile` still rejects every borrowed-result
declaration. No returned runtime borrow, ticket or executable Program is exposed
by this analysis entry point.

## Reuse existing source and control-flow checks

The private lowerer reuses ordinary parsing, bindings, scopes, branches, switches,
loops and mixed capture cleanup. A direct `return ref [mut] name;` becomes a length
observation of that named slice followed by existing cleanup and a usize return
inside an internal analysis Program. Existing lexical aliases/subviews work;
inline return reslicing is deliberately deferred. A direct forwarding return
`return callee(...);` uses a compatible borrowed-result CALL as a scalar proxy.
Ordinary expressions cannot consume these proxies as usize values.

The existing independent verifier checks the entire analysis Program's type,
function partitions, definitions, CFG joins/backedges, live loans, suspended
parents and cleanup. The internal Program is not a returned-reference runtime
implementation and must not be used to infer ticket transfer or owner retention.
Only scalar summary facts leave the compiler analysis entry point.

## Reconstruct one exact input origin

For each emitted return, the checker finds its unique preceding LENGTH or CALL
producer. A named view must have a rootless formal anchor in the same function
with exact scalar/access metadata; the anchor maps back to one formal argument
position. Local owned arrays, by-value arguments and temporary owners cannot be
selected origins, even when a signature has one compatible candidate.

A forwarding CALL selects the callee summary's one input, then maps that actual
slice back to the caller's input anchor. Other arguments do not contribute to the
result origin. Parameter reordering and lexical subviews preserve this mapping.
All emitted returns must agree, conservatively including constant-condition arms;
there is no constant-folding-based origin exemption in this stage.

Grounded direct returns seed a monotone summary computation. Each of at most
16 function entries can become known once; at most 17 passes include the final
stable check. A recursive cycle with no ground rejects. A cycle that permutes
inputs inconsistently rejects after its tentative summaries become grounded.
A grounded self/mutual cycle with consistent remapping may be analyzed.

Producer lookup scans at most 256 instructions per return, giving a conservative
O(17 * I^2) origin-analysis bound for I <= 256, in addition to the existing verifier.
No host/guest effect or guest Fuel is executed by analysis. Native size, stack,
allocation count and timing have not been measured.

## Remaining execution contract

This proves source-body input-origin summaries for the admitted subset, not the
lifetime of an escaping result. Returned-view IR descriptors, independent result
handoff proof, runtime publication and cleanup remain required. Selected caller
arguments, including anonymous literal/CALL-result owners, must survive through
the returned view's lifetime; unselected captures may end normally. Exclusive
parents must remain suspended until their returned descendants end.

Static storage, borrowed results as general expressions/locals/arguments, inline
return ranges and implicit type/mode coercions remain outside this stage. No VM
layout, opcode, instruction price, runtime authority or public capability changes.

## Verification

Development and release each passed **12 native groups and 990 CLI cases**.
Eight new native groups cover six scalar/access modes, shared/exclusive lexical
subviews, branches/switches/loops, reordered forwarding, selected/unselected
temporary arguments, grounded and ungrounded recursion, conflicting origins,
suspended parents, proxy misuse and unreachable bodies. Four prior groups check
signature boundaries and immediate mutable-child cleanup after CALL.

The CLI scope is 88 new closed-gate cases plus 902 existing signature/borrow
cases, using a cleared environment and tool-free PATH. Existing public Fuel and
backing limits remain; the prior signature matrix includes successful depth 32
and rejected depths 33/64. No analysis Program or returned borrow is executed.

Development native results precede a CLI-only expected-source-count correction
from 45 to the actual 44 fixtures. Their original input manifest differs from
final inputs only in that CLI tool. Development CLI results are retained after
fixing WindowsPath JSON serialization in the ignored verifier; no product/test/
CLI-tool input changed after that successful run. The evidence records original
native inputs/command and exact reuse. Release reruns every selected native and
CLI check on final inputs.

All 462 final input hashes match across profiles and each input matches the
implementation commit under Git LF normalization. Compiler, native report,
retained CLI artifact and receipt identities were rechecked. Production changes
are compiler lowering/analysis and the new origin checker; 99 old source files
match `45e74f3`. See the
[Windows evidence](../evidence/m2-slice-result-origins-windows-20261103.json).

Full native/full M1/other M2/Linux/isolation/packaging/allocator/native size-stack/
timing and actual returned-reference execution are outside this verification.
Local only; no push, release or deployment.

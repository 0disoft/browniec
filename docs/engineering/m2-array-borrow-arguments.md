# Call-scoped whole-array borrow arguments

Implemented at `528934b`, following derived record results at `e8105f6`.

A visible existing array may be passed directly to an exact scalar slice formal:

```text
let Answer answer = update(ref mut output, ref input);
```

This first inline-borrow slice accepts whole array names only. A mutable formal
requires explicit `ref mut`, a mutable local binding and a mutable array descriptor.
Readonly formals require explicit `ref`. All six scalar types match exactly;
same-width signed/unsigned types do not coerce. Existing named slice arguments
retain their prior mode and ticket behavior. See the
[example](../../examples/array-borrow-arguments.brc).

## Evaluation and cleanup

`slice_call_source::capture` opens an anonymous whole-array handle when its
argument is evaluated. A zero-length name span keeps this local invisible to
guest name lookup. The temporary is appended to the CALL's existing lexical
capture table, so later argument expressions see its borrow. A subsequent nested
CALL does not close the outer CALL's capture.

The existing argument cleanup closes temporary borrows in reverse capture order
immediately after successful CALL return, before later caller expressions. The
same mixed array/record/slice cleanup handles argument-time return, propagation
and loop exits. Runtime failure drains sessions using the existing invocation
cleanup. Earlier writes survive failure and the original error is preserved;
there is no automatic replay or external-effect rollback.

Readonly duplicates may share an array. Independent mutable arrays may be mixed
with readonly or owned arguments and scalar expressions. Conflicting mutable
borrows and reads from an exclusively borrowed owner in a later argument fail
independent verification before guest effects, including unreachable functions.
Mutable writes under a readonly borrow retain existing source/verifier rejection.
Both scalar and owned array/record results use the existing CALL result path.
The anonymous handle is closed before the caller accesses its array again.

## Costs and boundaries

Each direct array borrow adds one static slice site, one anonymous local entry,
two usize constants, one OPEN and one CLOSE: four existing instructions and two
scalar registers, with their existing Fuel charges. It introduces no array owner,
payload copy, opcode, persistent runtime field or new instruction price. Callee
retention/handoff still uses existing borrowed CALL admission. The 16-site,
64-local, 128-register, 8-argument and other depth/quota/Fuel bounds remain.
The public CLI still caps Fuel at 1M.

Version JSON adds `array_slice_array_arguments: true`. Inline ranges, array
literals, call-result temporary roots, implicit mode conversions and escaping or
returned borrows remain outside this slice. No external bytecode loader, runtime
cache, JIT, guest GC or host capability is introduced.

## Verification

Development and release each passed **11 native groups and 644 CLI cases**.
Eight new native groups cover source behavior, lowering and failure cleanup;
three existing admission groups now accept direct array references. The CLI total
is 82 direct-array borrow, 74 mutable-parameter, 74 readonly-parameter, 252 scalar
slice source, 50 derived record-result, 44 derived array-result and 68 lexical
reborrow cases. All 448 final input hashes match across profiles; compiler,
native-report, retained CLI and receipt hashes were rechecked. Three production
paths change: CALL capture, its mutable names argument in the compiler and CLI
version JSON. The other 97 sources match `04ab3ef` under Git LF. See the
[Windows evidence](../evidence/m2-array-borrow-arguments-windows-20261103.json).

Development native results precede a CLI-only correction to the expected-value
list for a newly admitted readonly fixture. They remain valid because all native
sources and the compiler are unchanged; reuse retains the original command and
input manifest. Final CLI and release native checks follow that correction.
Development started with uncommitted implementation inputs; every final input is
bound to the implementation commit under Git LF normalization.

Source coverage includes six readonly and mutable scalar types, duplicate readers, independent mixed arguments, nested CALLs, aggregate
results, repeated CALLs, early argument exits, conflicts and rejected roots.
Native failure tests inspect cleanup after both a pre-CALL argument error and a
callee write followed by bounds failure. They check canonical readiness, closed
owner sessions, the original error and the surviving root payload. A lowering
test checks exactly one OPEN/CLOSE around CALL and no additional array site.

Native source fixtures use 16M Fuel and 256-byte backing. CLI cases use a cleared
environment and tool-free PATH with 1M Fuel and 64KiB backing. A 16-total-site
program compiles and reaches the CLI Fuel cap; a 17-site program fails source
compilation. Full native suites, full M1, other M2, Linux, isolation, packaging,
allocator, native size/stack and timing are not part of this verification.
No performance claim is made. Local only; no push, release or deployment.

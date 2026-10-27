# M2 Source Record Results

- Status: implemented at `bb401a4` with tooling `78a1fb4`; verified in
  development and release.
- Scope: bare visible exact-nominal record returns and `let`/`var` record-result
  call initializers through the existing record-result IR and VM.
- Implementation: [record-result source lowering](../../src/struct_result_source.fy),
  [compiler integration](../../src/compiler.fy), and [version output](../../src/main.fy).
- Predecessors: [result signatures](m2-struct-result-signatures.md),
  [record-result IR and verification](m2-struct-results-ir.md), and
  [record-result VM transfer](m2-struct-result-vm.md).
- Focused fixture: [source record-result cases](../../tests/m2/struct_result_source.fy).
- Harness: `python -B tools/verify-m2-struct-result-source.py --phase core`.
- Evidence: [Windows receipt](../evidence/m2-struct-result-source-windows-20261028.json).

The compiler now lowers a bounded source subset for calls that return a nominal
record. The source gate that rejected every `return_records` declaration before
IR construction is gone. This document covers that subset only; it does not mark
all of M2 verified.

## Supported source subset

A record-result function returns one bare, visible binding of the exact declared
nominal type:

```brownie
module main;
struct Pair { i32 x; i32 y; }

fn Pair make() {
    let Pair pair = Pair { .x = 20, .y = 22 };
    return pair;
}

fn i32 main() {
    let Pair pair = make();
    return pair.x + pair.y;
}
```

The `return` operand is exactly one identifier followed by `;`. A field path,
parenthesized name, constructor, direct call, aggregate expression, array, or
scalar value does not satisfy a record result.

Record-result calls are accepted as typed declaration initializers:

```brownie
let Pair pair = make();
var Pair mutable_pair = make();
```

The declaration type must match the callee result exactly. A `var` destination
may later be written. The caller's mutable flag is independent of the callee and
does not make a returned parameter alias the original argument. Assignment of a
record-result call into an existing record remains unavailable.

Record-result calls cannot appear in scalar expressions, wrapper payloads, or
general aggregate arguments. A record-result function also cannot use `?`
propagation because its result context is a record rather than a scalar or shallow
wrapper.

## Result anchors and compiler context

Result sites are prepared after record-parameter sites and before any function
body is lowered. For every nonzero `return_records` entry, preparation loads the
exact nominal layout and scans the result function's existing record sites. The
first site with the matching nominal type becomes the shape anchor. This reuses a
matching formal, including the formal's existing ordinal binding. If no matching
site exists, preparation reserves a dead function-owned record site with
`ir::record_in`.

The anchor names the result shape. It need not remain live when the function
returns, and it is not the call destination. The existing record-formal
preparation runs first, so result-anchor reuse does not renumber formal ordinals.

`struct_result_source::context` returns `255` for an enclosing record result and
otherwise passes through the existing scalar or wrapper return tag in `1..12`.
Zero retains its existing `for`-header restriction. Value `255` is an internal
compiler context and is never written to `return_types`; a record result keeps
`return_types[f] == 0`.

## Call initializers and cleanup

The declaration provides the explicit nominal type. Its initializer must be an
identifier followed by `(`. That callee identifier must resolve to a function and
must not name an already visible local. The new declaration name must be unbound
among visible locals; it may shadow a function because the function remains
resolvable until the initializer finishes. The compiler then reserves a dead
caller-owned record destination and emits CALL with destination `144 + site`.

Scalar, array, and record arguments share the existing left-to-right evaluation
path. A mutable record argument receives its anonymous `SCOPY` capture before
the next argument evaluates; an already present stable binding is used directly.
The pending initializer name is not declared in the local table until argument
evaluation, CALL, and capture cleanup all finish.

That placement matters for transfers. An early scalar or record return, a `?`
inside an argument expression, or an outer `break`/`continue` may leave during
argument evaluation. Cleanup then drops only bindings that were already visible;
it cannot drop an unborn result destination. The name becomes visible only after
`locals::declare` receives the completed call result.

## Return finisher and ownership

The return finisher accepts one visible record binding owned by the active
function with the exact anchor shape. It walks the visible lexical bindings in
reverse order, emits `ADROP` for arrays and `SDROP` for records other than the
selected owner, then emits `SRET` (50). Formals and anonymous argument captures
take part in that mixed cleanup.

Ownership transfer then follows the existing VM contract. `SRET` prepays 42,113
Fuel, validates the complete result through bounded scratch storage, clears the
callee token, and publishes the same owner token in the caller. It reserves no
extra owner or payload extent. Returning a parameter transfers the independent
callee copy created by CALL, so changing the result does not change the original
caller argument.

## Bounds, profiles, and version

The existing limits remain unchanged:

- 16 static record sites and 16 shared owner descriptors;
- 32 VM frames, a 65,536-byte payload arena, and 256 instructions;
- 16 scalar leaves and 128 planned bytes per selected source root;
- eight call arguments and 32 call sites.

Existing scalar, array, record, and result Fuel charges are unchanged. Existing
profile strings remain unchanged. `--version --json` adds
`"struct_results":true` beside the current capability fields.

## Remaining unsupported forms

Record results still do not support:

- `return Constructor { ... };`;
- `return call(...);` direct return calls;
- field, parenthesized, or aggregate return expressions;
- assignment of a call result to an existing record;
- record-result calls in scalar expressions or general aggregate arguments;
- record wrappers, borrows, `ref` results, or `var` results;
- record construction in a `for` header.

These forms fail during compilation instead of reaching an invalid IR type or a
partially initialized caller destination.

## Verification status

The core harness selects 14 native groups per development/release profile: 8 new
`struct_result_source` groups and 6 updated `struct_result_signatures` groups.
The CLI selection is 2,438 cases per profile: 166 new source-result, 70 updated
result-signature, 114 updated source-parameter, 119 array-result-source, and
1,969 M1 cases.

Development and release each passed all 14 native groups and all 2,438 CLI cases
through the core aggregate. The exact 166 source-result cases and the 2,438 total
were confirmed for both profiles. The development report retained its
`development-browniec.exe`, and its hash matched the recorded aggregate build.

A manual compiler/CLI smoke check had already produced 42 for a simple factory
and for an independently returned parameter. That smoke check is not part of the
focused receipt.

The updated result-signature checker had one metadata defect in its
`for source, kind` loop: the loop variable overwrote the global `kind` label.
All 70 checks passed, but the emitted schema was mislabeled
`browniec.m2-4-cli/v1`. After the aggregate completed, the checker changed only
that loop variable name to `error_kind`. The 70 result-signature CLI cases were
then rerun for each profile against the retained, hash-checked development and
release binaries. Sources, exits, result JSON, and version output matched the
aggregate. Native groups, builds, and the other CLI selections were not rerun.

The audited receipt records 219 rechecked input hashes, matching compiler/SDK
identities, and the complete native/build/core aggregate followed by this focused
70-case-per-profile checker metadata repair. It includes `postAggregateRepair`
provenance and does not present the result as one unchanged aggregate run after
the repair.

The new native groups cover scalar extrema with flat and nested layouts and
forward declarations; formal anchor reuse, caller mutability, and the eight-byte
quota; reverse mixed cleanup with deferred holes; recursive and mutual named
result forwarding; pending destinations and captures on early scalar or record
returns and wrapper `?`; outer loop transfers and inner-loop capture
preservation; type and unsupported contexts; and sixteen static sites with a
`compile_limit` failure at the seventeenth.

Earlier [signature](../evidence/m2-struct-result-signatures-windows-20261028.json),
[IR](../evidence/m2-struct-results-ir-core-windows-20261028.json), and
[VM](../evidence/m2-struct-result-vm-windows-20261028.json) receipts remain
historical evidence for their exact original inputs. Their blanket source gates
and their statements that source record returns were unavailable are superseded
by this subset. Full native/CLI suites, M0, Linux, isolation, DLL, packaging,
allocation instrumentation, and performance are outside the focused harness. This
slice verifies the bounded source subset; it does not verify all of M2.

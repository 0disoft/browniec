# Reference and text local type inference

Date: 2026-11-06. Implementation: `442f1f8`; name-shadowing fix: `365ac5d`.
This extends [local inference](local-inference.md) and
[owned aggregate inference](aggregate-inference.md) within the existing reference
and literal profiles. The complete L02 language objective remains open.

## Available initializers

Initialized immutable declarations can infer existing byte/text views and loans:

```brownie
let text = "hello";
let bytes = text::bytes(text);
let alias = bytes;
let window = (ref alias)[1..];
let values = [42; 2];
let loan = ref values;
let shared_alias = loan;
let returned = same(ref [42; 3]);
```

The returned example requires an existing admitted shared-byte result signature
such as `fn ref u8[] same(ref u8[] p)`. Inferred aliases can also appear in its
body and carry that input's return origin. Inferred text aliases and explicit
`text::bytes` conversion can ground an image-backed result. Qualified functions
use the original module context and source-local diagnostics.

Existing rooted loans preserve all six scalar element types. Exclusive access
requires `ref mut`, including explicit reborrows from an exclusive parent:

```brownie
var values = [0; 1];
{
    let parent = ref mut values;
    { let child = ref mut parent; child[0] = 42; }
}
```

A bare exclusive reference cannot be implicitly copied. As with annotated views,
the binding itself is immutable: `var view = ...` and reassignment are rejected.
Exclusive bindings permit the same checked element stores as before. Immutable
image/text backing never gains mutable access. A bare array still means the
existing owned value-copy initializer; borrowing it requires `ref`.

## Lowering and ownership

`reference_inference::inspect` reads an independent lexer snapshot plus immutable
local, signature and IR metadata. It emits no instruction, evaluates no endpoint
and leaves the active lexer unchanged. Classification requires a complete view
initializer at the statement terminator. Index reads, `.len` and other scalar
continuations retain ordinary scalar inference, including grouped scalar reads.
Existing Static grouping, ranges and explicit conversion keep their real parser.

Annotated and inferred declarations share `static_initializer` or
`slice_initializer`. Header inference does not replace actual type/access checks.
The complete initializer executes once before publication. Static aliases use
the existing ALIAS instruction; runtime aliases use existing shared reborrows.
No payload is copied for a view alias. The new name remains absent while its
initializer is checked. Duplicate/self references and the original quotas still
fail; hidden selected temporary owners continue to count against lexical limits.

The source return-origin pass now recognizes inferred reference/text bindings.
Its fixed-point hints remain advisory. Final canonical IR admission independently
reconstructs the origin, selected owners, loan exclusion and CFG lifetime. A live
last alias prevents owner mutation or drop; closing the lexical suffix releases
the existing loans/receipts and restores exclusive parents in the original order.
Selected temporary arrays survive returned-view publication. Unselected captures
and pending parents retain existing cleanup on return, propagation, break and
continue. No admission retry or source rewriting is used.

## Fuel and bounds

No opcode, operation price, backing limit, frame limit, profile or feature flag
changes. CLI Fuel remains default 256 and ceiling 16000000. Native host-selected
budgets remain independent. The existing 64-name and 16-site limits still apply;
each image alias consumes a site even though its payload is shared.

Two straight-line fixtures compare annotated/inferred executable bytes and use
independent numeric exact/one-short budgets. The rooted i32-loan fixture costs
286935, including the default 64KiB backing preparation. The byte literal plus
one alias costs 344121: entry 147456, leave 196608, OPEN 17, ALIAS 17, index 1,
READ 18, cast 1, two CLOSE dispatches and one RETURN dispatch. These fixtures
retain the distinct existing legacy and retained schedules.

## Remaining scope

This does not add general mutable/non-byte returned results, Buffer/input text,
scalar references, field-reference expressions, grouped native-loan expressions
or host-visible lifetimes. Ambiguous tag constructors, general aggregate
expressions, element-list arrays, void/if values and the rest of L02/L03 remain.
Engine/Instance accounting, bounded stepping, deadlines, worker, ABI and package
delivery remain separate completion-plan work.

## Verification

```text
python -B tools/verify-static-execution.py --profile development --selection reference-inference
python -B tools/verify-static-execution.py --profile release --selection reference-inference --shards 3 --shard 1
python -B tools/verify-static-execution.py --profile release --selection reference-inference --shards 3 --shard 2
python -B tools/verify-static-execution.py --profile release --selection reference-inference --shards 3 --shard 3
python -B tools/verify-local-inference-cli.py --profile development --references
python -B tools/verify-local-inference-cli.py --profile release --references
```

The native selection covers new inference and ownership cases, existing scalar
and aggregate inference, annotated Static bindings, returned origins/cleanup and
real module execution. It retains depth-32 success/depth-33 rejection for both
compiler routes. It checks all six native loan elements, access/kind rejection,
16/17 Static sites, one-time endpoint effects, last-alias exclusion and exact
legacy/retained Fuel. CLI cases run the real executable with an empty runtime
tool path, including UTF-8 text, returned temporary owners, diagnostics, exact
Fuel and the existing scalar cases. Both verifiers capture their starting Git
head before execution; the native verifier was corrected at `8fb1ea4`.

The initial whole release invocation exceeded the verifier's 1200-second process
deadline and is excluded. `ed10ad3` adds deterministic identity partitioning
without changing production/test/lock/CLI inputs or reducing coverage. Each shard
records the complete selected identity set before partitioning. Final evidence
requires disjoint release reports whose union exactly matches all 36 development
identities. The passed development run retains its exact verifier snapshot from
`442f1f8`; release shards use `ed10ad3`. Evidence authenticates these two tool
versions against their respective Git bytes rather than claiming identical
verifier input hashes. Both use the same production and test source bytes.

Final results and input/artifact identities are recorded in
[Windows evidence](../evidence/reference-inference-windows-20261106.json).
At `442f1f8`, Windows development and release each passed 36 native groups and
32 CLI cases. The evidence contains 164 common input paths plus the two exact
native verifier snapshots; both profiles used the same 258-file discovery and
154 LF production modules. Release coverage is the disjoint union of three
twelve-group reports. These are baseline results, before the follow-up below.

## Follow-up: scalar aliases that shadow reference functions

Final review reproduced a name-shadowing regression in the source-origin hint
pass: a scalar local named like a reference-returning function was mistaken for
that function when copying its value. `let x = owner;` failed with a syntax error
while `let i32 x = owner;` succeeded in the same returned-reference body.
`365ac5d` requires a real `(` suffix before using a global function result type.
Bare/grouped scalar copies retain lexical meaning; genuine reference CALLs,
known reference aliases and final independent lifetime proof keep their paths.

```text
python -B tools/verify-static-execution.py --profile development --selection reference-inference-shadow
python -B tools/verify-static-execution.py --profile release --selection reference-inference-shadow
python -B tools/verify-local-inference-cli.py --profile development --references
python -B tools/verify-local-inference-cli.py --profile release --references
```

Both final profiles passed the focused native group and 34 standalone CLI cases.
The native group compares inferred/annotated instruction bytes and execution for
bare/grouped scalar copies, inferred reference aliases and rejection of bare
function values. CLI reruns all 32 baseline fixtures plus two shadowing cases.
The final 160-path input union matches checkout and Git raw bytes at `365ac5d`;
both locked LF mirrors pass, with 154 LF modules and the same 259-file discovery.
Only `slice_result_source_origins.fy` changed among production inputs after the
baseline. The original 36 native groups were not rerun after this guard fix;
their reports remain scoped to `442f1f8`. Shared CLI build/receipt paths now hold
the follow-up artifacts, whose hashes are recorded separately. See the
[follow-up evidence](../evidence/reference-inference-shadow-windows-20261106.json).
Neither result promotes full language/profile, general RAM/stack/timing/OOM,
Linux, restricted worker, ABI or package completion. All commits remain local.

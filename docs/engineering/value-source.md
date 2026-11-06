# Typed source foundations and Result handling

This increment prepares source types, signatures and lexical ownership for the
[typed value dialect](value-ir.md). At this checkpoint the typed foundations were
compiler preparation only. The [body successor](value-body.md) now compiles empty
Buffer/nested-wrapper construction, immutable locals and mixed CALL/RETURN to
private native execution; broader expressions and public integration remain. The public compiler
also adds Result inspection and explicit discard through its existing scalar/tagged
path. Full
Buffer/wide-tagged body lowering remains implementation work, alongside the
remaining [completion plan](completion-plan.md).

## Canonical source types and signatures

`value_type_source::parse` consumes the original lexer state and interns nodes in
the existing checked type DAG. It supports all six scalar domains, exact scalar
arrays of length1..4096, plain nominal records and Option/Result nesting to depth4.
Buffer, bytes::Buffer and brownie::bytes::Buffer denote the private Buffer type.
Import/visibility resolution still belongs to the enclosing compiler; accepting
a spelling is not executable or capability authority.

The parser reuses identical nodes, retains nominal identity, enforces the 64-node
bound and validates whole-type properties, size and inactive Buffer alternatives.
Scalar arrays are the permitted array form; array/resource fields and additional
array dimensions are not silently enabled. Plain-record and wrapper depth remain
separate. Nominal parsing uses the existing source declaration IDs and a caller
supplied checked record catalog. Adjacent generic `>>` closers split only within
this parser, preserving original positions and ordinary shift lexing. Any failure
leaves both caller lexer and catalog unchanged.

`functions::scan_values` reuses the actual bounded signature pass, forward body
spans, argument positions and ordinary scalar/array/record/reference candidates.
It validates plain declarations before installing their nominal catalog. Buffer
and wider/nested wrappers use private source tags128..191, indexing canonical
types; these are never ordinary IR scalar tags. Scalar/array/record metadata keeps
its existing encoding. The complete catalog publishes only after every signature
succeeds. Existing ordinary and scoped signature entry points do not opt in.

These are source candidates. No Buffer body, source CALL, constructor, assignment
or return becomes executable merely because its signature now parses.

## Lexical typed ownership preparation

`value_source_bindings` shares existing locals names and uniqueness rules, including
the rejection of active shadowing. This checkpoint admitted immutable typed
bindings; the [control successor](value-control.md) now adds mutable bindings,
whole-value replacement and checked selection of independent compiler paths. Allocation is globally monotonic across functions/scopes/alternatives
within the existing sixteen-slot private IR bound; it is not a full-profile limit
promotion. Names may contain ordinary and typed bindings in one 64-entry table.

Exact-type initialized sources emit COPY89 when the whole type is copyable and
MOVE88 otherwise, including inactive Buffer alternatives. Destinations must be
Dead. Moved names remain discoverable and reject subsequent value use. Trusted
initializer/CALL/RETURN hooks update compiler liveness only after the surrounding
operation's complete admission. Cleanup preflights the entire instruction budget
before emitting reverse-scope DROP90 for live bindings. Anonymous temporaries need
their parent's explicit cleanup; this module does not own native roots.

Snapshots describe source analysis, not runtime ownership. Alternative-path setup
may restore entry liveness for a separate, unexecuted CFG path while retaining the
global allocation cursor and distinct static slots. Exit merge requires identical
surviving bindings and live sets; it cannot revive a consumed outer value or rewind
allocation. The independently verified exclusive-branch regression emits two
different MOVE destinations and proves only one executes on a path. Complete IR
admission remains mandatory before any native execution.

## Public Result inspection and discard

The existing compiler accepts `.is_ok` on its admitted Result values, including
locals, mutable snapshots, direct CALLs and grouped/conditional/switch values.
It evaluates the receiver once, yields bool and preserves ordinary propagation,
short-circuit behavior, capture cleanup and original dot spans. Option/scalar
receivers, unknown members and method-call spelling `.is_ok()` reject.

Inspection emits seven existing instructions: CASE24, a true/store/jump arm, a
false/store arm, then LOAD. The selected arm executes five Fuel units for success
and four for failure. Existing operation prices are unchanged. Independent literal
oracles verify complete programs at9/8 Fuel, including one-short rejection.

`_ = EXPR;` explicitly acknowledges an existing scalar/tagged value without a new
binding or discard instruction. RHS evaluation, effects, returned arguments and
nonlocal cleanup happen once through the ordinary expression path. Ignored direct
nonvoid `f();` calls remain errors. Void is not a discardable value. Classic-for
clauses retain their existing pure-scalar restriction.

Version metadata advertises `result_is_ok` and `explicit_discard`. This does not
complete `must_use_result`: unused Result-binding diagnostics and wider/
resource-bearing predicates, discard, switch and propagation remain open.
Public Buffer/wide-wrapper execution and its capabilities remain unavailable.

## Verification

`python -B tools/verify-value-source.py --cli` selects both development and release
profiles. The default phase is `all`: with `--cli` (also spelled
`--public-fuel-cli`), it runs the selected native groups followed by the CLI cases
for each profile. Without `--cli`, default `all` runs only the native selection.
Use `--profile development` or `--profile release` to select one profile.

The phases can also be run separately:

```text
python -B tools/verify-value-source.py --phase native
python -B tools/verify-value-source.py --phase cli
```

`--phase native` rejects `--cli`. `--phase cli` enables CLI execution and includes
all `CLI_INPUTS` in the hashed input manifest without requiring `--cli`; it still
performs the locked mirror check and CLI build, but runs no native test groups.
Each invocation replaces `build/value-source/{profile}/receipt.json`, so a CLI-only
receipt must not be read as a native pass for that invocation.

On Windows, the original same-turn default-`all` plus `--cli` runs passed all 19
selected native groups in each profile. Their CLI portions stopped solely because
the runner incorrectly expected compile-error exit code 5 instead of the correct
exit code 3. Those invocations were not complete native-plus-CLI passes. The native
pass evidence is retained separately in
`build/value-source/{profile}/native-checkpoint.json`.

After correcting that exit-code expectation, fresh CLI-only runs passed 150 cases
per profile: 105 existing public Fuel cases and 45 Result cases. Their receipts
report `phase: cli` and `nativeGroups: 0`. The final input-manifest correction makes
`--phase cli` alone include the same `CLI_INPUTS` as `--cli`; only the CLI phase was
rerun for that correction and both final 150-case runs passed. Production and selected test sources remain frozen.
The 19-group native results remain the original same-turn evidence, not newly
executed tests in a CLI phase. See the
[Windows verification evidence](../evidence/value-source-windows-20261107.json)
and [input reconciliation](../evidence/value-source-inputs-windows-20261107.json)
for the separate native/CLI scopes and their input identities.

All 207 final input hashes match checkout and Git raw bytes, including all 193
LF production modules. Native-checkpoint inputs differ only in the verifier.
Native mirror inputs were hashed before execution; the original run did not reach
its final post-suite mirror assertion because the CLI expectation failed. Final
CLI mirrors and their inputs were checked before and after execution. The native
selection covers parser rollback and limits, nominal identity, signature candidate
atomicity, COPY/MOVE, reverse cleanup, exclusive-branch flow, actual public Result
execution, 32-deep captured calls and qualified module paths. The CLI cases cover
independent exact budgets, effect counts, malformed types and syntax. Runtime
PATH contains no compiler/build tools. Inputs, streams, native reports, commands
and artifacts are hashed, without native overrides. Retaining the original native
checkpoint across runner-only fixes does not enlarge its scope or assert a native
rerun against the final runner inputs.

Full language/native Fuel matrices, Linux, LF runtime mirrors, OOM/general stack
containment, performance and clean-machine delivery remain separate validation.
The complete objective also still requires Buffer body integration, broader
L04/L05/L06/D01-D04, Engine/Instance, host exchange, isolation and delivery.

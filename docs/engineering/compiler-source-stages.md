# Compiler source stages

The private source-lowering foundations now have explicit continuations. The
owning compiler collects immutable module bytes through `source_context_work`;
ordinary lexer, literal-decoder, scoped-name and primitive/wrapper-type calls
drain their corresponding continuations synchronously. The complete proof
continues through the [preceding proof kernels](runtime-authority-metadata-stages.md#compiler-proof-stages).
This remains partial lowering, rather than a resumable compiler coordinator.
Untyped and typed/value signature passes compose the children below, including
canonical catalog proof and result/parameter planning. Ordinary function-body
control traversal now also drains an explicit frame continuation.

## Implemented boundaries

Each advance admits one fresh 4096-unit logical allowance. A partially used
allowance defers without changing the continuation or meter. Child work runs
in separate advances; unused credit cannot accumulate into a later scan.

| Kernel | Work in one stage |
| --- | --- |
| `source_context_work` | Copy at most 64 immutable source bytes, pack one import/symbol row, or validate one sealed name of at most 64 bytes. |
| `source_utf8_work` | Validate a scalar-aligned cut of at most 259 bytes. |
| `literal_source_work` | Decode at most 16 scalar/escape transitions; raw and cooked UTF-8 checks use separate cuts. |
| `literal_scan_work` | Scan a token without constructing the decoder's 4096-byte cooked bank. |
| `lexer_work` | At most 16 byte/scan transitions, or one separately resumed literal-scanner stage. Qualified-name lookahead has its own continuation. |
| `source_context_check_work` | Validate one shape/metadata row or at most 64 bytes of a copyable, possibly forged name. |
| `source_name_work` | Resume context authentication, query tokenization, one alias/declaration row, or at most 64 spelling comparisons. |
| `type_parse_work` | One primitive/wrapper grammar transition or a separately resumed lexer stage. |
| `signature_type_work` | One array/borrow/nominal annotation transition, a primitive/name/token child, or an explicit unscoped nominal discovery request. |
| `declaration_skip_work` | One struct field/body-brace transition or lexical child, preserving the existing sixteen-field and depth-33 limits. |
| `struct_locate_work` | A single-source declaration/header/skip transition or at most 64 nominal spelling comparisons. |
| `signature_parse_work` | One function/parameter metadata transition or one separately resumed annotation/discovery/name/body child; duplicate comparisons use at most 64 bytes. |
| `source_state_work` | A context-authentication child, one module/import row, or fixed scoped-lexer preparation. |
| `function_scan_work` | One single-source/indexed declaration transition or one signature/skip/context/token child; publish only the complete Table. |
| `record_fields_work` | One source-state/type/name child, field metadata transition or at most 64 nominal/duplicate-name comparisons. |
| `struct_scan_work` | One declaration/field/layout child or declaration-name comparison; all declaration syntax is checked before type resolution. |
| `literal_intern_work` | One builder/catalog row, one UTF-8 child or at most 64 existing-payload comparisons/new-payload copies; final catalog update only after fallible checks. |
| `literal_collection_work` | One source/context/token/decoder/intern child, one result/catalog row or at most 64 candidate-copy/decoded-clear bytes; only the completed Index is prepared. |
| `value_properties_work` | One canonical/unused row, one cleared restart row, or the existing struct-layout child; preserve catalog-before-grammar diagnostics. |
| `value_type_work` | One five-frame grammar transition, canonical match/copy row, sixteen packed record fields, or token/nominal/catalog-proof child. |
| `value_signature_work` | A type-parser child or fixed canonical-node-to-tag conversion and successful candidate publication. |
| `value_function_work` | Record declaration proof, one candidate row, sixteen packed fields or the existing signature coordinator with an external typed annotation bank. |
| `value_catalog_work` | One function/parameter/unused header, canonical matching row or independent catalog-proof child. |
| `body_source_work` | One ordinary body/control or pattern transition, one scoped local release, at most 256 loop-fixup visits, or a separate lexer child. Semantic expression/statement requests wait outside this allowance. |
| `struct_layout_work` (reused) | Fixed scratch initialization, one sixteen-slot row, at most sixteen dependency visits, or one node of at most sixteen fields. |

The owner pins the exact source, Index/context and query across advances.
States are copyable analysis scratch, not independent authority to execute or
accept changed inputs. Initial fixed scratch construction is outside these
advance contracts. Logical entry/transition bounds are not instrumented scalar
field, byte, CPU or wall-clock measurements.

## Compatibility and evidence

Raw collection, decoder, token scanner, context validity, name binder and type
grammar remain comparison paths. Name lookup preserves the first matching
alias/declaration, cross-module visibility and the first-private-match result;
malformed queries still return the existing absent sentinel. Primitive/wrapper
parsing preserves exact tags, syntax/type/lexical error order and the observable
lexer state on failure, including qualified lookahead. Decoder checks preserve
escape-before-encoding diagnostics and exact source offsets.

Lexer and primitive-type compatibility adapters retain the historical raw path
for sources larger than this private 4096-byte profile. Public compilation still
uses its existing admission gates and remains synchronous. No public Pending
compile, cancellation protocol, time bound or peak-stack improvement follows.

The [source-stage evidence](../evidence/runtime-compiler-source-windows-20261111.json)
records the frozen unit receipts, exact integrated owner/test/input hashes,
both-profile adapter checks and complete Engine images on default stacks.
The combined adapter suite exercises 18 native groups per profile, including
4096-byte comments/names, forged contexts, insufficient-room deferral, terminal
idempotence, visibility ordering and exact raw diagnostics. Historical focused
receipts describe their original snapshots, rather than the final whole tree.

Integrated Engine development/O2 pass default 1MiB/4KiB stacks, exact Fuel/
output/error, compile/reuse, pins/moves, terminal/cancel and zero SDK heap at
exit. All 321 Engine input hashes match integration `c6e1cf8`; all 313 production
modules retain LF. Transport retains 36 bindings and 51 layouts. A recursive
bijective comparison of 176 referenced aggregate graphs confirms unchanged
structure despite generated C identifier renumbering. Core/Cursor/Machine
remain 172400/1184/1792 bytes.

## Untyped declaration and signature integration

Owning `functions::scan` / `scan_reference_returns` and scoped/input signature
adapters now drain `function_scan_work`. Untyped single-source and immutable
module inputs retain exact entry selection, record order, pub/import resolution,
parameter duplicates and reference-return candidates. Raw signature/single/index
scans remain independent ordering oracles. The unscoped compatibility adapter
keeps the raw fallback above 4096 bytes. Typed/value signature preparation now
composes the later kernels described below.

Every declaration/signature child resumes separately, including unscoped nominal
discovery. Struct/function skipping preserves early-match discovery and exactly
the previous brace/field limits. Private partial candidate metadata and observed
lexer failure state also match the raw signature oracle. A fixed signature
scratch copy bridges the compiler's sibling mutable-loan restriction without
replaying source or banking credits. This fixed framing is part of the logical
allowance, not an instrumented copy/CPU guarantee.

The [signature evidence](../evidence/runtime-compiler-signatures-windows-20261111.json)
records six new kernels with seventeen frozen groups per profile and six current
integrated groups per profile. Engine development/O2 pass default 1MiB/4KiB
stacks, exact Fuel/output/errors, compile/reuse, moves/pins, terminal/cancel and
zero SDK heap at exit. All 327 Engine inputs match integration `93f10db`; all 319
production modules retain LF. The 36 typed bindings/51 layouts and 176 referenced
aggregate graphs remain structurally equivalent after generated identifier
renumbering. Core/Cursor/Machine remain 172400/1184/1792 bytes. The preceding
foundation receipts continue to describe their own frozen snapshots.

## Struct declaration, field and layout integration

Owning `struct_source::scan` and `scan_scoped` now drain `struct_scan_work`.
The first pass retains declaration-name/body spans and validates every member
syntax (and single-source function skip) before any field type is resolved.
The second pass resolves nominal/scalar fields and duplicate field names; the
existing layout kernel then checks the complete catalog and dependency graph.
Only the finished Table is available through `prepared`.

Preserve raw quirks as well as successful tables: single-source layout errors
point to the first declaration, while scoped errors point to the first failing
root. A scoped packed span may be only a prefix of the actual lexer token;
primitive words must still query that metadata. The primitive lookup shortcut
is restricted to syntax-checked unscoped declaration names. Fixed field-frame/
catalog copies bridge sibling-loan restrictions within logical framing; they
do not establish instrumented byte/CPU bounds.

The [record evidence](../evidence/runtime-compiler-records-windows-20261111.json)
records two new kernels, six frozen groups/profile and six current owning adapter
groups/profile. Engine development/O2 pass default 1MiB/4KiB stacks and zero exit
SDK heap. All 329 Engine inputs match `da8fe2c`; 321 production modules retain LF.
Transport keeps 36 bindings/51 layouts and equivalent 176 aggregate graphs;
Core/Cursor/Machine remain 172400/1184/1792 bytes. Prior source/signature evidence
continues to describe its own frozen checkpoints.

## Literal collection and image interning integration

Owning `literal_collection::collect` / `collect_scoped` now drain the private
collection continuation. Pin immutable source/context/original Builder and use
separate private candidate/control banks. Whole-source UTF-8 validation precedes
any tokenization; each module's lexer state, token, cooked literal and image
interning child resumes independently. Candidate payload copying, decoded bank
clearing and intern comparison/copy inspect at most 64 bytes in a stage.

Preserve exact Source/Image error fields and order: syntax/decoding occurs before
image admission; existing literal matches precede count/remaining-byte failures.
The sixteen-occurrence ceiling remains separate from sixteen unique image IDs.
A malformed Builder is still accepted when no literal needs interning, as in the
raw owner. Only complete collection publishes the Index and caller Builder.
The synchronous adapter's final fixed aggregate assignment, initial fixed scratch
construction and final native image allocation/copy remain outside these advance
contracts. Raw `collect_scoped_raw` and static image intern helpers are comparison
oracles; the public compiler remains synchronous.

The [literal evidence](../evidence/runtime-compiler-literals-windows-20261111.json) records
three initial interning groups/profile, six frozen composed groups/profile and
14 current integrated groups/profile, including existing exact-Fuel, image
quota, literal execution, occurrence limits and whole-owner rollback regressions.
Engine development/O2 pass default 1MiB/4KiB stacks and zero exit SDK heap. All
331 inputs match `52e7aca`; 323 production modules retain LF. Transport
keeps 36 bindings/51 layouts and equivalent 176 aggregate graphs; Core/Cursor/
Machine remain 172400/1184/1792 bytes. Older evidence remains frozen history.

## Typed/value signatures and canonical catalogs

`value_type_source::parse`, `value_signature_source::parse`, `functions::scan_values`
and `value_source_functions::prepare` now drain explicit children. The type
parser uses five frames rather than native recursion for the maximum four
wrappers. It preserves exact Buffer qualification/relex behavior, original `>>`
positions/token counts, nominal discovery, first canonical match at capacity,
array restrictions and original Catalog/lexer rollback. Source helpers retain
the raw compatibility path above 4096 bytes. Initial catalog validation remains
before grammar; complete record declarations/layouts remain before signatures.

The typed annotation bank is separate from legacy signature State, keeping
untyped continuation layouts unchanged. Signature metadata/name/body children
are reused. Catalog mapping authenticates all canonical properties first, then
visits result, parameter and unused rows in the original order. Only readonly
byte reference modes and the previously supported exact origin metadata map to
66. Preserve raw quirks: unused result origin/candidate fields remain ignored.
`properties::inspect`, type/annotation `parse_raw`, `scan_values_raw` and
`prepare_raw` remain comparison paths. Body-derived canonical interning and
function-header admission outside this preparation remain atomic.

Restarted catalog proof clears one result row per stage and reuses completed
layout storage, avoiding repeated nested scratch construction. Fixed initial
scratch and frame/catalog handoffs still lie within logical framing rather than
an instrumented byte/CPU or peak-stack guarantee. No public Pending compiler or
time improvement follows from these changes.

The [value signature evidence](../evidence/runtime-compiler-value-signatures-windows-20261111.json)
records five new kernels and frozen snapshots, plus 8 groups/profile at that checkpoint.
Coverage includes exact raw tags/tables/Plan/error fields, deferral, terminal
idempotence, rollback, sixteen functions, eight arguments, 64 canonical nodes,
four wrappers with 32 controls and rejection at 33, and existing value execution.
Engine development/O2 pass default 1MiB/4KiB stacks and zero exit SDK heap; all
335 inputs match `f3995df`. 328 production modules are LF. Transport
retains 36 bindings/51 layouts and equivalent 176 aggregate graphs; Core/Cursor/
Machine remain 172400/1184/1792 bytes. Earlier evidence stays frozen history.

### Local annotation/control stack repair

The former failing source combines a local four-wrapper annotation, owned-value
use and 32 nested controls. Its exact 941 guest bytes now compile, verify and
execute to 42 in both development and release regressions; depth 33 still
rejects with kind 4 and an in-source offset. The separate maximum-wrapper function-signature
fixture remains selected. All 9 selected groups pass in each profile. Engine
development/O2 also pass default 1MiB/4KiB stacks and zero exit SDK heap; all 335
input hashes match `5f00e60`. The reviewed 36 bindings, 51 layouts and 176
aggregate graphs retain their shapes; Core/Cursor/Machine stay
172400/1184/1792 bytes. 328 production modules retain LF. See the
[body stack evidence](../evidence/runtime-value-body-stack-windows-20261112.json).

The crash was inside `source::compile`, while constructor preflight checked the
canonical catalog. Native development code for `properties::inspect` reserved
large Plan-bearing Result temporaries on every error edge, including untaken
edges. A private `inspect_into` now writes caller-owned scratch and returns a
small count/error result. The compatibility wrapper publishes its complete Plan
only after success. Catalog/record/node validation order and properties stay the
same; existing independent staged catalog comparisons cover the raw checker.

The [earlier signature evidence](../evidence/runtime-compiler-value-signatures-windows-20261111.json)
retains the original failure as history. This repair uses the pinned compiler
and default native stacks. It does not replace recursive body lowering or prove
that every independently admitted source limit composes.

### Ordinary body control continuations

`body_source_work` replaces the common compiler's recursive statement-control
walk with 67 fixed slots: up to 65 admitted live frames and two slots preserving
the old depth-error order. Function-root sequences, nested blocks, if/else-if,
while, for and two-arm switch resume through explicit phases. Pattern tokens use
the lexer continuation; block and break/continue cleanup releases one local per
stage. Loop jump fixups visit at most 256 rows. The owner pins one source, IR,
name table and loop state across every advance; deferred work consumes no credit
and replays no semantic child.

The owning `compiler::body` adapter drains these stages synchronously. The raw
`lower_body(...,false)` path remains a candidate-only comparison oracle. All IR
fields, including unused/reserved tails and catalog/owner metadata, are compared
after successful and failed body calls. The focused suite covers branch/loop/
pattern diagnostics, lexical array cleanup, void fallthrough and 32/33 boundaries
for both nested blocks and else-if chains. A 33-brace failure may precede body
lowering in the independent signature scanner; the else-if cases separately
exercise the semantic depth guard.

At this control-only checkpoint, declarations, assignments, returns, condition/
subject expressions and for-header probe/replay remained synchronous semantic
children outside the control-stage bound. The following semantic section records
the later Pratt, annotated declaration and scalar/void return stages. Function parameter setup, entry
lexer preparation, implicit-return cleanup and final metadata assignment also
remain outside this kernel. Value-yielding expression scopes and the separate
`value_source` body walker still recurse. This is bounded ordinary control work,
not complete resumable body/expression lowering or a public Pending compiler.
Fixed initial scratch remains outside the advance contract; no measured byte,
CPU, timing or peak-stack improvement is claimed.

The [body control evidence](../evidence/compiler-body-control-windows-20261112.json)
records the 2-group kernel checkpoint, 5-group integration checkpoint and current
5 groups per development/release profile (12 successful and 11 failing source
fixtures). Engine development/O2 pass default 1MiB/4KiB stacks and zero exit SDK
heap; all 336 input hashes match `6451094`. Transport preserves 36 bindings,
51 layouts and 176 aggregate graphs. Core/Cursor/Machine remain
172400/1184/1792 bytes. 329 production modules retain LF. Run
`python tools/verify-body-source-work.py --profile development` and then
`--profile release`; Engine verification remains `python tools/verify-runtime-engine.py`.

### Expression, annotated declaration and scalar return semantics

At the initial expression checkpoint, the common compiler gained two private kernels. The expression
kernel keeps 34 Pratt frames and requests each converted unary/postfix/cast
operand explicitly. Operator tokens resume through the lexical kernel; binary
precedence, comparisons and logical short-circuit slot/branch/patch/load emission
preserve the raw expression order. Depth rejection precedes the operand request.
Conditions and switch subjects use this adapter, as do the newly staged scalar
initializers and returns. This does not replace recursion inside a converted
operand, including parenthesized expressions, CALLs or value-yielding scopes.
The later group/CALL/unary checkpoints below replace its ordinary recursive children.

The semantic kernel stages annotated primitive and legacy scalar-payload
Option/Result declarations through keyword/type/name/equals, initializer,
terminator, optional slot/store and final local registration. The binding stays
invisible throughout initialization. Inference, array, record and reference
forms request the existing semantic child; exploratory annotation tokens are
discarded by restoring the original lexer before that child starts. No
initializer or emitted semantic child is replayed.

Ordinary scalar and void returns stage keyword, expression/type check when
needed, terminator, pending selections, lexical finalizers and RETURN. Cleanup
visits one pending selection or local in reverse order per stage and retains the
return keyword offset. A local finalizer may scan up to 256 existing IR rows to
recover a slice parent. Reference, slice, record, array and Result return
protocols retain explicit legacy children. Scalar assignments, for-post probe
and replay, and implicit void fallthrough cleanup also retain their old paths.

Each advance admits one logical grammar transition or delegates one lexical,
type or Pratt advance. An outstanding child and an exhausted dispatch allowance
remain idle. Initial fixed scratch construction and synchronous adapter drains
stay outside these contracts; the per-dispatch allowance is not a byte/CPU,
latency or measured peak-stack guarantee. Intermediate IR is candidate scratch;
only completed kernel results and complete initialized bindings are published.

Run `python tools/verify-semantic-source-work.py --profile development` and
then `--profile release`. The selection includes both existing body-control
kernel groups, so a second identical body-only native build is unnecessary.
The [semantic evidence](../evidence/compiler-semantic-source-windows-20261112.json)
records separately committed Pratt and declaration checkpoints, then 13 native
groups in each profile: 32 successful and 28 failing source comparisons, exact
IR/error fields, expression/control depth 32/33 and local count 64/65. Engine
development/O2 pass default 1MiB/4KiB stacks and zero exit SDK heap; all 338
inputs match `5fa36fa`. Transport retains 36 bindings, 51 layouts and 176
equivalent aggregate graphs. Core/Cursor/Machine remain 172400/1184/1792 bytes;
331 production modules retain LF. Optional public Fuel CLI and full release
suites were not requested. Earlier checkpoints remain frozen history.
The public compiler still drains synchronously; remaining semantic children and
the separate typed/value body walker are not made resumable by this change.

### Grouped and CALL operand internals

Ordinary groups and scalar-result CALLs now share the existing 34 Pratt frame
slots. Opening/closing tokens resume through the lexer; group results pass once
to the converted tail. Plain CALLs retain eight argument cells per frame and
stage each argument expression, type/arity check, delimiter and CALL emission.
Admitted group/CALL argument traversal reuses this stack; legacy operand
children can still recurse. Existing depth and actual-argument limits retain
their original error order, including trailing commas and excess arguments.

Scalar-result CALLs with array, record or reference formals use a separate CALL
kernel. It stages the stable scalar/immutable-owner prefix, one argument
request, its delimiter, final arity, close token, CALL, optional reference
promotion and reverse capture cleanup. Scalar argument expressions rejoin the
same Pratt stack. CALLs share one append-only 64-binding prefix. Frame counts
and pending masks restore each enclosing lexical view; callbacks reject changes
to existing bindings. Child frames inherit the correct enclosing capture
context. Mutable owners are still captured before subsequent argument effects,
and early returns see all active hidden captures. Whole candidate IR, including
failure prefixes, remains equal to the independent raw body route after both
routes prepare aggregate catalogs. The internal aggregate-preparation helper
publishes candidates only.

The owning adapter pins the capture bank separately from the expression and
semantic State values. This avoids copying the large bank through every State
constructor. A CALL dispatch loads and stores 64 lexical rows and eight argument
cells through fixed scratch, then advances one phase. These bounded transfers
belong to the conservative 4096-unit logical stage. Initial bank/scratch
construction and explicit legacy children remain outside the advance contract.
No heap allocation, compiler override or larger native stack was introduced by
this bank. Default-stack execution is evidence for the selected fixtures, not a
measured peak-stack or performance improvement.

At the grouped/CALL checkpoint, read-only cast/Result/projection/CALL classification remained an explicit child.
Constructor payloads, postfix/propagation/casts, conditional
value scopes, projections, aggregate/reference argument evaluation and
special-result CALL protocols also retain legacy children. The separate
typed/value body walker remains outside this coordinator. In particular, do not
charge a whole legacy argument parser as if its recursive work had been split by
the CALL kernel.

Run `python tools/verify-operand-source-work.py --profile development` and then
`--profile release`; `--kernel-only` narrows a completion/mixed-depth recheck.
The [operand
evidence](../evidence/compiler-operand-source-windows-20261112.json) records the
small group/plain-CALL/capture commits, composed development/release snapshots,
current capture/completion/mixed-depth rechecks in both profiles and Engine
results. It preserves three reproduced stack failures and their subsequent
repairs, including the later reduction from per-frame tables to a shared prefix.
Existing [semantic
evidence](../evidence/compiler-semantic-source-windows-20261112.json) remains
the earlier checkpoint. Public compilation still drains synchronously; there is
no public Pending compiler or R02-R05 closure.

Composed development/release snapshots each pass 21 native groups. After the
binding-bank reduction, all three affected capture/completion/mixed-depth groups
pass in each profile. Engine development/O2 pass default 1MiB/4KiB stacks and
zero exit SDK heap; all 339 input hashes match `fe0dff4`. Transport retains 36
bindings, 51 layouts and 176 equivalent aggregate graphs; Core/Cursor/Machine
remain 172400/1184/1792 bytes. All 332 production modules retain LF. The composed
source comparisons cover 55 successful and 47 failing fixtures; the affected
subset was rechecked rather than rebuilding unchanged groups after the bank
reduction. Optional public Fuel CLI and full release suites were not requested.

### Unary operand internals

Ordinary `-`, `!` and `~` now reuse the same 34 expression frames. Each operator
stages its unsigned-context rejection/token, primary child, type check and IR
emission separately. The child inherits the enclosing capture environment and
uses minimum precedence zero as a private primary-only mode: it finishes
postfix inspection/propagation, then returns before casts or binary operators.
The enclosing frame applies the unary operation before its own converted tail.
No new frame fields, capture banks, allocations or native-stack overrides were
added. Unsupported child atoms keep their existing explicit legacy service.

The signed minimum literal branches consume their token through the lexical
kernel and emit the negative constant in a subsequent stage. They preserve raw
typing and depth exceptions without first materializing a positive magnitude.
Ordinary unary children keep primary's read-only Result preflight before operand
depth rejection; converted frames also retain their earlier cast preflight.
At this unary checkpoint, these scanners and all postfix/cast internals remained outside the stage allowance.
Owning adapters still drain synchronously.

Use `python tools/verify-operand-source-work.py --unary-only --profile development`
and `--profile release` for the focused unary selection. The full operand selection
also checks the existing group/CALL/capture and semantic continuation contracts.

The [unary evidence](../evidence/compiler-unary-source-windows-20261112.json)
records the first two-group development checkpoint at `32118ae`, then 24 native
groups in each profile at `02f9b0d`. It adds 17 successful and 14 failing source
fixtures plus six direct kernel expressions. Whole raw/staged IR and exact
diagnostics match, including 32/33 unary depth, signed-minimum depth exceptions,
mixed group/unary/ordinary or captured CALL depth, capture effects and early
return cleanup. These composed runs also recheck all earlier operand groups
after the shared binding-bank reduction; the earlier 21-group snapshot remains
historical evidence.

Engine development/O2 pass default 1MiB/4KiB stacks and zero exit SDK heap; all
339 inputs match `4af4888`. Transport retains 36 equivalent typed declarations
and 51 equivalent reviewed layouts. That comparison covered 384 generated
struct/resource definitions, retaining fixed-array type names without expanding
their 111 wrapper definitions. The later tail review below expands arrays as
well. Core/Cursor/Machine stay
172400/1184/1792 bytes. All 332 production modules retain LF. These selected
fixtures do not measure CPU/time or peak-stack improvements. Optional public
Fuel CLI and full release suites were not requested; changes remain local.

### Postfix and cast operand internals

Common compiler operand tails now use `operand_tail_work`. A single tail State
is pinned in the capture bank, separately from semantic State and the 34 Pratt
frames. It resumes `.is_ok`, `?` and `as` without re-evaluating the operand.
Primary-only unary children finish postfixes before returning to the enclosing
unary frame; casts remain after that operation and before binary operators.
Casts loop only over later `as` tokens, preserving rejection of a postfix
following an ungrouped cast. Cast target parsing delegates one advance to the
existing primitive/wrapper annotation kernel; the widening check and emission
are separate stages.

Dot lookahead resumes through the lexer using private scratch. A second dot
leaves the real lexer unchanged for the enclosing range parser, including its
token counter. A probe failure also leaves the real position unchanged. A valid
member commits the same next token as the raw parser before validating `is_ok`.
Inspection stages its slot, CASE, constants, stores, jump, patches and load in
the original order. Each grammar phase performs at most one IR helper call.

Propagation stages compatibility, success/failure CASEs, wrapping, jump/patch,
cleanup, RETURN and trap separately. Pending selections and lexical finalizers
visit one entry in reverse order per stage; only the failure path cleans up.
The names and pending set remain immutable for the success continuation. A tail
inside a captured CALL restores the enclosing 64-row lexical prefix before each
advance. That bounded transfer is part of the conservative 4096-unit logical
stage; individual static/slice finalizers may still inspect 256 existing IR
rows. Their internals have not been split into smaller continuations.

Read-only cast/Result/projection/CALL classifiers, initial fixed scratch and
unsupported child atoms remain outside this allowance. Postfix/casts inside
legacy assignments, aggregate/constructor/value children and the separate
typed/value body walker still use those children's original routes. Owning
adapters continue to drain synchronously; no public Pending compiler follows.

Run `python tools/verify-operand-source-work.py --tail-only --profile development`
and then `--profile release` for the focused tail, semantic and mixed-depth
selection. The default selection also includes the earlier operand groups.

The [tail evidence](../evidence/compiler-tail-source-windows-20261112.json)
records three initial development groups at `b9b3c54`, followed by nine focused
groups per profile at `ab23103`. The added source comparisons cover 15 successes
and 14 failures, with identical complete IR/error prefixes and diagnostic byte
offsets. Kernel checks cover eleven IR-capacity boundaries, reverse pending/local
cleanup, token/IR deferral, private dot-probe failures and terminal idempotence.
The focused selection also rechecks existing 32/33 ordinary/captured CALL and
mixed unary/group/CALL depth plus annotated binding and return contracts. The
default 29-group selection was not rerun.

Engine development/O2 pass default 1MiB/4KiB stacks and zero exit SDK heap; all
340 input hashes match `a6a332f`. The transport review retains 36 equivalent
declarations and 51 reviewed layouts after recursively expanding struct,
resource and fixed-array definitions. There are 495 definitions before and
496 after, including 111 array wrappers in each snapshot. The only layout
changes are the fixed tail State and its field in Bank; all other definitions
remain equivalent. Core/Cursor/Machine stay 172400/1184/1792 bytes. All 333
production modules retain LF. Optional public Fuel CLI and full release suites
were not requested; no performance or peak-stack improvement is claimed.

## Required remaining lowering work

The following semantic work remains atomic, even where its helpers drain stages:

1. Body-derived canonical interning and header admission outside typed/value
   signature/catalog preparation.
2. Fixed final Builder assignment, initial scratch and native image allocation/copy.
3. Body-derived slice origin analysis, including its seventeen rounds and
   expression/atom/CALL/name/control-flow traversal.
4. Array/record parameter/result catalog preparation.
5. Read-only operand preflight, constructor/conditional/projection and
   aggregate/reference argument children, including their internal postfix/cast
   parsing; special-result CALLs, scalar assignments,
   inferred/aggregate/reference declarations, special return protocols, for-post
   probe/replay, value-yielding scopes and the separate typed/value body walker;
   function entry/final metadata and implicit-return cleanup. Ordinary control,
   Pratt/group/unary/scalar-result CALL and operand-tail traversal, annotated scalar/wrapper declarations
   and scalar/void returns have explicit stages; remaining semantic children stay outside those bounds.
6. Final entry-call restrictions and output normalization, plus raw context/
   nominal discovery outside the newly staged owners.

Keep exact diagnostics/emitted IR, immutable originals and final-only publication
while replacing these calls in small verified commits. The current authorization
covers this lowering work; broader completion stays paused. Public R02-R05
closure, post-proof cache planning, admission allocations and unrelated runtime
discovery remain separate work. Local only; no push, release or deployment.

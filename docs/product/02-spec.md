- Latest loop-origin checkpoint (2026-11-07): [Evolving shared-view loop origins](../engineering/value-view-loop-origins.md)
  now infer candidate roots/retention from emitted IR through real backedges,
  nested loops and shared for-post paths. Converged state rechecks earlier writes,
  moves and cleanup, then widens zero-trip/break exits without source replay.
  Exact owning headers and descriptor identity remain; bottom break/continue
  composition executes. `9d7712b` passed 15 groups per Windows native profile,
  using disjoint locked mirrors and default stacks. All 228 inputs match
  checkout/Git raw bytes; all 216 production modules are LF. See [evidence](../evidence/value-view-loop-origins-windows-20261107.json).
  The combined depth fixture is byte-identical. No opcode, existing price, public
  admission or Fuel default/cap change. Next: loop-root cleanup deferral, remaining
  bottom contexts, general references, methods/public AllocError and remaining
  runtime/host/platform work. Full completion remains open. Local only.

- Predecessor native view-call checkpoint (2026-11-07): [Shared Buffer view CALL/RETURN](../engineering/value-view-calls.md) now
  publishes up to eight argument aliases atomically and returns only a window
  contained in the selected caller origin across authenticated adjacent frames.
  `4c8c84d` passed 12 native groups per Windows profile (six new); all 223 inputs
  match checkout/Git raw bytes and 214 production modules are LF. See [evidence](../evidence/value-view-calls-windows-20261107.json).
  This is the native prerequisite; guest reference signatures/IR/source remain
  next, followed by view-valued joins and the remaining full-profile work.
  Public admission/prices remain unchanged. Local commits only; no push/release.

- Predecessor Buffer view-copy checkpoint, 2026-11-07: Private [Buffer view copying](../engineering/value-view-copy.md) now accepts
  `bytes::copy(ref view)` and qualified/range/temporary inputs, returning an
  independent exact `Result<Buffer,u8>`. APPEND_VIEW112 independently proves live
  views, a live distinct unpinned Buffer and a fresh Result; runtime prepays
  publication and copies only authenticated initialized bytes without payload
  staging. The anonymous capture closes before Result wrapping; named views stay
  pinned. Kernel `3d158ba` and integrated source/VM `223260f` are local commits.
  Windows development/release each passed 21 groups (nine new) in three
  disjoint batches. All 224 union inputs match checkout/Git raw bytes; all 213
  production modules are LF. The unchanged admitted32/rejected33 depth fixture
  executes in both profiles. See [evidence](../evidence/value-view-copy-windows-20261107.json).
  Next: general reference parameters/results, reference-valued joins, methods,
  public AllocError/admission, text/I/O, full Engine/Instance/host/cancellation,
  isolation and platform/delivery. Existing prices, no-view setup costs and public
  Fuel default256/ceiling16000000 stay unchanged. The full objective remains open.
  Local only; no push/release/deployment.

- Predecessor native Buffer view checkpoint, 2026-11-07: Native [Buffer view lifetimes](../engineering/value-buffer-views.md) now pin actual
  roots through shared aliases and nested ranges, with authenticated bindings,
  checked windows, last-alias release and generation retirement. Read/copy-out
  exposes no native view. Registry metadata shares root quotas and refunds before
  root drain; cleanup needs no remaining Fuel. Both Windows native profiles passed
  19 groups (views/leases/roots 10, root/frame/copy regressions 9) on `34863b5`.
  All 219 union inputs match checkout/Git raw bytes; all 208 production modules are
  LF. See [evidence](../evidence/value-buffer-views-windows-20261107.json). Native bookkeeping is not guest authority.
  Next connect independent Buffer view IR/CFG/retained VM and source admission,
  then copy-from-view, public AllocError, text/I/O and the remaining full profile.
  Public gates, existing prices/Fuel defaults remain. Local only; no push/release.

- Predecessor Buffer copy checkpoint, 2026-11-07: Private [owned Buffer copy](../engineering/value-buffer-copy.md) now lowers
  `bytes::copy(ref b)` / `brownie::bytes::copy(ref b)` to exact `Result<Buffer,u8>`.
  One native append copies initialized bytes into an independent owner, retaining
  the source and cleaning temporary inputs. Shared Result destinations avoid
  extra arm slots; no opcode or existing Fuel price changes. Both Windows native
  profiles passed 13 groups (source 9/native 4), including 22 new guest programs and
  the unchanged 32/33 depth fixture, on `ee8a686`. All 218 inputs match checkout/Git
  raw bytes; all 207 production modules are LF. See [evidence](../evidence/value-buffer-copy-windows-20261107.json).
  Next Buffer views, copy-from-view, methods/public AllocError and deliberate public
  admission, text/I/O and general language/runtime composition. The full objective
  remains open. Local only; no push/release/deployment.

- Predecessor Buffer source checkpoint, 2026-11-07: Private [Buffer source operations and loans](../engineering/value-buffer-source.md) now lower
  `bytes::` / `brownie::bytes::` empty, len/read/write and push/reserve/append.
  Compiler-only loans protect later arguments, survive control/propagation/loop
  exits and release temporary owners. Named mutation requires `var`; overlapping
  loans and self append reject. Typed `&&`/`||` skip runtime RHS work and join
  conditional moves and Result obligations. Both Windows native profiles passed
  12 groups (source 7/native 5), including 62 new guest programs and the unchanged
  32/33 depth fixture, on `e8d2a7d`. All 217 inputs match checkout/Git raw bytes;
  all 206 production modules are LF. See [evidence](../evidence/value-buffer-source-windows-20261107.json).
  Next Buffer copy/view/methods, public AllocError and deliberate public admission,
  text/I/O and general aggregate/reference/module/runtime composition. D02/D04 and
  the full objective remain open. Public gates, existing prices and Fuel default
  256 / ceiling 16000000 remain unchanged. Local only; no push/release/deployment.

- Predecessor Buffer instruction checkpoint, 2026-11-07: Private [Buffer instructions](../engineering/value-buffer-execution.md) now independently verify and execute
  length/read/write, push/reserve and distinct-source append (99..104). Growing
  operations prepay canonical Result publication; allocator errors return the
  private Result<usize,u8>, while Fuel/quota/bounds remain execution errors. Source
  owners and failed operations retain their bytes/accounting. Both Windows native
  profiles passed ten focused groups on `6107487`; all 210 inputs match checkout/Git
  raw bytes and all 202 production modules are LF. See [evidence](../evidence/value-buffer-execution-windows-20261107.json).
  Next source Buffer methods/borrows/views, a public AllocError contract and I/O,
  then general aggregate/reference/module/public composition. D02/D04 and the full
  objective remain open. Existing prices/Fuel defaults and public gates remain.

- Private typed source, 2026-11-07: [lexical loops](../engineering/value-loops.md)
  now compose while/for/break/continue with Buffer/nested-tag values, owner cleanup,
  [conditional values](../engineering/value-joins.md) and cyclic
  [Result obligations](../engineering/value-must-use.md). Both Windows native
  profiles passed ten focused loop groups with 47 guest programs and the unchanged
  32/33 depth fixture. Public source/CLI gates and capabilities are unchanged;
  useful Buffer operations, general composition and the full profile remain open.

- Native value bytes, 2026-11-07: [retained canonical layouts and byte operations](../engineering/value-codec.md) now validate exact scalar/array/plain-record/wrapper representation, tags, bool, padding/inactive bytes and the one active opaque Buffer word. Direction-aware copies and disjoint wrapper construction validate before mutation. Development/release each passed six native groups on f5d3d1a, with 188 checkout/Git-raw-matching inputs and 183 LF production modules. This is a byte-storage prerequisite: native root authentication, owning value/frame storage, metering, cleanup, VM execution and source bindings remain next. Public behavior/prices/limits remain. See [Windows evidence](../evidence/value-codec-windows-20261107.json). Full language/native Fuel/CLI, LF mirrors, Linux, OOM/general stack/performance and clean-machine delivery were not rerun. Earlier checkpoints retain their scopes.

- Typed value IR prerequisite, 2026-11-07: [complete independent ownership analysis](../engineering/value-ir.md) now connects MOVE/COPY/DROP, tag build/case, scalar value conversion and value CALL/RETURN to whole-type properties, exact initialized/Dead CFG state and canonical scalar/aggregate/loan/selected-place proof. Inactive/scalar Buffer alternatives still consume their complete wrapper. This is analysis only; all existing executable routes retain their gates. Metered native value storage/execution, cleanup and compiler source integration remain next. Full L04/L05/D01-D04/Engine/Instance/host/delivery remain open. See the [focused Windows evidence](../evidence/value-ir-windows-20261107.json); earlier checkpoints retain their scopes.

- Resource/tag ownership prerequisite, 2026-11-07: [whole-type properties and native Buffer handoff](../engineering/value-ownership.md) independently derive scalar/array/plain-record/Buffer/Option/Result layout, depth and copyability, including inactive Buffer alternatives. The native handoff consumes a real allocation, preserves its owner token and charge, prepays Fuel and returns the original root on rejection. Guest source-binding/Dead CFG proof, resource TAG_BUILD/TAG_UNPACK, wrapper source/VM integration and full L04/L05/D01-D04 remain open; no public capability or existing price/limit changes. See the [focused Windows evidence](../evidence/value-ownership-windows-20261107.json). Earlier checkpoints retain their scopes.

- L04 ordered aggregate source assignment: [all five source store forms](../engineering/aggregate-place-assignment.md) now select whole arrays and nominal record subtrees before RHS and end them before anonymous owner cleanup. Grouped/CALL/if/switch inputs and nonlocal cleanup share existing place IDs; complete source Fuel changes while instruction prices/default 256/cap 16000000 remain. Resource/tag copy/move and the remaining full L04 obligations stay open.

# Product Specification

- Status: Accepted for design, 2026-10-23
- Implementation status: Reconciled 2026-11-07; bounded M1 and public M2 aggregate/slice/literal/shared-byte-result subsets; full profile incomplete
- Source profile name: brownie.safe/0.3

- L04 common native dispatch: [shared storage and IDs](../engineering/place-dispatch.md)
  now serve scalar arrays, exclusive slices, scalar record fields, whole arrays
  and nominal record subtrees in one allocation/counter per invocation/frame.
  Legacy-only formats/prices remain. Both drivers and retained guards must consume
  this dispatcher before executable kind3/4 admission; ordered lowering follows.

- L04 aggregate metering: [native invocation storage](../engineering/aggregate-place-vm.md)
  now executes array copy/fill/list and nominal record copy/constructor stores
  with prepaid setup/operations, invocation-local tickets and zero-Fuel abort.
  Legacy formats/prices, public default256/cap16000000 and executable admission
  remain unchanged. Both coordinators, retained guards and source lowering are next.

- L04 aggregate IR: [independent identity/phase/lifetime analysis](../engineering/aggregate-place-ir.md)
  now proves whole-array copy/fill/list stores and exact nominal record copy or
  constructor replacement. Kinds3/4 and PLACE_REPLACE87 share the existing sixteen
  frame-local place IDs, scalar definitions and dense operand pool. Complete
  ordinary/image/returned-reference execution remains gated pending both drivers,
  retained guards and source lowering; metered native storage is described above.

- L04 aggregate destinations: [private native snapshots](../engineering/aggregate-selected-place.md)
  now capture whole arrays and exact nominal record subtrees before RHS work.
  Owner generations, original reservations and selected windows are revalidated
  before owner copy, fill, list or constructor publication, without another guest
  owner/extent. The adapter accepts a reusable scratch prefix and keeps atomic
  source validation. Aggregate-place IR, metered VM storage, both drivers and
  source lowering remain separate; public source/IR/prices/limits are unchanged.

- L04 copy IR: [independent strategy and lifetime composition](../engineering/aggregate-copy-ir.md)
  now derives all five existing array/record copy forms and by-value CALL argument
  strategies from immutable operands. Canonical CFG/owner/loan proof, ordinary,
  image and returned-reference admission consume the same checks. Recursive equal
  static IDs still copy into distinct activations; records always stage complete
  canonical snapshots. Aggregate selected places and resource/tag move rules remain open.

- L04 native copy prerequisite: [checked byte windows](../engineering/aggregate-copy-windows.md)
  now guard existing scalar-array/plain-record copies and CALL transactions.
  Authenticated array self copies skip redundant bytes after canonical bool and
  loan checks; records retain snapshots and padding normalization. A reproduced
  optimized flat Shape preparation failure is repaired. Both Windows profiles
  pass 22 focused native groups and20 CLI cases with unchanged prices/limits.
  The [IR successor](../engineering/aggregate-copy-ir.md) now composes those strategies
  with canonical lifetime proof; aggregate selected places and resource/tag move rules remain open.

- Public aggregate Fuel: [the shared schedule](../engineering/public-fuel-limits.md#shared-aggregate-prices-and-current-public-routes-2026-11-06)
  owns existing array/record/list prices. Layout admission and both drivers keep
  their original dispatch, cleanup and numeric charges. The public boundary
  selection shares 24 independent source/numeric oracles between native and CLI
  checks, including four grouped assignment target kinds in ordinary and
  retained routes. Default 256 and explicit CLI ceiling 16000000 remain;
  native host budgets are independent. Other C05/Engine/Instance limits remain open.

- L04 native prerequisite: [owned-array selected locations](../engineering/array-selected-place.md)
  capture and revalidate the original scalar target. The
  [independent IR successor](../engineering/array-place-ir.md) now proves
  owned-array place identity, phases and lifetimes. [Both VM drivers](../engineering/array-place-execution.md)
  now execute this independently admitted native IR with metered snapshots,
  frame/CALL cleanup and returned-view guards. [Owned-array source assignment](../engineering/array-place-assignment.md)
  now selects/checks bounds before RHS and captures old scalars before all ten
  checked integer compounds. Full L04 remains incomplete; later kinds follow. The
  [compiler cleanup prerequisite](../engineering/array-place-cleanup.md) now
  preserves pending masks across lexical/loop scopes and ends them before
  ordinary nonlocal cleanup; the source successor now uses those paths.
  The [native exclusive-slice prerequisite](../engineering/slice-selected-place.md)
  captures the original range/session and accepts a canonical ticket refreshed
  by completed CALL/reborrow restoration. Its
  [analysis-only ordinary IR](../engineering/slice-place-ir.md) now proves
  available authority plus shared location identity/phases/lifetimes; existing
  executable admission now accepts this slice kind after the complete proof. The
  [private metered adapter](../engineering/slice-place-vm.md) now supplies bounded,
  explicitly tagged snapshot storage and exact slice/mixed setup/operation
  preflight. Its [execution successor](../engineering/slice-place-execution.md)
  connects both VM drivers to canonical bindings, cleanup and
  image/returned-view/recipe guards. The
  [source successor](../engineering/slice-place-assignment.md) now selects and
  checks slice indices before RHS, captures old scalars before ten checked
  integer compounds and shares pending-place cleanup with owned arrays.
  This changes source IR and total Fuel; existing instruction prices and CLI
  limits remain unchanged. Version metadata adds two slice-assignment flags.
  The [native record-location prerequisite](../engineering/record-selected-place.md)
  captures the original nominal owner and scalar leaf, authenticates complete
  metadata and stages atomic scalar stores. Its
  [independent IR successor](../engineering/record-place-ir.md) now reconstructs
  exact scalar types and proves kind/site/field identity, phases and root/CFG
  lifetimes through separate analysis. Its [metered storage](../engineering/record-place-vm.md)
  and [execution successor](../engineering/record-place-execution.md) now connect
  complete admission and both drivers. The [record source successor](../engineering/record-place-assignment.md)
  selects exact fields before RHS and captures old values for checked compounds.
  Record source IR/Fuel changes deliberately; existing prices/limits remain and
  two narrow record-assignment flags are exposed.
  The [scalar-local successor](../engineering/scalar-assignment.md) now captures
  stable frame slots and old values before ten integer compounds, using existing
  LOAD/operation/STORE verification without a new native vector or pending ID.
  Compounds work in value arms and pure for clauses; plain scalar assignment IR
  and prices remain. Version metadata adds scalar_local_compound_assignment.
  The [grouped-location syntax prerequisite](../engineering/grouped-place-syntax.md)
  retains exact original spans and index/operator lexer states through a bounded
  read-only plan. Its [source successor](../engineering/grouped-assignment.md)
  now connects grouped scalar, array, slice and record targets to existing typed
  lowering, including whole/child aggregate transactions. Grouping preserves
  instruction bytes, exact Fuel, index/old-value order and nonlocal cleanup.
  Version metadata adds grouped_assignment_targets. Grouped borrows, generic
  aggregate overlap and complete L04 remain open.

## Product boundary

Brownie C runs a small, statically typed source profile on a native JIT-free VM.
The first intended uses are application data validation, byte transforms, and rule
evaluation. These are starting workloads, not proven market requirements.

The native VM reads .brc source. Running a program must not start Go, MSVC, a C
compiler, an interpreter subprocess, or a disk bytecode runtime.

## Current implementation versus target

The remainder defines the accepted target `brownie.safe/0.3`; it is not a list of
already available features. Current version JSON retains narrower experimental
profiles and feature flags. Six scalar types, arrays, nominal scalar/nested records,
by-value aggregate parameters/results and shared/exclusive scalar slices are public.
Whole/ranged/named-slice/temporary-array CALL borrows and fixed-array UTF-8 views
are available. Root exclusion remains whole-root, including disjoint mutable ranges.

Private returned-slice signatures, body-origin analysis and explicit
[preparation IR/independent proof](../engineering/m2-slice-result-ir.md) exist;
the [retained public successor](../engineering/public-program.md) now admits
byte/text literals and shared-byte image/runtime results through check/run. [Native ownership transactions](../engineering/m2-slice-result-runtime.md)
now support private returned-view VM execution, owned array/record inputs and CALLs,
root retention and prepaid finalization. [Direct return ranges](../engineering/m2-slice-result-ranges.md)
now use those same preparation/proof/handoff recipes. General returned-result
forms beyond shared-byte results, Buffer/input backing and host-visible reference
lifetimes remain open.
Private [Buffer source operations](../engineering/value-buffer-source.md) and
[owned copy](../engineering/value-buffer-copy.md) execute through the typed VM.
General Buffer view IR/VM/source, text and deliberate public Buffer admission
remain open.
There is no general Engine/Instance API, guest input/output, host suspension,
restricted worker or public DLL.

The [complete remaining-work audit](04-remaining-work.md) maps all 40 reference
required features and the wider delivery gaps. The [roadmap](01-roadmap.md) orders
them. [Typed mutable parameters](../engineering/m2-slice-mutable-parameters-public.md),
[temporary arguments](../engineering/m2-temporary-array-borrow-arguments.md) and
[private returned origins](../engineering/m2-slice-result-origins.md) own the newest
borrow boundaries. Immutable literal text and explicit text::bytes are public;
general runtime/Buffer/input text remains open. Existing shallow tags remain
i32/bool, depth one; general references, wide/resource-bearing tags and full module/visibility/inference syntax
are target work. Current M1 accepts Option `?` as an intentional narrow extension;
reconcile it explicitly before claiming raw-package dialect conformance.

## First source profile

The initial storage and value types are:

- bool, u8, i32, i64, u32, and 64-bit usize;
- scalar arrays with a literal length from 1 to 4096;
- limited acyclic plain structs with scalar or plain-struct fields;
- ref and ref mut borrows, with static ref str and explicit byte views for text;
- Option and Result with scalar, array, struct, Buffer, or shallow tagged payloads;
- move-only brownie::bytes::Buffer and staged output bytes.

The current lexer accepts a leading UTF-8 BOM, LF/CRLF and nested block comments,
and rejects a misplaced BOM, lone CR or raw NUL with original byte positions.
See [lexical compatibility](../engineering/lexical-compatibility.md).

Source functions use explicit Fairy-like declarations such as fn Type name.
Modules and imports are explicit. let and var introduce initialized locals.
The [local inference increment](../engineering/local-inference.md) now admits
`let name = value;` and `var name = value;` for existing scalar and complete
tagged expression types. The [owned aggregate successor](../engineering/aggregate-inference.md)
adds repeated arrays, nominal constructors, bare copies, aggregate CALLs and exact
record child paths. The [reference/text successor](../engineering/reference-inference.md)
adds existing views, loans, aliases and shared-byte results. The
[Option constructor successor](../engineering/option-constructor-inference.md)
derives `.some` from existing i32/bool payloads. The
[constructor-join successor](../engineering/constructor-join-inference.md)
combines complete final if/switch arm constraints: none-first Option values and
paired ok/err Result values infer existing i32/bool domains without choosing
missing defaults. Known typed values and mixed nested tails also constrain them.
Standalone ambiguous constructors and wider/resource-bearing tags remain separate
work. The
[element-list declaration successor](../engineering/array-list-source.md) adds
`let a=[x,y];` and `let i32[2] a=[x,y];`, with exact scalar types/arity,
left-to-right one-time evaluation and publication after complete initialization.
The [contextual successor](../engineering/array-list-contexts.md) now connects
direct list arguments, returned literals and temporary borrows. Whole-array list
replacement is covered by the [assignment successor](../engineering/array-list-assignment.md).
The [literal projection](../engineering/array-literal-projections.md),
[grouped array](../engineering/array-expression-projections.md) and
[grouped record](../engineering/record-expression-projections.md) successors now
compose the documented bounded aggregate forms. The
[aggregate conditional successor](../engineering/aggregate-if-expressions.md)
adds fixed-array/plain-record if values, and the
[switch successor](../engineering/aggregate-switch-expressions.md) supplies the
same aggregate contexts for exhaustive Option/Result switches. Broader inference,
general reference/Buffer joins and resource-bearing types remain pending; this is not a
full-profile promotion.

The experimental M1 increment keeps `fn i32 main()` as the zero-argument entry
point. Other functions and their parameters may use i32, i64, u8, u32, usize, or bool. Bool is canonical
0/1 and never converts implicitly to or from an integer type. The increment adds `!`, same-type
`==`/`!=`, same-type integer ordering, short-circuit `&&`/`||`, `if`/`else if`/`else`,
standalone lexical blocks, and early returns. Every function path must return, and
statements after a guaranteed return are rejected. Block-local names are limited to
their block, and a visible local or parameter cannot be redeclared. The loop
increment adds `while`, classic `for`, `break`, and `continue`; `for` init and post
are restricted scalar statements, and its header forbids direct calls. Transfers
target the nearest lexical loop. A `for` continue runs the post, while break and
return skip it. For return completeness, every loop is conservatively treated as
possibly zero-trip. Exact grammar and limits are in the [branch contract](../engineering/m1-branches.md)
and [loop contract](../engineering/m1-loops.md).

The tagged increment admits `Option<i32|bool>` and
`Result<i32|bool, i32|bool>` at wrapper depth one. Constructors take their wrapper
type from a typed initializer, assignment, function parameter, or return, including
through parentheses. Nested and aggregate wrappers are rejected. Wrapper values copy
by value through locals, calls, frames, and loops, but they do not support arithmetic,
ordering, or equality. `for` headers remain pure scalar. Exhaustive `switch`
statements use `.some`/`.none` or `.ok`/`.err` arms in either order, evaluate the
subject once, and bind immutable payloads in block scope. There is no default arm,
or fallthrough in statement arms. Exact statement rules are in the
[tagged contract](../engineering/m1-tagged.md).

The propagation increment adds postfix `?` in functions returning an admitted
`Option<T>` or `Result<T, E>`. The operand is evaluated once. An
`Option<S>` yields its `S` payload and returns `.none` on failure; a
`Result<S, E>` yields its `S` payload and returns `.err(E)` on failure.
Option success types may differ, while a Result error type must match exactly and
its success type may differ. Option and Result propagation cannot mix. Functions
returning i32 or bool, including `main`, reject `?`.

Postfix `?` binds tighter than unary and binary operators. It is admitted in
expressions such as while conditions, loop bodies, initializers, assignment right
sides, constructor payloads, call arguments, and returns. Classic `for` headers
remain pure scalar and reject it, and standalone expression statements remain
unavailable. Unevaluated short-circuit and untaken branch paths skip `?`. An
evaluated failure returns immediately, skipping later expression work, arguments,
the rest of the loop body, the `for` post step, and later iterations. Constructors
use the existing expected type, payload-derived some or final-arm constraints;
`?` itself adds no inference. Exact rules are in
the [propagation contract](../engineering/m1-propagation.md).

The switch-expression increment makes an exhaustive shallow-wrapper switch an
operand. A value arm contains zero or more typed local declarations and plain
assignments followed by one final expression without a semicolon, or `return EXPR;`
for the enclosing function. At least one arm must yield, and all yielding arms use
one exact type. A known yielding arm or expected expression type provides context;
complete final constructor arms can jointly resolve missing Option/Result domains
through the [constructor-join rules](../engineering/constructor-join-inference.md).
Subject evaluation is
once, mutable subjects are snapshotted, and a `_` binding discards the payload.
Each arm has private visible bindings, while assignments to an outer `var` persist.
Switch expressions compose with calls, returns, assignments, while conditions,
short-circuit expressions, and `?`; classic `for` headers remain pure scalar.
Exact rules are in the
[switch-expression contract](../engineering/m1-switch-expressions.md). The later
[arm-statement contract](../engineering/m1-switch-arm-statements.md) adds blocks,
if/else, while/for, and lexical loop transfers before the final arm value. Every
continuing path needs a final expression; wholly terminal arms close immediately.
At least one arm must still yield. A leading switch is the final expression;
wrap a statement switch in a standalone block. Expression and structural depth
budgets are inherited through arm statements. While conditions own their loop
transfers, and classic-for headers remain pure scalar.

The [if-expression successor](../engineering/if-expressions.md) now admits
`if (condition) { value } else { value }` and else-if chains for the existing
scalar and shallow-tagged types. A condition is exactly bool, only the selected
arm executes, and every continuing arm yields one exact type. Nested final
conditionals compose without extra parentheses; existing arm statements and
nonlocal cleanup remain. Missing else, mismatched types, entirely terminal
operands and pure-for usage are rejected. The
[aggregate successor](../engineering/aggregate-if-expressions.md) adds exact-shape
fixed-array and nominal plain-record joins, including locals, arguments, returns,
whole/child assignment, child constructor fields and scalar projections. Continuing
arms initialize one shared destination; selected evaluation, source-order effects
and existing nonlocal cleanup remain. The
[switch successor](../engineering/aggregate-switch-expressions.md) adds the same
fixed-array/plain-record value contexts for exhaustive Option/Result switches,
including grouped projections and mixed nested if/switch tails. The subject and
selected arm execute once, pattern payloads stay arm-local, and continuing arms
initialize one exact-shape destination before existing cleanup. General
reference/Buffer joins remain separate work.

The [void successor](../engineering/void-source.md) supports `fn void f(...)`,
explicit `return;`, implicit end-of-body return and direct `f(...);` statements,
including qualified native module calls. Calls preserve ordered argument effects,
captures and existing cleanup, without a result register. Void is return-only;
it cannot be a value, local, parameter, wrapper or array element. Ignoring nonvoid
results remains rejected, and classic-for headers remain pure scalar. Entry
still returns i32. Void RETURN costs one dispatch unit; existing CALL/cleanup
prices, public default 256 and ceiling 16000000 remain.

The i64 increment admits `i64` locals, function parameters and results, call
arguments and returns, assignments, loop variables and expressions, and
switch-expression result joins. Unsuffixed decimals default to i32 and become i64
from typed context or an already typed left integer operand. There is no implicit
conversion or suffix. Arithmetic, i64 comparisons, zero-divisor handling,
and overflow checks use the existing scalar instructions and i64 cells. Wrapper
payloads remain i32/bool, so `Option<i64>` and i64-containing Result types are
rejected; i64-returning functions reject `?`. Classic `for` headers still reject
calls, `?`, and switch expressions. Exact rules are in the
[i64 contract](../engineering/m1-i64.md).

The unsigned increment adds `u8` (0..255), `u32` (0..4294967295), and 64-bit
guest `usize` (0..18446744073709551615). These are distinct types, including
`u32` and `usize` when a value fits both. They may appear in locals, parameters,
results, calls, assignments, copies, recursion, loop clauses, and switch-expression
joins. Unsuffixed decimals still default to i32. Typed initializer, assignment,
argument, or return context, and an already typed left binary operand, admit an
unsigned literal without lookahead inference. There is no implicit conversion or
suffix. Unary minus is forbidden for unsigned values, including `-0`.
Same-type arithmetic is checked to the type's range; underflow or overflow reports
guest `overflow`, and a zero divisor reports `zero_divisor`. Unsigned ordering
decodes the stored cell as unsigned, while equality requires the same type.
Wrappers remain i32/bool payloads, and unsigned-returning functions reject `?`.
Exact rules are in the [unsigned contract](../engineering/m1-unsigned.md).

The widening increment adds `EXPR as TYPE`. Postfix `?` binds first, then unary
operators, then `as`, then all binary operators; casts associate left to right.
Exactly seven domain-preserving pairs are admitted: `u8` to `i32`, `i64`, `u32`,
or `usize`; `u32` to `i64` or `usize`; and `i32` to `i64`. Identity casts,
narrowing, signed-to-unsigned, `usize` to `i64`, bool/integer, and wrapper or
aggregate casts are rejected regardless of the current value. The cast source gets
no expected type from its target or surrounding context: `1 as i64` starts from an
i32 source and works, while `1 as u8` and `2147483648 as i64` are rejected. Existing
contextual typing of uncast literals is unchanged, and there are no implicit
conversions or promotions. Casts compose in the existing scalar positions, include
constructor payloads whose final payload is i32/bool, and preserve i32/bool-only
wrappers. Exact rules are in the [widening contract](../engineering/m1-widening.md).

Classic for headers may contain only the profile's pure scalar declaration,
assignment (including integer compounds), condition, and post steps. Arrays and repeated initializers use positive
integer literals.

## Evaluation and arithmetic

The [array-length increment](../engineering/m2-array-length.md) adds `NAME.len`
for visible fixed scalar arrays declared in outermost `main`. The exact `usize`
element count is lowered to a scalar constant, including in pure scalar `for`
headers. There is no implicit conversion, property assignment, or method call.
Array parameters, results, borrows, and slices remain outside this increment.

The [lexical-array increment](../engineering/m2-array-scopes.md) also permits
declarations in `main` blocks, branches, loop bodies, and switch arms. Scope exits
and loop transfers release exited arrays in reverse order; return evaluates its
result before releasing all visible arrays. Classic `for` headers and helper
functions still cannot declare arrays. The 16-entry catalog limits declaration
sites rather than cumulative loop executions.

The [whole-array assignment increment](../engineering/m2-array-assignment.md)
adds `DEST = SOURCE;` between visible arrays with exactly matching element types
and lengths. The destination must be mutable. Assignment overwrites its existing
extent and preserves the source, destination shape, and owner identity. A bool
source is fully validated before writing; self-assignment is admitted. RHS array
expressions and classic `for` header assignments remain excluded.

The [private frame foundation](../engineering/m2-array-frames.md) associates each
array catalog entry with one function and keeps array tokens separate across
recursive VM frames. Private helper-local arrays share the same 16-owner table
and payload arena as the entry frame. The later
[helper-local increment](../engineering/m2-array-helpers.md) admits source arrays
in ordinary functions, including those returning shallow wrappers. Explicit
returns and `?` failure paths drop visible arrays after evaluating the return
value; a successful `?` keeps arrays live. Initializer destinations become visible
only after completion. The subsequent [source parameter increment](../engineering/m2-array-parameters.md)
adds immutable exact-shape scalar-array parameters. Arguments are bare array
names; mutable sources are captured before later arguments execute. Each callee
owns an independent by-value copy, and pending captures are cleaned on early exits.

The [array result signature foundation](../engineering/m2-array-result-signatures.md)
recognizes `fn ELEMENT[LENGTH] NAME(...)` for the same six scalar elements and
lengths 1..4096. Compilation rejects every such result declaration with `type`
at its function name before lowering any body or parameter catalog, including
unused and forward helpers. This signature metadata does not enable source
array result execution. `main` remains zero-argument scalar `i32`.
The later [private result increment](../engineering/m2-array-results.md) verifies
result shapes and lifetimes independently and transfers the callee's sole live
owner to an empty caller destination without payload copying. Returning a
parameter preserves its original independent CALL copy. These private paths do
not admit `.brc` array return programs; the source gate remains enabled.

The current scalar CLI implements fixed-width integer `~`, `&`, `^`, and `|`,
and checked `<<` and `>>`. Binary operands, including shift amounts, must have the
same integer type. Signed right shift is arithmetic; unsigned right shift is
logical. Counts outside `0..width-1` and left-shift results outside the operand
range report the existing guest `overflow` outcome. No amount masking or implicit
promotion occurs. The [integer-operator contract](../engineering/m1-integer-operators.md)
owns exact precedence and execution rules.

Operands, arguments, and record initializers are evaluated once in source order.
Logical operators short-circuit. Assignment remains a statement. A classic for
executes its post step on continue and skips it on break.

There is no implicit numeric promotion. In the current M1 slice, context-free
integers are i32. Widening is explicit and value-preserving; no suffix syntax
exists. Narrowing, unsigned negation, and
integer-to-handle coercion are rejected.

add, sub, mul, signed negation, division, remainder, shifts, and lengths are checked
before they can overflow. Unsigned underflow is an overflow failure. Division by
zero is detected before division. Signed division truncates toward zero and its
remainder follows the dividend sign; unsigned division uses unsigned values.

The last executed guest instruction defines the first arithmetic failure. The VM
converts that condition to a guest outcome and terminates the Instance. A guest
failure never becomes a Fairy native trap or a host-process termination.

## Ownership and values

Owned values move as a whole. Buffer and tagged types containing Buffer are
move-only. The VM has no guest garbage collector or guest reference-count cycle.
Normal exits run guest cleanup; trap and cancellation use runtime ledgers only.

A shared loan blocks root mutation, move, and drop. An exclusive loan blocks all
competing access to the same root, even through a different field or index.
Returned borrows come from exactly one input borrow or from Static storage.

Arrays are independent by-value values. Aggregate values become guest-readable
only after every initializer succeeds. Missing fields are not silently zero-filled.
Bool has canonical 0/1 representation, and all published bytes are initialized.

Option and Result use shallow switch handling: .some/.none or .ok/.err. There are
no nested patterns or user enums in the first profile.

## Runtime and lifecycle

Program is immutable and explicitly reusable. Instance is one-shot and owns input,
frames, owners, loans, pending work, grants, and output. Engine is owner-thread bound;
parallel execution uses separate Engines.

The private bytecode has eight-byte typed instructions and an independent verifier.
Verification checks structure, control flow, layout, register initialization,
ownership, root lifetimes, loan origins, selected stores, and metering templates.

All quota checks, including old plus new allocation peaks, happen before allocation.
Preparation, commit, cleanup, and descriptor reclamation count as bounded work.
Guest recursion uses VM frames. Scalar loads create no descriptor objects.

Input is an Instance-owned bounded snapshot. Output is staged and published only on
a successful terminal result. Destroy does not turn a failed operation into success.

## Host and delivery boundary

Host access is denied by default. A typed host request suspends the Instance and
waits for a bounded reply. The reachable requirements must fit declared requirements,
run grants, and the Engine policy ceiling. Policy or catalog paths are not discovered
ambiently from the source folder.

The trusted embed path is a native host in the same process. Arbitrary external source
requires an independently tested restricted Windows worker and parent broker.
Malformed input, unknown fields, duplicate keys, excess depth, and excess bytes are
rejected before publication or adapter dispatch.

## First-profile exclusions

The initial profile excludes user resources, generics, enums, raw pointers, arbitrary
FFI, host dynamic libraries, JIT, guest GC, Map, closures, dynamic text ownership,
external bytecode, and disk runtime code caches.

These are first-profile limits. A later profile change requires dated review,
corpus updates, and appropriate verification.

## Acceptance criteria

1. A clean native build runs a trivial scalar source and exits 0 for normal completion.
2. Guest i32 is reported as data, independent of the CLI process result.
3. Arithmetic boundaries return a guest outcome without terminating the native host.
4. Move, borrow, root conflict, and return-origin violations fail before execution.
5. Quota failure occurs before allocation and reports accounted peak accurately.
6. Output from trap, cancellation, deadline, or internal failure is not published.
7. The restricted level is unavailable until actual Windows isolation tests pass.
8. The embed level is unavailable until an actual DLL export/call test passes.

The experimental M1 slice establishes a native source path for its narrower grammar.
The [tagged receipt](../evidence/m1-tagged-windows-20261023.json) remains historical
verification for the tagged switch slice and its prior scalar/branch/loop
regressions. The propagation receipt is historical at 37 native groups and 510 CLI
cases per profile. The switch-expression receipt is historical at 41 native groups
and 580 CLI cases. The [i64 receipt](../evidence/m1-i64-windows-20261023.json) is
historical and records 49 native groups and 760 CLI cases in each profile. The
[unsigned receipt](../evidence/m1-unsigned-windows-20261023.json) records 59 native
groups and 1,159 CLI cases in both development and release and remains historical.
The [widening receipt](../evidence/m1-widening-windows-20261023.json) records
67 native groups and 1,272 CLI cases in each profile, including 113 widening cases.
The [integer-operator receipt](../evidence/m1-integer-operators-windows-20261023.json)
records 75 native groups and 1,898 CLI cases in each profile, including 626 new cases.
The [arm-statement receipt](../evidence/m1-switch-arm-statements-windows-20261023.json)
records 81 native groups and 1,969 CLI cases in each profile, including 71 new cases.
The [M1 audit](../engineering/m1-checkpoint-audit.md) closes the bounded scalar
checkpoint. Subsequent M2 increments add the scoped arrays, records and scalar
borrows above. They do not establish executable returned references, guest Buffer,
full-profile ownership/accounting, host, isolation or embed criteria. Use the
[remaining-work audit](04-remaining-work.md) and exact dated engineering receipts;
acceptance of this specification and historical totals are not current full-profile
conformance evidence.

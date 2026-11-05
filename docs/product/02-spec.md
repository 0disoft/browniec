# Product Specification

- Status: Accepted for design, 2026-10-23
- Implementation status: Reconciled 2026-11-05; bounded M1 and public M2 aggregate/slice/literal/shared-byte-result subsets; full profile incomplete
- Source profile name: brownie.safe/0.3

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
Buffer storage/leases/scanning have private native evidence but no guest Buffer
execution path. There is no general Engine/Instance API, guest input/output, host
suspension, restricted worker or public DLL.

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
[element-list declaration successor](../engineering/array-list-source.md) adds
`let a=[x,y];` and `let i32[2] a=[x,y];`, with exact scalar types/arity,
left-to-right one-time evaluation and publication after complete initialization.
Direct list arguments, returned literals and list replacement remain separate
source integrations. Broader constructor context and
general aggregate-expression inference remain pending; this is not a full-profile
promotion.

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
still require an expected wrapper type; `?` adds no inference. Exact rules are in
the [propagation contract](../engineering/m1-propagation.md).

The switch-expression increment makes an exhaustive shallow-wrapper switch an
operand. A value arm contains zero or more typed local declarations and plain
assignments followed by one final expression without a semicolon, or `return EXPR;`
for the enclosing function. At least one arm must yield, and all yielding arms use
one exact type. The first yielding arm can infer the result and provide constructor
context; otherwise an expected expression type provides it. Subject evaluation is
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
assignment, condition, and post steps. Arrays and repeated initializers use positive
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

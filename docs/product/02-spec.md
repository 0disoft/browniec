# Product Specification

- Status: Accepted for design, 2026-10-23
- Implementation status: M1 scalar expressions, branches, loops, shallow Option/Result, and switch implemented and verified; scalar `?` propagation implemented and verified; full profile not implemented
- Source profile name: brownie.safe/0.3

## Product boundary

Brownie C runs a small, statically typed source profile on a native JIT-free VM.
The first intended uses are application data validation, byte transforms, and rule
evaluation. These are starting workloads, not proven market requirements.

The native VM reads .brc source. Running a program must not start Go, MSVC, a C
compiler, an interpreter subprocess, or a disk bytecode runtime.

## First source profile

The initial storage and value types are:

- bool, u8, i32, i64, u32, and 64-bit usize;
- scalar arrays with a literal length from 1 to 4096;
- limited acyclic plain structs with scalar or plain-struct fields;
- ref and ref mut borrows, with static ref str and explicit byte views for text;
- Option and Result with scalar, array, struct, Buffer, or shallow tagged payloads;
- move-only brownie::bytes::Buffer and staged output bytes.

Source functions use explicit Fairy-like declarations such as fn Type name.
Modules and imports are explicit. let and var introduce initialized locals.

The experimental M1 increment keeps `fn i32 main()` as the zero-argument entry
point. Other functions and their parameters may use i32 or bool. Bool is canonical
0/1 and never converts implicitly to or from i32. The increment adds `!`, same-type
`==`/`!=`, i32-only ordering, short-circuit `&&`/`||`, `if`/`else if`/`else`,
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
or fallthrough, and switch is a statement rather than an expression. Exact rules are in the
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

Classic for headers may contain only the profile's pure scalar declaration,
assignment, condition, and post steps. Arrays and repeated initializers use positive
integer literals.

## Evaluation and arithmetic

Operands, arguments, and record initializers are evaluated once in source order.
Logical operators short-circuit. Assignment remains a statement. A classic for
executes its post step on continue and skips it on break.

There is no implicit typed numeric promotion. Context-free integers are i32.
Only value-preserving explicit widening is allowed. Narrowing, unsigned negation,
and integer-to-handle coercion are rejected.

add, sub, mul, signed negation, division, remainder, shifts, and lengths are checked
before they can overflow. Signed division by zero is detected before division.
The quotient truncates toward zero and the remainder follows the dividend sign.

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
regressions. The current [propagation receipt](../evidence/m1-propagation-windows-20261023.json)
uses 37 native groups and 510 CLI cases per profile;
propagation verification passed. Full M1, switch expressions, other scalar
types, and Windows isolation remain unimplemented or unverified. The slice does not
satisfy full-profile ownership, allocation, host, isolation, or embed criteria.
Claims require scoped [M1 details](../engineering/m1-scalar-slice.md) and recorded
evidence, not acceptance of this specification alone.

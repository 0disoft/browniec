# M2 Helper-Function Array Locals

- Status: implemented and focused-harness verified in development and release
- Evidence: [Windows helper receipt](../evidence/m2-array-helpers-windows-20261025.json)
- Scope: source-level local fixed scalar arrays in ordinary functions, including
  scalar and shallow `Option`/`Result` return functions
- Integration target: [`compiler.fy`](../../src/compiler.fy),
  [`locals.fy`](../../src/locals.fy), [`ir.fy`](../../src/ir.fy),
  [`propagation.fy`](../../src/propagation.fy), and the independent array
  verifier and VM

This page specifies the helper-local source increment. The private ownership and frame
machinery from the [frame contract](m2-array-frames.md) supplies the execution
basis; the existing [lexical scope rules](m2-array-scopes.md) supply declaration,
cleanup, and control-flow behavior inside each function.

## Source behavior

The existing local array declaration grammar is admitted in every ordinary
function body, including helper functions. `main` remains the zero-argument i32
entry point. Helpers may return a scalar type or a shallow `Option`/`Result`, as
the scalar function contract already allows.

Supported arrays retain the current fixed shapes:

- Element types are `bool`, `u8`, `i32`, `i64`, `u32`, and `usize`.
- Lengths are literals from 1 through 4096.
- `let` and `var` declarations use a repeated scalar initializer.
- A declaration may use an exact-type and exact-length array copy initializer.
- Element reads and writes use an exact `usize` index.
- `NAME.len` is the existing compile-time `usize` length expression.
- Whole-array assignment copies an exact-shape visible source into a mutable
  destination.
- Declarations and operations may appear in nested blocks, loop bodies, and
  switch statement or expression arms under the existing scope rules.

The declaration, copy-initialization, element, length, and whole-assignment
source contracts otherwise apply unchanged. Each initializer runs once before
the new binding becomes visible. A copied array owns independent storage, so
later writes through either binding do not change the other.

No token or grammar production is added. This slice changes which ordinary
function bodies may accept the existing array productions.

## Function ownership and lowering

The local table records the current function ID for all its bindings. The
compiler declares each array through `ir::array_in` for its current function, so
the private `Program.array_functions` catalog map identifies the owning function
of every static declaration site.

Every array instruction in a function must resolve to a catalog entry owned by
that function, and operand-bearing operations must address live bindings of that
function. Copy initialization and whole-array assignment require both source and
destination to belong to the current function. A scalar or wrapper call transfers
no array token: the callee cannot see, copy, assign, or drop a caller's array
through an argument or result.

The independent verifier evaluates each function with only its own arrays in the
live set. A return requires that set to be empty. The entry function has no
privileged access to a helper's arrays, and a helper has no access to entry
arrays.

## Lifetimes and `?` failure

Within a helper, explicit returns, ordinary scope exits, `break`, and `continue`
use the cleanup behavior already implemented for `main`. A normal return
evaluates its scalar or wrapper result first, then emits `ADROP` in reverse
binding order for all visible local arrays, then emits `RETURN`. Scope and loop
transfers drop only the arrays they leave.

The propagation change extends the `?` lowering to receive the current
visible-local table. On the failure path, after the operand has been evaluated
and the enclosing function's declared failure wrapper has been formed, the
lowering emits reverse-order drops for every visible local array before
`RETURN`. The failure wrapper remains available across those drops. The success
path performs no array cleanup and retains its live arrays for the continuation
of the function.

An initializer's destination is not visible until the initializer completes.
If a `?` inside a repeated fill expression fails, cleanup drops arrays visible
before that declaration and does not drop the unpublished destination. After a
successful initialization, the new binding is visible to later exits and `?`
failure paths.

## Frames and resources

Recursion and mutual recursion preserve suspended parent arrays through the
existing private frame machinery. Each active function frame accesses its own
token slots, so a child's array operations cannot overwrite a parent's live
tokens. Parent arrays remain live across the child call and resume with the
parent frame.

The following capacities remain program-wide:

- 16 static array declaration sites in the catalog
- 16 shared live runtime owner slots
- 32 bounded guest frames
- one shared payload arena, 65,536 bytes by default

Function ownership does not multiply any of these capacities. In particular,
recursive activations do not create additional owner or payload tables.

Array operation costs are unchanged by this slice; the [frame contract](m2-array-frames.md)
retains the current per-operation Fuel schedule. Existing array result profiles
and the `browniec.result/v1` schema remain unchanged. No profile name or result
field is added.

Each executed cleanup `ADROP` costs 49 Fuel. A failing `?` with K visible arrays
therefore charges 49K for those drops before its return; the success path does
not execute them. The one-element i32 helper fixture passes with a four-byte
arena and 164 Fuel, and fails at 163. With the standard CLI arena, the boundary
is 65,696 versus 65,695. These are resource-contract checks, not performance
measurements.

## Source example

The helper initializes and updates its own array before returning a scalar:

```brownie
module main;

fn i32 shifted_sum(i32 seed) {
    var i32[2] values = [seed; 2];
    values[1] = 22;
    return values[0] + values[1];
}

fn i32 main() {
    return shifted_sum(20);
}
```

The helper initializes and writes a function-local array, then returns the scalar
sum 42. The same declaration, element, drop, and frame rules apply to helpers
returning `Option` or `Result`; their `?` failure path additionally uses the
visible-local cleanup described above.

## Excluded forms

This slice does not admit:

- arrays whose element type is `Option`, `Result`, or another wrapper
- array parameters or array return values
- `ref`, borrow, or slice forms for arrays
- array declarations or array operations in a classic `for` header
- calls to `main` in any program with an array catalog entry

The source call rejection for `main` remains program-wide and applies even when
the call appears in a function that is never executed. Calls between ordinary
scalar-returning or shallow-wrapper-returning helper functions remain available.

The slice adds no opcode, token, or grammar production and exposes no public
bytecode. Helper arrays use the existing private array instructions and frame
tokens.

## Staged next work: by-value array parameters

The next staged source feature is exact-shape, immutable by-value array
parameters. It is not part of this helper-local slice and is not yet admitted by
the parser.

In that later stage, the parameter's element type and length must exactly match
the argument. Each call receives an independent copy instead of a caller token.
The caller evaluates and captures each argument exactly once, from left to right,
before later argument effects can change a captured value. A failed copy must
roll back every partial copy and owner mutation before rejecting the call. Arena
peak accounting must include both the old and new payload extents. Array results,
borrows, and slices remain separate later work.

## Verification

The focused commands are:

```powershell
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice helpers
python -B tools/record-m2-array-write-evidence.py --slice helpers --scalar-regression
```

Per development/release profile, the harness passed 16 native groups: six
helper-array groups, six existing read-source groups, and four existing scalar
propagation groups. It also passed 426 array CLI cases: 67 reads, 61 writes,
58 copies, 40 lengths, 44 scopes, 59 assignments, and 97 helper cases. The
recorder also passed 1,969 scalar CLI cases per profile on those same binaries.

The helper checks cover all six element types and scalar returns, all six shallow
wrapper types, success/failure propagation, helper-owned declarations and copies,
reads, writes, lengths, whole assignment, scopes, loops and switch arms, recursive
and mutually recursive parents, and shared owner/payload/frame limits. They check
that early propagation skips unpublished initialization and pending writes, and
that removing failure-path cleanup makes independent verification fail. Each CLI
subprocess runs with a tool-free `PATH`; this is not isolation evidence.

IR, independent verifier, VM, codec, layout, and storage source identities match
the prior frame receipt. The compiler, local table, array source helpers, and
propagation lowering receive fresh native source and CLI checks. The full
84-group scalar native suite, M0/private-array-unit reruns, allocator
instrumentation, Linux execution, isolation, DLL, and performance checks are
skipped.

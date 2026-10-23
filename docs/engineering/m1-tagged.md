# M1 Shallow Option, Result, and switch

- Status: implemented and verified on Windows; historical after the propagation, switch-expression, and i64 increments; 33 native groups and 423 CLI cases in each development and release profile
- Scope: one-level Option/Result values and exhaustive switch statements in `brownie.m1-scalar/1`

This increment extends the scalar, branch, and loop slice with shallow tagged
values. It admits `Option<i32>`, `Option<bool>`, and `Result<T, E>` where each of
`T` and `E` is i32 or bool. Wrapper depth is exactly one: nested wrappers and
aggregate wrappers are rejected. Later nested-depth and struct-depth budgets are
separate obligations.

`main` remains a zero-argument i32 function. This historical slice defines switch
statements, not expression-position arms, and does not define arbitrary user enums,
arrays, structs, or the full `brownie.safe/0.3` profile. The successor
[propagation contract](m1-propagation.md) adds postfix `?`; the later
[switch-expression contract](m1-switch-expressions.md) adds exhaustive arms as
operands.

## Values and constructors

The admitted scalar and wrapper type IDs are:

| ID | Type |
| --- | --- |
| 1 | i32 |
| 2 | bool |
| 3 | Option<i32> |
| 4 | Option<bool> |
| 5 | Result<i32, i32> |
| 6 | Result<i32, bool> |
| 7 | Result<bool, i32> |
| 8 | Result<bool, bool> |

Constructors are `.some(EXPR)`, `.none`, `.ok(EXPR)`, and `.err(EXPR)`.
The expected wrapper type supplies the context: a typed initializer, assignment,
function parameter, or return type. Parentheses preserve that context. A
constructor without a compatible expected type is rejected. `EXPR` must match
the active i32/bool payload type; there are no integer-to-bool conversions.

```text
let Option<i32> present = .some(42);
let Option<i32> absent = .none;
let Result<bool, i32> accepted = .ok(true);
let Result<bool, i32> rejected = .err(-1);
```

Plain wrapper values copy by value through `let`, `var`, function parameters,
VM frames, and loop iterations. Wrapper values are not compared, ordered, or used
in arithmetic. `for` headers remain pure scalar, so a wrapper init or post is
rejected and a wrapper cannot satisfy the bool condition. Wrapper values may be
used in `while` and `for` bodies.

## Switch statements

`switch` is a statement, not an expression. Its subject is an Option or Result:

```text
switch (SUBJECT) {
    case .some(name): { ... }
    case .none: { ... }
}

switch (SUBJECT) {
    case .ok(name): { ... }
    case .err(name): { ... }
}
```

Both variants must appear exactly once in either order. A variable case binds its
scalar payload in an immutable block scope. `_` discards the payload. A currently
visible local or parameter cannot be redeclared by a case binding. There is no
default arm, nested pattern, or fallthrough in these statement arms. Switch
expressions are owned by the successor contract.
`?` is owned by the successor [propagation contract](m1-propagation.md).

The subject is evaluated once. A mutable local subject is loaded as a snapshot
before matching, so later storage updates do not change the selected payload.
`return`, `break`, and `continue` are allowed inside arms; each transfer keeps its
nearest lexical-loop or function meaning. If both exhaustive arms are terminal,
the switch is terminal and following code is rejected as unreachable. Otherwise
the arms join at a continuation.

## Private representation

Each wrapper occupies one i64 cell. It encodes the active scalar payload as
`payload * 2 + variant`, where variant 1 means some/ok and variant 0 means none/err.
`none` is exactly 0. A payload-bearing wrapper's value is decoded after selecting
the variant; the implementation subtracts the variant before signed division by
two so negative odd encodings decode without truncation errors.

Wrapper registers and slots use the same 128-cell register budget as i32, bool,
and short-circuit values. There is no separate VM tag array or hidden wrapper
allocation. A wrapper parameter or local still occupies one bounded cell.

## IR and verifier

Instructions remain eight bytes; `CASE` uses byte 4 for its mismatch target
instead of a reserved zero. The new opcodes are:

| Opcode | Name | Encoding and effect |
| --- | --- | --- |
| 23 | `MAKE` | `23,dst,payload-or-0,variant,0,0,0,0` |
| 24 | `CASE` | `24,dst-payload-or-0,subject,variant,forward-mismatch-pc,0,0,0` |
| 25 | `MATCH_FAIL` | `25,0,0,0,0,0,0,0` |

`MAKE` materializes one wrapper value. `CASE` atomically tests the subject's
variant. A mismatch branches to the forward mismatch target without defining the
payload destination. A match falls through and defines the scalar payload; a
payload-free case uses destination 0. There is no unguarded `UNWRAP` opcode.

The verifier checks exact wrapper type IDs, variant/payload correspondence, forward
CASE targets, reserved bytes, and definite initialization only on the matching
path. The source checker admits exactly two exhaustive arms, and ordinary fallthrough
jumps past the terminal fallback. That fallback is opcode 25 and maps to internal
verification error kind 5 / process exit 6. Valid typed source cannot reach it;
source exhaustiveness is not claimed as an IR-wide policy proof.

## Limits, Fuel, and evidence

The existing limits remain unchanged: 4096 source bytes, 1024 tokens, structural
parser depth 32, expression depth 32, loop depth 32, 128 register cells including
wrapper, `var`, and short-circuit slots, 256 instructions, 16 functions, 8
arguments, 32 call sites, 32 VM frames, and 64 simultaneously visible bindings.
Switch nesting counts toward structural parser depth.

Every executed `MAKE`, `CASE`, and `MATCH_FAIL` costs one Fuel. `CALL` remains one
Fuel plus its argument count because a wrapper parameter occupies one cell.

`check` verifies a tagged program without executing it; `run` uses the same
validation before execution. The result framing is unchanged. The example returns
42 at the default Fuel limit:

```powershell
./build/browniec.exe run examples/tagged.brc --json
```

The historical [tagged receipt](../evidence/m1-tagged-windows-20261023.json) records
33 native groups and 423 black-box CLI cases for each development
and release profile, with compiler, source, artifact, and harness identities. It
covers constructors and context, wrapper copying and calls, depth-one rejection,
switch exhaustiveness and arm order, `_` binding, subject-once and snapshot
behavior, terminal joins, type/IR corruption, `CASE` initialization, and Fuel.
The loop and branch receipts are historical after this increment.

The [propagation contract](m1-propagation.md) owns postfix `?` for shallow scalar
wrappers, and the [switch-expression contract](m1-switch-expressions.md) owns
expression-position exhaustive arms. Both later slices are verified; the current
switch-expression receipt is historical at 41 native groups and 580 CLI cases. The
current [i64 contract](m1-i64.md) records 49 native groups and 760 CLI cases per
profile. Full M1 still needs remaining scalar types and richer value-arm statements. The full
profile, Windows isolation, DLL ABI, and performance targets remain unverified.

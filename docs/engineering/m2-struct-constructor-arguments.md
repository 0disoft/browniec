# M2 Exact-Nominal Record Constructor Arguments

- Status: implemented at `bd9db83fed8180b3b24cea29523c9faf66d44aeb`; verified in
  development and release.
- Scope: a bare exact-nominal constructor as an argument to an immutable record
  formal, such as `take(P { .x = 42 })`.
- Implementation: [`compiler::record_argument`](../../src/compiler.fy), the
  shared constructor staging in [`compiler.fy`](../../src/compiler.fy), and
  constructor syntax validation in
  [`struct_value_source`](../../src/struct_value_source.fy).
- Predecessors: [source record parameters](m2-struct-parameters-source.md),
  [record result arguments](m2-struct-result-arguments.md), and [record path
  arguments](m2-struct-path-arguments.md).
- Focused fixture: [constructor argument cases](../../tests/m2/struct_constructor_arguments.fy).
- Harness: [verify-m2-struct-constructor-arguments.py](../../tools/verify-m2-struct-constructor-arguments.py)
  with `--profile development` or `--profile release`.
- Evidence: [Windows receipt](../evidence/m2-struct-constructor-arguments-windows-20261028.json).

This slice lets a constructor at a call boundary satisfy a by-value record
formal without first declaring a named temporary. It reuses constructor
staging, the existing record CALL transaction, anonymous immutable captures,
and the shared mixed-capture cleanup. It does not create a general aggregate
expression.

```brownie
module main;

struct P { i32 x; }

fn i32 take(P p) {
    return p.x;
}

fn i32 main() {
    return take(P { .x = 42 }); // 42
}
```

## Detection and accepted form

For an exact-nominal record formal, `record_argument` inspects an identifier and
peeks at the following token. An identifier followed by `{` selects the
constructor branch. That branch uses `record_values::constructor` to require
the constructor's type to have the exact nominal identity of the formal and to
consume the type-name and `{` prefix before any field expression is lowered.
Structural layout equality is insufficient; another nominal type with the same
fields remains a compile-time type error.

The argument is a bare constructor operand. Existing record-argument forms
remain available in the same position:

- a visible exact-nominal binding, such as `take(p)`;
- a bare exact-nominal result call, such as `take(make())`, including nested
  result calls;
- an exact-nominal child path, such as `take(outer.child)`.

After a successful constructor, the next token must be the argument comma or the
outer call's closing parenthesis. The delimiter is validated before any record
owner is published and is left unconsumed for the outer argument loop.

## Shared constructor staging

`compiler::record_argument` calls `record_constructor_value` with
`argument = true`. The existing `record_constructor` wrapper delegates to the
same function with `argument = false`, so declarations, root replacement, child
replacement, and direct constructor returns retain their semicolon contract.
The only delimiter difference is:

- `argument = false` consumes the terminating semicolon exactly as before;
- `argument = true` requires a comma or `)` and leaves it unconsumed for the
  outer call.

Field lowering is shared. The constructor allocates up to sixteen scalar staging
slots, visits every field exactly once in declaration order, and evaluates each
field expression in its declared scalar context. Nested constructors follow the
existing traversal. Child bindings, child paths, and exact-nominal child call
results use the old staging rules.

A child call returns through the existing record-result CALL transaction. Its
scalar leaves are copied into the parent's staging slots, and its anonymous
child result is dropped before the next sibling field evaluates. The parent
constructor has no owner or catalog site while field calls and their other
effects run.

Once the last field and the argument delimiter have passed validation, the
lowering emits the consecutive scalar `LOAD` operations. `record_argument` then
allocates one immutable, function-owned anonymous site with `ir::record_in` and
publishes it with `SINIT`. The anonymous capture has an empty source span, so a
guest name cannot refer to it. No parent owner or site is allocated until field
evaluation and delimiter handling finish.

## Evaluation, capture, and cleanup

Fields evaluate left to right. A constructor at one argument position is
complete before the next argument starts, so later arguments observe its field
effects. Effects are not rolled back. The newly constructed argument is then an
independent immutable value; later arguments may mutate source bindings without
changing it.

Pending constructor state is absent from the caller's names and ownership
snapshots until `SINIT` and anonymous declaration finish. An early `return`,
question-mark propagation, `break`, or `continue` during field evaluation
therefore cannot try to drop a site that does not exist. Captures already
visible from earlier arguments participate in the normal mixed cleanup for
those transfers. An inner loop's transfer preserves captures belonging to the
enclosing argument expression under the existing loop rules.

On normal completion, the outer CALL copies the anonymous immutable argument
into the callee's immutable by-value formal through the existing CALL
transaction. After the call returns, the shared reverse mixed cleanup drops
already visible array and record captures, including the anonymous constructor
argument.

The constructor form produces byte-equivalent IR to the explicit named form:

```brownie
return take(P { .x = 42 });
```

```brownie
let P p = P { .x = 42 };
return take(p);
```

No VM dispatch, opcode, Fuel price, profile string, or version field changes.

## Ownership and resources

Scalar staging slots use the existing function-local register storage. The record
argument's owner allocation is deferred until the complete constructor and its
delimiter are valid. This preserves the existing early-exit behavior without
adding a second staging record.

The existing bounds remain unchanged:

- 16 static record sites and 16 shared owners;
- 16 scalar leaves and 128 planned bytes per selected source root;
- 32 VM frames, eight arguments per call, 128 registers, and 256 instructions.

The direct case has one anonymous argument and one immutable formal. A four-byte
constructor argument plus a four-byte formal requires eight payload bytes at
their overlap; a limit of seven fails with the existing quota error. Other
captures, locals, or arguments can raise peak use through the existing
transaction checks. No allocation or performance measurement is claimed by this
slice.

## Rejected forms

The following remain compile-time errors in a record argument position:

- a constructor with the wrong nominal type, including a layout-compatible
  type;
- a parenthesized constructor, such as `take((P { .x = 42 }))`;
- a field selected from a constructor literal, such as
  `take(P { .x = 42 }.x)`;
- casts or equality expressions built around a constructor;
- unknown fields, duplicate or reordered fields, mismatched field types, and an
  unknown constructor type;
- a constructor supplied to a scalar formal;
- writes through the callee's formal and other immutable-formal misuse;
- a wrong argument count or malformed argument delimiter.

These checks do not add parenthesized or general aggregate expressions, record
borrows, `ref`/`var` record parameters, or call-result field selection.

## Verification

The focused native fixture contains six test groups, fifteen successful
programs, and twelve compile-time type rejections. It covers forward calls,
nested constructors, all scalar kinds and extrema, declaration-order field
effects, exact-nominal child calls, mixed array/record/scalar arguments,
array-returning and wrapper-returning consumers, early scalar and record exits,
question-mark propagation, loop transfers, and preservation of an enclosing
capture by an inner loop.

The fixture also compares direct-constructor IR with the named `let` form,
checks independent verifier rejection after mutating the anonymous argument's
cleanup, and probes the eight-versus-seven payload boundary. Additional
early-return probes require zero payload bytes when a pending constructor exits
before publication, and four bytes when a child-result field has already been
staged before a later field exits.

The new CLI selection has 154 cases:

- 27 fixture programs through both `check` and `run` (54 cases);
- 48 scalar-boundary programs through both commands (96 cases);
- two static-site programs through both commands (four cases).

Static case 15 passes `check` with repeated constructor arguments and reports
exhaustion of the CLI's 1,000,000 Fuel allowance during `run`. Static case 16
adds another constructor after one formal plus fifteen anonymous argument sites
have used the 16-site budget, so it reports `compile_limit`.

Development and release each passed 26 native groups: six new
constructor-argument, eight source-parameter, six constructor-return, and six
constructor child-call groups. Each profile also passed 874 CLI cases: 154 new,
114 source-parameter, 154 result-argument, 154 path-argument, 144
constructor-return, and 154 child-call cases.

These were two combined focused profile invocations. Development ran from
baseline `e5926af` with the implementation files uncommitted; release ran after
implementation commit `bd9db83`. Both invocations rechecked the same 220 input
hashes and matching compiler/SDK identities. Both retained executable hashes
were confirmed against their CLI receipts before archival. Earlier receipts
remain historical for their original inputs.

The focused slice does not cover full native or CLI suites, M0, Linux, process
isolation, DLL embedding, packaging, allocation instrumentation, or
performance.

## Compatibility with earlier evidence

The source-parameter, result-argument, and path-argument fixtures formerly used
the now-valid bare constructor as a negative case. They now reject
`take((P { .x = 42 }))`; this keeps their case counts unchanged while preserving
rejection of unsupported parenthesized aggregate expressions. Those older
matrices were run before the new native harness. Their earlier receipts remain historical for their original
inputs, and this successor records fresh evidence for the compiler and fixture
hashes it changes.

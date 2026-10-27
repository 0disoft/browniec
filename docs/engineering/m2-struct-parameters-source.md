# M2 Source Record Parameters

- Status: implemented at `d0ca7e7`; verified in development and release.
- Scope: immutable nominal record parameters with bare record-binding arguments
  and existing VM calls.
- Implementation: [record parameter lowering](../../src/struct_call_source.fy),
  [call and body integration](../../src/compiler.fy),
  and [array argument capture](../../src/array_call_source.fy).
- Reused paths: [existing lexical cleanup](../../src/array_source.fy) and the
  existing array-result finisher already handle record bindings; this slice
  adds no cleanup implementation.
- Related contracts: [record parameter signatures](m2-struct-parameter-signatures.md),
  [record parameter IR](m2-struct-parameters-ir.md), and
  [record call execution](m2-struct-call-vm.md).
- Focused tests: [source parameter cases](../../tests/m2/struct_parameters_source.fy)
  and updated [signature cases](../../tests/m2/struct_parameter_signatures.fy).
- Verification: 51 native groups and 2,318 CLI cases per development/release
  profile, split into separate core and regression runs.

The source compiler now admits an immutable record parameter declared with a
bare nominal type. A call argument for that formal must be a bare visible
record binding of the same nominal type. The parameter is passed by value and
uses the existing private CALL transaction, record owner table, payload arena,
verifier, and metered VM.

```brownie
module main;
struct Pair { i32 x; i32 y; }

fn i32 sum(Pair pair) {
    return pair.x + pair.y;
}

fn i32 main() {
    let Pair pair = Pair { .x = 20, .y = 22 };
    return sum(pair);
}
```

The example shows the accepted source shape.

## Argument surface

An argument for a record formal is exactly one identifier such as `pair`. The
capture checks that its lexical table entry names an immutable or mutable record
owner of the callee-declared nominal type in the current function. The token
after the identifier must be a comma or the closing parenthesis.

Constructors, field paths, parenthesized names, casts, aggregate literals, and
general expressions cannot satisfy a record parameter. Arrays and wrappers of
records remain outside the source signature grammar. Scalar and array
parameters may still share the same eight-position argument list.

Record formals and their callee bindings are immutable. A mutable source binding
may be passed, but its value becomes an immutable callee parameter. Writes
through the formal, whole-record assignment to it, and replacement of it remain
rejected by the existing verifier. Record results, borrows, `ref` parameters,
and `var` parameters are unsupported.

## Site predeclaration

Function signatures are scanned before aggregate preparation. Array parameter
and result catalogs are prepared first, struct declarations and layouts are
checked, and then every record formal receives a static record site before any
function body is lowered. The preparation walks functions and formals in order,
validates each selected record's source leaf count, and calls `ir::record_in`
with the owning function and an immutable site. Unused helpers count because
their sites are reserved at this stage.

The existing 128-byte `u8[128] record_parameters` register metadata remains the
record-placeholder metadata. The 128-byte signature array
`param_records` continues to store a nominal record ID plus one. There is no
additional 128-byte signature-to-site map.

When a body binds a record formal, it computes that formal's record ordinal by
scanning the earlier `param_records` positions of the owning function. It then
walks the predeclared record sites owned by that function and selects the site
at the same ordinal. This preserves the preparation order and avoids a second
site table.

The formal still consumes its existing argument-order scalar register position.
That register is a placeholder: `record_parameters[register]` stores the site ID
plus one, while `types` and `array_parameters` stay zero. The source name is
declared in the lexical table with the record binding token `144 + site`.
Scalar operand checks reject the placeholder as a scalar value; record reads,
copies, drops, and calls resolve through the record token.

## Evaluation and snapshots

Call arguments are lowered from left to right. An immutable record binding is
already a stable source for the argument's position. If the visible binding is
mutable, lowering copies it with `SCOPY` into a new immutable caller-owned site
before the next argument is evaluated. The copy is recorded in the private
lexical snapshot as an anonymous binding whose empty source span cannot match a
guest identifier.

This caller capture freezes the value at the point where the record argument is
evaluated. A later argument may write the original mutable binding without
changing the pending argument. The final CALL then copies the captured value
again into the callee parameter; it does not alias the caller capture.

For an immutable argument, the CALL uses the visible record token directly and
the existing aggregate-copy transaction creates the callee owner. For either
kind of argument, record inputs are encoded as `144 + site`. The existing CALL
cost and mixed array/record copy preflight run before child-frame publication.
No source-only copy opcode or Fuel charge is introduced. A quota, late bool,
token, or ownership failure follows the existing atomic call failure behavior;
external effects from earlier statements are not rolled back.

## Cleanup

`array_source::release_from` is the shared reverse-order lexical cleanup path for
arrays and records. The record-aware implementation predates this slice; it
already emitted `SDROP` for record bindings and the array-result finisher already
dropped visible records before `ARET`. This slice reuses both paths and makes no
new cleanup change.

The helper covers normal CALL completion, lexical block exits, scalar returns,
question-mark propagation, and `break` or `continue` transfers. A scalar return
drops every visible formal, including a record formal, before `RET`. An array
return keeps the selected result owner and drops every other visible record,
including record formals, before `ARET`. No path returns a record; record results
remain unsupported.

For a call, cleanup runs over the private argument lexical snapshot after CALL.
A mutable argument's `SCOPY` capture is dropped there, while bindings visible
before the call remain live. Nested calls clean only their own captures. Early
returns and loop transfers that leave an argument's lexical lifetime also drop
pending captures.

Both paths use the existing `SDROP` opcode and charge.

## Profiles and version

The former pre-lowering rejection of every record-parameter declaration is gone.
Record formal placeholders reach independent verification and the existing
record-call VM. The existing record profile selection in `array_source::profile`
continues to choose the read, write, copy, or nested profile from the lowered
record bindings, layouts, and opcodes. This slice adds no new profile.

`--version --json` adds the boolean field `struct_parameters` with value `true`.
Existing profile strings and the other capability fields remain unchanged.

## Bounds and unchanged runtime

The source and runtime budgets remain:

- 16 scalar leaves in a selected record root;
- 128 planned bytes in each selected record root;
- 16 static record sites and the same 16 shared owner descriptors;
- eight arguments per call and 32 VM frames.

Each record formal consumes one static site during signature preparation, even
if the formal is unused. A mutable actual consumes an extra site and owner for
its caller capture. At a call, the original or capture plus the callee copy can
be live together, so peak owner and payload use is checked by the existing
transaction rather than hidden or expanded.

No opcode, Fuel charge, owner slot, payload cap, frame limit, or record result
form is added. Record parameters remain by-value, immutable, nominal, and
non-borrowed.

## Verification

Executed separately:

```text
python -B tools/verify-m2-struct-parameters-source.py --phase core
python -B tools/verify-m2-struct-parameters-source.py --phase regressions
```

Development and release each passed 51 unique native groups and 2,318 CLI cases. The [core receipt](../evidence/m2-struct-parameters-source-core-windows-20261028.json) records 14 native groups and 180 CLI cases; the [regression receipt](../evidence/m2-struct-parameters-source-regressions-windows-20261028.json) records 37 native groups and 2,138 CLI cases. The CLI selections comprise 114 source parameter, 66 signature, 80 array parameter, 89 helper-local record and 1,969 M1 cases per profile. These are two separate phase runs with disjoint native selections, matching profiles, and identical 206 input hashes, compiler and SDK identities; all inputs were rechecked before archival. Native stress tests use 16,000,000 Fuel; the CLI retains its 1,000,000 ceiling, with four costly fixtures expected to pass `check` and report `fuel` on `run`. Other native/CLI matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.

Core covers source records, nominal signatures, snapshots before argument side
effects, recursion, nested calls, mixed scalar/array/record parameters, array
results, early returns, propagation, and loop transfers. Regressions include five
struct declaration groups and the existing array parameter, helper-local record,
function IR, record-call VM, and scalar-function groups. Rejection cases include
mismatched nominal types, parameter writes, constructors, paths, parenthesized
arguments, borrows, record results, arity errors, and static site exhaustion.

The receipts retain their original baseline commit and exact executed commands;
implementation is committed at `d0ca7e7`. The final release CLI hash was checked
against its report. Earlier receipts are historical for changed source, fixture,
root-lock, and harness inputs. No additional combined aggregate was run.

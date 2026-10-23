# M1 Shallow Scalar `?` Propagation

- Status: implemented and verified on Windows; historical after the switch-expression increment; 37 native groups and 510 CLI cases in each development and release profile
- Scope: postfix `?` on one-level Option/Result values in `brownie.m1-scalar/1`

This increment adds `expr?` to the existing scalar, branch, loop, and shallow tagged
slice. It admits `Option<i32>`, `Option<bool>`, and
`Result<T, E>` where `T` and `E` are i32 or bool. Wrapper depth is still one:
nested wrappers, aggregate payloads, other scalar types, and host effects remain
outside this increment. The successor [switch-expression contract](m1-switch-expressions.md)
adds exhaustive shallow-wrapper switches as operands.

## Types and propagation

The operand is evaluated exactly once. On success, `expr?` yields the scalar
payload for use by the surrounding expression. On failure, it returns from the
enclosing function with that function's declared wrapper failure value.

| Operand | Enclosing function return | Success | Failure |
| --- | --- | --- | --- |
| `Option<S>` | `Option<T>` | `S` payload | return `.none` |
| `Result<S, E>` | `Result<T, E>` | `S` payload | return `.err(E payload)` |

`S` and `T` may differ. For Result, the success types may differ but the error type
must match exactly; there is no conversion or widening of an error. An Option
operand cannot propagate through a Result-returning function, and a Result operand
cannot propagate through an Option-returning function.

Every `?` needs an enclosing Option or Result return type. A function returning i32
or bool rejects it, including `main`. The compiler carries the declared function
return type separately from the expected type of the surrounding expression. The
expected expression type checks the scalar success payload; it does not choose the
wrapper used for failure propagation.

`?` is postfix and binds tighter than unary or binary operators. `-value?` means
`-(value?)`, and `value? + 1` means `(value?) + 1`. Parentheses remain available
for grouping. A second `?` cannot be applied to the scalar payload because nested
wrappers are not admitted.

Bare constructors keep their existing rule: an expected wrapper context must supply
their type. `?` introduces no constructor inference and no new wrapper inference.

## Placement and short-circuiting

`?` may appear in an expression in a wrapper-returning function, including:

- while conditions and loop bodies;
- local initializers and assignment right sides;
- constructor payloads;
- call arguments; and
- return expressions.

All three classic `for` header clauses remain pure scalar and reject `?` and switch
expressions. The compiler also retains the existing rule against standalone
expression statements.

An unevaluated `?` performs no work. A short-circuited right operand and an unselected
conditional branch therefore skip their `?`. A failure that is evaluated returns
immediately: later work in the same expression, later call arguments, the rest of
the loop body, the `for` post step, and later loop iterations do not run.

## Lowering and verification

Propagation uses the existing `CASE`, `JUMP`, `MAKE`, `RETURN`, and
`MATCH_FAIL` opcodes. No VM opcode is added.

For a successful Option or Result:

1. `CASE` selects the some or ok variant and defines the scalar payload.
2. `JUMP` continues after the failure path.

For a failure:

1. The first `CASE` selects some/ok; a mismatch targets the failure case.
2. `CASE` selects none/err and defines an err payload when present.
3. `MAKE` builds the enclosing function's declared return wrapper.
4. `RETURN` leaves the function.

If the none/err case does not match the operand, its negative `CASE` targets
`MATCH_FAIL`. The verifier retains its existing checks for CASE targets,
initialization of the success path, wrapper types, variants, and the unreachable
internal fallback.

A successful propagation costs two Fuel for `CASE` plus `JUMP`. A failed
propagation costs four Fuel for `CASE`, the failure `CASE`, `MAKE`, and
`RETURN`. These counts exclude computation of the operand and use of the successful
payload by the surrounding expression. Skipped propagation and outer work cost
nothing.

All existing source, token, instruction, register, depth, binding, function,
argument, call-site, and frame limits remain unchanged. A wrapper still occupies
one i64 register cell.

## Example and evidence

```powershell
./build/browniec.exe run examples/propagation.brc --json
```

The example uses `Option<i32>` in the `Option<bool>` function `positive`, then
combines two `Result<i32, bool>` values in `add`. Its successful path returns 42.

The propagation receipt is
[m1-propagation-windows-20261023.json](../evidence/m1-propagation-windows-20261023.json).
It records 37 native groups and 510 black-box CLI
cases for each development and release profile and is historical after the
switch-expression increment. The tagged receipt's 33 native groups and 423 CLI
cases remain the historical record for the preceding tagged slice. The current
[switch-expression receipt](../evidence/m1-switch-expressions-windows-20261023.json)
records 41 native groups and 580 CLI cases in each profile.

This contract does not establish full M1, other scalar types, richer value-arm
statements, Windows isolation, the DLL ABI, clean-machine packaging, or performance
results.

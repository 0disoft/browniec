# M2 Direct Record Return Calls

Implemented at `c23e6e4`, extending the [named source-result subset](m2-struct-result-source.md).

```brownie
module main;
struct Point { i32 x; }
fn Point make() { let Point p = Point { .x = 42 }; return p; }
fn Point forward() { return make(); }
fn i32 main() { let Point p = forward(); return p.x; }
```

## Source contract and lowering

The return operand may be a function identifier followed by its argument list
and `;`. That identifier must not name a visible local binding. The callee must
return the exact nominal record type declared by the enclosing function.
Forward and mutual calls use the predeclared function and result catalogs.

The compiler reserves one dead, immutable function-owned destination site before
argument evaluation. The site is not entered in the local binding table, so it
remains invisible while arguments are evaluated. The existing `call_value`
evaluates scalar, array, and record arguments from left to right and captures
mutable aggregates before evaluating later arguments. After CALL, the same
helper releases argument captures. The shared record-result finisher then drops
every other visible mixed array and record in reverse lexical order and emits
`SRET` for the anonymous result.

Argument expressions may themselves return a record or leave an enclosing loop.
Cleanup releases only live bindings/captures; the pending destination is never
dropped. An inner loop preserves captures belonging to the surrounding call.
No record-result `?` propagation, constructor return, parenthesized call return,
field access on a returned call, aggregate expression, scalar/wrapper use or
assignment to an existing record is added.

## Ownership, limits and Fuel

The existing CALL/SRET VM transfers the result owner without allocating another
owner or payload extent. A forwarding factory with a four-byte record succeeds
with a four-byte payload limit. By-value arguments still require their existing
independent copies. Ordinary frames, sixteen static record sites and owners,
32 call sites, 32 VM frames, and existing source/IR limits are unchanged. Each
static direct call reserves a site, including calls reached through recursion,
and recursive invocations use separate frame-local tokens for that site.

No opcode, Fuel price, profile, or version field changes. The simple named and
direct forwarding fixtures emit identical instruction bytes and have the same
exact runtime boundary: 171,728 Fuel succeeds with a four-byte payload arena,
while 171,727 fails. Recursive forwarding uses ordinary frames and SRET
Fuel. The 30-recursion fixture succeeds natively with 16,000,000 Fuel and four
payload bytes but exhausts the CLI's 1,000,000 Fuel ceiling; the next frame
reports the existing frame-limit error.

## Verification

Six new native groups cover forward/nested values and scalar extrema, mixed
captures, early exits and loops, recursive/mutual forwarding, exact IR/Fuel, and
rejected forms. Existing regression selections are eight named source-result
groups and four direct array-return groups. The CLI selects 152 direct record,
166 named record, 70 result-signature and 117 direct array-return cases (505).

Commands:

```sh
python -B tools/verify-m2-struct-return-calls.py --phase core --profile development
python -B tools/verify-m2-struct-return-calls.py --phase regressions --profile development
python -B tools/verify-m2-struct-return-calls.py --phase core --profile release
python -B tools/verify-m2-struct-return-calls.py --phase regressions --profile release
```

Development core was first executed directly with `fairyc test --native
--capture-output --json --locked --file tests/m2/struct_return_calls.fy` before
the harness was written. The harness covers development core, development
regressions, release core, and release regressions. These are four separate phase
invocations, not one aggregate run.
The [Windows receipt](../evidence/m2-struct-return-calls-windows-20261028.json)
records the four harness phases and notes the earlier direct run separately;
the earlier run does not contribute to the archived totals.

Development and release each passed 18 native groups and 505 CLI cases. All four
phases share 196 matching rechecked input hashes and the same compiler/SDK
identities. Both CLI artifact hashes were checked against retained binaries.
The earlier named-result receipt is historical for its
changed compiler, fixture, and harness inputs. The focused selection does not
cover full native or CLI suites, M0, Linux, isolation, DLL, packaging, allocation
instrumentation, or performance.

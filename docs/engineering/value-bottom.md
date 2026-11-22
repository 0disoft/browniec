# Terminal value expressions

Private retained-value source now distinguishes a terminal expression (bottom)
from an ordinary void call. An `if` or exhaustive Option/Result switch whose
every arm returns, breaks or continues produces no value on any continuing edge.

```c
module main;
fn i32 main() {
    return if (true) { return 42; } else { return 0; };
}
```

Both branch returns execute directly. There is no join destination, capture,
read or outer RETURN to execute after them. Bottom is compiler control metadata,
not a guest slot, runtime value, public type declaration or new instruction.

## Supported composition

An explicit `Value.bottom` bit is separate from `Value.nothing`. Expected-type
checking accepts bottom in scalar, owning and shared-view contexts; ordinary
capture, scalar conversion, publication and discard helpers reject it so no
consumer can manufacture a value from a terminal edge.

Return, declaration, assignment, explicit discard and value-arm tails propagate
terminal control. Declarations create no binding; assignment creates no store.
The parser uses reserved declaration result 64 and assignment result 256, outside
the corresponding binding and instruction namespaces.

Parentheses, unary operands, constructor payloads, ordinary binary right operands
and final CALL arguments propagate bottom. Earlier arguments have already been
evaluated once; their real terminal edge performs checked cleanup. The enclosing
CALL is not emitted. Existing Result obligations still apply to those captures.

For `&&` and `||`, a terminal right operand terminates only the evaluated path.
The skip path restores its binding state and reads the already initialized
boolean destination. Existing branch and loop-effect machinery preserves
break/continue transfers and outer scalar mutations without replaying effects.

Shared and owning returns retain their existing selected-origin and cleanup
proof. Independent canonical IR verification still rejects forged return values.
No verifier, VM opcode, existing price, public admission gate, native frame or
native stack setting changes. Public Fuel default 256 and ceiling 16000000 remain.

Both source lowerers accept a final `.len`, `.is_some`, `.is_none`, `.is_ok`
or `.is_err` on a terminal receiver. They validate the property name and
propagate the already established terminal control. No length read, tag test,
result slot or extra cleanup is emitted. Ordinary void calls keep their existing
type error. Unknown properties, method-call spelling and chained postfixes
after the terminal property still reject.

## Deliberate remaining limits

This is a bounded bottom-expression increment. The
[terminal-operand successor](value-terminal-operands.md) now propagates final
Buffer/view operands, including sole len/copy/view receivers, final byte arguments,
view indices and range upper endpoints. Bottom in control conditions or switch
subjects, index and propagation receivers, nonfinal byte operands/range lower endpoints, a
binary left operand followed by more operators and non-final CALL arguments
still rejects. Classic for headers retain their existing pure-expression restriction.
The [void-bottom successor](value-void-bottom.md) now admits private
`return <bottom>;` while keeping ordinary void-CALL/value operands rejected.

Statements after an unconditional terminal edge still reject at the first
trailing token. They are not silently skipped; valid unreachable statements are
also rejected. A parser that type-checks unreachable continuations without
emitting runtime work remains necessary for the broader language contract.

## Verification

`tools/verify-value-bottom.py` selects ten new groups and sixteen existing
join/view/Result/loop/depth regressions, with disjoint locked development/release
mirrors and default native stacks. The source suite includes both branch choices,
nested terminal tails, Buffer and shared-view cleanup, earlier CALL captures,
short-circuit effects, loop transfers, malformed input and tampered canonical IR.
The former fully-terminal shared-return rejection is now an execution regression.

For quick local regression checks, [optional bottom smoke](value-bottom-smoke.md)
calls these ten new checks in one native image per profile. It keeps the original
test bytes, but shares process state and adds a frame; keep isolated boundary
checks and the full focused verifier when their coverage is required.

Implementation `6f39099` passed 26 groups in each Windows native profile: ten
new groups and sixteen focused regressions. Fresh locked mirrors use exact final
inputs, default native stacks and no overrides. The shared-return oracle now
executes the formerly rejected guest; Result and lifetime rejection rules remain.
All 227 union inputs match checkout and Git raw bytes; all
216 production modules are LF. The full admitted32/rejected33 source fixture
is byte-identical to `8757f40` and ran in both profiles. See [focused evidence](../evidence/value-bottom-windows-20261107.json).

For terminal receiver properties, the Windows development and /O2 fixture
executables ran four groups in fresh processes with default stacks. The new
group executes all five properties through both lowerers and checks exact
return and Buffer drop counts, zero tag tests and zero view length reads.
It also rejects seven invalid forms. The other groups cover terminal operands,
unreachable source rejection and the combined 32/33 conditional-depth fixture.
The fixtures use locked mirrors and the production Windows clock companion.
Local receipts: `build/value-bottom-properties-7ug15y53/{development,release}/receipt.json`.

This increment does not establish full bottom syntax, public CLI admission,
Linux/macOS, restricted execution, embedding or the remaining runtime/host work.

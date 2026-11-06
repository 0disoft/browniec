# Fixed-array and plain-record if expressions

Date: 2026-11-06. This extends the existing scalar/tagged conditional expression
with fixed scalar arrays and nominal plain records. Full L02/L03 remain open.

## Source and type rules

```brownie
fn i32 main() {
    let a = if (true) { [20, 22] } else { [0; 2] };
    return a[0] + a[1];
}
```

Inferred and typed locals, by-value arguments, aggregate returns, array assignment,
whole/child record assignment and scalar projections accept conditional values.
Record child constructor fields can also use a conditional. Parentheses and
nested final conditionals compose, including else-if. Existing ordinary and
retained module compilation resolve the real qualified types and CALLs.

The condition is exactly bool. Every continuing arm yields one exact array
element type/length or one exact nominal record type. A surrounding array shape
supplies its expected scalar element type to literals. Without that context,
the first yielding arm
establishes the type. Terminal arms do not constrain it; an entirely terminal
conditional cannot be an operand. Missing alternatives, incomplete arms, mixed
scalar/aggregate values and mismatched types/shapes are rejected even in an
unselected arm. Reference/Buffer joins remain unavailable.

## Ownership and evaluation

The [lazy join recipe](aggregate-if-joins.md) is compiler scratch. It contributes
no opcode, owner phi, runtime tag or verifier authority. A first complete owned
value supplies the destination, while named values snapshot into a new owner.
Subsequent literal/whole CALL arms initialize that same destination directly.
Nested tail conditionals share it. Record constructors feed scalar staging
straight into the destination; selected child values copy their exact leaf range.

Conditions and the selected arm execute once in source order. The other arm
creates no runtime owner or backing extent. Static catalogs and invocation-level
array-list scratch are still bounded and prepared for the whole Program. An
aggregate argument snapshots its value before later argument effects. Whole/child
assignment keeps the existing destination alive until the conditional finishes.

Arm-local cleanup runs after capturing its final value. The pending result is
absent from lexical names before it is completely initialized. Return, propagation,
break and continue use existing cleanup and only close already published owners.
Projection indices capture a completed conditional owner before evaluating any
effectful index. Earlier guest effects are never rolled back.

Independent CFG/type/live-owner admission is unchanged. Both continuing branches
must arrive with the same initialized result owner, and malformed missing or
duplicate initialization is rejected. Existing returned-owner protection applies.

## Fuel and bounds

Existing operation prices, default 256 and CLI ceiling 16000000 are unchanged.
For an i32 repeated array of length one, selected true/false paths use 165/164
Fuel with four backing bytes, or 65697/65696 with the public 64-KiB backing.
The corresponding one-i32-field record uses 87503/87502 native Fuel and
153035/153034 public Fuel. Exact and one-short native budgets, and exact,
one-short and one-more public budgets, are checked independently.

Two literal branches and nested tails use one catalog site and four backing
bytes for a one-i32 result; a three-byte quota fails. Named snapshots still need
independent storage. Source/type/CFG, token, register, instruction, frame, arena
and site limits remain. Sixteen nested repeated-array arms pass; seventeen fail.
Record constructor fields consume their existing additional expression levels:
fifteen nested arms pass and sixteen fail. Original 32/33 captured CALL bounds
and scalar conditional depth probes remain in the focused verification.

## Verification

The focused commands are:

```text
python -B tools/verify-static-execution.py --profile development --selection aggregate-if-expressions
python -B tools/verify-static-execution.py --profile release --selection aggregate-if-expressions
python -B tools/verify-local-inference-cli.py --profile development --aggregate-if-expressions
python -B tools/verify-local-inference-cli.py --profile release --aggregate-if-expressions
```

CLI builds share output and must be serialized. Both profiles use the pinned
compiler and a locked LF mirror; standalone CLI execution has no runtime tools
on PATH. No native stack override or historical result reuse is permitted.
Development and release each passed **21 native groups and 264 tool-free CLI
cases** at `33f32f4`. The 172 input paths match checkout and Git raw bytes,
including 160 LF production modules and common 273-file test discovery. Forty-one
unselected discovery fixtures differ only by CRLF/LF; both hashes are recorded.
See the [Windows evidence](../evidence/aggregate-if-expressions-windows-20261106.json)
for commands, exact identities, reports, inputs, compiler and CLI artifact hashes.

The original ungrouped record depth harness overflowed with native process status
`-1073741571`. A fresh isolated snapshot of pre-feature `dda1cf6` reproduced the
same failure. The retained helper now calls the same underlying `compile_reference_returns`
and `run_public_references` paths directly, leaving large public container staging
off its native stack. All original sources, 32/33 limits and assertions remain.
Eight byte-identical original record inputs additionally pass through the complete
public CLI wrappers in each profile. This is scoped harness evidence, not a
general native API stack guarantee. No native stack override or reduced guest
limit was used.

The [switch successor](aggregate-switch-expressions.md) now adds aggregate
switch values and mixed tails through the same join recipes. The
[void successor](void-source.md) separately owns void source support.
General reference/Buffer joins, broader constructor context,
grouped lvalues/borrows, nested/resource array elements,
full C05/Instance/host and delivery remain separate work. This increment does not
claim full-profile conformance, Linux execution, allocator fault injection,
general native-stack bounds or elapsed-time/performance measurements.

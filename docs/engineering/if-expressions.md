# Scalar and shallow-tagged if expressions

Date: 2026-11-06. This increment supplies conditional value expressions within
the existing scalar/shallow-tagged profile. Full L02/L03 remain open.

## Source and typing

An ordinary operand may be `if (CONDITION) { VALUE } else { VALUE }`, including
`else if` chains. The condition must be exactly bool. An expression requires an
else branch, and every continuing arm must finish with a value without a trailing
semicolon. Existing declarations, assignments, blocks, loops, conditional
statements and nonlocal exits can precede that final value.

```brownie
fn i32 main() {
    let answer=if (true) {
        let n=20;
        if (false) { 0 } else { n+22 }
    } else { 0 };
    return answer;
}
```

Results may use the six existing scalar domains and admitted shallow Option and
Result types. All yielding arms have one exact type; there are no implicit
conversions. Existing expected-type rules apply to literals and constructors.
Without a surrounding type, the first yielding arm supplies subsequent branch
context. `.some` can infer its existing i32/bool payload; bare `.none`, `.ok` and
`.err` still need complete constructor context.

The result composes with operators, widening casts, calls, local inference,
assignment, returns, while conditions, switch arms and postfix propagation under
the existing type rules. A conditional at the end of a value arm can be its final
expression without additional parentheses. Conditional statements before a tail
value keep their original grammar and scope. Function bodies still require
explicit returns. Pure classic-for headers continue to reject conditional values.

A terminal arm may return from the enclosing function, propagate failure, or
transfer to a lexical loop. It does not constrain the value type. An entire
conditional with no yielding path cannot serve as an operand: this increment
does not introduce a bottom/never value type. A terminal else-if suffix can still
terminate an outer conditional's alternative path.

## Evaluation and ownership

Conditions execute once. An else-if condition runs only after preceding
conditions are false. Only the selected arm executes, including its effects,
failures and local owner allocation. All arms are nevertheless type checked.
Outer mutable slots retain selected-arm changes; arm declarations cannot escape
or shadow an already visible local, while sibling arms can reuse local names.

Arms use the existing scope evaluator and reverse-order cleanup. Local arrays,
records and loans close before a scalar/tagged value leaves the arm. Existing
pending CALL captures remain live through evaluation and close correctly on
return, propagation, break or continue. A while condition retains its own nearest
loop target. Earlier guest effects are never rolled back.

Read-only syntax classification distinguishes a final conditional value from a
conditional statement inside a value arm. It shares ordinary assignment
classification, consumes only a lexer snapshot and grants no IR authority.
Actual parsing rechecks the complete expression. Keyword spelling and Yield
temporaries stay in separate helpers outside ordinary recursive scalar frames.

## IR, Fuel and bounds

Lowering reuses conditional jumps, unconditional jumps, STORE and LOAD. Continuing
value paths initialize one lazy exact-type join slot; terminal paths never read
it. Independent existing control-flow/definite-initialization admission remains
mandatory. No opcode or operation price changes.

`return if(true){42}else{0};` uses exactly 7 scalar Fuel; the corresponding false
path returning 42 uses 6. Exact budgets succeed and one-less budgets fail through
native VM and public CLI execution. Default 256 and CLI ceiling 16000000 remain.

Condition parsing adds one expression/structural level; arm parsing adds two.
Limits are inherited rather than reset through nested statements and values.
Sixteen nested value arms pass and seventeen fail. With an additional conditional
inside each condition, fifteen nested arms pass and sixteen fail. Other source,
token, register, instruction, function, frame and storage capacities remain.

## Native depth harness

The original inferred-local 32/33 native case overflowed the Windows stack with
status `-1073741571` and no valid trap control. The same case reproduced on
pre-feature `7b9a9de`; independent route probes identified the retained path.
Removing the test's redundant Program switch-result assignment alone was
insufficient. Its depth helpers now call the same underlying ordinary and
retained compiler/VM routines directly, outside the large pass-through public
container frames. The original guest sources, 32/33 bounds, two successful
runs, error kinds and assertions remain. The exact four original sources also
run through each tool-free public CLI profile, covering public mode selection
and container admission. No native stack override or smaller parser limit is
used. This records the observed harness boundary, not a general native API
stack guarantee.

## Verification and remaining work

Windows development and release each passed **11 native groups and 216 tool-free
CLI cases** at implementation `98a30ca`. The 168 input paths match checkout and
Git raw bytes, with 159 LF production modules and common 271-file discovery.
Both locked LF mirrors pass. Forty-one unselected discovery fixtures differ
from Git only by CRLF/LF; both hashes are preserved in the receipt. Exact selected
identities, compiler/artifact/input hashes, public depth fixtures and baseline
harness diagnosis are recorded in the
[Windows evidence](../evidence/if-expressions-windows-20261106.json).

```text
python -B tools/verify-static-execution.py --profile development --selection if-expressions
python -B tools/verify-static-execution.py --profile release --selection if-expressions
python -B tools/verify-local-inference-cli.py --profile development --if-expressions
python -B tools/verify-local-inference-cli.py --profile release --if-expressions
```

CLI builds share their output and must be serialized. Verification uses the pinned
compiler, locked LF mirrors and tool-free CLI execution. No native stack override
or historical result reuse is allowed.

Array/record/reference/Buffer value joins, broader constructor context, void
functions, grouped lvalues/borrows, full C05/Instance/host and delivery remain
separate work. No full-profile conformance, whole-project performance or general
native API stack-size guarantee is established here.

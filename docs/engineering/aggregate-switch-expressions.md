# Fixed-array and plain-record switch expressions

Date: 2026-11-06. Successor to [aggregate if values](aggregate-if-expressions.md).

```brownie
fn i32 main() {
    let Option<i32> source = .some(20);
    let a = switch (source) {
        case .some(v): { [v, 22] }
        case .none: { [0; 2] }
    };
    return a[0] + a[1];
}
```

The existing two-variant Option/Result switch now yields fixed scalar arrays or
nominal plain records. Inferred/typed locals, by-value arguments, aggregate
returns, whole-array/record and child-record assignment, child constructor
fields and scalar projections use the same value readers as if expressions.
Grouped values and mixed nested if/switch tails compose. Qualified native module
calls work through ordinary and retained compilation. This does not add general
integer patterns, resource-bearing tags or other new subject types.

Every continuing arm supplies one exact element type/length or nominal record.
Contextual array shapes type literal elements; otherwise the first yielding arm
sets the type. Terminal arms supply no value constraint, and an entirely terminal
operand is rejected. Both variants are mandatory and duplicate patterns fail.
Pattern payload names remain arm-local. Mismatched and invalid unselected arms
still fail compilation. General reference/Buffer joins remain unavailable.

## Ownership and control flow

The subject and selected arm execute once. Array/record values use the existing
lazy [join recipe](aggregate-if-joins.md); one initialized destination is shared
by continuing branches, including mixed nested tails. Named values snapshot
before later argument effects. Selected literal/whole-CALL arms initialize the
result directly, and record constructors stage exact leaves into it. The result
is absent from lexical names until initialization finishes.

Scalar/tagged switch values use the same exact-type join. The separate scalar
arm parser has been removed. Existing arm statements, void calls, lexical cleanup,
return, propagation and loop transfers retain their behavior. A leading switch
inside a value arm is its final expression; a statement switch still requires a
standalone block there. Classic-for headers remain pure scalar.

No opcode, owner phi, runtime type tag or verifier authority is added. Independent
CFG/type/live-owner admission checks every path. Native mutations removing a
selected result initialization or duplicating it fail admission before execution.
Earlier guest effects are never rolled back by a later failure.

## Fuel and limits

Operation prices, default 256 and CLI ceiling 16000000 remain. For a `.none`
subject with the selected variant first/second, the exact fixture prices are:

| Result | Four-byte native backing | Public ordinary backing | Public retained with image binding |
| --- | ---: | ---: | ---: |
| One repeated i32 element | 165 / 166 | 65697 / 65698 | 409782 / 409783 |
| One i32 record field | 87503 / 87504 | 153035 / 153036 | 497120 / 497121 |

Native fixtures check exact/one-short budgets. Public ordinary and retained
fixtures also check one-more. Native setup is 5; array INIT/READ/DROP are
68/37/49 plus six or seven scalar units. Record INIT/READ/DROP are
46145/41281/65 plus seven or eight scalar units. Public backing adds 65532;
the retained fixture additionally adds the existing 344064 entry/leave reserve,
18 image OPEN/CLOSE units and three separate aggregate dispatch units.

Literal branches and mixed nested tails require one catalog site and exactly
four backing bytes; three bytes fail. Named snapshots still require independent
storage. Source, token, register, instruction, frame, site and arena limits remain.
Public depth fixtures admit 16 nested repeated-array switches and reject 17;
record constructor leaves retain their extra levels, admitting 15 and rejecting
16. Original 32/33 captured CALL limits remain in the focused regression selection.

## Verification commands

```text
python -B tools/verify-static-execution.py --profile development --selection aggregate-switch-expressions
python -B tools/verify-local-inference-cli.py --profile development --aggregate-switch-expressions
python -B tools/verify-static-execution.py --profile release --selection aggregate-switch-expressions
python -B tools/verify-local-inference-cli.py --profile release --aggregate-switch-expressions
```

CLI builds share output and are serialized. Both profiles use the pinned compiler
and locked LF mirrors. CLI execution has an empty runtime tool PATH. New version
flags `array_switch_expressions` and `record_switch_expressions` advertise this
source subset; profile/core/restricted/embed meanings remain unchanged. Outcomes,
input identities and artifact hashes are recorded in the
[Windows evidence](../evidence/aggregate-switch-expressions-windows-20261106.json).

General reference/Buffer joins, broader constructor context, grouped lvalues and
borrows, nested/resource array elements, complete C05/Instance/host and delivery
remain open. Full language matrices, the original full public Fuel suite, Linux,
allocator fault injection, general stack-size bounds and timing/delivery benchmarks
are outside this focused increment.

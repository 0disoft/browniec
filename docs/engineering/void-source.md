# Void functions and statements

Date: 2026-11-06. Source successor to [void IR](void-ir.md).

`fn void work(...) { ... }` declares a function without a result. It accepts
`return;` or an implicit return at the closing brace. Direct `work(...);`
statements use the existing ordered argument evaluation, ownership captures,
CALL admission and frame restoration. Qualified native module calls work on
both ordinary and retained compiler routes. Entry remains zero-argument i32.

Only void functions may be called as standalone statements. Ignoring a scalar,
aggregate or Result return is still rejected. Void is a reserved return-only
type: it cannot inhabit a local, parameter, array, wrapper, expression or value
arm. A void call may precede the final value of an if/switch arm; it never
supplies that value. Pure classic-for headers still reject calls and early
exits. Returning a value from a void function fails type checking. Statements
after an unconditional return fail syntax checking.

Explicit and implicit returns release visible local owners, loans and image
views before emitting opcode 82. Parameter and captured-argument lifetimes use
the existing transaction/driver cleanup. Early return/break/continue in later
arguments closes only captures already published. Neither source classification
nor the void return metadata bypasses independent whole-program admission.
The CALL has destination zero without defining or writing a scalar result cell;
the builder sentinel 256 remains native metadata, never a guest value.

## Fuel and limits

Existing operation prices, default 256 and public ceiling 16000000 remain.
Void RETURN costs one dispatch unit. CALLs retain their original dispatch,
parameter-transfer, aggregate-copy, retention and restoration charges. Avoiding
a dummy result creates no discount in these phases.

For `noop(){}` and a main that defines 42, calls noop and returns that value:

| Route | Exact invocation Fuel |
| --- | ---: |
| Ordinary source/native IR | 4 |
| Retained native IR, empty image | `2*(147456+196608)+4 = 688132` |
| Public retained source, unused `b"*"` binding | `2*(147456+196608)+22 = 688150` |

Each route checks an exact and one-short budget; the public fixtures also check
one-more. The retained source adds the existing image OPEN/CLOSE costs. These
are whole-invocation costs, not alternative prices for RETURN. With all 128
value registers occupied, the native ordinary fixture succeeds at 131 and fails
at 130 without a dummy register. Public source still admits 32 CALL sites and
rejects 33; no source, register, instruction, frame or storage capacity expands.

The new `void_functions: true` version flag advertises this source subset.
Profiles and `core`/`restricted`/`embed` meanings are unchanged.

## Focused verification

```text
python -B tools/verify-static-execution.py --profile development --selection void-functions
python -B tools/verify-local-inference-cli.py --profile development --void-functions
python -B tools/verify-static-execution.py --profile release --selection void-functions
python -B tools/verify-local-inference-cli.py --profile release --void-functions
```

Windows development and release each passed 17 native groups and 298 language
CLI cases. The existing public Fuel CLI phase separately passed 57 cases per
profile, including usage/overflow/ceiling rejection and prior exact aggregate
oracles. All 182 input paths match checkout and Git raw bytes, and both locked
LF mirrors pass. The common 275-file discovery records forty-one unselected
legacy CRLF/LF variants separately. The original full public Fuel native
selection was not rerun.

The selection covers void source/independent IR, original 32/33 captured CALL
regressions, native qualified modules, conditional tail classification and
nonlocal aggregate cleanup. The CLI selection includes prior inference and
aggregate-condition regressions and runs with an empty runtime tool PATH.
Artifact/input identities and outcomes are recorded in the
[Windows evidence](../evidence/void-functions-windows-20261106.json).

Aggregate switch values, general reference/Buffer joins, broader constructor
context, grouped lvalues/borrows, nested/resource array elements, complete
C05/Instance accounting, host integration and delivery remain open. This
increment does not rerun full matrices, Linux, allocator fault injection,
general stack-size bounds or elapsed-time/delivery benchmarks.

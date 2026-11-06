# Aggregate places in both VM drivers

Date: 2026-11-06. Execution successor to the
[shared native dispatcher](place-dispatch.md).

## Complete admission and current bindings

Ordinary, immutable-image and returned-reference admission now accept whole
scalar-array places (kind 3), exact nominal record-subtree places (kind 4), and
REPLACE87 after complete operand, CFG, owner, loan and phase proof. The narrow
legacy native adapters keep rejecting aggregate encodings; executable drivers
use `place_dispatch`. Analysis alone still issues no executable receipt.

Both coordinators prepare one common invocation vector and dispatch op 83..87
through it. Ordinary record bindings come from `struct_vm::State.tokens`;
retained record bindings come from `slice_result_record_bindings`. Array bindings
come from the current frame's array map. Record SELECT and copy-source tokens
are resolved only after instruction Fuel preflight. Native transactions still
authenticate the actual original destination, owner generation, nominal shape,
reservation and window before publishing bytes.

Kinds0..4 share the same frame-local IDs and counter. The parent selection stays
live across child CALLs and owned array/record result publication; each child
must END its own places before normal return. Later CALLs can reuse the child's
ID without changing the parent's captured destination. Existing scalar,
aggregate, reference and void return checks remain in place.

## Setup, failure and retained dependencies

Both public routes preflight backing/entry plus list and place setup before
allocating guest backing or entering native ownership. Invocation-local list
scratch also serves selected list replacement, including the full 4096-cell /
32768-byte case. Preparation is charged once, separately from each instruction.

The ordinary execution loop keeps its scratch in an outer fallible wrapper;
the retained wrapper uses the same abort helper. On failure, place rows drain
at zero remaining Fuel before owner/loan cleanup. Setup prepaid the bounded
metadata destruction. Prior successful payload writes remain visible and the
first error survives cleanup. A subsequent invocation is an explicit host retry.

Returned-reference lifetime proof interprets kind 3 as an array owner and kind 4
as a separate record namespace. A live returned array view blocks whole-array
selection and writes, while same-numbered record sites and nominal IDs remain
usable. Recipe proof does not treat aggregate SELECT metadata or copy-source
owner IDs as scalar reads. REPLACE87 tracks the fill register, every dense-list
operand and every consecutive constructor input; opaque CALL_BIND identities
cannot become payload values through any of these forms.

## Independent Fuel boundaries

No existing instruction is repriced. Legacy-only invocations retain their
original formats, setup and END 17/22 prices. Aggregate-capable invocations use
the existing eighteen-word format and END 26. Retained execution adds its
existing dispatch unit to each instruction. Default 256 and CLI cap 16000000
remain unchanged; native APIs still take a host-selected budget.

The test oracles use numeric arithmetic without calling the production price
functions. For the two-element array fixture, scalar width `w`, store price `S`
and optional list setup `L`, custom-backing ordinary Fuel is
`6741 + 13*w + S + L`, with `4*w` backing bytes:

- Copy/self-copy: `S=178+2*w`, plus 2 for bool validation.
- Fill: `S=146+4*w`.
- List: `S=148+6*w`, `L=261+2*w`.

Public ordinary backing adds `65536-4*w`. Public retained execution adds
`409608-4*w`. These are native-IR fixture totals, not new source syntax prices.

| Native IR fixture | Custom ordinary | Public ordinary | Public retained |
| --- | ---: | ---: | ---: |
| Two i32s, copy/self-copy, 16 backing bytes | 6979 | 72499 | 416571 |
| Two i32s, fill, 16 backing bytes | 6955 | 72475 | 416547 |
| Two i32s, list, 16 backing bytes | 7234 | 72754 | 416826 |
| Nominal root/subtree copy, 32 backing bytes | 394604 | 460108 | 804181 |
| Nominal root/subtree constructor, 32 backing bytes | 350637 | 416141 | 760214 |
| 4096 i64s, selected list, public backing | — | 281616 | 625688 |

All six scalar array domains test one-short/exact/one-more budgets through
custom ordinary and public retained execution. Record root/subtree copy and
constructor replacement use the same three boundaries. The maximum list tests
both public routes. Native retained i32 copy with sixteen backing bytes requires
351034 Fuel and leaves zero at exact budget. Its 153822 setup shortage leaves
backing untouched; at 154257, STORE has published but END fails with zero Fuel,
then owner/frame metadata drains without undoing bytes.

## Verification and next work

Run `python -B tools/verify-aggregate-place-execution.py --profile development --batch core`,
then `--batch regression`, and repeat both for `release`. The
default selection contains 12 native groups: five new execution groups plus
seven complete-admission, malformed-IR, loan/CALL-lifetime, legacy exact-price
and retained dependency/scalar-use regressions. The two batches keep each native
compiler invocation within a bounded selection. Public CLI regression uses
`tools/verify-public-fuel.py --phase cli` in each profile. A preceding 37-group
development attempt exceeded the runner's 600-second timeout and is not a pass.

Guest aggregate-assignment source lowering still uses its earlier lowering;
ordered lowering into these selected places is next. Resource/tag move rules,
grouped borrow and reference/Buffer joins, complete L04/C05/Engine/Instance/host/
isolation/platform/delivery remain open. Full language/native Fuel matrices, LF
mirrors, Linux, OOM injection, general stack/performance and clean-machine
delivery are outside this selection.

Windows development/release each passed **12 native groups and 105 tool-free
public Fuel CLI cases** on implementation `3b1aa50`. Both profiles run core 5 and
regression 7 fresh on the same final inputs. The 199-input union matches checkout
and Git raw bytes; all 177 production modules are LF, and discovery inventories
305 test-source files / 1828 annotations. This inventory is not a full-suite
pass. Compiler, report, receipt and CLI artifact hashes plus commands and the
preliminary fixture/build/selection failures are recorded in the
[Windows evidence](../evidence/aggregate-place-execution-windows-20261106.json).
No historical runtime result reuse or compiler/linker/stack override was used.
No push, release or deployment was performed.

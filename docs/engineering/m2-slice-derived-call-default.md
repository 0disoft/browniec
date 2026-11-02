# Default checked native derived CALL admission

Implemented at `2a30fae` on `main`, this promotes supported derived CALLs into
default checked native `inspect`/`execute`; the former `inspect_derived` body is
default admission. Only `src/vm_reborrow_execution.fy` changes production logic;
97 others match baseline `8c9c8b6` under Git LF. This is a native wrapper
promotion: public source admission, verify/VM execution, legacy execution and CLI remain gated.

The old `inspect_derived` body is byte-identical under Git LF normalization to
new `inspect`; `execute`/`run` are unchanged and aliases delegate to the defaults.

## Admission order

`inspect` now performs these checks in order:

1. run the complete `verifier::inspect_reborrow_calls` proof;
2. build the existing `slice_reborrow_ir::Sites` metadata;
3. walk every CALL, evaluate its existing canonical price, and for a CALL that
   requires the derived transaction, reject owned arguments or array/record
   results at the CALL site.

The walk covers all instructions and functions, so unsupported derived CALLs,
including owned/aggregate shapes, fail in unreachable functions. Before proof/scan
succeed, no context is accepted, Fuel spent, guest-owned storage allocated or
dispatch/effect begun; native verifier scratch still exists.

`execute` calls `inspect` before the private run path and preserves its one-state,
one-CALL-map and one-child-map requirements. Dirty contexts fail validation
before dispatch. `context::ready`, the shared core and `context::finish` keep
their existing bodies and ordering. `inspect_derived`/`execute_derived` delegate
without a second proof, execution pass or charge.

## Runtime contract

The shared loop and native loan handoff still execute supported derived CALLs
with borrowed/scalar arguments and a scalar result; ordinary CALLs keep their
owned and aggregate-result transaction.

The CALL price remains `1 + arity + owned-copy cost + slice-retention cost`; retention
is zero without slices or `65,537 * (1 + R + 2 * W)` for `R` readers and `W` writers.
Admission validates every CALL price; runtime uses the existing path with no new charge.

Normal return and abort still use reverse restoration and combined drain.
Rejection/runtime failure preserves prior writes. Successful cleanup returns the
original result/error; failed cleanup returns its own error and retains receipt,
pool, ticket, origin and diagnostic maps. Native callers dispose owned storage/backing.

## Closed gates

| Surface | Derived CALL status |
| --- | --- |
| Default native `inspect` / `execute` | Supported scalar derived shapes admitted |
| Compatibility aliases (`inspect_derived` / `execute_derived`) | Same default native behavior; no second proof or execution pass |
| `verifier::inspect` | Admits reborrow op61/62 analysis without suspended/derived CALLs; rejects the supported derived CALL shape via `validate(false)` |
| `verifier::verify` | Rejects any private reborrow opcode 61/62 |
| Public VM and legacy execution | Still reject the native derived shape |
| Compiler, source grammar and CLI | Still gate the private reborrow opcodes |

Native default promotion does not promote a guest/public language feature. No
opcode, Program field, profile or capability is added. Native authority, loop,
prices and layouts are unchanged; production logic changes only wrapper admission.

## Verification status

Development passed 8 updated core groups; release passed the same 8 plus 8
regression groups, 16 native groups. Default-entry core tests cover:

- six scalar tags for owned/formal sources; recursion/depth; shared/multiple
  writers and ordinary owned CALLs;
- bounds/arithmetic/Fuel cleanup; exact Fuel; preflight before handoff;
- raw-core retry maps; and rejection in unreachable functions, dirty contexts,
  strict/public/legacy gates, plus alias success.

Release regression passed 8 groups: 6 existing `slice_reborrow_execution` tests
plus exact gate tests in `slice_reborrow_call_admission` and `slice_reborrow_call_vm`.
Those fixtures now expect default native `inspect` success while retaining
strict verifier, public VM and legacy rejection; final regression executed both.

All 402 current input hashes plus compiler/receipt identities were rechecked.
Core manifests differ from final regression only in those two previously
unselected gate fixtures. Selected core test, production, lockfile and compiler
hashes match across phases. Sole production delta: `vm_reborrow_execution`; 97 files
match baseline `8c9c8b6` under Git LF normalization.

CLI, full native, other M2, full M1, Linux, isolation, packaging, allocator,
native-size/stack and timing were not rerun. Public/compiler/legacy production is unchanged;
no production module imports this wrapper, so no CLI rebuild was needed.

Public VM canonical integration/source promotion and derived owned/aggregate
support remain separate. No push was made. [Verified Windows evidence](../evidence/m2-derived-call-default-windows-20261103.json)

# Risk Register

- Status: Reconciled 2026-11-03 against source and scoped historical receipts
- Decision owner: Zerodi / Rodisoft
- Design acceptance alone closes no risk; scope-specific native evidence is retained.

| Risk | Current exposure and remaining closure evidence |
| --- | --- |
| R1: Native feasibility | M0 and the M1 checkpoint have scoped Windows native evidence. The core interpreter exists; new Buffer, lifecycle, worker and ABI boundaries need their own failure evidence. |
| R2: Native memory safety | Public aggregate/slice code and native shims require correct identity, loan and rollback bookkeeping. Scoped stale-token/quota tests are not a proof for the entire VM; restricted containment is absent. |
| R3: Broker ordering | No worker/broker is implemented. M4 must reject illegal phases and late dispatch/publication, including cancellation, exit/EOF and I/O-lease races. |
| R4: Layout budget coupling | Scalar/nested records work, but wide/resource-bearing depth-four tags do not. Separate plain nesting, tagged depth and total traversal/bytes before full-profile acceptance. |
| R5: Buffer growth rejection | Minimum rounded fallback and old-plus-new accounting have private native evidence. Guest Buffer/VM/Instance integration remains open and must preserve those semantics. |
| R6: ABI gap | Brownie has no public DLL ABI. Callable Fairy functions or historical adapter findings do not prove exports; M5 needs actual symbol/export/C-host-call evidence. |
| R7: Cost targets | Startup/compile/reuse, stack/heap, total memory and retained builds are unmeasured. The current 4KiB source cap cannot execute the 10KiB compile target unchanged. |
| R8: Product mismatch | No representative input -> transform -> staged-output guest workload has been delivered. Validate a usable workload and developer benefit before optional language expansion. |
| R9: Unknown effects | Typed host and cancellation paths are not implemented. Preserve known/unknown effect state and host reconciliation; no automatic replay. |
| R10: Toolchain drift | `toolchain.json` records the adopted compiler/SDK, not a permanent version freeze. Windows narrow evidence does not establish Linux runtime support or compatibility of a future update. |
| R11: Returned-view lifetime | Private IR proof and scoped native handoff/retention now exist. Keep public results gated until result/frame/site bindings, opcode dispatch, capture/callee cleanup and integrated lifetime/failure proof are verified. |
| R12: Resource and terminal boundaries | Fuel and an aggregate arena cap exist, but complete Engine-total accounting, bounded step/cleanup, cancellation/deadline and persistent poison do not. Do not expose those lifecycle guarantees early. |
| R13: Stale status or overclaim | Historical increment gates/counts can contradict newer features. Current inventory and version availability must separate private foundations, public execution, full profile, OS and packaged delivery. |

## Exposure and ownership

An experimental native core exists and is intended for trusted local source. It
has no verified restricted worker for arbitrary external source. Production incident
rates and full-profile performance/safety guarantees are not established.

The maintainer implementing each slice owns its mitigation evidence; Zerodi /
Rodisoft owns scope and release decisions. Reassess affected risks after each
counterexample or implementation boundary. Retain residual limits when a narrow
case closes; failed native probes, unavailable isolation and missing DLL exports
block their corresponding deliveries.

See the [complete inventory](04-remaining-work.md), [roadmap](01-roadmap.md),
[review findings](../design-baseline.md) and [validation policy](../../VALIDATION.md).

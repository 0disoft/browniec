# Risk Register

- Status: Initial open risks, 2026-10-23
- Decision owner: Zerodi / Rodisoft
- No risk below is closed by accepting the design

| Risk | Failure scenario | Response and closure evidence |
| --- | --- | --- |
| R1: Native feasibility | Fairy C cannot return storage/arithmetic failure without trapping | M0 native probes; narrow or revise implementation before expansion |
| R2: Native memory safety | A shim or VM ledger error corrupts the host | Narrow shims, stale-token and quota probes, worker containment; no safety proof claimed |
| R3: Broker ordering | Illegal or late frames dispatch host work or publish cancelled output | M4 negative phase, cancellation, exit/EOF, and I/O lease tests |
| R4: Layout budget coupling | Valid structs fail when wrapped in Option/Result | Independent structural, wrapper, and total-work budgets with boundary cases |
| R5: Buffer growth rejection | Preferred capacity fails although minimum capacity fits | Test minimum rounded fallback with old-plus-new peak reservations |
| R6: ABI gap | A callable Fairy function is mistaken for a public DLL export | M5 actual symbol/export/call test before embed delivery |
| R7: Cost targets | Compilation, startup, RAM, or retained builds exceed budgets | Measure named workloads separately; narrow scope before complex optimization |
| R8: Product mismatch | No useful task benefits from a new language | Test validation, bytes, and rules with developer feedback before broadening scope |
| R9: Unknown effects | Cancellation hides an already performed host effect | Report known/unknown effect state; host owns reconciliation; no automatic replay |
| R10: Toolchain drift | Compiler/SDK changes alter semantics or native behavior | Record build identities and run narrow compatibility probes on adoption |

## Exposure and ownership

The implementation does not exist, so production likelihood and incident frequency
are unknown. The maintainer implementing each slice owns its mitigation evidence;
Zerodi / Rodisoft owns scope and release decisions.

Reassess at each affected milestone or after a counterexample. Close a risk only
with evidence for its stated scope and retain residual limits. Failed native probes,
unavailable isolation, or missing exports block the corresponding delivery level.
See the [review findings](../design-baseline.md) and [validation policy](../../VALIDATION.md).

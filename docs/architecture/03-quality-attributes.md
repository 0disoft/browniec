# Quality Attributes

- Status: Designed scenarios; no measured results

| Attribute | Required scenario and observation |
| --- | --- |
| Correctness | Real source yields the specified value or diagnostic through the native pipeline |
| Failure containment | Arithmetic/quota/cancellation becomes an Instance outcome, not a native trap |
| Bounded work | Parsing, verification, runtime work, cleanup, and IPC obey explicit limits |
| Isolation | Actual restricted Windows worker denies unauthorized access and fails closed |
| Latency | Measure reused setup and compile/verify separately from process startup |
| Memory | Report VM ledgers, allocation peaks, and process memory independently |
| Build footprint | Bound retained project outputs and separate compiler/debug/cache costs |
| Operability | Report terminal cause, publication status, and unknown external effects accurately |

## Measurement

The [performance budget](../engineering/03-performance-budget.md) owns numeric targets.
Record workload, hardware, OS, artifact/toolchain identity, optimization profile,
sample count, and warm/cold conditions. Targets are not current guarantees.

Correctness and resource failures must remain observable during optimization.
Do not count work delegated to a native host as VM throughput. Do not compare
accounted VM bytes directly to another runtime's process RAM.

## Tradeoffs and review

Favor a small source profile and end-to-end delivery before JIT, broad APIs, or
complex caching. Checked arithmetic, quotas, ownership, and output staging remain
required even when they cost time or memory.

Review targets after M0 feasibility, representative workloads, and each material
profile or delivery-boundary change. Zerodi / Rodisoft owns scope decisions.

# Performance Checklist

- Status: Draft

## Source of Truth

- [AGENTS.md](../../AGENTS.md)
- [VALIDATION.md](../../VALIDATION.md)
- [docs/engineering/03-performance-budget.md](../../docs/engineering/03-performance-budget.md)
- [docs/engineering/00-project-invariants.md](../../docs/engineering/00-project-invariants.md)

## Failure Modes

Unrepresentative measurements, changed workloads mistaken for improvements, resource pressure, unbounded work, stale cache results, and hidden correctness tradeoffs.

## Checklist

Complete applicable items only with evidence. Record unresolved choices and the reason for any skipped or inapplicable item.

- [ ] The affected journey or hot path, representative workload, supported environment, and relevant resource limits are identified.
- [ ] Measurements name artifact and environment identity, observation points, units, comparable baseline, and meaningful uncertainty or regression thresholds.
- [ ] Relevant latency, memory, payload, I/O, or queue evidence covers operating conditions and tails rather than only a favorable average.
- [ ] Changed concurrency, allocation, caching, or batching preserves agreed correctness, freshness, identity, and lifecycle behavior.
- [ ] Overload, deadlines, cancellation, and bounded admission or recovery are accounted for where work can outlive its usefulness.
- [ ] Observed results and tradeoffs support the stated improvement, with unmeasured environments and remaining verification gaps explicit.

## Validation

- Relevant validation names: test, smoke, check
- Select configured checks from VALIDATION.md for the affected contracts and failure paths.
- Report skipped or unconfigured checks with reasons and remaining risk; they are not passing evidence.

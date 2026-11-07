# Performance Budget

- Status: Initial targets only; every number is unmeasured
- Scope: small reused runs, pure compilation, scalar loops, and retained builds

## Workloads

Benchmark small data validation, byte transform, rule evaluation, scalar loops,
Buffer growth, host request/reply, and compile/run reuse separately. Use fixed input
and observable output so dead-code removal cannot hide work. Record warm and cold
conditions and the build ID that produced each binary.

## Initial targets

| Metric | Target | State |
| --- | --- | --- |
| Reused small Instance setup | p95 at or below 1 ms | Unmeasured |
| 10 KiB pure source compile plus verify | p95 at or below 10 ms | Unmeasured |
| Empty Instance accounted memory | at or below 32 KiB | Unmeasured |
| Warm scalar loop heap allocation | zero | Unmeasured |
| 100 retained edit builds | at or below 32 MiB project output, excluding explicit debug/toolchain artifacts | Unmeasured |

A tuned low p95 is not a guarantee for allocator, kernel, or process-startup delay.

## Measurement boundaries

Use repeated independent runs and enough timed samples to justify reported
percentiles; disclose sample count, median, and spread. For small work, batch calls
and record harness cost. Distinguish:

- source read, compile, verify, run, and result publication;
- VM accounted memory, retained capacity, process private bytes, commit, working set, and startup;
- developer build cache, compiler installation, binary output, and OS page cache;
- core VM time, worker process cost, IPC, and native-host work.

Emptying only Program retention is not the same as an OS file-cache reset. Worker
measurement includes process creation, isolation preparation, and transport.

## Optimization and evidence

Benchmark small real workloads before fixing firm targets. Compare identical input,
artifact, optimization profile, hardware, and power state. Do not claim VM speed by
offloading the measured workload to a native host. Report correctness, peak memory,
code size, compile time, and safety cost with every optimization.

Long fuzzing and precise benchmarks are manual, risk-based runs rather than mandatory
per-push suites. No benchmark runner or measured budget exists today.

## Current measurement blockers (2026-11-03)

The native CLI currently caps source at 4096 UTF-8 bytes, so the 10KiB compile
workload cannot yet run through it. Explicitly reconcile the benchmark/profile
before raising limits; do not describe this target as measured. Full Instance
setup, guest Buffer/input/output, host, worker and embed workloads need their
missing integration first. The [remaining-work audit](../product/04-remaining-work.md)
tracks those prerequisites and separate runtime/build-footprint measurements.

## Measured control-storage increment (2026-11-07)

[Engine control storage](runtime-engine-control-memory.md) now measures SDK
requests and typed inline size in development/O2. One Program/Instance needs
6,592 heap bytes plus a 600-byte inline Engine; all-64 backing uses 52,736 heap
bytes. This measures fixed descriptor storage, not full Instance setup, VM frames,
input/output payloads, compile work, process memory or timing. The initial full
Instance and latency targets above therefore remain unmeasured.

The [retained Program successor](runtime-engine-program-memory.md) adds exact
source/IR/image budget metadata. Its current one-slot control request is 6,720
bytes plus a 664-byte inline Engine; maximum backing is 53,760 bytes. Programs
add 176,512 bytes (ordinary/output) or 176,448 bytes (input), plus actual literal
payload. Native development/O2 independently match these ledger charges against
SDK live allocations. Compiler scratch, VM/Instance totals and timing remain
outside these measurements; no original full-profile target is promoted.

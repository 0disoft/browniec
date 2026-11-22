# Performance Budget

- Status: Initial targets and one measured Windows embedding workload
- Scope: small reused runs, pure compilation, scalar loops, and retained builds

## Workloads

Benchmark small data validation, byte transform, rule evaluation, scalar loops,
Buffer growth, host request/reply, and compile/run reuse separately. Use fixed input
and observable output so dead-code removal cannot hide work. Record warm and cold
conditions and the build ID that produced each binary.

## Initial targets

| Metric | Target | State |
| --- | --- | --- |
| Reused small Instance setup | p95 at or below 1 ms | Met for one Windows embedding workload |
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
per-push suites. The Windows embedding benchmark below runs on demand.

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
bytes plus a 688-byte inline Engine after the compile successor; maximum backing
is 53,760 bytes. Programs
add 176,512 bytes (ordinary/output) or 176,448 bytes (input), plus actual literal
payload. Native development/O2 independently match these ledger charges against
SDK live allocations. The [compile successor](runtime-engine-compile-memory.md)
now enforces a conservative 256KiB lowering-heap reservation plus actual Index/
incoming backing under working/combined ceilings. VM/Instance totals, native
stacks, process RAM and timing remain outside these measurements; no original
full-profile target is promoted.

## Shared-byte rule reuse on Windows (2026-11-22)

The native C benchmark uses the revision-2 DLL from `90db042`. The 104-byte
rule reads a one-byte order amount and returns 3000 at 127 and 0 at 128.
Each profile ran three fresh host processes. Each process measured one first
compile, 201 subsequent compiles on the same Engine and 201 executions using
one retained Program. The benchmark checks the result on every execution.
With a quantum of 64, both inputs used 380,332 Fuel and reached a peak of
212,265 accounted bytes in every sample.

The ranges below come from the three process reports. Times are microseconds.

| Phase | Development median | Development p95 | /O2 median | /O2 p95 |
| --- | ---: | ---: | ---: | ---: |
| Subsequent compile | 3,924.9–4,202.3 | 5,209.8–6,143.9 | 997.1–1,098.7 | 1,540.9–1,658.5 |
| Reused Instance setup | 363.8–367.0 | 522.5–543.5 | 49.6–60.6 | 82.0–111.7 |
| Step to done | 5,434.5–5,519.4 | 6,528.1–7,736.7 | 1,097.9–1,162.3 | 1,392.7–1,939.1 |
| Destroy | 28.2–28.5 | 41.7–44.4 | 8.1–11.2 | 15.8–19.6 |

First compile took 6,620.8–7,030.7 µs in development and 2,149.1–2,640.0 µs
in /O2. Engine creation, DLL loading and file reads were outside the timed
intervals. One QPC measurement pair had a 0.1 µs p95. The host ran Windows
11 build 26100 on an Intel Core i5-8265U with MSVC 14.51.36231 and Windows
SDK 10.0.26100.0. The setup result applies to this nonempty input and policy.
The 10 KiB compile target, empty Instance memory target, process memory and
worker startup require separate workloads.

Build the preview with `python -B tools/build-embed-preview.py`. In either
profile's artifact directory, use the x64 MSVC developer shell to compile
[the benchmark](../../tools/bench-embed-reuse.c) against the generated
`brownie-preview.lib` and repository `include` directory. Match `/Od` or
`/O2` to the directory. Run `bench-embed-reuse.exe policy.json run.json`
three times. Raw reports and DLL hashes are in the local
`build/embed-preview-io6zkobo` artifact directory.

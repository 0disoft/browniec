# Performance Budget

- Status: Initial targets and measured Windows embedding workloads
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
| Empty Instance accounted memory | at or below 32 KiB | Missed: 186,440 bytes with no input or output |
| Warm scalar loop heap allocation | zero | Met for SDK heap across steps of the measured Windows loop |
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
The 10 KiB compile target, process memory and worker startup require
separate workloads.

Build the preview with `python -B tools/build-embed-preview.py`. In either
profile's artifact directory, use the x64 MSVC developer shell to compile
[the benchmark](../../tools/bench-embed-reuse.c) against the generated
`brownie-preview.lib` and repository `include` directory. Match `/Od` or
`/O2` to the directory. Run `bench-embed-reuse.exe policy.json run.json`
three times. Raw reports and DLL hashes are in the local
`build/embed-preview-io6zkobo` artifact directory.

## Empty Instance on Windows (2026-11-22)

On the same DLLs and host, append `--empty` to run a 45-byte rule that returns
77 with no input, output, or host calls. Each profile ran 201 executions in each
of three fresh host processes. Every execution used 345,090 Fuel and reached
187,688 peak accounted bytes. This exceeds the 32 KiB target by 154,920 bytes
(5.73 times the target). This is the Instance ledger peak, separate from DLL,
Engine and retained Program memory or process private bytes.

| Phase | Development median | Development p95 | /O2 median | /O2 p95 |
| --- | ---: | ---: | ---: | ---: |
| Subsequent compile | 2,313.9–2,730.8 | 3,245.3–3,900.7 | 478.6–539.5 | 676.8–882.5 |
| Reused Instance setup | 336.2–345.4 | 522.0–542.6 | 37.3–44.2 | 66.2–89.0 |
| Step to done | 4,609.5–4,964.7 | 5,922.6–7,431.9 | 959.9–1,002.9 | 1,275.0–1,780.3 |
| Destroy | 17.8–19.3 | 29.2–31.6 | 7.1–9.1 | 14.0–19.0 |

Times are microseconds. First compile took 4,880.3–5,326.4 µs in development
and 1,737.4–2,626.2 µs in /O2. The same harness still checks the original
shared-byte rule when run without `--empty`.

## Scalar rule loop on Windows (2026-11-22)

On the same DLLs and host, `--loop` compiles a 129-byte scalar rule that
sums 0 through 63. Each of three fresh processes per profile ran 201
Instances from one Program, alternating between quanta of 64 (101 samples)
and 1 (100 samples). All returned 2016, used 345,930 Fuel and reached
187,688 peak accounted bytes. The two schedules took 309 and 1,137
`bc_step` calls respectively, including setup and cleanup advances.

| Phase | Development median | Development p95 | /O2 median | /O2 p95 |
| --- | ---: | ---: | ---: | ---: |
| Subsequent compile | 5,360.8–5,424.7 | 6,135.3–7,094.7 | 1,361.5–1,976.0 | 1,646.5–2,771.8 |
| Reused Instance setup | 350.5–355.3 | 509.0–536.3 | 40.3–42.3 | 70.8–77.3 |
| Step to done, quantum 64 | 7,225.8–7,319.0 | 9,274.8–9,887.3 | 1,098.4–1,115.4 | 1,576.9–1,605.5 |
| Step to done, quantum 1 | 20,995.5–21,548.8 | 25,265.0–28,656.1 | 3,108.0–3,178.6 | 3,783.6–4,569.3 |
| Destroy | 20.6–20.7 | 32.3–38.8 | 4.8–4.9 | 13.5–16.0 |

Times are microseconds. First compile took 7,697.0–10,177.4 µs in development
and 2,561.1–3,784.6 µs in /O2. The event reports reservation peaks.
The same hosts also ran against the original DLL objects relinked with the
SDK heap observer. Each profile completed 201 more Instances with zero SDK
allocation attempts from the first step through the terminal event at both
quanta. Engine destruction left zero live SDK allocations. The probe starts
after Instance creation and covers SDK heap calls. It excludes OS allocations
and the host C runtime. Timing above uses the original DLLs.

```powershell
python -B tools/verify-embed-loop-allocations.py build/embed-preview-io6zkobo
```

The local allocation reports are in `build/embed-allocations-ofhf_qw8`.

## Pending Instance metadata reuse on Windows

Pending execution reads static sites and selected return origins directly
from the immutable, pinned Program. The Instance Core still owns mutable
static bindings, registers, and work state. Removing the two metadata copies
reduces the Windows x64 Core from 172,416 to 171,168 bytes. The same Core
stride determines both the allocation and its Engine memory charge.

The empty and scalar loop benchmarks each ran 201 Instances per Windows
profile with the SDK heap observer. Both peaked at 186,440 accounted bytes
per Instance, down 1,248 bytes from the baseline above. Results remained 77
and 2016, with 345,090 and 345,930 Fuel respectively. The loop took 308 steps
at quantum 64 and 1,136 at quantum 1, one fewer setup batch at each quantum.
Both workloads made zero SDK allocations during steps and left zero live
SDK allocations after Engine destruction. The empty Instance still exceeds
the 32 KiB target by 153,672 bytes.

The native Engine suite passed both profiles, including exact admission and
one-byte-short refusal, preparation allocation rollback, and output after
the caller releases its Program handle. The embedding C hosts also passed
both profiles. Local evidence is in
`build/runtime-engine/20261122T120431926885Z/receipt.json`,
`build/embed-preview-cdl9wkrx/receipt.json`, and
`build/embed-allocations-0u99y3ad`.

## Configured byte transform on Windows (2026-11-22)

The [unframe project](../cli/configuration.md#validate-and-unwrap-a-binary-payload)
checks a version byte and emits the 4,098-byte payload. The rejected case
passes a different version with the same payload size and receives empty
output. Each benchmark invocation ran 41 fresh CLI processes per case.
Three invocations per profile used the same Windows host as above and the
development and /O2 executables from the restricted worker verification
receipt `build/restricted-worker/20261122T104554561349Z/receipt.json`.
All 984 processes exited 0, wrote no stderr, and produced the expected JSON
and output bytes.

| Process | Development median | Development p95 | /O2 median | /O2 p95 |
| --- | ---: | ---: | ---: | ---: |
| Check | 60.121–60.600 | 70.068–77.327 | 49.477–50.286 | 63.342–66.065 |
| Reject version | 62.462–63.695 | 72.734–77.684 | 52.472–52.963 | 60.624–63.624 |
| Transform | 62.409–63.499 | 75.136–76.232 | 48.990–51.111 | 58.942–63.068 |
| Isolated transform | 325.070–330.765 | 368.691–398.774 | 257.176–263.596 | 282.913–308.417 |

Times are milliseconds, measured from before process creation to receipt of
stdout/stderr and process exit. The OS cache remains warm. The isolated row
includes Windows isolation setup, child startup, IPC, guest execution, output
publication and reaping. Per-phase latency and process memory require separate
probes.

```powershell
python -B tools/bench-cli-unframe.py --exe build/browniec.exe
```

# Native Buffer allocator-failure probe

Verified in development and release. Runtime sources are unchanged by this slice.
See the [Windows receipt](../evidence/m2-buffer-failure-windows-20261029.json).

The probe exercises actual [replacement transactions](m2-buffer-replacement.md)
through a one-shot target allocator failure. It closes the Allocation-path fault
injection gap of the preceding storage/replacement checkpoints; Provider
inconsistency injection is now covered by the focused
[Provider probe](m2-buffer-provider.md). The original results below retain their
Allocation-only scope.

The [append successor](m2-buffer-append.md) expands the current harness to nine
scenarios over five production modules, using allocator counters v2. The five-case
v1 receipt and unchanged-source claims below describe the original checkpoint.

## Build and instrumentation

Run `python -B tools/verify-m2-buffer-failure.py` on Windows with the configured
MSVC toolchain. `--profile development` or `--profile release` selects one profile;
the default runs both. Ambient CL/_CL_ overrides are rejected. The tool checks the
configured Fairy compiler checksum and revision, root locked check and SDK lock.

An isolated generated project receives byte-identical copies of
`buffer_growth.fy`, `buffer_storage.fy`, `buffer_owners.fy` and
`buffer_replacement.fy`, plus the committed probe main and manifest. Generated
copies are checked against their originals, and all selected inputs are rehashed
after execution. The generated project's SDK identity must match the root lock.

`probes/m2-buffer-failure/allocator_probe.h` adapts the M0 forced-include system
heap seam without changing M0 or the Fairy checkout. The header wraps target
runtime FY system-heap malloc/free calls, counts outstanding successful
allocations, and optionally returns NULL on the first request of exactly 320 or
384 bytes. Runtime environment variable `BROWNIE_BUFFER_FAIL_BYTES` selects the
failure size. The build override is confined to child build processes.

Each fresh process runs with an empty tool PATH. Its exit handler rejects
outstanding tracked allocations or an unexecuted requested failure and emits
allocator counters. The harness requires a successful probe line, the exact
counter schema, zero stderr and zero exit status. An absent instrumentation report
also fails verification. This counts the documented allocator seam rather than
all CRT/OS/process allocations.

## Recorded scenarios

Each profile executes these five cases using the same instrumented executable:

| Case | Required result |
| --- | --- |
| normal-min | Capacity 256 to 320, original `keep` bytes retained, next token committed |
| normal-preferred | Capacity 256 to 384, original bytes retained, next token committed |
| abandon | Prepared capacity 384 dropped before cancellation; old token remains valid |
| oom-min | First 320-byte allocation fails; Allocation returns; explicit retry commits 320 |
| oom-preferred | First 384-byte allocation fails; Allocation returns; explicit retry commits 384 |

Both failure cases check all 16 descriptors against their original snapshot,
original native capacity 256 and initialized bytes `keep`, and old-token reads.
The Plan stays inactive. Ledger usage restores to Instance 320 and Engine 352;
pending, old/new capacity and before-used fields are cleared. Observed peaks
remain 704/736 for minimum growth and 768/800 for preferred growth.

Each failure process reports exactly one injected failure and two target-size
attempts: the rejected request and the explicit successful retry. Returning a
successful fallback from the failed prepare would fail the fixture assertion;
no hidden retry is credited. Successful commit advances generation once,
invalidates the old token and finishes at capacity plus 64/96 for Instance/Engine
usage. Every case exits with zero outstanding tracked allocations, including
replacement abandonment and final owning-root cleanup.

## Evidence and limits

The receipt rechecks 11 selected input hashes, 5 generated source hashes, the
generated SDK lock and both instrumented executable hashes. Both profiles ran
from baseline `4651c20` with the new probe/harness uncommitted. Production Buffer
sources were unchanged; this is targeted failure-path evidence for those sources.

This probe does not re-run the prior 31 native groups or CLI sentinels, the full
M0/native/CLI suites, Linux, isolation, DLL embedding, packaging or elapsed-time
performance. It does not inject Provider inconsistencies, fail every allocation
site/size, measure total memory, or prove absence of leaks outside the wrapped
FY heap seam. Guest Buffer syntax/VM ownership and explicit root-publication
responsibilities remain unchanged. Prior receipts are historical for their inputs.

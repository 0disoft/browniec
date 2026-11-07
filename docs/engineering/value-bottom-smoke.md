# Optional bottom smoke

Run a quick execution check while changing retained-value source:

```sh
python tools/verify-value-bottom-smoke.py
python tools/verify-value-bottom-smoke.py --profile development
python tools/verify-value-bottom-smoke.py --profile release
```

The default runs development and release concurrently in disjoint locked native
mirrors. Each profile builds **one native image calling ten reviewed bottom
checks in order**, instead of ten isolated images. Native accounting remains one
passed driver with ten completed checks; it does not report ten native groups.

## Frozen inputs and selection

The tool snapshots current production sources, `fairy.toml`, `fairy.lock`,
`toolchain.json`, the original bottom test and the tool itself. It validates the
pinned compiler checksum, uses default stacks and rejects CL/_CL_/LINK overrides.
Production inventory is discovered from that snapshot rather than a fixed count.

The ten check names form an explicit allowlist. Missing/duplicate tests, effects
annotations and driver collisions reject before native work; new tests need an
intentional selection review. Comments and quoted guest programs cannot spoof
test declarations. Original test bytes remain an exact prefix; only an ordinary
same-module driver calling the selected functions is appended.

Each invocation creates a fresh directory under `build/value-bottom-smoke/`.
Read-only inputs, manifests, compiler identity, generated-driver hashes, exact
commands, logs and native reports remain there. Final checks compare against the
frozen snapshot even if another worker advances the source checkout. Receipts
distinguish incomplete/error/pass; exit zero requires every selected profile to
pass with empty process output and no native trap.

## Execution limits

This is an optional fail-fast smoke check. It shares process/allocator state,
adds a call frame and applies one default 60-second execution timeout to all ten
checks. A failed or interrupted run does not claim a completed-check count.
The separate 900-second compiler-command ceiling includes compilation.

Keep isolated depth, process, I/O, timeout and leak checks. This command does
not replace `tools/verify-value-bottom.py`, the default-stack 32/33 fixture or
full-profile/platform conformance. Build/execution invocations decrease from
ten to one per profile (90% fewer); no same-workload timing speedup was measured.

## Executed evidence

Tool `9981a13` passed development and release on the current
loop-integrated source. Each profile executed one driver and all ten checks;
the concurrent invocation took 43.897 seconds including locked preparation.
All 221 inputs match checkout and Git raw bytes. A separate tiny native fixture
on the same pinned compiler confirmed direct annotated calls execute in order
and propagate a late helper assertion; its one failure was expected. See
[focused evidence](../evidence/value-bottom-smoke-windows-20261107.json).


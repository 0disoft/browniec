# Reserved output with a shared VM meter

`runtime_output::open_metered(limit, allowed, remaining)` reserves a bounded
output Buffer once. `emit_metered` copies only the new bytes into its unused
capacity; it performs no allocation or prefix copy. `seal_metered` moves that
Buffer into a `Published` owner. Only the trusted invocation coordinator may
decide to seal after actual guest success. Failed/cancelled staging is discarded.

The shared meter records committed output preparation, emit and seal charges.
Every operation samples actual VM remaining Fuel instead of maintaining an
independent guest budget. An unsuccessful preflight changes no caller Fuel or
payload. The header's Fuel snapshot may reflect intervening VM work. Accumulated
charges and emit counts cannot wrap. Terminal observations freeze first.

The former `open`/`emit`/`seal` operations preserve their existing behavior and
cannot be mixed with metered reserved mode. `disabled()` owns empty Buffers and
allocates nothing; legacy VM paths can carry it without changed work/prices.
Its observation has phase 4 and all mutating/publication operations reject State.

New private Fuel prices are `prepare = 512 + 2*limit`, `emit = 512 + 2*length`,
`seal = 512`. A separate EMIT provenance lookup costs 8192 in the VM. No previous
instruction price, public default 256 or ceiling 16000000 changes.

`python tools/verify-runtime-output-metered.py` passed development and O2: all ten
unchanged I/O groups and eight new groups, actual generated layout/cleanup and
explicit allocation failures. A native observer verified 4096 emits of 256 bytes:
two allocations at open, **zero additional allocations at emit/seal**, exactly
1048576 payload bytes copied, and no live SDK heap allocations on exit. Output
operations cost 6292480 Fuel, leaving 9707520 from 16000000; this component probe
does not execute VM dispatch or charge its separate provenance lookups.

The [executed evidence](../evidence/runtime-output-metered-windows-20261107.json)
reuses the exact eight matching mirror inputs. Buffer remains 32 bytes,
Transaction 88 bytes and Published 72 bytes under the pinned Windows AMD64 SDK;
generated native guards verify those assumptions with default 1MiB/4KiB stacks.
The legacy I/O verifier's dependency copy and layout pattern were updated for
the additional reserved flag; its whole older command was not rerun here.

This is bounded synchronous staging, not complete Engine peak accounting,
bounded steps, OS sink delivery or external-effect rollback. VM success binding,
source/IR admission and owning Instance output transfer are separate successors.

# Reuse the authenticated remainder during slice cleanup

`array_slices::clear` drains retained slice handles on cleanup, and
`close_arguments` releases readonly CALL argument handles. Both already validate
the pool and stage metadata copies before committing. Previously each staged
close called the public `close`, which scanned the entire remaining pool again.

The private `close_prepared` now contains the unchanged close mutation logic.
The public single-handle `close` still resolves the ticket and validates the pool
before calling it. Cleanup loops reuse their initial full preflight. `clear`
selects only live slots; `close_arguments` still looks up each batch ticket in
reverse order, so a stale later ticket fails at the original point and discards
all provisional closes. Count, shape, duplicate and unused-tail checks remain.
There is no unchecked public API or validation cache carried across operations.

## Why the remaining pool stays valid

Retiring a shared handle with peers does not change its owner session. The last
shared handle ends that root session only after proving that no peer remains.
A writer was proven unique by the initial preflight, so ending it also leaves
no live handle referencing that session. Retirement resets the slot to canonical
inactive metadata and advances its ticket generation, saturating to zero at
exhaustion. Owner end APIs independently reauthenticate their table and epoch;
they change only session flags and epoch, never allocation order, extent,
generation or payload. Consequently every remaining view/lease is still valid
after each close, including epoch exhaustion. No callback or external mutation
can intervene in these synchronous private loops. Reverse close order, external
sessions, peers, rollback and original errors are preserved.

## Structural cost

Let V be the initial live handles, K the handles being closed, E the root
sessions actually ended, D the retained allocation depth and M=16 slots. In an
all-shared successful cleanup, the old pool validators ran 1+K times, requiring
V + K*V - K*(K-1)/2 full owner validations. The new pool validator runs once,
requiring V owner validations. Both versions also require E independent owner
end validations. Each successful owner validation visits D+M chain/slot entries.

For `clear` with V=K=E=16 and D=16, total owner validations fall from
16+136+16=168 to 16+16=32; chain/slot visits fall from 5376 to 1024 (80.95% less).
For a CALL batch with eight callers and eight children sharing the callers'
roots, V=16, K=8, E=0: owner validations fall from 16+100=116 to 16 (86.21% less).
At D=16 the corresponding visits are 3712 to 512. Pool validation calls fall
from 17 to 1 for the full clear and from 9 to 1 for the batch.

For a full shared clear the owner-validation portion changes from
O(V*V*(D+M)) to O((V+E)*(D+M)). Root-peer searches still cost O(V*M); mixed
writer conflict checks in the initial preflight are unchanged. No claim is made
that the entire cleanup becomes linear. The fixed staged metadata copies, Fuel,
quotas, reservations and payload access are unchanged. No stored field or heap
allocation is added. Counts describe source structure, not elapsed throughput,
machine instructions or physical stack/heap peaks.

## Focused verification

`tools/verify-slice-cleanup-preflight.py` selects six native groups. Frozen
2b4fe75 cleanup loops still call fully checked public `close`; the new paths are
compared for return values/errors, every pool and owner-table field, and every
batch entry. Failure must preserve both input tables and the batch. Healthy
tests cover occupancies 0..16, distinct readers, aliases of one root and mixed
readers/writers, ordinary and maximum ticket/session generations, offset/empty
ranges, and batch lengths 0..8 in two source patterns. Metadata tests vary every
slot with 20 fault modes at occupancies 1,8,16, including invalid unused-owner
metadata, stale tickets and short backing. A stale/out-of-range ticket at each
reverse-cleanup position tests rollback after earlier valid closes. Existing
tests cover copied batches, external sessions, both-mode epoch exhaustion and
actual CALL cleanup failures/eight empty arguments with exact Fuel.

Run development and release separately with the pinned compiler and default
native stacks. Receipts are under `build/slice-cleanup-preflight/<profile>`.
The first comparison fixture failed to compile because its copied `Slot` type
lacked the module qualifier; that attempt is incomplete, not passing evidence.
Full Engine, standalone memory, public CLI and release gates are outside this
focused change. No public admission or broader completion milestone is expanded.

Development and O2 each passed all six native groups in byte-identical locked
mirrors. All 378 receipt input hashes match implementation 10f45c8. See the
[evidence](../evidence/slice-cleanup-preflight-windows-20261115.json).

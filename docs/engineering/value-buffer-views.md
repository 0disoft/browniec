# Native Buffer view lifetimes

`value_buffer_views` adds invocation-local shared windows over the actual owning
Buffer store. It retains bytes in their original allocation and supports nested
ranges, aliases, logical binding moves, length/read/copy-out and explicit close.
This document records the native runtime kernel. The
[retained execution successor](value-view-execution.md) connects independent
IR/CFG proof and invocation-owned VM cleanup; the [source successor](value-view-source.md)
adds lexical bindings, ranges and nonlocal cleanup. Escaping reference
composition, public admission and complete Engine/Instance behavior remain.

## Ownership and authority

One Pool belongs to one exact `value_roots::State` and its owning root/scratch
vectors. Like the existing root state and UTF-8 bookkeeping, the Pool is native
copyable metadata: the trusted coordinator must not clone or transplant it,
mix stores or publish its tickets as guest authority. The retained verifier/VM
owns this association in the execution successor; a supplied numeric ticket is
insufficient.
The pinned compiler rejects mutable projections through user resource fields,
so this layer follows the existing runtime metadata convention.

The registry has 32 generation-checked rows over at most 16 native roots. View
bindings range from 0 to 511 in a separate lane from owning root bindings. Every
access authenticates its row generation/binding and exact live root serial,
logical owner binding, canonical owner slot/generation and native initialized
extent. No owning Buffer or native borrowed slice escapes this API.

The first view acquires the root's actual read lease through the authenticated
root-store bridge. Subsequent views, aliases and ranges share that lease. Their
windows contain absolute start/length; range endpoints are relative to their
actual parent. Subtraction checks admit empty end ranges and exclude overflow
before addition. Closing a parent does not invalidate a sibling or child.

Any live view, including an empty one, blocks root write, structural mutation,
move and drop through the existing writable gate. Extent-preserving no-op
reserve/append/write operations are blocked too. Other roots can still move or
be destroyed: dense vector compaction does not change the pinned serial/token.
Only the last same-root close ends the physical lease and permits mutation.

Logical view moves retain the ticket/generation but change its authenticated
binding. The old binding then rejects. Close increments the descriptor generation;
maximum generation retires its row as zero rather than wrapping. Failed range,
binding, quota, Fuel and slot admissions publish no descriptor or new lease.
Already accepted Fuel charges remain spent.

## Accounting and cleanup

Opening a Pool admits 4096 logical metadata bytes to both Instance and Engine
usage through `value_roots::State.external`. This is a policy charge, not a
native sizeof/RAM claim. The root store validates base metadata + external
metadata + actual owner charges with checked arithmetic. External refund cannot
refund base/root charges. Existing callers start with external zero and keep
their previous prices and accounting behavior.

Opening prepays bounded lifecycle cleanup. Close and shutdown need no remaining
guest Fuel. Shutdown closes all rows, releases each last root lease, refunds
the registry's metadata and marks the Pool closed. Repeated shutdown is harmless.
A failed close keeps its row for explicit repair/retry. The root store refuses
to drain while external metadata remains, before destroying any root; the
coordinator must shut down attached registries first. The execution successor
wires this order into retained invocation completion/failure. Complete Instance
teardown and cancellation dispatch remain broader lifecycle work.

Native policy charges for successful operations are:

| Operation | Fuel |
| --- | --- |
| Pool metadata admission | 256 |
| First view on a root | 512 + 256 root lease |
| Further view / alias / range | 512 |
| Logical binding move / length | 256 |
| Read one initialized byte | 256 + 257 root read |
| Copy out the complete n-byte view | 256 + 256 + n root copy |
| Close / shutdown | Prepaid; no new Fuel |

Length and metadata operations use bounded tables; duplicate-row checks examine
at most 496 pairs. Read accesses one byte. Copy-out performs O(n) work only after
the root precharges it, into distinct caller-owned storage with exactly the view
length. There is no input-sized staging allocation and no per-view payload copy.
Existing opcode prices and public Fuel default256/ceiling16000000 are unchanged;
these native costs do not advertise a new executable instruction profile.

## Verification and remaining integration

Implementation commit: `34863b5`. Run
`python -B tools/verify-value-buffer-views.py --batch views --profile development`
and the release counterpart; select `--batch vm` for affected root/frame/copy
regressions. The four batch/profile combinations use separate locked native
mirrors and outputs. `--discover` lists the exact identities without writing.

Both Windows profiles passed 19 groups: ten registry/lease/root groups and nine
root-operation/frame/source-copy regression groups. The five new groups execute
actual bytes, relative and empty windows, aliases after parent close, unrelated
root compaction, mutation/no-op/move/drop exclusion, last-close restoration,
exact staged Fuel failures, output preservation, quota admission/refund,
descriptor exhaustion/reuse, and zero-Fuel shutdown before root drain. Trusted
native metadata injection reaches maximum generation and proves permanent slot
retirement; it does not assert guest access to native metadata.

All 219 union inputs match checkout and Git raw bytes; all 208 production modules
are LF. Each batch hashes its own selected tests, with identical production/tool
inputs across all four runs. No native overrides or historical reuse were used.
The existing conditional-depth fixture stays byte-identical but was not selected
here. See [Windows evidence](../evidence/value-buffer-views-windows-20261107.json)
and [input manifest](../evidence/value-buffer-views-inputs-windows-20261107.json).
Actual allocator/OOM injection, full language/public CLI/native Fuel matrices,
Linux, general stack/performance and clean-machine delivery were not run.

The [execution successor](value-view-execution.md) now supplies Buffer-backed
view-origin IR, independent CFG proof, retained VM binding storage and terminal
cleanup. The [source successor](value-view-source.md) adds lexical/nonlocal cleanup
and `bytes::view`/ranges. Next: copy-from-view, general reference composition and
intentional public admission. The native-only registry tests recorded above cannot establish
the successor's execution behavior; its own evidence records that scope.
Public AllocError, text/input/output, full Engine/Instance/host behavior, isolation,
platform/delivery and broader validation remain part of the full objective.

## One header preflight for view shutdown (2026-11-16)

Compared with 79e86d0, shutdown previously checked the complete registry header
and then called public close for every live row. Each close repeated the same
quadratic header check as part of its resolver. Successful close only retires
the selected row to the canonical blank representation; removing a row cannot
introduce duplicate bindings or conflicting same-root identities. Thus every
successful retirement preserves the initial header invariants.

Shutdown now uses its initial complete header check for the entire sweep. Each
row still authenticates its exact ticket, binding, root serial/token/backing,
physical lease and initialized window through the private `resolve_prepared`.
The private `close_prepared` factors the unchanged sibling scan, last-sibling
lease release and canonical retirement. Public close retains its full resolver.
Root leases can change during the sweep, so no root authentication is reused.
No public unchecked API, persistent proof, cache, state or heap allocation is added.

For N initially live views, full header checks fall from 1+N to one. With all
32 rows live, ascending retirement previously performed 496 initial live-pair
comparisons plus sum(k*(k-1)/2, k=1..32) = 5456 more: 5952 in total. It now performs
496, removing 5456 (91.7%). Header outer-row visits fall from 1056 to 32. Worst-case
registry cleanup work falls from O(C^3) to O(C^2) for registry capacity C,
including the retained per-row sibling scans. Per-row root authentication,
last-sibling releases and final metadata
refund remain separate and unchanged. These are source-operation counts, not
measured throughput or physical memory peaks; the fixed limits remain 32 views
and 16 roots.

The sweep keeps ascending slot order, exact errors and partial progress on a
late failure. A failing row remains live, earlier successfully closed rows stay
retired, and metadata is refunded only after every close succeeds. Maximum
view generations retire as zero. Closed-pool idempotence, prepaid zero-Fuel
cleanup, root bytes and owning vector positions/capacities remain unchanged.

Run `build/toolchain/fairyc.exe check`, followed by
`python -B tools/verify-value-view-shutdown.py --profile all`. Five selected native
groups include an independent pre-change close/shutdown oracle over 2101 cases.
The fixture uses 16 actual roots and checks healthy view counts 0..32, 16 metadata
variations at every slot for counts 0/1/8/32, and five root faults at those counts.
Every comparison checks the exact result/error and complete pool/root state,
including owner tables, ledger, closing plan, metadata balance and generations.
All root bytes and vector capacities are checked too. A separate late bad-window
case proves exactly one row/lease remains and a repaired retry completes.
Successful and already-closed cases verify idempotence; the original fixture
shuts down and drains at zero remaining Fuel. Existing groups cover direct close,
parent/child aliases, lease exclusion, generation retirement, quota refund and
actual frame CALL/selected-range RETURN cleanup.

Windows development and release each passed five native groups on cdc76c7.
All 376 tested input hashes match that implementation commit and the Git index.
Execution results and exact implementation/input identities are recorded in the
[Windows evidence](../evidence/value-view-shutdown-windows-20261116.json).
Full Engine transport, retained/source CALL integration, public CLI, standalone
memory and full release gates are outside this focused change. Known legacy
compiler and stack failures are not claimed fixed; broader completion stays paused.

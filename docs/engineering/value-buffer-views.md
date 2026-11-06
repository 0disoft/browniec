# Native Buffer view lifetimes

`value_buffer_views` adds invocation-local shared windows over the actual owning
Buffer store. It retains bytes in their original allocation and supports nested
ranges, aliases, logical binding moves, length/read/copy-out and explicit close.
This is native runtime storage, not source syntax, retained IR admission, a guest
handle API or an Engine/Instance completion claim. Those integrations remain.

## Ownership and authority

One Pool belongs to one exact `value_roots::State` and its owning root/scratch
vectors. Like the existing root state and UTF-8 bookkeeping, the Pool is native
copyable metadata: the trusted coordinator must not clone or transplant it,
mix stores or publish its tickets as guest authority. The eventual retained
verifier/VM must own this association; a supplied numeric ticket is insufficient.
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
coordinator must shut down attached registries first. Automatic Instance teardown
and failure/cancellation dispatch still need this ordering wired into the VM.

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

Next connect Buffer-backed view origin/loan IR, independent CFG proof, canonical
retained VM/frame storage and transfers, lexical/nonlocal cleanup, source
`bytes::view`/ranges/copy-from-view, general reference composition and intentional
public admission. Native-only registry tests cannot establish these capabilities.
Public AllocError, text/input/output, full Engine/Instance/host behavior, isolation,
platform/delivery and broader validation remain part of the full objective.

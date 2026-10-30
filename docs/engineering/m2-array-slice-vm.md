# Private metered array slice instructions

The [source successor](m2-array-utf8-slices.md) now exposes lexical read-only
u8 slice bindings and UTF-8 scans with reverse-order scope/exit cleanup. Guest
indexing, length, reslicing, aliases, parameters/results and temporary roots
remain unavailable. The private backend contract below is unchanged.

Implementation: `272f359`.

The private IR/VM now connects the [shared slice registry](m2-array-slices.md)
to independently verified function-local origins. Guest slice syntax, automatic
lexical exit lowering, slice parameters/results, subslice/read/length instructions
and a public capability remain pending. Existing source forms and Fuel prices
are unchanged.

## Representation and instructions

`Program.slice_roots` contains sixteen origin entries: zero is unused; otherwise
the value is the array catalog ID plus one. The root determines the function and
scalar shape. There are at most sixteen static slice sites per program, sixteen
live registry entries per invocation, and thirty-two VM frames. A frame-local
512-entry ticket map holds sixteen site positions for each frame; it does not
raise the live-entry limit. No guest pointer, payload copy or extra owner is added.

All instructions retain the private eight-byte encoding. Bytes 4..7 must be zero.

| Opcode | Operands | Fuel |
| --- | --- | --- |
| 54 open | dst=slice site, a=start usize register, b=end usize register | 65537 |
| 55 UTF-8 | dst=fresh bool register, a=live u8 slice site, b=0 | 4097 + 4*N |
| 56 close | dst=live slice site, a=b=0 | 4097 |

N is the complete origin length, not the selected range length. These are
conservative logical prices for bounded metadata work. Open also prepays deferred
abort cleanup; cleanup does not require another Fuel allowance. This is not a
claim that one unit corresponds to one CPU instruction or measured elapsed time.

Open accepts all six existing scalar-array tags; only u8 slices support opcode
55. Bounds are ordinary already-evaluated usize registers. Every operation
prepays its price before semantic endpoint/ticket/payload reads and publication.
Bounds use the existing unpacker and checked descriptor API: reversed,
out-of-root and maximum-unsigned endpoints fail without publishing a handle.
Empty u8 ranges scan as true after validation and pay the same full-root price.

## Independent verification

The existing 64-bit owner live state uses bits 0..15 for arrays and 16..31 for
records; slices occupy bits 32..47. This reuses the existing exact-state branch
merge and backedge proof without another per-PC state table. Origin metadata is
validated even when unused. Each instruction must reference a declared origin
owned by the current function and a live root. Open requires a dead slice site
and readable, nonslot usize bounds within the function's register partition.
UTF-8 requires a live u8 slice and a fresh bool result. Close requires a live
site and canonical operands.

Outstanding slices reject root write, fill, destination assignment, release,
and result transfer before execution. Independent value copies remain allowed.
Scalar/aggregate returns require balanced close instructions and ordinary owner
cleanup; an active descriptor cannot escape. Branch merges and loop backedges
must preserve the exact slice set. Terminal internal failures may retain slices
because invocation cleanup handles the failing path. Origins are never accepted
from scalar cells or caller-provided source metadata.

## Runtime and cleanup

The runtime retains one registry ticket per frame/site and checks the actual root
token, generation, scalar tag and original length against the Program origin.
The registry then revalidates all retained sessions/descriptors and backing
bounds. Handles from another frame, stale tickets, missing backing and forged
shape/padding fail before writing result registers or publishing state. Multiple
sites on one root share its session; the last close unlocks it. A full registry
returns the existing resource-limit kind 13 before acquiring another root lease.
Bounds use kind 14, insufficient Fuel kind 8, and malformed VM state generally
kind 5. Error offsets follow the instruction's source offset.

`vm.run_with_array_limit` executes its loop behind an invocation cleanup boundary.
Both successful and failing outcomes pass through `slice_vm.finish`, which clears
all registered sessions across frames and then invalidates the entire ticket
map. Successful cleanup preserves the original return value or error/offset,
including Fuel exhaustion. Cleanup does not release owner descriptors, alter
payload/arena use or roll back external effects. Payload destruction remains the
existing Buffer lifetime behavior.

If native metadata corruption prevents cleanup, the cleanup error at offset zero
replaces the original outcome and retained metadata is not silently discarded
by the helper. Native callers must repair that invariant before explicit retry;
there is no hidden retry or guarantee of recovery from arbitrary native writes.
The wrapper's local state then ends with the invocation. Caller-owned external
sessions and table/backing association remain native integration obligations.

The registry's ordinary O(D*O), scan O(D*O+K) and clear O(D*D*O) bounds still apply
with D=O=16 and K<=4096. The ticket map adds 512 fixed metadata entries; cleanup
invalidates at most 512 tickets. This adds fixed native state and work, including
on source programs that cannot yet construct slices. Allocator/process-memory
instrumentation and timing measurements were not performed. There is no scheduler
cancellation integration or public retained borrow contract in this slice.

## Focused verification

Run `python -B tools/verify-m2-array-utf8.py --profile development --slice-vm`
and repeat with `--profile release`. Each profile passed 39 native groups: eight
new slice VM groups, seven registry, five sessions, five dynamic UTF-8, six array
result VM and eight struct VM groups. Each passed fourteen tool-free CLI sentinels,
including scalar/array/record behavior and honest guest slice/Buffer rejection.

New coverage includes exact per-op Fuel boundaries, a 73870-Fuel four-byte full
VM fixture with a four-byte arena, post-open Fuel failure, empty and unsigned
invalid bounds, all sixteen live-state bits, forged origins/operands/types,
function-local registers, branch/loop state agreement, root conflict gates,
allowed copies, stale/frame-mismatched handles, short backing, global registry
quota, all-frame cleanup preserving an injected error, and retryable cleanup
failure under native fault injection. Internal call execution is covered as well.

The [Windows evidence](../evidence/m2-array-slice-vm-windows-20261030.json) records
both profiles, matching input hashes, compiler/SDK identity, native reports,
original receipt hashes and retained CLI hashes. Full suites, other source CLI
matrices, M0, Linux, DLL embedding, Windows isolation, packaging, allocator
instrumentation and timing benchmarks were not rerun.

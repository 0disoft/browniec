# Native Buffer operations in the typed value store

The typed value coordinator supplies authenticated length/read/write, append,
push and reserve over its actual native Buffer allocations. This extends the
previous empty/move/drop bridge with byte operations. It does not define a
replacement guest API or promote public source, capabilities or ABI availability.
Source ref/ref-mut lifetime proof, allocator-error Result types, bytes views and
input/output composition remain separate required integration work.

## Identity, mutation and quotas

Every access authenticates the declared Buffer type, live activation generation,
canonical serial word and store-local binding against the real allocation.
Native methods return metadata/bytes rather than an escaping view. Writes stay
inside initialized length. Reserve retains length; append initializes new bytes.
Successful length/capacity changes advance the owner generation while preserving
the store serial, logical binding, frame word and initialization order. Content
writes preserve extent/generation. No native ownership authority comes from bytes.
Shared native read leases permit length/read/copy-out; all mutations, including
empty append and reserve within existing capacity, require writable ownership.

The two owning vectors remain one invocation-local store. Content-only writes
borrow the authenticated vector element directly. Operations that replace or
transfer ownership still use pre-reserved vector transfers to expose a local
mutable root without unsafe resource-field projection.
Growth uses the existing old-plus-new capacity/owner reservation and exact
minimum-capacity fallback. It stages a separate allocation, destroys the old root
before refund and publishes the new generation only after success. Rejected
preparation preserves the old data/root and settled accounting. Allocator failure
is distinct from hard quota and Fuel errors; no allocator retry is introduced.
Frame wrappers subtract their admitted backing/metadata from root quota limits.
Commit is preflighted against disposable metadata before replacement. A provider
invariant failure after bytes change is fatal rather than a recoverable rejection
with changed data. The trusted SDK/provider remains part of this kernel boundary.

Input borrows are trusted native, distinct storage; no guest self-aliasing view is
admitted by these methods. Source operations still need borrow/selected-place
proof before publication. Low-level native APIs are not guest handles.

## Fuel and validation

Root length/read cost 256/257. Content write costs 256+n. Reserve costs 2048+4L;
append costs 2048+4(L+n), where L is old length and n is input length. Reserve and
append first charge metadata 256, authenticate the root, then prepay the remaining
payload price before mutation. Frame wrappers add existing operation_cost(8),
2080, before address/root authentication. A failed second Fuel admission keeps
the metadata charge already spent; it leaves root/data/accounting unchanged.
New kernel prices do not change existing instructions or public Fuel
256/default and 16000000/ceiling. These prices bound charged work; resumable
work quanta, general stack/performance and full Engine/Instance integration remain
open.

Run `python -B tools/verify-value-buffer.py --batch roots --profile development`
and its frames/release counterparts. Windows development/release each passed ten
native groups on `a0cde3c`: three new and two regression groups in each disjoint
roots/frames batch. All 210 inputs match checkout/Git canonical bytes (209 raw); all 201 production modules are LF.
The one raw-byte difference is the verifier checkout CRLF versus Git LF; exact
executed runner bytes and both digests are recorded. Production/test mirrors are
byte-identical and were checked before/after each fresh run, with no native
stack/compiler override or historical result reuse. See the
[Windows evidence](../evidence/value-buffer-windows-20261107.json) and
[input manifest](../evidence/value-buffer-inputs-windows-20261107.json).

The existing 32/33 conditional-depth fixture is byte-identical; its runtime group
was not rerun by this kernel selection. Public CLI/full language/native Fuel
matrices, Linux, OOM injection, general stack/performance and clean-machine
delivery remain separate obligations. The [private instruction successor](value-buffer-execution.md) now connects
independent proof/dispatch and prepaid allocator Results. Source methods/borrows/
views, public AllocError types and I/O remain implementation work. Local only; no push,
release or deployment.

## Shared two-root append preflight (2026-11-16)

Compared with 7a540e2, `append_from` and `append_window` each performed a complete
store preflight while resolving the destination, then repeated it while resolving
the source. No store/vector mutation or callback occurs between those lookups.
Both paths now run `ready` once and use the module-private `resolve_prepared` twice,
before Fuel remainder admission, destination extraction or append publication.
The ordinary resolver still starts with a complete `ready` for independent calls.

The complete preflight and exact operand resolver bodies are unchanged. The
destination retains writable authentication; the source permits an existing read
lease while retaining exact serial/binding/token/backing authentication. Same-root
rejection, subtraction-based initialized-window bounds, error priority, Fuel,
source selection in either vector, restoration and append transactions remain.
No public unchecked interface, persistent cache, allocation or production staging
copy was added. Prepared lookup is valid only for the same unchanged store and
vectors within the synchronous operation.

For R live roots, the duplicated preflight's R*(R-1) live-pair comparisons become
R*(R-1)/2. At R=16, full preflights fall from two to one, primary root-row visits
from 32 to 16, and live-pair comparisons from 240 to 120 (50% fewer). Both exact
operand lookups remain. Overall preflight complexity remains O(R^2), with R<=16;
the improvement removes duplicate work, not an asymptotic bound. Fuel prices,
payload copying and allocator policy are unchanged. Throughput and physical
memory were not measured.

Run `python -B tools/verify-value-root-append.py --profile all`. The selection
includes two original-preflight comparison groups plus standalone root resolution,
root leases, Buffer appends and view-window copy regressions. The oracle retains
the original two full resolutions and delegates the unchanged append transaction
to standalone append with test-only copied input. Its comparison covers exact
results/Fuel, all state/table/ledger/close-plan fields, every retained byte and
vector capacity/order.

Development and release each passed all eight selected native groups on
343e209, including 240 successful/boundary cases and 1420 slot-fault/error-priority
cases against the original preflight. All 378 input hashes match both profiles,
the working files, Git index and implementation commit; all 367 production files
retain LF. The initial test-fixture type failure is retained separately and is
excluded from passes. See the
[Windows evidence](../evidence/value-root-append-windows-20261116.json).

Full Engine transport, public CLI, Linux, OOM and full release gates remain
outside this local slice; legacy compiler/stack failures are not claimed fixed.

## Direct content writes (2026-11-16)

Compared with 524ca70, `value_roots::write` no longer extracts the selected
owning Buffer, moves its vector tail into scratch, and restores that tail after
`buffer_write::within_length`. Content writes change neither the Buffer's length
nor capacity, token, binding or allocation. After the unchanged writable root
resolution, the method passes `vec::at_mut(roots, i)` to the unchanged write
kernel. The exclusive borrow ends within the call and no native view escapes.

For n roots and selected index i, extraction/restoration formerly made
`4*(n-1-i)+2` vector push/pop calls, including on range/quota rejection after
authentication. Direct borrowing makes zero such calls. With 16 roots, writing
the first root removes 62 calls per operation; 4,096 one-byte writes remove
253,952 calls. Selecting the buffer changes from O(n-i) transfer work to O(1).
The complete operation still includes O(n^2) root preflight and O(m) byte writes
for m input bytes. Both implementations allocate nothing during content writes;
throughput and physical memory were not measured.

Fuel remains `256+m`. Read leases still reject writes including empty writes;
the original owner, backing, quota and subtraction-based range checks and error
mapping are retained. Other ownership-changing operations keep their existing
transfer paths.

Run `python -B tools/verify-value-root-write.py --profile all`. Nine selected
native groups cover all sixteen target positions against the counted original
transfer sequence, 240 boundary/identity/Fuel/quota/lease/generation comparisons,
4,096 exact-price one-byte write pairs, empty native buffers, metadata faults,
growth/retirement regressions and actual frame writes. Payload checks include
all roots and untouched bytes, vector order/capacity, settled accounting and
zero-Fuel cleanup. Results and input identities are recorded in the
[Windows evidence](../evidence/value-root-write-windows-20261116.json). Full
Engine transport, public CLI, standalone memory and full release gates remain
outside this change; known legacy compiler/stack failures are not claimed fixed.

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

The two owning vectors remain one invocation-local store. Pre-reserved vector
transfers expose a local mutable root without unsafe resource-field projection.
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
delivery remain separate obligations. Source Buffer instruction/borrow/Result/
view and I/O integration remains implementation work. Local only; no push,
release or deployment.

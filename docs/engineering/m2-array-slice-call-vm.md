# Private metered borrowed-frame adapter

Implementation: `c70abfa`. `slice_call_vm` adds prospective native
CALL admission and frame cleanup for borrowed u8 slices. It uses Programs that
passed [independent flow inspection](m2-array-slice-borrow-flow.md). Admission is now
connected through the [gated CALL frame adapter](m2-array-call-frame-vm.md);
the later [shared lifecycle](m2-array-slice-lifecycle-vm.md) connects automatic cleanup. The existing execution gate, CLI behavior,
opcodes, Fuel prices and version capabilities remain unchanged.

## Frame origins and provenance

The separate `Frames` context has 256 owner-token entries: eight formal ordinals
for each of 32 frames. Derived sites share their formal's binding instead of
allocating another root entry. Slots/generations are copied without truncation.
Bindings remain available after the formal ticket closes, until frame cleanup,
so a retained child can be validated and forwarded without a live anchor ticket.

The VM now creates one context per invocation for gated CALL admission.
There is no change to Program or `slice_vm.State` fields. Its native layout/process-memory cost has
not been measured. It is bounded metadata, not payload storage or an owner of
backing bytes. No new owner, payload copy/scan, root read session or runtime heap
allocation path is introduced by admission.

The `root` helper resolves an owned local site through its frame's array token,
or a borrowed/derived site through the same-function formal ordinal. Admission
also validates the actual retained range ticket against the original pool and
owner table, compares its root slot/generation with this binding, and requires
u8 with a valid original length in 1..4096. An empty selected range remains valid.
Owned local root lengths must agree with their Program catalog shape.

These are private, invocation-local native structures. Callers must supply the
actual parent frame and an immutable inspected Program. They are not authenticated
guest/host handles or a public ABI.

## Metered admission

`cost` reads only bounded signature metadata. With B borrowed formals, it returns
zero when B=0 and `65537 * (B + 1)` otherwise. One fixed reserve covers eventual
frame cleanup; each borrowed formal reserves conservative retention work. This
is the adapter's additional private charge, not a complete CALL price. Existing
base/scalar and owned aggregate copy prices must be added by future integration.

Examples are 131074 for one borrow, 196611 for two and 589833 for eight.
`enter` checks this entire charge before frame, ticket, backing/session resolution
or table mutation. Insufficient Fuel returns kind 8; parent frame 31 or beyond
returns kind 12 after the Fuel check. Source errors use the CALL's source offset.

For borrowed admission, the child frame's sixteen ticket entries and eight root
bindings must be
canonical empty. Each borrowed source must be encoded as 160..175, belong to the
CALL's caller function and match its checked runtime root. All incoming tickets
are validated against the original pool before any child is published. The
existing atomic argument-borrow primitive stages the pool and retains a whole
selected range per formal. Only after the entire batch succeeds are child tickets
and root bindings published. Duplicate arguments receive independent tickets.

Late stale/fabricated inputs, non-u8 or mismatched roots, backing failures,
occupied child entries and pool exhaustion preserve all original metadata.
Registers, return-frame state, owned argument tokens and payload bytes are not
modified by this adapter. In particular, accepting a signature with mixed kinds
does not copy or validate its scalar/array/record payload arguments.

## Prepaid atomic cleanup

`leave` requires an admitted non-entry frame and its declared function. It
validates all formal root bindings, stages the pool and owner table, and closes
live frame tickets in reverse static-site order. Shared read handles do not need
allocation-stack order. Owned local sites retain their catalog element shape;
borrowed formals/derived sites remain u8. A closed formal's binding still permits
its retained children to be checked.

Only after every close succeeds does cleanup publish the staged tables and clear
all sixteen frame ticket entries and eight origin bindings. Late stale or
duplicate handles leave both tables and all frame bookkeeping unchanged for
diagnosis/corrected cleanup. Caller/peer tickets survive; only the final handle
on a root ends its read session. No array owner is freed by this operation.
Reusing the child frame is safe after successful cleanup.

Cleanup uses the reserve prepaid by successful admission. This is a private
primitive, not an independently metered arbitrary host cleanup service. Automatic
VM return/error/cancellation paths and preservation of an original VM outcome
were not connected in the original checkpoint. The later
[shared lifecycle](m2-array-slice-lifecycle-vm.md) now connects them and shares
the staged pool drain with invocation cleanup.

## Bounds and remaining integration

B<=8, 32 frames, sixteen sites/handles/owners and the existing 128 register
positions remain bounded. Admission scans at most sixteen function partitions,
sixteen child ticket entries, eight child origins and eight parameters. Rootless
lookup scans at most eight formal positions. Registry validation retains bounded
pool/owner scans. Cleanup stages fixed metadata tables and visits sixteen sites.
No unbounded traversal or payload copy is added; timing and allocator/process
memory instrumentation were not run.

A [private mixed CALL successor](m2-array-mixed-call-vm.md) now combines borrowed
admission with owned array/record copies before the mixed operation succeeds.
It separates retention preparation from publication and leaves registers and
return-frame state outside that boundary. The [CALL frame successor](m2-array-call-frame-vm.md)
now publishes those registers and return tables after mixed success. The
[dynamic slice adapter](m2-array-slice-frame-vm.md) resolves runtime roots privately;
the [shared lifecycle](m2-array-slice-lifecycle-vm.md) now connects its instruction
dispatch and normal/error cleanup. Until public admission is promoted,
every borrowed Program remains rejected by public execution verification and
CLI check/run. No public source capability or public forwarding/recursion
execution is claimed here.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --slice-call-vm`
and repeat with `--profile release`. Each profile selects sixteen native groups:
four frame-adapter, four registry-batch, five independent-flow and three subslice
VM groups. CLI regression selects 326 tool-free invocations: 74 gated-source,
120 aliases, 124 subslices and eight ordinary/unsupported-Buffer sentinels.
Both profiles passed at `c70abfa` with 333 matching input hashes. That receipt
is historical for shared adapter, lock, test and tool inputs changed by the mixed
CALL successor. Its original checkout bytes matched both receipts; committed
text matched after CRLF-to-LF normalization.

Coverage includes non-dense mixed formal ordinals, duplicate ranges, exact Fuel,
unchanged caller storage/owned tokens, frame reuse, retained-child forwarding
after anchor close, two nested native frame contexts, Fuel-before-backing/frame
ordering, dirty child state, a late fabricated future ticket, partial pool
capacity, late duplicate/stale cleanup failures, stale origin generations and
eight independent empty retained ranges. Native setup/adapter calls do not
execute a guest CALL; executable VM rejection remains explicitly checked.

See the [Windows evidence](../evidence/m2-array-slice-call-vm-windows-20261031.json).
Full suites, other CLI matrices, M0, Linux, DLL embedding, isolation, packaging,
allocator instrumentation and timing benchmarks are outside this selection.

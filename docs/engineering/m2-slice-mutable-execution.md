# Private mutable slice CALL execution

Mutable scalar-slice formals now execute through the same `vm_execution` core as
existing public scalar, owned aggregate and readonly slice programs. This joins
the [frame transaction](m2-slice-mutable-call-vm.md), authenticated formal
instructions, scalar/control publication, normal returns and invocation abort
cleanup. Native integration tests perform actual writes through mutable CALLs.

Public `verify` still rejects rootless exclusive formals after the complete proof
and before VM backing, Fuel or dispatch. Guest mutable parameter grammar, public
CALL admission and a parameter capability flag remain unavailable. The source
compiler and CLI keep their existing public behavior. No opcode, Program field,
profile or public/readonly instruction price changes.

Implementation: `f22a6da`.

## CALL publication and the shared core

`call_frame_vm` now shares immutable scalar/control preflight and infallible
publication between its existing `step` entry and private `step_mutable`. Both
validate full charge, frame bound, register/control spans, result destinations
and every scalar source before an owner/loan transaction. Only up to eight scalar
snapshots are staged. Borrowed and owned formal positions never become scalar
cells. Late copy/loan errors leave scalar registers and return metadata unchanged.

The mutable entry delegates mixed owner/loan admission to the existing staged
adapter, then publishes scalars and return PC/destination with no remaining
fallible work. The existing entry still uses the legacy readonly cost/admission
path and retains its signature. Its native regression tests remain applicable.

`execute_mutable` accepts exactly 32 initialized unique invocation-owned receipts.
The caller must inspect the immutable Program first, own all supplied state and
call `slice_mutable_call_vm::finish` for every result. The core borrows this
collection; it does not copy receipts. Mutable destinations use `step_mutable`;
ordinary/readonly destinations keep `step`, including readonly helpers called
from an active mutable frame. Each active mutable frame uses its own depth index.
Fuel admission still precedes the depth32 overflow error in the coordinator.

The existing `execute` API passes an empty receipt view and cannot admit mutable
CALLs. One inert native receipt backs that empty view, avoiding the complete
32-receipt collection for ordinary invocations. This is a source-level structural
fact, not a measured native stack or memory claim. Both APIs call one shared
instruction loop.

## Authenticated formal instructions

`slice_mutable_frame_vm::step` handles rootless exclusive read, write, length,
u8 UTF-8 and close. Open and derived/subslice instructions remain invalid.
The adapter checks function/frame/site, operand spans, reserved bytes and exact
scalar tag before using the invocation receipt. `slice_mutable_call_vm::view`
authenticates the live binding, original root/range/write epoch and current
monotonic ticket generation. Detached formals cannot execute further accesses.

Read costs `4130 + width`; write costs `4130 + 2*width`; length/close cost 4097.
UTF-8 prepays 4097 for metadata resolution, then the complete
`4097 + 4*full_origin_length` before scanning the selected range. One-short Fuel
preserves payload, destination registers and ticket state. Scalar/bounds failures
also precede payload publication. Close invokes binding release, keeping the
owner write session and detached capability alive until return restoration.
These are the existing instruction prices; mutable CALL itself keeps its private
prepaid transfer/restore formula from the preceding adapter stage.

## Return and failure lifecycle

Scalar, tagged, array and record return paths use the same per-frame leave
selector. An active mutable receipt stages ordinary child closes and fresh
caller restoration before clearing child bindings; ordinary frames keep the
existing lifecycle adapter. Restored callers can immediately read, forward or
close their own slice. Aggregate owner result transfer retains its existing
checks and prices. Normal source-lowered owned cleanup remains unchanged.

Guest recursion uses the bounded VM frame arrays. 31 nested mutable calls can
reuse one exclusive pool slot and owner; the next call reports the frame limit
when enough Fuel remains. Mutual calls, repeated frame reuse and shared children
preserve the correct receipt and origin maps.

On error the core retains invocation state for diagnosis. Mutable finish drains
all live/detached sessions, clears roots/receipts after success and preserves the
original error/result and prior writes. Failed cleanup retains metadata and
surfaces the cleanup error. No automatic retry or payload rollback is added.

## Verification and next delivery

```text
python -B tools/verify-m2-slice-elements.py --profile development --mutable-execution
python -B tools/verify-m2-slice-elements.py --profile release --mutable-execution
```

Six new native groups cover all scalar widths and actual write/read/restore,
exact/one-short formal instruction prices, selected u8 UTF-8, formal release,
scalar/control preflight, late owned copy failure, depth32/depth33, mutual and
reused frames, mixed readonly helpers, owned arguments, scalar/array/record/tagged
returns, Fuel/bounds/arithmetic failure and failed abort cleanup preserving
writes/receipts. Four control-frame and six readonly lifecycle groups exercise
the unchanged public paths. CLI regression covers 222 owned mutable, 192 readonly
scalar and all 2007 M1 cases. New mutable CALL execution evidence is private
inspected IR; it is not public source execution.

Development and release each passed all 16 selected native groups and 2,421
CLI cases, with 368 identical current input hashes. The pinned compiler,
retained CLI and matrix/M1 receipt identities were rechecked, and the Program
declaration still matches `cfd8275`. Both profiles accept parser depth32 in
check/run and reject depths33/64 with `compile_limit`. Both complete selections
ran all 16 native groups without report reuse. See the
[Windows evidence](../evidence/m2-slice-mutable-execution-windows-20261101.json).

Next is mutable parameter/argument source lowering with exact mode/type rules,
followed by deliberate public admission and CLI capability promotion. Mutable
aliases/subloans, readonly coercions, temporary roots and returned borrows remain
outside this execution stage.

Full native, other M2, Linux, M0, isolation, packaging, allocator and timing checks
are outside this selection. No native performance, memory or stack measurement
is claimed. Local commits only; no push, publication, packaged release or deployment.

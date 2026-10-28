# Private Buffer growth admission

Implemented at `3f99138e98f9fc4779f70efa47bab6956fae756a`; verified in development
and release. This is private admission accounting for the M2 Buffer foundation.
Guest Buffer syntax, allocation, copying, move/borrow rules and VM integration
remain future work. See the [Windows receipt](../evidence/m2-buffer-growth-windows-20261028.json).

## Capacity policy

`src/buffer_growth.fy` plans capacity without allocating memory. Capacities are
multiples of 64 bytes. The preferred candidate is `max(required, old + old / 2)`,
rounded up to 64. If geometric growth or its rounding cannot be represented,
the planner tries the rounded required capacity instead. If the preferred
candidate exceeds the object, Instance or Engine limit, the planner retries the
minimum rounded required capacity. If neither fits, it returns `Quota`.
An unrepresentable minimum capacity plus owner charge returns `Overflow`.

`plan` returns the existing capacity for a request already covered by the current
capacity, after validating state and limits. `begin` returns `NoGrowth` for that
case and does not mutate the ledger. This module does not shrink capacity.

## Reservation and publication

The ledger includes aggregate Instance and Engine usage, their observed peaks,
and at most one pending growth transaction. Each Buffer owner costs 64 logical
bytes at this checkpoint. `empty()` accounts for one empty owner; it does not
allocate payload or metadata. These charges are accounting policy, not measured
allocator overhead or a claim about the native struct size.

The trusted caller must keep the ledger exclusive and perform these steps:

1. `begin` validates the ledger and reserves the entire replacement payload plus
   a new owner charge. The old payload and owner remain charged throughout.
2. The caller allocates and copies into an unpublished replacement. On failure,
   it drops any replacement allocation, then calls `cancel`. Allocator OOM is
   separate from quota rejection; this module performs no retry or allocation.
3. After publication and dropping the old allocation, the caller passes the
   published replacement capacity to `commit`. Commit releases the old payload
   and owner charges and clears the pending transaction.

`commit` requires a valid pending snapshot and the exact replacement capacity.
`cancel` requires a valid pending snapshot and restores pre-reservation usage.
Both preserve observed peaks. Duplicate commit/cancel, nested admission,
malformed counters and inconsistent pending snapshots return `State` before
mutation. Checked bounds and subtraction-based quota checks precede arithmetic.
No loop or allocation is used by the accounting operations.

The public Fairy C structs are private runtime plumbing, not guest handles or
an authenticity boundary. Consistent forged snapshots, stale owner descriptors,
concurrent mutations and actual allocation/publication order are not validated
here. The future owner/storage layer must supply those guarantees. This module
does not protect unrelated ledger mutations during a pending transaction.

## Boundary example

With old capacity 256 and required size 257, preferred capacity is 384 and
minimum capacity is 320. Initial Instance usage is 320: old payload 256 plus
owner charge 64. Engine usage 352 includes 32 additional accounted bytes.

| Operation | Instance usage | Engine usage |
| --- | ---: | ---: |
| Before reservation | 320 | 352 |
| Reserve minimum capacity 320 plus owner 64 | 704 | 736 |
| Reserve preferred capacity 384 plus owner 64 | 768 | 800 |
| Commit preferred replacement | 448 | 480 |
| Cancel either reservation | 320 | 352 |

An Instance ceiling of 704 and Engine ceiling of 736 admit the minimum candidate;
703 or 735 respectively reject it. Cancellation restores usage but retains the
reservation peak. Commit preferred retains peaks 768 and 800.

## Focused verification

`tests/m2/buffer_growth.fy` supplies eight native groups covering rounding and
geometric preference; object/Instance/Engine fallback; every Instance ceiling
from 640 through 800; reservation and commit; cancellation and nested rejection;
malformed clean state; corrupted pending state; and near-`usize` overflow edges.
The large old-capacity case that leaves insufficient simultaneous quota returns
`Quota` without a native arithmetic trap.

Run `python -B tools/verify-m2-buffer-growth.py --profile development` and repeat
with `--profile release`. Both profiles passed 8 native groups and 8 CLI sentinels.
Scalar, array and record sentinels each pass `check` and return 42 through `run`.
The fourth source uses `Buffer`; both commands continue to reject it as a type
error. These CLI cases establish compatibility and the unsupported syntax gate,
not execution of a guest Buffer. CLI commands ran with an empty tool PATH.

The archived receipt rechecks 250 identical input hashes, matching compiler/SDK
identities and both retained executable hashes. Development ran from `d30ce2a`
with the implementation uncommitted; release ran after `3f99138`. No opcode,
Fuel price, profile or version capability changed.

Full suites, M0, Linux, isolation, DLL embedding, packaging, allocation
instrumentation and elapsed-time performance were not run. Earlier receipts
remain historical evidence for their original inputs.

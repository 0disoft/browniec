# Call-local view header indexing

The private retained-value runtime authenticates a view registry before lookup,
read, range, move, alias, close and shutdown operations. The preceding
[single-header lookup change](value-view-lookup.md) retained a pairwise header
scan. A full 32-view pool compared 496 earlier/live row pairs per header, even
when every view shared one root. Lookup-then-read performs two headers per byte.

## Change and invariants

`value_buffer_views::header` uses two disposable, call-local indexes:

- Eight `usize` words track all 512 possible bindings exactly. Range validation
  precedes indexing and shifts, including bindings 0, 63, 64 and 511.
- Sixty-four `u8` buckets retain the first row index for each serial. Linear
  probing compares the complete serial before comparing its owner binding,
  slot and generation. Bucket collisions never establish identity. A consistent
  alias reuses the representative; a conflicting alias still returns State.

Only earlier live rows enter the serial index. At most 32 distinct serials can
occupy 64 buckets, so every search terminates within 32 probes. Maximum serials
and bucket wraparound require no overflowing arithmetic. Different serials may
still share an owner slot in raw metadata; the header invents no new rule.

All existing live/dead-row checks remain. Header failures still report State
before ticket, binding, root or window errors. No pool/store mutation, native
root access, callback, payload copy, heap allocation, cross-call cache, new
authority or changed Fuel price is introduced. Exact root, backing and lease
authentication still follows the header on every operation. Failed and partial
shutdown behavior remains owned by the existing close/shutdown implementation.

## Structural cost

For N live aliases of one root, earlier-row comparisons fall from N(N-1)/2 to
N-1. For 32 aliases this is 496 to 31, a 93.75% reduction. Binding uniqueness
uses 32 bit tests instead of pairwise binding comparisons. For 4,096
lookup-then-read operations, the two headers per read reduce earlier-row
comparisons from 4,063,232 to 253,952: 3,809,280 fewer comparisons.

Serial indexing has expected linear work with well-distributed keys and linear
work for repeated aliases. Deliberately colliding distinct serials retain a
quadratic worst case, bounded by 496 earlier-row comparisons plus 32 empty-bucket
probes at the 32-row cap. This is not a worst-case O(N) or constant-time claim.
Scratch grows by 128 logical bytes on the pinned 64-bit target (8*8+64), with
zero heap requests. Native frame size, compiler copies and elapsed latency are
separate quantities; no process-memory or production latency improvement follows
from these source-level counts.

## Verification

`tools/verify-value-view-header.py` runs focused native development and release
groups in locked, byte-identical mirrors with default stacks. Existing frozen
pairwise oracles compare lookup, alias admission, handoff and shutdown results,
Fuel and exact partial state. The new header group adds 2,880 comparisons over
pool sizes 0..32, sparse binding bits, shared/distinct/colliding serials, maximum
serials, bucket wraparound, metadata faults and conflicting aliases. Empty alias
admission exercises the actual production header without granting root access.
The existing 4,096-read fixture and real VM nested-view fixture cover actual
byte reads, exact Fuel and last-alias cleanup.

Receipts are written to `build/value-view-header/<profile>/receipt.json`.
Public CLI admission, full Engine validation, Linux and delivery are outside
this change.

Windows development and O2 each passed all nine selected native groups. All 376
verification inputs match the executed mirrors; 367 production modules retain
LF. Root checks pass with 375 source files and 4,096 MIR functions. The original
4,096-read fixture also passed on the unmodified baseline in release. See the
[recorded evidence](../evidence/value-view-header-windows-20261117.json), including
the exact compiler hash and reconstructed source-tag provenance. These runs
establish behavior parity, not elapsed-time or native peak-stack improvement.

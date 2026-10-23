# M2 Caller-Backed Scalar Array Storage

- Scope: private byte-storage primitives, not source-array or VM instruction support.
- Implementation: [`scalar_codec.fy`](../../src/scalar_codec.fy) and
  [`array_storage.fy`](../../src/array_storage.fy).
- Harness: [`verify-m2-storage.ps1`](../../tools/verify-m2-storage.ps1).
- Evidence: [Windows receipt](../evidence/m2-array-storage-windows-20261023.json).

This slice connects the [layout foundation](m2-array-layout.md) to actual backing
bytes. The caller supplies initialized memory as a Fairy byte view and an Arena
cursor with `used` and `limit`. The helpers allocate no backing memory and add no
storage to the current scalar VM. A caller may supply a fixed array or an owned
Buffer; the maximum-size native test uses a Buffer and checks surrounding guards.

## Scalar encoding

The codec accepts the six existing scalar tags and exactly 1, 4, or 8 bytes as
specified by the layout. Integers use explicit little-endian bytes; signed values
use two's complement. i64 MIN is encoded using floor division without negating
MIN. Sign-extended decoding keeps each intermediate within the signed range.
Unsigned decoding stays within 64-bit usize and uses the existing cell conversion.

The input/output value is the VM's i64 cell representation. In particular, the
upper half of guest usize is represented by negative cells: cell -1 encodes guest
usize MAX, not an unsigned source-language negation. u8, u32 and i32 writes must
fit their exact domains. Bool encodes only 0 or 1, and decoding every other byte
fails. Unknown tags and wrong widths fail before accessing payload bytes.

Encoding builds at most eight bytes in scratch, then copies to the destination.
All errors preserve destination bytes; no narrowing or truncation is exposed.

## Initialization and element access

`initialize(layout, fill, storage, arena)` accepts one already-computed scalar cell
and repeats its encoding across an array. It performs these steps in order:

1. Check `used <= limit <= storage.len`.
2. Validate canonical layout metadata and preflight the aligned reservation.
3. Encode the fill value in scratch, including exact type-domain validation.
4. Zero alignment padding and write the complete repeated payload.
5. Advance `used` only after the entire payload is initialized; return its base.

No fallible operation remains after step 3. A rejected quota, layout, state, or
value preserves both the old cursor and every backing byte. Padding is included
in the quota charge. Bytes after the new end are untouched. No ledger rollback,
allocator retry, or hidden allocation is needed in these helpers.

`read` and `write` check cursor validity, canonical layout, index bounds, base
alignment, and containment of the entire array within the published `used` prefix.
They do not treat spare capacity as published storage. A successful write changes
only one element, preserves the cursor, and keeps adjacent elements unchanged.
An invalid write preserves all bytes. Noncanonical bool input is an explicit error.

The error enum retains Type, Length, Metadata, Overflow, Quota, Bounds and
Alignment from layout checking, and adds Value and State. Codec width mismatches
map to Metadata. These are private helper errors, not public ABI or CLI diagnostics.

## Ownership and work boundary

The cursor and layout are trusted private runtime state, not guest handles.
Offsets are not ownership tokens: these helpers do not prove allocation identity,
that the requested type matches an earlier allocation, generation freshness, or
root/loan authority. A forged cursor or layout must never be accepted directly
from guest source or external bytecode. Those policies require the future owner
table and independent aggregate IR verifier before VM integration.

Initialization writes at most 32768 payload bytes plus seven padding bytes. Codec
work is bounded by eight bytes; element access checks do not traverse an array.
This is a static work bound, not a latency measurement. No aggregate Fuel schedule,
instance/engine accounting, allocator ownership, frame reclamation, by-value copy
operation, or source initializer semantics is implemented by this slice.

## Evidence and next step

The focused native harness runs four codec groups and five storage groups in
development and release with Fairy C `4ce12642`. Coverage includes exact signed
MIN/MAX and unsigned edge byte vectors, all 256 repeated-byte full-cell patterns,
wrong widths, out-of-range writes, all noncanonical bool bytes, each scalar type's
element mutation, initialized padding, quota/value rejection preserving state,
corrupt metadata and cursor rejection, unpublished bounds, and a 4096-element
usize payload with guards and last-element mutation.

The earlier six layout groups retain their historical receipt; layout code and
tests are unchanged. M0 and the M1 scalar execution sources are unchanged, so their
native/CLI executions are not repeated. Their recorded input and artifact hashes
are checked separately from the changed root lock. No new CI workflow is added.

Next: owned arena reservations and array copy/lifetime rules, followed by source
construction and indexing through independently verified, metered aggregate IR.
M2 is partial. No source-array, allocator-failure, stale-handle, OS isolation, DLL,
clean-machine packaging, or performance claim follows from these tests.

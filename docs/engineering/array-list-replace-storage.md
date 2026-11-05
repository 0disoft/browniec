# Atomic replacement of scalar array values

Date: 2026-11-06. Implementation: `6e2b75f`.
Native prerequisite for whole-array element-list assignment.
Successor to [list creation](array-list-storage.md) and
[source list contexts](array-list-contexts.md).

## Storage transaction

`array_storage::replace_values` receives a canonical scalar layout, the base of
an existing extent, exact `i64` cells, caller-owned encoded scratch, mutable
backing and a read-only arena. It validates the complete arena and recomputes
the layout, alignment and full destination extent against `arena.used`, before
encoding any value. Checking only the first cell would be insufficient.

Both creation and replacement now share one private complete-list encoder.
Values must match the exact arity, and scratch must contain exactly `N*stride`
bytes. All cells are encoded before the first target write. A bad final cell
therefore preserves every published backing byte, even after earlier cells have
changed discardable scratch. Commit copies only the selected extent; prefix,
suffix, alignment padding and the arena cursor remain unchanged. No fallible
validation or codec operation follows the first target write.

As with existing fill, replacement need not decode obsolete target values.
For example, a canonical new bool list can replace obsolete invalid bool bytes;
it cannot read those bytes as valid values or bypass ownership/lease admission.
Input cells and scratch must be disjoint from backing and one another, as
required by the safe caller borrows. References are not retained.

## Owner admission

`array_owners::replace_values` first resolves an authentic current scalar-array
token, validates the complete owner/order/arena metadata, and rejects active
shared or exclusive sessions. It compares the supplied exact element type and
length with the owner before delegating to storage. Record tokens cannot be
reinterpreted as equally sized arrays. Source mutability is a later IR/caller
obligation, as for existing native writes; the private owner table does not
represent source `let`/`var` declarations.

The table is read-only on success and failure. Tokens, generations, lease epochs,
live/occupied flags, order, marks, bases, ends, depth and arena fields remain
unchanged. No new descriptor or extent is acquired, so replacement works with
all sixteen owners live and with `used == limit == backing length`. Repeating
replacement cannot accumulate descriptors, bytes or generation changes.

All six existing scalar domains, packed full-width `usize` cells, 4096 elements
and a 32768-byte payload remain supported. The primitives make zero allocation
calls and introduce no payload-sized fixed local. The caller supplies B encoded
scratch bytes; work is O(N+B) plus the bounded O(16) owner scan. This is a native
atomic operation, not a resumable/chunked Instance operation or a claim about
actual allocator capacity/accounting.

## Verification

```text
python -B tools/verify-static-execution.py --profile development --selection array-list-replace-storage
python -B tools/verify-static-execution.py --profile release --selection array-list-replace-storage
```

The selection includes six new replacement groups, all three original list
creation groups and the existing six-domain ordinary VM exact-Fuel oracle.
New cases cover every scalar codec and signed/unsigned edges, scratch
independence, prefix/suffix/padding preservation, 64 replacements at full
sixteen-owner/full-byte capacity, bad final cells, exact arity/scratch/shape,
malformed layouts/arenas/whole extents, stale/zero/out-of-range and record tokens,
active read/write sessions, and all 4096 i64 cells with both backing guards.
Failure checks compare complete backing and every owner/order/arena field;
success checks preserve the same table and target token.

Development and release each passed all ten native groups on 163 matching input
hashes, 156 LF production modules and the 265-file test-discovery identity. Every
recorded input matches the checkout and `6e2b75f` Git raw bytes; both locked LF
mirrors pass. Final runs use no compiler/stack overrides or historical-result
reuse. The initial test-only storage-error comparison lacked an explicit integer
context and failed semantic checking; its corrected fixture is used in every
final run. See the
[Windows evidence](../evidence/array-list-replace-storage-windows-20261106.json).

## Remaining integration

The [native execution successor](array-list-replace-execution.md) now supplies
opcode 81, complete independent admission and ordinary/retained VM dispatch with
prepaid replacement Fuel. The [source assignment successor](array-list-assignment.md)
now connects ordered cell evaluation, exact types/arity and nonlocal-exit cleanup.

The original storage increment introduced no opcode, public syntax or version flag. Existing
operation prices, default 256 and ceiling 16000000 remain unchanged. Whole-array
`a=[x,y];` uses the existing destination directly, preserving the full-capacity
behavior above. RHS effects
occur in source order and are not rolled back if later evaluation fails.

Full profiles, public CLI/full matrices, Linux, allocator fault injection,
general native stack/timing, Instance accounting/resumability and restricted/
ABI/package delivery remain separate obligations. Full L03/C05 and the complete
objective remain open.

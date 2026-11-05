# Atomic array element-list storage

Date: 2026-11-06. Native storage prerequisite for L03; source element-list
syntax, its IR proof and VM dispatch remain to be connected.

## Transaction

`array_storage::initialize_values` receives an exact scalar layout, immutable
`i64` register cells, caller-owned encoded scratch, backing bytes and an arena.
It revalidates the arena, recomputes the canonical layout/reservation and checks
exact element and scratch lengths. The existing limits remain 1..4096 elements,
six scalar domains and at most 32768 payload bytes. Packed `usize` cells retain
their existing full-width codec representation.

Every element is encoded into scratch before any backing byte changes. A bad
value in the last element therefore preserves the entire old backing, padding
and arena cursor. Scratch contents are unspecified after failure. On success,
padding is zeroed, the complete encoded payload is copied, then the cursor
advances once. No fallible codec or metadata operation follows the first backing
write. Safe nonoverlapping caller borrows keep values, scratch and backing
separate; none of those references is retained.

`array_owners::create_values` validates the complete owner table and finds an
available nonretired slot first. It invokes storage preparation, then uses the
existing infallible publication helper. An error preserves every owner field,
allocation-order entry, epoch, depth and arena field as well as all backing
bytes. Existing owners remain usable. Successful arrays own independent values;
reusing scratch or changing one array does not change another array or the input.

The new functions allocate no heap storage and introduce no fixed payload-sized
local array. The caller supplies exactly `length * stride` encoded scratch bytes,
up to 32768, in addition to its input cells and backing. Preparation and commit
take O(length * stride) work; bounded owner validation adds O(16) visits.
This is an atomic native primitive, not a resumable Instance operation.

## Verification commands

```text
python -B tools/verify-static-execution.py --profile development --selection array-list-storage
python -B tools/verify-static-execution.py --profile release --selection array-list-storage
```

The selection contains three element-list groups and the existing repeated-fill
alignment/rollback and owner-pressure regressions. Cases cover all six codecs,
signed/unsigned edges, independent values/tokens, scratch reuse, the full 4096
element/32768-byte extent with both guards, alignment, exact quota and rejection
of short/long scratch, wrong arity, invalid bool/u8/i32, malformed layout, corrupt
cursor and exhausted owner slots. Failure checks compare the complete backing
and every owner/order/arena field. Test-only host Buffers supply large byte
backing because Fairy's fixed arrays admit at most 4096 elements.

## Remaining L03 integration

Guest `[x, y]` declarations/expressions are not enabled by this prerequisite.
Next distinguish element lists from `[filler; N]` without evaluating guest
expressions during lookahead. Lower elements left to right exactly once, infer
or enforce exact type and arity, and expose the name only after initialization.
Connect complete IR operand/CFG/lifetime proof, atomic VM publication and a
precharged price covering every encoding plus the final copy. Preserve current
repeated initializer prices, backing/owner limits and nonlocal-exit cleanup.

The current compiler's 128 global value registers, 256 instructions and 4096-byte
source limit remain separate C05 constraints. Native 4096-element support does
not prove that source lists of that size can be represented today. Do not impose
a smaller permanent language limit or claim L03/full-profile completion from
these native primitives. Runtime scratch accounting and bounded resumable work
remain obligations of the later VM/Instance integration.

# Validate view lookup once

Successor: [call-local header indexing](value-view-header.md) replaces the
pairwise scan discussed below while preserving its validation boundaries.
The counts and receipts in this document describe the preceding implementation.

The private typed/value VM resolves a view binding through
`value_buffer_views::lookup` before its read/length/range/alias operation.
The old successful lookup called `header(pool)`, searched for the binding, then
called `resolve`, whose first operation was the same complete header check.
Both checks read the same immutable Pool with no intervening mutation/callback.

The successful path now uses `resolve` as its single header and root/lease/
backing authentication boundary. The bounded search reads only `live`, `binding`
and `generation` from the fixed 32-row metadata array. No unchecked ticket,
native pointer or borrowed backing escapes. Out-of-range bindings and misses
still call `header` before returning Binding, preserving State-before-Binding
diagnostics for invalid/closed/duplicate/corrupt registry metadata. `resolve`
itself, including the header, remains unchanged for every independent caller.
There is no checked-handle API, cross-call cache, new allocation or state field.

With D live rows packed into a full registry, one header visits every outer row
and D*(D-1)/2 live-row pairs to reject duplicate bindings and incoherent aliases.
At the 32-row bound this is 32 outer rows and 496 row pairs per header. Successful
lookup reduces two header passes to one. The VM lookup-then-read path reduces
three to two: 96 to 64 outer-row visits and 1,488 to 992 row-pair visits (33.33%
less header work). For 4,096 reads, 2,031,616 row-pair visits are eliminated.
These are source-level structural counts, not elapsed-time or measured machine
instruction counts; compiler optimization may affect native work. The O(D^2)
header algorithm remains unchanged. View read Fuel remains 513 and lookup
consumes no Fuel, exactly as before. No native peak-memory change is claimed.

Malformed inputs may cause up to 32 safe metadata-row reads before a header
rejection instead of rejecting before the search. The old diagnostic wins on
every path, and all native/root access still follows header validation. Invalid
binding ranges do not perform this preliminary search.

`tools/verify-value-view-lookup.py` selects six native groups. A frozen copy of
the original 9256469 header, resolver and lookup compares exact ticket fields or
error kind at every healthy pool size 0..32. All existing bindings are exercised.
For sizes 0,1,8,32, 16 mutation modes at every row are queried with six hit/miss/
out-of-range bindings: 12,288 registry-fault comparisons. Root lease, generation,
extent, closed-state and accounting faults add 120 comparisons. A full 32-alias
pool performs 4,096 lookup-then-byte-read operations with exactly 2,101,248 Fuel,
then closes every alias, releases the actual lease and drains root charges at
zero Fuel. Three existing registry groups cover ranges, moves, stale/exhausted
generations, rejection and shutdown; one VM group executes real nested views,
aliases, moves and empty windows.

Run development and release separately with the pinned compiler and default
native stacks. Receipts are written to
`build/value-view-lookup/<profile>/receipt.json`. This does not change public CLI
admission. Full Engine, standalone memory, public CLI and release gates are
outside this focused change.

Development and O2 each passed all six native groups in byte-identical locked
mirrors. All final inputs match the implementation commit. See the
[evidence](../evidence/value-view-lookup-windows-20261114.json).

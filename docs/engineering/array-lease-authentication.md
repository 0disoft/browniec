# Authenticate shared array views once per operation

`array_owners::leased_read`, `leased_length` and `leased_utf8` are used by
shared slice access and pool validation. Each previously called `resolve_read`
and then a public view operation. Both paths resolved the same root and ran
the full owner-table validator on the same immutable table, without an
intervening callback or mutation.

The private `resolve_leased_view` now authenticates the table and read epoch,
checks the view/root identity, then checks the descriptor shape and range using
that owner. Private payload helpers are shared with the ordinary view entry
points; those entry points still authenticate independently. No unchecked
public API or validation result survives the call. Token-before-table,
table-before-epoch, epoch-before-view identity, shape-before-index and scalar
codec errors retain their order. UTF-8 type checking and byte scanning remain.

For D retained allocations and M=16 owner slots, one full `valid` traversal
visits D allocation-chain entries plus M slot entries. Each successful leased
operation reduces two traversals to one: 2*(D+M) visits to D+M. At D=16 this is
64 to 32 visits (50% less), or 262144 to 131072 over 4096 leased reads.
For a pool validation with V live shared views this portion becomes V*(D+M)
instead of 2*V*(D+M); the pool still checks each view independently. The whole
slice operation has other validation work, so no 50% end-to-end speedup is
claimed. Metadata validation stays O(D+M), and UTF-8 stays O(selected bytes).
Fuel, copying, quotas, ownership rules and conservative reservations do not
change. There are no new allocations or stored fields. These are source-level
structural counts, not measured machine instructions, throughput or peak memory.

`tools/verify-array-lease-authentication.py` runs six selected native groups.
The new tests compare all three operations with the original b292981 wrapper
sequence at every live owner count 1..16, with 20 table mutation modes across
all 16 slots at counts 1,8,16. Each mutation is also paired with a bad descriptor
and index to check diagnostic order. Fourteen descriptor/lease variants include
empty ranges, foreign roots, short backing, stale epochs and invalid bounds.
Maximum arrays exercise all six scalar tags, first/last/out-of-range elements,
bool decoding, invalid UTF-8, session reopening and root reuse. Existing tests
cover write exclusion, copied tickets, prepaid slice-index Fuel, failure
atomicity and actual VM slice scanning.

Run development and release separately with the pinned toolchain and default
native stacks. Receipts are under `build/array-lease-authentication/<profile>`.
The first test attempt failed to compile because a fixed array exceeded Fairy's
4096-element limit; the final fixture uses an explicit SDK byte buffer. That
attempt is not passing evidence. Full Engine, standalone memory, public CLI and
release gates are outside this focused change. No admission gates are expanded.

Development and O2 each passed all six native groups in locked byte-identical
mirrors. All 377 input hashes match implementation bccd7c9. See the
[evidence](../evidence/array-lease-authentication-windows-20261115.json).

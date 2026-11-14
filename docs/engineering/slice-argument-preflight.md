# Reuse the shared argument batch preflight

`array_slices::borrow_arguments` retains whole selected ranges for readonly
CALL arguments. It used to validate the original pool, call `length` for every
source (validating the pool again), then call `subslice` for every child on a
staged pool (validating the growing pool and resolving the source owner again).
The same original pool and owner table remain unchanged throughout admission.

The batch now validates the pool once and uses a private identity-only `lookup`
for each source, retaining the original order of stale-ticket and exclusive-mode
errors. The second loop reserves the same free slots in the same order in a
staged pool, then publishes copies of the original checked view and read lease.
A whole-range child has exactly the parent's root-relative start/end, including
nonzero starts and empty ranges. No arithmetic or payload operation is needed.
Both tables remain unchanged on every admission failure, including exhaustion
after earlier provisional children. The original pool is committed only when
all children are prepared. No source is resolved against a provisional child.

This reuse is local to one synchronous call with an immutable owner table and
no callbacks. `lookup` is private and proves only ticket identity. Ordinary
`resolve`, `length` and `subslice` still validate the pool independently. No new
unchecked public API, retained cache, stored field, allocation or reservation
is introduced. The old eight-element usize length scratch is also unnecessary.
Arity-before-pool, pool-before-source, source-order mode errors and all source
checks before free-slot exhaustion are preserved. Fuel and quotas are unchanged.

## Structural cost

Let V be the initial live shared views, K the number of arguments, D the retained
owner allocation depth and M=16 owner/pool slots. For a successful all-shared
batch, pool validation calls fall from 1+2K to 1. Each pool validation invokes
one full owner validation per live view. The old batch therefore invoked full
owner validation V*(1+2K)+K*(K-1)/2+K times; the final K came from `subslice`'s
owner resolution. The new batch invokes it V times.

With V=8, K=8 and D=16: pool validations fall from 17 to 1; owner validations
fall from 172 to 8 (95.35% less). Each successful owner validation visits D+M
allocation-chain/slot entries, so those visits fall from 5504 to 256. These
figures exclude other checks, copies of fixed metadata, and free-slot searches.
The owner-validation portion changes from O((V*(1+K)+K*K)*(D+M)) to O(V*(D+M));
the K bounded free-slot searches remain O(K*M). Caps stay V<=16 and K<=8.
Mixed exclusive pools retain their existing conflict checks. This is structural
work, not measured throughput, machine instructions or physical stack/heap peaks.

## Verification

`tools/verify-slice-argument-preflight.py` selects six native groups. A frozen
copy of the f2c1c57 algorithm compares error kinds, returned batch entries and
every field of the resulting pool. Every failed batch must leave the pool equal
to its input. Healthy cases cover all 17 pool occupancies, three generation
variants (ordinary, exhausted free slots, maximum generations), repeated/reverse
source orders and all ten input lengths 0..9: 1020 comparisons. Sixteen actual
owners keep the owner table full. Views include root-relative offsets and empty
ranges. Metadata tests apply 20 mutation modes over every slot at occupancies
1,8,16, comparing valid inputs, a late bad input, an empty input and short
backing: 3840 comparisons. A further 48 comparisons check future/stale tickets
at every admitted argument position. Existing tests cover partial capacity
rollback, eight mixed scalar arrays, maximum ranges, exclusive conflicts and
actual CALL entry/return with exact Fuel and frame reuse.

Run development and release separately with the pinned compiler and default
native stacks. Receipts are under `build/slice-argument-preflight/<profile>`.
Full Engine, standalone memory, public CLI and release gates are outside this
focused change. No public admission or broader completion milestone is expanded.

Development and O2 each passed all six native groups in byte-identical locked
mirrors. All 377 input hashes match implementation 8e6fc5f. See the
[evidence](../evidence/slice-argument-preflight-windows-20261115.json).

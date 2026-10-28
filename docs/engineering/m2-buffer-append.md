# Native Buffer append within admitted capacity

Implemented and verified in development and release. See the
[Windows receipt](../evidence/m2-buffer-append-windows-20261029.json).

`buffer_append::within_capacity` adds bytes to a caller-bound native Buffer using
its already-admitted capacity. It returns a table-local token for the new length.
It performs no implicit growth or allocation retry. Guest Buffer syntax, VM
instructions, borrow tracking, Fuel prices and capability flags are unchanged.

The [close successor](m2-buffer-close.md) adds descriptor retirement followed by
usage release after trusted native root destruction. The current shared harness
selects 13 scenarios over six production modules; the nine-case receipt below
retains its original inputs and verification scope.

## Preflight and publication

The private API accepts an owner table, source token, mutable native root, shared
input bytes, limits and a shared ledger. It checks these in order:

1. Resolve token identity and validate the owner table before native root metadata.
2. Require exact native initialized length and capacity matching the descriptor.
3. Use no-growth admission planning to validate all ledger invariants and current
   object/Instance/Engine limits, including the absence of pending reservations.
4. Check `input.len <= capacity - length` before adding lengths or calling the SDK.
   The descriptor already proves `length <= capacity`; the comparison bounds the
   resulting addition by capacity and prevents integer overflow.
5. Empty input returns the original token unchanged. Nonempty input requires a
   next generation; MAX returns `Owners` before any native write.
6. Call the trusted SDK append only after capacity is proven sufficient. Check
   returned length and native length/capacity, then publish the new initialized
   length and generation in the same descriptor slot. No allocation, callback or
   fallible operation follows that metadata update.

Token, State, Quota, Capacity and generation-headroom errors precede the SDK write.
Capacity shortage returns `Capacity`, leaving the caller to explicitly choose the
existing replacement transaction before retrying append. Empty input still checks
identity, metadata, accounting and limits, but consumes no generation; a MAX token
can therefore perform a valid no-op. Every nonempty success invalidates the old
token even though the native allocation is unchanged.

All nine ledger fields, including observed peaks, stay unchanged. Other slots and
the native capacity stay unchanged. Work is O(input length) plus bounded 16-slot
metadata validation. No payload-sized scratch buffer is introduced.

## Trust and remaining work

The caller must bind the correct native root to the token/table and maintain
exclusive access, as in the [descriptor contract](m2-buffer-owners.md). Matching
metadata cannot authenticate a different root or another table. Native borrowing
must keep shared input from aliasing the mutable destination; this is not guest
borrow enforcement. Do not bypass transaction completion by manually clearing a
pending ledger and writing through lower-level APIs.

The pinned SDK and allocator remain trusted. Unexpected SDK errors or changed
length/capacity return `Provider`; this API does not guarantee rollback of a
malfunctioning provider's native mutation. Provider fault injection is deferred.
An explicit growth commit followed by append is not one atomic grow-and-append
operation. Those capabilities and guest integration remain future work.

## Focused evidence

The shared [allocator probe](m2-buffer-failure.md) now copies five production
modules and selects nine scenarios per profile. Allocator report v2 adds total
attempt/free counts; the original five-case/v1 receipt remains historical.

Four append cases cover successful `keep` to `keep!`, old-token invalidation and
empty input; rejection of 253 bytes with 252 bytes remaining, exact filling and
full-capacity rejection; invalid identity/backing and MAX generation with a no-op;
and pending/corrupt accounting plus Instance/object limit rejection. Every case
asserts unchanged ledger fields. Each whole append process reports exactly one
allocation attempt for initial Buffer creation, one free and zero live allocations,
so its append operations add zero FY heap allocations. Counts exclude other
process/CRT allocation paths and are not whole-process memory measurements.

Five regressions exercise normal minimum/preferred growth, abandonment/cancel,
and one-shot 320/384-byte allocation failures with explicit successful retries.
All nine scenarios passed in both development and release. The archived receipt
rechecks 12 selected inputs, six generated sources, SDK lock and both retained
instrumented binaries. Both profiles ran from `dc4735b` with this increment
uncommitted; hashes identify the tested implementation rather than that baseline.

The prior 31 native groups and CLI sentinels, full suites, M0, Linux, isolation,
DLL embedding, packaging, Provider injection and elapsed-time performance were
not run. This is targeted native append/allocator evidence, not guest execution.

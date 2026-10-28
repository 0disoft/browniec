# Private native Buffer storage

Status: implemented and verified in development and release.
See the [Windows receipt](../evidence/m2-buffer-storage-windows-20261028.json).

`src/buffer_storage.fy` connects the [growth admission layer](m2-buffer-growth.md)
to actual Fairy C `std::bytes::Buffer` allocation and copying. This is private
native storage, not guest Buffer support. No owner-token table, borrow tracking,
VM opcode, source syntax, Fuel price or capability changes are supplied here.

The [descriptor successor](m2-buffer-owners.md) supplies table-local generation
checks over caller-bound native roots. The storage API below still leaves root
publication, descriptor binding and accounting completion to the caller.

The [allocator-failure successor](m2-buffer-failure.md) now supplies one-shot
320/384-byte Allocation-path injection and tracked exit-cleanup evidence for
these unchanged production modules. Provider inconsistency injection remains
deferred; the original checks and limitations below retain their historical scope.

## Transaction contract

`prepare_growth(ref old, required, limits, ref mut ledger)` returns an owning
replacement without moving or modifying the original root. The trusted caller
supplies the correct root/ledger association and exclusive ledger access.

1. Validate the old initialized length against its capacity. Growth admission
   checks the clean ledger, arithmetic, quotas and minimum-capacity fallback.
   `State`, `Overflow`, `Quota` and `NoGrowth` return before requesting storage.
2. Charge the complete replacement capacity and a logical 64-byte owner while
   the old payload and owner remain live. Record the simultaneous usage peak.
3. Allocate using `bytes::with_capacity`; require the provider's capacity to
   equal the admitted capacity. Copy only `bytes::view(old)` using `bytes::append`.
   The old initialized length fits the admitted capacity, so the current provider
   needs no growth allocation to perform this copy. Check capacity and length
   again before returning the owning replacement.
4. Allocation failure returns `Allocation`; a provider capacity/copy inconsistency
   returns `Provider`. The preparation helper drops an unpublished replacement
   before its caller cancels the reservation. Usage restores to its previous
   values while observed peaks remain recorded. There is no automatic retry.
5. On success, the caller either replaces its owning root and invokes
   `buffer_growth::commit` with the published capacity, or drops the replacement
   and invokes `buffer_growth::cancel`. Do not cancel while the replacement is
   still live. Do not commit before root replacement has dropped the old allocation.

The API returns an owning value because the pinned Fairy C compiler supports
resource replacement at an owning local; whole resource replacement through a
mutable reference is outside its supported boundary. Publication is deliberately
an explicit caller step. A successful prepare leaves a pending reservation;
forgetting commit/cancel retains that charge. Nested preparation is rejected.
The caller must also account final root destruction and unrelated Engine usage.

This layer does not authenticate public ledger fields, identify a stale or wrong
owner, constrain other native SDK mutations, or serialize concurrent callers.
Guest ownership must be enforced by the later descriptor/VM layer. The SDK and
its allocator are trusted providers; provider checks are consistency guards.
The 64-byte owner charge is policy rather than measured native metadata size.

## Focused verification

Verified selection: 7 native storage groups plus 8 admission groups and 8 CLI
sentinels per profile, using `tools/verify-m2-buffer-storage.py`.

Storage groups cover initial allocation; 256-to-384 growth preserving `keep`;
minimum 320-byte replacement under each quota dimension; pre-allocation rejection
without root/counter mutation; malformed and already-pending ledgers; six repeated
growth operations plus a native owning move; and abandoned replacement cleanup,
cancellation, and subsequent successful minimum-capacity growth.

For old capacity 256, initialized length 4, Instance usage 320 and Engine usage
352, preferred preparation produces real capacity 384 and initialized length 4.
Pending usage is 768/800, then commit gives 448/480. Peaks remain 768/800.
A minimum-capacity transaction uses peak 704/736. No spare capacity is exposed as
initialized data. Copy work is O(initialized length), not O(old capacity).

The CLI sentinels run unchanged scalar, array and record source and continue to
reject guest Buffer syntax in both `check` and `run`. They do not execute a guest
Buffer. Native tests exercise real allocations and scope cleanup; they do not
count allocator calls, prove absence of leaks, or inject target allocator failure.
The Allocation/Provider rollback paths remain unverified by fault injection.

Full suites, M0, Linux, isolation, DLL embedding, packaging, allocation
instrumentation and elapsed-time performance are outside this focused selection.
Earlier receipts remain historical evidence for their original inputs.

Both profiles ran from `027ac4f` with this implementation uncommitted.
The archived receipt identifies the tested working tree through 253 matching
input hashes. Compiler/SDK identities matched and both executable hashes were
rechecked against retained binaries. This receipt does not use its baseline SHA
as the identity of the new implementation.

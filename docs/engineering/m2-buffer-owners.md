# Private Buffer owner descriptors

Status: implemented and verified in development and release.
See the [Windows receipt](../evidence/m2-buffer-owners-windows-20261028.json).

`src/buffer_owners.fy` supplies fixed private descriptors over the actual native
Buffer storage from [the storage foundation](m2-buffer-storage.md). This slice
adds token lifecycle and byte-access guards; it does not integrate guest Buffer
syntax, owner roots, borrows, VM instructions, Fuel or capability flags.

The [replacement successor](m2-buffer-replacement.md) now validates descriptor
and ledger snapshots together during preparation/completion. Native root
publication and root association remain explicit trusted caller responsibilities.

The [read-lease successor](m2-buffer-read-lease.md) adds a reading flag and gates
descriptor-aware mutation while an explicit private lease is active. The original
descriptor contract and receipt below retain their historical scope.

## Table and token contract

A table contains 16 slots. Each stores generation, live state, initialized length
and capacity. Fresh unused generations start at one. Tokens carry only slot and
generation and are meaningful within the caller-selected table. They are not
cross-Instance handles, unpredictable capabilities or native pointers.

`create` checks the complete table and a trusted native Buffer's metadata, then
publishes a descriptor in the first available non-retired slot. Capacity must be
64-byte rounded, admit its logical owner charge without usize overflow, and cover
initialized length. Empty native Buffers may have a zero-capacity descriptor.
A full or fully retired table returns `Owners` without changing descriptors.

`release` validates identity and the whole table before clearing live state,
length and capacity. It advances generation once. Generation MAX becomes zero,
retiring that slot permanently; it never wraps to a reusable generation. Repeated
release or a token from before slot reuse returns `Token` without mutation.
Release invalidates metadata only; it neither frees storage nor changes quotas.

## Access order

`read` and `write` perform the following checks before obtaining a payload view:

1. Slot is below 16, generation is nonzero, and the selected slot is live with
   exactly the token's generation. Failure returns `Token` before inspecting the
   supplied native Buffer, including for already-released storage.
2. All live table slots have valid lengths, capacities and generations. Vacant
   slots have zero lengths and capacities; retired slots remain unavailable.
3. The caller-supplied Buffer has exactly the descriptor's length and capacity.
   A mismatch returns `State`; spare capacity is never treated as initialized.
4. The requested index is strictly below initialized length, using comparison
   without index addition. Failure returns `Bounds` before creating a byte view.

A successful read returns one initialized byte. A successful write updates one
byte and returns its index without changing length, capacity or generations.
Work is bounded by a 16-slot metadata scan and one payload-byte access. Create
uses at most two scans; no operation allocates or copies a payload.

## Trusted caller boundary

The Instance must bind each slot to the correct native root, register each root
once, use the correct table, invalidate descriptors before freeing their roots,
and keep table access exclusive. This module cannot distinguish a wrong Buffer
with matching length/capacity, duplicate root registration, or a token from another
table whose slot/generation coincides. Public metadata is private native plumbing;
consistent forged metadata is not authenticated. These are caller obligations,
not protections implemented by this foundation.

Native growth or length mutation requires explicit descriptor release/recreation;
old snapshots reject a changed length/capacity. Growth, publication, descriptor
replacement and rollback are not yet one atomic operation. A native owning move
may preserve a descriptor only when the caller updates its root association.
Borrow counters, table storage admission and final root/ledger cleanup remain
future work. The 16 slots are a private checkpoint bound, not a public language
limit or a claim that descriptor memory has been quota-accounted.

## Focused verification

Verified selection: 8 descriptor groups, 7 native storage groups, 8 admission groups
and 8 CLI sentinels per development/release profile, via
`tools/verify-m2-buffer-owners.py`.

The descriptor groups exercise actual Buffer reads/writes and spare-capacity
rejection; stale access after the original backing scope exits; slot reuse;
invalid slots and generations against empty backing; changed native metadata;
16-slot exhaustion and MAX generation retirement; malformed table rejection
without payload/descriptor mutation; and zero-length access rejection. The full
capacity fixture registers one native root repeatedly solely to fill metadata;
production registration must instead maintain one descriptor per owning root.

Token errors against empty backing distinguish the identity-first path from
metadata mismatch or bounds errors. They do not instrument native pointer reads.
Existing storage and admission groups remain selected. CLI sentinels preserve
scalar/array/record behavior and reject guest Buffer syntax; they do not execute
guest Buffers or enforce guest ownership.

Full suites, M0, Linux, isolation, DLL embedding, packaging, allocator-failure
injection, allocation instrumentation and elapsed-time performance were not run.
Earlier receipts remain historical evidence for their original inputs.

Both profiles ran from `6291367` with the implementation uncommitted. The
archived receipt identifies the tested working tree through 256 matching
input hashes. Compiler/SDK identities matched and both retained executable
hashes were rechecked. The baseline SHA identifies provenance rather than
the new implementation; prior receipts retain their original inputs.

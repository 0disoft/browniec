# Reuse root-store table authentication within one preflight

The native `value_roots::ready` preflight authenticates the whole owner table,
ledger and root-row identities before Buffer operations. It is shared by scalar
byte reads, lengths, writes, copying, ownership changes and cleanup. Typed/value
execution remains private; this does not change public CLI admission.

`owners::accounted` already calls `buffer_owners::valid` for all 16 owner slots
before summing charges. The old per-row `owners::describe` repeated that full
validation once per live root. For n live roots and M table slots, the table
validation portion cost M*(1+n) slot visits in `ready`. The replacement keeps
the initial validation and directly matches each bounded row's live flag and
generation. That portion now costs M full-table visits plus n identity checks.
The existing pairwise serial/binding duplicate checks remain O(n^2); this does
not claim the entire preflight becomes linear.

For a successful `value_roots::read` with all 16 roots live, the complete call
chain used 19 full `valid` scans: one in `accounted`, 16 per-row descriptions,
one in `resolve_mode`, and one in `owners::read`. It now uses three. Full-table
validation slot visits fall from 304 to 48 (84.21% less). A 4,096-read loop
eliminates 1,048,576 such slot visits: 1,245,184 to 196,608. These are source-level
structural counts, excluding accounting sums, identity/duplicate checks and all
other work, not measured throughput or physical heap/stack peaks. Compiler
optimization may affect native work counts. Fuel prices remain unchanged.

This reuse is valid only inside this synchronous call: `s` is shared immutable,
no callback or mutation intervenes, row slot/generation bounds precede indexing,
and `accounted` rejects corruption even in unused table slots. Nothing is cached
between operations. The per-row live/generation match, duplicate slot/serial/
binding guards, empty tail, final live-slot bijection, ledger and native backing
extent checks are retained. No unchecked-owner API, allocation, state field,
native layout or conservative memory reservation is added.

`tools/verify-value-root-authentication.py` selects six native groups. A frozen
copy of the original 2233345 preflight compares every healthy root count 0..16,
plus 1,280 metadata variations (20 modes across every slot at counts 0,1,8,16).
These include mismatched/dead/zero-generation owners, forged row identities,
overflowing capacities, invalid inactive-slot metadata, leases and ledger faults.
A full-store test executes 4,096 exact-price byte reads under a lease, checks
Fuel-before-bounds ordering, rejects leased writes, preserves bytes and drains
all charges. Three existing root-store groups cover removal/reuse, exact Fuel
and corrupt metadata; one existing VM group executes all six Buffer opcodes.

Run development and release separately with the pinned compiler and default
stacks. Receipts are written to
`build/value-root-authentication/<profile>/receipt.json`. Full Engine, standalone
memory, public CLI and release gates are outside this focused change. The first
fixture attempt failed at compile time with E2101 for nested-field read/write
loans; it is incomplete evidence and is not counted as passing verification.

Development and O2 each passed all six groups in locked byte-identical mirrors;
all final inputs match the source tree. See the
[evidence](../evidence/value-root-authentication-windows-20261114.json).

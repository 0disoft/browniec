# Private Buffer UTF-8 validation

Implemented and verified in development and release. Root `fairyc check` passed
with a lock refresh (69 sources, 552 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`.
The [Windows receipt](../evidence/m2-buffer-utf8-windows-20261029.json) records
the tested input hashes and both native binaries.

`buffer_utf8::validate(table, token, buffer)` checks the entire initialized byte
range and returns its byte length on success. It reuses the pinned Fairy C SDK's
allocation-free `std::text::validate_utf8`, already used for Brownie source input.
It returns no string, borrow, cached flag, character count or error offset.

## Checks and caller boundary

1. Resolve the token through `owners::describe`. Invalid or stale identity returns
   `Token` before native metadata or bytes are read. The complete 16-slot owner
   table must be valid; malformed descriptor state returns `State`.
2. Require exact native initialized length and capacity matches to the descriptor;
   otherwise return `State`.
3. Pass only `bytes::view(buffer)` to SDK validation. Invalid UTF-8 returns `Utf8`;
   valid input returns the validated byte length. Empty initialized input is valid,
   including a registered empty native root with capacity zero.

This read-only operation neither allocates nor changes bytes, initialized length,
capacity, token/generation, descriptors or accounting. It accepts a valid old root
while a replacement is pending, like [copy-out](m2-buffer-copy-out.md). A pending
replacement is not identified by the old descriptor: different native length or
capacity returns `State`. The API does not take a ledger or apply mutation quotas.

The trusted caller must supply the root associated with the table-local token and
keep it alive and unmodified throughout the call. Matching metadata does not
authenticate root identity, a different table or a different Instance. Validation
does not establish a persistent text property: content writes keep generation,
so any later consumer must validate the content it actually uses. No internal
borrow escapes this API.

Work is one bounded 16-slot table scan plus O(initialized byte length) SDK
validation, with O(1) auxiliary space and no payload copy or heap allocation.
The full scan is synchronous and unmetered. Chunked resumable validation,
cancellation polling, guest string/Buffer syntax, VM dispatch, Fuel integration
and guest borrow enforcement remain unfinished. This primitive does not satisfy
the M2 chunked UTF-8 milestone by itself.

## Focused Windows evidence

Development and release each passed 55 native scenarios: four new UTF-8 cases
plus 51 lifecycle/allocator regressions. All 110 processes exited with `live=0`.
The authoritative fixture is `probes/m2-buffer-failure/src/utf8.fy`.

| New scenario | Verified coverage |
| --- | --- |
| `utf8-valid` | Registered empty root, empty initialized range in allocated storage, all 128 ASCII bytes including NUL, 2/3/4-byte lower/upper boundaries, U+FFFF and U+10FFFF, BOM, mixed Korean/emoji/ASCII/NUL, and a full 256-byte range. |
| `utf8-invalid` | All 256 isolated byte values, overlong 2/3/4-byte encodings, first/last surrogate encodings, code points above U+10FFFF, an illegal four-byte leader, every truncated prefix of a valid four-byte sequence, truncated three-byte input, a broken continuation, and an invalid tail. Valid input succeeds after rejected input; changing its final byte to 255 causes the next check to fail without advancing generation. |
| `utf8-identity` | Invalid/stale tokens precede missing-root checks; wrong native length/capacity and a malformed unrelated slot return `State`; a fresh token and generation MAX validate unchanged text. |
| `utf8-pending` | Original text validates while a replacement is pending; that replacement fails old-token metadata checks. Corrupting only the replacement leaves the original valid. Discard/cancel retains original bytes and descriptors, restores usage 320/352 and preserves peaks 768/800. |

Each of the first three new processes performs one initial native allocation and
one final free. The pending case performs two allocations and two frees for the
old root and replacement. Repeated validation adds no allocation. These are FY
system-heap counts, not measurements of all process memory.

The archive rechecks 24 input hashes, 18 generated sources (eleven byte-identical
production modules and seven fixture modules), the generated lock and two binaries.
Earlier receipts retain their original inputs and historical scope.
Full native/CLI suites, M0, Linux, DLL embedding, isolation, packaging,
elapsed-time performance and Provider inconsistency fault injection were not run.
Whole-Instance Buffer cleanup remains unfinished.

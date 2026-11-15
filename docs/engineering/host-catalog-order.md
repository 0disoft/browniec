# Linear host-catalog name admission

`host_catalog::imports` used to compare each fully parsed import with every
previous decoded module/symbol pair, then check increasing qualified-name order.
For N valid imports, it performed N*(N-1)/2 duplicate-pair comparisons even
though all accepted entries already form a strictly increasing prefix.

The adjacent qualified-order check now runs first. If the new item follows the
last accepted item, transitivity proves it cannot duplicate any earlier pair,
so the parser publishes it directly. An ordering failure retains the original
full-prefix duplicate scan before returning `Duplicate` or `Order`. Parsing
returns immediately on either error, so this fallback can execute only once.
The table and decoded pool are privately owned; no caller-supplied sorted flag,
cache, new allocation, descriptor field or changed size limit is introduced.

## Error and identity preservation

The whole entry is still parsed before name admission. Import-limit, JSON,
decoded-key, required-field, spelling, ID and allocation failures retain their
earlier positions. A decoded nonadjacent duplicate still reports `Duplicate`,
even though it is also out of order, at the original entry-opening offset.
The comparator is unchanged and compares complete qualified ASCII spelling,
including the `host::a0::x` versus `host::a::x` prefix case.

Only the order of pure comparisons changes. Failed parsing publishes no
Catalog. Accepted descriptors, canonical bytes, SHA-256, accessors and real
catalog-to-wire composition retain their existing implementations. This is
metadata admission; public host dispatch and embedding availability are unchanged.

## Quantitative scope

| Valid catalog | Before | After |
| --- | ---: | ---: |
| Duplicate-pair comparisons, 64 imports | 2016 | 0 |
| Adjacent qualified-order comparisons | 63 | 63 |

For the same-module 64-import fixture, each old pair invokes two byte-equality
helpers, so those duplicate-path calls decrease from 4032 to zero. One rejected
entry scans at most 63 earlier pairs. Import 65 rejects at the limit before any
such scan. These are source-level operation counts; native time and physical
memory peaks were not measured.

Let S be input bytes and L the maximum compared name width. Name admission
changes from O(N^2 * L) to O(N * L), including the single terminal fallback;
the complete parse is O(S + N * L). N remains capped at 64, qualified spellings
at 194 bytes, and input at 16384 bytes. Extra space remains O(1).

## Focused verification

Run `build/toolchain/fairyc.exe check`, then
`python -B tools/verify-host-catalog-order.py --profile all`. The verifier
includes all twelve existing host-catalog native groups and three new groups:

- Every length-three sequence from eight distinct name pairs is checked against
  the original duplicate-first algorithm, both with literal ASCII and escaped
  ASCII names: 1024 cases with exact error kind and entry offset. The name set
  includes case differences, nested modules, underscores and qualified prefixes.
- A valid 64-import catalog is admitted. Every one of 63 earlier positions is
  repeated as the final import, including escaped spellings; all report the
  same duplicate category and offset. A distinct out-of-order final item
  reports Order.
- Missing fields still precede both duplicate and order errors; the 65-import
  limit still precedes name classification.

The unchanged reference verifier checks fixture provenance, exact native corpus
coverage, canonical bytes and independent Python SHA-256 answers. Native groups
also cover grammar/UTF-8, schema/type/name limits, owned descriptor storage,
binding identity, SHA padding boundaries and catalog-to-wire decoder composition.
Each profile uses the pinned compiler, default native settings and a byte-identical
input mirror. Reference calculations alone are not native runtime evidence.

See the [Windows evidence](../evidence/host-catalog-order-windows-20261116.json)
for final results and implementation/input identity. Full Engine transport,
public CLI, standalone memory, host dispatch and full release gates were not
rerun. The known legacy source failure was not retested or claimed fixed.

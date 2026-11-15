# Reuse authenticated root resolution within an operation

The private native root store resolves a serial and binding before metadata,
byte, lease and ownership operations. Its unchanged `ready` preflight validates
the complete owner table through `owners::accounted`, matches every live row's
slot/generation, rejects duplicate identities, and checks accounting. The old
`resolve_mode` then called `owners::describe` or `owners::writable`, repeating
the full table validation for the selected row. `describe` repeated it again.

The resolver now reads that row's already authenticated descriptor directly.
It still rejects a mismatched binding, a write under a read lease, and a native
Buffer length/capacity mismatch before returning. `describe` returns the same
descriptor without another raw owner lookup. The proof is valid only within
the synchronous call: the state is immutably borrowed, no callback or mutation
intervenes, and `ready` precedes all slot indexing. No caller-supplied proof,
unchecked public owner API, persistent cache, allocation or state field is added.

For successful operations on a healthy store, source-level calls to
`buffer_owners::valid` change as follows:

| Operation | Before | After | Validation slot visits, 16 slots |
| --- | ---: | ---: | ---: |
| `value_roots::describe` | 3 | 1 | 48 to 16 |
| `value_roots::len` | 2 | 1 | 32 to 16 |
| `value_roots::read` | 3 | 2 | 48 to 32 |
| `value_frames::buffer_read` | 6 | 3 | 96 to 48 |

The frame path first authenticates its key through `inspected`/`describe`, then
performs the root byte read. Its 4,096 successful reads therefore change from
393,216 to 196,608 full-validation slot visits. Direct root reads instead change
from 196,608 to 131,072 visits. These counts exclude accounting summation,
row/duplicate scans, native backing checks and all other work. The duplicate
checks remain O(n^2) for n live roots (n <= 16), so the whole operation's
asymptotic complexity is unchanged. Compiler optimization can change executed
machine work; throughput and physical memory peaks were not measured.

The standalone `buffer_owners` APIs and the final raw byte-read check remain
unchanged. Fuel prices and admission order, error mapping, mutation/publication,
lease release, generation exhaustion and cleanup retain their existing bodies.
The public CLI admission gate remains unchanged.

At the earlier checkpoint, `tools/verify-value-root-resolution.py` selected
eight native groups:

- Two new groups compare resolution, full descriptor fields, lengths, byte
  values/errors and no-op write admission against the original resolver and raw
  owner APIs. The existing independent root preflight oracle remains included.
  Twenty metadata variations across all 16 slots at 0, 1, 8 and 16 live roots
  combine with five handle queries: valid, zero serial, out-of-range binding,
  wrong binding and absent serial. Additional cases cover removed/reused slots,
  row ordering and terminal generations. Exact/insufficient Fuel and preserved
  native bytes are checked throughout.
- Two existing preflight groups cover all healthy root counts, metadata faults
  and 4,096 exact-price reads under a lease, with bounds/failure ordering.
- One existing lease group rejects all mutation forms, including no-ops, during
  read leases and verifies retirement, accounting and drain ordering.
- Three existing Buffer-root groups cover structural token changes, growth and
  transient quota rollback, exact Fuel, stale identity and generation exhaustion.

Run `python -B tools/verify-value-root-resolution.py --profile all`. Each profile
uses a locked byte-identical input mirror, the pinned compiler and default
native settings. The tracked [evidence](../evidence/value-root-resolution-windows-20261116.json)
records the final results and implementation identity. Full Engine transport,
public CLI, standalone memory and full release gates are outside this change;
the known legacy source failure was not retested or claimed fixed.

## Direct byte reads after authentication (2026-11-16)

The preceding table records the earlier resolver-only change. The subsequent
byte-read change removes the remaining raw owner revalidation from
`value_roots::read`. Its unchanged resolver already authenticates the full
owner table, exact slot/generation and selected native Buffer extent. Immutable
state/backing borrows and no intervening callback keep that proof local to the
read. The method checks the index against the initialized Buffer length before
forming a native byte view; no view or proof escapes. Standalone owner APIs
still authenticate independently. Fuel admission remains first and costs 257.

Compared with f5e13f9, successful direct reads reduce full owner-table checks
from two to one, or 32 to 16 validation-slot visits. Over 4096 reads this removes
65536 visits (131072 to 65536). Typed frame Buffer reads reduce three full table
checks to two. Root duplicate checks remain quadratic for at most 16 roots;
auxiliary state, allocation and API signatures are unchanged. These are source
operation counts, not measured throughput or physical-memory improvements.

`python -B tools/verify-value-root-read.py --profile all` selects eleven native
groups: the original raw-owner resolver oracle, full-store 4096-read and metadata
fault oracles, root lease and mutation regressions, actual typed-frame byte
access, and the existing eight-argument view CALL batch. The added boundary
group independently checks bytes/errors and raw-owner parity for lengths
0, 1, 63, 64, 65 and 4096, before and during a read lease. It covers the first, middle
and final byte, initialized-length and allocation-capacity boundaries, maximum
usize, exact/short Fuel, unchanged accounting and zero-Fuel cleanup.
The original resolver verifier now discovers nine groups because it also picks
up this boundary case; only discovery was rerun through that older entry point.

Results and scope are recorded in the
[Windows evidence](../evidence/value-root-read-windows-20261116.json). Full Engine
transport, public CLI, standalone memory and full release gates are outside
this focused change.

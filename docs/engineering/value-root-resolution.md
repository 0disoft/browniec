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

`tools/verify-value-root-resolution.py` selects eight native groups:

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

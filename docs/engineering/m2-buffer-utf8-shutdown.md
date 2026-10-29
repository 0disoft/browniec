# Explicit UTF-8 registry shutdown

Implemented and verified on Windows in development and release by
`python -B tools/verify-m2-buffer-failure.py`, following root `fairyc check`.
The [receipt](../evidence/m2-buffer-utf8-shutdown-windows-20261029.json) identifies
the inputs, generated project, instrumented binaries and allocator counters.

The [storage admission successor](m2-buffer-utf8-admission.md) now requires
`admit` before use and adds a mutable Ledger argument to shutdown for its final
refund. The results and unchanged-accounting statements below describe the
original shutdown slice at `469f9b8`.

## One-way lifecycle

The private [session registry](m2-buffer-utf8-pool.md) now exposes
`shutdown(pool, table)`. It transitions Open to Closing **before** attempting
cleanup, delegates to the existing batch drain, and transitions to Closed only
when drain succeeds. Failure returns State and retains Closing plus unresolved
Session state. Successful entries remain retired even if another entry fails.
After repairing inconsistent private metadata, the caller explicitly retries
shutdown; it visits only remaining live entries. There is no automatic retry.

Shutdown needs no Fuel, byte access, native root argument, allocation or new
reservation. It releases at most 16 leases with the existing bounded registry
and owner-table validation. It does not change payloads or usage/peak accounting.
Success returns the number released by this call. Repeated shutdown on a valid
Closed Pool returns zero without advancing generations. Closed consistency is
checked again; malformed state cannot bypass validation through idempotency.

The pinned compiler rejects executable assignment to an enum field in a nested
record. A private `u8 phase` therefore represents Open=0, Closing=1 and Closed=2;
all other values reject as State. Closed registries must have no live entries.
The field is host metadata, not a guest-controllable lifecycle command.

## Operation ordering

| Operation | Open | Closing or Closed |
| --- | --- | --- |
| `begin(true, ...)` | Cancelled | Cancelled, preserving cancellation-first precedence |
| `begin(false, ...)` | Existing admission | State before Fuel, lease or native access |
| `step(...)` | Existing Ticket/session checks | Invalid/stale Ticket returns Token first; otherwise State before Fuel, native access or cancellation cleanup |
| `abandon(...)` | Existing per-Ticket cleanup | Same cleanup remains available for retained Tickets |
| `drain(...)` | Batch cleanup | Same cleanup; never changes lifecycle phase |
| `shutdown(...)` | Enter Closing, drain | Retry Closing or validate idempotent Closed |

Closing never reopens through any operation. Successful individual abandon or
drain in Closing leaves Closing; invoke shutdown to record final Closed state.
Generation retirement, Session Fuel prices and ordinary Open drain remain
unchanged. Invalid lifecycle values reject shutdown without normalization.

## Host integration boundary

Call shutdown while the associated table and native roots are still alive. On
failure, preserve them and the Pool for repair/retry. After success, the host
can close each root using the existing begin/native-destruction/finish sequence.
The new close scenario executes that sequence and verifies restored charges.

This is an explicit host lifecycle hook. There is no common Instance owner or
shutdown dispatcher to bind it to yet. Discarding a plain Pool without calling
shutdown can still lose cleanup state. Metadata copying/overwrite, lower-level
lease release, raw native mutation/destruction and concurrent access remain
trusted-caller restrictions. Shutdown does not destroy native roots, detect
unregistered leases, release logical owner charges or implement complete
Instance cleanup. Registry storage admission, guest syntax/VM dispatch,
scheduler integration and automatic scope cleanup remain unfinished.

## Focused evidence

Both profiles passed 83 native scenarios: four new shutdown cases plus all 79
existing lifecycle/allocator cases. All 166 processes exited with `live=0`.
Every new scenario allocates/frees one initial 256-byte payload; bookkeeping
and shutdown add no heap allocation. Counts cover only the FY system heap.

| New scenario | Executed coverage |
| --- | --- |
| `pool-shutdown-close` | Partial multibyte scan blocks close; zero-Fuel shutdown releases its lease, retires its Ticket and permits actual native destruction and close accounting. Closed admission and stale-Ticket ordering are checked. |
| `pool-shutdown-retry` | One stale source blocks release while a distinct empty-root session cleans successfully. Closing rejects new work and cancellation-step without consuming Fuel or losing the held lease. Repair and explicit retry release only the survivor. |
| `pool-shutdown-complete` | Already completed scan closes without further retirement; repeated shutdown returns zero and old Ticket remains stale. |
| `pool-shutdown-state` | Malformed registry leaves shutdown in Closing; repair and individual cleanup cannot reopen it. Final shutdown closes; malformed Closed state and unknown phase reject instead of returning false success. |

The archive rechecks 34 input hashes, 28 generated sources, generated lock and
two native binaries. Full native/CLI suites, descriptor/replacement suite, M0,
Linux, DLL embedding, isolation, packaging, elapsed-time performance and Provider
inconsistency fault injection were not run. Earlier receipts remain historical
for the exact inputs and scopes recorded in them.

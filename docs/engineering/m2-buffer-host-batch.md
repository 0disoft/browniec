# Explicit host visitation for shutdown of multiple Buffer roots

Implemented and verified on Windows in development and release. Root
`fairyc check` passed (74 sources, 602 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`. The
[receipt](../evidence/m2-buffer-host-batch-windows-20261029.json) records inputs,
instrumented artifacts and exact allocator counters.

The [descriptor sweep successor](m2-buffer-host-sweep.md) now selects live
shutdown targets and tracks attempted slots/offers over this protocol. The host
still supplies and retains actual native resources.

## Host protocol

The [single-root shutdown](m2-buffer-host-close.md) now shares its actual
retirement/destruction/refund path with `close_stopped`. A host can explicitly
visit its independently owned roots after starting Pool shutdown:

1. Invoke Pool shutdown, or the existing single-root shutdown. A failed lease
   cleanup may leave the Pool Closing with its metadata charge retained.
2. Pass each independently writable root to
   `close_stopped(root, token, pool, table, ledger, plan)`. Retain every returned
   error resource. A failed preflight does not prevent visiting another root.
3. Repair failed lease/preflight state and explicitly retry only retained roots.
4. Call `finish_all(pool, table, ledger, plan)` after all tracked roots are closed.

`close_stopped` accepts Closing or Closed Pool state. Open, unknown phase and
Closed-with-admission state return the supplied root unchanged. An outstanding
lease on the selected root still prevents destruction through checked close
begin. An unrelated failed lease can remain registered while another writable
root is retired, actually destroyed and refunded. Pool metadata stays charged
until its own shutdown succeeds; ordinary root close never returns that charge.

Before starting a close, the helper validates the entire descriptor table and
checked sum of all live owner/payload charges. Instance usage must cover that sum
plus 2,112 metadata bytes while the Pool remains admitted. Aggregate overflow or
undercoverage returns the root before token retirement. This prevents a close
from spending another live root's or the registry's accounted bytes. The existing
close begin additionally enforces backing metadata, idle/consistent accounting
and snapshot rules. Arbitrary invalid shared table/accounting state can still
block every root; continuation applies only to independently admissible closes.

The ownership-returning `Result<usize, Buffer>` contract is unchanged. Success
returns remaining Instance usage. Failure returns the original root before
destruction, or an empty root when only an active close Plan remains to settle.
The single-root `shutdown` API retains its stricter rule: Pool shutdown must
succeed before initial destruction, and its active-Plan retry requires Closed.

## Exactly one pending close Plan

All visits must share **one** Plan and run sequentially. Close finish snapshots
the complete descriptor table and ledger. If destruction succeeded but finish
failed, another close would invalidate the snapshot required for retry.

An active Plan therefore admits only its matching token and an empty resource
for accounting-only retry. Every other root is returned without destruction or
table/ledger mutation. Repair and settle that Plan through `close_stopped` before
visiting another root. This path also works while the Pool is Closing; it does
not attempt another Pool shutdown or metadata refund.

Do not mutate owners/accounting, retry Pool shutdown, or use independent Plans
while a Plan is active. The supplied host APIs maintain this serialization;
arbitrary calls to lower-level helpers remain a trusted caller restriction.
No failed effects are automatically replayed or rolled back.

## Completion

`finish_all` rejects an Open/unknown Pool phase, active Plan, any live owner,
malformed table, inconsistent counters or pending growth transaction. The new
read-only `growth::settled` check also works at zero Instance usage; it validates
idle transaction fields and all current/peak counter orderings.

Only after those checks does completion finalize Pool shutdown/refund and return
remaining Instance usage. Unrelated background usage is preserved. Repeated
completion on a valid finished state returns the same usage without another
refund or generation change. Closing an already retired token still returns the
supplied empty resource as an error.

The operations add no allocation, payload copying or Fuel charge. Work remains
bounded by the 16-slot owner/Pool tables and existing snapshot checks; the caller
supplies the traversal and owns its root collection. No elapsed-time claim is made.

## Focused native evidence

Development and release each passed **95 scenarios**: four new multi-root cases
and 91 lifecycle/allocator regressions. All **190 processes** exited with zero
tracked live allocations. Each new case owns two distinct real payloads (256 and
64 bytes) and allocates/frees exactly twice; visits, failures and retries allocate
nothing. The archive rechecks 37 inputs, 31 generated sources (16 product modules,
15 fixtures), generated lock and both native binaries.

| New case | Executed coverage |
| --- | --- |
| `close-batch-partial` | Two leased roots; stale source metadata retains the first lease while the second releases. The second root closes during Closing without refunding Pool metadata. Repair and retry close the survivor and restore usage. |
| `close-batch-preflight` | Open-state visitation and premature completion reject. A root with a backing/descriptor length mismatch is returned while the other root closes. Repair then closes the retained root. |
| `close-batch-accounting` | The fixture constructs a destroyed-root active Plan with failed final accounting. Visiting the second root returns it unchanged and completion rejects; settling the repaired Plan permits the next close. |
| `close-batch-coverage` | One-byte aggregate undercoverage, owner-charge sum overflow and an unknown Pool phase preserve both resources and accounting; repair permits both closes. |

All cases preserve peaks at 2,560/2,592, restore Instance usage to zero and retain
32 bytes of unrelated Engine usage. Pending accounting blocks final completion;
repeated completion and stale-token close do not change charges or generations.
The accounting retry state is deliberately constructed with existing close APIs,
not injected concurrently inside native destruction.

## Integration boundary and skips

This is an explicit host visitation protocol, not an owning Instance container,
automatic root enumerator or scope destructor. The host must retain roots and
error results, use stable root/token/table/ledger/Pool associations and share the
same Plan. Equal metadata does not authenticate a native root. Buffer descriptor
coverage does not account for unrelated host resources or prove process RSS.

Counts cover the FY system heap only. Failed native SDK destruction, arbitrary
corrupted native roots, thread safety, automatic Instance ownership, guest/VM and
scheduler binding remain unfinished. Provider injection was not rerun: storage
preparation/provider code is unchanged, and earlier Provider receipts retain
their exact historical inputs. Full native/CLI suites, M0, Linux, DLL embedding,
isolation, packaging and elapsed-time performance were also not run.

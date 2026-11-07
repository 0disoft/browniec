# Private owning runtime input and staged output

This I01/I02 native source slice starts at `f78a734`. It provides real immutable
input snapshots and output staging with explicit trusted-owner publication. It
does not implement an Instance, guest input/emit instruction, VM success, entry
binding, public CLI/ABI, file/stdin reader or binary/JSON/text sink. Public gates,
Fuel prices/defaults/caps and existing source files are unchanged.

## Current successors

The paragraphs below describe the original unmetered component and its historical
receipts. [Metered guest execution](module-output-execution.md) now separately
admits and verifies `output::emit`, reserves capacity once, shares actual VM Fuel,
copies only each new suffix and seals only after successful completion. Its
[Engine binding](runtime-engine-outputs.md) retains or transfers the resulting
owner without exposing a failed prefix. The [input successor](runtime-engine-inputs.md)
binds OS-adopted Snapshots to actual Instances. Public controls, sinks, full
accounting and asynchronous runtime controls remain open.

## Input

`runtime_input::snapshot(data, limit, charge, ref mut fuel)` validates the entire
byte length against a caller limit and the 1 MiB hard ceiling before allocation.
It checks the supplied trusted Fuel charge, copies exact bytes into an actual
`bytes::Buffer`, then debits Fuel and publishes `Snapshot`. Every rejection,
including actual allocator failure, preserves caller bytes and Fuel. Empty input
is valid; neither UTF-8 nor C-string interpretation applies. NUL and all u8 values
are ordinary data. The original input need only remain immutable during the call.

The resource has private fields and owns its storage independently of the source.
`observe` returns detached length/charge data. `view` and checked `range` return
immutable borrowed bytes retaining Snapshot; range uses subtraction before sum.
There is no replacement API or mutable input view.

## Output

`runtime_output::open(limit, allowed, fuel)` creates an owning Transaction with a
fixed private state header. The limit cannot exceed 1 MiB. Its explicit native
allowlist flag controls emission; capability/policy admission must still be bound
by the integrating owner. Metadata alone never enables emission.

`emit(transaction, bytes, charge)` checks Open state, allowlist, remaining byte
quota, nonwrapping emit count and Fuel before allocation/copy. It prepares the
complete existing prefix plus new suffix in a fresh Buffer, then atomically moves
that backing into Transaction and publishes length/count/Fuel. Actual OOM leaves
the exact old bytes and all observations unchanged. There is no retry or callback.
Repeated appends copy the old prefix again: supplied trusted charges must cover
actual copying. This intentionally simple bounded transaction is not a chunked
builder or a performance claim. Empty emit is an explicit counted operation and
may consume a supplied charge, but makes no backing allocation.

Rejected quota/Fuel/denied operations preserve staging so the native owner can
choose the correct lifecycle outcome. They are not implicit VM results. Explicit
`fail` or `cancel` discards unpublished backing, sets length zero and freezes its
first terminal phase/Fuel/count. Destroying an unsealed Transaction also drops
its staging. Repeated fail/cancel cannot change a terminal observation.

Only explicit trusted-owner `seal(transaction, charge)` creates `Published`.
It checks Fuel before moving the single Buffer, charges once, and marks Sealed.
The move copies metadata only, not payload. Repeated seal and post-terminal emit
reject. `Published` has private fields and immutable `view`/`published_observation`
accessors; it outlives Transaction and caller input. Fail/cancel after seal leaves
the already-owned Published output unchanged. Empty sealed output is valid even
when emission was denied, because it contains no emitted bytes.

Phase codes are Open=0, Sealed=1, Failed=2, Cancelled=3. Observation is a copy,
not authority. Staged bytes have no external accessor. Seal is a trusted native
owner operation, not evidence that any actual guest VM completed successfully.
The integrating lifecycle must call fail/cancel on trap/deadline/poison/cancel and
call seal only after its real success decision. Output sink publication belongs
after this handoff; sink failures must not replay source or external effects.

## Ownership and pinned layout

The pinned compiler cannot mutably project owning resource fields. Output reuses
the validated `host_exchange` ownership technique: one leading Buffer, a fixed
40-byte private header with a pointer to its own allocation, and a narrow private
32-byte metadata move. The header never grows or exposes a pointer. The emptied
source is zeroed, matching SDK empty Buffer cleanup. Three nonallocating SDK
`reserve(0)` validation barriers are required before whole-resource moves/drop;
the earlier exchange slice demonstrated optimized heap corruption without them.
No new runtime shim, raw caller pointer, callback or ambient I/O is introduced.

The original verifier emitted actual C types and executed size/offset assertions
before the reserved-mode flag was added. These are historical layout measurements.
Pinned Windows x64 Buffer has size 32 and data/capacity/alignment/length at
0/8/16/24. Snapshot size is 40, Transaction 88, Published 72. Transaction backing,
header, header pointer, limit and allowlist occupy offsets 0/32/64/72/80.
The executed C hook inspects actual post-seal owners, verifies the emptied source,
binary bytes, fixed header identity, and zero live FY allocations at exit.
The hook and allocator instrumentation exist only in ignored test output.

## Scope of accounting and verification

Quotas count actual binary payload bytes (there is no wire header). Input and
output each allow at most 1 MiB; their limits are independent. Charged plus remaining
Fuel stays equal to the trusted initial budget, so charge addition cannot wrap.
Output preparation temporarily retains both old and new backing. This is logical
per-object accounting, not complete Engine/Instance peak/RSS accounting. Allocation,
growth and copying are synchronous; no R03 work quantum, mid-copy deadline or
allocator latency guarantee is claimed. No existing guest price is introduced.

Run `python tools/verify-runtime-io.py --profile all`. It writes only ignored build
projects/locks/evidence. Ten native groups in each development/release profile
exercise binary/empty input, immutable ownership, checked bounds, quota/Fuel
rollback, ordered staging, explicit seal, discard/terminal stability, detached
observations, maximum usize Fuel and actual 1 MiB boundaries. Negative compiler
cases reject private mutation/access, mutable Published bytes and input-view escape.
Two separate explicit C `/FI` allocator seams in each profile fail actual 320-byte
input and 384-byte append allocations, prove unchanged bytes/observations/Fuel,
and require explicit caller resubmission with no hidden retry and zero live storage.
`--native-from` optionally reuses hash-matching current-session normal reports
while rerunning every negative/layout/OOM seam. Native runs use default stacks; no CL/_CL_/LINK environment or /STACK override.

Receipts retain commands, streams, native reports, pinned compiler and exact runtime
Git objects, source/test/tool/doc/lock hashes, emitted C, layout executable hashes
and allocator counters. Test adapters only rename the test module and turn @test
entrypoints into callable public fixture functions; production source stays exact.
Only the new runtime input/output sources, focused test, verifier and this document
belong in the patch. Root lock/inventory edits, commits and remote changes are outside
this worker slice. Main owns future Engine/Program/Instance and guest integration.

# Shared and exclusive runtime slice tickets

The VM's existing `array_slices::Pool` now holds both readonly shared tickets and
exclusive range tickets within the same sixteen-slot ceiling. This is the
runtime storage foundation for the private exclusive IR and write instruction.
Public exclusive admission remains gated. Metered exclusive instruction dispatch
and guest mutable-slice syntax are not enabled by this stage. The
[VM successor](m2-slice-exclusive-vm.md) adds private metered execution and
invocation cleanup; guest syntax and public admission remain gated there.

Implementation: `1a278a1`.

## One pool and two access modes

Each slot adds an `exclusive` boolean while retaining its existing view, full
owner token, session epoch and independently retiring ticket generation. For an
exclusive slot, the existing lease fields carry the exclusive session identity;
the mode controls which checked owner API receives it. No second pool, payload
owner or per-frame mode array is added. The existing 512 frame/site ticket
references still point into one invocation-wide pool of at most sixteen handles.
No native-layout or process-memory measurement is claimed.

`open_exclusive` validates the pool and available capacity before acquiring an
owner write session. Range admission precedes lock publication; all fallible
work finishes before publishing the pool entry. Exclusive access locks the whole
root, including empty ranges. It conflicts with existing shared or exclusive
access to that root. Other roots can retain either mode independently.

`length` and `read` dispatch by mode. `write` accepts exclusive tickets only and
uses the existing checked scalar encoder; `i32`, `bool`, `i64`, `u8`, `u32` and
`usize` retain their signed/unsigned cell and width rules. Indexing is relative
to the selected range. Failed bounds, backing and value checks leave bytes and
metadata unchanged; earlier successful writes are not rolled back.

`utf8` dispatches through checked shared or exclusive access. The new native
`array_owners::exclusive_utf8` validates the active session and selected view
before scanning the `u8` range. Other scalar tags are rejected. Invalid selected
UTF-8 returns false, and empty ranges return true. Bytes outside the range are
not scanned. Ordinary root access remains blocked while an exclusive ticket lives.

Exclusive aliases/subranges and CALL argument retention are unsupported. Both
CALL borrow and close batches reject exclusive tickets before publication.
Readonly VM adapters and CALL admission also reject exclusive tickets so they
cannot reinterpret a writer as a shared read session. Their existing supported
instruction encodings and Fuel prices remain unchanged.

## Validation, generations and cleanup

Validation checks every live entry's mode, root/session identity and owner/view
shape. An exclusive root cannot appear in another live pool entry. Duplicate
writers, mismatched roots or epochs, wrong modes and exclusive flags on dead
slots fail before mutation. Duplicate checks scan at most sixteen slots for each
exclusive entry, within the existing fixed table bounds; this is structural
accounting, not a timing or Fuel measurement.

Close ends the matching owner session before retiring the ticket. The final
shared close preserves its existing last-handle rule. Failed close retains the
ticket and root lock. Ticket and owner-session generations never wrap: the last
generation can close once, then zero prevents reuse. Copied tickets alias one
handle and cannot close a later generation.

Whole-pool clear stages the pool and owner metadata, closes both modes in reverse
slot order, and publishes only after success. The existing VM drain therefore
handles mixed pools without a separate cleanup registry. It clears frame ticket
references only after successful pool cleanup. Successful cleanup preserves the
original result/error; failure surfaces the cleanup error and retains metadata.
Backing payloads and earlier writes survive cleanup and execution errors.

These are private table-local native APIs. The caller must preserve one owner
table/backing association, keep tickets private and balance cleanup. Forged
structs, cloned tables, direct session mutation and raw native backing writes are
outside this ownership guard. Root mutability, source lifetime and instruction
metering remain obligations of the future exclusive VM adapter.

## Verification

```text
python -B tools/verify-m2-slice-elements.py --profile development --exclusive-pool
python -B tools/verify-m2-slice-elements.py --profile release --exclusive-pool
```

The selection includes six new exclusive-pool groups, seven existing shared-pool
groups, four argument-batch groups and five typed borrowed-VM groups. CLI
regression includes 192 public scalar-slice and all 2,007 M1 cases on Windows.
The new native tests perform actual scalar writes and scans, mixed-mode cleanup,
stale/corrupt metadata rejection, full capacity and existing VM drain.

Development and release each passed all 22 selected native groups and 2,199 CLI
cases. Both matched 355 identical current input hashes; pinned compiler,
retained CLI, public matrix and full M1 receipt identities were rechecked. Both
profiles accept depth 32 and reject depths 33/64 with `compile_limit` in check/run.
Program fields remain unchanged. See the
[Windows evidence](../evidence/m2-slice-exclusive-pool-windows-20261101.json).

Full native and other M2 suites, Linux, M0, isolation, packaging, allocator and
timing checks are outside this selection. No exclusive VM opcode execution,
opcode60 Fuel price, mutable guest syntax or public capability is enabled.
Earlier receipts remain historical for their original source hashes. No push,
publication, packaged release or deployment is part of this local delivery.

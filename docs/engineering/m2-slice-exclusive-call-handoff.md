# Private exclusive CALL handoff and restore

The private native `slice_handoff` helper transfers existing exclusive slice
handles and restores fresh caller handles without ending their owner sessions.
This follows the [mutable-formal IR foundation](m2-slice-mutable-parameters-ir.md).
Mutable CALL IR admission, VM frame integration, runtime formal dispatch and
source parameters remain gated. Existing public owned mutable and readonly
slices keep their current behavior.

Implementation: `88b96ff`.

## Authority and publication

`array_slices::rotate_exclusive` validates the complete pool and selected live
exclusive ticket, then increases only that slot's generation. The slot, root,
range, scalar tag and write-lease epoch stay unchanged. The previous ticket
becomes stale immediately; generations never wrap or move backwards. It does
not acquire another owner session, slot or payload extent.

`slice_handoff::begin` accepts at most eight existing exclusive tickets and the
caller's zero-based frame depth, 0..30. It resolves every original input before
staging any rotation, rejecting readonly, stale, fabricated, duplicate-slot and
duplicate-root inputs. This prevents a guessed future ticket from becoming valid
because an earlier argument advanced a slot. It then rotates tickets in a local
sixteen-slot pool copy and publishes only after all rotations succeed.

The returned `Batch` records up to eight issued tickets, exact write leases,
count and frame depth. It contains metadata only. No Program field or pool-slot
field grows, and no payload is copied. A full sixteen-slot mixed pool can still
transfer eight exclusive inputs because their slots are reused.

`restore` takes the callee's current tickets in original argument order. Nested
calls may have advanced those tickets. Every current ticket must resolve in the
same slot, with a generation at least as new as the issued one, and match the
receipt's exact root token, scalar tag, range and owner write epoch. Unused receipt
entries must remain canonical. Wrong counts, reordered or duplicate inputs,
changed sessions, stale tickets and malformed receipts fail before publication.
It stages rotations, then publishes fresh caller tickets and clears the receipt.
The old caller and callee generations remain invalid.

The trusted native caller supplies the real frame depth, keeps one receipt per
active CALL and replaces its callee bindings after nested returns. A receipt is
not a guest-visible or cryptographic token. Receipt/table cloning, direct owner
session mutation and unrelated ticket rotations are outside this protocol.
Guests cannot construct these native metadata values.

## Generation reserves and errors

For maximum generation `M = 2^64 - 1` and caller depth `d`, entry requires
`generation <= M - (d + 2)`: one advance for entry and enough advances for this
return plus every outstanding ancestor. Restore requires
`generation <= M - (d + 1)` before advancing. At depth30 this supports the last
of 31 nested calls within the existing 32-frame bound; depth31 entry fails.
Repeated inner calls may exhaust additional headroom and are rejected before
mutation. A retired maximum-generation slot becomes permanently unavailable
under the existing pool close policy; an exhausted owner epoch is never reopened.

Entry/restore failure preserves the original pool, owner metadata, payload and
receipt. Prior guest stores are not rolled back. The native tests also use the
existing invocation drain with updated current ticket bindings: successful drain
preserves the original error and prior writes; a late owner-epoch mismatch reports
cleanup failure and retains metadata for diagnosis. This is abort-drain evidence,
not automatic restoration of suspended frames during executable mutable CALLs.

The helper performs bounded metadata work for eight arguments and sixteen pool
slots, independent of payload length. Each entry/restore operation stages one fixed pool
copy. There is no new Fuel price, opcode, profile or public capability; no native
allocation, stack-size or timing measurement is claimed.

## Verification and next integration

```text
python -B tools/verify-m2-slice-elements.py --profile development --exclusive-handoff
python -B tools/verify-m2-slice-elements.py --profile release --exclusive-handoff
```

The selection contains six new handoff groups, six unified exclusive-pool groups,
four readonly argument groups, four readonly CALL groups and six mutable-formal
IR groups. Public CLI regression covers 222 owned mutable, 192 readonly scalar
and 2,007 M1 cases. The new groups exercise actual writes for all six scalar
tags, relative/empty ranges, 31 nested transfers, stale/fabricated/reordered
inputs, generation exhaustion, changed owner epochs and full-pool abort cleanup.

Development and release each passed all 26 selected native groups and 2,421
CLI cases. Both matched 363 identical current input hashes. Compiler, retained
CLI and matrix/M1 receipt identities were rechecked; the Program declaration
matches `85e76f3`. Both profiles accept parser depth32 and reject depths33/64
with `compile_limit` in check/run. See the
[Windows evidence](../evidence/m2-slice-exclusive-handoff-windows-20261101.json).

Next, integrate this protocol with CALL argument validation, mixed owned/shared/
exclusive admission and frame return/error lifecycle. Entry must run on the
unpublished CALL plan so later argument/copy failures cannot publish ticket
changes. Complete costs must be prepaid before mutation. Track latest tickets
through nested returns, restore before caller resume, and distinguish normal
formal cleanup from global abort drain. Only then connect mutable formal
instruction dispatch, guest syntax and public admission. Aliases/subloans and
returned borrows remain future work.

Full native and other M2 suites, Linux, M0, isolation, packaging, allocator and
timing checks are outside this selection. No push, publication, packaged release
or deployment is part of this local delivery. Earlier receipts remain historical
for their original inputs.

# M2 Atomic Array Argument Copies

- Status: private storage primitive implemented and focused-harness verified; source and VM call integration pending
- Scope: `array_owners::copy_arguments`, with at most eight array sources
- Evidence: [Windows receipt](../evidence/m2-array-arguments-windows-20261025.json)

This is the storage foundation for immutable by-value array parameters. It does
not enable array parameter programs: the [signature gate](m2-array-signatures.md)
still rejects them before lowering any body. No opcode or CALL behavior changes.

## Copy contract

The helper accepts equal-length slices of source owner tokens and expected
canonical array shapes, plus caller-owned payload storage and an owner table.
The dense slices contain array arguments only. Mixed scalar/array argument
mapping belongs to future call lowering. Empty batches are valid; more than
eight sources or mismatched slice lengths fail with `Metadata`.

Each successful result contains a fresh owner token for every input, in input
order. Shape checks require exactly matching element tags and lengths; no
conversion occurs. Repeating a source produces distinct independent copies.
Unused result tokens have generation zero. The helper does not impose guest
binding mutability: future frontend/verifier integration must enforce immutable
callee parameters.

## Failure atomicity

Preflight starts with a value copy of the bounded owner table. For each argument:

1. Resolve the source against the original table, never provisional destinations.
2. Match its expected element and length and validate canonical shape metadata.
3. Reserve an eligible owner slot and an aligned extent in the provisional table.
4. Validate every source bool byte before recording the provisional owner.

All original extents remain charged. Each provisional reservation starts after
the preceding one, so the peak includes the original prefix, every new payload,
and all alignment padding. Retired generation-zero slots and retained extents
from deferred releases remain unavailable as required by the owner contract.

Any error returns before the first payload write or mutation to the actual owner
table. There are no partial copies to undo. On successful preflight, the helper
zeros destination padding, copies bytes into disjoint new extents, then publishes
the complete provisional table. That phase contains no allocation, callbacks,
or recoverable failure. Source bytes and source owners remain intact.

For example, a three-byte source followed by an aligned eight-byte source occupies
16 existing bytes. Copying both needs a 32-byte arena: the first copy ends at 19,
five padding bytes follow, and the second ends at 32. A ceiling of 31 rejects
the entire batch without changing the first provisional destination.

Work is O(K * C + B + Q), where K <= 8 arguments, C = 16 owner records,
B is copied payload plus padding, and Q is scanned bool payload. Each shape has
at most 32,768 payload bytes. The helper performs no heap allocation; scratch
state is one fixed owner-table copy and fixed eight-entry token/offset arrays.
This is a structural bound, not a measured performance claim or a VM Fuel tariff.

## Verification

```powershell
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice arguments
```

Development and release each passed 18 native groups: seven batch-copy groups,
five owner-lifetime groups, four single-copy groups, and two whole-assignment
storage groups. Fairy C revision `4ce1264273be` ran them on Windows x64.
New cases compare every owner field, order entry, arena field, and payload byte
after failures. They cover all six scalar elements, repeated sources, independent
copies, combined/aligned quota failures, late shape/token/bool failures, retired
slots, retained holes, provisional-source forgery, stale generations, empty/eight/
oversized batches, the sixteenth owner slot, and a 65,536-byte exact arena peak.

CLI execution, the full scalar/private-array native suites, M0, allocator
instrumentation, Linux, isolation, DLL, clean-machine, and performance checks are
outside this increment. Test images are temporary native artifacts managed by
Fairy C; the receipt identifies the compiler and exact input hashes.
All 29 other source inputs match the signature receipt. That comparison is not
a fresh CLI or VM/verifier test result, and the earlier receipt remains historical.

## Remaining call work

Source lowering must capture arguments exactly once, left to right, before later
argument effects. This helper copies the state supplied when it is invoked; it
does not implement capture timing or roll back earlier argument evaluation.
Independent verification must associate each captured array shape and owner with
the corresponding callee parameter and invocation. VM integration must meter
work before mutation and retain each recursive frame's parameters and locals
independently. Only then can the source signature gate be removed.

# Actual immutable input execution

`module_input_program::run(ref Program, ref runtime_input::Snapshot, fuel)` now
executes the admitted single shared-byte input entry and returns `Run { value,
remaining }`. It borrows the exact immutable Snapshot throughout the invocation;
there is no input payload copy, clipping or conversion to an image/array lease.
The accepted length remains 0 through **1048576** bytes. This private scalar
execution API does not supply Engine association, guest output, OS-reader
adoption, public CLI controls or a C ABI.

## Authority and transactions

The input entry repeats `verifier::inspect_input_returns` over the exact retained
code and literal Image. Ordinary reference execution still rejects external
kind-3 parameters. A separate input invocation admits exactly the already-proved
entry; no existing zero-argument entry is widened.

[Input metadata](input-reference-views.md) stores absolute windows separately
from existing packed 4096-byte image/loan words. Its reserved marker selects no
storage by itself. Every access requires a proved kind-3 site in the current
active native frame plus its invocation-private window. Input liveness follows
the same proved site bitset, while backing remains borrowed from the Snapshot.

PARAM binds the exact formal grant. ALIAS preserves its source window; RANGE
checks relative endpoints and narrows within the parent. Closing a site removes
only that descriptor. CALL validates/stages each input window with the other
image/loan/owned arguments before native entry; grants and child sites publish
only after entry succeeds. Input creates no native array capture or lease.

A returned input window must match both the independent recipe's selected formal
origin and that formal's actual passed grant. Containment alone cannot substitute
for the origin proof. Native leave restores all other arguments before publishing
the caller's result descriptor. No Held receipt is manufactured for input.
Native return and frame reuse clear all sixteen sites/eight grants. Any failure
aborts the canonical ownership state and destroys the entire private input map.
External effects and consumed OS input are never rolled back or replayed.

READ indexes the exact Snapshot bytes after bounds checks; LEN reports the full
actual window length, including empty ranges at the end of a 1MiB input. Original
image and array-loan accesses use their previous code paths and limits.

## Fuel and retained storage

Original opcode/dispatch/CALL/leave prices and public default256/ceiling16000000
are unchanged. New input-only metadata charges are explicit in `fuel.fy`:

| Work | Fuel |
| --- | ---: |
| Prepare 768 cells and prepay final destruction | 32768 |
| Input PARAM/access/alias/range/close metadata | 128 |
| Each staged input actual | 128 |
| CALL/return frame maintenance, 24 cells | 2048 |

These add to existing dispatch, static operations and canonical native
entry/leave costs. Complete native entry/copies and preparation are preflighted
before allocating the input map or entering the root frame. Every instruction
prepays its new metadata work before publication/read. Metadata cleanup remains
available when guest Fuel reaches zero. The actual pinned Vec allocation rounds
to 1024 cells/24576 bytes; this ownership is separate from input payload and any
65536-byte array backing. Full Engine accounting and R03/deadlines remain open.

## Native validation

Run `python tools/verify-module-input-execution.py` for development and release,
or choose `--profile development` / `--profile release`. The focused suite
contains ten input groups and six unchanged reference/module/depth regressions:

- Actual lengths 0/4096/4097/1MiB, full length and final byte, plus over-limit
  Snapshot rejection without charge or partial ownership.
- Nested cross-4096 ranges, empty end ranges, returned subranges passed through
  another CALL and distinct image/array/input roots.
- Distinguishable overlapping actuals selecting the second formal; corrupted
  origin and parameter metadata reject before any native owner/frame publication.
- Program reuse with different exact binary/NUL Snapshots, reversed/MAX ranges,
  bounds/division traps and exact original BOM/CRLF source-local/global offsets.
- Zero/partial/one-less/exact/one-more Fuel, preserving input and scalar results.
- Unchanged image/loan returned-reference Fuel, alias lifetime and invalid-formal
  preflight, named scalar/image/loan module execution and original depth32/33.

Input READ diagnostics retain the receiver's first byte; RANGE retains its opening
bracket and division retains its operator. Tests assert exact original source
identity and byte offsets, rather than replacing these existing anchors.
Receipts under `build/module-input-execution` retain all source/test/tool inputs,
compiler identity, exact native reports and commands. Default native stacks and
compiler environment restrictions remain; broad unchanged suites are not rerun.

Both native profiles passed **16 groups** on the same final inputs.
See [executed evidence](../evidence/module-input-execution-windows-20261107.json).
The independent metadata component also has [development/O2 and explicit OOM evidence](../evidence/input-reference-views-windows-20261107.json).

## Integrated identity and compatibility

Commits `3503aba` (metadata) and `c86aff6` (actual execution/Engine compatibility)
were integrated serially from disjoint worker mirrors. All 256 current aggregate
inputs match raw checkout and committed Git blobs; all 233 production modules
retain LF. The root check is 241 source files/2748 MIR functions. The original
232 production modules retain their bytes except the six listed VM/API/Fuel
changes. No fairyc checkout was modified or rebuilt, and no public capability,
existing capacity or prior price was widened.

The [Engine compatibility successor](runtime-engine.md#input-vm-compatibility-successor-2026-11-07)
compares eight actual typed bindings over its new 185-module closure and passes
both native profiles with zero heap allocations. Its 195 executed inputs match
integration bytes; unchanged native results were reused explicitly. The final
input suite ran in the root; baseline CLI/language suites were not repeated.
See [aggregate identity evidence](../evidence/input-execution-integration-windows-20261107.json).
All workers are closed. These are local commits; no push/release/deployment.

## Remaining work

Bind owning input Programs and the exact Snapshot to Engine/Instance lifetimes,
adopt actual OS-reader bytes, route guest `output::emit` through the real success
barrier, and finish full memory/work accounting, resumability/deadlines and
cancellation/poison behavior. Public project/input/output/host/restricted/embedding
and complete platform/profile delivery remain open in the accepted inventory.

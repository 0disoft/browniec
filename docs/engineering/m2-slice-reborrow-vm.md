# Private metered owned reborrow instruction adapter

`slice_reborrow_vm` connects private op61/62 to the canonical
[authority stack](m2-slice-authority.md) and existing invocation ticket bindings.
This stage supports exclusive owned scalar-array roots, including derived
parents, empty ranges and nested ranges. Immutable independently inspected IR
and the `Sites` derived from that same immutable Program are prerequisites.

This is native instruction-adapter execution, not shared VM-loop or guest-source
admission. Public verification and both internal execution entries still reject
op61/62. CALL while suspended remains rejected by inspection. Rootless mutable
formals are rejected by this adapter until canonical CALL parameter/site maps
and receipt ownership replace the existing mutable frame adapter.

## Fuel admission and authenticated publication

Each begin and end requires 65,537 Fuel. The fixed logical reserve covers bounded
metadata authentication, publication and eventual invocation cleanup; it is not
a native timing or machine-instruction count. Success returns the remaining
Fuel. Existing read/write/length/UTF-8 and public CALL prices are unchanged.

Static opcode, operand, function, catalog and owned-mode guards run first.
A one-short budget returns kind8 at the instruction's source offset before
runtime ticket, map, bound or owner lookup. With sufficient Fuel, the adapter
checks the canonical stack and all active child-site maps, then checks current
frame identity. Combined-depth exhaustion on begin returns kind12.

The private `Bindings` has three fixed 31-entry parent/child/function columns,
indexed by the authority receipt index. It stores no duplicate Loan/Batch
receipts, owner sessions or payload bytes. A readonly authority inspection API
reuses existing stack validation; admission/restore algorithms and State fields
are unchanged. Parent bindings for every active child must be absent, and child
site maps must be unique within a frame.

Runtime tickets must resolve against the expected frame-local owned root, exact
scalar tag and original owner length. A derived parent's current selection and
write session must also match its canonical child receipt and issued slot.
Rootless formals cannot bypass this check through a guessed origin binding.

Begin authenticates the parent, decodes usize bound cells and lets the native
transaction validate relative range bounds and generation headroom. Only after
success does it publish the site map, clear the parent binding and bind the
child ticket. End requires the exact top child/parent/function entry, an absent
parent binding and an authenticated current child; only successful restoration
publishes the fresh parent ticket, clears the child binding and clears the map.
Equal nested ranges cannot bypass receipt/site ordering. Scalar registers and
payload are unchanged by begin/end. The existing owned adapter can read/write,
measure length and validate u8 UTF-8 through an available child binding.

Wrong frames, occupied children, stale tickets, invalid maps/sessions, bad
bounds, short backing and generation failures leave stack, bindings and pool
unchanged. Unsigned cells use the existing reversible codec; negative i64 bit
patterns can represent large usize values and fail bounds without wrapping.

## Abort and lifecycle boundary

`finish` drains the authentic pool through the canonical authority stack before
clearing child maps, all 512 invocation ticket bindings and all 256 shared origin
bindings. Failed drain overrides the original outcome with cleanup failure and
preserves diagnostic metadata. Successful drain preserves prior writes and the
original success/error, even after a failed Fuel/bounds instruction. It releases
loan sessions, not owned arrays or external effects. Cleanup has no extra Fuel
parameter: successful admissions already prepaid bounded abort work.

Native callers keep the canonical authority and maps unique for the invocation.
They must not mix this receipt stack with duplicate live mutable-CALL Frame
receipts. The entire active child-map collection in this stage must use owned
roots. Normal CALL parameter maps, shared retention, owned argument copies,
scalar/control publication and aggregate return handling remain future work.

No Program, signature-table, owner, pool-slot, shared Frames, opcode or public
capability field grows. Additional fixed private map storage is 93 usize cells.
No allocator, native size/stack or performance claim is made.

## Verification and next integration

```text
python -B tools/verify-m2-slice-elements.py --profile development --reborrow-vm
python -B tools/verify-m2-slice-elements.py --profile release --reborrow-vm
```

Six new native groups cover six scalar tags and actual relative writes/reads,
exact/one-short begin/end Fuel, fifteen nested sites, equal/empty ranges, wrong
restore order, invalid bounds and backing, stale/occupied bindings, frame1 and
combined depth31, corrupt write-session receipts, atomic abort failure, preserved
writes/results and public/internal/rootless gates. They run with six order,
six authority and six existing owned-dispatch groups. These are direct native
adapter results; no guest program executes reborrow in the shared core.

Next is canonical CALL parameter/site mapping and lifecycle integration, including
rootless formal adaptation, then shared execution-loop wiring and deliberate
private inspection admission for suspended CALLs. Guest grammar and public
promotion remain separate deliveries.

Implemented at `995e22f`. Development and release each passed all 24 selected
native groups and 2,495 CLI cases, with 381 matching current inputs. Compiler,
retained CLI and all matrix/M1 receipt identities were rechecked. Program,
signature, verifier, execution-core, CLI/compiler, IR and native primitive sources
match `19e1886`. Native authority differs only by the readonly inspection API;
its State fields and previous algorithms match that baseline. Both profiles
accept parser depth32 in check/run and reject depths33/64 with `compile_limit`.
See the [Windows evidence](../evidence/m2-slice-reborrow-vm-windows-20261102.json).

Public CLI regression covers 74 mutable parameter, 222 owned mutable, 192 readonly
scalar and 2007 M1 cases on Windows. Full native, other M2, Linux, M0, isolation,
packaging, allocator, native size/stack and timing are outside the selection.
Local commits only; no push, publication, packaged release or deployment.

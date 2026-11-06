# Independent exclusive-slice place IR analysis

Date: 2026-11-06. Successor to the [native snapshot prerequisite](slice-selected-place.md)
and the [owned-array place graph](array-place-ir.md).

## Encoding and construction

The existing eight-byte SELECT 83, READ 84 and STORE 85 now use byte4 as a
location kind: zero retains the owned-array encoding; one names an exclusive
slice site in the repeated root operand. Bytes5..7 remain zero. END 86 is shared
across kinds and has zero bytes2..7. Other kind values are invalid.

`slice_place_ir::select/read/store` construct the slice form. Construction checks
exact scalar shape/operand roles and bounded output capacity but does not prove
definitions, availability, single use or permission to execute. READ reserves one
fresh exact-element scalar; the other operations reserve no value registers.
Array and slice selections share the same sixteen frame-local place IDs.

## Independent analysis

`verifier::inspect_slice_places` runs complete canonical ordinary-IR function,
scalar, owner, parameter, CALL, loan and CFG proof, then the common place graph.
It returns analysis only, not an executable receipt or retained image authority.
The [execution successor](slice-place-execution.md) now connects complete
executable admission and both drivers; this analysis-only result itself grants
no execution authority.

Each slice operand must identify an exclusive site of the containing function:
an owned-root slice, a rootless formal or a derived lexical child. The scalar
element is reconstructed from canonical metadata. SELECT/STORE inputs must be
defined ordinary scalars of exact usize/element type, not slots or aggregate/
slice placeholders. READ defines a fresh exact scalar. SELECT/READ/STORE require
available live authority; a suspended parent is rejected even when its child
has exactly the same byte range. Rooted slices also require their live owner.

The shared graph records the actual selecting PC and phase for each ID. READ
and STORE must agree with both the selected kind and exact root/site ordinal.
One optional READ precedes one STORE; END can finish or abandon a live place.
It cannot end a dead place. Re-selection, repeated READ/STORE and READ after
STORE fail. Forward joins/backedges require identical selecting PCs and phases,
including mixed kinds. Functions have separate place namespaces.

CLOSE 56 cannot end a selected slice, and END_CHILD 62 cannot restore away a
selected child, until its place END has executed. A selected parent may survive
a balanced child lifetime or a CALL, but cannot be read/stored while suspended.
Normal returns require no pending place; abort uses the existing drain rule.
Owned-array DROP guards remain specific to array locations, so an unrelated
same-numbered slice close does not invalidate an array selection.

Bounds, original range/session/extent authentication and payload publication
remain runtime obligations. The prior native snapshot supplies those primitives;
this proof alone does not run a RHS, access payload or authenticate a host token.
The extra graph retains the existing bounded 256-PC by sixteen-ID metadata;
no Program field, guest register/site/owner or payload allocation is added.

## Executable boundary and remaining work

The [execution successor](slice-place-execution.md) now admits the slice kind
through complete ordinary/image/returned-reference validation and both VM
drivers. The legacy array-only `place_vm::requirement` still rejects it before snapshot setup or
Fuel reservation, and `place_vm::cost` rejects it before a raw step can inspect
invocation state. A native caller cannot obtain execution by passing this
analysis result to an old adapter. The old owned-array encoding/prices and public
default 256/ceiling 16000000 are unchanged; no version flag or source syntax is
added.

The [metered native successor](slice-place-vm.md) now supplies explicitly tagged
slice/mixed invocation vectors and exact setup/operation preflight. It remains a
private adapter requiring the canonical caller-supplied restored ticket. Its [execution successor](slice-place-execution.md) connects both drivers and
complete admission/cleanup/retained guards. Source early selection and slice
compounds remain open. Record/scalar-local/grouped places, aggregate overlap and full
L04/C05/Instance/host/delivery remain open as well.

VM integration must retain an explicit location/format discriminator in its
invocation metadata. The common END instruction carries no kind, and vector
length alone may be ambiguous across different snapshot row widths. Dispatch
must use the active snapshot's kind rather than guessing from a current binding.
Existing array-only preparation and instruction prices must remain unchanged.

## Verification

Run `python -B tools/verify-static-execution.py --profile development
--selection slice-place-ir`, repeated for release. The focused selection combines
new slice-place proof/gate cases, existing complete array-place IR cases, native
array snapshot price/guard checks, source assignment/Fuel/cleanup regressions
and the original ordinary/retained 32/33 CALL boundaries. Public Fuel CLI checks
run separately with `tools/verify-public-fuel.py --phase cli` in each profile.

See [Windows evidence](../evidence/slice-place-ir-windows-20261106.json) for the
actual executed scope, input identities, LF mirror checks and skipped work.
These results do not establish executable slice places, a full language/Fuel
matrix, Linux, OOM, general stack/performance, worker isolation or delivery.

Development and release each passed **24 native groups** (nine new slice-place
proof/gate groups and fifteen existing array/proof/VM/source/CALL regressions)
and **57 tool-free public Fuel CLI cases**. The native selections each cover
175 identical input hashes; the CLI receipts each cover 179. Their 185-path
union matches the checkout and staged Git bytes. Both locked LF mirrors pass,
with 166 LF production modules and common 286-file test discovery. Forty
unselected legacy discovery fixtures differ only by CRLF/LF; both hashes are
recorded. There is no historical result reuse or native compiler/stack override.

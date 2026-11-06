# Independent owned-record place IR analysis

Date: 2026-11-06. Successor to [native record locations](record-selected-place.md)
and the [common array/slice place graph](slice-place-ir.md).

## Encoding and construction

The existing eight-byte SELECT 83, READ 84 and STORE 85 use location kind two
in byte4 for an owned-record scalar leaf. Byte5 repeats its depth-first scalar
ordinal, 0..127, in all three operations; bytes6..7 remain zero. Kinds zero and
one retain their array/slice encodings and zero byte5. Common END 86 has no kind
or field operand and requires zero bytes2..7.

| Operation | dst | a | b |
| --- | --- | --- | --- |
| SELECT | place ID | record site | zero |
| READ | fresh scalar | place ID | record site |
| STORE | place ID | record site | scalar value |
| END | place ID | zero | zero |

`record_place_ir::select/read/store` check mutable record shape, exact leaf and
scalar roles, output limits and canonical encoding. SELECT needs no index
register. READ reserves one fresh exact scalar; the other operations reserve
no value register or owner. Builder success does not prove definitions, live
ownership, affine phases or executable admission. Failed construction preserves
instruction/register counts and existing instructions.

## Independent proof

`verifier::inspect_record_places` admits kind two to complete ordinary-IR
function/catalog/parameter, scalar-definition, owner, CALL, loan and CFG analysis,
followed by the common selected-place graph. It returns an analysis count,
never executable authority or an immutable-image receipt.

The canonical verifier prepares the exact record catalog once and passes its
derived leaf counts/types through both analysis passes. Record operations do
not replan the catalog per instruction. Direct native `place_ir::inspect`
prepares its own catalog; that graph still does not replace canonical proof.

Each record site must belong to the containing function, be mutable and be
live in the record-owner plane. Its scalar ordinal must exist in the prepared
nominal layout. READ must define a fresh ordinary scalar of that exact type;
STORE must read a defined ordinary scalar of that exact type. Slots and
array/record/slice parameter placeholders cannot masquerade as scalar values.
The SELECT zero operand is not interpreted as a scalar register.

All kinds share sixteen frame-local place IDs. The graph retains the actual
selecting PC and phase, and ties READ/STORE to the exact selected kind, record
site and field ordinal. Same-type fields cannot be substituted. Re-selection,
repeated READ/STORE, READ after STORE and dead END fail. One optional READ
precedes one STORE; END can also abandon a live selection.

Joins and backedges require identical selecting PCs and phases. Functions have
separate ID namespaces, so a caller can retain a place across a balanced CALL.
Record DROP 45 cannot end its selected root before END. Array DROP and slice
close/end guards remain specific to their own namespaces even when numeric
IDs coincide. A record place can coexist with an exclusive slice of an
unrelated, same-numbered array. Normal returns require no pending places;
terminal aborts may retain obligations for the future runtime drain.

The graph retains its existing 256-PC/sixteen-ID bounds. No Program field,
guest owner/site or payload allocation is added. Runtime generations, actual
reservation/offset authentication and payload mutation remain the native
snapshot/VM adapter's responsibility.

## Execution gate and remaining work

At this analysis checkpoint executable admission accepted at most kinds zero/one.
The [execution successor](record-place-execution.md) now connects complete kind2
admission, both drivers and image/returned-reference/recipe guards. The named
slice-only analysis and both old native adapters retain their original dialects.
An analysis result or storage helper alone cannot bypass complete admission.
No source grammar, capability flag, existing instruction price, default256 or
ceiling16000000 changes.

The [metered native storage successor](record-place-vm.md) now supplies private
record-capable frames and exact setup/instruction preflight; the execution
successor supplies both drivers and guards. Record source early selection and
compounds remain next. Scalar-local
and grouped places, generic aggregate overlap and full L04/C05/Instance/host/
delivery remain open.

## Verification

Run `python -B tools/verify-static-execution.py --profile development
--selection record-place-ir`, repeated for release. The selection has nine new
record-IR groups, eight existing array-IR groups, nine slice-IR groups and the
two original captured-call 32/33 boundary groups. It covers all six scalars,
nested/same-type field identity, exact roles and definedness, phases, root/drop/
return/abort obligations, mixed array/slice/record namespaces, joins/backedges,
per-function IDs, atomic builder failures, 128 leaves/registers, sixteen IDs,
the final selectable PC and early execution/adapter rejection.

`tools/verify-public-fuel.py --phase cli` rebuilds each profile and checks the
existing 57 tool-free public Fuel CLI cases. See
[Windows evidence](../evidence/record-place-ir-windows-20261106.json) for actual
commands, input/compiler/artifact identities and executed results.

Full language/original full native Fuel matrices, Linux, OOM injection, general
stack/performance characterization, worker isolation and packaging/clean-machine
delivery are outside this focused proof slice.

Windows development/release each passed **28 native groups** and **57 tool-free
public Fuel CLI cases**. Native/public receipts cover 177/182 input paths; their
187-path union matches staged Git raw bytes and the checkout. Both locked LF
mirrors pass, with 169 LF production modules and common 291-file discovery.
40 unselected legacy discovery fixtures differ only by CRLF/LF, with both raw
hashes recorded. No historical results or native stack/compiler/linker overrides
were reused. The skipped scopes above remain unverified by this selection.

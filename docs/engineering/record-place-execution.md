# Owned-record places in both VM drivers

Date: 2026-11-06. Successor to [metered record-place storage](record-place-vm.md)
and [independent record-place proof](record-place-ir.md).

## Complete admission and canonical bindings

Ordinary, image, generic-reference and returned-reference admission now accept
kind2 SELECT/READ/STORE only after complete scalar, owner, ordinal/type, CALL,
CFG and common place identity/phase/lifetime proof. The named slice-only analysis
entry retains its kind0/1 scope. Constructing IR or allocating a native place
vector alone still confers no execution or image authority.

Both drivers prepay record-capable setup exactly once. Public wrappers include
that cost in the preflight before backing allocation or native owner entry.
Programs without record places retain their existing vector formats and costs.

For SELECT, ordinary execution resolves `struct_vm::State.tokens[frame*16+site]`;
retained execution uses `slice_result_record_bindings::get` on its canonical
sparse map. Both maps already receive normal INIT, COPY, CALL, returned-record
transfer and frame cleanup publications. The selected snapshot never supplies
the current binding. The drivers preflight the instruction price before the
lookup, then call `record_place_vm::bound`. No owner-map materialization, new
owner/reservation or extra instruction operand is needed.

Complete admission has already reconstructed each exact scalar type and field
ordinal. Executable READ/STORE pricing therefore uses the immutable admitted
scalar register type. SELECT has no payload cost; after prepayment, native
selection determines its field tag from the authenticated nominal owner. Native
READ/STORE still reauthenticate the captured owner, nominal record, reservation,
ordinal, tag and byte offset. A later descriptor or same-type field substitution
cannot redirect the saved target. This avoids preparing the entire record
catalog again at invocation setup or before every instruction. The older native
`step` API still accepts independently prepared catalogs for direct adapter use.

## Cleanup, mixed IDs and returned references

Record, array and slice rows share IDs and frame counters. Both drivers route
common END through the record adapter when record-capable storage is active;
other array/slice instructions retain their existing bound dispatch. CALL checks
that the child frame is empty before reuse. Every normal scalar, aggregate,
reference and void return checks its frame counter before cleanup/handoff.
Selected record DROP and missing END remain rejected by the independent proof.

Any runtime error discards invocation place metadata and runs existing canonical
abort cleanup, preserving earlier payload writes and the original error. A
post-STORE Fuel failure does not roll back that store or replay the invocation.
An explicit fresh invocation is allowed only after normal cleanup succeeds.

Static recipes now permit the canonical record encoding, including the repeated
0..127 scalar ordinal in byte5. SELECT's zero b operand is not a scalar read;
STORE still reads b. Complete ordinary admission remains mandatory after recipe
inspection. Plain records cannot back the current byte-reference result types,
so returned-array protection must not interpret a record site as an array or
slice site. Array/slice access to an actually protected root remains rejected.

## Independent Fuel oracles

Existing operation prices, default256 and public ceiling16000000 remain. The
fixture initializes two nested i32 leaves with 20/99, selects leaf0, reads its old
value, adds22, stores42, ends, reads the actual leaf, drops the root and returns.
Its five scalar/return instructions cost5; INIT46145, SELECT41025, READ41029,
STORE41033, END22, final record READ41281 and DROP65 total **210605** body Fuel.
Record-capable width1 preparation is5077.

| Entry | Exact required Fuel |
| --- | ---: |
| Ordinary native, eight backing bytes | 215691 |
| Ordinary public native-IR wrapper, 65536 backing bytes | 281219 |
| Retained native over caller-owned eight-byte backing | 559753 |
| Retained public native-IR wrapper, 65536 backing bytes | 625290 |

Retained native adds initial entry147456, final leave196608 and seven existing
extra aggregate/place dispatch units. Public backing is charged separately.
At retained native Fuel321773, STORE has published42 but the next END cannot
start; abort must retain those bytes and drain owners/authority before explicit
retry. These native-IR fixture totals are not source-lowering oracles.

## Verification and remaining work

The focused `record-place-execution` selection tests the exact/one-short/one-more
budgets, six scalar types, nested ordinals, caller/callee same-ID snapshots,
by-value record arguments, record-result owner transfer, returned-array/record
namespace separation, post-store abort/retry and malformed early admission.
It includes record proof, native adapter boundaries, existing slice execution,
returned-owner protection and original ordinary/retained 32/33 CALL limits.
Public CLI Fuel tests remain a separate tool-free regression selection.

The [source successor](record-place-assignment.md) now connects ordered record
field selection, ten checked compounds and cleanup lowering. This native-IR
checkpoint itself added no source flag; the successor advertises two narrow
record-assignment flags. Scalar-local/grouped places,
generic aggregate overlap and complete L04/C05/Instance/host/delivery remain
open. Full language/original full native Fuel matrices, Linux, OOM injection,
general stack/performance, isolation and clean-machine delivery are not implied.

Windows development/release each passed **27 native groups** and **57 tool-free
public Fuel CLI cases**; see [the evidence](../evidence/record-place-execution-windows-20261106.json).
The 190-path input union matches checkout and staged Git raw bytes.
Both locked LF mirrors pass with 170 production modules and
293-file discovery. The 40 unselected CRLF/LF-only discovery differences
are recorded separately. No historical result reuse or native compiler/linker/
stack overrides were used. The skipped scopes above remain unverified here.

# Private mutable scalar-slice formal IR

The IR can now describe a rootless mutable scalar-slice formal and independently
prove its body. This is the descriptor and body-validation foundation for future
mutable CALL arguments. Existing owned mutable slices and readonly parameters
remain public. Mutable formals, their CALL execution and source syntax remain
unavailable.

Implementation: `33da699`.

## Encoding without growing Program

`Program.slice_elements` keeps its existing sixteen bytes. Owned sites retain
0 for shared or 128 for exclusive. Readonly rootless sites retain their exact
scalar tag. A private mutable formal uses bit 128 plus the exact scalar tag:

| Element | Mutable formal byte |
| --- | ---: |
| i32 | 129 |
| bool | 130 |
| i64 | 137 |
| u8 | 138 |
| u32 | 139 |
| usize | 140 |

`ir::exclusive` reads the high bit; `ir::borrow_element` decodes the low seven
bits. These helpers do not validate metadata. The checked shape lookup and
independent metadata proof reject unknown tags, flag-only rootless byte 128,
typed flags on owned roots, orphan flags and inconsistent origin/function data.

`slice_builders::parameter_exclusive` applies the existing checked typed formal
constructor, then sets the mode bit with no remaining fallible work. Failure
preserves register counts and all formal/site metadata. A formal still reserves
one existing argument position, with scalar type zero and no payload owner.
Its root is zero, origin is its own site plus one, and function is its helper
function ordinal plus one. Duplicate positions, entry parameters, invalid
partitions and capacity exhaustion remain rejected.

Mutable rootless derived sites are not allowed. They must be self-anchored
formals; `derived` and SUBSLICE reject writers. Sixteen formal descriptors fit
across two eight-argument helpers within the existing site/register ceilings.
That capacity test proves metadata only, not CALL or runtime capacity.

## Independent body proof and execution gate

`slice_parameters::initial` marks each formal live at function entry. The slice
flow verifier uses the decoded scalar tag for relative reads, length, u8 UTF-8
and opcode60 stores. Stores require a live exclusive site, ordinary defined
same-function usize index and exact scalar value. They do not define registers
or alter loan live sets. Existing close, return, branch/backedge and definition
proofs still apply. Undefined values, wrong widths/tags and missing close fail.

`inspect` admits a fully proved unused mutable helper. It rejects every CALL
to a mutable formal because the argument checker explicitly rejects either an
exclusive destination or source. Thus readonly coercions, mutable forwarding and
mutable calls cannot enter an executable inspected call graph in this stage.
This does not implement argument transfer or restoration of caller authority.

Public `verify` performs the complete proof first, then rejects every rootless
exclusive site at offset zero, including unused helpers. VM entry therefore
fails before backing preparation, Fuel or instruction dispatch. Malformed body
and CALL errors retain their independent proof errors rather than being hidden
by that gate. Owned marker128 sites continue to pass public verification.

Existing CALL costing/root resolution, readonly instruction adapters and owned
exclusive adapters reject mutable formals. Native tests check these private
boundaries with zero Fuel, empty payload and unchanged register/ticket state.
There is no mutable-formal payload read/write execution claim.

## Verification selection and next slice

```text
python -B tools/verify-m2-slice-elements.py --profile development --mutable-parameters-ir
python -B tools/verify-m2-slice-elements.py --profile release --mutable-parameters-ir
```

The selection includes six new formal-IR groups, four existing parameter groups,
five builder groups, six owned-exclusive IR groups and five borrow-flow groups.
Public CLI regression covers 222 owned mutable, 192 readonly scalar and all 2,007
M1 cases. No version capability, opcode, Program field, source grammar or Fuel
price changes. New native tests are descriptor/proof/gate evidence, while CLI
tests exercise the already-public owned mutable and readonly implementations.

Development and release each passed all 26 selected native groups and 2,421 CLI
cases. Both matched 361 identical current input hashes; pinned compiler,
retained CLI, both matrix and full M1 receipt identities were rechecked. Both
profiles accept parser depth 32 and reject depths 33/64 with `compile_limit` in
check/run. Program fields remain unchanged. See the
[Windows evidence](../evidence/m2-slice-mutable-parameters-ir-windows-20261101.json).

The next integration needs an atomic exclusive CALL handoff/restore protocol,
including duplicate-root rejection, callee return/error cleanup and retained
caller authority. It must be implemented before mutable CALL admission, runtime
formal dispatch, source syntax or public promotion. Mutable aliases/subranges
and returned borrows remain outside this descriptor stage.

Full native and other M2 suites, Linux, M0, isolation, packaging, allocator and
timing checks are outside this selection. No push, publication, packaged release
or deployment is part of this local delivery. Earlier receipts remain historical
for their original inputs.

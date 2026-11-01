# Private exclusive slice-write instruction

This document records its named implementation checkpoint. The
[public mutable-slice successor](m2-slice-exclusive-public.md) now enables public
verification and execution; gate statements below describe the earlier stage.

The independently inspected exclusive IR now has a typed store instruction.
It is a construction and verification foundation; public execution remains
blocked by the existing exclusive-site gate. No guest mutable-slice syntax,
runtime write dispatch or instruction Fuel price is enabled.

Implementation: `caea3d2`.

The [runtime pool successor](m2-slice-exclusive-pool.md) supplies exclusive native
tickets and mixed-mode drain. The later
[metered VM successor](m2-slice-exclusive-vm.md) connects opcode 60 and the other
owned exclusive operations to private execution; public admission remains gated.
The remaining sections describe this IR-only checkpoint.

## Encoding and construction

Private opcode 60 uses the existing eight-byte encoding:

| Byte | Meaning |
| --- | --- |
| 0 | Opcode 60 |
| 1 | Live exclusive slice site |
| 2 | Ordinary `usize` index register |
| 3 | Ordinary exact-element value register |
| 4-7 | Zero |

`ir::slice_write` checks the existing owned exclusive marker, scalar root shape,
exact value tag, ordinary operand kinds and register bounds before emitting.
It returns the instruction PC, records the source offset and allocates no scalar
register. Wrong tags, readonly sites, slots, aggregate/borrow positions, invalid
IDs and code exhaustion preserve code, offsets and register/constant counts.
`i32`, `bool`, `i64`, `u8`, `u32` and `usize` are distinct exact tags; equal-width
types do not interchange. Construction does not prove liveness or definitions.

## Independent proof and public gate

`verifier::inspect` validates opcode 60 against the full Program metadata and
current function's flow state. The destination must be a live exclusive owned
site with a live mutable array root in the same function. Both operand registers
must be defined ordinary snapshots in that function; the index must be `usize`
and the value must have exactly the root's scalar element tag. Mutable slots,
aggregate/borrow parameters, undefined values and foreign registers fail.

A store does not define a register, consume the slice or change any owner/loan
live bit. Repeated writes and following reads retain their existing definitions
and lifetime. Closed/unopened and readonly sites fail. All reserved bytes remain
independently checked; malformed or unknown instructions cannot bypass the proof.
Existing exact joins/backedges and reverse cleanup obligations still apply.

Public `verify` first runs this proof, then rejects any exclusive declaration.
VM entry therefore fails before backing preparation, Fuel or shared dispatch.
Opcode 60 without exclusive metadata also fails the independent proof. Native
tests validate construction/inspection; they do not execute guest slice writes.

Index values, selected-range bounds and codec/store failures still require the
future checked runtime adapter. No native pointer, payload clone, new Program
field or scalar register is introduced. Code and register ceilings remain 256
instructions and 128 registers; the sixteen-site limit and existing Fuel prices
are unchanged. No timing, allocator, stack-size or native-layout measurement is
claimed.

Next work connects runtime exclusive tickets, metered open/read/write/close,
UTF-8 access and normal/error cleanup to the existing native
[owner-session APIs](m2-array-write-leases.md). Public syntax and admission must
follow that integration.

## Verification

```text
python -B tools/verify-m2-slice-elements.py --profile development --slice-write-ir
python -B tools/verify-m2-slice-elements.py --profile release --slice-write-ir
```

The selection includes five new write-IR groups, six existing exclusive-IR groups
and three public scalar-slice groups. Development and release each passed all
14 selected native groups and 2,199 CLI cases: 192 public readonly scalar-slice
and all 2,007 M1 CLI cases on Windows. Both matched 354 identical current input
hashes; compiler, retained CLI, public matrix and full M1 receipt identities were
rechecked. Both profiles accept depth 32 and reject depths 33/64 with
`compile_limit` in check/run. Program fields remain unchanged. See the
[Windows evidence](../evidence/m2-slice-write-ir-windows-20261101.json).

Full native and other M2 suites, Linux, M0, isolation, packaging, allocator and
timing checks are outside this selection. Mutable parameters, subloans, returned
borrows, runtime exclusive cleanup and guest write execution remain unsupported.
Earlier receipts are historical for their original inputs. No push, publication,
packaged release or deployment is part of this local delivery.

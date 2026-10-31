# Private dynamic slice instruction adapter

Admission update: the [public successor](m2-array-slice-parameters-public.md)
now enables verified readonly u8 slice calls. Gate-rejection statements below
refer to the original private checkpoint and its historical receipts.

Implementation: `af8ad1e`. [`slice_frame_vm.fy`](../../src/slice_frame_vm.fy)
adds a private native instruction boundary for immutable, independently
inspected Programs. It combines a same-function PC partition with the
[borrowed-frame context](m2-array-slice-call-vm.md) and supports opcode 55
(`slice_utf8`), 56 (`slice_close`), 57 (`slice_length`), 58 (`slice_read`)
and 59 (`slice_sub`). The later [shared lifecycle](m2-array-slice-lifecycle-vm.md)
connects it to the shared VM loop; public borrowed CLI execution stays gated.

## Dispatch and roots

The supplied `pc` must be inside the function's static `starts`/`ends`
partition; function, frame, opcode, Program metadata, register width and site
must be bounded. The adapter checks these fields and canonical operands before
an operation, reporting kind 5 at the instruction's source offset.

The dynamic site follows the encoding: `dst` is the site for 56 and 59;
`a` is the site for 55, 57 and 58. For opcode 56, `dst` is a static slice
site and operands `a` and `b` must both be zero. For 55, 57 and 58, `dst`
is an output register index bounded by the runtime register width; it does
not need to contain an already defined runtime value.

Opcodes 55 and 57 require `b=0`. Opcode 58 bounds index `b`; opcode 59
bounds both endpoint registers. For 55 through 59, unused operand bytes must
be zero. Independent inspection guarantees operand types and definition flow;
the adapter checks bounds, static-site references and canonical encodings, not
runtime definition tracking. These checks precede the instrumented path.

For a rooted site, the adapter resolves `calls::root` and delegates to the
original `slice_vm.step` path. Existing owned-slice prices, owner checks,
sessions, ticket publication and array behavior remain exact; no second owned
price or duplicate core operation is added.

Borrowed formal and derived sites support 55 through 59, but rootless opcode
54 (`slice_open`) is rejected. Opcode 59 rejects a rooted parent, a parent
whose root origin or function metadata differs from the child, and a formal
used as a reslice destination. The child must be inactive and its relative
endpoints must be ordinary bounded registers.

`calls::root` selects the current frame's full-width owner token: the owned
array token for a rooted site, or the formal token bound for a borrowed or
derived site. Derived children still resolve after the formal anchor ticket is
closed. A rootless site without a current same-function formal binding fails.
The token must identify a live owner.

A borrowed ticket must come from the current loan state and pool, match the
token's root slot and generation, name a u8 element, and retain the original
full-origin shape. A selected range may be empty. These provenance checks and
core pool/session validation complete before a child is published or an
operation reads or closes data.

## Two-phase Fuel

The first phase checks a fixed base before dynamic owner or backing resolution:
4097 for length, close and UTF-8; 4131 for read; and 65537 for sub. Shortage
returns kind 8 at the instruction offset without publishing a register,
ticket, owner or session.

After base admission, a metadata-only `owners::view` checks the actual u8
root and requires length 1..4096. It does not read payload or allocate a root
or context. A metadata error may therefore precede a later scan-Fuel shortage;
a base shortage still precedes all dynamic resolution.

UTF-8 then requires `4097 + 4 * actual full-origin length`. This charge uses
the root length, not the selected child length, and is checked before source
ticket resolution or payload reads. A small or empty child of a large root
therefore carries the full-origin scan cost. Other operations do not charge
selected length as payload work.

Opcode 59 endpoints are relative to the selected parent, not the root. They
must satisfy `0 <= start <= end <= parent.len`; the existing subslice helper
performs the remaining ticket, owner, session and pool checks and publishes a
child only after success.

## Publication and failure behavior

UTF-8 writes only a boolean output. Length, read and sub publish after their
core helper succeeds. Close clears the selected frame/site ticket only after
the core close succeeds. A failed call leaves existing tickets, registers,
owner generations, sessions and payload unchanged; rooted failures preserve
`slice_vm.step` atomic behavior.

This boundary copies no payload, creates no owner or context, adds no opcode or
capability, and does not enable the gate. The later
[shared lifecycle](m2-array-slice-lifecycle-vm.md) connects instruction dispatch
and normal/error cleanup. The
[mixed borrowed/owned transaction](m2-array-mixed-call-vm.md) is now connected
to executable CALL through the [frame publication adapter](m2-array-call-frame-vm.md).
Public borrowed-source gate promotion remains separate.

## Focused verification

[`tests/m2/slice_frame_vm.fy`](../../tests/m2/slice_frame_vm.fy) constructs IR
manually and inspects it natively. Its four new groups cover exact prices and
children after anchor close, Fuel/backing/provenance failure, empty ranges and
UTF-8 values, and malformed or capacity-limited operands. Three existing
`slice_sub_vm` groups complete the seven-group native selection. Tests use
native setup and adapter calls; no guest borrowed execution is claimed.

```text
python -B tools/verify-m2-array-utf8-source.py --profile development --slice-frame-vm
python -B tools/verify-m2-array-utf8-source.py --profile release --slice-frame-vm
```

Both development and release verification passed seven native groups and 326
tool-free CLI invocations per profile, with 337 tracked source/test/tool hashes
and the retained CLI binaries matching. The main integration run will archive
the [Windows evidence](../evidence/m2-array-slice-frame-vm-windows-20261031.json).
Broad suites, Linux, DLL embedding, isolation, packaging, allocator measurement
and timing were not rerun.

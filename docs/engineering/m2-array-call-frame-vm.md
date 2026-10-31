# Gated VM CALL frame publication

Implemented at `89bd0bf`. Development and release each passed four native
groups and 2,297 CLI invocations, with 369 matching input hashes and retained
CLI identities.

The [CALL adapter](../../src/call_frame_vm.fy) connects the executable VM's
CALL opcode to [mixed owned/borrowed admission](m2-array-mixed-call-vm.md).
Public execution still rejects borrowed signatures before backing preparation
or dispatch. This slice does not enable borrowed guest execution.

## Transaction boundary

The adapter requires an immutable independently inspected Program. It checks the
CALL site, combined Fuel, parent frame, child register and return-table spans,
caller/callee register partitions, result destination and all scalar argument
sources before entering the mixed transaction. Scalar values are staged in at
most eight i64 cells. A late invalid scalar source cannot follow owner copying
or borrowed ticket publication.

Only after the existing mixed transaction succeeds does the adapter write scalar
formals and the child's return PC/destination. Array, record and borrowed formals
never receive scalar writes. No fallible operation follows mixed publication.
The VM then changes its frame and instruction pointer through bounded assignments.
Unrelated registers and return-table entries retain their previous bytes.

A returned error preserves scalar registers, return tables, participating owner
metadata, backing bytes, borrowed tickets and dynamic roots. Earlier guest effects
are not rolled back. This is a synchronous single-thread transaction; crash or
concurrent access recovery is outside its contract.

## Bounds and charging

The existing 32-frame, 128-register-per-frame and eight-argument limits remain.
The adapter stages 64 bytes of scalar values, not a 4096-register snapshot or
payload clone. The VM creates one bounded borrowed-root context per invocation;
it is not allocated once per CALL. Native peak stack and latency are unmeasured.

The complete existing price remains
`1 + arity + owned work + borrowed retention reserve`. The adapter performs no
additional Fuel debit. Scalar/array/record calls retain their existing exact
prices. A Fuel shortage precedes frame and backing admission. New control/span
and scalar-source checks complete before any mixed publication.

## Verification

Run the focused selections in both profiles:

```text
python -B tools/verify-m2-array-utf8-source.py --profile development --call-frame-vm
python -B tools/verify-m2-array-utf8-source.py --profile release --call-frame-vm
```

The [native tests](../../tests/m2/call_frame_vm.fy) exercise mixed scalar/owned/
borrowed publication, nested forwarding, unchanged non-scalar register cells,
late owned and stale-borrow failure, capacity/Fuel/frame limits, short register
and return spans, malformed scalar sources/destinations, and executable ordinary
calls with exact Fuel and frame reuse. Borrowed calls use the private adapter
directly and explicit cleanup; public VM rejection is asserted separately.

The selection also runs all 2,007 M1 CLI cases, 106 array-call-read cases,
102 record-call-read cases, 74 gated borrowed-source cases and eight sentinels.
Retained CLI hashes, input hashes and actual outcomes are recorded in the
[Windows receipt](../evidence/m2-array-call-frame-vm-windows-20261031.json).
Full native suites, other M2 matrices, M0, Linux, isolation, packaging and
performance are outside this focused selection.

Dynamic slice instruction wiring and automatic normal/error frame cleanup remain
the next integration work. The execution gate stays closed until those paths,
including question propagation and loop transfers, are verified together.

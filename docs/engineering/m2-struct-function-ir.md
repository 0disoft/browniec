# M2 Private Function-Owned Record IR

- Status: private IR/verifier foundation verified in development and release;
  its entry-only runtime checkpoint is historical.
- Scope: static record-site ownership and independent verification. Frame-local
  execution is supplied by the successor.
- Predecessor: [private struct IR](m2-struct-ir.md).
- Successor: [private frame-local record VM](m2-struct-function-vm.md).
- Evidence: [Windows receipt](../evidence/m2-struct-function-ir-windows-20261027.json).
- Implementation: [IR builder and metadata](../../src/ir.fy), [program verifier](../../src/verifier.fy),
  and [struct verifier](../../src/struct_verifier.fy).
- Tests: [native function-owned record IR cases](../../tests/m2/struct_function_ir.fy).
- Combined selection: `python -B tools/verify-m2-struct-values.py --function-ir`.

This slice was a verifier foundation rather than helper runtime or source support.
Private record sites carry a function owner, allowing the verifier to attribute
each opcode 41..49 operation to the function that contains it. The original
foundation left the VM entry-frame-only; the
[frame-local successor](m2-struct-function-vm.md) now executes it. Source
helper-local records, record parameters, record results, and borrows remain
unavailable.

## Static ownership

`ir::Program` adds a 16-byte `record_functions` array parallel to
`array_functions` and the sixteen static record sites. `record()` defaults its
site owner to `p.entry`. `record_in()` takes an explicit function
ID and records it before changing catalog bytes or site count.

Both builders reject function IDs outside the 16-function metadata array. When
`function_count` is already known, they also reject an ID outside the declared
function range. The existing sixteen-record-site quota remains shared by all
functions. Failed allocation leaves the record catalog and ownership metadata
unchanged.

## Verifier rules

Program verification requires every active record owner to name a declared
function and every unused `record_functions` byte to remain zero. The struct
verifier checks the site owner against the function currently being verified.

All record opcodes 41..49 require the referenced record site to belong to that
function. `SCOPY` (42), `SASSIGN` (46), and `SSUBASSIGN` (47) additionally require
their source site to belong to the same function. Physical layout equality and
global liveness do not bypass ownership.

Each function's dataflow starts with all record bindings dead. Existing cleanup,
joins, backedges, input-range checks, nominal identity, mutability, and combined
array/record live sets are unchanged. At this checkpoint, runtime struct
operations remained limited to the entry frame. The successor keeps the existing
ban on calls into an entry function with record bindings.

## Execution and source boundary

No opcode, encoding width, Fuel charge, VM dispatch, version capability, or source
form was added by this foundation. At that checkpoint, the VM was entry-frame-only:
a native fixture verified a valid helper-owned IR program, then confirmed that
execution failed with error kind 5 at the helper boundary.

That entry-only assertion is historical. The
[frame-local record VM](m2-struct-function-vm.md) now executes the same verified
helper IR. One current test group expects 42 instead of kind 5; the other five
groups are unchanged. This foundation still does not grant source helper records,
record parameters/results, or borrows.

The fixture also places `main` at function 1 with an entry-owned record, calls a
scalar helper, and verifies that the VM returns 42. Entry scalar calls retain their
existing behavior; this does not allow an entry record to cross into a helper.

Source lowering continues to reject helper-local record declarations, record
parameters, and record results. This verifier work does not make helper records
available in source programs.

## Verification

The complete `python -B tools/verify-m2-struct-values.py --function-ir` invocation
passed without reusing earlier results in development and release. Each profile
passed 31 native groups: six function-owned record IR, nine existing IR, six root
constructor source, six child replacement VM, and four atomic source groups.
The 2,383 CLI cases per profile comprise 103 child constructor, 97 root
constructor, 83 child-path, 131 subrecord-assignment, and 1,969 M1 scalar cases.

Native checks exercise all record opcodes in their declared functions, foreign
destination and source sites, out-of-range and dirty unused owner metadata,
cleanup failures, and entry reentry rejection. At the checkpoint, a helper-owned
IR fixture passed verification and failed VM execution with kind 5. The current
fixture expects 42 after frame-local execution; the successor's new groups cover
frame slots, shared quotas, recursion, and stale generations. Entry-owned records
still execute when `main` is function 1 and calls a scalar helper. Source helper
records and record signatures remain rejected.

The [receipt](../evidence/m2-struct-function-ir-windows-20261027.json) records
input hashes, compiler/SDK identities, exact commands, native/CLI outcomes, and
artifact hashes. All recorded inputs and compiler hashes, the release binary,
and equal native identities across profiles were rechecked before archival.
The SDK lock identity is unchanged; the compiler remains `4ce1264273be`.
Implementation commit: `3380b10`. The 31-group result remains recorded for its
original scope. Its test file changed one of six function-IR groups to expect
helper execution; the other five are unchanged. The [frame-local successor](m2-struct-function-vm.md) passed 46 native groups
and 2,383 CLI cases per development/release profile at `80ed712`.

Earlier receipts remain historical for changed IR, verifier, root-lock, test,
and harness inputs. At its checkpoint this foundation added no helper VM
execution or source form; the successor adds private helper execution while
source forms remain unavailable.
Full native suites, other struct/array CLI matrices, M0, Linux, packaging, DLL,
isolation, allocation instrumentation, and performance were not run.

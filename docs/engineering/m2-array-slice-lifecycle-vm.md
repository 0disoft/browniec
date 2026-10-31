# Shared VM slice dispatch and frame cleanup

Implemented at `eb8fcdd`. Development and release each passed five native
groups and 2,541 CLI invocations, with 372 matching input hashes and retained
CLI identities. The public [VM wrapper](../../src/vm.fy) still calls
execution verification before preparing backing or entering the shared
[execution core](../../src/vm_execution.fy). At the original checkpoint borrowed signatures remained rejected. The later
[public promotion](m2-array-slice-parameters-public.md) now admits them after the
same complete proof; the historical lifecycle receipt stays unchanged.

## Shared execution and normal return

The internal core requires an immutable independently inspected Program and
invocation-owned backing, owner/loan tables and root bindings. It does not repeat
verification: the public wrapper verifies once; native integration tests inspect
once. This is an internal Fairy C boundary, not an external bytecode loader or
published embedding interface.

Each active frame records its function index in a bounded 32-entry table. CALL
publishes the target function after mixed argument admission succeeds. Slice
opcodes 54..59 use the existing dynamic instruction adapter with that function,
PC, frame and root context. Owned sites retain their existing dispatch and price.

Scalar/tagged return, array return and record return all call
[`slice_lifecycle_vm::leave`](../../src/slice_lifecycle_vm.fy) before publishing a
parent result or transferring its owner. Borrowed frames use their prepaid
cleanup reserve to close remaining frame tickets and clear all eight root
bindings. Ordinary frames retain their existing source-lowered closes and prices.
Parent/caller tickets survive normal child cleanup. Reused frames cannot inherit
the preceding borrower's roots.

## Invocation success and failure

The root context now belongs to the invocation wrapper rather than the execution
loop, so it survives a returned execution error until cleanup completes.
`slice_vm::drain` shares the existing bounded, staged pool clear with the older
`slice_vm::finish` API. After successful pool cleanup it clears all 512 ticket
entries. The lifecycle wrapper then clears all 256 root-binding entries and
returns the exact original result or error, including its source offset.

If pool cleanup fails, its error is returned and ticket/root metadata is retained
for diagnosis. Root bindings are not cleared ahead of a failing pool operation.
The runtime performs no automatic repair or replay. Earlier guest effects are
not rolled back. Native tests explicitly repair corrupted test metadata before
making a separate cleanup call.

No new heap allocation path, opcode or Fuel price is introduced. The function table and
existing root context are invocation-local bounded metadata. Cleanup uses the
existing open/CALL reserves and does not require remaining guest Fuel. Native
peak memory, latency and throughput were not measured.

## Verification scope

```text
python -B tools/verify-m2-array-utf8-source.py --profile development --slice-lifecycle-vm
python -B tools/verify-m2-array-utf8-source.py --profile release --slice-lifecycle-vm
```

The [five native groups](../../tests/m2/slice_lifecycle_vm.fy) execute twelve
borrowed-source fixtures through the shared core after independent inspection.
They cover nested forwarding, derived UTF-8/length/index operations, owned local
slices, frame reuse, array/record returns, `?`, while/for break/continue, nested
division failure, overflow, bounds, Fuel exhaustion, and failed cleanup followed
by explicit test repair. Successful returns leave no live loan or root binding;
failed executions are drained while preserving the original error and offset.
The original tests asserted public rejection. Current tests also execute every
fixture through the public wrapper after the admission promotion.

Native fixtures provision backing separately and supply execution-only Fuel.
They do not demonstrate public borrowed-source admission or promote a new CLI
Fuel contract. The selection also runs the full 2,007-case M1 CLI matrix, five
related M2 matrices totaling 526 cases, and eight basic CLI sentinels.
The [Windows receipt](../evidence/m2-array-slice-lifecycle-vm-windows-20261101.json)
records actual outcomes, input and retained image hashes, commands and limits.

Full native suites, other M2 matrices, M0, Linux, isolation, packaging and timing
were not rerun. Public gate promotion, capability reporting and borrowed CLI
conformance are now covered by the [public successor](m2-array-slice-parameters-public.md).

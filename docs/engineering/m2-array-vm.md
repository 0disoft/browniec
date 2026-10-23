# M2 Entry-Array VM Execution

- Scope: real native execution of [private array IR](m2-array-ir.md); no array source syntax.
- Implementation: [`array_vm.fy`](../../src/array_vm.fy), [`vm.fy`](../../src/vm.fy).
- Harness: `tools/verify-m2-arrays.ps1 -Slice vm` and `tools/verify-m1.ps1`.
- Evidence: [Windows VM receipt](../evidence/m2-array-vm-windows-20261024.json).

The common VM now dispatches array initialization, copy, read, write and drop
through the existing generation-checked owner table. Verification runs before
preparation or execution. Arrays remain separate from scalar register values;
native tests build real Program values with the IR helpers, not a model runtime.
The CLI source parser and `brownie.m1-scalar/1` grammar are unchanged.

## Storage and lifetime

An array run owns one fixed-capacity Fairy Buffer, with a selected payload ceiling
0..65536 bytes. The internal `run_with_array_limit` entry allows a smaller ceiling;
ordinary `run` selects 65536 when an array catalog exists. Preparation checks the
ceiling and Fuel before allocation, checks the provider's actual logical capacity,
then initializes all backing bytes. Scalar-only programs allocate no array buffer
and pay no array preparation Fuel.

Each run has a fresh owner table and 16 private token bindings. Array dispatch is
restricted to frame zero, with the entry-recursion and non-entry access restrictions
independently enforced by the verifier. Scalar callees may execute while parent
arrays live; they cannot access those arrays. Array parameters/results and array
locals in other guest frames are not implemented.

AINIT/ACOPY publish fresh ownership only after preflight and complete initialization.
Copying preserves the source and uses independent bytes. AREAD/AWRITE decode the
usize index from its full register-cell representation; an upper-half value is a
large unsigned index and fails bounds checking. Owner helpers retain full scalar
codec, bool-canonicality, generation and quota checks.

ADROP invalidates the token and performs bounded suffix reclamation. Normal RETURN
requires all arrays already dropped. On any runtime error the one-shot run ends
and Fairy resource cleanup frees the backing Buffer; Program stays reusable for a
fresh run. There is no automatic retry, guest GC, external effect, or partial
result publication. Cancellation and host suspension are outside this slice.

The ceiling accounts for retained payload bytes and padding, including old plus
new copy peaks. It is not a complete Instance/Engine ledger or process-memory cap.
Owner metadata, existing scalar frame storage and allocator overhead are separate.
The fixed-capacity prototype is not a memory or startup performance result.

## Fuel

Let B be the selected arena ceiling, w the element width, n its payload bytes,
and L its literal length. Fuel is preflighted and deducted before any corresponding
allocation or array operation, including operations that subsequently report quota
or bounds failure.

| Work | Fuel |
| --- | --- |
| Prepare/initialize arena | `1 + B` |
| AINIT | `49 + 2*w + n + 7` |
| ACOPY | `49 + n + 7 + (bool ? L : 0)` |
| AREAD | `33 + w` |
| AWRITE | `33 + 2*w` |
| ADROP | `49` |

The fixed terms cover one instruction plus two or three 16-record metadata passes;
payload work charges bytes, worst-case padding, codec scratch and bool validation.
These are conservative logical work units, not CPU instruction or latency counts.
Scalar instructions and calls retain their prior schedule. A two-element i32
initialize/read/drop program with two scalar constants and an 8-byte arena costs
170 total Fuel including preparation; 169 fails. A balanced create/drop loop can
reuse slots and bytes indefinitely only while Fuel remains.

## Outcomes and evidence

Three runtime diagnostic kinds are added: 13 `array_limit`, 14 `bounds`, and 15
`allocation`, all process exit 5. Invalid verified-runtime metadata or ownership
maps to the existing internal `verification` outcome. The result schema and scalar
CLI profile stay unchanged.

The VM harness passed five IR-verifier groups, six VM groups and one allocation
group in each development/release profile. VM coverage includes all six scalar
types, writes and independent copies, exact Fuel and first-error boundaries,
fresh reuse, frame-limit failure with a live parent array, balanced loop recycling,
and 4096-element usize copies at the exact 65536-byte peak.

It also runs four instrumented native allocation executions: normal and forced-NULL
in each profile, using the unchanged M0 allocator header. Preflight rejection must
leave the injected failure pending; the actual arena allocation reports a guest
allocation error, and its forced request is exactly 320 bytes. An explicit new run
then succeeds, and the allocator's exit hook checks for leaked target allocations.
These are real target allocator executions, not a simulated VM error branch. The
fresh scalar regression passed all 81 native groups and 1,969 CLI cases in
each profile because IR/verifier/VM code changed.

The earlier IR receipt's unavailable-dispatch check is historical. Its current
fixture now expects native execution to return 42 and is rerun by the VM harness.
All recorded M0 inputs and the retained compiler are unchanged, so the full M0
harness is not repeated. No new CI job, release or performance measurement is added.

Next: lower source-array declarations, construction, indexed reads/writes and
lexical cleanup to this IR. Full-profile borrows, aggregate calls, structs, Buffer
APIs, host suspension, Windows isolation, DLL and clean-machine gates remain open.

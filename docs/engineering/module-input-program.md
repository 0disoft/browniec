# Retained input-entry compilation and independent IR admission

`module_input_program::compile` now consumes the owning
[InputEntry](module-input-entry.md), reconstructs its original source context,
compiles every body and retains the complete admitted IR/image/source snapshot.
This advances I01 from signature metadata to a compiled owning Program. Its
[execution successor](module-input-execution.md) now adds a separate `run` API
for the exact immutable input Snapshot up to 1MiB. It cannot be passed to the
existing zero-argument module Program API.

## Exact source and body lowering

`functions::scan_input_scoped` shares the ordinary scoped scanner's implementation
over the exact owning Index and selected symbol. It preserves the original
visibility, module/type identities and file fences. `compiler::lower_input_modules`
uses the same complete body compiler, reference lowering, literal collector and
source-origin inference; it forces the reference-aware path for the shared-byte
formal. All bodies, including unused helpers, must type-check. Candidate lowering
cannot publish a Program or confer execution authority.

The selected entry must be public i32 with exactly one named shared `ref u8[]`
parameter. The source selector proves that grammar; independent IR admission
rechecks one entry argument, scalar i32 result and reference parameter kind3.
The generic formal has no scalar/array/record/ordinary-loan storage, and cannot
be reinterpreted as text or mutable data. Helper signatures keep existing rules.

### Timed input body lowering

Timed input-only compilation drains the same body cursor as the private
ordinary Engine compile job. It checks expiry before every advance and
maps failures through the selected input Index. Completion closes the cursor
so a repeated advance cannot run finalization twice. Input-only compile still
drains the cursor within one call. The [Engine-owned input source cursor](runtime-engine-compile-memory.md#engine-owned-input-source-preparation)
now hands prepared source to the [resumable lowering stages](runtime-engine-compile-memory.md#resumable-input-only-lowering).
Input proof and publication still drain within a single Engine step.

The Windows Engine harness exercised the exact deadline between a control
advance and its pending semantic child in development and /O2. Both ended
with zero live SDK allocations. Local receipt:
`build/runtime-engine/20261121T060749184748Z/receipt.json`.

## Independent proof and owning retention

`static_call_ir::inspect_input_returns` reconstructs all definitions, signatures,
CALL/return recipes, source origins and control-flow liveness against the exact
immutable image. `verifier::inspect_input_returns` adds the complete existing
scalar, aggregate, loan, selected-place, executable CALL and returned-reference
owner/lifetime proof. Its private entry-mode switch is reached only by this
separate admission function. The ordinary and reference-return entry points
retain their zero-argument entry rule.

The ordinary slice metadata pass also has a separate input variant. It preserves
all ordinary loan/catalog checks, allows exactly one generic entry argument and
forbids ordinary slice storage for that position. The enclosing complete proof
must establish its generic kind3 signature. Calling this metadata helper alone
does not grant executable or resource authority.

Only after lowering and proof have returned does retention allocate an owning
`Vec<Stored>` with one record: the original source/name Snapshot, admitted
candidate and actual native literal Image. Source, proof and owning-return stack
frames remain separate. Read-only accessors cannot alter the resource. Source
errors identify original files/offsets; verifier instruction indices map through
the retained source offsets. Image and native allocation errors retain existing
diagnostic classes. Image quota covers its logical metadata/payload, not total
Program or Engine RAM. Failed construction publishes no Program and performs no
fallback or retry.

## Focused native evidence

Run `python tools/verify-module-input-program.py`; `--profile development` or
`--profile release` selects one profile. It reuses the existing native verifier
runner, leaves the original combined depth fixture intact and writes ignored
mirrors, commands, reports and receipts under `build/module-input-program`.
Both profiles passed five native groups:

- Selected nonfirst input entry and complete body/independent proof; altered
  parameter kind, entry arity and result type reject. Ordinary reference-return
  admission rejects the input candidate.
- Actual multi-module reference CALL/return, returned input ranges, mixed literal
  origins and retention of both original source identities.
- Unused/selected body errors and insufficient image quota reject publication.
- Unchanged named zero-argument module execution returns 42 with exact Fuel.
- The original retained captured-call fixture compiles/runs at depth 32 and
  rejects 33 without rewriting or weakening its source cases.

The refreshed [Engine transport](runtime-engine.md) was reviewed against its new
184-module closure: the Engine resource remains `fy_resource_14`, Entry-vector
projection is derived from the actual compile helper, and all eight typed helper
signatures match their callers. Its full emitted C hash is frozen. Both native
Engine profiles still pass actual source execution, OS guard contention,
nonwrapping lifecycle/cleanup and zero live SystemHeap allocations. No stack or
compiler environment override is used.

## Execution successor and remaining integration

[Actual immutable input execution](module-input-execution.md) now supplies an
invocation-private window domain through PARAM, aliases/ranges, CALL/return and
READ/LEN. It retains the exact Snapshot borrow and full 1MiB limit, preserving
input/image/loan provenance without the old 4096-byte descriptor limitation.
Independent selected-origin proof and actual formal-grant containment both apply.

Engine/Instance association, OS-reader adoption, guest output success disposal,
public CLI/ABI and full R02/R03 accounting/deadlines remain open. Existing public
availability, capacities and prior Fuel prices/defaults/caps are unchanged; new
input metadata work has explicit additive prices in the execution successor.

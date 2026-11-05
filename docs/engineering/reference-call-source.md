# Shared byte CALL source lowering

Date: 2026-11-05. This B04/B05 increment connects source formals and actuals to
the existing [mixed-backing native CALL path](reference-vm.md). Returned-reference
source lowering and ordinary public admission remain the following steps.

## Source and retained authority

`compiler::compile_references(source, image_limit)` returns a private retained
`ReferenceProgram`. It collects the immutable literal image, lowers source,
reconstructs logical formal metadata and applies complete reference-aware
canonical proof before retaining the exact code/image. Source scratch and failed
candidates do not escape. The image quota covers metadata plus payload, not
complete compiler/Program/Engine RAM. Existing source and IR capacities remain.

```brownie
module main;
fn i32 first(ref u8[] bytes) { return bytes[0] as i32; }
fn i32 main() {
    let u8[1] data = [24; 1];
    return first(ref b"*") + first(ref data);
}
```

The same shared byte formal accepts image literals, named image views, explicit
`text::bytes`, existing array loans and owned array captures. Explicit `ref` is
required at each CALL. Direct text, exclusive access and non-byte coercions do
not satisfy the shared-byte signature. Scalar prefixes and all eight logical
actual positions retain their indices. Non-byte/exclusive loans, owned array
values and records keep their existing signature-selected capture paths.

Inside a callee, a shared byte formal supports READ/LEN, local aliases, narrowed
ranges and forwarding through another CALL. Literal and runtime backing use the
same source type while the proved IR and native receipts retain actual storage
and window authority. Immutable image aliases do not allocate guest array bytes.

## Evaluation, cleanup and prices

Only exact shared-byte formals become PARAM 77 placeholders and CALL 78 targets.
Existing checked CALL builders still create scalar/owned destinations, arity and
maps. Static site allocation now counts formal definitions in the same sixteen
global sites, including closed sites. Scalar formal positions never become view
sites; view positions never become scalar cells.

Image/universal actual expressions join the existing hidden lexical capture
suffix before later arguments execute. Range endpoints evaluate left to right;
owned parents remain in cleanup while endpoints execute. Early return,
propagation, break and continue therefore finalize only their exiting suffix.
After CALL, captures close in reverse order. Named views remain live for their
ordinary lexical scope. Independent admission checks the resulting liveness,
owner exclusion, types, exact windows and destinations.

No runtime price, frame capacity, pool capacity, native receipt format or public
flag changes. The existing private CALL/PARAM/access schedule and prepaid native
cleanup remain additive to dispatch. Public Fuel remains default 256 and an
explicit CLI ceiling of 16000000. Ordinary `compile`/`compile_image` and CLI
admission keep their existing gates for mixed-backing source CALLs.

## Verification and remaining work

Run `python -B tools/verify-static-execution.py --profile development --selection
reference-source` and repeat for release. Eight new source groups execute the
retained native program, including distinct image/runtime bytes, ranges,
forwarding, empty values, explicit text conversion, scalar prefixes, eight
actuals, mixed loan/owned/record arguments, evaluation effects and early exits.
They also check retained source immutability, image quota boundaries, Fuel/bounds
cleanup and unchanged legacy admission. Successful examples measure a wide run,
then check one-short/exact/one-more budgets; these are measured boundaries, not
an independent numeric price oracle. Seven existing Static binding groups and
three mixed reference VM groups cover affected regressions.

Windows development and release each passed all 18 selected native groups and
33 standalone public Fuel CLI cases. Builds were serialized and the CLIs ran
with a tool-free PATH. Native inputs match across 143 paths, CLI inputs across
148 paths: 152 distinct committed inputs, 136 LF production modules and 241-file
discovery. Both locked LF mirrors pass. No compiler/stack overrides or historical
reuse; the two preliminary probes and corrected unsupported element-list array
fixtures are excluded from final counts. Final commands, identities, results and
limitations are recorded in
[focused evidence](../evidence/reference-call-source-windows-20261105.json).
The original public Fuel native selection was not rerun by this successor.

Next lower source return expressions, result bindings and selected lifetimes
through the [existing canonical result VM](reference-return-vm.md), then connect
ordinary public admission and CLI execution. Kind-3 equality, mixed-backing text/non-byte
references, Buffer/input backing and host-visible reference lifetime APIs
remain open. Full profiles, Linux, general RAM/stack, allocator/OOM/timing,
restricted delivery and ABI/package checks are outside this increment. The
[complete inventory](../product/04-remaining-work.md) and
[implementation plan](completion-plan.md) remain active.

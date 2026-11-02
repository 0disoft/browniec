# Public reborrow IR admission and execution

Status: implemented at `409d77c`; Windows verification passed. Public IR opcodes 61 and 62
are admitted and executed through the verifier and VM. Source grammar, parser,
compiler and CLI capabilities remain gated.

Preparation commit `42a66e9` shares the immutable derived-CALL classifier and shape
guard between the native adapter and verifier. `409d77c` adds public proof and VM
routing. Together, these commits form the five-path production delta described below.

## Public proof and admission

The bounded whole-program proof returns the exact immutable `Sites` forest instead
of only an instruction count. `inspect` and `inspect_reborrow_calls` retain their
count-returning APIs. Strict `inspect` keeps `allow_reborrow_calls = false`;
`inspect_reborrow_calls` remains analysis-only without executable-shape admission.

`verify_sites` validates the complete Program, enables suspended CALL proof only
when `reborrows::present(p)` finds opcode 61 or 62, and returns that forest. A
nonempty forest causes a scan of every CALL in every function with the shared
executable check, including unreachable functions. No second proof or runtime
forest reconstruction occurs.

`verify` delegates to `verify_sites` and returns the instruction count. Unsupported
derived CALL shapes fail before VM quota checks, preparation Fuel, payload backing,
local authority publication or guest execution.

## Shared executable CALL subset

[`slice_reborrow_admission_ir::call`](../../src/slice_reborrow_admission_ir.fy)
uses immutable Program metadata and `Sites` parents to classify derived CALLs.
They accept borrowed/scalar arguments and a scalar result. Owned array/record
arguments and array/record results reject before effects, including in unreachable
functions. Ordinary CALLs retain owned arguments and aggregate results. The module
has no runtime, authority, pool or map dependency; native cost-before-guard order
is unchanged.

## Public VM routing and lifecycle

[`vm.fy`](../../src/vm.fy) calls `verify_sites` before quota checks, preparation Fuel,
backing and loan/frame construction. Nonempty sites route directly to the canonical
core with that forest. With no sites, an exclusive formal still selects canonical
mode; owned-only opcode 61/62 programs now route without a formal. The old empty-
Sites assumption is removed.

Canonical execution receives fresh local receipt and CALL/child bindings. Normal
return restores the caller view. Abort drains the authenticated pool before local
maps clear and does not replay reverse CALL restoration. Successful cleanup returns
the original result; failed cleanup retains metadata for retry. Public backing
disposal remains local. Prices, bounds, frame/depth limits, layouts, pool formats
and profiles are unchanged.

## Remaining boundaries

Source grammar/parser/compiler and CLI capability flags remain gated; external
bytecode prohibition is unchanged. Public support applies to constructed IR through
verifier/VM APIs. Derived owned arguments and aggregate results remain separate.

## Verification status

Windows passed: development 8 core groups; release 19 groups (8 core, 6 boundary,
5 proof); 74 mutable-parameter CLI cases in each profile. All 404 current inputs
match, with 94 of 99 production sources unchanged against `e952162`. The five
production paths are `slice_reborrow_admission_ir.fy`, `slice_reborrow_call_vm.fy`,
`verifier.fy`, `vm.fy` and `vm_reborrow_execution.fy`.

The differential core compares public and native results, error kind and offset.
The public helper adds 257 preparation Fuel for 256-byte backing. Legacy raw
`execution::execute` remains gated. Updated fixtures verify public admission with
Fuel, quota and frame outcomes.

An initial development differential core run exceeded the native Windows stack
while retaining both execution contexts. Splitting native and public helper context
lifetimes fixed the overlap; all final core reruns passed. No stack-size measurement
was made.

The development core input differs only in the unselected
`slice_formal_reborrow_vm` fixture: recursion Fuel increased from 1M to 16M to reach
the frame limit. Release boundary tests executed it. Core tests and production did
not differ.

Full native, other M2, full M1, Linux, isolation, packaging, allocator, native
size/stack and timing were not rerun. No new user-facing flag is added. Local only;
no push.

See the [verified Windows evidence](../evidence/m2-slice-public-reborrow-windows-20261103.json).

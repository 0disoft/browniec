- Latest parallel-integration checkpoint (2026-11-07): [Composed native verification](../engineering/parallel-integration.md)
  records public IR inspection `2b44bf9` (19 CLI cases plus version/help in each
  profile), strict catalog/SHA-256 `41144d7` (12 native groups/profile), fresh
  singleton loop owners `cbdfdbe` (11 groups/profile), and real internal lazy
  registry `8a4dae9` (four C-host scenarios in each development/optimized profile).
  The final root release passed four native groups and three public CLI cases;
  all 233 inputs match checkout/Git raw bytes and all 223 production modules are
  LF. The root check passed 231 sources/2560 MIR functions; default stacks remain.
  Full Engine/Program/Instance lifecycle, accepted registry scale, host exchange,
  conditional fresh-root unions and the remaining inventory are open. Public
  Buffer/host/restricted/embed gates and existing Fuel limits/prices are unchanged.
  All parallel workers are closed. Local commits only; no push/release/deployment.

# Roadmap

- Native value bytes, 2026-11-07: [retained canonical layouts and byte operations](../engineering/value-codec.md) now validate exact scalar/array/plain-record/wrapper representation, tags, bool, padding/inactive bytes and the one active opaque Buffer word. Direction-aware copies and disjoint wrapper construction validate before mutation. Development/release each passed six native groups on f5d3d1a, with 188 checkout/Git-raw-matching inputs and 183 LF production modules. This is a byte-storage prerequisite: native root authentication, owning value/frame storage, metering, cleanup, VM execution and source bindings remain next. Public behavior/prices/limits remain. See [Windows evidence](../evidence/value-codec-windows-20261107.json). Full language/native Fuel/CLI, LF mirrors, Linux, OOM/general stack/performance and clean-machine delivery were not rerun. Earlier checkpoints retain their scopes.

- Typed value IR prerequisite, 2026-11-07: [complete independent ownership analysis](../engineering/value-ir.md) now connects MOVE/COPY/DROP, tag build/case, scalar value conversion and value CALL/RETURN to whole-type properties, exact initialized/Dead CFG state and canonical scalar/aggregate/loan/selected-place proof. Inactive/scalar Buffer alternatives still consume their complete wrapper. This is analysis only; all existing executable routes retain their gates. Metered native value storage/execution, cleanup and compiler source integration remain next. Full L04/L05/D01-D04/Engine/Instance/host/delivery remain open. See the [focused Windows evidence](../evidence/value-ir-windows-20261107.json); earlier checkpoints retain their scopes.

- Resource/tag ownership prerequisite, 2026-11-07: [whole-type properties and native Buffer handoff](../engineering/value-ownership.md) independently derive scalar/array/plain-record/Buffer/Option/Result layout, depth and copyability, including inactive Buffer alternatives. The native handoff consumes a real allocation, preserves its owner token and charge, prepays Fuel and returns the original root on rejection. Guest source-binding/Dead CFG proof, resource TAG_BUILD/TAG_UNPACK, wrapper source/VM integration and full L04/L05/D01-D04 remain open; no public capability or existing price/limit changes. See the [focused Windows evidence](../evidence/value-ownership-windows-20261107.json). Earlier checkpoints retain their scopes.

- Reconciled: 2026-11-03; private owned-array/CALL integration at `5cccbd3`; record integration at `e01a9b1` is described in [the successor contract](../engineering/m2-slice-result-record-vm.md), explicit native owned entry at `8bf37de`, updated 2026-11-04.
- This is the current delivery plan. The old increment log is preserved in
  [history](history/roadmap-20261103.md); its dated gates are not current TODOs.
- Language progress, 2026-11-06: scalar/tagged and fixed-array/plain-record
  [if values](../engineering/aggregate-if-expressions.md),
  [switch values](../engineering/aggregate-switch-expressions.md) and
  [void functions/statements](../engineering/void-source.md) are connected.
  [Constructor arm constraints](../engineering/constructor-join-inference.md) now
  resolve the existing Option/Result domains in either branch order.
  General reference/Buffer joins, grouped borrows and
  broader constructor context remain language work alongside the units below.
- The complete requirement crosswalk and actionable gaps are in
  [remaining work](04-remaining-work.md). The [specification](02-spec.md) owns
  semantics, and [Validation](../../VALIDATION.md) owns recorded execution claims.
- L04 copy proof now [derives strategies from IR](../engineering/aggregate-copy-ir.md)
  for fixed arrays, plain records/subrecords and by-value CALL arguments, composing
  with canonical owner/loan CFG and every current executable admission route.
  [Native aggregate destination snapshots](../engineering/aggregate-selected-place.md)
  now capture whole arrays/nominal subtrees through existing atomic stores.
  [Independent aggregate-place IR/lifetimes](../engineering/aggregate-place-ir.md)
  now cover all five copy/value-store forms through shared phase/owner proof.
  [Metered native aggregate storage](../engineering/aggregate-place-vm.md) now
  supplies invocation-local tickets, prepaid snapshots and all five final stores.
  [Shared native place dispatch](../engineering/place-dispatch.md) now supplies
  one vector/ID space for all five kinds, preserving legacy-only formats/prices.
  [Aggregate-place execution](../engineering/aggregate-place-execution.md) now
  connects both drivers, complete admission and retained guards with exact Fuel
  preflight and prepaid cleanup. [Ordered aggregate source assignment](../engineering/aggregate-place-assignment.md)
  now connects early selection, shared exit bookkeeping and all five final stores.
  Next: resource/tag copy/move semantics and remaining complete L04 obligations.
- L04 starts with [native owned-array selected locations](../engineering/array-selected-place.md).
  [Independent place IR analysis](../engineering/array-place-ir.md) now checks
  identity and lifetimes. [Native metered storage](../engineering/array-place-storage.md)
  supplies snapshots/dispatch. [Both VM drivers and retained guards](../engineering/array-place-execution.md)
  are connected. [Compiler exit bookkeeping](../engineering/array-place-cleanup.md)
  now prepares return/propagation/loop cleanup without consuming guest locals;
  [owned-array source assignment](../engineering/array-place-assignment.md) now
  connects early bounds, old-scalar capture and ten integer compounds. Other
  place kinds, grouped lvalues and complete L04 remain open.
  The [native exclusive-slice prerequisite](../engineering/slice-selected-place.md)
  now captures the original view/session and revalidates current restored tickets.
  Its [independent ordinary-IR analysis](../engineering/slice-place-ir.md) now
  proves kind/site identity, phases, lifetime and available authority. Its
  [metered private storage adapter](../engineering/slice-place-vm.md) now retains
  original snapshots in explicitly tagged bounded invocation vectors, with
  separate slice/mixed preparation and preflight costs. The
  [execution successor](../engineering/slice-place-execution.md) now connects
  both VM drivers to canonical current-binding maps with complete admission,
  frame/CALL cleanup and retained/image/recipe guards. The
  [source successor](../engineering/slice-place-assignment.md) now connects
  bounds-before-RHS selection, old-scalar capture and ten checked integer
  compounds, with shared nested place IDs and nonlocal cleanup. Source IR/Fuel
  changes deliberately; version metadata adds two narrow slice-assignment flags.
  Record/scalar-local places, grouped lvalues and aggregate overlap remain next.
  The [native record-location prerequisite](../engineering/record-selected-place.md)
  now captures nominal owner/reservation and nested scalar ordinal, with
  metadata-only selection and revalidated atomic read/store. Its
  [independent IR successor](../engineering/record-place-ir.md) now checks exact
  kind/site/field identity, prepared scalar types, phases and root/CFG lifetimes
  in a separate analysis entry. Metered VM integration and source lowering remain next.

## Milestone status

| Milestone | Current state | Exit still required |
| --- | --- | --- |
| M0: native feasibility | Scoped native primitive evidence recorded | Revisit only for a new platform/shim/toolchain requirement; not a full product gate |
| M1: scalar source to native VM | Bounded scalar checkpoint met | Keep regressions on semantic changes; full safe/0.3 is not M1 completion |
| M2: aggregates, borrows and bytes | Public arrays/records/scalar slices plus retained literal/shared-byte results; private Buffer foundations | General returned references, general reference/type gaps, guest Buffer/text, input/output and full accounting/runtime integration |
| M3: typed host suspension | Not implemented | Engine/Instance stepping, authority chain, fake typed host request/reply, failure/cancel/poison and reply adoption |
| M4: restricted Windows worker | Not implemented | Real AppContainer/Job/private IPC, broker publication/cancel races and I/O lease/budget evidence |
| M5: embed and clean-machine delivery | Not implemented | Real DLL/C ABI/handle lifecycle, clean-machine packaging and measured workload/build footprint |

Current `core: true` advertises the experimental native CLI only. It does not
certify full-profile completion. Restricted and embed availability remain false.
Windows is the verified narrow-development target; Linux native Brownie execution
has not been verified by the toolchain's Linux cross-build alone.

## Already available

- Six scalar types, checked arithmetic/bitwise/shifts, explicit widening, direct
  calls and bounded VM recursion, lexical control flow and shallow i32/bool tags.
- Function-owned fixed scalar arrays and nominal scalar/nested records, complete
  admitted constructors, by-value arguments/results, copy/replacement/assignment,
  scalar/aggregate result expressions and paths.
- Shared/exclusive scalar slices, lexical aliases and mutable children, relative/
  open/empty ranges, inline whole/ranged named-array/slice and temporary CALL roots.
- Fixed-array/view UTF-8 checks; private Buffer storage/accounting/lease/scanner/
  cleanup components with scoped native evidence, not guest integration.
- Private result-signature and body-origin analysis through named/subview returns,
  branches, forwarding and grounded recursion, plus explicit
  [returned-view preparation IR/independent proof](../engineering/m2-slice-result-ir.md).
  [Native handoff/capture transactions](../engineering/m2-slice-result-runtime.md)
  retain selected owners and suspended parents; private VM dispatch now connects
  owned array/record locals and ordinary CALLs. Public result execution stays gated.

The original audit's [focused Windows receipt](../evidence/m2-slice-result-origins-windows-20261103.json)
records 12 native groups and 990 CLI cases per profile on 462 matching inputs.
Development reuse is documented; release reruns the selected scope. This audit
rechecked identities, not native tests, and does not claim full M1/M2 conformance.

The 2026-11-04 [preparation-IR evidence](../evidence/m2-slice-result-ir-windows-20261104.json)
records 10 native groups and 208 CLI cases per profile on 476 matching inputs,
without final result reuse. This focused increment does not replace the earlier
broader receipts or establish runtime returned-reference/lifetime support.

The final 2026-11-04 [native handoff/lifetime evidence](../evidence/m2-slice-result-runtime-windows-20261104.json)
records 12 native groups and 208 CLI cases per profile on 479 matching inputs,
with no final result reuse. Source result/dispatch/cleanup integration is still
required; this native transaction does not promote public execution.

## Next implementation units

The internal registry/catalog/wire prerequisites and private singleton fresh-loop
owners now have scoped native evidence. They do not close their wider inventory
groups. Public IR inspection is available through the existing source gates.

1. R01/E03: connect the real owner-thread Engine, immutable reusable Program and
   one-shot Instance to typed handles, native object ownership, Program pins and
   release/destroy. Keep public ABI availability separate from internal metadata.
2. R02-R05: complete accounting/preallocation, bounded resumable work, monotonic
   deadlines/cancellation, first-cause poison and zero-Fuel budgeted cleanup.
3. H01-H04: bind retained Program imports/catalog digests to policy/declarations/
   grants and real HOST_REQUEST/WAITING_HOST/reply adoption. Codecs alone do not
   authorize or dispatch effects; start with the in-memory adapter.
4. L01-L07/B04-B05/D01-D04: complete aggregate/reference/module composition,
   conditional fresh-root unions, methods/AllocError and deliberate public
   graduation. Preserve the existing return-origin, owner and Fuel proofs.
5. D05/I01-I02: connect actual guest input, Buffer/text validation and staged
   grant-controlled output in one usable workload.
6. C01-C05: anchored source collection, public project/policy/catalog/run loaders,
   multi-source diagnostics and deliberate full-profile limit reconciliation.
7. W01-W06: actual restricted Windows process/broker/IPC, cancellation races,
   publication and I/O-lease/reaping bounds.
8. E01-E04/V01-V05: actual complete VM DLL ABI, accepted-scale registry/pins,
   supported-platform/clean-machine packages, conformance/failure coverage and
   measured build/runtime/release evidence.

Use the [complete inventory](04-remaining-work.md) as the requirement crosswalk.
Do not increase VM capacities or add excluded language features as incidental
fixes. Small verified local commits remain separate from remote delivery.

## Evidence and release rules

Keep design, private native implementation, public guest execution, OS integration
and packaging/performance evidence distinct. Full-profile tests must cover actual
source/entry/policy/input/output contracts; historical case totals are not a full
conformance claim. The reference package's 32 cases are not silently marked run.

Use focused checks for each change; documentation reconciliation needs link and
consistency checks, not a repeated native/benchmark matrix. Long fuzzing and precise
benchmarks remain manual and risk-based. Make verified local commits, group only
authorized pushes, and keep publish/deploy/release approval boundaries intact.

Stop or revise the affected delivery if guest code can terminate the native host,
stale identity can access a new object, reservations happen after allocation,
cancellation can publish output or isolation cannot be established on the real OS.
Performance targets may be revised from measurements; these failure boundaries
cannot be removed merely to meet a target.

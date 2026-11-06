# Roadmap

- Reconciled: 2026-11-03; private owned-array/CALL integration at `5cccbd3`; record integration at `e01a9b1` is described in [the successor contract](../engineering/m2-slice-result-record-vm.md), explicit native owned entry at `8bf37de`, updated 2026-11-04.
- This is the current delivery plan. The old increment log is preserved in
  [history](history/roadmap-20261103.md); its dated gates are not current TODOs.
- Language progress, 2026-11-06: scalar/tagged and fixed-array/plain-record
  [if values](../engineering/aggregate-if-expressions.md),
  [switch values](../engineering/aggregate-switch-expressions.md) and
  [void functions/statements](../engineering/void-source.md) are connected.
  [Constructor arm constraints](../engineering/constructor-join-inference.md) now
  resolve the existing Option/Result domains in either branch order.
  General reference/Buffer joins, grouped lvalues/borrows and
  broader constructor context remain language work alongside the units below.
- The complete requirement crosswalk and actionable gaps are in
  [remaining work](04-remaining-work.md). The [specification](02-spec.md) owns
  semantics, and [Validation](../../VALIDATION.md) owns recorded execution claims.
- L04 starts with [native owned-array selected locations](../engineering/array-selected-place.md).
  [Independent place IR analysis](../engineering/array-place-ir.md) now checks
  identity and lifetimes; VM/Fuel and source compound assignment remain open.

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

1. B01 preparation recipes and independent proof are implemented. The private VM
   adapter separately admits a rootless borrowed-input dialect; proof alone never
   authorizes ordinary Program execution.
2. B02 native handoff/abort, caller result/frame/site bindings and private op63/64/65
   dispatch are connected. Owned array/record locals and scalar/array/record CALLs
   are integrated; [bounded Fuel accounting](../engineering/m2-slice-result-fuel.md)
   now replaces the private reserve and prepays terminal cleanup.
3. B03 native capture/root lifetime and descendant suspension are implemented.
   Guest-created array temporaries, record locals and mixed CALL captures now use
   the same owner table and terminal cleanup. [Explicit native owned entry](../engineering/m2-slice-result-entry.md)
   now copies array/record inputs through the initial transaction.
4. B04 shared-byte results now have [public retained execution](../engineering/public-program.md).
   General mutable/non-byte/Buffer/input results and host-visible lifetimes remain.
   L01 now has [native source snapshots](../engineering/module-sources.md); bind
   module/import/visibility tables before connecting multi-module compilation.
5. D01-D04 and L05-L06: connect guest Buffer, resource-bearing wrappers and
   ownership-aware builtins to the VM/Instance, using existing native components.
6. D05 and I01-I02: deliver a real input -> Buffer/text -> staged-output workload.
7. R01-R05: complete the Engine/Instance, quotas, bounded stepping, deadlines,
   cancellation, poison and terminal contracts needed for M3 and later surfaces.
8. H01-H04/C01-C04: finish explicit source/configuration/authority and typed host
   integration, initially using an in-memory fake adapter.
9. W01-W06: implement and verify actual Windows restricted delivery.
10. E01-E04/V01-V05: close embed, clean-machine, full-profile and measured release
    gates. Measure relevant workloads earlier when they can guide a real decision.

L01-L07/B05/C05 are full-profile language/reference/limit gaps, not completed by
finishing only the returned-slice path. Schedule them as bounded vertical units
alongside M2/M3, and track every item in the [complete inventory](04-remaining-work.md).
Do not increase caps or add an excluded language feature as an incidental fix.

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

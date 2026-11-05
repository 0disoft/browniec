# Completing the accepted implementation

Objective: implement the accepted remaining Brownie C design, not merely the
current experimental subset. The requirement-by-requirement inventory remains
[04-remaining-work.md](../product/04-remaining-work.md); this file gives execution
order. A green increment does not establish full-profile completion. Features
explicitly excluded from the first profile remain excluded.

Work on main in small local commits. Verify changed behavior and its affected
regressions, then commit; record broader checks only when actually run. Do not
enable public syntax, delivery flags or ABI availability ahead of implemented
admission, execution and cleanup. Push/release/deployment are separate actions.

## Implementation sequence

1. **Returned references: B04/B05.** Preserve the existing origin, independent
   proof, canonical authority and Fuel work. Direct return ranges now reuse those
   recipes, and typed lexical CALL bindings now lower to independently proved IR.
   Native lexical CALL destinations, parent restoration and prepaid close are now
   connected. [Immediate scalar projections](m2-slice-result-projections.md) now
   reuse that path. [Direct returned CALL arguments](m2-slice-result-arguments.md)
   now retain transitive selected ancestry and close unselected captures.
   [Declaration/return range projections](m2-slice-result-range-projections.md)
   reuse the same retained results and terminal handoff. The
   [native literal-image prerequisite](static-literal-image.md) now owns immutable
   deduplicated bytes. A [retained native Program](retained-program-image.md) now
   owns that image beside independently verified copyable IR and borrows both for
   existing scalar execution. The [native return-stack fix](native-return-stack.md)
   removes reproduced return-transaction stack amplification without changing
   ownership APIs, VM capacities or prices. The [private Static IR proof](static-ir.md)
   now reconstructs real image definitions, scalar types and independent CFG
   lifetimes. The [native Static successor](static-execution.md) now connects
   retained Program admission, canonical dispatch, frame-local aliases and exact
   prices. The [literal decoder](literal-source.md) now recognizes exact byte/text
   tokens and stages checked UTF-8/escape data before kind-specific image interning.
   The [native source compiler](literal-compiler.md) now owns atomic literal
   collection and lowers immediate byte/text projections through the retained
   image. The [alias IR successor](static-alias.md) now preserves same-kind views
   and source liveness without copying payload. The [typed binding successor](static-bindings.md)
   now lowers native Static byte/text locals, aliases and explicit text::bytes
   projections with lexical/nonlocal-exit cleanup. Next connect general runtime
   view expressions and image-backed CALL/return origins. Keep source scratch separate from retained authority. The [byte-view equality successor](static-byte-equality.md) now extends private
   EQUAL proof/execution to immutable bytes without changing its price. The
   [source equality successor](static-equality-source.md) now lowers the byte-view
   signature for immutable image views with explicit text::bytes conversion.
   [Checked frame range metadata](static-view-ranges.md) now supplies compact
   descriptor bounds, kind/function and liveness checks. The
   [range execution successor](static-range-execution.md) now adds independently
   proved RANGE 76 and actual per-frame spans with complete Fuel/bounds preflight,
   nested narrowing, recursive isolation and loop reentry. General runtime view
   arguments and Static CALL/return origins remain. The
   [range-source successor](static-range-source.md) now lowers computed byte
   endpoints with hidden parent cleanup on return/propagation/break/continue and
   retains an owned equality left argument across right-argument exits. Finish
   Static CALL/return receipts and general references. The
   [Static CALL recipe proof](static-call-ir.md) now reconstructs typed argument
   classes, separate view lifetimes and grounded logical-input/Static origins
   from actual IR, including transitive calls and recursive witnesses. Complete
   scalar/owner/loan analysis is now connected by the
   [Static CALL admission successor](static-call-admission.md), including possible
   real image roots and exact text windows. The
   [canonical transfer successor](static-call-transfer.md) now executes private
   PARAM/CALL/RETURN against a retained CallProgram, with actual per-frame words,
   full Fuel/destination preflight and ordinary ownership cleanup. The
   [byte-access successor](reference-access.md) now shares instruction-local
   READ/LEN across image sites and runtime byte loans while retaining their
   authentication and prices. The [shared byte-formal analysis](reference-formals.md)
   now combines mixed-backing signature/CFG recipes with canonical runtime loan
   type, owner and liveness proof. The [native VM successor](reference-vm.md) now
   executes mixed-backing CALL/PARAM using existing native captures and compact
   window words, with exact Fuel and prepaid failure cleanup. The
   [returned-reference recipes](reference-return-ir.md) now reconstruct shared-byte
   result signatures and grounded image/input/local origins. The
   [canonical result-analysis successor](reference-return-lifetimes.md) now adds
   complete scalar/owner/loan proof and local-owner exclusion through all returned
   aliases. The [native receipt prerequisite](reference-receipts.md) now provides
   disjoint sparse bindings, exact returned windows and transactional last-alias
   close without another frame map. The [native result VM successor](reference-return-vm.md)
   now connects retained admission and canonical selected CALL/RETURN handoff,
   caller publication, exact windows and complete Fuel preflight. The
   [shared byte CALL source successor](reference-call-source.md) now lowers shared
   formals and image/runtime actuals through retained native CALL execution. The
   [returned-source successor](reference-return-source.md) now lowers return
   expressions, result bindings and selected temporary owner lifetimes through
   the same complete proof/native VM. The [public Program successor](public-program.md)
   now connects retained byte/text/shared-byte source to public check/run with
   complete admission, fresh native state and explicit canonical Fuel prices.
   General mutable/non-byte/Buffer/input results and host-visible lifetimes remain.
   Continue language completion while preserving those explicit boundaries.
2. **Language completion: L01-L06, C03/C05.** The [source snapshot prerequisite](module-sources.md)
   now retains native explicit source identities, immutable original bytes and
   checked source-local spans. The [module index](module-index.md) now binds
   canonical module names, explicit aliases and public/private declarations while
   owning that exact snapshot. The [entry signature successor](module-entry.md)
   now retains a named public zero-argument i32 entry beside its exact Index.
   The [source context](source-context.md) supplies exact file fences, scoped name
   lookup and qualified function signatures/nominal record catalogs. The
   [retained module Program](module-program.md) now carries that context through
   expression/constructor/field/reference lowering, the selected entry through
   complete body/type/ownership and independent IR/image checks, and actual native
   multi-module execution with original source identity. The [native project Program](project-program.md) now retains complete project metadata beside that executable, independently rechecks exact map/header/entry agreement and denies nonempty requirements before guest/Fuel work. Public project loading,
   module/entry CLI flags and deliberate full-profile limits still leave L01 open.
   [Scalar/complete-tagged local inference](local-inference.md) is implemented;
   finish aggregate/borrow/text and constructor inference, void/if values,
   complete array/record construction,
   selected-place compound assignment, wider/resource-bearing tags and must-use
   handling. Reconcile operand/source/type/compile limits deliberately rather than
   silently treating the old experimental bounds as full-profile conformance.
   L07 byte compatibility is implemented at `5bb055b` and has focused checks.
3. **Engine and Instance: R01-R05.** The [call capture-stack fix](native-call-capture-stack.md)
   removes a reproduced retained compiler overflow without changing depth/owner
   limits; it does not close general R02 stack/accounting obligations.
   Implement lifecycle/reentry/Program retention,
   complete accounting and preallocation, bounded resumable operations, deadlines,
   cancellation, poison and stable terminal state. Include cleanup at zero guest
   Fuel and prove result/Fuel invariance across step sizes. Current fresh-state VM
   invocation and flat metadata prices do not meet this step/Instance contract.
4. **Useful byte/text workload: D01-D05, I01-I02.** Connect native Buffer owners
   and leases to guest move-only values, wrappers and Instance teardown. Expose
   bounded byte/text operations, actual guest input and staged success-only output.
   Run a complete input -> validation/transform -> output example.
5. **Authority and host exchange: H01-H04, C01-C02/C04.** Add strict bounded
   project/policy/catalog/run loaders, source identities, ceilings/declarations/
   grants, typed TLV and a resumable host request/reply state machine. Start with
   an in-memory adapter, including malformed/late/duplicate reply handling. Expose
   only the CLI controls and metadata whose underlying paths exist.
6. **Restricted Windows delivery: W01-W06.** Implement actual restricted process
   creation, Job and handle limits, authenticated bounded transport, broker phases
   and publication barrier, cancellation and I/O lease/reaping budgets. Verify
   races and denial behavior on the real OS before advertising isolation.
7. **Embedding and packages: E01-E04.** Export the actual v2 DLL/C ABI, implement
   typed generation handles and thread/lifetime rules, bounded data exchange,
   clean-machine packages and native platform evidence. Fairy module visibility
   alone is not a public C ABI or clean-machine proof.
8. **Full-profile evidence and delivery: V01-V05.** Execute the accepted reference
   source cases and complete profile cases; apply focused mutation/failure tests
   to implemented trust boundaries; measure compile/reuse/runtime/memory/build
   retention targets. Record supported-platform, compatibility and release-unit
   evidence. Keep CI limited to necessary checks and batch remote delivery only
   when authorized.

These groups overlap where a vertical feature needs its runtime prerequisite;
they are not permission gates for routine local implementation. No group is
complete until its owning inventory conditions have current evidence. In
particular B04 public bindings, Buffer, Engine/Instance, host exchange, restricted
delivery and DLL exports are still open after the lexical/range increments.

## Next B04 integration constraints

- Ordinary scalar entry/terminal execution now uses the same canonical native
  coordinator through `vm::run_slice_scalar`; retained inputs return fresh resumed
  tickets and anonymous captures close transactionally. See the
  [scalar entry contract](m2-slice-scalar-entry.md). This is a prerequisite for
  public scalar callers, not public returned-result admission or lexical binding.
- Native `frames::pop` can now retain a result in a caller slice site without
  preparing that caller. Held close restores the fresh parent binding and uses
  its prepaid finalizer; terminal handoff consumes the callee's receipts. See
  the [binding foundation](m2-slice-result-bindings.md). Source/new IR admission
  must still prove and route those destinations before guest code can use them.
- Use the 47-entry sparse Held map. Exclusive descendants share physical slots,
  so sixteen pool slots are not a sixteen-receipt limit: at most 31 canonical
  exclusive children plus shared slots bound the live set, with one publication
  spare. Preserve canonical authority/owners/pool and exact generations.
- Private CALL-binding IR now has a [destination/origin proof](m2-slice-result-call-ir.md),
  including exact END masks and definition-based recursive origins. Source lowering
  is connected by the [source successor](m2-slice-result-call-source.md), including
  selected temporary retention in IR. The [execution successor](m2-slice-result-call-execution.md)
  now connects native destinations, masks, fresh parents and actual owner lifetime.
  Public admission/dispatch and remaining argument/Static forms stay open.
- Independent admission must prove the destination's exact type/access, selected
  input origin and whole-root conflict/lifetime, including CFG joins and cleanup.
  An ordinary scalar proxy or an unchecked CALL flag is not that proof.
- Ordinary array/range CALL captures retain immediate call-scoped cleanup. The
  new private result-binding IR retains selected temporary parents/owners through
  lexical cleanup. Connect this proved lifetime to actual VM handoff/close; keep
  unselected capture cleanup and fresh parent publication exact.
- Public promotion requires source-to-execution cases for ordinary callers,
  aliases, nested uses, traps and cleanup, plus accurate capability metadata.
  Implementing only a native registry does not close B04.

- The [public Fuel successor](public-fuel-limits.md) deliberately raises the
  explicit CLI ceiling to 16000000, retains the 256 default and existing prices,
  and unifies public slice cost formulas. This resolves the narrow budget gap.
  Ordinary returned-reference Program admission/dispatch and other C05 capacities
  remain open; public result promotion still needs its own end-to-end proof.

The native/IR [caller END-chain prerequisite](m2-slice-result-capture-chains.md)
now supports multiple temporary Held/reborrow closes before result installation.
Its next-source-bridge section records ancestry retention, prompt unselected
cleanup, recursive source hints and endpoint/exit requirements. Connect these
source forms next; this foundation does not complete B04 or public admission.

The [direct-argument successor](m2-slice-result-arguments.md) now connects nested
returned actuals, including argument ranges, transitive shared/owned retention,
exclusive chain collapse and recursive advisory source hints. Ordinary result
kinds retain reverse capture cleanup. The [range-projection successor](m2-slice-result-range-projections.md)
now connects declaration/return ranges over retained CALL results. Static backing,
general references and public promotion remain next.

Native project metadata now admits the complete explicit source map and entry
under the [owning format](../cli/project-format.md). Exact snapshot/header binding
and the [retained native project Program](project-program.md) now connect that
map and its preserved requirements to complete executable admission. Next implement
anchored filesystem collection and public project CLI, then policy/grant integration.
The full completion objective remains open.

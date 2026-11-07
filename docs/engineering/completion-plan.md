- Latest origin-set checkpoint (2026-11-07): [Shared reference origin sets](../engineering/value-view-origin-sets.md)
  now join different already-live Buffer/formal roots through private byte views.
  Independent fixed-point proof pins every candidate, rechecks widened loops and
  keeps shared returns at one selected formal. Per-origin retention and cleanup
  preserve mixed named/anonymous roots; Buffer view copies accept formal origins.
  `49dc33f` passed 49 groups per Windows native profile, using concurrent locked
  mirrors and default native stacks. All 231 inputs match checkout/Git raw
  bytes; all 216 production modules are LF. See [evidence](../evidence/value-view-origin-sets-windows-20261107.json).
  Next: conditional branch-created owners, evolving source-loop origin inference,
  bottom expressions, general references, methods, public admission/AllocError and
  remaining runtime/host/platform work. Existing prices/Fuel limits remain. Local only.

- Predecessor native view-call checkpoint (2026-11-07): [Shared Buffer view CALL/RETURN](value-view-calls.md) now
  publishes up to eight argument aliases atomically and returns only a window
  contained in the selected caller origin across authenticated adjacent frames.
  `4c8c84d` passed 12 native groups per Windows profile (six new); all 223 inputs
  match checkout/Git raw bytes and 214 production modules are LF. See [evidence](../evidence/value-view-calls-windows-20261107.json).
  This is the native prerequisite; guest reference signatures/IR/source remain
  next, followed by view-valued joins and the remaining full-profile work.
  Public admission/prices remain unchanged. Local commits only; no push/release.

- Predecessor Buffer view-copy checkpoint, 2026-11-07: Private [Buffer view copying](value-view-copy.md) now accepts
  `bytes::copy(ref view)` and qualified/range/temporary inputs, returning an
  independent exact `Result<Buffer,u8>`. APPEND_VIEW112 independently proves live
  views, a live distinct unpinned Buffer and a fresh Result; runtime prepays
  publication and copies only authenticated initialized bytes without payload
  staging. The anonymous capture closes before Result wrapping; named views stay
  pinned. Kernel `3d158ba` and integrated source/VM `223260f` are local commits.
  Windows development/release each passed 21 groups (nine new) in three
  disjoint batches. All 224 union inputs match checkout/Git raw bytes; all 213
  production modules are LF. The unchanged admitted32/rejected33 depth fixture
  executes in both profiles. See [evidence](../evidence/value-view-copy-windows-20261107.json).
  Next: general reference parameters/results, reference-valued joins, methods,
  public AllocError/admission, text/I/O, full Engine/Instance/host/cancellation,
  isolation and platform/delivery. Existing prices, no-view setup costs and public
  Fuel default256/ceiling16000000 stay unchanged. The full objective remains open.
  Local only; no push/release/deployment.

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

Predecessor native Buffer view checkpoint (2026-11-07): Native [Buffer view lifetimes](value-buffer-views.md) now pin actual
roots through shared aliases and nested ranges, with authenticated bindings,
checked windows, last-alias release and generation retirement. Read/copy-out
exposes no native view. Registry metadata shares root quotas and refunds before
root drain; cleanup needs no remaining Fuel. Both Windows native profiles passed
19 groups (views/leases/roots 10, root/frame/copy regressions 9) on `34863b5`.
All 219 union inputs match checkout/Git raw bytes; all 208 production modules are
LF. See [evidence](../evidence/value-buffer-views-windows-20261107.json). Native bookkeeping is not guest authority.
Next connect independent Buffer view IR/CFG/retained VM and source admission,
then copy-from-view, public AllocError, text/I/O and the remaining full profile.
Public gates, existing prices/Fuel defaults remain. Local only; no push/release.

Predecessor private Buffer copy checkpoint (2026-11-07): Private [owned Buffer copy](value-buffer-copy.md) now lowers
`bytes::copy(ref b)` / `brownie::bytes::copy(ref b)` to exact `Result<Buffer,u8>`.
One native append copies initialized bytes into an independent owner, retaining
the source and cleaning temporary inputs. Shared Result destinations avoid
extra arm slots; no opcode or existing Fuel price changes. Both Windows native
profiles passed 13 groups (source 9/native 4), including 22 new guest programs and
the unchanged 32/33 depth fixture, on `ee8a686`. All 218 inputs match checkout/Git
raw bytes; all 207 production modules are LF. See [evidence](../evidence/value-buffer-copy-windows-20261107.json).
Next Buffer views, copy-from-view, methods/public AllocError and deliberate public
admission, text/I/O and general language/runtime composition. The full objective
remains open. Local only; no push/release/deployment.

Predecessor private Buffer source checkpoint (2026-11-07): Private [Buffer source operations and loans](value-buffer-source.md) now lower
`bytes::` / `brownie::bytes::` empty, len/read/write and push/reserve/append.
Compiler-only loans protect later arguments, survive control/propagation/loop
exits and release temporary owners. Named mutation requires `var`; overlapping
loans and self append reject. Typed `&&`/`||` skip runtime RHS work and join
conditional moves and Result obligations. Both Windows native profiles passed
12 groups (source 7/native 5), including 62 new guest programs and the unchanged
32/33 depth fixture, on `e8d2a7d`. All 217 inputs match checkout/Git raw bytes;
all 206 production modules are LF. See [evidence](../evidence/value-buffer-source-windows-20261107.json).
Next Buffer copy/view/methods, public AllocError and deliberate public admission,
text/I/O and general aggregate/reference/module/runtime composition. D02/D04 and
the full objective remain open. Public gates, existing prices and Fuel default
256 / ceiling 16000000 remain unchanged. Local only; no push/release/deployment.

Predecessor private Buffer instruction checkpoint (2026-11-07): Private [Buffer instructions](value-buffer-execution.md) now independently verify and execute
length/read/write, push/reserve and distinct-source append (99..104). Growing
operations prepay canonical Result publication; allocator errors return the
private Result<usize,u8>, while Fuel/quota/bounds remain execution errors. Source
owners and failed operations retain their bytes/accounting. Both Windows native
profiles passed ten focused groups on `6107487`; all 210 inputs match checkout/Git
raw bytes and all 202 production modules are LF. See [evidence](../evidence/value-buffer-execution-windows-20261107.json).
Next source Buffer methods/borrows/views, a public AllocError contract and I/O,
then general aggregate/reference/module/public composition. D02/D04 and the full
objective remain open. Existing prices/Fuel defaults and public gates remain.

Predecessor private loop checkpoint (2026-11-07): Private [typed lexical loops](value-loops.md) now connect while,
classic for and nearest break/continue to real owner cleanup and cyclic Result
obligations. Backedges preserve header initialization; exit trampolines normalize
break/zero-trip liveness. Escaping branch exits survive scoped pool compaction.
Nested Result summaries catch second-iteration discards while allowing the next
condition to acknowledge a body replacement. Both Windows profiles passed ten
groups (source 7/native 3), with 47 guest programs and the unchanged 32/33 fixture,
on `85b10f6` after helper `5c3bb12`. All 212 inputs match checkout/Git raw bytes;
all 201 production modules are LF. See
[evidence](../evidence/value-loops-windows-20261107.json). Public gates,
capabilities, existing prices and Fuel default/cap stay unchanged. Next useful
Buffer operations and general aggregate/reference/module/public composition.
Full implementation and broader validation remain open.

Predecessor private value-join checkpoint (2026-11-07): Private [typed if/switch values](value-joins.md) now join exact
scalar, Buffer and nested-tag values, including local owners and terminal return
arms. One destination is initialized only on yielding paths; arm cleanup follows
publication, and Result obligations survive joins. Both Windows profiles passed
ten groups (source 7/native 3), with 55 new guest programs and the unchanged 32/33
fixture, on `7a7ff8f` after helper `f06cc54`. All 210 inputs match checkout/Git raw
bytes; all 199 production modules are LF. See
[evidence](../evidence/value-joins-windows-20261107.json). Public source/CLI gates,
capabilities, existing prices and Fuel default/cap stay unchanged. Next typed
loops/break/continue, useful Buffer operations and general source/public
composition. Full implementation and broader validation remain open.

Predecessor private must-use checkpoint (2026-11-07): Private [typed Result obligations](value-must-use.md) now reject
unhandled Results at overwrite, scope/return exits and early propagation edges.
Non-consuming predicates, exhaustive cases, return, CALL and explicit discard
handle or transfer obligations independently of COPY ownership. Both Windows
profiles passed ten focused groups (source 7/native 3), including 80 new guest
programs and the unchanged admitted 32/rejected 33 fixture, on `b6e18b2`.
All 209 inputs match checkout/Git raw bytes; all 198 production modules are LF.
See [evidence](../evidence/value-must-use-windows-20261107.json). Public gates,
capabilities, existing instruction prices and Fuel defaults/cap are unchanged.
Next typed value-expression joins, loops, useful Buffer operations and general
source/public composition; the full objective and broader validation remain open.

Predecessor private propagation checkpoint (2026-11-07): [typed postfix `?`](value-propagation.md)
now connects exact-family Option/Result success and early failure across wide,
nested and Buffer payloads. Cleanup includes earlier anonymous CALL captures and
lexical owners before RETURN94. Both Windows native profiles passed 11 groups in
disjoint source 8/helper 3 selections on `78cde1f`, with 208 checkout/Git-raw matching
inputs and 198 LF modules. See [evidence](../evidence/value-propagation-windows-20261107.json).
The existing admitted 32/rejected 33 fixture remains unchanged. Public gates and
existing prices/default/cap stay unchanged. Next Result must-use diagnostics,
typed value-expression joins, loops, useful Buffer operations and general source/
public composition. Full implementation and broader validation remain open.

Predecessor private predicate checkpoint (2026-11-07): [non-consuming tag inspection](value-predicates.md)
now preserves named/grouped Option/Result receivers, including active/inactive
Buffer wrappers, through TAG_TEST98. Computed subjects evaluate once then drop.
Both native profiles passed 26 groups (source 22 + instruction 4), with 210 matching
checkout/Git-raw inputs and 197 LF modules, on `5a02886`. See
[evidence](../evidence/value-predicates-windows-20261107.json). The existing
admitted 32/rejected 33 conditional fixture stays byte-identical; public compiler/
CLI gates and existing prices/default/cap stay unchanged. Next propagation,
must-use, typed value-expression joins, loops, useful Buffer operations and general
source/public composition. Full implementation and broad validation remain open.

Predecessor private control checkpoint (2026-11-07): [mutation and statement joins](value-control.md)
now implement mutable typed/scalar locals, replacement/reinitialization, checked
compound assignments, if/else-if and exhaustive nested tag switches. Continuing
paths converge through real cleanup to their live-set intersection. Both native
profiles passed 29 groups on `dbda356` after `a95eb11`, including unchanged admitted 32/
rejected 33 conditional depth. All 209 inputs match checkout/Git raw bytes; 197
production modules are LF. See [evidence](../evidence/value-control-windows-20261107.json).
Next extend wider non-consuming predicates and propagation, typed value-expression
joins and loops, then useful Buffer operations and general source/public composition.
The full objective and broader validation obligations remain open.

Predecessor private body checkpoint (2026-11-07): [typed-source bodies](value-body.md)
now connect empty Buffer/nested wide-wrapper construction, immutable locals,
lexical cleanup and mixed forward CALL/RETURN to independently verified native
execution. Development/release each passed 19 native groups on `468394d`; all 206
inputs match checkout/Git raw bytes and 196 production modules are LF. See the
[evidence](../evidence/value-body-windows-20261107.json). Next implement mutable
assignment and control-flow joins, then wider predicates/propagation, Buffer
byte/text/input/output operations, aggregate/reference/module composition and
public admission. The broader objective and validation obligations remain open.

Predecessor source checkpoint (2026-11-07): [value-source foundations](value-source.md)
provide canonical types, atomic complete-signature scanning and immutable lexical
COPY89/MOVE88/reverse-DROP90 metadata. Public scalar/tagged Result now has `.is_ok`
and `_ = EXPR;`; `result_is_ok` and `explicit_discard` are true, but
`must_use_result` remains false. Next connect executable Buffer/wider-wrapper
constructors, locals, CALL, assignment and return. Windows development/release
each passed 19 focused native groups and a separate 150-case CLI phase (105 Fuel +
45 Result). All 207 final inputs match checkout and committed raw bytes; all 193
production modules are LF. See the [proof](../evidence/value-source-windows-20261107.json)
and [input evidence](../evidence/value-source-inputs-windows-20261107.json). Full L04/L05/L06 and Engine/Instance/host/isolation/platform/
delivery remain open. Full matrices, Linux, LF runtime mirrors, OOM/general stack/
performance and clean-machine delivery were not run; existing opcode prices,
Fuel default 256 / ceiling 16000000 and wider capability gates remain unchanged.

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
   the [owned aggregate successor](aggregate-inference.md) adds repeated array
   initializers, record constructors, copies, CALLs and record child paths. The
   [reference/text successor](reference-inference.md) adds existing image views,
   runtime loans, aliases and shared-byte results with original ownership proof.
   [Payload-derived Option constructors](option-constructor-inference.md) now
   infer existing i32/bool `.some` payloads through the same emitter. Finish
   branch-order-independent constructor context and general aggregate-expression
   inference, void/if values,
   complete array/record construction. The [native array-list storage
   prerequisite](array-list-storage.md) now stages all exact scalar values before
   atomic backing and owner publication, with unchanged 4096-element capacity.
   The [IR/VM successor](array-list-execution.md) now supplies complete operand/
   CFG/owner proof, atomic ordinary/retained execution and reusable prepaid
   invocation scratch. The [source declaration successor](array-list-source.md)
   now connects inferred/annotated lists, exact arity/types, left-to-right one-time
   evaluation and nonlocal-exit cleanup. The [contextual successor](array-list-contexts.md)
   now adds direct list arguments, returned literals and borrowed temporaries.
   The [replacement storage prerequisite](array-list-replace-storage.md) now
   atomically overwrites exact scalar extents without another owner or allocation.
   The [native execution successor](array-list-replace-execution.md) now adds
   independent IR proof and both VM drivers with exact prepaid replacement Fuel.
   The [source assignment successor](array-list-assignment.md) now connects
   existing mutable destinations, ordered evaluation and nonlocal-exit cleanup.
   The [scalar literal projection successor](array-literal-projections.md) now
   adds index/length expressions, grouping, prompt temporary cleanup and UTF-8
   element lists. The [grouped-array successor](array-expression-projections.md)
   now connects existing/literal/CALL values through scalar projections and
   by-value initialization, CALL, return, replacement and UTF-8 contexts. Finish
   broader record/control-flow expressions and grouped lvalues/borrows; then continue with
   selected-place compound assignment, wider/resource-bearing
   tags and must-use
   handling.
   The [native copy-window prerequisite](aggregate-copy-windows.md) now guards
   current scalar-array/plain-record storage, including exact self identity and
   record snapshots. Connect independent general IR copy/lifetime proof and
   aggregate selected places before claiming the generic L04 contract complete.
   Reconcile operand/source/type/compile limits deliberately rather than
   silently treating the old experimental bounds as full-profile conformance.
   L07 byte compatibility is implemented at `5bb055b` and has focused checks.
   The [resource/tag prerequisite](value-ownership.md) now independently derives
   whole-type layout/copyability and hands off actual native Buffer roots while
   preserving one token/charge and returning ownership on preflight rejection.
   The [typed value IR successor](value-ir.md) now independently proves move/Dead
   CFG, tag build/case, scalar conversion and CALL/RETURN against canonical scalar,
   owner/loan and selected-place analysis. The [canonical byte successor](value-codec.md)
   now supplies retained layouts, active-resource inspection and validated atomic
   copy/wrapper bytes. The [owning root successor](value-roots.md) now retains
   actual native allocations, serial/token/location bindings, metered moves and
   destruction-before-refund cleanup with setup-prepaid failure drain. The native
   coordinator retains its matching State and two owning vectors for one lifetime;
   this is not guest/Engine authority. The [native frame successor](value-frames.md)
   now connects initialized/Dead slots, activation generations, COPY/MOVE, tag
   build/CASE, combined quotas and prepaid normal/failure cleanup to actual native
   backing/root bindings. The [private execution successor](value-execution.md)
   is now implemented in source: an immutable retained value Program binds full
   admission, code/layout and reborrow proof to operations 88..97, atomic mixed
   typed/ordinary CALL/RETURN, combined quotas and prepaid terminal cleanup.
   Windows development/release each passed 26 native groups and 105 tool-free
   public Fuel CLI cases; see the [evidence](../evidence/value-execution-windows-20261107.json).
   This `d025c6f`/`fe387bf` predecessor is followed by the
   [source foundations](value-source.md): `value_type_source` canonicalizes all
   six scalar domains, arrays of 1..4096 elements, Buffer aliases, nominal records
   and Option/Result through depth four, with atomic rollback and canonical IDs.
   `functions::scan_values` validates entire typed signatures and atomically
   publishes the catalog; original scan/scoped gates are unchanged.
   `value_source_bindings` provides immutable lexical compiler metadata, COPY89 /
   MOVE88 and reverse DROP90, monotonic sixteen-slot allocation and dead-source
   rejection. CFG alternative snapshots never rewind allocations or owner authority.
   The [private body successor](value-body.md) now connects empty Buffer and nested
   wrapper constructors, immutable locals, lexical cleanup and mixed CALL/RETURN.
   The [control successor](value-control.md) now adds mutable assignment and
   statement if/switch joins. The [predicate successor](value-predicates.md) now adds
   non-consuming inspection. The [propagation successor](value-propagation.md) now
   adds typed early return and complete anonymous capture cleanup. The
   [private must-use successor](value-must-use.md) checks bindings, parameters,
   replacement, scopes and early exits independently of COPY ownership. The
   [typed-join successor](value-joins.md) now adds exact scalar/Buffer/nested-tag
   if/switch values with publication before arm cleanup. The
   [private loop successor](value-loops.md) connects while/for/break/continue,
   exact header initialization, escaping exit retention and cyclic Result checking.
   The [native Buffer kernel](value-buffer.md) now provides authenticated byte
   operations through real roots/frames. [Private Buffer instructions](value-buffer-execution.md)
   now connect independent proof/dispatch, distinct-source append and prepaid
   allocator-error Results. Next source borrowing/methods/views, public AllocError and I/O,
   before general aggregate/reference/module composition and public admission.
   Public L06 composition and
   complete validation remain, so the public `must_use_result` flag stays false.
   These increments do not close L04/L05/L06/D01-D04; wider public gates and
   ordinary prices/default/cap remain unchanged.
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
  The aggregate successor also centralizes existing array/record/list prices
  and shares 24 independent numeric source oracles across native/public CLI
  boundaries, including current grouped assignments in both execution routes.
  The [public retained Program](public-program.md) now admits and executes the
  shared-byte image/runtime result subset with its canonical prepaid schedule.
  General mutable/non-byte/Buffer/input results, Engine/Instance budgets and
  other C05 capacities remain open; this ceiling does not promote those limits.

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

- Latest owning-VM checkpoint (2026-11-08): [Pending output VM](runtime-pending-output.md)
  records implementation `1e1e47b`. The private continuation now returns Pending
  to its caller and preserves banks/frames/authority/loans/input/scratch/output in
  owned storage. One exact Core allocation and typed in-place initialization fix
  a reproduced default-stack overflow; no stack-size override is used. Native
  development/O2 cover eight new groups, fixed/mixed quanta, exact final output/
  Fuel/original diagnostics, zero resume allocations, all preparation allocation
  ordinals in the exercised recipe and zero SDK heap at exit. The archive pins
  234 checkout/Git inputs, seven SDK objects, 29 bindings and 20 layouts.
  Root check: 255 sources/2911 MIR; all 247 production modules are LF.
  Caller-pinned Program/input, owning Engine Instance association, native heap
  ledgers, bounded bulk/setup/publication/cleanup, deadlines and poison remain
  open. The existing Engine facade is synchronous; R03-R05 stay incomplete.
  Public gates, capacities and Fuel prices/default256/cap16000000 are unchanged.
  Two disjoint Sol High workers completed; integration/commits were serial. Local only.

- Predecessor immutable-input execution checkpoint (2026-11-07): [Actual 1MiB input](module-input-execution.md)
  integrates input windows `3503aba` and owning Program execution `c86aff6`.
  Development/O2 each pass 16 native groups: full input lengths/last byte,
  returned/nested/overlapping ranges, mixed backing, origin mutations, exact Fuel,
  original diagnostics and six unchanged reference/module/depth regressions.
  Kernel development/O2 six-group and explicit layout/OOM evidence is retained.
  The reviewed 185-module Engine transport also passes both profiles, eight typed
  bindings, real OS guards/default stacks and zero live heap allocations.
  All 256 current aggregate inputs match raw checkout/committed Git; 233
  production modules retain LF. Root check: 241 sources/2748 MIR functions.
  Original public gates, capacities and prices/default256/ceiling16000000 remain;
  new input-only metadata charges are explicit. No input payload copy during run.
  Next: owning input Program/Snapshot Engine/Instance association, OS-reader
  adoption and guest-output success binding. Full accounting, bounded steps,
  deadlines/poison, host/restricted/embed and the accepted inventory remain open.
  Parallel patches were reviewed/committed serially; workers closed. Local only.

- Predecessor project/input integration checkpoint (2026-11-07): [Project sources and binary input](runtime-project-input-integration.md)
  records owning input Program admission `070ceaa`, private anchored project
  compile/run `40f2c45` and bounded Windows binary input `564bd6f`.
  Development/O2 each pass five input Program groups and 18 actual project cases;
  binary input passes three production/six test groups plus four explicit syscall
  return injections and an expected old-branch failure in each profile. Actual
  zero-byte pipe reads were not reproduced; injection is separately labeled.
  All 258 aggregate inputs match raw checkout/committed Git; 232 production
  modules retain LF. Project/reader integration changes no root source/lock.
  Public gates, VM capacities and Fuel prices/default256/ceiling16000000 remain.
  Next: actual 1MiB input VM windows through PARAM/CALL/return/READ/LEN, then
  Engine/OS input and staged output binding. Full accounting, bounded steps,
  deadlines/poison, host/restricted/embed and the accepted inventory remain open.
  Disjoint parallel patches were reviewed and committed serially; workers closed.
  Local only; no push/release/deployment.

- Predecessor owning-runtime integration checkpoint (2026-11-07): [Engine, sources and I/O](runtime-engine-io-sources.md)
  integrates real Program/one-shot Instance ownership `5ccb424`, anchored Windows
  acquisition `1a6f5c2`, owning I/O staging `0b7231a`, actual collector->Fairy
  Snapshot admission `2d298d8`, and exact shared-byte input signatures `333f47a`.
  All native development/O2 checks pass: collector five groups/profile, I/O ten,
  input/unchanged entry thirteen, plus Engine and loader ownership/OS harnesses.
  Completion contention, exhausted-epoch teardown, image move/relocation, real
  allocator failures and zero retained allocations have focused native evidence.
  All 218 aggregate inputs match checkout/Git raw bytes; all 231 production
  modules are LF, with the prior 228 unchanged. Root check: 239 sources/2678 MIR.
  Public gates, existing VM capacities and Fuel prices/default256/ceiling16000000
  remain unchanged. Project/Engine source binding and executable input/output,
  full accounting, bounded steps, deadlines/poison, host/restricted/embed and the
  accepted inventory stay open. Parallel workers completed, patches reviewed and
  committed serially. Local only; no push/release/deployment.

- Predecessor runtime-admission/exchange checkpoint (2026-11-07): [Parallel integration](runtime-admission-exchange.md)
  integrates typed policy/run admission `c774ee0` (21 native groups per Windows
  profile), actual private host exchange `dcbba76` (13 groups/profile, layout and
  identity hosts, four explicit allocator failures), and three final release
  composition groups `8846b0f`, including the unchanged combined 32/33 fixture.
  The owning Store probe `5453574` passes development/O2 with exact drop order and
  zero live allocations; it is an R01 prerequisite, not lifecycle completion.
  All 283 aggregate inputs match checkout/Git raw bytes; 228 production modules
  retain LF. Root check: 236 sources/2644 MIR. Existing public gates, VM capacities,
  Fuel prices/default256/ceiling16000000 and all earlier source bytes are unchanged.
  Full Engine/Program/Instance/VM host binding, R03 work quanta and the accepted
  remaining inventory stay open. Workers completed; local only, no remote changes.

- Predecessor parallel-integration checkpoint (2026-11-07): [Composed native verification](parallel-integration.md)
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

- Predecessor registry-prerequisite checkpoint (2026-11-07): [Fairy handles](abi-handles.md)
  (`fef9fd3`) passed ten native groups per development/release profile; unchanged
  kernel/test/compiler evidence was retained after the root 227-source/2487-MIR
  composition check. [Windows guard/TLS](abi-thread-identity.md) (`5618726`)
  passed real development/optimized OS hosts, including live-TLS release checks: eight concurrent threads, 1024
  guarded updates, 32 sequential lifetimes and nonwrapping ticket exhaustion.
  These separate components are not yet one lazy process registry or public
  Engine/Program/Instance APIs. Full E02/E01, host exchange and inventory remain
  open. Host TLV codec `6560805` separately passed ten groups in both profiles.
  No public gates, existing Fuel prices/defaults/caps or delivery changes.

- Predecessor host-wire checkpoint (2026-11-07): [Typed TLV codecs](host-wire.md)
  validate/encode exact request and success/error/fatal payloads with whole-message
  preflight and header-inclusive 1MiB limits. Implementation `6560805` passed ten
  native groups per Windows development/release profile (six new, four scalar
  regressions), with 227 checkout/Git-raw matching inputs and 218 LF modules.
  Catalog binding/digest, actual host dispatch/adoption, process-wide handles,
  Engine/Instance/VM ABI and the full inventory remain open. Public host/embed
  availability, existing limits and Fuel prices/defaults/caps are unchanged.

- Predecessor ABI-bootstrap checkpoint (2026-11-07): [Windows DLL query](abi-bootstrap.md)
  now exports only `bc_get_abi_info_v2`; Fairy owns admission/metadata and a small
  native shim marshals the exact 32-byte result. `ad86fc9` passed 53 real DLL calls
  in each development/optimized profile, C/C++ layouts, guard pages, singleton
  exports and four fail-closed controls. Unicode output and empty tool PATH pass.
  Build uses included ABI references; the original ZIP is optional provenance.
  All 228 root/feature inputs match checkout/Git raw bytes; all 217 production
  modules retain LF. Native bootstrap freezes nine feature inputs; it does not
  execute the VM. See [evidence](../evidence/abi-bootstrap-windows-20261107.json).
  E01/full embedding, Engine/Instance/handles and all other accepted inventory
  work remain open. CLI availability/Fuel/gates are unchanged. Local only.

- Predecessor terminal-operands checkpoint (2026-11-07): [Final Buffer/view operands](value-terminal-operands.md)
  now propagate terminal control after real receiver/index work without the
  enclosing byte operation or duplicate cleanup. `093475d` passed five new
  development groups across two scoped snapshots, seven integrated development
  regressions and all twelve final release groups. The four retained group bodies
  and helpers are byte-identical; only an ambiguous .none fixture was annotated.
  All 227 union inputs match checkout/Git raw bytes; all 216 production modules
  retain LF. See [evidence](../evidence/value-terminal-operands-windows-20261107.json).
  The combined 32/33 fixture and existing opcodes/prices/public/Fuel gates remain.
  Nonfinal/unreachable contexts, fresh loop owners, general references and the
  full runtime/host/isolation/embed/platform/delivery inventory remain open. Local only.

- Predecessor void-bottom checkpoint (2026-11-07): [Terminal void-return operands](value-void-bottom.md)
  now compose private `return <bottom>;` without an extra return/capture/cleanup.
  `37c3994` passed five new development groups on byte-identical worker inputs,
  four integrated development regressions and all nine integrated release groups.
  All 226 union inputs match checkout/Git raw bytes, all 216 production modules
  are LF, and all 220 worker inputs match integration. See [evidence](../evidence/value-void-bottom-windows-20261107.json).
  The combined 32/33 depth fixture is unchanged. Bare return and non-bottom
  rejection remain; VM/opcodes/prices/public gates/Fuel defaults/caps are unchanged.
  Fresh loop owners, other bottom/general references, methods/AllocError and
  runtime/host/platform/delivery remain open. Full completion remains open. Local only.

- Predecessor safe-cast checkpoint (2026-11-07): [Private retained-value strict widening](value-safe-casts.md)
  now passed 15 groups in each Windows native profile on `4b0601b`, using locked
  disjoint mirrors and default stacks. All 227 inputs match checkout/Git raw bytes;
  all 216 production modules are LF. See [evidence](../evidence/value-safe-casts-windows-20261107.json).
  Unary/postfix precedes explicit `as`, then binary operators; chains associate
  left to right. The existing matrix admits 7 of 36 scalar pairs without implicit
  conversion. Effects evaluate once; bottom validates scalar target syntax without
  reading/emitting/interning a cast. The combined 32/33 depth fixture is unchanged.
  No VM, opcode, pricing or public admission changes. Fresh loop-carried owners,
  remaining bottom/general references, methods/AllocError and runtime/host/platform
  work remain open. Full completion remains open. Local only.

- Predecessor header-owner checkpoint (2026-11-07): [Deferred anonymous loop-header owners](../engineering/value-loop-header-owners.md)
  now preserve pre-existing retained seeds when their last view is rebound on a
  repeating edge. Compiler protection survives snapshots/trims/nested loops;
  reached exits release only their mask and terminal cleanup releases all after
  preflight. Real owners stay charged; no dummy owner, payload copy or source replay.
  `03c758a` passed 15 groups per Windows native profile with locked disjoint
  mirrors and default stacks. All 228 inputs match checkout/Git raw bytes;
  all 216 production modules are LF. See [evidence](../evidence/value-loop-header-owners-windows-20261107.json).
  The combined depth fixture is byte-identical. No runtime field/opcode, existing
  price, public gate or Fuel default/cap change. Next: fresh loop-carried owners,
  private safe casts, remaining bottom/general references, methods/AllocError and
  runtime/host/platform work. Full completion remains open. Local only.

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

The [actual Windows ABI bootstrap](abi-bootstrap.md) now supplies a real query
DLL/C-host boundary, compiled Fairy metadata/validation and canonical layouts.
This is an E01 prerequisite only: serialized owner-thread Engine/Instance state,
VM/step/reply/cancel/destroy exports and data lifetimes remain before full
embedding. The [real internal handle coordinator](abi-registry.md) now connects
the 64-slot Fairy kernel to OS identity/serialization; production-scale registry
accounting and actual object/pin/lifecycle ownership still remain. Keep CLI embed availability false until those paths
are implemented and evidenced. The bootstrap builder is self-contained in the
checkout and does not rebuild the whole CLI/VM.

The private [terminal-operand successor](value-terminal-operands.md) now closes
final Buffer/view operand composition while preserving real preceding effects,
loans and cleanup. Current scoped development evidence covers five new groups
and seven integrated regressions; all twelve final groups ran in release. Nonfinal
continuations require general unreachable checking; the full language/runtime,
host, isolation, embedding, platform and delivery work remains open.

The private [void-bottom successor](value-void-bottom.md) now accepts terminal
void-return operands without replaying cleanup or emitting an enclosing return.
Five new development groups on byte-identical worker inputs, four integrated
development regressions and nine integrated release groups passed. Other bottom
contexts/unreachable diagnostics and general cyclic ownership/references remain
open; this does not complete any wider inventory group.

The private [strict-widening source bridge](value-safe-casts.md) is implemented and
verified in both Windows native profiles. It reuses the existing 7/36 scalar-pair
matrix after unary/postfix and before binary evaluation, with left-to-right
chains and once-only effects. Terminal bottom checks scalar target syntax without
reading a value, emitting WIDEN or interning a cast type. This adds no implicit
conversion, VM/opcode, pricing or public admission change. The linked evidence
records this focused increment. [Fresh singleton loop owners](value-fresh-loop-owners.md)
now compose with real carrier cleanup and pinned-owner MOVE; continue conditional
fresh-root unions and remaining bottom/general reference composition, then the
existing methods/AllocError and runtime/host/platform work; the full objective
and the inventory completion conditions remain open.

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
   The [private owning Engine](runtime-engine.md) now retains real reusable
   Programs and one-shot Instances, checks OS owner/reentry/epochs, pins image/code
   backing, preserves terminal events and releases actual storage. Its
   [output successor](runtime-engine-outputs.md) retains exact output completions
   and moves immutable bytes once. Complete public
   association and policy/Program binding, complete accounting/preallocation, bounded
   resumable operations, deadlines, in-flight cancellation and poison containment.
   Preserve cleanup at zero guest Fuel and prove result/Fuel invariance across step
   sizes; synchronous `execute_once` does not meet the bounded step contract.
   The [canonical instruction cursor](runtime-instruction-quanta.md) now preserves
   PC/registers/static banks and the existing invocation state across internal
   batches. Its eleven new development/O2 groups prove equal dispatch visits,
   output, Fuel and original diagnostics at quanta 1, 2, 3, 7, 64 and 4096.
   The [owning continuation](runtime-pending-output.md) now stores its execution
   banks/frames/proof fields/input/scratch/output across actual caller returns;
   default-stack development/O2 pass eight new groups, including fixed/mixed
   quanta and no SDK allocation on resume. Next add quota-reserved pending slots
   to the real Engine Instance, keep its exact Program pin/input association and
   guard/epoch checks, then release charges on terminal/cancel/destruction once.
   Preserve the synchronous facade. Subsequently chunk setup, bulk helpers,
   CALL/RET, publication and cleanup. Full R03, R04 and R05 remain open.
   [Fixed control storage](runtime-engine-control-memory.md) now has a pre-allocation
   budget and count-sized reserved vectors. [Exact Program retention](runtime-engine-program-memory.md)
   now preflights actual source/IR/image backing and returns charges on final owner
   removal. The [Engine compile successor](runtime-engine-compile-memory.md) now
   reserves Index/incoming Entry plus lowering growth and exclusive persistent
   phases before incoming allocation. Next bind per-Instance frames/input/owners/
   loans/output, native stacks and remaining combined peaks.
   Tracked control/Program bytes must not be reported as total Engine memory.
4. **Useful byte/text workload: D01-D05, I01-I02.** Connect native Buffer owners
   and leases to guest move-only values, wrappers and Instance teardown. Expose
   bounded byte/text operations and actual guest input. The [private I/O owners](runtime-io.md)
   now snapshot input and stage explicitly sealed output with real native OOM
   rollback. [InputEntry](module-input-entry.md) owns exact shared-byte signatures;
   [owning input Programs](module-input-program.md) now lower and independently
   verify all bodies against original source/image provenance. The separate
   [input execution path](module-input-execution.md) now runs the exact Snapshot
   up to 1MiB with per-invocation windows, CALL/selected-origin returns and READ/LEN.
   [Owning Instances](runtime-engine-inputs.md) now bind that Program/Snapshot
   to actual OS input. [Guest output](module-output-execution.md) and its
   [Engine binding](runtime-engine-outputs.md) now connect verified emit, actual
   shared Fuel and success-only publication. Complete immutable policy/grants,
   accounting, bounded resumability, public controls and sinks. Deliver a useful
   user-facing input -> validation/transform -> output example.
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
map and its preserved requirements to complete executable admission. The [anchored collector](anchored-sources.md) and [owning Fairy adapter](anchored-source-loader.md) now acquire exact bounded source snapshots on Windows. Next connect project/Engine admission and public project CLI, then policy/grant integration.
The full completion objective remains open.

- Native element-list IR/VM execution is implemented at `873e71a`: opcode 80,
  dense 4096-register operand pool, complete canonical type/CFG/owner proof and
  ordinary/retained dispatch. Invocation-local typed/encoded scratch is prepared
  once before guest entry and reused through CALLs/loops; retained allocation
  precedes argument ownership changes. New setup/instruction prices are explicit;
  existing operation prices, default256/cap16000000 remain. Development/release
  each passed nine native groups on 163 Git-matching inputs, 156 LF modules and
  262-file discovery; both locked LF mirrors pass. See the array-list execution
  contract/evidence. Guest `[x,y]` syntax, source evaluation/exit cleanup, L03/C05,
  full Instance scratch/accounting/resumability and the full objective remain open.
  No public CLI/full matrices/Linux/OOM injection/general stack/timing/delivery
  rerun. No public element-list syntax flag is enabled by this native increment.
- Native array element-list storage/ownership is implemented at `4f94112`.
  Exact arity/layout/quota/owner preflight and complete codec staging precede
  backing/cursor/token publication. Caller-owned scratch is payload-sized, with
  no allocation in the new primitives. All six scalar domains and 4096 elements
  remain supported. Development/release each passed five native groups on 161
  Git-matching inputs, 154 LF modules and the 261-file discovery identity; both
  locked LF mirrors pass. See the array-list storage contract and Windows evidence.
  This is a native prerequisite: guest element-list syntax, independent IR proof,
  VM/Fuel integration, Instance scratch accounting and L03/full completion remain
  open. Public prices/default/cap are unchanged. No public CLI/full matrices,
  Linux, allocator fault injection, general stack/timing or delivery rerun.
- Public Fuel revalidation on the inference source baseline `624eac6` passed
  25 native groups and 33 tool-free CLI cases per Windows profile on 166 matching
  inputs, 154 LF modules and the 260-file discovery identity. Inputs match the
  checkout and Git raw bytes. Development started at `624eac6`; release started
  at the documentation-only successor `7c8f0f4`. Default 256, cap 16000000, operation
  prices and independent native host budgets remain unchanged. See the public
  Fuel contract and `docs/evidence/public-fuel-windows-20261106.json`. No full
  profiles, retained-source oracle suite, LF mirror, Linux or delivery rerun.
  Other language/runtime/host/delivery work and the full objective remain open.
- Payload-derived Option constructor inference is implemented at `92ca0d4`.
  `.some` infers existing i32/bool payloads once through the original constructor
  emitter; missing none/Result domains, wider/nested/resource payloads and broader
  branch context remain explicit limits. No type/opcode/Fuel/profile/cap changes.
  Development/release each passed five native groups and 25 tool-free CLI cases,
  on 161/158 paths (162-path union), 154 LF modules and 260-file discovery. All
  inputs match the commit's Git raw bytes; both locked LF mirrors pass. See the
  Option constructor contract and Windows evidence. Full L02/objective remains
  open, including general expressions, element lists and void/if. Local only.
- Reference/text local inference is implemented at `442f1f8`, with the scalar
  name-shadowing guard fix at `365ac5d`. Existing byte/text views, native loans,
  shared aliases, explicit exclusive reborrows and shared-byte results use the
  same initializers, origin/lifetime admission and cleanup. Default 256, cap 16000000
  and operation prices remain. Baseline development/release each passed 36 native
  groups and 32 CLI cases; release uses three disjoint 12-group shards (`ed10ad3`).
  The final one-file production guard fix passed one focused native group and 34
  CLI cases per profile on 160 matching final inputs, 154 LF modules and 259-file
  discovery, with both locked LF mirrors. Original 36 native groups remain
  historical at `442f1f8`; final CLI 34 reruns every original 32 fixture. See the
  reference-inference contract and both Windows evidence files. General views,
  tag constructors, element lists, void/if and the full goal remain open. Local only.
- Owned aggregate local inference is implemented at 6c7d94f: repeated scalar
  arrays, nominal constructors, bare copies, aggregate CALLs and exact local/
  returned record child paths share existing typed initializers and ownership.
  No active-lexer/IR mutation or guest evaluation during source-shape lookup.
  Development/release each passed 32 native groups and 24 CLI cases on 161/157
  inputs (162-path union), 153 LF modules and the same 257-file discovery. All
  inputs match Git raw bytes; both LF mirrors pass. See the aggregate-inference
  contract/evidence. Reference/text/tag constructor/general aggregate-expression
  inference, element lists, void/if and full L02/objective remain open. Local only.
- Local scalar/complete-tagged expression inference is implemented at 6edab73:
  let/var name=value keeps exact types, one-time initialization and existing
  scopes/IR/Fuel/limits. Development/release each passed 29 native groups and
  12 CLI cases on 159/155 inputs (160-path union), 151 LF modules and the same
  256-file discovery; both LF mirrors pass. All inputs match Git raw bytes.
  See docs/engineering/local-inference.md and its focused Windows evidence.
  Aggregate/borrow/text/constructor inference, void/if and full L02 stay open.
  Before void, separate result_type==0's pure-header sentinel from return types.
  Other runtime/reference/host/delivery work and the full goal remain open.
- Call capture lowering now defers its lexical Table snapshot until scalar and
  bare immutable-owner prefixes finish. Code 51437c1 fixes a reproduced retained
  compiler native stack overflow without depth/owner/IR/Fuel changes. Both
  development and release passed 28 groups on the same 158 Git-matching inputs,
  150 LF production modules and 255-file discovery; both locked LF mirrors pass.
  The final byte-identical boundary fixture overflows on baseline 3160751.
  See docs/engineering/native-call-capture-stack.md and focused Windows evidence.
  Real captures retain their old suffix/cleanup; general R02 stack/accounting,
  preallocation, full profiles and the complete objective remain open. Local only.
- Native project_program now owns the complete Project beside its admitted
  module Program. It independently rechecks exact map/header/entry agreement,
  preserves original diagnostics, runs with fresh VM state and denies nonempty
  requirements before guest/backing/Fuel work. No policy/grant API is implied.
  Code 83370c1 builds on typed Index/Program owners at 2e611f6. See
  docs/engineering/project-program.md and its focused Windows evidence.
  Final development passed 14 project/source groups and integrated release passed
  30 groups, on 155/157 matching input paths, 149 LF production modules and the
  same 254-file discovery. All final inputs match checkout and Git raw bytes;
  both locked LF mirrors pass. The earlier 16-group development retention
  foundation has a separate 253-file snapshot; do not reuse it as a final-input
  development run. Release explicitly covers all sixteen foundation identities.
  Original combined 16/17-file and legacy/reference 32/33-depth cases remain.
  No compiler/stack overrides or historical-result reuse. Diagnostics/enum-fixture
  failures are excluded. CLI/Fuel/full profiles/Linux/allocator-fault injection/
  general memory-stack timing/restricted/ABI/package were not rerun. Public
  default256/cap16000000 and existing operation prices remain. Next: anchored
  collection/project CLI plus grant integration, and independent remaining
  language completion. Stable SDK ordinary opens are not anchored filesystem
  proof; preserve the explicit OS-boundary work. Engine/Instance, general views,
  Buffer/input, worker, ABI and the complete objective remain open. Local only.
- Native project_sources now matches an explicit Project to exact sealed host
  snapshot identities irrespective of order, proves every canonical header and
  selects its named public zero-argument i32 entry. Original source spans and
  snapshot identities are preserved; >16 mapped files fail with Limit.
  Development/release each passed 26 native groups on 156 matching inputs; both
  locked LF mirrors pass. Owning Entry adaptation no longer duplicates its error
  domain; signature proof uses a small private result before publication. The
  combined 16/17-file case remains intact; no stack/compiler overrides. See
  docs/engineering/project-sources.md and its focused evidence. Diagnostic probes
  and the input-invalidated run are excluded. This is not filesystem proof, body
  admission, project CLI or grants; retain the caller Project authority.
- Native project_manifest now validates and owns brownie.project/0.3 metadata:
  all required/unknown/duplicate decoded fields, 32 source mappings, 256 declared
  requirements, canonical path collisions and entry-module membership. It grants
  nothing and opens no files. See docs/cli/project-format.md and schemas/project.schema.json.
  Development/release each passed 20 native groups on 154 matching inputs; locked
  LF mirrors pass. See docs/evidence/project-manifest-windows-20261105.json.
  Next bind exact source/header snapshots, then anchored collection and CLI.
  The full objective, policy/Engine/Instance/host/worker/ABI gates remain open.
  No CLI/full-profile/Linux/OOM or filesystem-race claim; local commits only.
- Native project input primitives now provide bounded UTF-8 JSON tokens and
  canonical project/module/function/capability/member spelling checks. This is
  lexical/name validation only, not a schema loader, filesystem collector, CLI
  project flag or grant. Development/release each passed 13 native groups on
  152 matching inputs, with locked LF mirrors. See docs/engineering/project-input.md
  and docs/evidence/project-input-windows-20261105.json.
- L01/C03 retained native module Programs now execute an explicitly selected public
  i32 entry with scoped function/nominal record/field/shared-byte lowering and
  complete independent IR/image/owner admission. Original source/name snapshots
  remain owned for source-local diagnostics. Code 65e0b5a and 7ab2eb8; see
  docs/engineering/module-program.md and focused Windows evidence.
  Development/release each passed 50 native groups (29 module/public/record/metadata
  +21 context/entry/function/lexer) on 157 matching verification inputs, 144 LF
  production modules and 249-file discovery; all locked LF mirrors pass. Of the
  inputs, 155 match Git raw bytes; unchanged lexer_compatibility and
  struct_call_assignment tests are CRLF locally/LF in Git, with both hashes and
  exact normalization recorded. No overrides or historical reuse. Diagnostic-only
  probes and earlier failed fixtures/runs are excluded. Combined record and
  scalar/retained 32-call cases remain; depth33 rejects. Empty-record preparation
  validates all unused metadata without the unused layout Plan. Ungrounded return
  origins/layout failures identify their actual declarations; quotas/global errors
  have no fabricated location. Verifier indices map through original byte offsets.
  Next: public project loading and CLI module/entry flags, then language completion.
  Native compiler output remains candidate scratch until admission. General mutable/
  non-byte/Buffer/input references, generic runtime-view equality, host lifetimes
  and the complete objective remain open. CLI/Fuel/full profiles/general RAM-stack/
  allocator/OOM/timing/Linux/restricted/ABI/package were not rerun. Public default
  256/cap16000000 and prices stay. Local commits only; no push.
- L01 source_context now copies exact source bytes and compact module/import/pub
  spans into compiler-only scratch. Fenced lexer State distinguishes qualified
  names (kind5) from plain binders (kind2), preserves each original BOM/comment/EOF
  and explicit text aliases. Native scoped function signatures and nominal record
  catalogs resolve exact module identities and reject private/cyclic invalid types.
  Code 959c8d3; see docs/engineering/source-context.md and focused Windows evidence.
  Development/release each passed 21 native groups (6 context + 6 entry + 4 function
  + 5 lexer), 150 matching verification inputs, 142 LF modules and 247-file discovery;
  both locked LF mirrors pass. All production inputs match Git; 149/150 total inputs
  match byte for byte. Unchanged tests/lexer_compatibility.fy is CRLF locally/LF in
  Git, with both hashes and exact normalization recorded. No overrides/historical
  reuse. Preliminary selection/SDK/test-marker errors and diagnostic cases excluded.
  Metadata is candidate scratch, not executable authority. Native execution must
  reconstruct it internally from the exact retained Index and complete source/IR/
  ownership proof. Next carry scope through expression/constructor/field/reference
  lowering and selected retained executable admission. Preserve local/field names
  and original spans. Intermediate EOF diagnostics must keep active file identity,
  not infer it from a flat boundary. CLI/public Fuel/full VM/profile/general RAM-
  stack/allocator/OOM/timing/Linux/restricted/ABI/package were not rerun. Public
  module flags/project loader remain unavailable. L01/C03/full goal stay open.
- L01/C03 native source snapshots now own exact source/name byte copies and
  checked original-byte spans. Copyable Builder scratch is independently proved
  before private Snapshot retention; failed appends leave both pools unchanged.
  IDs are local to the exact snapshot. Names are opaque host identities, not
  validated paths. Up to 16 files, 4096 source bytes, 4096 name bytes and 256-byte
  identities; no CLI/source/profile limit promotion. Code f7a67b5; see
  docs/engineering/module-sources.md and focused Windows evidence.
  Development/release each passed six native groups on 144 matching committed
  inputs, 139 LF modules and 244-file discovery; both locked LF mirrors pass.
  No overrides or historical reuse. CLI/full VM/profile, general RAM/stack/OOM/
  timing/Linux/restricted/ABI/package were not rerun. Next bind module headers,
  aliases, declarations/visibility and source-local resolution, then connect
  multi-module compilation/project entry. L01/C03 and the full objective remain
  open. No public module flag or project loader. Local only; no push.
- Public check/run now admits retained byte/text/shared-byte source, including
  single-origin results and selected temporary owners, under brownie.m2-reference/1.
  Native PublicProgram moves the whole sealed resource; CLI uses thin selected
  branches to keep inactive owning return slots off the native parser stack.
  Small-result lowering/signature phases preserve 32-deep source calls; 33/64
  reject with compile_limit on both paths instead of overflowing native stack.
  Code 63c8fb7; see docs/engineering/public-program.md and focused Windows evidence.
  Development/release each passed 18 native groups and 2112 tool-free CLI cases
  (33 Fuel, 72 retained/depth, 2007 M1), on 164 matching distinct committed inputs,
  138 LF modules and 243-file discovery. Both locked LF mirrors pass. No compiler/
  stack overrides or historical reuse; earlier fixture failures, stack probes and
  interrupted native runs excluded. Literal exact Fuel oracle is 344103; legacy
  scalar remains 2, default256/cap16000000 stay, and runtime prices are unchanged.
  Original public Fuel native selection/full M2/general RAM-stack/allocator/OOM/
  timing/Linux/restricted/ABI/package were not rerun. General mutable/non-byte/
  Buffer/input results, mixed runtime equality, host lifetimes and Engine/Instance
  integration remain open; array_slice_results/restricted/embed stay false.
  Continue the completion plan's language work and retain remaining B04/B05 gates.
  The complete objective stays open. Local commits only; no push.
- Shared byte source returns and result bindings now compile through private
  compiler::compile_reference_returns into the existing ReferenceReturnProgram.
  Source hints distinguish exact inputs/image origins; complete IR/canonical
  owner-lifetime proof independently authenticates them before retained admission.
  Only selected owned temporary arrays survive CALL. Temporary source views and
  unselected owners close promptly; hidden selected owners join cleanup before
  result endpoints/later arguments. Aliases/ranges/nested calls and nonlocal
  exits reuse existing finalizers. No runtime frame/table/price changes.
  Code 0173333; see docs/engineering/reference-return-source.md and focused evidence.
  Development/release each passed 18 native groups (8 new source returns, 8 result
  VM, 2 source CALL) and 33 tool-free CLI cases on 153 matching distinct committed
  inputs, 137 LF modules and 242-file discovery. Both locked LF mirrors pass.
  Source Fuel boundaries are measured; existing result VM numeric oracles remain.
  No overrides/historical reuse; earlier direct and rejected-fixture probes excluded.
  Ordinary public Program/CLI admission is next; mixed-backing text/non-byte and
  Buffer/input references, host-visible lifetimes and the complete objective stay
  open. Original public Fuel native/full profiles/general RAM-stack/allocator/
  timing/Linux/restricted/ABI/package were not rerun. Local only; no push.
- Shared byte CALL source now lowers through compiler::compile_references into
  the existing retained ReferenceProgram. One ref u8[] formal accepts image/text
  byte views and ordinary rooted/owned runtime loan actuals with explicit ref.
  PARAM77 placeholders retain logical positions; checked CALL maps use CALL78.
  Hidden view arguments join existing reverse lexical capture cleanup before
  later arguments/endpoint exits. Other loan/owned/record paths remain shared.
  Code 5f90245; see docs/engineering/reference-call-source.md and focused evidence.
  Development/release each passed 18 native groups (8 new source, 7 Static source
  binding, 3 mixed VM) and 33 tool-free CLI cases on 152 matching distinct committed
  inputs, 136 LF modules and 241-file discovery. Both locked LF mirrors pass.
  New source Fuel boundaries are measured, not independent numeric price oracles.
  No compiler/stack overrides or historical reuse; preliminary probes excluded.
  Existing runtime prices/public default256/cap16000000/frame/pool/word tables
  remain. Source returns/result bindings and ordinary public Program/CLI admission
  are next; mixed-backing text/non-byte and Buffer/input references remain open.
  Original public Fuel native/full profiles/general RAM-stack/allocator/timing/
  Linux/restricted/ABI/package were not rerun. Complete objective stays active.
  Local commits only; no push.
- Canonical generic byte results now execute private CALL/RETURN through a
  retained ReferenceReturnProgram, with exact image/runtime windows and existing
  full native tickets. Selected handoff succeeds before caller publication;
  aliases/ranges/forwarding preserve the selected window and last-alias lifetime.
  Complete RETURN metadata (512) plus native leave/handoff is prepaid before
  receipt authentication; returned lookup adds 64 and CLOSE metadata remains 128.
  Code 5911cfb; see docs/engineering/reference-return-vm.md and focused evidence.
  Development/release each passed 18 focused native groups, 25 public Fuel native
  groups and 33 tool-free CLI cases on 151 matching distinct committed inputs,
  135 LF modules and 240-file discovery. Both locked LF mirrors pass; no compiler/
  stack overrides or historical reuse. Earlier direct probes are excluded.
  Existing 32x16 u32 words remain 2048 logical bytes, with no extra dense ticket
  map, frame fields or pool reservation. Public prices/default256/cap16000000 stay.
  Source signatures/actuals/returns, ordinary public generic-result admission,
  text/non-byte/Buffer/input references and host-visible lifetimes remain open.
  Full profiles/general RAM-stack/allocator-OOM/timing/Linux/restricted/ABI/package
  are not covered. The complete objective stays active. Local only; no push.
- Native returned-byte receipt helpers now use existing u32 words and sparse
  47-slot Held storage. Returned selectors decode as 16..31; formal selectors
  stay 0..7. Ordinary locations 0..511, absent512 and universal1024..1535 stay
  disjoint. Same-numbered sites cannot select each other's full native ticket.
  Last-alias close prepays 128 metadata units; physical close remains prepaid by
  handoff. Failed final owner drop preserves word/receipt/native state. Frame
  retirement handles both namespaces only after native handoff/abort. No new
  decoded Word fields, dense ticket map, frame fields or pool reservation.
  Code ec27142; docs/engineering/reference-receipts.md records boundaries.
  Development/release each passed 18 native groups on 142 matching inputs,
  134 LF modules and 239-file discovery; both locked LF mirrors pass. No overrides/
  historical reuse; earlier rejected fixtures excluded. Old shared-byte formal
  VM and sparse writer nesting regressions pass. Public CLI/Fuel selections/full
  profiles/general RAM-stack/timing/Linux/restricted/ABI/package were not rerun.
  Next connect retained returned-reference Program and complete canonical generic
  CALL/RETURN transfer, selector/access Fuel and caller publication. Generic
  results remain unexecuted through IR/public admission. Source signatures/
  actuals/returns and the complete objective remain open. Local only; no push.
- Generic returned-byte recipes now combine complete scalar/owner/loan/CFG proof
  with local-owner dependency masks via verifier::inspect_reference_returns and
  distinct ReferenceReturnProof. Image actuals have no owner mask; runtime actuals
  remap local roots at each CALL; formals do not alias same-numbered recursive
  locals. Last-alias liveness rejects owner drop/write/fill/assignment/exclusive
  access while permitting original source-loan close and unrelated owner writes.
  Sixteen usize masks add 128 logical bytes to analysis on the 64-bit target;
  no runtime frame/pool/Program/Sites/price changes. Code 00dcedd.
  Development/release each passed 18 native groups on 140 matching inputs,
  133 LF modules and 238-file discovery; both locked LF mirrors pass. No overrides
  or historical reuse; earlier eight-group core probe excluded. See
  docs/engineering/reference-return-lifetimes.md. Generic results are still not
  executable: old canonical/retained/public gates reject result kind 3. Next native
  selected handoff/publication/last-alias close with exact windows and receipt
  namespaces, then source signatures/actuals/returns and ordinary public admission.
  Public CLI/Fuel selections/full profiles/general RAM-stack/timing/Linux/
  restricted/ABI/package were not rerun. Full objective stays active; local only.
- Shared byte return recipes now reconstruct kind-3 results through actual
  PARAM/CALL/ALIAS/RANGE/RETURN and exact image/input/local origins. Rootless shared
  byte inputs map to their logical formal. Symbolic local origin 10 can describe
  caller temporaries but cannot satisfy any declared function result. Runtime
  actuals contribute no image roots and are never indexed as actual-192.
  Code 969456a; docs/engineering/reference-return-ir.md records scope and next work.
  Windows development/release each passed 18 native groups on 139 matching inputs,
  132 LF modules and 237-file discovery; both locked LF mirrors pass. No overrides/
  historical reuse. Earlier fixture errors/unsupported interpreter probe excluded.
  This is recipe analysis, not complete canonical returned-loan lifetime proof or
  native generic-result execution. Existing canonical/retained/public admission
  still rejects result kind 3. Next implement canonical owner/drop/write lifetime
  proof, native selected handoff and last-alias close, then source/public lowering.
  Public CLI/Fuel selections/full profiles/general RAM-stack/timing/Linux/
  restricted/ABI/package were not rerun. Full objective remains active; local only.
- Shared byte kind-3 formals now execute private canonical CALL/PARAM through a
  retained ReferenceProgram. Image/runtime words preserve exact selected windows
  and logical formal indices, with full tickets in existing native Call receipts.
  Runtime actuals are captured once; alias/range/close shares transaction-owned
  input without extra pool leases. The 32x16 u32 table stays 2048 logical bytes;
  no second dense ticket map. Complete Fuel precedes entry/publication and existing
  prepaid abort drains failures. Code d9f1929; word/window prerequisite 87cfba1.
  Windows development/release each passed 18 native groups and 33 tool-free CLI
  cases on 141 native/144 CLI matching paths, 150 distinct committed inputs,
  132 LF modules and 236-file discovery; both locked LF mirrors pass. No compiler/
  stack overrides or historical reuse; earlier probes/fixture rejection excluded.
  Native public Fuel original selection/full profiles/general RAM-stack/timing/
  Linux/restricted/ABI/package were not rerun. See docs/engineering/reference-vm.md.
  Next connect generic reference results, source signatures/actuals/returns and
  public admission. Equality for kind 3, text/non-byte references and Buffer/input
  backing remain open. The complete objective stays active. Local only; no push.
- Shared byte formal kind 3 now has separate recipe and canonical analysis via
  verifier::inspect_reference_calls and a distinct ReferenceCallProof. One IR
  signature accepts image/universal sites or live shared runtime u8[] actuals;
  logical prefixes, eight actuals, alias/range kind and transitive origins remain.
  Runtime actuals require canonical caller liveness, exact byte/shared mode and
  rooted owner or rootless formal ancestry. Scalar/owned/text coercion rejects.
  Kind 3 is formal-only; equality/results/native VM transfer/source lowering stay
  open. Existing Static retain/verify and public admission keep rejecting it.
  Code 68826d4; docs/engineering/reference-formals.md records the next native
  CALL/PARAM/receipt step. No new Program/proof layout, descriptor table, opcode,
  price, public flag or ABI. Keep the complete objective active.
  Windows development/release each passed 18 native groups (8 new, 8 admission,
  2 existing Static VM) and 33 tool-free CLI cases. Native 137/CLI 142 paths match;
  146 distinct committed inputs, 130 LF modules and 233-file discovery. Both
  locked LF mirrors pass; no overrides/historical reuse. Earlier probes excluded.
  Original public Fuel native/full profiles/general RAM-stack/allocator/timing/
  Linux/restricted/ABI/package checks were not rerun. Local only; no push/release.
- Instruction-local byte READ/LEN now share reference_access across immutable
  image sites and runtime u8[] loan tickets. Canonical tags reject mixed storage;
  frame/image spans and full runtime ticket/root/lease validation remain required.
  Access prices remain image 17/16 and runtime 4131/4097, plus one existing private
  dispatch unit. Compatibility Static READ shares checked bounds; non-byte loans
  keep their existing adapter. No payload copy, ownership mutation or public flag.
  Development/release each passed 18 focused native groups and 33 tool-free CLI
  cases on 139 native/142 CLI matching inputs, 148 distinct committed inputs,
  130 LF modules and 232-file discovery; both locked LF mirrors pass. Code 648d4bd.
  No overrides/historical reuse; earlier rejected-fixture/superseded probes are
  excluded. Full profiles/original public Fuel native/general RAM-stack/timing/
  Linux/restricted/ABI/package checks were not rerun. See
  docs/engineering/reference-access.md and focused Windows evidence. Next unify
  guest reference formals and source CALL/return lowering, then public/lifetime
  APIs; the complete objective remains open. Local only, no push/release/deploy.
- Mixed Static CALL coverage now directly executes record arguments, shared/
  exclusive runtime loans and owned array/record results through canonical
  adapters. Five examples plus kind-confusion rejection pass three groups per
  Windows development/release profile on 134 matching inputs, 129 unchanged LF
  production modules and a 231-file discovery identity. Exact/one-short budgets
  here are measured, not independent price oracles. No overrides/historical reuse.
  Fixtures replace an unused scalar marker with a private Static formal; no
  source signature, opcode, runtime price or public capability changes. CLI/full
  profiles/general memory/timing/Linux/restricted/ABI/package were not rerun.
  See docs/engineering/static-call-transfer.md and mixed-call evidence. Next unify
  byte reference access across backing kinds, then source/formal/lifetime paths.
- Native Static PARAM 77/CALL 78/RETURN 79 now execute through the existing
  canonical coordinator, borrowing body/origin tables without another IR wrapper.
  Private CallProgram retains a completely proved code/image snapshot; legacy
  Program/bare admission stays gated and external entry/results stay scalar-only.
  Actual word/kind/span transfer, including packed-zero empty views, never reads
  Static formals as scalar cells or broadens to proof root unions. Complete Fuel
  precedes child publication; native leave succeeds before caller publication.
  Existing owner/loan transactions and prepaid zero-Fuel abort remain shared.
  PARAM costs 17 including dispatch; CALL adds 32+32*N metadata (0..8 actuals)
  plus existing dispatch/arity/copy/native entry; Static RETURN adds 49 including
  dispatch plus native leave. Existing prices/default256/cap16000000 remain.
  The 32x16 u32 word table remains 2048 logical bytes; no image payload is copied.
  Development/release each passed 24 native groups (8 transfer/VM, 9 ranges,
  7 scalar-entry) on 136 matching native inputs and 33 tool-free public Fuel CLI
  cases on 141 matching CLI inputs. All 129 production modules are LF; locked
  mirrors pass; test discovery is 230 files. No overrides or historical reuse.
  Exact/one-short/one-more zero-backing examples, literal/text/byte/empty returns,
  eight actuals/scalar prefixes, recursive spans, frame-limit abort, retained
  immutability and owned array argument copies/drop pass. Earlier checker/native
  probes are excluded. New mixed-Static record/loan arguments and aggregate
  results reuse canonical adapters but have no new mixed runtime fixture here.
  Full profiles/original public Fuel native/general stack/RAM/allocator/timing/
  Linux/restricted/ABI/package checks were not rerun. Code a1b555a; metadata-only
  predecessor 39f4688. Next complete mixed runtime coverage and storage-independent
  reference/source CALL integration, then ordinary public and returned-image
  lifetime APIs. The complete inventory/goal remains open. See
  docs/engineering/static-call-transfer.md and focused Windows evidence.
- Private Static CALL analysis now combines reconstructed PARAM/CALL/RETURN
  recipes and grounded origins with canonical scalar/array/record/loan proof.
  Static type-zero formals never become scalar cells or destinations; Static
  returns cannot leak ordinary owned state. Bounded possible-root sets support
  different literal windows at different calls; byte spans stay in one real root
  and text keeps an exact validated window. This is copyable analysis metadata,
  not retained image/frame authority or executable/public admission. PARAM 77
  remains rejected by the legacy Static executor; source CALL lowering is open.
  Development/release each passed 38 native groups (8 new, 30 regressions) on
  136 matching final inputs and a 229-file discovery identity. All 128 production
  modules are LF; locked LF mirrors pass. Public Fuel CLI-only phases each pass
  33 tool-free cases on 140 matching CLI inputs; default 256/cap 16000000 remain.
  No compiler/stack overrides or historical-result reuse. The earlier 37/38
  development run, superseded release run and diagnostic probes are excluded;
  the loan fixture now uses required explicit ref syntax. Original public Fuel
  native/full profiles/general stack/RAM/allocator/timing/Linux/restricted/C ABI/
  package checks were not rerun. Code 1dff6a1. Next connect actual frame/image
  transfer to canonical VM execution with full Fuel/destination preflight,
  actual-span preservation, ordinary owner/loan cleanup and zero-Fuel abort.
  Source/public promotion and the complete inventory remain open. See
  docs/engineering/static-call-admission.md and focused Windows evidence.
- Static CALL recipe proof now reconstructs actual PARAM 77/CALL 78/RETURN 79
  signatures, globally unique view sites, CFG liveness and grounded logical-input
  or Static origins. Type-zero formals are view placeholders; encoded actuals
  are never scalar cells. BYTES/ALIAS/RANGE preserve lineage; calls remap exact
  logical positions, including scalar prefixes. Every return agrees; conflicting
  origins and ungrounded recursive cycles reject. Parameter preludes cannot be
  replayed by jumps. This is recipe proof only: complete scalar/owner/loan
  admission, actual frame/image receipt transfer, source CALL lowering and public
  promotion remain open. Current bare/retained execution rejects the new opcodes.
  Development/release each passed 17 native groups (11 new, 6 retained-Program)
  on 133 matching inputs and a 228-file discovery identity. All 127 production
  modules are LF; locked LF mirrors pass. No overrides or historical reuse.
  Earlier checker/native and fifteen-group probes are excluded. CLI/full profiles/
  general stack/RAM/allocator/timing/Linux/restricted/C ABI/package checks were
  not run. Code a6a62d5. Next integrate complete image-aware admission, then
  canonical transfer with actual spans and prepaid Fuel; a formal must support
  different image windows at different calls and text must retain validated
  boundaries. Keep the complete goal active. See docs/engineering/static-call-ir.md
  and focused Windows evidence.
- Native compile_image now lowers computed immutable byte ranges from literals,
  named/ref/parenthesized views and text::bytes. Omitted endpoints use usize zero
  and actual parent LEN; nested ranges, scalar projections and equality reuse
  independently proved RANGE 76. Hidden owned parents join lexical cleanup before
  endpoints. Owned equality left arguments remain retained through every right
  endpoint return/propagation/break/continue. Named bindings remain live and pending
  result names are not visible in their own initializer. Member dots/nested reads
  do not become range delimiters; endpoint expressions evaluate left to right
  before RANGE validates bounds. All prices/capacities/public gates remain.
  Development/release each passed 32 native groups (11 new, 21 existing) and 88
  tool-free CLI cases on 140 matching final inputs and a 227-file discovery
  identity. All 126 production modules are LF; locked LF mirrors pass. No native
  overrides or historical reuse. Early probes, including a corrected invalid
  narrowing in the Fuel fixture, are excluded. Full profiles/general stack/RAM/
  allocator/timing/Linux/restricted/C ABI/package checks were not run. Code commit
  9b97263. Next connect Static CALL/return origin/lifetime receipts, then ordinary
  public admission. Dynamic runtime/Buffer/input views and the complete inventory
  remain open. See docs/engineering/static-range-source.md and focused evidence.
- Private Static RANGE (76) now independently proves byte source/liveness and
  defined non-slot usize endpoints, retaining maximum proof windows plus dynamic
  alias flags. Canonical dispatch uses actual per-frame words for all Static
  operations: 32x16 u32 descriptors add 2048 logical bytes, separate from live
  bits. Nested ranges cannot re-expand; closing a parent preserves descendants.
  Fuel 128 including dispatch is prepaid before endpoint checks/publication;
  shortage and invalid endpoints publish no word/register changes. Existing
  prices, public default 256/cap 16000000 and all capacities remain.
  Development/release each passed 35 focused native groups (9 new, 26 existing)
  on 133 matching inputs and a 226-file discovery identity. All 126 production
  modules are LF and locked LF mirrors pass; no native overrides or historical
  reuse. Early core probes are excluded. CLI/full profiles/general stack/RAM/
  allocator/timing/Linux/restricted/C ABI/package checks were not run. Next lower
  computed source endpoints with cleanup on all exits, then Static CALL/return
  origins and retained receipts. Public promotion and the complete inventory
  remain open. See docs/engineering/static-range-execution.md and evidence.
- static_views now prepares packed frame-local byte ranges against admitted
  image windows, function/kind and separate liveness. Thirteen-bit start/length
  fields fit u32; 32x16 descriptors require 2048 bytes. Packing is bounded to
  26 iterations per pack with the pinned SDK; decoding does not repack the actual
  word; inspection separately validates the maximum window through pack. Empty
  ranges are allowed, byte windows cannot broaden, text retains its exact
  validated window and raw bytes cannot coerce to text. Check bounds before
  arithmetic; metadata failures are IR 5, guest relative endpoint failures are
  Bounds 14. Words alone do not own/pin/authenticate image authority.
  This is metadata preparation only: no opcode, driver/source or public change.
  Development/release each passed 7 focused native groups on 131 matching inputs
  and a 225-file discovery identity, including proof from a real retained source
  Program. All 126 production modules are LF and locked LF mirrors pass; no
  overrides or historical reuse. CLI/full profiles/general stack/RAM/allocator/
  timing/Linux/restricted/C ABI/package checks were not run. Next add independently
  proved dynamic range IR and actual frame span execution, then computed source
  endpoints and their exit cleanup. Keep the full goal active. See
  docs/engineering/static-view-ranges.md and focused Windows evidence.
- Native compile_image now lowers text::equal over exactly two immutable byte
  views: literals, named/explicit-ref/parenthesized views and explicit text::bytes
  conversion. Text and runtime mutable/owner-backed views are not coerced into
  image sites. EQUAL emits a fresh bool and closes only owned argument temporaries
  in reverse order, preserving named view liveness. Both current arguments are
  pure immutable view construction; future effectful right arguments must retain
  the left temporary through every exit before being admitted.
  Existing image/CFG/type proof, prices, source/site/register limits and public
  gates remain. EQUAL costs 17 plus both entire selected byte lengths, even on
  immediate mismatch. Complete one-byte/three-byte-unequal/empty source examples
  cost 58/62/56 plus entry/leave reserves and run with zero guest backing.
  Development/release each passed 21 native groups (5 new, 16 regressions) and
  88 tool-free CLI cases on 138 matching inputs and a 224-file discovery identity.
  All 125 production modules are LF and locked LF mirrors pass; no native override
  or historical reuse. Full profiles/general stack/RAM/allocator/timing/Linux/
  restrictions/C ABI/package checks were not run. General runtime/range views,
  dynamic input/Buffer equality, Static CALL/return receipts and ordinary public
  admission remain open; keep the complete goal active. See
  docs/engineering/static-equality-source.md and focused Windows evidence.
- Native compile_image now lowers typed Static ref u8[]/ref str locals,
  same-kind aliases and explicit text::bytes projections over retained images.
  Compiler-only encodings 192..223 never become scalar cells or owner tickets.
  Lexical block/value-arm/return/propagation/break/continue cleanup includes
  Static views; aggregate returns reuse the per-binding finalizer while keeping
  their returned owner. Owned projected views enter hidden cleanup before index
  effects; simple length projections avoid the hidden local/table snapshot.
  Byte/text kind separation, immutable access, independent CFG proof and all
  existing capacities/prices remain. A one-byte binding+alias costs 57 plus
  entry/leave reserves, retains one byte at quota 577 and runs at zero backing.
  Development/release each passed 16 native groups (7 new, 9 regressions) and
  88 tool-free CLI cases on 137 matching inputs and a 223-file discovery identity.
  All 125 production files are LF and locked LF mirrors pass; no native override
  or historical reuse. Full profiles/general stack/RAM/allocator/timing/Linux/
  restricted/C ABI/package evidence was not run. Source text::equal/general view
  expressions, Static CALL/return receipts and ordinary public admission remain
  next; the complete objective stays active. See docs/engineering/static-bindings.md
  and its focused Windows evidence.
- Retained-image compilation now preserves text::valid_utf8 dispatch after
  speculative text::bytes lookahead. Plain text bindings, prices and limits are
  unchanged. The exact fixture fails at 58c6b92; development/release each pass
  one native group with three source executions and owner/loan teardown checks.
  See docs/engineering/image-text-dispatch.md and focused Windows evidence.
  Static local/alias/ref str lowering remains next; the complete goal stays open.
- Private Static ALIAS (75) now preserves exact immutable byte/text kind,
  image range and function while keeping source/destination independently live.
  Closing the source preserves its aliases. No payload allocation/copy or new
  runtime state is introduced; exact cost is 17 including dispatch, preflighted
  before destination publication. All definitions share the existing 16-site cap.
  Independent proof rejects invalid operands, foreign/closed sources and kind
  coercion. The builder derives allocation from actual retained instructions.
  Windows development/release each passed 32 focused native groups on 131 matching
  inputs and a 221-file discovery identity. All 124 production files are LF;
  locked LF mirrors pass. Current public Fuel CLI phases each passed 33 tool-free
  cases on 136 matching CLI inputs: default 256, explicit cap 16000000 unchanged.
  No native overrides/historical reuse. Public Fuel native/full-profile/Linux/
  restricted/ABI/packaging and general stack/RAM/allocator/timing were not rerun.
  Typed Static local/alias syntax, ref str, general view expressions and Static
  CALL/return origins remain next; public promotion and the complete inventory
  stay open. See docs/engineering/static-alias.md and its Windows evidence.
- Native compiler::compile_image now collects bounded source literals into a
  staged kind-specific builder, lowers immediate byte reads/lengths and explicit
  text-literal text::bytes projections, freezes exact used payload and retains
  independently proved code/image together. Whole-collection errors preserve
  the caller's builder; raw-span index metadata remains compiler scratch.
  Dynamic usize indices/CALLs and loop reentry use the existing canonical VM,
  with zero guest array backing for these expressions. One-byte source execution
  costs 39 plus unchanged entry/leave reserves; exact image charge is 577.
  Public compile/origin-analysis and returned-reference declaration gates remain.
  Static definitions and source occurrences each retain the 16-entry bound.
  Speculative for-post rollback now zeros discarded instruction bytes before
  scalar body emission can inherit OPEN range bytes; a classic-for regression
  verifies replay. Metadata-only site allocation follows actual retained code.
  Windows development/release each passed 32 focused native groups (eight new)
  and 88 tool-free CLI cases on 134 matching final inputs and a 221-file test
  discovery identity. All 124 production files are LF; locked LF mirrors pass.
  No overrides/historical reuse. Pre-correction passes and the intentionally
  stopped older release native run are excluded from final evidence.
  Full profiles/general stack/RAM/allocator/timing/Linux/restricted/C ABI/package
  evidence remains open. Typed Static locals/aliases/ref str, general byte-view
  expressions/text::equal arguments, Static CALL/return receipts and public
  admission are next; the complete objective remains active. See
  docs/engineering/literal-compiler.md and its focused Windows evidence.
- Private image EQUAL now admits live immutable byte/text operands, including
  mixed backing kinds, without coercing bytes to text. Actual-image kind/range,
  function/definition/liveness and bool destination proof remain mandatory;
  READ/LEN stay byte-only and BYTES text-only. Unknown native kind tags reject.
  Pricing is unchanged: 17 plus both complete selected byte lengths, with no
  new allocation/backing copy and no result publication on insufficient Fuel.
  Windows development/release each passed 27 focused native groups (five new)
  on 129 matching inputs and a 220-file discovery identity; all 122 production
  files are LF and locked LF mirrors pass. No overrides/historical reuse.
  Full profiles/CLI/general stack/RAM/allocator/timing/Linux/restricted/C ABI
  were not run. Source literals/types, explicit text::bytes and byte-view
  text::equal argument checking, Static CALL/return receipts and public admission
  remain open; the complete objective is active. Next connect compiler-owned
  literal collection and real source lowering to retained images. See
  docs/engineering/static-byte-equality.md and its focused Windows evidence.
- Bounded literal_source decoding now emits byte/text lexer kinds 3/4 with raw
  spans and unchanged lexer State. Shared escapes plus text-only Unicode scalars
  are checked before complete cooked UTF-8 acceptance. Compiler scratch stays
  outside token snapshots; production intern decodes fully before kind-specific
  immutable-image insertion and preserves the builder on Source/Image failures.
  Raw source-byte policies, 4096 source/scratch and 1024 tokens remain unchanged.
  Public expression/ref str lowering and capability promotion remain gated.
  Development/release each passed 25 native groups (8 new) plus 88 tool-free CLI
  cases: 52 literal diagnostics/gates and 36 existing lexical cases. All 132 inputs
  and the 220-file discovery digest match; 122 LF production modules and locked LF
  mirrors pass. Final runs use no overrides/historical reuse; early CLI and the
  failed development fixture probe are excluded. Full profiles/Linux/restricted/
  C ABI/packaging and general stack/RAM/timing/allocator evidence remain open.
  Next connect compiler-owned literal collection, typed Static locals and
  text::bytes. The accepted text::equal takes byte views; extend private EQUAL's
  text-only proof before lowering that signature. Static CALL/return receipts,
  public admission and the complete goal remain open. See
  docs/engineering/literal-source.md and its focused Windows evidence.
- Retained-image Static execution now admits and runs private operations 69-74
  through the existing canonical driver, tied to the exact immutable Program
  image. Independent image/ordinary CFG/type/owner/loan/origin proof precedes
  native transfers; separate frame words track Static aliases. CALL_BIND opaque
  identities cannot be read by Static indexing. Bare ordinary verifier/VM and
  public guest syntax/capability promotion remain gated. Prices include dispatch:
  OPEN/BYTES/LEN 17, CLOSE 1, READ 18, EQUAL 17 plus both byte lengths.
  Native stack reproductions required borrowed IR/runtime field reads, staged
  field publication, separate return-map validation and wrapper-owned compiler
  lowering scratch. Existing APIs, rollback, cleanup order and guest limits/prices
  are preserved; combined fixtures were not split. No general stack bound follows.
  Development/release each passed 59 focused native groups plus 33 tool-free
  public Fuel CLI cases on 133 matching native inputs and a 219-file discovery
  digest. All 121 production files are LF; locked LF mirrors pass. Final counted
  runs use no overrides or historical reuse. Earlier probes/generated-C diagnostics,
  including a diagnostic larger-stack run, are excluded. Full profiles/Linux/
  restricted/ABI/packaging and allocator/OOM/general stack/RAM/timing remain open.
  Next add bounded literal token/escape decoding and guest text bindings, then
  Static CALL/return origin receipts and public result admission. The complete
  objective remains active. See docs/engineering/static-execution.md and its
  focused Windows evidence. Earlier entries retain their checkpoint scope.
# AGENTS.md

- Private Static IR preparation now reconstructs actual image definitions and
  exact kinds/ranges/UTF-8 boundaries in src/static_ir.fy. The image-aware ordinary
  verifier reuses complete metadata/scalar/owner/loan proof and a separate Static
  live-state plane for branch joins/backedges; all 64 existing owner/loan bits are
  already allocated. Six private opcodes 69-74 prepare open/close/read/length/
  equality/text-bytes views. Sites are image-local analysis metadata, not pinned
  storage or authenticated handles. Normal returns require closed Static sites.
  Ordinary/public verifier, retained Program admission and VM still reject them;
  no guest syntax, pricing, capacity or capability change is claimed.
  Windows development/release each passed 31 focused native groups (eight new)
  on 129 matching final inputs and a 218-file discovery digest. All 120 production
  files are LF and locked LF mirrors pass; no native overrides/historical reuse.
  Early fixture-checker corrections and the pre-snapshot eight-group probe are
  excluded. Standalone CLI/full profiles/Linux/restricted/ABI/packaging and native
  stack/RAM/timing/allocator evidence were not run. Next connect retained Program
  admission with actual Static dispatch, exact Fuel and image-backed lifetimes,
  then CALL/return origins and guest text syntax. The full objective remains open.
  See docs/engineering/static-ir.md and its focused Windows evidence.
- Active objective: complete every accepted missing implementation item in
  docs/product/04-remaining-work.md. Do not redefine completion around the
  experimental subset. Execution order and next B04 constraints are recorded in
  docs/engineering/completion-plan.md. Remote delivery remains separate.
- The default Windows combined quota/empty-image Program fixture now passes.
  src/slice_result_runtime.fy leave_call borrows nested authority/pool/table before
  private staging and publishes three fields only after every fallible operation.
  This avoids large native intermediate Runtime values, retaining rollback,
  first errors, cleanup order, 32 frames, Program API and all guest prices.
  Development/release each passed 13 focused native groups on 125 matching inputs
  and a 217-file discovery digest; 119 production files are LF and LF mirrors pass.
  The baseline at 16aea0c fails with byte-identical fixture input; no overrides or
  historical reuse. Diagnostic /Od emitted frame drops 263544 -> 58152 bytes;
  this is not total/release stack, RAM, allocator or timing evidence. Packed IR/
  resource-replacement prototypes were discarded. General R02 containment and
  Static/Engine/public integration remain open. See native-return-stack.md under
  docs/engineering and its Windows evidence. Keep the full objective active.
- Native Program retention now owns independently verified copyable IR and the
  move-only literal image together in src/program_image.fy. Private fields/shared
  getters preserve immutable snapshots; scalar native execution borrows the owner
  and reuses existing admission/Fuel/cleanup. Image ownership moves on all outcomes.
  Development/release each passed 20 native groups on 126 matching final inputs,
  with a 217-file discovery digest and 119 LF production files; LF mirror checks
  passed without native overrides/result reuse. Earlier probes are excluded.
  No Static opcode/origin/returned receipt, guest literal syntax, Engine handles,
  Instance pinning, global accounting or public promotion is implemented yet.
  Next prove real Static definitions against this image and connect VM lifetimes;
  keep the complete objective active. See docs/engineering/retained-program-image.md
  and its Windows evidence. Whole-profile/CLI/Linux/ABI/allocator/stack/RAM/timing
  checks were not run; no native stack-safety claim follows from fixture splitting.
- Static literal backing now has a private move-only native Image in
  src/static_image.fy. Compiler scratch interns exact byte/text kinds, bounds
  rows/bytes and validates UTF-8 before mutation. Freezing independently validates
  metadata/text, preflights retained bytes and owns an exact used-prefix copy.
  Resource fields are private; no mutable image API exists. Shared byte/text
  ranges and equality require the live owning image; spans are image-local
  offsets, not authenticated Program handles. Logical charge is 576 plus payload
  capacity; whole Engine/Program/scratch accounting is not implemented here.
  Development/release each passed six native groups on 122 matching final inputs
  and a 216-file discovery digest; all 118 production files are LF and an LF
  mirror passed check --locked. Final runs follow final capture; no native
  overrides/historical reuse. Earlier field-slicing/resource-privacy/Result-equality
  probes and pre-snapshot results are excluded. At this storage checkpoint, Program
  retention and Static IR/authority/VM lifetime were open; the successor above now
  supplies native Program ownership. Guest literals and public promotion remain open; this
  actual owning-storage prerequisite does not complete B04/D05 or the objective.
  No old VM/CLI/full-profile/Linux/restricted/ABI/packaging/allocator OOM or native
  timing/stack/RAM evidence was produced. Next integrate a retained Program image
  alongside copyable proof IR, independently prove static definitions/origins,
  then connect views and source with exact metering. See
  docs/engineering/static-literal-image.md and its focused Windows evidence.
- B04 declaration and terminal-return ranges over retained CALL results now
  execute privately. Parse exact-usize endpoints in order with hidden result/
  ancestry live; declarations finish delimiters before child acquisition and
  publish one user binding. Ranged returns use a post-CALL snapshot and existing
  PREPARE_VIEW/handoff cleanup, preserving real returned-relative bounds and
  consuming Helds once. A bounded lexer snapshot keeps bare PREPARE_FORWARD
  unchanged. Rooted temporary backing is local; independent origin proof rejects
  its escape. No opcode, cost, capability or public limit change.
  Windows development passed 14 native groups and release eight on 125 matching
  final inputs and a 215-file discovery digest. All 117 production files are LF;
  an LF mirror passed check --locked. All counted groups ran after final capture;
  no native overrides or historical reuse. Earlier probes corrected unsupported
  bool-switch and root-shape-versus-selected-length fixture assumptions and are
  excluded. Native external results prove actual bounds, exact/one-short Fuel,
  zero-Fuel close, double-close/stale rejection and invocation drain. Standalone
  CLI/full profiles/Linux/restricted/ABI/packaging/allocator/performance were not
  run. Next: actual Static backing, general references and public result admission.
  The complete objective remains open. See
  docs/engineering/m2-slice-result-range-projections.md and its Windows evidence.
- B04 direct returned CALL actuals now lower and execute privately, including
  argument ranges, temporary literal/owned CALL backing and all six scalar/access
  modes. Publish hidden selected ancestry before later arguments/endpoints;
  shared chains retain every anonymous parent/owner transitively, while exclusive
  anonymous BEGIN/BIND_RESULT chains collapse to the surviving lexical/root view.
  Unselected captures close before installing the outer result. Ordinary scalar/
  array/record CALLs retain reverse cleanup. Recursive advisory source hints now
  follow selected nested actuals; independent definitions/CFG/origins/loans remain
  mandatory. No opcode, operation price, public capability or CLI limit changed.
  Windows development passed 37 native groups and release 15 on 126 matching final
  inputs and a 214-file discovery digest; all 117 production files are LF and an
  LF mirror passed check --locked. No compiler/stack overrides or result reuse.
  All counted groups ran after the final snapshot; the earlier seven-group probe
  is excluded. Standalone CLI/full profiles/Linux/restricted/ABI/packaging/
  allocator/performance were not run. Next: reference-valued declaration/return
  ranges, Static backing and ordinary public result admission. The complete
  objective remains open. See docs/engineering/m2-slice-result-arguments.md and
  its focused Windows evidence. Earlier entries retain their historical scope.
- B04 private caller END chains now consume multiple existing BEGIN/BIND_RESULT
  ancestors per actual atomically before installing the selected returned child.
  Independent proof checks each real definition/parent, exact formal mask,
  complete reverse acquisition order and surviving selected anchor. Native
  captures carry a bounded proved count; consumed Helds are retired once and
  fresh parents bind at final anchors. Single-END/native host behavior remains.
  Coupled caller+callee children share the 31-entry stack, keeping the existing
  handoff/cleanup Fuel allowances; bounded recipe/receipt scans fit staging.
  Windows development passed 15 native groups; release passed 5 on 123 matching
  final inputs and a 213-file discovery digest. All 117 production files are LF;
  an LF mirror passed check --locked. No stack/compiler overrides or result reuse.
  Final groups ran after the snapshot; exploratory semantic/early native results
  are excluded. Standalone CLI/full-profile/Linux/restricted/ABI/packaging/
  allocator/performance were not run. Next connect direct returned actuals,
  transitive selected ownership, source origin recursion and reference ranges.
  See docs/engineering/m2-slice-result-capture-chains.md, especially its next
  source bridge requirements. Public admission/Static/general references and
  the complete objective remain open; do not mark them complete from this slice.
- B04 immediate scalar projections now execute in the private returned-view
  coordinator: returned CALL indexing for all six scalar/access modes, actual
  range length and u8 UTF-8 inspection. A separate post-CALL lexical snapshot
  retains the returned Held and selected anonymous parent/owner through computed
  indices and exits; successful scalar materialization immediately closes them.
  Existing reverse cleanup handles return/?/break/continue; named writers receive
  fresh parents before the next expression. No opcode/price/capability promotion.
  Windows development passed 14 native groups (5 new and 9 affected regressions);
  release passed 6 (5 new plus existing owned UTF-8 CALL). All 124 inputs and the
  212-file discovery digest match; all 117 production files are LF and an LF
  mirror passed check --locked. No compiler/stack overrides or historical reuse.
  The first fresh 5-group run completed before its raw snapshot; no input edits
  intervened. Subsequent selections require that exact snapshot. Standalone CLI,
  full profiles/Linux/restricted/ABI/packaging/allocator/performance were not run.
  Next: direct returned CALL arguments/reference-valued range projections, Static
  backing and public admission. General references and the full objective remain
  open. See docs/engineering/m2-slice-result-projections.md and its Windows evidence.
- Public Fuel reconciliation now deliberately raises the explicit CLI ceiling
  from 1000000 to 16000000; default 256 and operation prices are preserved.
  Shared/exclusive rooted/formal/canonical/legacy slice dispatch and CALL pricing
  use the common fuel module, including BEGIN/END/CLOSE. Version JSON exposes
  fuel_default/fuel_limit from that same module. Native host budgets remain
  independent. An eight-writer CALL alone reserves 1114129 before dispatch,
  arguments, OPENs and backing, so the old ceiling could not run it.
  Windows development and release each passed 25 focused native groups and 33
  tool-free CLI cases. All 129 inputs and the 211-file test-tree digest match;
  all 117 production files are LF and an LF mirror passed check --locked.
  Exact/one-short operation/source budgets, six-scalar/UTF-8/cleanup regressions,
  old/new cap boundaries, overflow/duplicate usage and four existing record
  stress programs are covered without compiler/stack overrides or result reuse.
  Full M1/M2/Linux/restricted/ABI/packaging/performance were not run. Other C05
  capacities, B04 public result admission and the complete objective remain open.
  See docs/engineering/public-fuel-limits.md and its focused Windows evidence.
  Earlier entries retain their original schedules, ceilings and evidence scope.
- B04 lexical returned CALLs now execute in the private canonical VM: exact
  caller destinations, funded END masks, fresh resumed parent mapping, retained
  Held and prepaid close. Source-selected temporary parents/owners have actual
  lexical lifetimes; nested/recursive returns consume transferred receipts once.
  Native owned entry can return a bound subview and close it at zero Fuel.
  Windows development passed 25 native groups (7 new, 9 IR/admission, 9 old VM);
  release passed 8 (7 new plus native-input preservation). All 123 inputs and the
  210-file test-tree digest match; all 117 production files are LF and an LF mirror
  passed check --locked. No stack/compiler overrides or historical-result reuse.
  Constructor scratch in the raw-input fixture is separate from the VM call.
  Standalone CLI/full-profile/Linux/delivery/performance were not run.
  Simple new programs fit 1000000 native Fuel; complex cases use explicit larger
  budgets. C05 must reconcile public budgets before promotion. Public result
  compile/ordinary Program/capability gates stay in place. Next: direct returned
  CALL arguments/projections, Static backing and public admission/dispatch. Keep
  the full objective active; earlier entries retain their original scope. See
  docs/engineering/m2-slice-result-call-execution.md and its focused evidence.
- B04 typed lexical CALL-result source lowering is connected for all six scalar
  types/access modes. Source hints select construction candidates; independent
  IR proof still checks them. Selected temporary literals/owned CALL results keep
  their parent/owner names through result cleanup; unselected captures release
  normally. Anonymous exclusive ranges emit exact END masks. Scalar CALL tables
  remain shared; no recursive lexical-table copy was added.
  Windows development passed 18 native groups and release six new groups on 123
  matching inputs, with all 209 test-discovery files fingerprinted. All 117
  production modules are LF and an LF mirror passed check --locked. No native
  overrides/result reuse. Semantic execution is unsupported by UTF-8 primitives;
  standalone CLI/full-profile/Linux/delivery/performance were not run.
  VM binding dispatch remains gated. Next route native destinations/masks, remap
  resumed tickets to surviving parents, retain/close Held and verify exact Fuel,
  traps and temporary owners. Keep the full objective active. See
  docs/engineering/m2-slice-result-call-source.md and its focused Windows evidence.
- B04 private CALL-binding IR now proves exact destinations, selected input origins,
  anonymous exclusive END masks, whole-program CFG/loans and opaque scalar IDs.
  Definition tracing rejects fabricated recursive grounding. Source lowering and
  binding execution remain pending; VM entry rejects 66-68 before ownership transfer.
  Windows development passed 26 native groups; release passed nine new groups.
  All 122 inputs match Git LF and all 208 test-discovery files have a recorded
  aggregate identity. Final selections were re-executed after regression-fixture
  LF normalization. An LF mirror passed check --locked; no overrides/reuse.
  Standalone CLI/full-profile/Linux/delivery/performance were not run.
  See docs/engineering/m2-slice-result-call-ir.md and its focused Windows evidence.
  Next connect source recipes and retained Held dispatch; keep the full objective
  active. Earlier origin-hint/retained-binding entries describe their prior scope.
- B04 source origin hints now have a separate advisory pass and signature column.
  It handles lexical aliases, reordered inputs and grounded recursion, resets old
  hints and rejects ungrounded cycles. Three interpreter and three development
  native groups passed on 119 matching compilation inputs. It is not connected
  to source lowering/admission yet. Next build the CALL/binding recipe and have
  independent origin proof trace its definitions, not flattened claimed metadata.
  See docs/engineering/m2-slice-source-origins.md. No public promotion; the full
  objective and remaining B04/language/runtime/delivery work remain active.
- Native caller frames can now retain returned Held receipts in slice sites,
  continue, and publish fresh parent tickets on prepaid close. A sparse 47-entry
  map supports same-slot exclusive descendants; seventeen live native receipts
  across two frames use one physical writer slot in the new test. Successful
  terminal handoff consumes callee records; ordinary returns reject live Helds.
  Windows development passed 43 native groups and 217 CLI cases; release passed
  five new binding native groups. All 509 captured inputs match and all 114
  production sources are LF; an LF mirror passed `check --locked`. No result
  reuse or stack/compiler overrides. Other/full M1/M2/Linux/isolation/ABI/
  allocator/performance checks were not run. Source/new executable IR result
  bindings and public capabilities remain gated. Next connect independently
  proved source/IR destinations and selected temporary capture retention; this
  native foundation does not complete B04 or the active objective. See
  docs/engineering/m2-slice-result-bindings.md and its linked Windows evidence.
- L03 record field shorthand now supports `.field` for exact scalar/plain-record
  locals through existing ordered constructor staging. Windows final LF inputs
  passed 21 development and four release native groups, plus 362 tool-free CLI
  cases per profile, on 507 matching inputs. See the shorthand contract/evidence.
  Array element-list initialization remains open; public returned results remain
  gated. Other native/full-profile/platform/delivery/performance suites were not
  rerun for this increment.
- Preserve LF when writing production sources before refreshing `fairy.lock`.
  The Fairy source digest includes raw source bytes: a mixed CRLF workspace made
  its lock stale in a Git LF checkout. Sources and the lock are now consistent;
  a separate LF mirror passed `check --locked`. Write Python source edits with
  `newline='\n'` or bytes. Do not reuse pre-normalization input receipts as current.
- Ordinary scalar entry now shares the canonical returned-view VM through
  `vm::run_slice_scalar`: exact scalar admission, fresh resumed inputs, native
  value-copy arguments and transactional reverse-order capture cleanup. The
  default Windows stack overflow in the exploratory descendant/anonymous paths
  is fixed by borrowing entry snapshots and reading authority by reference.
  Windows development passed 63 native groups and 217 tool-free CLI cases on
  505 matching inputs, without stack/compiler overrides or native result reuse.
  Release/full M1/other M2/Linux/isolation/ABI/allocator/performance were not run.
  Public returned-result declarations/bindings remain gated. Next: lexical result
  destinations, Held retention and fresh parent restoration, then independent
  public admission/dispatch. See docs/engineering/m2-slice-scalar-entry.md and
  docs/evidence/m2-slice-scalar-entry-windows-20261104.json.
- L07 lexical compatibility is implemented at `5bb055b`: leading BOM, LF/CRLF,
  rejection of misplaced BOM/lone CR/raw NUL, nested block comments and raw spans.
  Direct return ranges are implemented at `9737710` in the private returned-view
  dialect: open/empty/dynamic/relative ranges, exact six-scalar modes and ordered
  endpoints use existing site proof and handoff. No new opcode or public flag.
  Source-owned roots still cannot escape; ordinary public declarations stay gated.
  Windows development passed 27 native groups (four range, eight origin, six Fuel,
  nine execution), five lexer interpreter groups and 244 tool-free CLI cases
  (36 lexical, 88 origin gate, 120 temporary borrows). All 319 captured compilation
  input hashes were rechecked and all 113 production files match `9737710` under
  Git LF. Native run started at `5bb055b` with the final range inputs; no result
  reuse. The full VM cannot execute in the semantic interpreter because UTF-8
  byte-slice operations need the native backend. Release/Linux/full M1/M2/
  isolation/ABI/allocator/performance were not run in this increment.
  Next: B04 lexical result destinations, Held retention/fresh parent restoration,
  ordinary scalar entry/return, independent CFG/lifetime proof and public execution.
  Native registry alone is not B04 completion; keep the full objective active.
  See docs/evidence/returned-ranges-lexical-windows-20261104.json.

Earlier entries below retain their original implementation/evidence scopes.


- Returned-view Fuel accounting is implemented at `275abfd`. The shared
  `fuel` module owns CLI default/cap and slice value/UTF-8 prices. Private
  returned-view entry is 147456, borrowed handoff 294912 and ordinary return
  196608, plus dispatch/arity and existing aggregate-copy/result charges. These
  replace the provisional 80*65537 reserve. Entry prepays emergency abort;
  handoff prepays linear Held.close, which now preserves supplied remaining Fuel
  and works at zero. Each cleanup reserve is 65536; none is refunded. Native
  handoff/ordinary-return callers use handoff_cost()/leave_cost(); cost() is entry
  only. Lower-level native ownership transactions meter metadata; their VM
  callers prepay aggregate-copy work separately, once. First-error/prior-write,
  initial-failure preservation and post-entry invocation-drain contracts remain.
  Native APIs retain explicit host Fuel budgets; the unchanged 256 default and
  1000000 cap belong to CLI arguments. Public result syntax/flags stay gated.
  Final Windows development/release each passed 56 native groups and 217 CLI
  cases (208 regressions plus nine CLI Fuel boundaries), with 500 matching input
  hashes and all 112 production sources matching `275abfd` under Git LF. All
  native batches began at c455e54 with those same final inputs; their actual
  starting heads are retained. CLI runs began after the implementation commit.
  No changed-input/historical native result reuse. Exact/one-short Fuel, zero-Fuel
  close, full 16-owner/16-view/31-authority limits, nested forwarding and owned
  entry within 1000000 are covered. Full M1/other M2/Linux/isolation/ABI/packaging/
  allocator/native size-stack/timing were not verified. Next: B04 general result
  bindings/lowering and ordinary public Program admission/dispatch proof, before
  public capability promotion. Local only; no push/release/deployment. See the
  [schedule](docs/engineering/m2-slice-result-fuel.md) and
  [Windows evidence](docs/evidence/m2-slice-result-fuel-windows-20261104.json).

Earlier entries below retain their named implementation and verification scopes.

- Explicit native owned entry is implemented at `8bf37de`. The private
  `vm::run_slice_result_owned` accepts formal-indexed array/record owner tokens
  alongside scalar cells and borrowed captures. It prepays the existing aggregate
  CALL work and stages authority plus all value copies in one initial transaction.
  Copied formals bind into the existing frame/record registry; ordinary CALL,
  owned return and borrowed handoff cleanup reuse their existing paths. Value
  copying does not consume source tokens; borrowed Capture drop flags still apply.
  Admission/initial-entry failure preserves native owners/pool/payload. Execution
  failure after entry drains originals and copies at zero Fuel, preserving prior
  writes and the first error. Revalidate native input tokens after any error.
  Legacy `run_slice_result` stays scalar/borrowed-only. No public syntax, capability,
  Program-layout, price or public Fuel-cap changes; the private reserve is unchanged.
  Final Windows development/release each passed 30 native groups and 208 CLI cases
  on 497 matching input hashes. All 111 production files match `8bf37de`
  under Git LF. Development's seven-group entry batch began before the commit with
  identical final inputs; original batch HEADs are retained. Fresh native batches
  resume only with matching input/compiler/report hashes; no historical result reuse.
  Full M1/other M2/Linux/isolation/ABI/packaging/allocator/native size-stack/timing
  were not verified. Next: reconcile public metering, then general returned-view
  source bindings/admission. Local only; no push/release/deployment. See the
  [contract](docs/engineering/m2-slice-result-entry.md) and
  [Windows evidence](docs/evidence/m2-slice-result-entry-windows-20261104.json).

Earlier entries below retain their named implementation and verification scopes.

- Private record CALL and local ownership are implemented at `e01a9b1`, following
  shared record byte-view adapters at `bcd56f4`. The returned-view VM executes
  record create/copy/read/write/drop/assign/subassign/replace/subreplace and
  ordinary mixed scalar/array/record arguments/results. `enter_records` stages
  borrowed authority and the complete aggregate-copy batch together. SRET moves
  the sole validated owner token without payload copying. Proved terminal SDROP
  defers to the same atomic handoff as array/loan cleanup.
  The private registry retains sixteen exact-generation tokens/locations rather
  than a permanent 512-token record map. Frame initialization follows independent
  admission. Early dense-map native stack failures are superseded; final tests
  use no stack/compiler overrides and no result reuse.
  Final Windows development/release each passed 58 native groups and 506 CLI
  cases, with 494 matching input hashes and all 110 production files matching
  `e01a9b1` under Git LF. Both final profiles start at that implementation commit;
  native phase/CLI continuation inputs match. Full M1/other M2/Linux/
  isolation/ABI/packaging/allocator/native size-stack/timing were not verified.
  Native owned entry inputs, public metering and general result source bindings
  remain pending; public syntax/flags/Fuel stay unchanged. Local only; no push,
  release or deployment. See the [contract](docs/engineering/m2-slice-result-record-vm.md)
  and [Windows evidence](docs/evidence/m2-slice-result-record-vm-windows-20261104.json).

Earlier entries below retain their named implementation and verification scopes.

- Private owned-array and ordinary scalar/array CALL integration is implemented
  at `5cccbd3`, following native restoration/root cleanup at `9be6c7e`.
  `vm::run_slice_result` now runs owned locals, temporary repeated-array/owned
  CALL-result borrows, value argument copies, ordinary returns and token-moving
  ARET. Raw byte-view adapters reuse the existing public array VM semantics.
  `enter_arrays` stages borrowed authority and owned copies in one transaction;
  do not clone the full Runtime around it (that overflowed native dev stacks).
  Formal CLOSE is logical until Call restoration. Proved terminal CLOSE/END/DROP
  defer to atomic handoff_roots; failed cleanup preserves original metadata.
  Failures drain invocation state at zero Fuel, preserving first errors/writes.
  Final Windows development/release each passed 33 native groups and 2,215 CLI
  cases with 489 matching inputs, no final result reuse, and all 108 production
  sources matching `5cccbd3` under Git LF. Development started before the commit
  with identical final inputs; its original HEAD is retained. Full native M1/
  other M2/Linux/isolation/ABI/packaging/allocator/native size-stack/timing were
  not verified. Local only; no push/release/deployment.
  Next: record CALL and native owned entry inputs, public metering, then B04
  result source bindings/admission. Public syntax/flags/Fuel stay unchanged.
  See the [contract](docs/engineering/m2-slice-result-owned-vm.md) and
  [Windows evidence](docs/evidence/m2-slice-result-owned-vm-windows-20261104.json).

Earlier entries below describe their named implementation commits.

- Private returned-view VM bindings/dispatch are implemented at `e183e7a` and
  `d468ca1`; the existing scalar parser stack regression is fixed at `af4aa13`.
  `vm::run_slice_result` independently admits rootless borrowed inputs and executes
  63/64/65 with separate result identities, bounded frames, canonical loans,
  forwarding and transaction-owned terminal cleanup. A native Held receipt escapes
  only after successful handoff; parents stay suspended through descendants.
  After initial enter, failures drain invocation metadata at zero Fuel while
  preserving the first error and prior writes. Initial admission failure preserves
  input ownership. Guest-owned temporary roots and ordinary CALLs stay gated.
  Private reserve remains 80*65537; do not promote public syntax/flags/Fuel yet.
  Final Windows development/release each passed 11 native groups and 2,215 CLI
  cases, with 485 matching inputs and no final native result reuse. All production
  sources match `af4aa13` under Git LF. Pre-fix checks are superseded; final profiles
  rerun after the parser fix. Full native M1/other M2/Linux/isolation/ABI/packaging/
  allocator/native size-stack-usage/timing were not verified. Local only; no push.
  Next: mixed owned-local/ordinary CALL capture integration and public metering,
  then B04 source bindings/admission. See the
  [contract](docs/engineering/m2-slice-result-vm.md) and
  [Windows evidence](docs/evidence/m2-slice-result-vm-windows-20261104.json).

- Private returned-view native handoff/capture lifetimes are implemented at
  `7f8f455`, with anonymous mutable capture restoration at `b82500d`.
  `slice_result_runtime` uses invocation-owned canonical authority, pool
  and owner metadata; actual payload bytes are external and never copied by its
  transactions. Contract derives selected formal/type/access from checked private
  IR. Atomic handoff transfers shared tickets in place or installs a caller-frame
  exclusive child, cleans unselected captures and retains a selected temporary
  root until result close. Exclusive parents stay suspended through descendants;
  nested forwarding invalidates consumed inner receipts. Anonymous mutable range
  captures END caller reborrows in reverse argument order before result creation;
  independently opened views CLOSE instead. Returned/resumed bindings restore
  named parents, using the post-cleanup canonical result depth. Failure preserves live
  metadata and earlier writes; abort uses prepaid cleanup at zero execution Fuel.
  Private admission cost is 80*65537; public prices/Fuel/capabilities are unchanged.
  No guest returned-view IR executes. Next: private result destination/frame/site
  bindings and op63/64/65 dispatch, including routing existing capture/callee-local
  cleanup through this transaction. Do not promote public syntax/flags yet.
  See [the contract](docs/engineering/m2-slice-result-runtime.md).
  Final Windows development/release each passed 12 native groups and 208 CLI cases,
  with 479 matching inputs and no final result reuse. All 103 prior source
  files match `ba1a62a`. Development started before the fix commit with the same
  final inputs; original HEAD and skips are explicit. Full native/M1/other M2/
  Linux/isolation/ABI/packaging/allocator/native size-stack/timing were not verified.
  See [Windows evidence](docs/evidence/m2-slice-result-runtime-windows-20261104.json).



- Private returned-view preparation IR and independent proof are implemented at
  `670a041`. `compiler::inspect_slice_result_ir` returns a separate non-executable
  unit, with exact scalar/access and selected-input metadata. Private 63/64/65
  markers preserve preparation/forward/return identity; ordinary Program layout,
  VM opcode admission, prices, profiles and flags are unchanged. The independent
  verifier reconstructs CFG/live-loan/origin facts and permits only cleanup before
  the paired return. This is B01 preparation only, not an escaping-result lifetime
  proof. Next: atomic runtime destination/ticket handoff and selected actual
  capture/owner retention with exclusive-parent suspension (B02/B03).
  Windows development/release each passed 10 native groups and 208 CLI cases,
  with 476 matching inputs and retained hashes rechecked. Final runs reuse no
  results and use the LF-normalized root lock; the adopted SDK is unchanged.
  Full native/M1/other M2/Linux/isolation/ABI/packaging/allocator/native size-stack/
  timing and actual returned-reference execution were not verified. Local only.
  See [the contract](docs/engineering/m2-slice-result-ir.md).
  See [Windows evidence](docs/evidence/m2-slice-result-ir-windows-20261104.json).

- Private scalar-slice body-origin analysis is implemented at `0d1a8cb`.
  `compiler::inspect_slice_results` returns one-based formal input summaries only.
  An internal length/CALL proxy Program reuses source and independent CFG/type/
  loan proof; no Program or runtime ticket escapes this entry point. Exact formal
  anchors, reordered forwarding, lexical subviews and grounded recursion resolve
  in at most 17 monotone passes. Conflicting, local/temporary/by-value origins and
  ungrounded cycles reject; every emitted return is checked conservatively.
  Public compilation and actual returned-reference execution remain gated.
  Windows development/release each passed 12 native groups and 990 CLI cases,
  with 462 matching final inputs and retained identities rechecked. Development
  native checks precede a CLI-only fixture-count correction; CLI results precede
  an ignored verifier serialization fix. Exact original inputs/reuse are recorded;
  release reruns all selected checks. Two production paths differ from `45e74f3`;
  99 old sources match under Git LF. VM layouts/opcodes/prices/capabilities stay.
  Next is returned-view IR/result handoff proof and selected-capture retention.
  Full native/M1/other M2/Linux/isolation/packaging/allocator/native size-stack/
  timing and actual returned-reference execution were not verified. Local only;
  no push/release/deployment. See the
  [contract](docs/engineering/m2-slice-result-origins.md) and
  [Windows evidence](docs/evidence/m2-slice-result-origins-windows-20261103.json).

- Private scalar-slice result signatures are implemented at `1ced18e`.
  `functions::scan` records exact scalar/access metadata and an eight-bit upper
  bound of compatible input positions. Candidates are not a body-origin or
  lifetime proof. Public compilation rejects every borrowed-result declaration
  before IR/result preparation, including unreachable functions. No returned
  borrow executes; VM layouts, prices, profiles and public capabilities stay
  unchanged. Windows development/release each passed 12 native groups and 902
  tool-free CLI cases, with 459 matching final inputs and retained identities
  rechecked. Two production paths differ from `d0924f8`; 98 match under Git LF.
  Next is independent single-origin body proof, then result/capture handoff.
  Full native/M1/other M2/Linux/isolation/packaging/allocator/native size-stack/
  timing and actual returned-reference execution were not verified. Local only;
  no push/release/deployment. See the
  [contract](docs/engineering/m2-slice-result-signatures.md) and
  [Windows evidence](docs/evidence/m2-slice-result-signatures-windows-20261103.json).

- Call-scoped temporary-array borrows are implemented at `8983737`.
  Explicit `ref [value; N]` and `ref mut make()[lo..hi]` accept repeated literals
  and owned array CALL results, with whole/open/empty ranges and exact six-scalar
  modes. The hidden owner is published after initialization/CALL and before
  endpoints; OPEN follows endpoint evaluation. Reverse capture cleanup closes
  the view before DROP on normal return and lexical exits. Runtime failure drains
  canonical sessions and preserves errors/prior writes; initialized native
  failure payload may remain until invocation disposal. No second borrow owner,
  payload copy, runtime layout, opcode, price, Fuel or profile change. Version
  JSON adds `array_slice_temporary_arguments: true`. Windows development/release
  each passed 16 native groups and 812 tool-free CLI cases, with 457 matching
  final inputs and retained identities rechecked. Three production paths differ
  from `cbb9c41`; 97 others match under Git LF. Six prior test modules now reject
  wrong temporary element types instead of rejecting every temporary root.
  Parenthesized roots, repeated slicing, coercions and returned/escaping borrows
  remain unsupported. Full native/M1/other M2/Linux/isolation/packaging/allocator/
  native size-stack/timing were not rerun. Local only; no push/release/deployment.
  See the [contract](docs/engineering/m2-temporary-array-borrow-arguments.md) and
  [Windows evidence](docs/evidence/m2-temporary-array-borrow-arguments-windows-20261103.json).

- Call-scoped named-slice range arguments are implemented at `b8ab0eb`.
  Exact-mode `ref part[lo..hi]` / `ref mut part[lo..hi]` support six scalar types,
  owned/formal/derived parents, relative open/empty ranges and aggregate results.
  Endpoints complete before acquisition; readonly children reuse SUBSLICE/CLOSE,
  mutable children reuse BEGIN/END and canonical derived CALLs. CALL restores the
  anonymous child before capture cleanup resumes its named parent. Existing
  early-exit/error cleanup preserves original errors and earlier writes. The
  source-only descriptor gains a parent discriminator; runtime layouts, prices,
  opcodes and payload-copy behavior are unchanged. Version JSON adds
  `array_slice_named_range_arguments: true`. Windows development/release each
  passed 12 native groups and 854 tool-free CLI cases, with 454 matching final
  inputs and retained identities rechecked. Three production paths differ from
  `4b6ab2c`; 97 others match under Git LF. The new mutable admission fixture uses
  public execution while legacy gates remain. Temporary roots, repeated slicing,
  mode coercions and escaping/returned borrows remain unsupported. Full native/
  M1/other M2/Linux/isolation/packaging/allocator/native size-stack/timing were not
  rerun. Local only; no push, release or deployment. See the
  [contract](docs/engineering/m2-named-slice-range-arguments.md) and
  [Windows evidence](docs/evidence/m2-named-slice-range-arguments-windows-20261103.json).

- Call-scoped owned-array range arguments are implemented at `749f9bf`.
  `ref array[lo..hi]` / `ref mut array[lo..hi]`, open-ended and empty ranges
  evaluate usize endpoints once in order before OPEN and anonymous publication.
  The source-only capture descriptor owns no runtime ticket. Endpoint/later
  argument exits and runtime failures reuse existing cleanup; prior writes and
  original errors survive. Six scalar types and aggregate results work. Exclusion
  remains per owned root, including disjoint mutable ranges. Version JSON adds
  `array_slice_array_range_arguments: true`. Windows development/release each
  passed 11 native groups and 752 tool-free CLI cases, with all 451 final input
  hashes matching and retained identities rechecked. Three production paths
  differ from `e51b0ed`; 97 others match under Git LF. No runtime layout, opcode,
  price or payload-copy change. Named-slice ranges, temporary roots, mode coercions
  and returned/escaping borrows remain unsupported. Full native/M1/other M2/Linux/
  isolation/packaging/allocator/native size-stack/timing were not rerun. Local only;
  no push, release or deployment. See the
  [contract](docs/engineering/m2-array-borrow-range-arguments.md) and
  [Windows evidence](docs/evidence/m2-array-borrow-range-arguments-windows-20261103.json).

- Call-scoped whole-array borrows are implemented at `528934b`. Explicit
  `ref array` / `ref mut array` open anonymous handles during argument evaluation,
  before later arguments. Existing mixed capture cleanup closes them after CALL
  or on argument-time lexical exits; invocation cleanup drains runtime failures.
  Six scalar types, exact modes, duplicate readers, independent writers, nested
  calls and scalar/array/record results work. One temporary adds a static slice
  site/local, two registers and four existing instructions, without a payload
  copy or array owner. Version JSON adds `array_slice_array_arguments: true`.
  Windows development/release each passed 11 native groups and 644 tool-free CLI
  cases, with 448 matching final inputs and rechecked retained hashes. Development
  native results are reused after a readonly CLI expected-value-list correction;
  its original inputs/command are recorded. Three production paths differ from
  `04ab3ef`; 97 others match under Git LF. Inline ranges, temporary roots, mode
  coercions and returned/escaping borrows remain unsupported. Full native/M1/
  other M2/Linux/isolation/packaging/allocator/native size-stack/timing were not
  rerun. Local only; no push, release or deployment. See the
  [contract](docs/engineering/m2-array-borrow-arguments.md) and
  [Windows evidence](docs/evidence/m2-array-borrow-arguments-windows-20261103.json).

- Derived mutable CALL record results are implemented at `e8105f6`. Strict
  zero-slot/zero-generation record destinations precede loan staging and owned
  copying. Unchanged canonical SRET validates the exact-nominal unique result,
  restores the child and moves its existing token, without a second persistent
  result extent or payload snapshot. Six scalar field types, nested records,
  owned/shared/multiple-writer arguments, forwarding, recursion and assignment
  are supported. Version JSON adds `array_slice_reborrow_record_results: true`.
  Windows development/release each passed 20 native groups and 282 tool-free CLI
  cases (50 record result, 44 array result, 46 owned argument, 68 lexical reborrow,
  74 mutable parameter), with 445 matching final inputs and rechecked retained
  hashes. Development native results are reused after a CLI-only harness change;
  original native inputs and that reuse are recorded. Three production paths
  differ from `f8642ea`; 97 others match under Git LF. Full native/M1/other M2/
  Linux/isolation/packaging/allocator/native size-stack/timing were not rerun.
  Local only; no push, release or deployment. See the
  [contract](docs/engineering/m2-slice-reborrow-record-results.md) and
  [Windows evidence](docs/evidence/m2-derived-record-result-windows-20261103.json).

Earlier entries record their named commits; superseded gates are historical.

- Derived mutable CALL array results are implemented at `56842b9`. Complete
  prepayment precedes a strict zero-slot/zero-generation caller destination
  check, then existing loan/owned admission. Unchanged canonical ARET validates
  the result, restores the child and moves its unique owner token; no second
  result extent or payload copy. Existing prices/layouts/grammar/profiles remain;
  version JSON adds `array_slice_reborrow_array_results: true`. Record results
  remain gated for derived CALLs, including unreachable functions. Development/
  release each passed 13 native groups and 232 tool-free CLI cases; all 443 input
  hashes match and retained artifact/receipt hashes were rechecked. Three
  production paths differ from `7980328`; 97 others match under Git LF. Full
  native/M1/other M2/Linux/isolation/packaging/allocator/native size-stack/timing
  were not rerun. Local only; no push. See the
  [contract](docs/engineering/m2-slice-reborrow-array-results.md) and
  [Windows evidence](docs/evidence/m2-derived-array-result-windows-20261103.json).

- Derived mutable CALLs with owned arguments are implemented at `c9f2294`.
  Loan preparation precedes existing atomic array/record copying, then only
  infallible authority, ticket, origin and scalar/control publication follows.
  The old readonly-backing `enter` rejects owned arguments; `enter_owned` is the
  canonical mutable entry. Existing charge includes copying once. No persistent
  layout, price or source-grammar change; version JSON adds
  `array_slice_reborrow_owned_arguments: true`. Derived aggregate results remain
  gated, including unreachable functions. Development/release each passed 16
  native groups and 188 CLI cases; all 441 input hashes match and artifact/receipt
  hashes were rechecked. Five production paths differ from `80c5b9e`; 95 others
  match under Git LF. Evidence includes the final test-only unused-helper fix.
  Full native/M1/other M2/Linux/isolation/packaging/allocator/native size-stack/
  timing were not rerun. Local only; no push. See the
  [contract](docs/engineering/m2-slice-reborrow-owned-calls.md) and
  [Windows evidence](docs/evidence/m2-derived-owned-call-windows-20261103.json).

- Lexical mutable reborrow source is implemented at `3a07820`. Exact-mode
  `let ref mut Tag[] child = ref mut parent[lo..hi]` uses existing op61/62;
  bare/open-ended ranges and nested owned/formal children work. All lexical
  exits and owned array/record result cleanup end children before closing parents.
  Independent public proof rejects suspended-parent access and unsupported derived
  CALL shapes before effects. Source snapshots and runtime layouts are unchanged;
  cleanup finds each parent in at most 256 emitted instructions. Version JSON adds
  `array_slice_mutable_reborrow: true`; CLI Fuel remains capped at 1M.
  Development/release each passed 9 native groups and 2,615 CLI cases including
  68 new cases and full M1. All 438 input hashes match across profiles; retained
  artifact hashes were rechecked;
  94 other production sources match `101e36e` under Git LF normalization.
  Full native/other M2/Linux/isolation/packaging/allocator/native size-stack/timing
  were not rerun. Local only; no push. See the
  [source contract](docs/engineering/m2-slice-reborrow-source.md) and
  [Windows evidence](docs/evidence/m2-slice-reborrow-source-windows-20261103.json).

- Public IR reborrow admission and execution: implemented at `409d77c` on `main`
  after shared-guard preparation `42a66e9`. `verifier::verify_sites` returns the
  exact proved `Sites` before public quota, preparation Fuel, backing or local
  authority effects. Nonempty sites and exclusive formals route to canonical core
  without a second whole-program proof or forest reconstruction; owned-only opcode
  61/62 programs route without a formal. Public IR 61/62 are admitted and executed.
  Source grammar/parser/compiler and CLI capabilities remain gated. Derived CALLs
  accept borrowed/scalar arguments and scalar results only; owned arguments and
  aggregate results reject before effects, including in unreachable functions.
  Strict `inspect` and raw legacy execution keep separate gates. Prices, bounds,
  layouts and external-bytecode prohibition are unchanged. Development passed 8
  core groups; release passed 19 (8 core, 6 boundary, 5 proof), with 74
  mutable-parameter CLI cases per profile. All 404 current inputs match; 94 of 99
  production sources are unchanged against `e952162`, with five paths differing.
  Final core reruns passed after overlapping native/public test helper context
  lifetimes were split. The development core input differs only in unselected
  `slice_formal_reborrow_vm` Fuel, raised from 1M to 16M to reach the frame boundary
  and exercised by release boundary tests. No stack-size measurement was made.
  Full native/other M2/M1/Linux/isolation/packaging/allocator/timing were not
  rerun. Local only; no push. See the
  [contract](docs/engineering/m2-slice-public-reborrow.md) and
  [verified evidence](docs/evidence/m2-slice-public-reborrow-windows-20261103.json).

- Public canonical routing for exclusive mutable formals: implemented at `0d57882`
  on `main`. Development and release each passed 5 native groups (2 new legacy
  differential and 3 existing public mutable) plus 74 public mutable CLI cases.
  All 403 current inputs exactly match across both phase manifests; compiler,
  native-report, retained CLI artifact and CLI receipt hashes were rechecked. The
  sole production delta is `src/vm.fy` versus `a023542`; 97 other production
  sources match under Git LF. The public entry body and verifier-before-Fuel/quota/
  backing/selection are unchanged; exclusive formals use local canonical state and
  two maps with no second proof or new grammar/opcode/capability. Public opcode
  61/62 admission and source grammar remain gated while native execution remains
  available. See [contract](docs/engineering/m2-slice-public-canonical.md) and
  [verified evidence](docs/evidence/m2-slice-public-canonical-windows-20261103.json).
  Full native/other M2/full M1/Linux/isolation/packaging/allocator/native size-stack/
  timing and performance were not rerun. Local commits only; no push.

- Default checked native derived CALL admission: implemented at `2a30fae`.
  Default `inspect` reuses the former `inspect_derived` body after LF normalization; `execute`/`run` keep their bodies. Compatibility names delegate without a second proof.
  Owned/aggregate derived shapes reject before Fuel/effects in every function, including unreachable ones; dirty contexts fail.
  Prices, cleanup, authority and layouts are unchanged. Development/release passed 8 core groups each; release
  also passed 8 regression groups, 16 native groups total. All 402 current input hashes and receipt identities were rechecked; 97 sources
  match baseline `8c9c8b6`, leaving only `vm_reborrow_execution` changed. Native default only: public/compiler/legacy
  stay gated; no production module imports the wrapper, so no CLI rebuild was needed. Public VM/source promotion and
  derived owned/aggregate support remain separate. No CLI/full native/other M2/M1/Linux/perf rerun or push.
  Core manifests differ only in two unselected gate fixtures, exercised by final regression.
  See [contract](docs/engineering/m2-slice-derived-call-default.md) and [verified evidence](docs/evidence/m2-derived-call-default-windows-20261103.json).

- Shared-VM native derived CALL execution: implemented at `cce170a`.
  Explicit native `inspect_derived`/`execute_derived` runs exclusive-source
  derived CALLs through the shared VM with the existing scalar/control preflight
  and canonical cleanup. Ordinary CALLs retain their owned/aggregate transaction;
  derived CALLs accept borrowed/scalar arguments and a scalar result only.
  Existing native wrapper, public, legacy, source and CLI gates remain closed;
  layouts and prices are unchanged. Development passed 8 new native groups;
  release passed those 8 plus 10 regression groups, with all 74 public
  mutable-parameter CLI cases passing. All 402 current input hashes and compiler,
  retained CLI and native receipt identities were verified. The initial
  30-group regression batch exceeded 600 seconds and has no completed verdict;
  the final selector narrows it to 10 directly affected groups, and its only
  manifest delta is `tools/verify-m2-slice-elements.py`. Four production
  sources changed; 94 others are unchanged under Git LF normalization. Next is
  deliberate existing/default checked-admission promotion. Owned derived
  arguments, aggregate results and guest/public promotion remain gaps. Full
  native, other M2, full M1, Linux, isolation, packaging, allocator,
  native-size/stack and timing were not rerun. Local only; no push. See the
  [execution contract](docs/engineering/m2-slice-derived-call-execution.md) and
  [Windows evidence](docs/evidence/m2-derived-call-execution-windows-20261103.json).

- Native derived CALL loan handoff: implemented at `cf18d2d`.
  enter consumes prepared metadata synchronously; all failure precedes infallible
  canonical receipt/pool/CALL-map PC/ticket/origin publication. Owned and formal
  descendants now transfer to callee formals, support actual scalar writes and
  recursive forwarding, then use existing release/leave to restore exact caller
  child tickets and views in combined-depth order. Rootless derived origin
  resolves through the immutable formal anchor to the real CALL lease. Abort
  preserves writes and the original result or retained failed-cleanup metadata.
  No extra receipt owner, persistent layout, payload copy, opcode, price or public
  capability is added. Native callers preflight scalar/control/register state
  before enter; those publications and shared-core dispatch remain separate.
  Development passed 8 new native groups; release passed those 8 plus 12 existing
  admission/CALL groups. All 401 current input hashes/compiler/native receipts
  match. The existing CALL module changes only origin; 96 other sources match
  `edb9b0a`. No CLI/full native/other M2/Linux/isolation/packaging/allocator/native
  size/stack/timing rerun. Existing legacy and checked/public gates remain.
  Next is shared VM scalar/control wiring, then deliberate checked admission.
  Owned arguments and aggregate results remain outside this derived CALL path.
  Local commits only. See [the handoff contract](docs/engineering/m2-slice-reborrow-call-vm.md)
  and [Windows evidence](docs/evidence/m2-slice-reborrow-call-vm-windows-20261103.json).

- Private unpublished derived-source CALL preparation: implemented at `a4a1430`.
  New native prepare authenticates the complete receipt/child maps and every
  original borrowed source before local shared retention and writer rotation.
  Existing CALL Fuel prepays first; frame and combined depth must both be below
  31, with fresh callee cells and sufficient generation headroom for every
  pending restore. The original invocation, owners, pool, payload and maps remain
  unchanged on success/failure. Prepared holds one unpublished Entry and metadata;
  it exposes no publication or executable admission. Borrowed/scalar signatures
  and scalar results only; owned copies and aggregate results stay outside it.
  Development passed 6 new native groups; release passed the same 6 plus 12
  existing helper groups. All 399 current input hashes and compiler/native
  receipts match. Existing info/checked helpers only add pub; their bodies and
  94 other production sources match `27bdb90`. No CLI, full native, other M2,
  Linux, isolation, packaging, allocator, native size/stack or timing rerun.
  Next is derived-source CALL publication, return authentication/restoration and
  abort coordination. Guest/public gates remain unchanged. Local commits only.
  See [the admission contract](docs/engineering/m2-slice-reborrow-call-admission.md)
  and [Windows evidence](docs/evidence/m2-slice-reborrow-call-admission-windows-20261103.json).

- Analysis-only suspended/derived CALL proof: implemented at `eb2a0ce`.
  `verifier::inspect_reborrow_calls` preserves exact caller live words, requires
  available leaf sources and closed suspended forests, and checks exact modes,
  tags, caller function/origin and unique exclusive source/root/formal-origin use.
  Existing full metadata/type/flow, joins/backedges and reverse cleanup remain.
  Legacy inspect/verify, checked canonical and public execution gates are unchanged.
  Development/release each passed 20 native groups and 2,495 CLI cases; all 397
  current input hashes and retained compiler/artifact/receipt identities match.
  The production delta is verifier plus one new proof module; 94 existing sources
  are unchanged from `5fa17ca`. No Program field, opcode, layout, Fuel or capability
  is added. Native receipt authentication, combined-depth reservation and ticket
  generation restoration for derived CALL sources remain the next integration.
  Full native, other M2, Linux, isolation, packaging, native size/stack, allocator
  and timing were not rerun. Local commits only; no push/release.
  See [the proof contract](docs/engineering/m2-slice-reborrow-call-ir.md) and
  [Windows evidence](docs/evidence/m2-slice-reborrow-call-ir-windows-20261103.json).

- Private canonical exact-nominal record results: implemented at `4a87cb1`. CALL result
  anchors/destinations must have matching nominal identity and correct functions;
  equal-sized other records are rejected. Caller destinations are checked empty
  before any argument copy or loan publication. Existing record return validation
  prepares one native single-use Transfer, retaining its unique result record
  while canonical authority restores. Only infallible token movement follows.
  Legacy step preserves its interface, validation order and 42,113 Fuel price.
  Existing fixed 128-byte validation scratch remains; no additional payload
  snapshot, extent, persistent field, authority clone or receipt collection is
  added. Scalar/array returns pass a no-record sentinel to shared cleanup.
  Development/release each passed 34 distinct native groups (15 core, 19
  regression) and 2,495 CLI cases. All 395 current input hashes and compiler/
  artifact/receipt identities were rechecked. Core inventories differ only in
  one unselected record-argument test subsequently updated to accept the new
  result signatures; final regression executes that expectation. This delta is
  recorded explicitly; production and selected core tests are unchanged.
  The production delta is four files; 91 other sources match `67ce203`.
  CALL/Admission/binding layouts, scalar/control preflight and canonical drain/
  finish are unchanged. Parser depth32 passes; depths33/64 return compile_limit.
  Suspended/derived exclusive CALLs and guest/public reborrow promotion remain
  gated. Abort preserves writes, returned/copied owners and original outcomes
  or failed-cleanup metadata; native callers dispose owned storage/backing.
  Native size/stack, allocation counts and timing remain unmeasured. Next is
  suspended/derived exclusive CALL proof. Local commits only; no push/release.
  See [the record result contract](docs/engineering/m2-slice-record-result-authority.md).
  See [Windows evidence](docs/evidence/m2-slice-record-result-authority-windows-20261102.json).

- Private canonical scalar-array results: implemented at `f7c0827`. Exact-shape CALL
  destinations must be empty before admission. Existing return validation now
  prepares a single-use native Transfer; canonical restoration is last fallible
  work, followed only by moving the existing token. No result payload copy,
  second extent, persistent field or authority clone is added. Source/IR/public
  capabilities and logical prices are unchanged. The legacy result leave API
  composes the same prepare/publish phases. Scalar returns retain prior cleanup;
  array return permits only its validated child result to survive cleanup.
  Development/release each passed 31 distinct native groups (13 core, 18
  canonical regression) and 2,495 CLI cases, with 394 matching current inputs
  across all four phases. Compiler/artifact/receipt identities were rechecked;
  parser depth32 passes and depths33/64 return compile_limit. The four-file
  production delta leaves 91 other source files unchanged from `1a4912b`,
  including compiler, verifier, public VM, native authority/owner/pool primitives
  and scalar/control CALL preflight. CALL/Admission/binding layouts, canonical
  drain/finish and logical prices are unchanged.
  Record results, suspended/derived exclusive CALLs and guest/public reborrow
  promotion remain gated. Abort preserves writes, transferred/copied owners and
  original outcomes or failed-cleanup diagnostics; native callers dispose owned
  storage/backing. Native size/stack, allocator and timing remain unmeasured.
  Next is canonical record results, then suspended CALL proof. Local commits
  only; no push/release. See [the array result contract](docs/engineering/m2-slice-array-result-authority.md).
  See [Windows evidence](docs/evidence/m2-slice-array-result-authority-windows-20261102.json).

- Private canonical owned record arguments: implemented at `b35b867`.
  Immutable exact-nominal records now mix with arrays/scalars/shared/exclusive
  formals. Existing struct_call_vm dispatches unchanged array-only or mixed
  copying after loan/authority preparation; only infallible publication follows.
  Complete existing copy/CALL prices are charged once. Repeated records get
  independent copies; nested bool checks and padding normalization precede writes.
  The mixed copier retains its existing fixed 1024-byte snapshot scratch. No
  additional payload snapshot, authority clone, persistent field or receipt
  collection is added; CALL/Admission/authority declarations remain unchanged.
  Prior native single-use plan, return cleanup and abort ownership contracts
  remain. Copied parameters must be dropped before return. Abort preserves writes,
  copies and original outcomes or failed-cleanup maps; native callers dispose
  owned storage/backing. Public source/capabilities/prices remain unchanged.
  The release-only record field-path repair is committed at `518a9cb`. Its
  standalone path/counter staging preserves existing bounds and logical prices.
  Development/release each passed 32 canonical native groups and 2,495 CLI
  cases, with 393 matching current input hashes. Separate record VM/path checks
  passed 10 native groups and one public wide-record CLI regression per profile.
  Nineteen core/public/native modules match `02e0140`; the remaining struct VM
  change is limited to the selector. Scalar/control and canonical release/return/abort bodies
  and binding/authority layouts are unchanged. Shared core changes only the
  readonly-to-mutable record argument passed into canonical CALL. Full native,
  other M2, Linux, M0, isolation, packaging, native size/stack, allocator and timing
  were not rerun; no measured memory/performance improvement is claimed.
  Aggregate results, suspended/derived exclusive CALLs and guest/public reborrow
  promotion remain gated. Next is canonical scalar-array results as a separate
  slice, then record results and suspended CALL proof. Local commits only;
  no push/release. See [the record CALL contract](docs/engineering/m2-slice-record-call-authority.md)
  and [Windows evidence](docs/evidence/m2-slice-record-call-authority-windows-20261102.json).

- Private canonical owned scalar-array arguments: implemented at `29ddc4a`.
  Immutable exact-shape array values now interleave with scalar/shared/exclusive
  arguments. Complete Fuel includes existing array copy work once. Native
  authority prepare/publish stages a fresh Entry without mutating its State;
  canonical Admission stages loan metadata before unchanged atomic array copying.
  Only infallible authority/pool/binding/scalar/control publication follows copy
  success. Plans are trusted native, single-use, with unchanged authority/root
  sessions between phases; only the atomic copier may intervene. The readonly
  compatibility enter still rejects owned signatures; enter_owned needs mutable
  owners/backing. Existing core cleanup drops copied parameters before return.
  Abort preserves copied owners, prior writes and original outcomes or failed
  cleanup metadata; owned roots/backing remain the native caller's responsibility.
  No persistent fields, receipt collections or payload snapshots are added.
  Temporary Admission/Entry staging and prior inert-view backing have no measured
  native size/stack/allocator/performance claim. Public paths/prices are unchanged.
  Development/release each passed 30 native groups and 2,495 CLI cases, with 391
  matching current inputs and rechecked compiler/artifact/matrix/M1/receipt
  identities. Parser depth32 passes; depths33/64 return compile_limit. Eighteen core/public/native
  modules match `18d2a87`, as do authority/CALL binding declarations, scalar/control
  helpers and canonical release/return/abort bodies. Full native, other M2, Linux,
  M0, isolation, packaging, size/stack, allocator and timing were not rerun.
  Record arguments, aggregate results, suspended/derived exclusive CALLs and
  guest/public reborrow promotion remain gated. Next is owned record argument
  coordination as a separate transaction slice. Local commits only; no push/release.
  See [the owned CALL contract](docs/engineering/m2-slice-owned-call-authority.md)
  and [Windows evidence](docs/evidence/m2-slice-owned-call-authority-windows-20261102.json).

- Private canonical shared-argument CALLs: implemented at `29d7dda`.
  Shared/scalar/exclusive formals now interleave through the existing core and
  canonical authority. Prices remain 1+arity, plus 65537*(1+readers+2*writers)
  when any slice is passed. Shared-only empty Batches consume combined depth;
  caller shared generations remain unchanged. Every original argument checks
  before staged retention; authority admission/restoration is the last fallible
  operation before publication. Return stages readonly child cleanup in reverse
  site order, preserves writer ordinals/detached bindings and clears maps only
  after success. Shared duplicates and derived forwarding after formal close
  retain existing behavior. Abort preserves writes and original outcomes or
  failed-cleanup diagnostics. No persistent fields or receipt collections grow;
  local pool/owner staging adds scratch, without a measured size/stack/allocator
  or performance claim. Existing inert-view backing remains.
  Development/release each passed 30 native groups and 2,495 CLI cases, with 390
  matching current inputs and rechecked compiler/artifact/matrix/M1/receipt
  identities. Fifteen core/public/native modules match `d0d66a1`; readonly CALL
  changes only helper visibility, and the CALL binding declaration is unchanged.
  Parser depth32 passes; depths33/64 return compile_limit. Full native, other M2,
  Linux, M0, isolation, packaging, allocator, size/stack and timing were not rerun.
  Owned arguments, aggregate results, suspended/derived exclusive CALLs and
  guest/public reborrow promotion remain gated. Next is canonical owned scalar
  array argument copying as a separate transaction slice. Local commits only;
  no push/release. See [the shared CALL contract](docs/engineering/m2-slice-shared-call-authority.md)
  and [Windows evidence](docs/evidence/m2-slice-shared-call-authority-windows-20261102.json).

- Private scalar-only canonical CALLs: implemented at `c1b2c0c`.
  The canonical CALL adapter admits zero-writer scalar arguments/results with the
  existing price `1 + arity`. Writer reserve/price is unchanged. Empty native Batch
  events consume VM and combined restoration depth without rotating pool tickets,
  changing views or ending sessions. Existing CALL PC cells record scalar targets;
  mapped empty events validate scalar positions, empty origins and detached cells.
  Normal return requires its real mapped PC/target and clean child bindings.
  Native unmapped empty events remain compatible with direct protocols; canonical
  adapter return still rejects a missing PC. Shared scalar/control/core/cleanup
  code and native primitives are unchanged. No state fields, receipt collections,
  backing values or heap allocations are added. Existing inert-view backing and
  unmeasured native stack/allocator/performance limitations remain.
  Scalar helpers can interleave with available outer mutable formals and execute
  owned local reborrow. Empty ancestors count toward later conservative writer
  generation headroom. Admission failure is atomic; abort preserves earlier
  writes and original outcomes or empty/nonempty failed-cleanup records.
  Development/release each passed 18 native groups and 2,495 CLI cases, with 389
  matching current inputs and rechecked compiler/artifact/matrix/M1 identities.
  Existing Program/signature/map fields, primitive/adaptor, compiler, verifier,
  public VM/CLI and shared core/control/admission/cleanup sources match `e960ec0`.
  Parser depth32 passes; depths33/64 return compile_limit. Full native, other M2,
  Linux, M0, isolation, packaging, size/stack, allocator and timing were not rerun.
  Local commits only; no push/release. Shared/owned arguments, aggregate results,
  suspended/derived CALLs and guest/public reborrow promotion remain gated. Next
  is remaining canonical CALL argument/result coordination. See
  [the scalar CALL contract](docs/engineering/m2-slice-scalar-call-authority.md) and
  [Windows evidence](docs/evidence/m2-slice-scalar-call-authority-windows-20261102.json).

- Private canonical reborrow shared-core execution: implemented at `94d73bd`.
  `vm_reborrow_execution` runs independent IR/flow/Sites and private subset
  admission, checks three unique fresh invocation roots and finishes every
  admitted outcome through combined drain. Existing vm_execution::core now wires
  canonical begin/end, data access, formal release, CALL and scalar return into
  its shared scalar/control loop. call_frame_vm::step_canonical reuses unchanged
  scalar/control prepare/publish; authority handoff is its last fallible step.
  Native authority remains the sole receipt owner. Existing map/Program/signature/
  owner/pool/shared-frame fields and logical prices are unchanged. Public/legacy
  entries still reject op61/62. Shared slices, zero-writer/scalar-only, shared/
  owned-argument and aggregate-result CALL shapes, suspended/derived CALLs and
  guest/public promotion remain outside this private mode. Guest recursion
  uses fixed VM frames rather than native recursion. The wrapper preserves dirty admission state
  without executing or draining it; runtime abort preserves writes and original
  outcomes or failed-cleanup diagnostics. Callers dispose owned roots/backing.
  Legacy wrappers now use one inert authority/CALL/site-map backing value each
  for empty views; canonical execution uses one inert legacy Frame. These add
  fixed local storage. Native stack size, allocator and performance are unmeasured.
  Development/release each passed 16 native groups and 2,495 CLI cases, with 388
  matching current inputs and rechecked compiler/artifact/matrix/M1 identities.
  Existing Program/signature/map fields, native primitives/adapters, verifier,
  compiler and public VM/CLI sources match `7b899d1`; old scalar/control preflight
  and publication bodies also match. Parser depth32 passes; depths33/64 return
  compile_limit. Full native, other M2, Linux, M0, isolation, packaging, native
  stack/allocator and timing were not rerun. Local commits only; no push/release.
  Next is canonical zero-writer/scalar-only frame coordination before other CALL
  shapes and deliberate guest/public promotion. See
  [the shared-core contract](docs/engineering/m2-slice-reborrow-execution.md) and
  [Windows evidence](docs/evidence/m2-slice-reborrow-execution-windows-20261102.json).

- Private canonical formal reborrow/data adapter: implemented at `5baffe4`.
  `slice_formal_reborrow_vm` supports owned roots and rootless exclusive formal
  children using the existing 93 site-map cells and canonical CALL maps. It adds
  no persistent fields or duplicate receipts. First children authenticate their
  suspended formal against the original CALL range/session/slot; nested children
  authenticate the exact previous selection and session. Current child tickets
  must match canonical receipts, owner sessions and generation bounds.
  Begin/end prepay 65,537 Fuel before runtime lookup. Authenticated length/read/
  write/u8 UTF-8 use existing scalar codecs and prices; UTF-8 charges original
  owner length before payload access. CALL exposes readonly inspect/suspended and
  one shared drain transaction. Combined finish clears all CALL and child maps
  only after successful pool drain, preserving writes/original outcomes or failed
  cleanup metadata. The owned-only adapter and its rootless rejection are intact.
  Native adapter only: shared-core dispatch, suspended/derived CALL admission,
  guest syntax and public promotion remain gated. No Program/signature/owner/
  pool/shared-frame fields or existing public capability/price changes.
  Development/release each passed 18 native groups and 2,495 CLI cases, with 385
  matching current inputs and rechecked compiler/artifact/matrix/M1 identities.
  Program/signature and existing map declarations and core/native sources match
  `f3f7fd1`; CALL changes only readonly authentication and shared drain extraction.
  Parser depth32 passes; depths33/64 return compile_limit. Full native, other M2,
  Linux, M0, isolation, packaging, allocator, size/stack and timing were not rerun.
  Local commits only; no push/release. Next is shared execution-loop and complete
  scalar/CALL/return/abort coordination using unique maps and canonical receipts.
  See [the formal adapter contract](docs/engineering/m2-slice-formal-reborrow-vm.md)
  and [Windows evidence](docs/evidence/m2-slice-formal-reborrow-vm-windows-20261102.json).

- Private canonical exclusive CALL binding: implemented at `c5c9a91`.
  `slice_authority_call_vm` derives caller/target/argument positions from 31 CALL
  PC cells, retains 248 detached-ticket cells and keeps canonical Batch/Loan
  receipts exclusively in native authority. It authenticates entry, formal
  release, return and abort against immutable IR, frame/origin/session maps and
  combined pending restoration depth. All originals validate before handoff;
  late multi-argument failure preserves earlier inputs. Abort drains before map
  cleanup and preserves writes/outcomes or failed-cleanup diagnostic state.
  This private bridge admits scalar/exclusive arguments only. Shared/owned args,
  aggregate results and derived reborrow CALL sources remain rejected. Scalar/
  control publication and unrelated callee cleanup belong to the coordinator.
  Existing public CALL and owned reborrow adapters remain unchanged. No Program/
  signature/owner/pool/shared-frame fields, opcode or public capability/price
  changes. Rootless reborrow instructions and shared execution-loop wiring are
  next; suspended CALL proof and guest/public promotion remain separate gates.
  Development/release each passed 24 native groups and 2,495 CLI cases, with 383
  matching current inputs and rechecked compiler/artifact/matrix/M1 identities.
  Program/signature declarations and existing authority, native primitives, IR,
  verifier, VM/CLI/compiler and CALL/reborrow adapter sources match `16da4f2`.
  Parser depth32 passes; depths33/64 return compile_limit. Full native, other M2,
  Linux, M0, isolation, packaging, allocator, native size/stack and timing were not
  rerun. Local commits only; no push/release. See
  [the CALL binding contract](docs/engineering/m2-slice-authority-call-vm.md) and
  [Windows evidence](docs/evidence/m2-slice-authority-call-vm-windows-20261102.json).

- Private metered owned reborrow adapter: implemented at `995e22f`.
  `slice_reborrow_vm` prepays 65,537 Fuel per op61/62 before runtime lookups,
  authenticates frame/root/site/canonical receipts and publishes fresh child or
  restored parent bindings only after native success. Three 31-entry maps retain
  parent/child/function identities without duplicate Loan/Batch receipts. Existing
  owned dispatch handles available child scalar reads/writes/length/u8 UTF-8.
  Abort drains first, then clears maps/tickets/shared origins while preserving
  prior writes and the original result; failed cleanup preserves diagnostic state.
  Native authority adds readonly inspect only; existing State/algorithms match
  `19e1886`. No Program/signature/owner/pool/shared-frame fields or existing prices
  change. Public/internal op61/62 execution and suspended CALL proof remain gated.
  Rootless formals are rejected by this adapter pending canonical CALL parameter
  maps. Next is shared CALL/site/lifecycle coordination, rootless adaptation and
  shared-core wiring without duplicate receipts, before guest/public promotion.
  Development/release each passed 24 selected native groups and 2,495 CLI cases,
  with 381 identical current inputs and rechecked compiler/artifact/matrix/M1
  identities. Verifier/core/CLI/compiler/IR/native primitive sources match
  `19e1886`; authority differs only by readonly inspection. Parser depth32 passes;
  depths33/64 return compile_limit. Full native, other M2, Linux, M0, isolation,
  packaging, allocator, native size/stack and timing were not rerun. No push/release.
  See [the adapter contract](docs/engineering/m2-slice-reborrow-vm.md) and
  [Windows evidence](docs/evidence/m2-slice-reborrow-vm-windows-20261102.json).

- Private independent-root reborrow order proof: implemented at `0163a26`.
  Immutable begin-PC ranks and sixteen newer-child masks enforce increasing
  creation rank and reverse restoration across independent roots, matching the
  native authority stack. Available and suspended derived children both count.
  Existing live-word equality uniquely determines pending order at joins/backedges;
  no new per-PC stack/word or Program/signature field is added. Metadata adds
  sixteen mask words and sixteen temporary begin-PC words, without a measured
  native size/stack/allocator/timing claim. Site allocation order is irrelevant.
  Public/internal op61/62 execution and CALL during suspension remain gated.
  Native authority, verifier source and VM/CLI paths remain unchanged.
  Next is metered site/binding instruction adaptation and shared CALL/return/abort
  integration using canonical native receipts, then deliberate private CALL proof
  admission. Guest syntax and public promotion remain separate.
  Development/release each passed 23 selected native groups and 2,495 CLI cases,
  with 379 identical current inputs and rechecked compiler/artifact/matrix/M1
  identities. Program/signature declarations and owner/pool/native receipt/VM/
  compiler/verifier sources match `38c4a33`. Parser depth32 passes; depths33/64
  return compile_limit. Full native, other M2, Linux, M0, isolation, packaging,
  allocator, size/stack and timing were not rerun. No push/release. See
  [the order contract](docs/engineering/m2-slice-reborrow-order.md) and
  [Windows evidence](docs/evidence/m2-slice-reborrow-order-windows-20261102.json).

- Private combined CALL/reborrow authority stack: implemented at `d0567c6`.
  `slice_authority` owns canonical native CALL/subrange receipts and counts all
  pending restorations in one 31-entry bound, including empty CALLs. Generation
  reserves use combined depth; creator-frame checks and strict reverse order
  prevent wrong-frame/type/ancestor restoration. Atomic abort drains the existing
  pool before clearing the private stack and preserves prior payload writes.
  Native fixed metadata is added; no Program/signature/owner/pool/shared-frame
  field, payload extent, source grammar, opcode, public capability or price changes.
  Existing mutable VM receipts and op61/62 execution gates remain unchanged.
  Next is aligning independent-root IR lifetimes with the stack's strict order,
  then metered VM binding/control/return/abort integration without duplicate
  canonical receipts. Guest/public promotion remains separate.
  Development/release each passed 24 selected native groups and 2,495 CLI cases,
  with 378 identical current inputs and rechecked compiler/artifact/matrix/M1
  identities. Verifier, execution, CLI/compiler and existing native loan/CALL
  primitives remain unchanged from `bc44a1f`. Parser depth32 passes; depths33/64
  return compile_limit. Full native, other M2, Linux, M0, isolation, packaging,
  allocator, native size/stack and timing were not rerun. No push/release. See
  [the authority contract](docs/engineering/m2-slice-authority.md) and
  [Windows evidence](docs/evidence/m2-slice-authority-windows-20261102.json).

- Private exclusive reborrow IR proof: implemented at `3987195`.
  Checked private op61/62 derive a unique acyclic child/parent forest from immutable
  code and prove available/suspended lifetimes over owned and rootless formal
  scalar slices. Existing live bits48..63 hold suspended parents; no Program,
  signature or per-PC flow words are added. Parent access, direct-root bypass,
  stale children, wrong restores and mismatched joins/backedges fail inspection.
  Public verification and both internal execution entries reject the instructions
  before dispatch/state publication. CALL during pending reborrow remains gated.
  Next is combined CALL/reborrow depth admission and per-frame receipt ownership,
  before metering, executable VM integration and guest/public promotion.
  Development/release each passed 23 selected native groups and 2,495 CLI cases,
  with 376 identical current inputs and rechecked compiler/artifact/matrix/M1
  identities. Program/signature declarations, owner/pool/native reborrow/handoff,
  shared frame helpers, compiler and public VM/CLI entries match `febe841`.
  Parser depth32 passes; depths33/64 return compile_limit. Full native, other M2,
  Linux, M0, isolation, packaging, allocator, timing and native stack/memory checks
  were not rerun. No push/release. See
  [the IR contract](docs/engineering/m2-slice-reborrow-ir.md) and
  [Windows evidence](docs/evidence/m2-slice-reborrow-ir-windows-20261102.json).

- Private exclusive subrange foundation: implemented at `ab85195`.
  `slice_reborrow` narrows one existing exclusive pool slot, invalidates the
  parent ticket and restores its original range with a fresh generation.
  Private linear native receipts retain the original write session. Empty and
  nested ranges preserve the whole-root lock; abort atomically drains the active
  pool before clearing at most 32 receipts and preserves payload writes.
  No Program/owner/pool-slot/shared-frame fields, owner session or payload extent
  is added. Native coordinators must preserve authentic receipts, reverse nesting
  order, latest tickets and generation reserves for the entire authority chain.
  Current CALL depth admission is not integrated. Next is independent IR
  suspended-parent/child lifetime proof plus combined CALL/reborrow depth and
  receipt ownership, before metering/VM/source/public promotion. Public mutable
  aliases/subloans, coercions and returned borrows remain unsupported.
  Development/release each passed 18 selected native groups and 2,495 CLI cases,
  with 374 identical current inputs and rechecked compiler/artifact/matrix/M1
  identities. Core owner/pool/handoff/frames/VM/execution/verifier/CLI files remain
  unchanged from `80adbb7`. Parser depth32 passes and depths33/64 return
  compile_limit. Full native, other M2, Linux, M0, isolation, packaging, allocator,
  timing and native stack/memory measurements were not rerun. No push/release.
  See [the native contract](docs/engineering/m2-slice-exclusive-reborrow.md).
  Evidence: [Windows receipt](docs/evidence/m2-slice-exclusive-reborrow-windows-20261102.json).

- Public mutable scalar-slice parameters: implemented at `914ae79`.
  Public verify and inspect now share complete metadata/type/flow/lifetime proof,
  including exact exclusive CALL sources and rootless mutable formals. The public
  VM selects a separate receipt-owning helper only for mutable-formal Programs,
  executes the shared core and invokes mutable finish on every outcome. Readonly
  and owned-only programs keep the legacy entry/cleanup. CLI version JSON reports
  `array_slice_mutable_parameters: true`. No Program/signature-table fields,
  opcodes, profile or existing instruction/CALL prices change. The CLI keeps its
  1,000,000 Fuel cap; native sufficient-Fuel tests cover the deeper frame bound.
  Mutable aliases/subloans, coercions, temporary roots and returned borrows remain
  unsupported. Remaining M2 includes these borrow extensions, Buffer and I/O.
  Development/release each passed 33 native groups and 2,495 CLI cases (74 mutable
  parameter, 222 owned mutable, 192 readonly scalar, 2,007 M1), with 372 identical
  current inputs and rechecked compiler/artifact/matrix/M1 identities. Program
  and signature-table fields match `69f96c9`. Parser depth32 passes; depths33/64
  return compile_limit. Development native/build preceded a CLI-only Fuel-test
  correction; its unchanged native result was retained and CLI phases completed
  separately. Release ran the full corrected selection. Full native, other M2,
  Linux, M0, isolation, packaging, allocator and timing were not rerun. No push.
  See [the public contract](docs/engineering/m2-slice-mutable-parameters-public.md)
  and [working example](examples/mutable-slice-parameters.brc).
  Evidence: [Windows receipt](docs/evidence/m2-slice-mutable-parameters-public-windows-20261101.json).

- Private mutable parameter source lowering: implemented at `2f9cc0d`.
  Source `ref mut Tag[]` formals and exact `ref mut name` arguments lower to
  existing exclusive descriptors/CALL arguments without new signature-table or
  Program fields. Existing lexical close releases a formal into its receipt;
  immutable inspected source executes with 32 unique receipts and mandatory
  mutable finish. Exact mode/tag checks reject coercions and non-named sources;
  independent proof rejects duplicate exclusive arguments and borrowed-root copies.
  Public verify/VM/CLI still reject rootless exclusive formals before backing,
  Fuel or dispatch, including unused signatures. No opcode, price, profile or
  capability change. Next is deliberate public VM/CLI admission and capability
  promotion. Aliases/subloans, returned borrows and temporary roots stay unsupported.
  Development/release each passed 22 native groups and 2,489 CLI cases (68 private
  source gates, 222 owned mutable, 192 readonly scalar and 2,007 M1), with 370
  identical current inputs and rechecked compiler/artifact/receipt identities.
  Program/signature-table fields are unchanged from `6eabce5`; depth32 parser
  passes and depths33/64 return compile_limit. Native source executes 31 nested
  mutable calls and rejects the next with kind12. Full native, other M2, Linux,
  M0, isolation, packaging, allocator and timing were not rerun. No push/release.
  See [the source contract](docs/engineering/m2-slice-mutable-parameters-source.md).
  Evidence: [Windows receipt](docs/evidence/m2-slice-mutable-parameters-source-windows-20261101.json).

- Private mutable CALL execution: implemented at `f22a6da`. The shared core
  routes mutable CALLs through checked scalar/control publication and the native frame transaction.
  Rootless mutable instructions authenticate the receipt/session, use existing
  read/write/length/UTF-8/close prices and detach formals on close. Scalar/tagged,
  array and record returns restore caller authority; abort uses mutable finish.
  `execute_mutable` requires inspected immutable IR, 32 initialized unique native
  receipts and mandatory finish on every result. Legacy execute passes an empty
  view backed by one inert receipt rather than allocating the full collection.
  Public verify/VM and mutable source grammar remain gated; no Program fields,
  opcodes, profile, capability or public/readonly price changes. Next is exact
  mutable parameter/argument source lowering and deliberate public promotion.
  Development/release each passed 16 selected native groups and 2,421 CLI cases
  (222 mutable, 192 readonly scalar, 2,007 M1), with 368 identical current inputs
  and rechecked compiler/artifact/receipt identities. Program fields remain
  unchanged; parser depth32 passes and depths33/64 return compile_limit. Native
  mutable execution accepts 31 nested calls; the next frame returns kind12 with
  sufficient Fuel. Full native, other M2, Linux, M0, isolation, packaging,
  allocator and timing were not rerun. No push/publication/release/deployment.
  See [the contract](docs/engineering/m2-slice-mutable-execution.md) and
  [Windows evidence](docs/evidence/m2-slice-mutable-execution-windows-20261101.json).

- Private mutable slice CALL frame adapter: implemented at `6ea599c`.
  `slice_mutable_call_vm` stages mixed shared retention and exclusive handoff, copies owned arguments last, then
  publishes child loan/origin bindings and a unique per-CALL receipt. Formal
  release detaches the capability without unlocking its owner; return stages
  ordinary loan closes and fresh caller restoration before publication. Abort
  drain clears receipts only on success and preserves prior writes/original
  outcomes. Scalar/control frames, shared execution-loop wiring, mutable formal
  instructions and source/public admission remain unconnected. Legacy gates and
  public/readonly prices are unchanged. Private CALL prepays base/scalar + owned
  copies + 65537*(1 + shared + 2*exclusive); release costs 4097. No Program,
  shared Frames or pool-slot fields grow. Next is executable coordinator/formal
  dispatch and return/abort integration. Development/release each passed 15
  selected native groups and 2,421 CLI cases (222 mutable, 192 readonly scalar,
  2,007 M1), with 366 identical current inputs and rechecked compiler/artifact/
  receipt identities. Program fields are unchanged; depth32 passes and depths33/64
  return compile_limit. Full native, other M2, Linux, M0, isolation, packaging,
  allocator and timing were not rerun. No push/publication/release/deployment.
  See [the contract](docs/engineering/m2-slice-mutable-call-vm.md) and
  [Windows evidence](docs/evidence/m2-slice-mutable-call-vm-windows-20261101.json).

- Private mutable scalar-slice CALL IR proof: implemented at `20afacd`. Exact
  tags/modes, live same-function owned or formal sources and per-CALL exclusive site/owned-root uniqueness are
  checked by the shared scalar/aggregate argument proof. Shared duplicates stay
  legal. CALL preserves the caller live set for synchronous restoration. Public
  verify/VM still reject rootless exclusive formals after full proof and before
  backing/Fuel/dispatch; runtime cost/frame adapters and guest syntax stay gated.
  No Program fields, opcodes, Fuel prices or capabilities change. Next is mixed
  runtime CALL admission, staged frame publication and return restoration using
  the native handoff foundation. Development and release each passed 21 selected
  native groups and 2,421 CLI cases (222 mutable, 192 readonly scalar, 2,007 M1),
  with 364 matching input hashes and rechecked compiler/artifact/receipt identities.
  Program fields are unchanged; depth32 passes and depths33/64 return compile_limit.
  Full native, other M2, Linux, M0, isolation, packaging, allocator and timing were
  not rerun. No push/publication/release/deployment. See
  [the contract](docs/engineering/m2-slice-mutable-call-ir.md) and
  [Windows evidence](docs/evidence/m2-slice-mutable-call-ir-windows-20261101.json).

- Private exclusive CALL handoff/restore foundation: implemented at `88b96ff`.
  `slice_handoff` validates up to eight original exclusive tickets, rotates their generations in a staged
  sixteen-slot pool and preserves exact owner write sessions. Restore validates
  the receipt and latest nested-return tickets before publishing fresh caller
  tickets; entry/restore failures leave state unchanged. Depth0..30 reserves
  generation headroom for all outstanding returns. No Program/pool fields grow,
  extra payload extent or public capability is added. Native tests cover six
  scalar writes, 31 nested handoffs and full-pool abort drain. Mutable CALL IR
  admission, VM frame integration, runtime formal dispatch and source parameters
  remain gated. Next is mixed CALL admission and return/error lifecycle using
  staged unpublished handoff plans. Development and release each passed 26
  selected native groups and 2,421 CLI cases (222 mutable, 192 readonly scalar,
  2,007 M1), with 363 identical current input hashes. Compiler, retained CLI,
  receipt identities and unchanged Program fields were rechecked. Depth32 passes;
  depths33/64 return compile_limit. Full native, other M2, Linux, M0, isolation,
  packaging, allocator and timing were not rerun. No push/publication/release/
  deployment. See [the contract](docs/engineering/m2-slice-exclusive-call-handoff.md)
  and [Windows evidence](docs/evidence/m2-slice-exclusive-handoff-windows-20261101.json).

- Private mutable scalar-slice formal IR: implemented at `33da699`.
  Rootless mutable formals use bit128 plus an exact low-seven-bit scalar tag in
  the existing element byte (129/130/137/138/139/140). The checked builder,
  metadata/entry masks and independent body proof support all six scalar tags
  without new Program fields. Reads, stores, length, u8 UTF-8 and exact lifetimes
  are inspected; this is not mutable-formal execution evidence. Mutable CALL
  sources/destinations, aliases/subloans and source formals remain unavailable.
  Public verify proves the whole Program then rejects rootless exclusive sites
  before backing/Fuel/dispatch. Owned mutable slices and readonly parameters
  stay public, with unchanged opcodes, Fuel, profiles and capabilities. Next is
  atomic exclusive CALL handoff/restore. Development and release each passed 26
  selected native groups and 2,421 CLI cases (222 owned mutable, 192 readonly
  scalar and 2,007 M1), with 361 identical current input hashes and rechecked
  compiler/artifact/receipt identities. Program fields remain unchanged;
  depth32 succeeds and depth33/64 return compile_limit. Full native, other M2,
  Linux, M0, isolation, packaging, allocator and timing were not rerun. No push,
  publication, packaged release or deployment. See
  [the contract](docs/engineering/m2-slice-mutable-parameters-ir.md) and
  [Windows evidence](docs/evidence/m2-slice-mutable-parameters-ir-windows-20261101.json).

- Public mutable scalar slices: implemented at `ecfe96c`.
  Public verify now uses the same complete metadata/type/flow/lifetime proof as
  inspect without the final blanket exclusive-site gate. CLI check/run admit
  same-function owned mutable roots for all six scalar tags, `let ref mut Tag[]`
  declarations and exact typed relative stores. Reads, length, selected u8 UTF-8,
  metered dispatch and normal/error cleanup use the existing unified pool.
  Version JSON reports `array_slice_mutable: true`. Program fields, instruction
  prices, profiles and CLI Fuel limits are unchanged. Mutable formals, aliases/
  subloans, returned borrows, temporary roots and readonly CALL coercions remain
  unsupported. See [the public contract](docs/engineering/m2-slice-exclusive-public.md)
  and [working example](examples/mutable-slices.brc). Development and release
  each passed 26 selected native groups and 2,421 CLI cases (222 mutable, 192
  readonly scalar and 2,007 M1), with 360 identical current input hashes and
  rechecked compiler/artifact/receipt identities. Development native reports were
  reused after CLI-only test corrections; release ran the complete selection.
  Depth32 succeeds; depth33/64 return compile_limit. Full native, other M2,
  Linux, M0, isolation, packaging, allocator and timing were not rerun. No push,
  publication, packaged release or deployment. See
  [Windows evidence](docs/evidence/m2-slice-exclusive-public-windows-20261101.json).
  Earlier private-stage entries below record their original boundaries at the
  named commits.

- Private mutable scalar-slice source: implemented at `e0a0ec0`.
  Source lowering accepts `let ref mut Tag[] p = ref mut a[lo..hi];` over an
  existing same-function mutable scalar-array root, and exact typed relative
  element stores. It reuses marker128, opcode60 and reverse lexical cleanup.
  Pending endpoints and store index/value expressions preserve evaluation order.
  Independent inspection rejects payload root access/copies and conflicting
  sessions. Source rejects mode mismatches, immutable roots, aliases/subloans,
  rebinding, mutable formals and readonly CALL coercions. Public verify and CLI
  still reject exclusive metadata before backing/Fuel/dispatch. Public admission
  is next; no public capability, Program fields or Fuel prices change.
  Development and release each passed 17 selected native groups and 2,363 CLI
  cases (164 private source-gate, 192 public readonly scalar and 2,007 M1), with
  359 matching current input hashes and rechecked compiler/artifact/receipt
  identities. Depth32 succeeds; depth33/64 return compile_limit. Full native,
  other M2, Linux, M0, isolation, packaging, allocator and timing were not rerun.
  No push/publication/release/deployment. See
  [the contract](docs/engineering/m2-slice-exclusive-source.md) and
  [Windows evidence](docs/evidence/m2-slice-exclusive-source-windows-20261101.json).

- Private metered exclusive slice VM: implemented at `b8b3d58`.
  The internal execution loop routes owned marker128 sites through checked
  open/read/write/length/u8 UTF-8/close over the existing unified pool. Every
  operation prepays its complete price before runtime state or payload access;
  opcode60 costs 4,130 + twice the scalar width. Explicit normal closes and the
  existing invocation drain retain their lifetime/error semantics. Public verify
  still rejects all exclusive metadata before allocation/Fuel/dispatch. No guest
  mutable-slice syntax, mutable parameters, subloans or capability is enabled.
  Program fields and readonly instruction prices are unchanged. Development and
  release each passed 28 selected native groups and 2,199 CLI cases (192 public
  scalar slices plus 2,007 M1), with 357 identical current input hashes and
  rechecked compiler/artifact/receipt identities. Depth32 succeeds; depth33/64
  return compile_limit. Full native/other M2, Linux, M0, isolation, packaging,
  allocator and timing were not rerun. No push/publication/release/deployment.
  Public admission and mutable guest lowering are next. See
  [the contract](docs/engineering/m2-slice-exclusive-vm.md) and
  [Windows evidence](docs/evidence/m2-slice-exclusive-vm-windows-20261101.json).

- Private shared/exclusive runtime slice pool: implemented at `1a278a1`.
  The existing sixteen slots now
  carry a mode bit and checked native exclusive reads/writes/selected UTF-8.
  Both modes share ticket/owner epochs and atomic reverse-order clear. Existing
  VM drain preserves result/error on success or retains metadata on cleanup
  failure. Readonly VM adapters and CALL batches reject writers. Public exclusive
  admission and instruction dispatch remain gated; no new Fuel price, mutable
  source syntax or capability is enabled. Development and release each passed
  22 selected native groups and 2,199 CLI cases (192 public scalar slices plus
  2,007 M1), with 355 identical current input hashes and rechecked compiler/CLI/
  receipt identities. Program fields remain unchanged; depth32 succeeds and
  depth33/64 return compile_limit in check/run. Full native/other M2, Linux, M0,
  isolation, packaging, allocator and timing checks were not rerun. No push,
  publication, packaged release or deployment. See
  [the contract](docs/engineering/m2-slice-exclusive-pool.md) and
  [Windows evidence](docs/evidence/m2-slice-exclusive-pool-windows-20261101.json).

- Private exclusive slice-write IR: implemented at `caea3d2`.
  Opcode 60 describes a store through a live owned
  exclusive site using ordinary same-function defined `usize` index and exact
  scalar value snapshots. `ir::slice_write` emits no scalar register; failures
  preserve code/offsets/counts. Independent inspection rejects readonly/closed
  sites, wrong tags, foreign/undefined operands and nonzero reserved bytes.
  Defined/written registers and loan live sets remain unchanged. Public
  verification/VM admission is still gated; no guest syntax, execution, Fuel
  price or capability is enabled. Development and release each passed 14 selected
  native groups and 2,199 CLI cases (192 public scalar slices plus 2,007 M1), with
  354 identical current inputs and rechecked compiler/artifact/receipt identities.
  Program fields remain unchanged; depth32 succeeds and depth33/64 return
  compile_limit in check/run. Full native/other M2, Linux, M0, isolation,
  packaging, allocator and timing were not rerun. No push/publication/release/deploy.
  See [the contract](docs/engineering/m2-slice-write-ir.md) and
  [Windows evidence](docs/evidence/m2-slice-write-ir-windows-20261101.json).

- Private owned exclusive slice IR: implemented at `ae66b1b`.
  Owned `slice_elements` marker 128 denotes
  exclusivity without growing Program; `ir::exclusive_slice` reserves a checked
  site. `inspect` proves
  root-wide read/write exclusion, source-copy gates and exact control-flow
  lifetimes. Aliases/subranges, rootless mutable formals and readonly CALL
  coercions are rejected. Public `verify` performs the full proof then rejects
  every exclusive flag before VM backing/Fuel/dispatch. No guest syntax, opcode,
  Fuel price, runtime integration or version capability change is added.
  Development and release each passed 14 selected native groups and 2,199 CLI
  cases (192 public scalar slices plus 2,007 full M1), with 353 identical current
  input hashes and rechecked compiler/artifact/receipt identities. Depth 32
  succeeds and depths 33/64 return compile_limit in check/run; no stack-size
  measurement is claimed. Full native/other M2, Linux, M0, isolation, packaging,
  allocator and timing checks were not rerun. No push/publication/release/deploy.
  See [the contract](docs/engineering/m2-slice-exclusive-ir.md) and
  [Windows evidence](docs/evidence/m2-slice-exclusive-ir-windows-20261101.json).

- Private exclusive array sessions: implemented at `78685b1`.
  `array_owners::WriteLease` locks one whole
  scalar-array root for checked relative reads/writes over a selected range.
  Ordinary root/view access, copies, CALL copy batches, transfer and cleanup
  reject exclusive roots. Shared read/write epochs never wrap; failed ends
  retain the lock. No guest mutable-slice syntax, VM dispatch or Fuel/capability
  change is added. Development and release each passed 32 selected native groups
  and 206 CLI cases, with 351 identical current inputs and rechecked artifact
  identities. Full native/M1/other M2, Linux, M0, isolation, packaging, allocator
  and timing checks were not rerun. No push/publication/release/deployment.
  See [the contract](docs/engineering/m2-array-write-leases.md) and
  [Windows evidence](docs/evidence/m2-array-write-leases-windows-20261101.json).

- Public readonly scalar slice elements: all six scalar tags (`i32`, `bool`,
  `i64`, `u8`, `u32`, `usize`) are implemented and locally committed at
  `ec73328` for same-function owned lexical array roots, immutable `ref Tag[]`
  aliases and explicit `ref name` CALL arguments. Public `verify` and CLI
  `check`/`run` share the complete metadata/type/flow/lifetime proof and the
  existing VM lifecycle; version JSON adds `array_slice_scalar_elements: true`.
  UTF-8 predicates apply only to `u8` arrays and slices. Development and release
  each passed 22 native groups and 2,833 CLI cases, including all 2,007 M1 cases.
  Both matched 351 current input hashes; pinned compiler, retained CLI identities
  and all six matrix receipts were rechecked. Full native and other M2 suites,
  Linux, M0, isolation, packaging, allocator and timing checks were not rerun.
  No push, publication, packaged release or deployment was performed. See the
  [Windows evidence](docs/evidence/m2-slice-element-public-windows-20261101.json).
  See [the public contract](docs/engineering/m2-slice-element-public.md).

- Private typed borrowed slice VM: implemented and verified at `b8ba1e0`.
  Development and release each passed 19 native groups (5 typed VM, 4 borrowed
  CALL, 4 dynamic frame, 6 lifecycle) and 634 CLI cases (252 typed source gate,
  64 public u8, 74 source, 120 alias, 124 sub). Both runs matched 348 identical
  current input hashes; both retained CLI identities and all five matrix receipt
  hashes were rechecked. See the [Windows evidence](docs/evidence/m2-slice-element-vm-windows-20261101.json).
  Public `u8` slices work; non-`u8` admission and typed owned-root bindings remain
  gated. Full M1 and full native were not rerun (`m1=null`); the parser and
  source-lowering implementation remains unchanged, while VM source and metadata
  checks changed. Other M2, Linux, M0, isolation, packaging, allocator and timing
  were not rerun. No push, publication, release or deployment was performed. See
  [the private typed VM contract](docs/engineering/m2-slice-element-vm.md).

- Typed slice element source: implemented and verified at `5401efb`; non-`u8`
  borrowed VM execution remains gated. Source lowering accepts readonly
  `ref i32[]`, `bool[]`, `i64[]`, `u8[]`, `u32[]` and `usize[]` formals,
  exact typed aliases/subranges and `ref name` calls. `inspect` proves the
  private IR; `verify` rejects non-`u8` borrows before VM admission.
  `u8` owned bindings and borrowed execution work; non-`u8` owned-root
  bindings remain unavailable. Development and release each passed 14 native
  groups and 2,641 CLI cases, with 347 identical current input hashes and
  verified CLI identities. The recursive CALL signature-index scratch repair
  is included; no stack-size measurement is claimed. Historical parser-stack
  docs remain unchanged. No opcode, Fuel, capability, version or profile change.
  No push, publication or release/deployment was performed. See [the source
  contract](docs/engineering/m2-slice-element-source.md) and [Windows
  evidence](docs/evidence/m2-slice-element-source-windows-20261101.json).

- Private typed readonly slice IR: implemented at `f9bc9d6`.
  `Program.slice_elements` records exact scalar tags for borrowed formals and
  derived sites; typed read/length/subslice/close preserve the shape, and
  argument and verification checks require exact matches. `inspect` accepts
  the proved private IR; `verify` then rejects every non-u8 borrowed site
  before VM backing, Fuel or dispatch. Public source and CLI remain `ref u8[]`
  only. Development and release each passed 28 native groups and 402 CLI cases,
  with 345 identical current input hashes; both CLI binaries were retained and
  identity-checked. Full native, M1 and other M2 suites, Linux, M0, isolation,
  packaging, allocator and timing checks were not rerun. See
  [the private typed slice contract](docs/engineering/m2-slice-elements.md) and
  [the Windows evidence](docs/evidence/m2-slice-elements-windows-20261101.json).

- Public readonly u8 slice parameters: implemented at `6a7d206`.
  Public VM and CLI now admit verified `ref u8[]` signatures and explicit
  ref-name arguments. Full metadata/type/flow/lifetime validation remains;
  version JSON adds `array_slice_parameters: true`. Existing profiles, schemas,
  instruction prices and CLI Fuel limits are unchanged. Public calls use the
  shared metered CALL, dynamic slice dispatch and normal/error cleanup.
  Development and release each passed eleven native groups and 2,605 CLI cases,
  with 373 matching input hashes and retained CLI identities. Full native suites
  and Linux were not rerun.
  See [the public parameter contract](docs/engineering/m2-array-slice-parameters-public.md).

- Shared VM slice lifecycle: implemented at `eb8fcdd`.
  The shared execution loop tracks function/frame context, uses dynamic slice
  dispatch, and cleans borrowed roots before scalar/array/record returns.
  Invocation cleanup drains loans before clearing root bindings, preserving
  the original outcome or surfacing cleanup failure with metadata retained.
  Public borrowed execution remains gated; native integration exercises the
  shared loop after independent inspection. Public gate/CLI promotion is next.
  Development and release each passed five native groups and 2,541 CLI cases,
  with 372 matching input hashes and retained CLI identities.
  See [the lifecycle contract](docs/engineering/m2-array-slice-lifecycle-vm.md).

- Gated VM CALL frame publication: implemented at `89bd0bf`.
  CALL now uses mixed owner/borrow admission, stages at most eight scalar values,
  and publishes scalar arguments and child return metadata only after success.
  Non-scalar positions remain untouched. Public borrowed execution stays gated;
  dynamic slice dispatch and automatic normal/error cleanup are the next slice.
  Development and release each passed four native groups and 2,297 CLI cases,
  with 369 matching input hashes and retained CLI identities.
  See [the CALL frame contract](docs/engineering/m2-array-call-frame-vm.md).

- Parser stack containment: implemented at `10822ee` and `6cbe716`.
  Separate statement, identifier and local-read handlers keep unrelated scratch
  off recursive paths. Mixed-arm depth 10 and scalar-call depth 32 remain valid;
  excessive nesting returns `compile_limit`. Both Windows profiles passed six
  focused native groups and 2,335 CLI cases (full M1: 2,007; relevant M2: 328),
  with 127 matching input hashes. The full 84-group native suite, other M2
  matrices and Linux were not rerun. This resolves the parser follow-up from
  the historical toolchain adoption below without changing its evidence.
  See [the parser contract](docs/engineering/m1-parser-stack.md).

- Fairy C toolchain adoption: implemented at `465e380`.
  The compiler is now `eb274643` with SDK `0.0.0-stage0.87`; language `/20`
  and runtime ABI `/0` remain unchanged. Root and M0 SDK locks were adopted
  together. Windows exact-source reproduction and eleven provisioning cases pass;
  Linux is cross-built with static ELF/build-metadata checks only.
  Development M1 exposed a pre-existing parser stack overflow on
  `arm-depth-mixed-10`, reproduced in both old/new images with identical Brownie
  source bytes. The full development M1 matrix is not a pass. Both profiles
  passed nine native groups; development passed 526 M2 CLI cases, and release
  passed 2,495 CLI cases including all 1,969 M1 cases. Further verification
  and its limits are recorded in [the adoption contract](docs/engineering/toolchain-setup.md).

- Private dynamic slice instruction adapter: implemented at `af8ad1e`.
  Borrowed and derived u8 sites now resolve full-width owner tokens from the
  function/frame context for length, read, UTF-8, subslice and close. Retained
  children work after formal close. Fixed metadata Fuel precedes runtime root
  resolution; UTF-8 prepays the actual full-origin length before reading bytes.
  Owned sites retain existing dispatch and prices. Executable VM wiring and
  automatic normal/error cleanup remain pending; the execution gate is unchanged.
  Development and release each passed seven native groups and 326 tool-free CLI
  invocations, with 337 matching input hashes and retained CLI binaries.
  See [the dynamic slice contract](docs/engineering/m2-array-slice-frame-vm.md).

- Private mixed owned/borrowed CALL admission: implemented at `6282245`.
  Borrowed retention now prepares an unpublished pool/argument plan. Atomic owned
  array/record copying runs next; only success publishes retained tickets and
  origins. Complete Fuel combines the existing base/scalar, owned and borrowed
  costs once. Failures preserve original metadata and backing bytes without a
  payload clone or full frame snapshots. Executable dispatch and automatic VM
  cleanup remain pending, so the borrowed-signature gate is unchanged.
  Development passed 21 native groups; release passed nine focused native groups
  after the combined 21-group command timed out at 600 seconds. Both profiles
  passed 326 tool-free CLI invocations, with 335 matching input hashes.
  See [the mixed CALL contract](docs/engineering/m2-array-mixed-call-vm.md).

- Private metered borrowed-frame adapter: implemented at `c70abfa`.
  A separate native context binds dynamic roots by frame/formal ordinal. Entry
  prepays retention and cleanup, validates every original caller ticket, then
  atomically publishes independent child handles and root bindings. Cleanup stages
  all frame closes before clearing bindings; caller tickets and payload survive.
  Retained children remain forwardable after anchor close. This adapter is not
  connected to executable dispatch or mixed aggregate copies; the gate remains.
  Development and release each passed 16 native groups and 326 tool-free CLI
  invocations. See [the frame adapter contract](docs/engineering/m2-array-slice-call-vm.md).

- Independent borrowed slice flow inspection: implemented at `b6b5525`.
  `verifier.inspect` uses the shared validator to check formal entry masks,
  rootless reads/subranges/cleanup, exact join/backedge live sets, mixed CALL
  argument kinds and nonescaping normal exits. Borrowed positions never become
  scalar values; retained children can outlive closed formal tickets. Execution
  verify and VM/CLI admission retain the early borrowed-signature gate. No VM
  frame, opcode, Fuel or capability is enabled. Development and release each
  passed 16 native groups and 326 tool-free CLI invocations.
  See [the flow inspection contract](docs/engineering/m2-array-slice-borrow-flow.md).

- Gated borrowed slice source parameters: implemented at `8278682`.
  Source lowering accepts readonly `ref u8[]` formals and explicit `ref name`
  arguments over existing lexical slices, including forward/recursive forms and
  mixed scalar/array/record signatures. Formal-derived bindings use rootless
  origins and existing reverse cleanup. The core verifier still rejects every
  borrowed signature before runtime admission; CLI check/run return verification
  errors. No borrowed CALL execution or new opcode/Fuel/capability is enabled.
  Development and release each passed 19 native groups and 326 tool-free CLI
  invocations. See [the source contract](docs/engineering/m2-array-slice-parameter-source.md).

- Private borrowed slice instruction builders: implemented at `d001a75`.
  Existing UTF-8, length, read, close and subslice helpers now construct typed IR
  for rootless u8 formal/derived sites. Shape checks require one same-function
  formal; subslices require a derived destination and matching origin/function.
  Validation and capacity failures preserve IR. Owned-root open remains private
  to owned sites, and the core execution gate remains unchanged. No guest syntax,
  VM dispatch, Fuel or capability is enabled. Development and release each passed
  19 native groups and 252 tool-free CLI invocations.
  See [the instruction builder contract](docs/engineering/m2-array-slice-borrow-ir.md).

- Private borrow-aware slice IR builders: implemented at `d776d1d`.
  Owned, formal and derived sites share one collision-free sixteen-site lookup.
  Formal declarations reserve non-scalar positions; derived declarations flatten
  origins to the same-function formal. Checked live argument helpers return the
  existing CALL-table encoding. Admission failures preserve prior declarations.
  The execution gate remains; guest signatures, borrowed instruction lowering,
  VM CALL/frame transactions and metering are pending. No capability changes.
  Development and release each passed 15 native groups and 252 tool-free CLI
  invocations. See [the builder contract](docs/engineering/m2-array-slice-builders.md).

- Private borrowed slice parameter origins: implemented at `3f678ca`.
  Bounded formal-position, formal/derived origin and function metadata share the
  existing sixteen slice sites, with exclusive parameter kinds and independent
  liveness/ownership checks for proposed u8 call arguments. Entry masks do not
  claim owned array roots. The core verifier checks then rejects declared borrow
  parameters before VM backing/Fuel/dispatch until runtime integration exists.
  Existing source Programs keep zero metadata; no source syntax, opcode, Fuel
  price or version capability is enabled. Development and release each passed
  20 native groups and 252 tool-free CLI invocations.
  See [the origin contract](docs/engineering/m2-array-slice-parameters.md).

- Private atomic slice argument batches: implemented at `515c274`.
  Up to eight incoming tickets are validated against the original pool before
  staging independent whole-range handles sharing their existing read sessions.
  Reverse-order batch cleanup stages both metadata tables; late failures preserve
  the original tables, generations and batch. Caller/peer handles survive.
  No payload copy, new owner, opcode, Fuel price or version capability is added.
  This is an unmetered native foundation: source slice parameters/results,
  dynamic parameter origins, CALL/frame integration and mixed argument
  transactions remain pending. Development and release each passed 14 native
  groups and 252 tool-free CLI invocations.
  See [the batch contract](docs/engineering/m2-array-slice-arguments.md).

- Checked read-only slice aliases: implemented at `1ed056f`.
  `let ref u8[] other = ref part;` reborrows the complete retained range through
  the same checked length/subslice/close lowering as `ref part[..]`. Each alias
  receives an independent handle sharing the root session; no payload copy,
  owner, opcode or Fuel price is added. Aliases remain immutable and lexical,
  using one static site, live handle and lexical entry. Version JSON adds
  `array_slice_alias: true`. Development and release each passed 15 native
  groups and 500 tool-free CLI invocations. Slice
  parameters/results, mutable/non-u8 slices, temporary roots and general slice
  expressions remain unavailable. See [the alias contract](docs/engineering/m2-array-slice-alias.md).

- Checked read-only subslice bindings: implemented at `f1216c3` on VM
  foundation `5b37d6b`. `let ref u8[] child = ref parent[start..end];` supports
  parent-relative computed/open/empty/nested ranges. Private opcode 59 validates
  the live parent and shared root before publishing one independent handle,
  without copying payload or adding an owner. Parent close preserves children;
  the last handle restores writes. It prepays 65537 Fuel; omitted ends also use
  the existing 4097-Fuel checked length getter. Version JSON adds
  `array_slice_sub: true`. Development and release each passed 19 native groups
  and 670 tool-free CLI invocations. Slice parameters/results, mutable slices
  and temporary roots remain unavailable.
  See [the subslice contract](docs/engineering/m2-array-slice-sub.md).

- Checked read-only slice indexing: implemented at `b7eda85` on VM foundation
  `74ce29c`. `part[index]` evaluates an ordinary usize index once and returns a
  fresh u8 snapshot. Private opcode 58 validates the active origin, ticket,
  session, range, backing and selected-length bound before publication. Reads
  preserve lexical loans and prepay 4131 Fuel for u8; existing prices stay
  unchanged. Version JSON adds `array_slice_index: true`. Development and
  release each passed 27 native groups and 546 tool-free CLI invocations.
  Slice parameters/results, mutable slices and temporary
  roots remain unavailable. See [the indexing contract](docs/engineering/m2-array-slice-index.md).

- Checked slice length: implemented at `f56e4aa`.
  `part.len` returns a fresh usize byte count through private opcode 57, after
  active origin/ticket/session/range/backing validation, including empty ranges.
  The getter prepays 4097 Fuel, does not scan/copy payload or reexecute bounds,
  and preserves root loans. Existing cleanup and ordinary array length prices
  are unchanged. Version JSON adds `array_slice_length: true`. Development and
  release each passed 21 native groups and 360 tool-free CLI invocations.
  Slice parameters/results and temporary
  roots remain unavailable. See [the length contract](docs/engineering/m2-array-slice-length.md).

- Lexical read-only u8 slices: implemented at `718ab34`.
  `let ref u8[] part = ref bytes[start + 1..bytes.len];` supports named u8
  locals/parameters/results and `text::valid_utf8(part)`. Ordinary usize bounds
  evaluate before publication. Reverse-order cleanup closes loans on block,
  value-arm and return/question/break/continue exits, including aggregate returns.
  Borrowed-root writes/fills/assignments are source type errors; reads/copies
  remain allowed. No payload copy, extra owner, opcode or Fuel schedule is added.
  Version JSON adds `array_utf8_slices: true`. Development and release each
  passed 29 native groups and 762 tool-free CLI invocations. Slice
  parameters/results and borrowing temporaries remain
  unavailable. Sixteen static sites and 64 lexical entries remain bounded.
  See [the source slice contract](docs/engineering/m2-array-utf8-slices.md).

- Private metered slice VM: implemented at `272f359`.
  Opcodes 54/55/56 open, scan and close function-local slice sites. Independent
  verification tracks exact live sets through branches/backedges and blocks
  borrowed-root mutation, release and transfer. Invocation cleanup drains all
  remaining sessions after success or VM error, preserving the original outcome
  when cleanup succeeds. Open prepays cleanup; no source capability is added.
  Development and release each passed 39 native groups and 14 tool-free CLI
  sentinels. Guest slice syntax and automatic lexical lowering remain pending.
  See [the slice VM contract](docs/engineering/m2-array-slice-vm.md).

- Private shared read-only array slices: implemented at `12071a8`.
  Sixteen independently closable range handles share one explicit session per
  root. Parent cleanup preserves children/peers; the final close unlocks the
  root. Admission failures preserve both tables; whole-pool clear stages only
  metadata. Generations never wrap; no payload copy or extra owner is added.
  Development and release each passed 28 native groups and 14 tool-free CLI
  sentinels. Guest slice syntax, independent IR borrow verification, automatic
  lexical cleanup and metering remain pending; no version capability changes.
  See [the slice registry contract](docs/engineering/m2-array-slices.md).

- Computed UTF-8 endpoints on temporary arrays: implemented at `62ad15f`.
  `text::valid_utf8(make()[start + 1..end()])` and repeated-literal ranges
  reuse ordinary usize expressions. Computed suffixes capture the published
  owner anonymously for existing reverse-order cleanup on return, question
  propagation, continue and break; normal completion scans then immediately drops.
  Simple suffixes retain their code, Fuel and binding requirements. The computed
  path needs one entry in the existing 64-binding table; nested temporaries need
  overlapping capacity. No extra root owner or payload copy is added. Version
  JSON adds `array_utf8_temporary_computed_ranges: true`. Development and
  release each passed 23 native groups and 1,518 CLI invocations.
  General slices and persistent borrows remain unavailable. See
  [the source contract](docs/engineering/m2-array-utf8-temporary-computed-ranges.md).

- Computed UTF-8 range endpoints: implemented at `b2ce341` on named live u8 arrays.
  `text::valid_utf8(a[start + 1..a.len])` reuses ordinary usize expression
  parsing with once-only left-to-right evaluation and existing exit cleanup.
  Calls, scalar fields, indexed reads, widening casts and switches are supported.
  Original literal/name forms retain their code and Fuel; computed forms use
  existing opcode 53 after ordinary endpoint evaluation, with no new root owner
  or payload copy. Version JSON adds `array_utf8_computed_ranges: true`.
  Development and release each passed 23 native groups and 1,794 CLI
  invocations. Computed temporary bounds were unavailable at this checkpoint;
  the successor above now supports them. Persistent borrows remain unavailable.
  See [the source contract](docs/engineering/m2-array-utf8-computed-ranges.md).

- Dynamic UTF-8 ranges on temporary arrays: implemented at `bb7476a`.
  `text::valid_utf8(make()[lo..hi])` and
  `text::valid_utf8([value; N][lo..hi])` accept
  scalar `usize` local/parameter endpoints, mixed literals and omitted bounds.
  Arguments/fillers finish before mutable bounds load; the scan immediately
  drops its temporary. No extra owner, payload copy or retained lease is added.
  The shared parser retains static opcode 52 and dynamic opcode 53 with existing
  Fuel prices. Version JSON adds `array_utf8_temporary_dynamic_ranges: true`.
  Development and release each passed 23 native groups and 1,646 CLI
  invocations. Endpoint expressions were unavailable at this checkpoint;
  the successor above accepts them on named arrays. Computed temporary bounds
  and persistent borrows remain unavailable. See [the source contract](docs/engineering/m2-array-utf8-temporary-dynamic-ranges.md).

- Named-array dynamic UTF-8 ranges: implemented at `9bb31ed`.
  `text::valid_utf8(a[lo..hi])` accepts existing scalar `usize` locals and
  parameters, mixed literal bounds and omitted endpoints on named live u8 arrays.
  Mutable names load their current value; immutable names reuse their register.
  Opcode 53 prepays `65 + 4*N` for the full root, with runtime bounds errors
  and no owner, payload copy or retained lease. Static forms keep opcode 52.
  Version JSON adds `array_utf8_dynamic_ranges: true`. Dynamic temporaries
  were unavailable at this checkpoint; the successor above now supports them.
  Endpoint expressions and persistent borrows remain unavailable.
  Development and release each passed 24 native groups and 1,114 CLI
  invocations. See
  [the source contract](docs/engineering/m2-array-utf8-dynamic-ranges.md).

## Project role

This repository owns the Brownie C design baseline and its native M0 probes and experimental M1 scalar CLI. The project is primarily Fairy C with small explicit allocator, codec, and
operating-system shims where needed.

Read the nearest user instruction, this file, VALIDATION.md, and the documents that
own the affected contract. Broader scaffold procedures are optional.

## Current state

- Register-bounded UTF-8 ranges: private VM foundation implemented at `4a076e5`
  and verified in development/release, each with 30 native groups and 18 CLI
  invocations. Opcode 53 takes `a` as the array catalog ID,
  `b` as the start `usize` register and byte 4 as the end `usize` register,
  producing a fresh bool. It prepays the full root length `65 + 4*N` before
  reading endpoint cells and reuses the checked view scan with no owner, payload
  copy or retained lease. Guest syntax was unavailable at that checkpoint;
  the named-array source successor above now exposes scalar usize bounds. See
  [the dynamic-range foundation](docs/engineering/m2-array-dynamic-utf8.md).

- Open-ended UTF-8 ranges: implemented at `c7830fc` and verified in
  development/release, each with 12 native groups and 1102 CLI cases.
  `text::valid_utf8(a[..])`, `a[..END]` and `a[START..]` accept omitted bounds
  for named `u8` arrays, direct call results and repeated-byte literals; the
  missing bound becomes 0 or the catalog length at compile time, reusing opcode
  52 with `65 + 4*K` Fuel and adding no register, owner or payload copy. Version
  JSON adds `array_utf8_open_ranges: true`. General slices, dynamic bounds and
  persistent borrows remain deferred. See
  [the open-range contract](docs/engineering/m2-array-utf8-open-ranges.md).

- UTF-8 ranges on temporary arrays: implemented at `d70da59` and verified in
  development/release, each with 16 native groups and 832 CLI cases.
  `text::valid_utf8(make()[S..E])` and `text::valid_utf8([value; N][S..E])`
  scan a literal range of a temporary and drop it immediately after the existing
  opcode 52, with no new opcode, Fuel price or second owner. Empty ranges still
  evaluate their filler and arguments once. Version JSON adds
  `array_utf8_temporary_ranges: true`. Dynamic endpoints, repeated slicing and persistent
  borrows remain deferred. See [the temporary-range contract](docs/engineering/m2-array-utf8-temporary-ranges.md).

- Named-array UTF-8 ranges: implemented at `92feb5e` and verified in
  development/release, each with 15 native groups and 582 CLI cases.
  `text::valid_utf8(a[START..END])` accepts a named live `u8` array (local,
  parameter or named array result) with explicit literal endpoints in 0..4096 and
  `start <= end <= length`. It reuses opcode 52 with prepaid `65 + 4*K` Fuel and
  adds no owner, payload copy or retained borrow. Version JSON adds
  `array_utf8_ranges: true`. Dynamic and persistent-borrow ranges remain
  deferred. See [the range-source contract](docs/engineering/m2-array-utf8-ranges.md).

- Private array range UTF-8 instruction: implemented at `65af78d` and verified
  in development/release, each with 41 native groups and 14 CLI cases. Opcode 52
  checks a literal half-open
  u8 range without a payload copy, new owner or retained lease. It prepays
  `65 + 4*K` Fuel for K selected bytes and preserves the source owner.
  Independent verification checks function ownership, liveness, destination
  and range bounds. Guest range syntax now comes from the range-source successor
  above; persistent borrows remain pending.
  See [the range VM contract](docs/engineering/m2-array-range-utf8.md).

- Explicit array read sessions: implemented at `f85bd4d` and verified in
  development/release, each with 34 native groups and 14 CLI cases. One session per root allows
  multiple range reads while blocking write/fill/destination assignment, result
  transfer, release and clear. Value copies stay allowed and start unleased.
  Old tickets cannot end a new session. Guest origins, automatic scope cleanup
  and metering remain pending.
  See [the session contract](docs/engineering/m2-array-read-leases.md) for verification and limits.

- Private checked array views: implemented at `0c22fb8` and verified in development/
  release, each with 16 native groups and 14 CLI cases. Range descriptors support
  scalar reads, subviews and selected u8 UTF-8 checks without payload copies or
  new owner slots. Every use revalidates current metadata and backing bounds.
  Descriptors do not pin roots or enforce borrow conflicts; guest integration,
  metering and origin table/backing association remain separate obligations.
  See [the range contract](docs/engineering/m2-array-views.md) for verification and limits.

- Direct UTF-8 repeated-byte literals: implemented at `3d569fa` and verified in
  development/release, each with 13 native groups and 380 CLI cases.
  `text::valid_utf8([value; N])` evaluates
  its u8 filler once before publishing one temporary array, then scans and drops
  it immediately. Pending filler exits create no owner; nested temporaries reuse
  capacity. Version JSON adds `array_utf8_literals: true`.
  See [the literal contract](docs/engineering/m2-array-utf8-literals.md) for verification and limits.

- Direct UTF-8 array-result calls: implemented and verified in development/release,
  each with 13 native groups and 356 CLI cases. `text::valid_utf8(make(...))` reuses ordinary
  CALL/ARET, scans once and immediately drops its anonymous result. Argument
  exits retain existing cleanup; no result payload copy is added. Version JSON
  adds `array_utf8_call_results: true`.
  See [the call-result contract](docs/engineering/m2-array-utf8-calls.md) for verification and limits.

- Source u8-array UTF-8 predicate: implemented and verified in development/release,
  each with 18 native groups and 256 CLI cases. `text::valid_utf8(bytes)` lowers to opcode 51
  without an array copy or extra owner. Named locals, parameters and array-result
  bindings are supported. Direct temporary calls were unavailable at that checkpoint;
  the successor above now accepts them. Buffer/text APIs remain unavailable. Version JSON adds `array_utf8_predicate: true`.
  See [the source contract](docs/engineering/m2-array-utf8-source.md) for verification and limits.

- Private u8-array UTF-8 opcode: implemented and verified in development/release,
  each with 25 native groups (6 new, 19 regressions) and 8 CLI sentinels.
  Opcode 51 independently verifies a live function-owned u8 array and bool
  result, prepays 33+4*length Fuel and preserves payload/ownership. Guest
  syntax and version capabilities were unchanged at that checkpoint; the source
  successor above now exposes the named-array predicate.
  See [the UTF-8 VM contract](docs/engineering/m2-array-utf8.md).

- Host shutdown descriptor sweep: implemented and verified in development/release,
  each with 99 native scenarios; all 198 processes exit with zero tracked live
  allocations. Existing owners are enumerated in descending slot order; failed
  preflight advances the pass, pending accounting pins its offer, and explicit
  retry revisits survivors. Native resources remain host-owned.
  See [the sweep contract](docs/engineering/m2-buffer-host-sweep.md).

- Explicit multi-root host shutdown visitation: implemented and verified in
  development/release, each with 95 native scenarios; all 190 processes exit
  with zero tracked live allocations. Independently writable roots close during
  partial lease cleanup; one shared pending close Plan blocks other closes
  until settled. Completion requires no live owners or pending accounting.
  See [the visitation contract](docs/engineering/m2-buffer-host-batch.md).

- Explicit single-root host shutdown: implemented and verified in development/
  release, each with 91 lifecycle/allocator scenarios; all 182 processes exit
  with zero tracked live allocations. One ownership-taking call drains sessions,
  destroys the selected native root and refunds its charge. Preflight errors
  return ownership; failed finish retains the Plan for accounting-only retry.
  Provider regressions also passed 16 processes. Full Instance wiring is pending.
  See [the host close contract](docs/engineering/m2-buffer-host-close.md).

- Buffer Provider inconsistency injection: verified in development and release,
  each with four injected faults and four no-fault controls; all 16 processes
  exit with zero tracked live allocations. Capacity/copy/append/resize failures
  preserve the old root/token and registry charge, clean unpublished storage,
  restore reservations, and allow explicit retry. Product Fairy sources unchanged.
  See [the provider probe](docs/engineering/m2-buffer-provider.md).

- Private UTF-8 registry storage admission: implemented and verified in development/
  release, each with 87 native scenarios (4 new, 83 regressions); all 174 processes
  exit with zero tracked live allocations. Each active Pool reserves 2,112 logical
  bytes against Instance/Engine limits before use. Failed shutdown keeps its charge;
  completed shutdown refunds once and preserves peaks. No new heap allocation.
  See [the admission contract](docs/engineering/m2-buffer-utf8-admission.md).

- Private UTF-8 registry shutdown: implemented and verified in development/release,
  each with 83 native scenarios (4 new, 79 regressions); all 166 processes exit
  with zero tracked live allocations. One-way Open/Closing/Closed state blocks
  admission and scan progress once shutdown starts; failures remain retryable.
  Explicit host hook only; automatic Instance teardown/VM wiring is pending.
  See [the shutdown contract](docs/engineering/m2-buffer-utf8-shutdown.md).

- Private host UTF-8 session registry: implemented and verified in development/
  release, each with 79 native scenarios (4 new, 75 regressions); all 158 processes
  exit with zero tracked live allocations. Sixteen fixed slots retain sessions,
  generation tickets reject stale operations, and batch cleanup retains failures
  for retry. No extra heap allocation; the explicit shutdown successor is above.
  Automatic Instance teardown and VM integration remain pending.
  See [the registry contract](docs/engineering/m2-buffer-utf8-pool.md).
- Private leased UTF-8 sessions: implemented and verified in development/release,
  each with 75 native scenarios (4 new, 71 regressions); all 150 processes exit
  with zero tracked live allocations. Sessions acquire a read lease, retain it
  on Fuel shortage and release it on completion, scan error, cancellation or
  explicit abandonment. Cleanup failures retain ownership; VM/guest wiring is pending.
  See [the session contract](docs/engineering/m2-buffer-utf8-session.md).
- Private Buffer read leases: implemented and verified in development and release,
  each with 71 instrumented native scenarios (4 new, 67 regressions); all 142
  processes exit with zero tracked live allocations. A leased owner permits reads
  and rejects descriptor-aware writes, resizing, replacement, close and release.
  Acquisition/release are explicit; guest borrow enforcement remains unfinished.
  See [the read-lease contract](docs/engineering/m2-buffer-read-lease.md).
- Private cooperative UTF-8 scan cancellation: implemented and verified in
  development and release, each with 67 native scenarios (4 new, 63 regressions);
  all 134 processes exit with zero tracked live allocations. A caller-supplied
  cancellation snapshot retires scan progress before Fuel or byte access, without
  changing Buffer storage or reservation accounting. VM/scheduler wiring is pending.
  See [the cancellation contract](docs/engineering/m2-buffer-utf8-cancel.md).
- Private prepaid Buffer UTF-8 scanning: implemented and verified in development
  and release, each with 63 native scenarios (4 new, 59 regressions); all 126
  processes exit with zero tracked live allocations. Begin costs 128 Fuel; each
  step prepays `128 + 4*min(request,256)` before validation. Short budgets preserve
  progress and Fuel; admitted errors keep their charge. VM/guest wiring is pending.
  See [the metered contract](docs/engineering/m2-buffer-utf8-meter.md).
- Private resumable Buffer UTF-8 scanning: implemented and verified in development
  and release, each with 59 native scenarios (4 new, 55 regressions); all 118
  processes exit with zero tracked live allocations. Each call processes at most
  256 new bytes, retaining at most three suffix bytes across calls. No allocation;
  stable content remains a caller obligation. Its prepaid successor is above;
  VM and guest integration remain pending.
  See [the scan contract](docs/engineering/m2-buffer-utf8-scan.md).
- Private Buffer UTF-8 validation: implemented and verified in development and
  release, each with 55 native scenarios (4 new, 51 regressions); all 110 processes
  exit with zero tracked live allocations. Token/table/backing checks precede an
  allocation-free SDK scan of initialized bytes. Results are not cached; the
  resumable successor is described above. Fuel and guest integration are pending.
  See [the UTF-8 contract](docs/engineering/m2-buffer-utf8.md).
- Private Buffer writes before replacement publication: implemented and verified
  in development and release, each with 51 native scenarios (4 new, 47 regressions);
  all 102 processes exit with zero tracked live allocations. Writes validate full
  transaction snapshots, native metadata, current quotas and initialized bounds.
  The old root, Plan, table and ledger remain unchanged; writes add no allocation.
  See [the prepared-write contract](docs/engineering/m2-buffer-prepared-write.md).
- Private Buffer writes within initialized length: implemented and verified in
  development and release, each with 47 native scenarios (4 new, 43 regressions);
  all 94 processes exit with zero tracked live allocations. Complete preflight
  includes ledger and current-quota checks even for empty input; this guarded
  path rejects pending growth with State. No allocation, resize, token/generation
  or accounting change. The Windows receipt is archived.
  See [the write contract](docs/engineering/m2-buffer-write.md).
- Private Buffer bulk copy-out: implemented and verified in development and
  release, each with 43 native scenarios (4 new, 39 regressions); all 86 processes
  exit with zero tracked live allocations. Copies initialized binary bytes into
  distinct caller-owned native output after token, full-table, exact backing
  metadata and overflow-safe range checks. No allocation, token/generation,
  metadata or ledger change. The Windows receipt is archived.
  See [the copy-out contract](docs/engineering/m2-buffer-copy-out.md).
- Empty Buffer registration: implemented and verified in development and release,
  each with 39 native scenarios (4 new, 35 regressions); all 78 processes exit
  with zero tracked live allocations. Each registration
  admits a 64-byte logical owner without payload allocation. Multiple empty roots
  and registration after final close share caller-managed accounting.
  See [the create contract](docs/engineering/m2-buffer-create.md).
- Buffer grow-and-resize preparation: implemented and verified in development and
  release, each with 35 native scenarios (7 new, 28 regressions); all 70 processes
  exit with zero tracked live allocations. Growth-only
  preparation preserves the old root and zeroes the unpublished replacement's
  new bytes. Publication and metadata commit remain explicit caller steps.
  See [the grow-and-resize contract](docs/engineering/m2-buffer-grow-resize.md).
- Buffer resize within retained capacity: implemented and verified in development
  and release, each with 28 native scenarios (4 new, 24 regressions); all 56
  processes exit with zero tracked live allocations.
  Shrinking preserves the prefix; growing zeroes newly exposed bytes. Capacity
  and accounting stay unchanged; equal length retains the token without SDK work.
  See [the resize contract](docs/engineering/m2-buffer-resize.md).
- Buffer truncate and clear: implemented and verified in development and release,
  each with 24 native scenarios (4 new, 20 regressions); all 48 processes exit
  with zero tracked live allocations. Shortening advances generation once;
  equal length retains the token. Capacity and accounting stay unchanged.
  See [the truncate contract](docs/engineering/m2-buffer-truncate.md).
- Buffer grow-and-append preparation: implemented and verified in development
  and release, each with 20 native scenarios (7 new, 13 lifecycle/allocator
  regressions). Growth-only preparation appends into an unpublished replacement
  and commits its initialized length/capacity after caller publication. The old
  root remains live for self-append and rollback; publication is still explicit.
  See [the grow-and-append contract](docs/engineering/m2-buffer-grow-append.md).
- Buffer close accounting: implemented and verified in development and release,
  each with 13 native scenarios (4 close, 9 append/allocator regressions).
  Begin retires the token while keeping its charge; after native root destruction,
  finish validates snapshots and releases payload plus logical owner usage.
  Native destruction order remains the trusted caller's responsibility.
  See [the close contract](docs/engineering/m2-buffer-close.md).
- Buffer append within admitted capacity: implemented and verified in development
  and release, each with 9 native scenarios (4 append, 5 allocator regressions).
  Nonempty append updates initialized length and token generation without changing
  capacity/accounting. Instrumented append cases allocate only the initial root.
  Guest Buffer syntax and VM integration remain future work.
  See [the append contract](docs/engineering/m2-buffer-append.md).
- Buffer allocator-failure probe: verified in development and release, each with
  5 native scenarios. Forced 320/384-byte allocation failures preserve the original
  data, token, inactive Plan and restored usage; explicit retries then commit.
  Every scenario exits with zero outstanding allocations at the instrumented
  FY system-heap seam. Runtime sources are unchanged by this verification slice.
  See [the failure probe](docs/engineering/m2-buffer-failure.md).
- Buffer replacement transactions: implemented and verified in development and
  release, each with 31 native groups (8 replacement, 23 regressions) and 8 CLI
  sentinels. Both invocations rechecked 259 identical inputs.
  Private preparation keeps the original token live; completion rechecks full
  descriptor/accounting snapshots before updating generation and final charges.
  Owning-root publication remains an explicit trusted caller step.
  See [the replacement contract](docs/engineering/m2-buffer-replacement.md).
- Buffer owner descriptors: implemented and verified in development and release,
  each with 23 native groups (8 descriptors, 7 storage, 8 admission) and 8 CLI
  sentinels. Both invocations rechecked 256 identical inputs.
  Private table-local slot/generation tokens guard initialized byte access;
  release invalidates tokens and exhausted generations retire their slots.
  Native root association and lifetime remain trusted caller responsibilities.
  Guest Buffer syntax, borrow tracking and VM integration remain future work.
  See [the descriptor contract](docs/engineering/m2-buffer-owners.md).
- Native Buffer storage: implemented and verified in development and release,
  each with 15 native groups (7 storage, 8 admission) and 8 CLI sentinels.
  Both invocations rechecked 253 identical inputs.
  Private replacement allocation copies initialized bytes while preserving the
  original root. Publication/commit and discard/cancel remain explicit caller steps.
  Guest Buffer syntax, owner tokens and VM integration remain future work.
  See [the storage contract](docs/engineering/m2-buffer-storage.md).
- Buffer growth admission: implemented at `3f99138` and verified in
  development and release, each with 8 native groups and 8 CLI sentinels. Both
  invocations rechecked 250 identical inputs.
  Private capacity planning and begin/commit/cancel accounting include old-plus-new
  payload and owner charges, with minimum-capacity fallback at quota ceilings.
  Guest Buffer syntax, allocation, move/borrow and VM integration remain future
  work. See [the foundation](docs/engineering/m2-buffer-growth.md).
- Returned subrecords in constructor fields: implemented at `c0d6217` and verified in
  development and release, each with 16 native groups and 442 CLI cases. Both
  combined invocations rechecked 247 identical inputs.
  `Box { .child = make().child }` stages only the selected exact-nominal leaves
  and releases the returned root before later fields. Declarations, replacement
  and constructor returns share this path. See [the source contract](docs/engineering/m2-struct-child-call-paths.md).
- Returned subrecords as direct returns: implemented at `c789300` and verified in
  development and release, each with 16 native groups and 444 CLI cases. Both
  combined invocations rechecked 244 identical inputs.
  `return make().child;` and deeper exact-nominal paths release the returned
  parent before creating the child, then use existing mixed return cleanup.
  See [the source contract](docs/engineering/m2-struct-call-path-returns.md).
- Returned subrecords as assignment values: implemented at `2971169` and verified in
  development and release, each with 16 native groups and 440 CLI cases. Both
  combined invocations rechecked 241 identical inputs.
  See [the source contract](docs/engineering/m2-struct-call-path-assignment.md).
- Returned subrecords as declaration initializers: implemented at `e38f00a` and verified in
  development and release, each with 22 native groups and 537 CLI cases. Both
  combined invocations rechecked 238 identical inputs.
  `let Point p = make().child;` and `var` create an independent exact-nominal
  child after releasing the returned root. Pending names remain invisible until
  CALL, path and delimiter validation finish. See [the source contract](docs/engineering/m2-struct-call-path-declarations.md).
- Returned subrecords as arguments: implemented at `7284da8` and verified in
  development and release, each with 17 native groups and 410 CLI cases. Both
  combined invocations rechecked 235 identical inputs.
  `take(make().child)` snapshots the exact-nominal child, releases the returned
  root before child creation, and reuses existing mixed argument cleanup.
  See [the source contract](docs/engineering/m2-struct-call-path-arguments.md).
- Direct record call-result scalar reads: implemented at `aee9885` and verified in
  development and release, each with 16 native groups and 374 CLI cases. Both
  combined invocations rechecked 232 identical inputs.
  `make().x` and deeper scalar field paths read the returned value, then
  immediately release its anonymous root through existing SREAD/SDROP.
  See [the source contract](docs/engineering/m2-struct-call-reads.md).
- Direct array call-result reads: implemented at `b822089` and verified in
  development and release, each with 18 native groups and 335 CLI cases. Both
  combined invocations rechecked 229 identical inputs.
  `make()[INDEX]` and `make().len` release the anonymous result after producing
  the scalar; index-expression exits use existing mixed cleanup.
  See [the source contract](docs/engineering/m2-array-call-reads.md).
- Repeated array literals as arguments: implemented at `ea6854f` and verified in
  development and release, each with 20 native groups and 344 CLI cases. Both
  combined invocations rechecked 226 identical inputs.
  `take([EXPR; N])` evaluates the filler once before publishing an anonymous
  immutable capture. Existing mixed cleanup handles calls and early exits.
  See [the source contract](docs/engineering/m2-array-literal-arguments.md).
- Array call results as arguments: implemented at `03795b9` and verified in
  development and release, each with 29 native groups and 507 CLI cases. Both
  combined invocations rechecked 223 identical inputs.
  `take(make_array())` and nested exact-shape calls join the existing mixed
  argument capture cleanup after CALL. Element type and length must match;
  visible local callee shadowing is rejected. See [the source contract](docs/engineering/m2-array-result-arguments.md)
  and the [Windows receipt](docs/evidence/m2-array-result-arguments-windows-20261028.json).
- Record constructors as arguments: implemented at `bd9db83` and verified in
  development and release, each with 26 native groups and 874 CLI cases. Both
  combined invocations rechecked 220 identical inputs.
  `take(Point { .x = 42 })` stages fields in declaration order before creating
  an anonymous immutable capture; existing mixed cleanup handles calls and early
  exits. See [the source contract](docs/engineering/m2-struct-constructor-arguments.md) and the
  [Windows receipt](docs/evidence/m2-struct-constructor-arguments-windows-20261028.json).
- Subrecord paths as arguments: implemented at `9650f12` and verified in
  development and release, each with 27 native groups and 570 CLI cases.
  The two successful combined profile invocations rechecked 217 identical inputs.
  An exact-type
  `take(outer.child)` or deeper path stages scalar leaves into an independent
  immutable snapshot before later arguments run. Existing mixed capture cleanup
  handles calls and early exits. See [the source contract](docs/engineering/m2-struct-path-arguments.md)
  and the [Windows receipt](docs/evidence/m2-struct-path-arguments-windows-20261028.json).
- Record call results as arguments: implemented at `7671f25`. A bare exact-type
  `take(make())` or nested `id(id(make()))` uses an anonymous argument capture
  after the inner CALL, then shared reverse mixed cleanup. Development and
  release each passed 29 native groups and 588 CLI cases in separate
  core/regression phases, with 214 matching rechecked inputs.
  See [the source contract](docs/engineering/m2-struct-result-arguments.md) and the
  [Windows receipt](docs/evidence/m2-struct-result-arguments-windows-20261028.json).
- M0 native primitives exist under `probes/m0` and have a repeatable Windows harness.
- The M1 scalar lexer/parser, i32 checks, private IR verifier, VM, and CLI exist in src/.
- Entry-only mutable root constructor assignment is verified in development and release; child constructor assignment is verified in development and release.
- Private function-owned record IR/verifier and frame-local record VM execution
  are verified in development and release.
- Source helper-local records are verified at `98a4525`: 48 native groups and 2,860 CLI cases per development/release profile. Development completed stepwise after tooling fixture fixes; release completed the aggregate. See [the source contract](docs/engineering/m2-struct-function-source.md) and [receipt](docs/evidence/m2-struct-function-source-windows-20261027.json).
- Nominal record parameter signature metadata is verified at `4a6792b` (16 native groups and 2,226 CLI cases per development/release profile). Its pre-lowering source gate is historical and superseded by source record parameter lowering. See [the foundation](docs/engineering/m2-struct-parameter-signatures.md).
- Private record-parameter IR metadata and independent verification are verified at `9b43e0d` (28 native groups and 2,226 CLI cases per development/release profile); its initial VM availability gate and source gate are historical and superseded by metered calls and source lowering. See [the IR foundation](docs/engineering/m2-struct-parameters-ir.md).
- Private mixed array/record argument copies are verified in development and release (70 native groups per profile, 9 new and 61 affected) through `array_owners::copy_call_arguments`; full-batch source validation and owner/payload admission precede mutation. Its statement that source lowering remained unavailable is historical. See [the storage contract](docs/engineering/m2-call-argument-copies.md).
- Private metered record CALL execution is implemented at `97bf1e2`; development and release each passed 47 unique native groups stepwise (21 core, then 26 regressions) with matching 58 input hashes across both receipts. Mixed aggregate copies precede scalar/return-frame publication; existing scalar/array prices remain unchanged. Its source-gate claim is historical and superseded by the source parameter slice. See [the VM contract](docs/engineering/m2-struct-call-vm.md).
- Immutable nominal by-value source record parameters are verified in development and release. Bare exact-type binding arguments are accepted; mutable inputs are captured with `SCOPY` before later arguments evaluate. Development and release each passed 51 native groups (14 core, 37 regressions) and 2,318 CLI cases. See [the source contract](docs/engineering/m2-struct-parameters-source.md).
- A bounded nominal record-result signature foundation was implemented and verified
  for its original baseline (22 native groups and 2,317 CLI cases per profile).
  `return_records` retains ID + 1 in 1..32, while `return_types` remains zero. Its
  blanket rejection of every scanned record result before IR, catalog, or body
  lowering is historical and superseded by the bounded source successor. See
  [the signature contract](docs/engineering/m2-struct-result-signatures.md).
- Private record-result IR and verification are implemented at `dc1574b` and verified in development and release. The
  `u8[16]` `record_results` table stores a callee-owned shape site plus one; `SRET` (50) requires one
  live exact-nominal callee record, and CALL destinations use `144 + site`. Its kind 11 runtime gate is
  historical and is superseded by the VM ownership-transfer successor. See [the IR contract](docs/engineering/m2-struct-results-ir.md).
- Private record-result VM ownership transfer is implemented at `68552f0` and verified for its original inputs.
  `SRET` (50) prepays 42,113 Fuel, checks the child and parent token layout, validates the complete planned
  record through a 128-byte scratch snapshot, clears the child token, and publishes that token in the caller.
  Owner descriptors, order, generations, and payload stay unchanged; no owner or payload is reserved.
  Profiles, version capabilities, and scalar/array prices were unchanged by that VM slice.
  Development and release each passed 34 native groups and 2,317 CLI cases.
  See [the VM contract](docs/engineering/m2-struct-result-vm.md) and
  [Windows receipt](docs/evidence/m2-struct-result-vm-windows-20261028.json).
- Bounded source record results are verified in development and release at
  `bb401a4` with tooling `78a1fb4`. A bare visible
  exact-nominal `return name;` and an explicit `let`/`var` exact-nominal call
  initializer now reach `SRET` and the existing record-result VM. Result anchors
  are reserved before bodies by reusing an exact nominal formal or adding a dead
  function-owned site. Pending initializer names stay invisible until CALL and
  capture cleanup finish. The source finisher drops other mixed arrays and records
  in reverse lexical order before `SRET`. Development and release each passed 14
  native groups and 2,438 CLI cases. The 70 result-signature CLI cases were then
  rerun per profile after a checker-only metadata repair. See [the source
  contract](docs/engineering/m2-struct-result-source.md) and [Windows
  receipt](docs/evidence/m2-struct-result-source-windows-20261028.json), which
  rechecks 219 inputs.
- Direct nominal record return calls are implemented at `c23e6e4`. An exact-type
  `return make(...);` uses the existing CALL/SRET ownership transfer and shared
  reverse mixed cleanup. Pending destinations remain absent from names during
  argument evaluation. Development and release each passed 18 native groups and
  505 CLI cases in separate core/regression phases; 196 input hashes match and
  were rechecked. Earlier receipts remain historical for their original inputs.
  See [the contract](docs/engineering/m2-struct-return-calls.md)
  and [focused receipt](docs/evidence/m2-struct-return-calls-windows-20261028.json).
- Direct nominal record constructor returns are implemented at `0a7b539` and
  verified in development and release. Fields and exact-nominal child values
  stage in declaration order before anonymous site allocation and `SINIT`.
  Nested returns and loop transfers therefore leave no pending owner or name.
  The shared reverse mixed finisher emits `SRET`; no opcode, Fuel charge, profile
  or version flag changes. Each profile passed 26 native groups (6 new, 20
  regressions) and 532 CLI cases in separate core/regression phases. The
  [receipt](docs/evidence/m2-struct-return-constructors-windows-20261028.json)
  records 199 matching rechecked inputs and both retained CLI identities.
  Earlier receipts remain historical for their original inputs. See [the
  contract](docs/engineering/m2-struct-return-constructors.md).
- Exact-nominal subrecord return paths are implemented at `d4aa643` and verified
  in development and release. A bare `return outer.child;` accepts an
  exact-nominal record endpoint, including deep paths. The shared
  extractor emits consecutive `SREAD` operations into consecutive registers,
  allocates one anonymous immutable site, and emits one `SINIT`; the source
  stays live through creation. The shared finisher drops other mixed arrays and
  records in reverse order before `SRET`. No opcode, Fuel charge, profile, or
  version field changes. Development and release each passed 25 native groups
  (6 core, 19 regressions) and 579 CLI cases. All four phase invocations
  rechecked 205 identical inputs; development core ran before `d4aa643` and the
  other phases ran after it. Record borrows, general/parenthesized expressions,
  and `call().child` returns remain unsupported. Earlier receipts remain
  historical for their original inputs. See [the
  contract](docs/engineering/m2-struct-return-paths.md).
- Exact-nominal child record call-result assignment is implemented at
  `63be9e5`. A shared `compiler::record_call_assignment` handles root and child
  destinations. The child branch validates a mutable exact path, emits
  `SSUBASSIGN` (47) with source leaf zero, then `SDROP` releases the anonymous
  result. Existing CALL and capture cleanup precede the normal assignment;
  destination roots, owners, and neighboring bytes stay live. Development and
  release each passed 26 native groups and 575 CLI cases. No opcode, VM, Fuel,
  profile, or version changes. See [the
  contract](docs/engineering/m2-struct-child-call-assignment.md) and [Windows
  receipt](docs/evidence/m2-struct-child-call-assignment-windows-20261028.json).
- Exact-nominal record calls in constructor child fields are implemented at
  `c4cd6ab` and verified in development and release. `compiler::record_child_call` reserves the exact child result site,
  evaluates arguments, stages every returned scalar leaf through the shared
  `struct_value_source::stage_part`, then emits `SDROP` before later fields or
  parent publication. Declaration, root replacement, child replacement, and
  direct constructor return all use the same `record_constructor`. A pending
  parent is not live during the child call; an old replacement parent remains
  live and visible until replacement or early-exit cleanup; argument effects
  are not rolled back. Each profile passed 23 native groups (6 core,
  17 regressions) and 529 CLI cases in four separate phase invocations, with
  211 verified input identities. No opcode, VM, Fuel, profile, or version
  change is involved. General aggregate arguments outside the exact-record-formal call position,
  parenthesized child calls,
  and call-result field
  selection remain unsupported. See [the
  contract](docs/engineering/m2-struct-child-calls.md) and [Windows
  receipt](docs/evidence/m2-struct-child-calls-windows-20261028.json).
- The record-result IR slice's evidence remains 39 unique native groups and 2,317 CLI cases in development and release. The [core receipt](docs/evidence/m2-struct-results-ir-core-windows-20261028.json) records 21 native groups (8 new record-result, 6 array-result, 7 record-parameter), CLI builds and all 2,317 cases; the [regression receipt](docs/evidence/m2-struct-results-ir-regressions-windows-20261028.json) records 18 native-only groups (6 array-result VM, 8 record-call VM, 4 scalar-function), with no build or CLI rerun. CLI coverage is 72 record-result signature, 66 record-formal signature, 114 source record-parameter, 96 array-result signature and 1,969 M1 cases per profile. These were two separate phase invocations across implementation commit `dc1574b`, with disjoint native selections and matching 212 input hashes, compiler and SDK identities. All inputs and the final release CLI were rechecked before archival. Full native/CLI suites, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.
- M2 has private scalar-array layout, codec, caller-backed storage, owner-lifetime and copy helpers;
  private function-owned array IR has independent verification and metered native VM dispatch. The current
  source slices add immutable/mutable scalar-array declarations in lexical scopes of ordinary functions, indexed reads,
  element assignment in nested scopes, and copy initialization from exact-type/length array bindings.
  Array length access uses `NAME.len`, an exact `usize` constant in scalar expressions and pure for headers.
  Lexical exits release local arrays in reverse order; loop transfers preserve enclosing arrays.
  Whole-array assignment copies an exact-shape visible source into existing `var` storage without an extra extent.
  Private array bindings are function-owned; recursive VM frames retain separate tokens while sharing
  the 16-owner table and payload arena. Source declarations include scalar and shallow wrapper-returning helpers.
  Question-mark failure returns drop visible local arrays in reverse order; success keeps them live.
  Previous source-parameter verification passed 28 native groups and 2,475 CLI cases
  (426 existing array, 80 parameter, 1,969 scalar) per development/release profile.
  Completed native/CLI outputs were combined stepwise after a corrected CLI fixture;
  the aggregate harness was not rerun. Changed frontend/fixture inputs have fresh evidence.
  Source immutable exact-shape scalar-array parameters are supported. Parameter
  catalogs are predeclared for forward/mutual calls. Arguments evaluate left to
  right; immutable inputs are stable snapshots and mutable inputs get anonymous
  captures with normal/return/propagation/loop-transfer cleanup.
  Source array results support bare-name returns and exact-shape let/var call
  initializers, direct return calls, repeated return literals and call-result
  assignment into var arrays, plus in-place repeated-literal assignment. General
  aggregate expressions, for-header arrays, borrows, slices and wrapper elements remain unsupported.
  Result signatures now retain exact scalar-array lengths in 16 bounded slots;
  its original blanket result gate is removed by source lowering. Result anchors
  reuse an exact-shape parameter site or reserve one dead site before body lowering.
  Previous result-signature verification passed 16 native groups and 2,242 CLI cases
  per development/release profile: 96 result-signature, 80 parameter, 97 helper-local,
  and 1,969 scalar cases. Checks ran individually; backend native suites were not rerun.
  Private array results now have independent shape/lifetime verification and VM
  owner transfer. ARET (39) requires the callee's sole live array; array CALLs
  initialize dead exact-shape caller destinations. Transfer clears the child token
  and publishes it in the parent without copying or allocating payload/owners.
  Bounds, canonical bool data, metadata and Fuel are checked before token mutation.
  Source lowering emits reverse-order drops for all other visible arrays and
  captures before terminal ARET. Call-result names become visible only after
  argument evaluation and CALL, so early exits cannot drop pending destinations.
  Previous source-result verification records 26 native groups and 2,690 CLI cases per
  development/release profile, including 119 new source-result cases. Development
  combines 18 unchanged groups from the first selection with eight fresh groups
  after correcting a mutual-call fixture; release selects all 26 together.
  These are individual commands, not an aggregate harness run.
  Direct array-return calls reuse argument evaluation and the shared return
  finisher. Each anonymous destination uses one fresh catalog site and remains
  invisible during argument evaluation; normal completion releases all other
  visible arrays/captures before ARET. Focused direct-return verification passes
  12 native groups and 509 CLI cases per development/release profile. Other array
  and scalar CLI matrices and full native suites were not rerun. The expanded
  combined result-source harness is available but was only syntax-checked.
  Repeated return literals evaluate their fill once in the declared element
  context and require an exact literal count. Initialization follows fill evaluation;
  early returns/loop exits never drop a pending literal. The shared finisher drops
  all other visible arrays/captures before ARET. Focused literal-return verification
  passes 16 native groups and 628 CLI cases per development/release profile,
  including 119 new literal CLI cases. Earlier receipts are historical for changed
  compiler, helper, source fixture and aggregate harness inputs.
  Call-result assignment keeps the old destination live, receives a result in
  an anonymous site, copies it into existing storage and drops the temporary.
  It preserves destination owner metadata and normal argument effects; result,
  snapshots and parameter copies still contribute to peak quota use. Focused
  verification passes 15 native groups and 609 CLI cases per profile, including
  115 new CLI cases. A corrected Fuel fixture received a full native rerun.
  Repeated-literal assignment evaluates the fill once, then AFILL (40) overwrites
  the live mutable extent. Owner preflight and scalar encoding precede writes;
  no temporary catalog site, owner or payload extent is required, including at
  full capacity. The verifier checks liveness, ownership, mutability, type and
  reserved operands. The [focused receipt](docs/evidence/m2-array-literal-assignment-windows-20261025.json)
  passes 36 unique native groups and 2,693 CLI cases per profile. The final 36
  combine 17 reused backend identities with 19
  fresh frontend groups in each profile; the aggregate harness was syntax-checked,
  not invoked. Development reuses the backend from `b5e0c98`; release reuses the
  same identities from its earlier 36-group selection. Reuse validation matched 28
  unchanged source and test files to their `b5e0c98` Git blobs and confirmed
  matching SDK and compiler identities. The 2,693 CLI cases comprise 724 array and
  1,969 scalar cases, including 115 new fill cases.
  The final lowering separates array statement, copy, and index handling into
  helpers. Scalar and composed-fill cases return 42 at depth 10; depth 11 reports
  `compile_limit`. Two permanent fill CLI cases cover the composed boundary. The
  pre-fix binary reproduces `0xC00000FD` at depth 10. No stack-byte or performance
  claim is made.
  Previous private-result verification passed 43 native groups and 2,571 CLI cases
  per development/release profile, including parameter independence and deferred
  callee holes. Native development combined 41 plus two disjoint groups; release
  selected the same 43 identities together. Aggregate tooling was syntax-checked;
  evidence records individual commands rather than an aggregate invocation.
  Private `array_owners::copy_arguments` preflights up to eight exact-shape copies
  before changing bytes or owner state. Private IR/verifier/VM calls now support
  immutable exact-shape array parameters, mixed scalar positions, metered atomic
  copies, and frame-specific owners. All parameter and capture sites share the
  existing catalog, lexical binding, owner and payload limits.
  For-header array declarations and writes remain rejected.
- A private [struct-layout planner](docs/engineering/m2-struct-layout.md) plans 0..32 acyclic
  records with 1..16 fields, declaration-order padding, and a per-record byte ceiling.
  A [scalar-only storage slice](docs/engineering/m2-struct-storage.md) prepares a selected
  scalar record, initializes it in caller-backed arena bytes, and reads or writes indexed
  fields. A [private copy/assignment slice](docs/engineering/m2-struct-copy.md) appends
  independent scalar records and overwrites existing records with normalized snapshots,
  including self and partial overlap. A [private nested-storage slice](docs/engineering/m2-struct-nested-storage.md)
  initializes selected acyclic records from depth-first scalar leaf inputs and reads or
  writes scalar field paths in the shared arena. Selected roots are capped at 128 bytes;
  the full catalog is replanned at each boundary, and unselected valid records may be
  larger. A [private nested copy/assignment slice](docs/engineering/m2-struct-nested-copy.md)
  appends nested records by value and overwrites existing extents without a cursor
  change, including self and partial overlap. A shared [struct-owner foundation](docs/engineering/m2-struct-owners.md)
  puts record descriptors in the existing 16-slot table and rechecks catalog layout on
  access; array-only APIs reject record tokens. A [private struct-owner copy/assignment slice](docs/engineering/m2-struct-owner-copy.md)
  appends independent record owners and requires exact record identity for assignment.
  Its 17-group Windows selection passed development and release. The previous 34-group owner receipt is historical
  for changed inputs. A [private struct IR and verifier](docs/engineering/m2-struct-ir.md)
  introduced entry-owned bindings for opcodes 41..46: SINIT, SCOPY, SREAD,
  SWRITE, SDROP, and SASSIGN. Initialization consumes all depth-first scalar leaves
  in consecutive registers with exact types; reads and writes use flattened leaf
  ordinals. Full catalogs are replanned, record lifetimes occupy bits 16..31 beside
  array bits 0..15, and joins or backedges require exact live sets. The original
  verifier limited struct instructions to entry; calls into entry remain rejected
  when bindings exist. A
  [private struct VM](docs/engineering/m2-struct-vm.md) now executes those
  instructions. It adds sixteen entry binding tokens while sharing the existing
  owner table and one payload arena. A nonempty array or record catalog prepares
  1+capacity Fuel with a 65,536-byte cap; the scalar path is unchanged. Every struct
  opcode prepays a fixed charge before traversal, owner checks, staging, or token
  and register mutation. Success returns remaining Fuel; runtime failures abort the
  invocation. The `--vm` selection passed all 38 groups in development and release,
  and the existing 115-case CLI suite passed in both profiles. Results are recorded
  in the struct VM native and CLI receipts. The old `--ir` 46-group and
  115-case CLI receipts are historical for changed runtime, test, harness, and
  root-lock inputs.
  A [private function-owned record IR foundation](docs/engineering/m2-struct-function-ir.md)
  assigns each of the 16 static record sites to a function. Active owners must be
  declared functions, unused owner bytes must remain zero, and every opcode
  41..49 must target the active function; copy/assign/subassign sources must use
  the same function. Each function starts with all record bindings dead, while
  existing cleanup, joins, backedges, and entry reentry rules are unchanged. No
  opcode, Fuel charge, VM dispatch, version capability, or source form is added.
  The entry-frame-only kind 5 boundary was the foundation's historical checkpoint.
  The complete `--function-ir` invocation passed 31 native groups and
  2,383 CLI cases per development/release profile without result reuse. The
  [receipt](docs/evidence/m2-struct-function-ir-windows-20261027.json) records 106 input hashes,
  compiler/artifact identities, commands and outcomes. Other CLI matrices, full
  native suites, Linux, packaging, isolation and performance were not rerun. That
  31-group receipt remains historical for its original runtime and test inputs.
  A [private frame-local record VM](docs/engineering/m2-struct-function-vm.md)
  now executes verified helper IR in up to 32 guest frames. Each frame has sixteen
  record token slots over the same shared 16 owners and payload arena, indexed like
  arrays. Opcodes, Fuel, frontend lowering, and version capabilities are unchanged.
  The 13-group smoke suite passed in one native invocation. The complete `--function-vm` invocation passed 46 native groups and
  2,383 CLI cases per development/release profile without result reuse. The
  [receipt](docs/evidence/m2-struct-function-vm-windows-20261027.json) records 109 input hashes,
  compiler/artifact identities, commands and outcomes. Implementation commit:
  `80ed712`. Other CLI matrices, full native suites, Linux, packaging,
  isolation and performance were not rerun.
  Frame entry allocates no separate table or arena, while `SINIT`/`SCOPY` reserve
  shared owners and payload and require dead destination tokens. Writes and
  assignments require live mutable destinations. Drops clear frame tokens; dead
  middle extents stay charged until suffix reclamation. Only one of the six
  function-owned IR test groups changed expectation, from kind 5 to return 42.
  At `80ed712`, source helper records and record parameters/results remained
  unsupported. Source successors now implement helper records, record parameters,
  and a bounded set of record results; record borrows remain unsupported. The 512-slot token
  array carries no measured allocation, stack, or speed claim.
  Source [record parameters](docs/engineering/m2-struct-parameters-source.md) are
  implemented at `d0ca7e7` and verified in development and release. Each formal is an immutable nominal
  record; at that checkpoint each argument was one bare visible binding of that
  exact type. The result-argument successor also accepts a bare exact-result call.
  Constructors, paths, casts, and aggregate expressions do not satisfy the formal.
  A mutable source is copied by `SCOPY` into an anonymous lexical capture before
  the next argument evaluates; the final CALL still creates an independent callee
  owner. All formal sites are predeclared after the catalog scan and bound by
  owning function plus record-formal ordinal within the unchanged 16 static sites.
  No second 128-byte signature site map is added. Scalar and array returns, `?`
  propagation, normal lexical exits, and loop transfers reuse the record-aware
  `array_source::release_from`; array results reuse the existing finisher. Those
  paths already supported records, so no new cleanup change is claimed. A scalar
  return drops each visible formal, including a record formal, before `RET`; an
  array return drops non-result records before `ARET`. Record results, borrows,
  `ref`, and `var` parameters remain unsupported.
  Development and release each passed 51 unique native groups and 2,318 CLI cases. The [core receipt](docs/evidence/m2-struct-parameters-source-core-windows-20261028.json) records 14 native groups and 180 CLI cases; the [regression receipt](docs/evidence/m2-struct-parameters-source-regressions-windows-20261028.json) records 37 native groups and 2,138 CLI cases. The CLI selections comprise 114 source parameter, 66 signature, 80 array parameter, 89 helper-local record and 1,969 M1 cases per profile. These are two separate phase runs with disjoint native selections, matching profiles, and identical 206 input hashes, compiler and SDK identities; all inputs were rechecked before archival. Native stress tests use 16,000,000 Fuel; the CLI retains its 1,000,000 ceiling, with four costly fixtures expected to pass `check` and report `fuel` on `run`. Other native/CLI matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.
  A [declaration-only source struct slice](docs/engineering/m2-struct-source.md)
  parses bounded top-level declarations, resolves scalar and by-value named
  fields, and attaches immutable declaration-order layouts. Its 23 native groups
  and 2,208 CLI cases per profile remain historical evidence for that
  declaration-only slice. The [bounded source struct-value slice](docs/engineering/m2-struct-values.md)
  is the historical read baseline: entry-only
  `let|var TYPE NAME = TYPE { .FIELD = EXPR, ... };` construction for scalar-field
  roots; exact, declaration-ordered typed fields staged before consecutive loads
  and `SINIT`. The compiler declares the name only after emitting the complete
  initializer; runtime `SINIT` failure aborts. One-level
  `NAME.FIELD` reads use `SREAD`. Mixed lexical exits, loop transfers, and
  returns release arrays and records in reverse order. Read-only record programs
  select `brownie.m2-struct-read/1`; declaration-only programs keep their existing
  profile. Construction is capped at 128 planned bytes and 16 fields, with 16
  record sites, the shared owner table, 65,536-byte payload cap, and existing
  Fuel. For that read baseline, development and release each passed 28 native
  groups and 2,352 CLI cases through the focused harness, plus three supplemental
  early-transfer/forward-name cases. The
  [receipt](docs/evidence/m2-struct-values-windows-20261026.json) records
  toolchain, inputs, artifacts, commands, and limitations. That read receipt is
  historical for the current field-write, source-copy, and nested-source compiler
  inputs. At that baseline, struct parameters/results and borrows were unsupported;
  nested type declarations and construction are handled by the nested successor,
  and source record parameters by their later successor. Record results and
  borrows remain unsupported.
  A [source struct-field write slice](docs/engineering/m2-struct-write.md) adds
  entry-only `NAME.FIELD = EXPR;` for one mutable scalar leaf. The binding and
  field resolve before a single exact-typed RHS; `SWRITE` follows the expression
  and terminator and reuses the existing record extent. For-header writes remain
  rejected, condition reads and body writes follow normal statement handling, and
  no copy, owner, or payload extent is added. Programs with nonempty record
  bindings and opcode 44 select `brownie.m2-struct-write/1`; `--version --json` adds
  `struct_write_profile`. VM checks, codec, 41,281 Fuel, 16 shared owners, and the
  65,536-byte cap remain unchanged. The full `--write` selection passed 24 native
  groups and 2,472 CLI cases in each development/release profile. The
  [write receipt](docs/evidence/m2-struct-write-windows-20261026.json) records
  commands, source/tool identities, artifacts, outcomes, and limitations; its
  results are historical for the current source-copy and nested-source inputs. The earlier nested-storage 18-group receipt is
  historical for changed inputs; nested-copy 24-group checks passed development and release.
  The copy slice's Windows 28-group receipt passed development and release after
  moving snapshot staging into caller-owned scratch. Earlier planner and storage
  receipts are historical for changed inputs.
  A [source struct-copy slice](docs/engineering/m2-struct-source-copy.md) adds
  entry-only bare-name `let|var P q=p;` initialization and `p=q;` assignment for
  exact nominal record types, including whole nested roots. Sources may be immutable, assignment targets
  must be mutable, and self-assignment is accepted. `SCOPY` creates an independent
  owner and extent; `SASSIGN` reuses the destination extent. The type-name/local
  ambiguity is resolved by inspecting `{` after the initializer name. Record
  statements remain unavailable in helpers and `for` initializer/post clauses;
  that slice left constructor RHS assignment, aggregate expressions, struct
  parameters/results, and borrows unsupported. Nested constructors, scalar paths,
  and child binding initializers are handled by the successors. Programs with
  nonempty record bindings and opcode 42 or 46 select
  `brownie.m2-struct-copy/1`, before opcode 44 write selection and read fallback;
  `--version --json` adds `struct_copy_profile`.
  Existing 128-byte roots, 16 fields, 16 record sites, 16 shared owners, and the
  65,536-byte payload cap remain. Development and release each passed
  39 native groups and 2,582 CLI cases, including 110 source-copy cases.
  [Stepwise evidence](docs/evidence/m2-struct-source-copy-windows-20261026.json)
  records input hashes, artifacts and development native/build reuse after CLI
  fixture corrections. The complete aggregate harness was not rerun. That receipt
  is historical for the current nested-source compiler inputs.
  Implementation commit: `f9cf654`.
  A [bounded source nested-struct slice](docs/engineering/m2-struct-source-nested.md)
  admits inline named child constructors, multi-segment scalar read/write paths,
  and whole-root copies for entry-owned records. A nested constructor is traversed
  iteratively in source order. Each scalar leaf's tag comes directly from the
  cursor, and one staging slot is allocated immediately before that leaf's
  expression is parsed; no tag array is returned. Leaves stage left to right,
  then consecutive loads and one `SINIT` follow the complete initializer. Child
  constructors reserve no owner, site, or extent. Verifier and VM rules are
  unchanged. Path segments resolve to depth-first scalar-leaf
  ordinals, including leaves in preceding nested siblings; `SREAD`/`SWRITE` use the
  exact scalar tag at the endpoint. The compiler declares a binding only after
  emitting its complete initializer and `SINIT`; runtime failure aborts. Control-
  transfer cleanup drops only owners visible before the pending declaration.
  Whole nested roots use the existing `SCOPY`/`SASSIGN`.
  Source staging is capped at 16 scalar leaves total, record nesting and path
  length at 16, selected roots at 128 bytes, and the existing 16 record sites, 16
  shared owners, 65,536-byte arena, 128-register and 256-instruction limits remain.
  The private VM still accepts 128 leaves. Traversals of the record tree are
  iterative; scalar expression depth limits are unchanged. A bound record with a
  nested field selects `brownie.m2-struct-nested/1` ahead of the copy, write, and
  read profiles; unused nested declarations do not promote a flat or non-record
  program. `--version --json` adds `struct_nested_profile`. Development and
  release each passed 36 native groups and 2,710 CLI cases, including 128 nested
  cases, through the complete `--nested` harness on the corrected source.
  The [receipt](docs/evidence/m2-struct-source-nested-windows-20261027.json)
  records input hashes, artifacts, commands and the corrected release regression;
  it is historical for the current child-binding compiler inputs.
  Implementation commits: `576d062` and `716c14b`.
  A [child binding initializer slice](docs/engineering/m2-struct-child.md) admits
  inline child values such as `R { .i = i }` when the field type and a visible
  whole binding have the same nominal identity. At the child field, it emits one
  `SREAD` and `STORE` per source scalar leaf into the parent's staging before any
  later sibling expression; the snapshot is independent and the source stays
  live. No `SCOPY`, temporary owner, site, or extent is created. Only the new
  parent root consumes an owner and extent, and its name becomes visible after
  the complete `SINIT`. Existing leaf, depth, root, site, owner, arena, register,
  and instruction limits are unchanged. The profile remains
  `brownie.m2-struct-nested/1`; version JSON adds
  `struct_child_binding_initializers: true`. The complete `--child` harness passed
  21 native groups and 2,798 CLI cases in each development/release profile.
  The [receipt](docs/evidence/m2-struct-child-windows-20261027.json) records 90
  input hashes, compiler and CLI artifact hashes, commands, and outcomes.
  Implementation commit: `ed63d1550ffd820e2ad197fe1be9d6b2e0b197a0`.
  A [subrecord declaration initializer](docs/engineering/m2-struct-extract.md)
  also admits `let I i = p.i` and deeper exact-nominal record endpoints. It reads
  the selected scalar leaf range directly into consecutive registers and emits
  one `SINIT`, without `STORE`, `LOAD`, `SCOPY`, or a temporary owner. The source
  stays live; the destination has an independent site, owner, and extent. Scalar
  expressions still reject record endpoints. The assignment successor below adds
  writes to/from record endpoints.
  At that checkpoint, helper records, parameters/results, and borrows were
  unsupported; later source slices add helper records and record parameters. Version
  JSON adds `struct_subrecord_initializers: true`; the nested profile is unchanged.
  Development and release each passed 26 native groups and 2,915 CLI cases
  stepwise. Development reuses its unchanged 26-group result after two CLI-only
  diagnostic fixes; final CLI matrices and release native groups ran afterward.
  The [receipt](docs/evidence/m2-struct-extract-windows-20261027.json) records 92
  input hashes, compiler/artifact hashes, commands, and native reuse provenance.
  Implementation commit: `f65a1d7`.
  The child-binding receipt is historical for changed compiler and fixture inputs.
  A [subrecord assignment successor](docs/engineering/m2-struct-subassign.md)
  admits exact-nominal `p.i = q.i`, `p.i = i`, and `i = p.i` with a mutable
  destination. All source leaves are read before writing the existing target.
  No new site, owner, extent, or temporary structure is created. Whole bare-name
  assignment retains `SASSIGN`; its historical partial lowering emitted
  `SREAD`/`SWRITE`. That baseline did not guarantee transaction rollback.
  Existing bounds and the nested profile remain; version JSON adds
  `struct_subrecord_assignment`. The complete `--subassign` invocation passed
  15 native groups and 3,044 CLI cases in each development/release profile.
  The [receipt](docs/evidence/m2-struct-subassign-windows-20261027.json) records
  91 harness input hashes plus four CLI fixture hashes, compiler/artifact hashes,
  commands, and outcomes. Implementation commit: `666da70`.
  The extraction receipt is historical for changed compiler and fixture inputs.
  The [atomic successor](docs/engineering/m2-struct-subassign-atomic.md) lowers
  those same forms to `SSUBASSIGN` (47), with independently verified live mutable
  destination, source, nominal node IDs, and leaf ordinals. Runtime prepays
  131,072 Fuel, validates owners/ranges, stages at most 128 canonical bytes, then
  commits once. Failure leaves the selected destination unchanged; external
  effects and earlier statements are not rolled back. No new site, owner,
  extent, or scalar register is used. Sixteen-leaf assignments now execute in
  the CLI allowance. Version JSON adds `struct_subrecord_assignment_atomic`;
  the nested profile remains. The complete `--atomic` invocation passed 26
  native groups and 3,046 CLI cases per development/release profile. The
  [receipt](docs/evidence/m2-struct-subassign-atomic-windows-20261027.json) records
  99 input hashes, compiler/artifact identities, commands, and outcomes. The
  separately [verified foundation](docs/evidence/m2-struct-atomic-foundation-windows-20261027.json)
  passed nine groups per profile at `2b5917c`. Integration commit: `5589803`.
  The per-leaf assignment receipt is historical for changed inputs.
  The [constructor child-path successor](docs/engineering/m2-struct-child-path.md)
  admits `R { .i = p.i }` and deeper exact-nominal record endpoints. It snapshots
  selected leaves before later sibling expressions and introduces no temporary
  owner, site or extent. The VM, verifier, bounds and nested profile are unchanged;
  version JSON adds `struct_child_path_initializers`. The complete `--child-path`
  selection passed 19 native groups and 419 CLI cases in each development/release
  profile. The [receipt](docs/evidence/m2-struct-child-path-windows-20261027.json) records 99 input hashes, compiler/artifact
  identities, commands and outcomes. Implementation commit: `680f57a`. This focused
  selection does not rerun scalar/array or other struct CLI matrices, full native
  suites, Linux, packaging, isolation or performance. Earlier receipts are historical
  for changed frontend, root-lock, fixture and harness inputs.
  A [private scalar-value replacement foundation](docs/engineering/m2-struct-replace-values.md) now stages every scalar
  field before overwriting an existing exact-nominal root. Owner tokens, order and
  payload use remain unchanged, including at full capacity. Initialization and
  replacement share one encoder. This adds no source syntax, opcode, verifier,
  VM dispatch, Fuel charge or version capability; constructor RHS assignment
  remained unavailable in that slice. The complete `--replace-values` invocation passed 21 native
  groups and 214 CLI cases per development/release profile. The [receipt](docs/evidence/m2-struct-replace-values-windows-20261027.json)
  records 102 input hashes, compiler/artifact identities, commands and outcomes.
  Implementation commit: `6509e27`. The selection covers six new replacement groups,
  six nested-storage, six owner-copy and three subrecord-owner groups, plus 83
  existing child-path and 131 existing assignment CLI cases. Other CLI matrices,
  full native suites, Linux, packaging, isolation and performance were not rerun.
  Earlier receipts are historical for changed storage, owner, root-lock and harness
  inputs. Metered VM integration is covered by the successor below; source lowering
  is covered by the [constructor-assignment successor](docs/engineering/m2-struct-replace-source.md).
  Private [metered root replacement](docs/engineering/m2-struct-replace-vm.md) now executes `SREPLACE` (48) after
  independent live/mutable/nominal and consecutive scalar-input verification.
  The VM prepays 46,145 Fuel, stages canonical bytes and overwrites existing storage
  without a temporary owner, site or extent. Scalar definitions and owner live sets
  are unchanged. No constructor-assignment source syntax or version capability
  was added by that slice. The complete `--replace-vm` invocation passed 27 native groups (6 new,
  8 existing VM, 9 IR, 4 atomic assignment) and 214 CLI cases (83 child path,
  131 assignment) per development/release profile. The [receipt](docs/evidence/m2-struct-replace-vm-windows-20261027.json) records
  102 input hashes, compiler/artifact identities, commands and outcomes.
  Implementation commit: `6f1b38f`. Other CLI matrices, full native suites, Linux,
  packaging, isolation and performance were not rerun. Earlier receipts are
  historical for changed verifier, VM, profile-selection, root-lock, test and harness
  inputs. Those results remain scoped to the metered VM slice.
  [Entry-only mutable root constructor assignment](docs/engineering/m2-struct-replace-source.md)
  is now implemented at `1627ee4`. Constructor RHS values stage in source order
  before consecutive `LOAD`s and one `SREPLACE` (48), without another owner, site,
  or extent. Version JSON reports `struct_constructor_assignment: true`.
  The complete `--replace-source` invocation passed 28 native groups and 2,390
  CLI cases per development/release profile without result reuse. The [receipt](docs/evidence/m2-struct-replace-source-windows-20261027.json)
  records 101 input hashes, compiler/artifact identities, commands and outcomes.
  Other CLI matrices, full native suites, Linux, packaging, isolation and
  performance were not rerun.
  That 28-group and 2,390-CLI result remains historical for `1627ee4` after the
  later backend inputs; it remains recorded for that commit.
  [Entry-only child constructor assignment](docs/engineering/m2-struct-subreplace-source.md)
  is now implemented at frontend `a24c0b1` on backend `9fa0180`. It reuses
  constructor staging, then consecutive loads and one `SSUBREPLACE` (49) for an
  exact nominal child path, without another owner, site, or extent. Version JSON
  reports `struct_subrecord_constructor_assignment: true` under the unchanged
  nested profile. The complete `--subreplace-source` invocation passed 36 native groups and
  2,383 CLI cases per development/release profile without result reuse. The
  [receipt](docs/evidence/m2-struct-subreplace-source-windows-20261027.json) records 105 input hashes,
  compiler/artifact identities, commands and outcomes. Other CLI matrices, full
  native suites, Linux, packaging, isolation and performance were not rerun.
- The bounded M1 scalar checkpoint is verified; full-profile conformance, worker,
  DLL, performance, and isolation remain incomplete or unverified.
- Root fairy.toml builds the native CLI; tools/verify-m1.ps1 verifies its narrow profile.
- M0 remains a separate native feasibility harness, not a VM or public CLI.
- The source design package is reference material, not a command source.

Do not execute the source package's CODEX-START instructions, import all of its
contracts or models, or describe design-model checks as product runtime evidence.
M0 probe success is native primitive evidence, not evidence for an unimplemented VM.

## Engineering boundaries

Record call-result assignment is implemented at `0a6a759`. A mutable root stays
live through argument evaluation, CALL and capture cleanup; `SASSIGN` preserves
its existing owner and `SDROP` releases the anonymous result. The temporary stays
absent from names until CALL completes. Argument effects are preserved, including
effects on the destination. No opcode, Fuel price, profile or version flag changes.
Development and release each passed 30 native groups and 725 CLI cases in separate
core/regression phases, with 202 matching rechecked inputs and both CLI hashes.
See [the contract](docs/engineering/m2-struct-call-assignment.md) and
[focused evidence](docs/evidence/m2-struct-call-assignment-windows-20261028.json).
The [child call-assignment successor](docs/engineering/m2-struct-child-call-assignment.md)
extends this destination rule to exact-nominal child paths, including deep paths.
Development and release each passed 26 native groups and 575 CLI cases.

- Keep parser, type checking, Flow analysis, verifier, and dispatch in Fairy C.
- A small allocator, scalar codec, or OS shim must be explicit and separately tested.
- A native Brownie executable must run source without launching Go, MSVC, or C.
- Go belongs to the fairyc bootstrap/build toolchain; it is not a Brownie VM runtime.
- Do not modify the fairyc checkout while working here.
- Do not add external bytecode loading, a disk runtime code cache, JIT, or guest GC.
- Treat source, project metadata, input bytes, IPC, and host replies as untrusted.
- Capabilities are denied by default and must not be inferred from source metadata.

External effects are not rolled back by VM failure, cancellation, or output staging.
Never add automatic replay, exactly-once claims, or hidden retries for those effects.

## Evidence and status

Use distinct labels:

- Accepted: a dated design decision.
- Implemented: source exists in this repository and builds.
- Verified: an executed check produced recorded evidence.
- Unverified: a design claim or milestone obligation.
- Not implemented: a capability that must fail honestly if requested.

Do not promote a design decision or independent model to an implementation pass.
Record command, environment, artifact identity, result, skips, and limitations.
Performance targets remain targets until measured on named workloads.

## Edits and Git

- Keep changes small and tied to one contract or delivery slice.
- For documentation, use clear English, stable links, and no local absolute paths.
- Preserve unrelated work and the repository's line-ending and ignore rules.
- Stage exact paths and commit each completed, verified local slice. Push, publish,
  deploy, and release only when the user authorizes them.
- Do not install dependencies or change branches as a side effect of authoring docs.

## Review focus

For runtime changes, require direct evidence for checked arithmetic, signed codec
edges, quota rollback, stale generation rejection, array fill/index evaluation
counts, reverse-order array drops, move and borrow rules, bounded work, staged
output, and Engine failure containment.

For worker changes, require actual Windows isolation evidence and negative broker
ordering tests. Design review findings remain acceptance obligations until the
corresponding implementation test exists.

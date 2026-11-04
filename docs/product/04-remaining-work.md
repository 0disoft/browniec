# Remaining Work and Design Reconciliation

- Reviewed: 2026-11-03, implementation `0d1a8cb`, documentation baseline `df56e7d`.
- B01 preparation: `670a041`; B02/B03 native transactions: `7f8f455`/`b82500d`; private returned-view VM: `d468ca1`; owned-array/CALL integration: `5cccbd3`; record CALL/local ownership: `e01a9b1`; explicit native owned entry: `8bf37de`; bounded returned-view Fuel: `275abfd`, updated 2026-11-04. Other audit findings retain their original scope.
- Scope: completion of the accepted Brownie design and its M0-M5 delivery gates.
- Evidence method: source/contract review, reference ZIP inspection, import-graph
  inspection and existing receipt/hash checks. No new native execution, benchmark,
  isolation, ABI or full-profile conformance run was performed for the original
  2026-11-03 audit; later focused increment evidence is linked separately.
- Authority: repository owning contracts and ADRs take precedence over the external
  design package. This audit records gaps; it does not silently adopt its schemas,
  limits, opcodes, commands or embedded instructions.

## Current delivery

M0 feasibility and the bounded M1 scalar checkpoint have recorded evidence. M2
public source supports six scalar arrays, nominal scalar/nested records, helper
locals, by-value parameters/results, construction, copy/replacement/assignment,
array/record result expressions and paths, fixed-array UTF-8 checks, typed shared/
exclusive scalar slices, lexical aliases/reborrows and whole/ranged/temporary CALL
arguments. Exclusion remains per owned root.

Returned-slice signatures, single-input body-origin summaries and explicit
returned-view preparation IR/independent proof are private only. The
[preparation contract](../engineering/m2-slice-result-ir.md) adds a separate private
unit. [Native handoff/capture transactions](../engineering/m2-slice-result-runtime.md)
now connect to [private VM execution](../engineering/m2-slice-result-vm.md) for
rootless borrowed inputs, caller result/frame/site destinations and deferred
terminal cleanup. [Owned arrays and scalar/array CALLs](../engineering/m2-slice-result-owned-vm.md)
are integrated at `5cccbd3`; [record CALLs and locals](../engineering/m2-slice-result-record-vm.md)
now share their ownership transactions. [Native owned entry](../engineering/m2-slice-result-entry.md)
now accepts explicit array/record value tokens. [Bounded returned-view metering](../engineering/m2-slice-result-fuel.md)
now reconciles the private schedule and cleanup reserves with CLI-sized budgets. Public compilation rejects
all borrowed-result declarations.
The original audit's focused [receipt](../evidence/m2-slice-result-origins-windows-20261103.json)
records 12 native groups and 990 CLI cases per Windows development/release profile.
The 2026-11-03 audit rechecked all 462 recorded input hashes and both retained CLI artifact
hashes. Development's documented harness-only result reuse remains explicit;
release ran the entire selected scope. These are not full M2 or full-profile tests.

There are 17 private Buffer modules, with focused historical native receipts for
storage/ownership, growth, writes, append/resize, leases, UTF-8 sessions and host
cleanup. None is reachable from the CLI's current local-module import graph.
They are reusable foundations, not guest Buffer/Instance integration.

M3 typed host suspension, M4 restricted Windows delivery and M5 public DLL/clean-
machine delivery are not implemented. `core: true` in the experimental version
JSON means that the narrow native CLI exists; it does not certify the full
`brownie.safe/0.3` profile or completion of M3. Restricted/embed remain false.

The 2026-11-04 [preparation-IR evidence](../evidence/m2-slice-result-ir-windows-20261104.json)
records 10 native groups and 208 CLI cases per profile on 476 matching inputs,
without final result reuse. This focused increment does not replace the earlier
broader receipts or establish runtime returned-reference/lifetime support.

The final 2026-11-04 [native handoff/lifetime evidence](../evidence/m2-slice-result-runtime-windows-20261104.json)
records 12 native groups and 208 CLI cases per profile on 479 matching inputs,
with no final result reuse. Source result/dispatch/cleanup integration is still
required; this native transaction does not promote public execution.

The 2026-11-04 [Fuel evidence](../evidence/m2-slice-result-fuel-windows-20261104.json)
records 56 native groups and 217 CLI cases per Windows development/release profile,
with 500 matching inputs and all 112 production files matching `275abfd` under
Git LF. Phase reserves now cover zero-Fuel abort/final close. At that historical checkpoint, public defaults/cap
were unchanged; B04 source bindings and ordinary public execution remain gated.

The [lexical/range increment](../evidence/returned-ranges-lexical-windows-20261104.json)
records five lexical interpreter groups, 27 native range/origin/Fuel/execution
groups and 244 standalone CLI cases on Windows development. L07 is implemented;
B04 inline return ranges are integrated privately. At that checkpoint general result bindings,
Static backing and public result execution were still pending. The later
private binding/range increments and [retained native Program](../engineering/retained-program-image.md)
now supply lexical input-result execution and actual literal ownership. The
[retained-image Static execution successor](../engineering/static-execution.md)
executes private literal operations; guest literal syntax and ordinary public
result admission remain pending. The full objective
and implementation order are retained in the [completion plan](../engineering/completion-plan.md).

The [private CALL-binding proof](../engineering/m2-slice-result-call-ir.md) now
adds independently checked result destinations, anonymous exclusive END masks
and definition-based recursive origins. The [source bridge](../engineering/m2-slice-result-call-source.md) now lowers typed
lexical bindings and selected temporary retention into these recipes. The [private VM successor](../engineering/m2-slice-result-call-execution.md) now
executes these recipes with exact parent restoration and actual owner cleanup.
Public result admission/dispatch remains gated. See its focused Windows evidence.

The [public Fuel successor](../engineering/public-fuel-limits.md) deliberately
raises the explicit CLI ceiling to 16000000 while preserving the 256 default
and operation prices. All public slice paths share the cost functions; version
JSON exposes the same limits. This addresses the narrow budget gap, not remaining
C05 source/IR/resource capacities or B04 public returned-reference admission.

The [retained-image Static execution evidence](../evidence/static-execution-windows-20261105.json)
records 59 native groups and 33 public Fuel CLI cases per Windows profile on
matching final inputs. Private image operations now execute with exact prices
and frame-local liveness. The subsequent [literal decoder](../engineering/literal-source.md)
and [native source compiler](../engineering/literal-compiler.md) now connect
bounded literal collection and immediate byte/text projections to this image.
Typed text bindings, Static CALL/return receipts and public promotion remain open.

## Status and priority

Accepted/designed means a contract exists. Implemented means source exists in its
stated scope. Verified means an actual recorded execution covers that scope.
Private/gated code is not a public capability. Missing means no implemented public
surface; unverified means the claimed execution/OS/measurement evidence is absent.
No one label implies full-profile or release readiness.

| Priority | Work IDs and dependency | Owning contracts |
| --- | --- | --- |
| Next | B04 public result bindings/admission: owned entry and bounded returned-view metering are connected; public end-to-end execution remains gated | [Private VM](../engineering/m2-slice-result-vm.md), [Preparation IR](../engineering/m2-slice-result-ir.md), [Returned-origin boundary](../engineering/m2-slice-result-origins.md) |
| M2 integration | D01-D05, L03-L06, I01-I02: private Buffer and aggregate foundations -> useful guest byte/text/input/output path | [Specification](02-spec.md), [Buffer storage](../engineering/m2-buffer-storage.md), [UTF-8 sessions](../engineering/m2-buffer-utf8-session.md), [output](../cli/output-and-exit-codes.md) |
| Full-profile prerequisites | L01-L02/L07, B05, C01-C05: accepted language, references, configuration and limit reconciliation | [Specification](02-spec.md), [command](../cli/command-contract.md), [configuration](../cli/configuration.md) |
| M3 prerequisite/core | R01-R05 -> H01-H04: Engine/Instance/accounting/step/cancel -> fake typed host boundary | [Runtime flow](../architecture/02-runtime-flow.md), [invariants](../engineering/00-project-invariants.md) |
| M4 | W01-W06 after bounded core/authority contracts | [System boundary](../architecture/00-system-boundary.md), [runtime flow](../architecture/02-runtime-flow.md) |
| M5 and release evidence | E01-E04, V01-V05; measure relevant slices earlier | [Architecture](../../ARCHITECTURE.md), [testing](../engineering/05-testing-standard.md), [performance](../engineering/03-performance-budget.md), [validation](../../VALIDATION.md) |

## Coverage of every reference required feature

The reference ZIP's `contracts/profile.json` lists 40 required features. Narrow
means implemented within the experimental profile, not full-profile conformance.
Partial/private means source or native foundations exist but integration is open.
Missing means the planned public surface has no implementation. The work IDs
below cover prose obligations beyond this feature list as well.

| Reference feature | Current scope | Remaining work |
| --- | --- | --- |
| modules | One fixed `module main` | L01, C01 |
| explicit_import_alias | Missing | L01 |
| public_functions | Missing | L01, I01 |
| local_type_inference | Explicit local types required | L02 |
| let_var | Narrow | L02, L05 |
| checked_integer_arithmetic | Narrow six scalar types | V01, V02 |
| bool_short_circuit | Narrow | V01 |
| if_expression | Statement if only | L02 |
| while | Narrow | R03, V01 |
| classic_for | Narrow, pure scalar headers | L02, V01 |
| break_continue | Narrow lexical transfers | R03, V01 |
| direct_function_calls | Narrow | L01, R03, V01 |
| recursion_with_frame_limit | Narrow bounded VM frames | R02, C05, V01 |
| scalar_fixed_arrays | Narrow, repeated initializers | L03, C05 |
| plain_structs | Narrow scalar/nested records | L03, L05, V01 |
| shared_borrows | Scalar slices | B05 |
| mutable_borrows | Scalar slices and lexical children | B05 |
| single_parameter_borrow_returns | Private proof/VM handoff for rootless borrowed inputs; public source remains gated | B01-B04 |
| array_views | Narrow scalar views | B02-B05 |
| half_open_slices | Narrow scalar ranges | B04, B05 |
| option_result | i32/bool payloads, depth one | L05 |
| result_propagation | Narrow Result and accepted M1 Option extension | L05, L06 |
| exhaustive_shallow_switch | Narrow | L05, V01 |
| must_use_result | Missing | L06 |
| owned_buffer | Private native foundations | D01-D04 |
| utf8_validation | Fixed-array views; private Buffer scanner | D05, R03 |
| capability_output | Missing | I02, H01 |
| typed_host_requests | Missing | H01-H04 |
| fuel | Narrow opcode prices; private Buffer metering | R02-R04, C05 |
| memory_quota | Aggregate backing cap; private Buffer ledgers | R01-R03 |
| deadline | Missing general runtime/compile deadline | R04 |
| source_diagnostics | Single-source byte offset | C03 |
| utf8_text_literals_ref_str | Missing | D05 |
| explicit_text_bytes | Missing | D05 |
| bounded_step_work | Private Buffer continuations; no VM step API | R03, R05 |
| engine_total_quota | Private ledger arithmetic, no Engine coordinator | R01, R02 |
| complete_aggregate_construction | Narrow arrays/records | L03, L05, V01 |
| explicit_root_lifetimes | Narrow array/record/slice generations | B05, R02, R05 |
| engine_poison_boundary | Missing persistent Engine state | R01, R04 |
| streaming_utf8_validation | Private Buffer scanner/session | D05, R03 |

## Language completion

| ID | Work and completion condition |
| --- | --- |
| L01 | Implement explicit multi-module snapshots, import aliases, name resolution, `pub` visibility and public entry selection. Preserve source identities across resolution and reject duplicate/ambiguous/cyclic-invalid definitions within compile budgets. |
| L02 | Add the target's local type inference, `void` returns and `if` expressions. Review current pure-for restrictions and other narrow grammar choices explicitly rather than silently widening them. Add only the agreed target syntax. |
| L03 | Record field shorthand is implemented for scalar and plain-record members through existing typed ordered staging; see [the contract](../engineering/m2-struct-shorthand.md). Remaining: complete array element-list initialization with exact arity, source evaluation order, complete initialization and independent values. Existing repeated-array/record constructors must keep their current behavior. |
| L04 | Implement selected-place receiver/index evaluation before RHS and agreed compound assignment forms; hold the originally selected root/location through RHS effects and independently verify its identity, lifetime and overlap. Ordinary current stores are not a generic selected-place contract. |
| L05 | Extend Option/Result to the agreed wide scalars, arrays, records, Buffer and nested tagged values. Separate wrapper depth (target four), plain-struct depth and total traversal/size budgets. Compute whole-type copyability and moves, including inactive Buffer variants; retain the first-profile forbidden field/type combinations. |
| L06 | Implement must-use Result handling, explicit discard and `.is_ok` under the target semantics, with proper errors for unhandled values. Extend switch/propagation and cleanup to resource-bearing payloads. Preserve or deliberately reconcile the accepted M1 Option propagation extension. |
| L07 | Implemented at `5bb055b`: leading BOM, LF/CRLF, rejection of lone CR/raw NUL, nested block comments and raw byte spans. Five focused interpreter groups and 36 native CLI cases passed. See [lexical compatibility](../engineering/lexical-compatibility.md). |

## Borrowed results and general references

| ID | Work and completion condition |
| --- | --- |
| B01 | Preparation subset at `670a041`: explicit view/forward/return IR, identity pairing and independent CFG/type/access/live-origin reconstruction. The private VM at `d468ca1` separately admits a rootless subset; proof alone remains insufficient for ordinary/public execution. |
| B02 | Native transaction at `7f8f455`; private result/frame/site/63-65 dispatch at `d468ca1`. Shared/exclusive handoff, parent suspension, generation checks and zero-Fuel abort are connected. Owned-array and scalar/array CALL integration is implemented at `5cccbd3`. Record CALLs/locals are now connected; see [the successor](../engineering/m2-slice-result-record-vm.md). Explicit native owned entry is connected; see [the entry contract](../engineering/m2-slice-result-entry.md). Bounded metadata/copy/Fuel reconciliation is connected; see [the schedule](../engineering/m2-slice-result-fuel.md). Remaining: B04 public integration and end-to-end admission. |
| B03 | Native capture/root retention at `7f8f455`; private rootless callee cleanup routes through handoff at `d468ca1`. Selected external temporary roots/descendants use native Capture receipts. Guest-created array temporary ownership and mixed scalar/array CALL captures are integrated at `5cccbd3`. Record locals and mixed record CALL captures are now connected. Explicit native owned entry is connected. Remaining: public source bindings; ordinary VM must not admit these private recipes without its own proof/metering. |
| B04 | Direct return ranges now lower through existing independently proved view/handoff recipes; see [range integration](../engineering/m2-slice-result-ranges.md). Ordinary scalar native entry/terminal cleanup is connected through the [scalar entry path](../engineering/m2-slice-scalar-entry.md). Native frames now have [retained Held bindings and fresh parent restoration](../engineering/m2-slice-result-bindings.md), with a sparse bound that supports exclusive same-slot descendants. Private CALL-binding IR destination/origin proof is now implemented; see the [binding recipe contract](../engineering/m2-slice-result-call-ir.md). Typed lexical source result lowering and selected temporary retention now produce independently proved IR; see the [source bridge](../engineering/m2-slice-result-call-source.md). Private binding dispatch and selected owner/parent retention through runtime are now connected; see the [execution contract](../engineering/m2-slice-result-call-execution.md). Immediate index/length/UTF-8 projections are now connected; see [the projection contract](../engineering/m2-slice-result-projections.md). The [caller END-chain prerequisite](../engineering/m2-slice-result-capture-chains.md) now supports their atomic multi-Held cleanup. The [direct-argument successor](../engineering/m2-slice-result-arguments.md) now connects nested returned actuals and argument ranges, selected transitive ancestry, prompt unselected cleanup and recursive source hints. The [range-projection successor](../engineering/m2-slice-result-range-projections.md) connects declaration/return ranges over retained CALL results, with hidden endpoint lifetimes and canonical terminal handoff. The [native literal-image prerequisite](../engineering/static-literal-image.md) now owns immutable deduplicated byte/text backing, with checked freezing and read-only ranges. The [retained native Program](../engineering/retained-program-image.md) now owns this backing beside independently verified copyable IR and supports existing scalar execution. The [private Static IR proof](../engineering/static-ir.md) now reconstructs actual image definitions, exact kinds/ranges/UTF-8 boundaries and separate CFG lifetimes alongside ordinary scalar/owner/loan proof. The [retained-image execution successor](../engineering/static-execution.md) now connects these operations to the existing canonical VM with frame-local lifetimes, zero guest backing and exact precharged prices. Bare ordinary admission and public guest Static syntax stay gated. The [native source compiler](../engineering/literal-compiler.md) now executes immediate byte/text projection expressions. The [alias IR successor](../engineering/static-alias.md) now preserves exact immutable kinds/ranges and independent liveness. The [typed binding successor](../engineering/static-bindings.md) now supplies native byte/text locals, aliases, text::bytes projections and lexical/nonlocal-exit cleanup. The [private range execution successor](../engineering/static-range-execution.md) now independently proves RANGE 76 and executes actual frame-local byte spans with Fuel/bounds preflight, nested narrowing and recursive/loop isolation; computed source endpoints and their exit cleanup remain open. The [immutable source equality successor](../engineering/static-equality-source.md) now lowers text::equal over actual Static byte-view arguments with explicit text conversion. The [frame range preparation](../engineering/static-view-ranges.md) now supplies compact checked range words against real image proof; the private range successor connects IR/VM execution, while computed source endpoints and their exit cleanup remain open. Remaining: general runtime/range view expressions, CALL actuals and returned-image lifetime/origin receipts, then ordinary public Program admission/dispatch with its remaining execution/admission proof. The narrow CLI Fuel gap is addressed by the [public-limit successor](../engineering/public-fuel-limits.md). Promote public compilation and capability metadata only after end-to-end checks. |
| B05 | Complete the target's scalar/array/record/Buffer references and CFG last-use rules, beyond current scalar-slice references. Enforce whole-root conflicts, mutation/move/drop exclusions, lexical/root generations and bounded group/descriptor reclamation. |

Grounded recursive origin analysis, typed scalar slices, lexical mutable children,
inline CALL ranges and temporary CALL roots are already implemented; do not
schedule them again. Parenthesized temporary roots, repeated slice chaining,
implicit access-mode coercions and disjoint mutable splitting are not automatic
requirements of this audit. They need a justified profile decision if desired.

## Guest Buffer and text integration

| ID | Work and completion condition |
| --- | --- |
| D01 | Add the guest move-only Buffer type, ownership-aware locals/parameters/results and typed IR/verifier/VM integration. Connect the existing native resource/owner/accounting implementation to actual Instance ownership. |
| D02 | Expose and type-check `bytes::empty`, `copy`, `append`, `push`, `reserve`, `view`, `len`. Separate allocator Result errors from hard quota/Fuel traps. Keep old values unchanged on preparation failure and reject self-append through a live view. |
| D03 | Coordinate admitted owner/session registries, replacement transactions, generation retirement, object/Instance/Engine old-plus-new peaks and native metadata allocation. Integrate host sweep/close with automatic Instance teardown; private explicit host hooks are insufficient. |
| D04 | Integrate Buffer moves, loans, tagged payloads, failure/cancellation and partial initialization cleanup without guest cleanup on failure. Preserve exactly one owner and account for retained capacity and pending work. |
| D05 | The [literal-image prerequisite](../engineering/static-literal-image.md) implements private immutable byte/text storage and checked UTF-8 ranges. The [Static IR proof](../engineering/static-ir.md) independently checks read-only definitions/types and CFG lifetimes; the [native execution successor](../engineering/static-execution.md) executes byte reads, lengths and text equality through exact retained image backing. The [literal decoder](../engineering/literal-source.md) now supplies bounded tokens, escape/UTF-8 validation and atomic image interning. The [native source compiler](../engineering/literal-compiler.md) now collects literals atomically and executes immediate byte/text projections against retained images. The [alias IR successor](../engineering/static-alias.md) now supports same-kind descriptor copying without payload allocation. The [typed binding successor](../engineering/static-bindings.md) now lowers native Static locals/aliases, ref str and text::bytes over those views, with lexical and aggregate-return cleanup. General view expressions, Static CALL/return integration and Buffer/input text remain missing. The [private range execution successor](../engineering/static-range-execution.md) now independently proves RANGE 76 and executes actual frame-local byte spans with Fuel/bounds preflight, nested narrowing and recursive/loop isolation; computed source endpoints and their exit cleanup remain open. The [immutable source equality successor](../engineering/static-equality-source.md) now checks and lowers text::equal byte-view arguments over retained images, with exact precharge and temporary cleanup. Dynamic runtime/Buffer/input equality and guest Buffer/input UTF-8 scanning remain open. The [private equality successor](../engineering/static-byte-equality.md) now supports immutable byte/text operands and unchanged precharged pricing. Reuse native continuation/lease machinery, preserve split sequences across 4096-byte chunks, precharge reads and resume cursors without replay. No dynamic/mutable owned text or constant-time equality promise is required. |

## Engine, Instance and bounded runtime

| ID | Work and completion condition |
| --- | --- |
| R01 | Implement owner-thread Engine and one-shot Instance lifecycle APIs, immutable explicitly reusable/pinned Programs, serialized compilation and reentry guards. Current `vm::run` fresh state is not the complete Engine/Instance API. |
| R02 | The [native return-stack fix](../engineering/native-return-stack.md) removes reproduced intermediate return-transaction snapshots; complete preallocation and general stack containment still require the following work. Account for control, compile scratch, Program retention, frames/input/owners/loans/descriptors, pending reply/output and all simultaneous Instances under Engine ceilings. Reserve before allocation, distinguish native OOM from quota and actual process RAM from logical accounting. |
| R03 | Add bounded `step(1..4096)` and resumable transfer/initialization/CALL/RET/copy/tag/store/cleanup recipes. Bound payload chunks and metadata visits, including planning and final publication; do not hide whole-table/type-graph work in one unit. |
| R04 | Implement compile/run monotonic deadlines, cancellation, first-cause precedence, STOPPING cleanup and stable terminal snapshots. Separate guest/input/quota failures from persistent Engine poison; propagate poison to nonterminal children while preserving existing terminal results. |
| R05 | Make cleanup work-budgeted even after Fuel exhaustion; preserve source/target ownership through multi-chunk commits, check stale generations and invalidate roots/groups without unbounded scans. Prove quantum-independent result/Fuel for equal resource/host outcomes. |

## Input, output and typed host boundary

| ID | Work and completion condition |
| --- | --- |
| I01 | Bind an allowed public i32 entry with zero arguments or `ref u8[]` input. Own a bounded input snapshot; limit file/stdin reads before allocation and preserve the same snapshot through execution. Current SOURCE is code input, not guest input bytes. |
| I02 | Implement grant-controlled `output::emit`, staged output storage and limits, success-only publication, output ownership and binary/JSON/text sinks. Trap/cancel/deadline/poison must discard unpublished output; sink partial failure must not replay computation. |
| H01 | Implement policy/run/project/catalog admission and the reachable-requirements <= declarations <= grants <= Engine-ceiling chain. Source metadata never grants authority; builtins and host imports need one consistent typed contract. |
| H02 | Implement bounded typed host catalog binding/digest and exact TLV request/reply codecs, including signed/canonical-bool/wire-layout validation and unknown/duplicate/malformed rejection. No ambient filesystem/network/command authority enters the guest. |
| H03 | Add HOST_REQUEST/WAITING_HOST/reply/INSTALL_REPLY state transitions, unique request identity, one outstanding exchange, limits/deadlines/cancel, malformed/duplicate/late replies and stable request/terminal observations. Start with an in-memory fake adapter. |
| H04 | Snapshot/adopt valid reply backing with quota/Fuel preflight, preserving request/Fuel on preparation OOM and preventing retry after commit. Bound host-call count, per-call/cumulative payloads and adapter cost; report unknown external effects without automatic replay. |

## CLI, diagnostics and profile graduation

| ID | Work and completion condition |
| --- | --- |
| C01 | Add explicit project/run/policy/catalog loaders and source maps. Validate strict bounded JSON, explicit entries, canonical path uniqueness, anchored root membership/reparse rejection and Windows path/device/ADS/case rules. No ambient discovery or glob expansion. |
| C02 | Add the planned guest `--input`, project/policy/grant controls, `inspect --ir`, restricted check/run and broker-only worker surfaces as their underlying implementations become available. Preserve explicit unavailable errors and no unrestricted fallback. |
| C03 | Extend diagnostics to source index and half-open start/end byte spans, stable line maps, bounded UTF-8 messages/counts and explicit no-source values. Validate child spans and escape terminal-control/line injection; never read arbitrary files for snippets. |
| C04 | Complete version/result metadata for build/profile/IR/cost/ABI/IPC, delivery availability, metrics and staged output. Keep guest return data separate from process status and distinguish computation, publication, transfer and external-effect outcomes. |
| C05 | The [public Fuel ceiling/cost successor](../engineering/public-fuel-limits.md) resolves the narrow CLI budget gap. Deliberately reconcile the narrow implementation with the full target's limits and IR/cost revisions. Current source is 4096 bytes, 1024 tokens, 16 functions, 128 global value registers, 256 instructions, 32 call frames, 16 array/record/slice sites and 64KiB aggregate backing. The package's much larger policy limits and u16 operand format are not already supported and must not be copied as current capabilities. |

## Restricted Windows delivery

| ID | Work and completion condition |
| --- | --- |
| W01 | Create and verify the restricted process/token/AppContainer, explicit inherited handles, Job process/commit/CPU limits and suspended-start/assignment sequence before untrusted compilation. Fail setup closed. |
| W02 | Implement authenticated private pipe setup/ACL/nonce, bounded RX/TX and exact IPC framing/correlation/revision validation. Reject truncated/duplicate/trailing/malformed frames and strict JSON violations before dispatch or publication. |
| W03 | Implement serialized parent broker phases, source/entry/policy authority and the staged-result publication barrier: valid result, exit 0, expected EOF/no trailing frame, no prior cancellation/failure and live deadline. Check-only uses the same publication discipline. |
| W04 | Implement cancellation races, late lawful-message drain without host dispatch/output, noninterleaved CANCEL TX, monotonic session/phase/idle deadlines, bounded grace and forced Job termination. Do not overwrite the first cause. |
| W05 | Keep OVERLAPPED/buffer/handle/session I/O leases until actual completion, not merely CancelIoEx or child exit. Bound REAPING, pending I/O, event queues and adapter residual work; retain session slots/reservations until their real release conditions. |
| W06 | Enforce aggregate parent/session/child-commit/transport/adapter/request/reply budgets and verify the required Windows race/denial cases on the real OS. Only then enable restricted availability. Isolation does not establish that a guest decision is correct. |

## Embedding, packaging and evidence

| ID | Work and completion condition |
| --- | --- |
| E01 | Establish an actual Brownie native DLL export and C-host call for public ABI revision 2, including `bc_get_abi_info_v2` and bootstrap/layout/version/capacity validation. Existing Fairy pub functions or historical adapter inspection are not Brownie export evidence. |
| E02 | Implement the bounded process-wide lazy typed handle registry, nonwrapping/retired generations, Engine ownership, owner-thread lifetime identity, synchronization and busy/reentry rejection. Do not pretend arbitrary C pointers can be validated safely. |
| E03 | Implement Program/Instance pin/release/destroy, sized output structs, event/reply/output pointer lifetimes and stable terminal metrics/errors across C calls, including malformed/wrong-thread/stale-handle cases. |
| E04 | Package executable/required runtime (and DLL for embed), license/dependency notices and integrity metadata; run without developer compilers on a clean Windows machine. Verify Linux natively before promising Linux support: the toolchain has a Linux cross-build artifact, not a Brownie Linux execution pass. |
| V01 | Close full-profile conformance using native source-to-VM cases, not model checks or a sum of increment counts. Map/adapt the reference's 32 original source cases and wider accepted obligations explicitly; primitive negative tests alone do not execute the original policy/entry envelopes. |
| V02 | Add risk-focused parser/verifier/lifetime/TLV/IPC mutation/fuzz and allocator/shim failure coverage as the corresponding boundaries are implemented. Check arithmetic/initialization/overlap/generation/rollback and the broker/layout/Buffer-fallback review counterexamples. |
| V03 | Measure representative validation, byte-transform and rule workloads: cold/warm compile, explicit Program reuse, setup/run/publication, heap allocation, accounted/retained/process memory, worker/IPC/host costs and quantum invariance. No current performance target is a measured guarantee. |
| V04 | Measure and bound retained build outputs/cache/symbols/toolchain costs and successful/failed scratch cleanup, including 100 retained edit builds. Keep invocation scratch separate and never prune user sources or another active build. |
| V05 | Define a profile-specific release unit, compatibility/rollback and supported-platform evidence, minimal relevant CI checks and useful user examples/runbooks. There is currently no configured GitHub Actions workflow; do not create an expensive matrix merely to audit docs. Release/push decisions remain separately authorized. |

## Budget and compatibility decisions still open

The accepted initial targets remain: reused setup p95 <=1ms; 10KiB pure compile+
verify p95 <=10ms; empty Instance accounted memory <=32KiB; zero warm scalar-loop
heap allocations; 100 retained edit builds <=32MiB project outputs, excluding explicitly reported
debug/toolchain artifacts. All are
unmeasured. The current 4KiB source ceiling cannot run the 10KiB compilation target;
C05 must define the intended benchmark/profile rather than silently raising caps.

Raw-package dialect differences (including its Result-only propagation versus
accepted M1 Option propagation), IR numbering/operand widths, exact trap/cost
codes and public `core` wording require deliberate reconciliation. Preserve the
working experimental contracts until an intentional profile promotion is agreed.

## Not a remaining-work promise

JIT, guest GC, external bytecode/runtime disk caches, arbitrary FFI/dynamic library
loading, user generics/enums/resources, floating point, Map, regex, closures,
dynamic text ownership, threads and multi-tenant worker pools remain excluded or
out of the first profile. No optional ergonomic syntax or generated ops template
becomes a release requirement merely because a file mentions it.

## Update discipline

Use this inventory for current omissions and the [roadmap](01-roadmap.md) for
ordering. Keep completed increments and exact receipts historical; the previous
roadmap is preserved in [history](history/roadmap-20261103.md). Update the owning
contract, this inventory and actual delivery flags when a gap is closed. Never
convert private native evidence into public guest/OS/ABI completion by wording.

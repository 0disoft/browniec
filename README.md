# Brownie C

## Current implementation (2026-11-06)

[Native retained module programs](docs/engineering/module-program.md) now execute
explicitly selected public i32 entries with scoped calls/nominal records and
original source diagnostics. The public CLI supports the existing single-source
scalar/aggregate and [retained byte/text/shared-byte subset](docs/engineering/public-program.md).
Its [Fuel default is 256 and explicit ceiling is 16000000](docs/engineering/public-fuel-limits.md).
Initialized locals infer existing scalar/tagged values, owned aggregate
initializers and [reference/text views](docs/engineering/reference-inference.md)
through the same typed initialization and ownership checks.
[Option constructors](docs/engineering/option-constructor-inference.md) infer
`.some` from existing i32/bool payloads; ambiguous domains still require context.
[Scalar element-list declarations](docs/engineering/array-list-source.md) now
support `let a=[20,22];` and annotated forms, with ordered one-time evaluation,
complete initialization and existing ownership/cleanup. The
[contextual successor](docs/engineering/array-list-contexts.md) adds direct list
arguments, returned literals and temporary borrows. [List assignment](docs/engineering/array-list-assignment.md)
now supports mutable `a=[20,22];` with complete evaluation before replacing the
existing extent. [Scalar literal projections](docs/engineering/array-literal-projections.md)
now support immediate indexing/length on list and repeated literals, including
grouping and existing UTF-8 element-list checks. [Grouped array values and
projections](docs/engineering/array-expression-projections.md) now extend named
owners and CALL results through index/length, initializers, by-value arguments,
returns, assignment and exact-u8 UTF-8 checks. [Grouped record values and
projections](docs/engineering/record-expression-projections.md) now add constructor
field reads, grouped named/CALL paths, initializers, by-value arguments, returns
and whole/child assignment. Aggregate-valued control flow, grouped lvalues/borrows
and nested/resource-bearing array elements remain unfinished.
[If value expressions](docs/engineering/if-expressions.md) now support the existing
scalar and shallow-tagged domains, including inferred locals, nested tails,
else-if chains and existing nonlocal-exit cleanup. Aggregate/reference/Buffer
joins and void functions remain separate work.
[Native project metadata](docs/cli/project-format.md) now admits complete explicit
source maps, entries and declared requirements; it opens no files and grants nothing.
Public project loading and CLI module/entry flags, general mutable/non-byte/
Buffer/input references, generic runtime-view equality and the full accepted
profile remain unfinished. See [remaining work](docs/product/04-remaining-work.md).
The delivery entries below retain their historical evidence and gate statements;
they do not override this current status.

## Owned arrays and ordinary CALLs in the private VM

Implemented at `5cccbd3`, with native transaction support at `9be6c7e`. The private
VM now executes temporary array borrows, owned array locals, scalar/array CALL
arguments/results and borrowed-result forwarding. Borrowed authority and owned
copies publish in one transaction; ARET moves the result token without copying its
payload. Terminal cleanup closes local views and drops their roots atomically.
See the [contract](docs/engineering/m2-slice-result-owned-vm.md).

Windows development/release each passed 33 native groups and 2,215 CLI cases on
489 matching inputs, with no final native result reuse. See the
[evidence](docs/evidence/m2-slice-result-owned-vm-windows-20261104.json).
Record CALLs, native owned entry inputs, general result bindings and public
metering remain gated. Public borrowed-result compilation/capabilities stay closed.
The earlier increments below retain their original verification scope.

## Private returned-view VM

Frame/destination bindings are implemented at `e183e7a`, with actual private
op63/64/65 execution at `d468ca1`. `vm::run_slice_result` independently admits
rootless borrowed inputs, executes scalar bodies/loans/forwarded calls and returns
a native Held receipt. Shared/mutable results retain the selected input lifetime;
mutable parents stay suspended through returned descendants. Terminal cleanup
runs through the atomic handoff, and execution failure drains invocation metadata
without undoing prior writes. See the [contract](docs/engineering/m2-slice-result-vm.md).
Final Windows development/release each passed 11 native groups and 2,215 CLI
cases on 485 matching inputs, without native result reuse. The development scalar
parser stack regression is fixed at `af4aa13`. See the
[evidence](docs/evidence/m2-slice-result-vm-windows-20261104.json).

That rootless increment initially gated owned temporaries and ordinary CALLs.
The owned-array increment above now admits them for scalar/array calls; result
locals/arguments and public metering remain gated. Public compilation, ordinary VM admission and
capability flags still reject borrowed results. The implementation increments
below retain their original verification scope.

## Private returned-view handoff and capture lifetime

Implemented at `7f8f455`, with anonymous mutable capture restoration at
`b82500d`. Native transactions transfer selected shared/exclusive
views, retain selected anonymous array owners, release unselected captures and
keep exclusive parents suspended through returned descendants. Preparation and
late cleanup failures preserve metadata and earlier payload writes; zero-Fuel
invocation abort drains the owned resources. See the
[contract](docs/engineering/m2-slice-result-runtime.md).
Windows development/release each passed 12 native groups and 208 CLI cases on
479 matching inputs, without final result reuse. See the
[evidence](docs/evidence/m2-slice-result-runtime-windows-20261104.json).


That increment covers native component execution. The private VM integration
above now executes op63/64/65 in its admitted subset; public results stay gated.

## Private returned-view IR preparation

Implemented at `670a041`. A separate preparation/forward/return IR carries exact
scalar/access and input-origin metadata. Its independent verifier rechecks CFG,
live loans, suspended parents, recursive origins and unique cleanup-to-return
recipes. Prepared identities cannot become ordinary scalar values. Public compile
and ordinary VM admission stay closed. That increment's proof alone does not
authorize execution; the private VM above separately admits its subset. See the
[contract](docs/engineering/m2-slice-result-ir.md).
Windows development/release each passed 10 native groups and 208 CLI cases on
476 matching inputs; see the
[evidence](docs/evidence/m2-slice-result-ir-windows-20261104.json). These are private
analysis and closed-gate checks; runtime handoff/lifetime, full suites, Linux,
isolation, packaging and performance remain unverified. Local only; no push.


The [remaining-work audit](docs/product/04-remaining-work.md) and
[current roadmap](docs/product/01-roadmap.md) reconcile full-profile requirements
with the implemented experimental core as of 2026-11-03. Sections below retain
their named increments and historical evidence.

## Borrowed-result input-origin analysis: execution gated

Implemented privately at `0d1a8cb`. `compiler::inspect_slice_results` proves one
input origin for each admitted borrowed-result body, including lexical subviews,
branches, forwarding and grounded recursive summaries. It rejects conflicting
origins and callee-owned/temporary roots. Only input-position facts leave analysis;
no runtime ticket or internal analysis Program is returned. Public compilation
still rejects every borrowed-result declaration. See the
[contract and remaining lifetime obligations](docs/engineering/m2-slice-result-origins.md).

Windows development/release each passed 12 native groups and 990 tool-free CLI
cases, with 462 matching final inputs. Development retains native/CLI results
across harness-only corrections; original inputs and reuse are explicit in the
[evidence](docs/evidence/m2-slice-result-origins-windows-20261103.json). Release
reruns the entire selected scope. Returned-view lifetime/handoff, full native/M1/
other M2/Linux/isolation/packaging/performance remain unverified. Local only;
no push, release or deployment.

## Borrowed-result signature analysis: execution gated

Implemented at `1ced18e`. Private frontend analysis describes `fn ref T[]` and
`fn ref mut T[]` declarations for the six scalar types, with exact-mode candidate
input positions. A candidate mask does not prove the body's actual return origin.
Public compilation continues to reject every borrowed-result declaration,
including unreachable helpers. No returned borrow executes. See the
[contract and remaining lifetime obligations](docs/engineering/m2-slice-result-signatures.md).

Windows development/release each passed 12 native groups and 902 tool-free CLI
cases, with 459 matching final inputs and rechecked retained identities. Public
borrow features below remain available; VM layouts, prices and capabilities are
unchanged. Full native/M1/other M2/Linux/isolation/packaging/performance were not
rerun. Local only; no push, release or deployment. See the
[verified evidence](docs/evidence/m2-slice-result-signatures-windows-20261103.json).

## Borrow temporary arrays in CALL arguments

Implemented at `8983737`. Literals and owned array results now work directly in
slice argument positions: `read(ref [42; 3])`, `update(ref mut make())`, and
`update(ref mut make()[1..])`. The temporary stays alive through endpoint and
argument evaluation and CALL; cleanup closes its view before dropping its owner.
Six scalar types, exact modes and scalar/array/record results are supported.
See the [example](examples/temporary-array-borrow-arguments.brc) and
[contract](docs/engineering/m2-temporary-array-borrow-arguments.md).

Windows development/release each passed 16 native groups and 812 tool-free CLI
cases, with 457 matching final inputs and rechecked retained identities. Repeated
site fixtures may hit the existing 1M public Fuel cap. Parenthesized roots,
repeated slicing and returned/escaping borrows remain unsupported. Full native/
M1/other M2/Linux/isolation/packaging/performance were not rerun. Local only; no
push, release or deployment. See the
[verified evidence](docs/evidence/m2-temporary-array-borrow-arguments-windows-20261103.json).

## Borrow named slice ranges in CALL arguments

Implemented at `b8ab0eb`. `update(ref mut part[lo..hi])` and readonly range
arguments accept existing lexical slices, formals and derived children. Bounds
are relative to the parent and evaluate once before acquisition. Mutable children
suspend the parent during the call; capture cleanup resumes it after return.
Scalar, array and record results use the existing paths. See the
[example](examples/named-slice-range-arguments.brc) and
[contract](docs/engineering/m2-named-slice-range-arguments.md).

Windows development/release each passed 12 native groups and 854 tool-free CLI
cases, with 454 matching final inputs and rechecked retained identities. Recursive
and repeated-site boundary fixtures reach the existing public 1M Fuel cap;
ordinary forwarding and range cases complete. Temporary roots, repeated slicing
and escaping borrows remain unsupported. Full native/M1, other M2, Linux,
isolation, packaging and performance were not rerun. Local only; no push, release
or deployment. See the
[verified evidence](docs/evidence/m2-named-slice-range-arguments-windows-20261103.json).

## Borrow array ranges directly in CALL arguments

Implemented at `749f9bf`. Existing arrays support `ref array[lo..hi]` and
`ref mut array[lo..hi]`, including open and empty ranges. Endpoints are evaluated
once in order, before the new borrow opens. Existing cleanup handles endpoint
exits, later arguments and runtime errors. Scalar, array and record results work.
Exclusion remains per root, so two mutable ranges of one array still conflict.
See the [example](examples/array-range-borrow-arguments.brc) and
[contract](docs/engineering/m2-array-borrow-range-arguments.md).

Windows development/release each passed 11 native groups and 752 tool-free CLI
cases, with 451 matching final inputs and rechecked retained identities.
Named-slice ranges, temporary roots and escaping borrows remain unsupported.
Full native/M1, other M2, Linux, isolation, packaging and performance were not
rerun. Local only; no push, release or deployment. See the
[verified evidence](docs/evidence/m2-array-borrow-range-arguments-windows-20261103.json).

## Borrow arrays directly in CALL arguments

Implemented at `528934b`. `update(ref mut output, ref input)` borrows existing
whole arrays for one call, with exact scalar types and explicit access modes.
The handle opens during argument evaluation and closes after return, so later
arguments observe the active borrow and the caller can access the array again
when the call completes. Early exits and runtime failures use existing cleanup.
Scalar, array and record results are supported. See the
[example](examples/array-borrow-arguments.brc) and
[contract](docs/engineering/m2-array-borrow-arguments.md).

Windows development/release each passed 11 native groups and 644 tool-free CLI
cases, with 448 matching final inputs. The evidence records development native
reuse after a CLI-only expected-value correction and retained artifact hashes.
Inline ranges, temporary roots and escaping borrows remain unsupported. Full
native/M1, other M2, Linux, isolation, packaging and performance were not rerun.
Local only; no push, release or deployment. See the
[verified evidence](docs/evidence/m2-array-borrow-arguments-windows-20261103.json).

## Record results from mutable reborrow calls

Implemented at `e8105f6`. Functions receiving an exclusive child may now return
exact-nominal records, including nested records and all six scalar field types.
Owned arguments, readonly slices, independent writers, forwarding, recursion and
record-result assignment use the existing CALL and authenticated return path.
The caller destination must be empty before loan/copy publication; canonical
restoration precedes moving the existing result token. See the
[example](examples/mutable-slice-record-result.brc) and
[contract](docs/engineering/m2-slice-reborrow-record-results.md).

Windows development/release each passed 20 native groups and 282 tool-free CLI
cases, with 445 matching final inputs. The evidence records development native
reuse after a CLI-only harness change and rechecked artifact/receipt hashes.
The larger mixed-record, recursive and repeated-assignment fixtures reach the
existing public 1M Fuel cap; lighter mixed and repeated-result cases complete.
Full native/M1, other M2, Linux, isolation, packaging and performance were not
rerun. Local only; no push, release or deployment. See the
[verified evidence](docs/evidence/m2-derived-record-result-windows-20261103.json).

Earlier sections record their named commits; superseded gates are historical.

## Array results from mutable reborrow calls

Implemented at `56842b9`. A function receiving an exclusive child may return a
fixed scalar array, including with owned arguments. Result validation and caller
restoration precede the existing token transfer; an occupied caller destination
rejects before loan/copy publication. Derived record results remain gated. See
the [example](examples/mutable-slice-array-result.brc) and
[contract](docs/engineering/m2-slice-reborrow-array-results.md).
Development/release each passed 13 native groups and 232 CLI cases, with 443
matching input hashes and rechecked artifact/receipt hashes. Full native/M1,
other M2, Linux, isolation, packaging and performance were not rerun. Local only;
no push. See the [verified evidence](docs/evidence/m2-derived-array-result-windows-20261103.json).

## Owned arguments with mutable reborrow calls

Implemented at `c9f2294`. A derived mutable slice may now be passed with owned
scalar arrays and records, readonly slices, other independent writers and scalar
arguments. Atomic copying completes before loan/control publication. Derived
array/record results remain gated. Development and release each passed 16 native
groups and 188 CLI cases with 441 matching input hashes. Full native/M1, other M2,
Linux, isolation, packaging and performance were not rerun. Local only; no push.
See the
[example](examples/mutable-slice-owned-call.brc) and
[contract](docs/engineering/m2-slice-reborrow-owned-calls.md), with
[verified evidence](docs/evidence/m2-derived-owned-call-windows-20261103.json).

## Mutable slice reborrows from source

Implemented at `3a07820`. `let ref mut i32[] child = ref mut parent[lo..hi];`
selects a temporary exclusive range from an owned slice, mutable formal or child.
The parent is unavailable until the child leaves scope; normal exits, early
returns, loops, tagged propagation and aggregate-result cleanup restore it.
All six scalar element types work, and `array_slice_mutable_reborrow` is now true
in version JSON. Derived CALLs still reject owned arguments and aggregate results.
The CLI Fuel cap, static-site limits, profiles and instruction prices are unchanged.
Development and release each passed 9 native groups and 2,615 CLI cases, including
68 new reborrow cases and full M1; all 438 input hashes match. Full native, other
M2, Linux, isolation, packaging and performance were not rerun. Local only; no push.
See the [example](examples/mutable-slice-reborrow.brc) and
[source contract](docs/engineering/m2-slice-reborrow-source.md), with
[verified Windows evidence](docs/evidence/m2-slice-reborrow-source-windows-20261103.json).

## Public IR reborrow admission and execution

Implemented at `409d77c` on `main`, following shared-guard preparation at
`42a66e9`. Public `verifier::verify_sites` returns the exact proved `Sites` forest
before the VM checks quota, reserves preparation Fuel, constructs backing or
publishes local authority. Nonempty sites and exclusive mutable formals route to
the canonical core with that forest; owned-only opcode 61/62 programs route without
a formal. Public IR opcode 61/62 admission and execution are enabled.

Derived CALLs accept borrowed/scalar arguments and scalar results only. Owned
arguments and aggregate results reject before effects, including in unreachable
functions. Ordinary CALLs retain owned arguments and aggregate results. Strict
`inspect` and raw legacy execution keep their separate gates. Source grammar,
parser, compiler and CLI capability flags remain gated, and prices, bounds,
layouts and external-bytecode prohibition are unchanged.

Development passed 8 core groups; release passed 19 groups (8 core, 6 boundary,
5 proof), with 74 mutable-parameter CLI cases in each profile. All 404 current
inputs matched, with 94 production sources unchanged against `e952162`; five
production paths differ. Final core reruns passed after overlapping native and
public test helper context lifetimes were split. No stack-size measurement was
made. Full native/other M2/M1/Linux/isolation/packaging/allocator/timing were not
rerun. Local only; no push. See the
[contract](docs/engineering/m2-slice-public-reborrow.md) and
[verified evidence](docs/evidence/m2-slice-public-reborrow-windows-20261103.json).

## Public canonical routing for exclusive mutable formals

Implemented at `0d57882` on `main`. Exclusive mutable formals now use fresh local
canonical state and two maps with exact empty Sites and no second proof; ordinary
readonly execution, the public entry body, native wrapper, verifier and dispatch
helpers remain unchanged. Development and release each passed 5 native groups
(2 new differential plus 3 existing public mutable) and 74 public mutable CLI cases;
all 403 inputs matched both manifests and artifact hashes were rechecked. The sole
production delta is `src/vm.fy` versus `a023542`; 97 other sources match under Git LF.
Public opcode 61/62 admission and derived source grammar remain gated, while native
execution remains available; empty Sites must change with public verification.
Full native/other M2/M1/Linux/isolation/packaging/allocator/native size-stack/timing
and performance were not rerun. Local commits only; no push. See the
[contract](docs/engineering/m2-slice-public-canonical.md) and [verified evidence](docs/evidence/m2-slice-public-canonical-windows-20261103.json).

## Default checked native derived CALL admission

Implemented at `2a30fae` on `main`. Default `inspect` reuses the former `inspect_derived` body after LF normalization; `execute`/`run` keep their bodies. Compatibility names delegate without a second proof.
Owned/aggregate derived shapes reject before Fuel/effects in every function, including unreachable ones; dirty contexts fail before execution.
Prices, cleanup, native authority and layouts are unchanged. Development and release each passed 8 core groups; release also passed 8 regression groups, 16 native groups total.
All 402 current input hashes and receipt identities were rechecked; only `vm_reborrow_execution` changes production, while 97 sources match baseline `8c9c8b6`.
Core manifests differ only in two previously unselected gate fixtures, exercised by final regression.
Native default only: public/compiler/legacy remain gated; no production module imports the wrapper, so no CLI rebuild was needed.
Public VM/source promotion and derived owned/aggregate support remain separate; no CLI/full native/other M2/M1/Linux/performance rerun or push.
See [contract](docs/engineering/m2-slice-derived-call-default.md) and [verified evidence](docs/evidence/m2-derived-call-default-windows-20261103.json).

## Private native derived CALL execution

Explicit native `inspect_derived` and `execute_derived` run exclusive-source
derived CALLs through the shared VM. They reuse the existing scalar/control
preflight and canonical cleanup. Ordinary CALLs retain owned and aggregate
transactions; the derived path accepts borrowed or scalar arguments and returns
a scalar only. Existing native wrapper, public, legacy, source and CLI gates
remain closed, and the program layout and logical prices are unchanged.

Implemented at `cce170a`. Development passed 8 new native groups. Release
passed those 8 plus 10 regression groups, and all 74 release public
mutable-parameter CLI cases passed. All 402 current input hashes and retained
compiler, CLI and native receipt identities were verified. An initial 30-group
regression batch exceeded 600 seconds and has no completed verdict, so it is not
counted as a pass. The final selector limits that run to 10 directly affected
groups; core manifests differ from final regression/CLI only in
`tools/verify-m2-slice-elements.py`. Production, test, lockfile and compiler
inputs were identical across completed phases.

Four production sources changed; 94 other production sources are unchanged
under Git LF normalization. Existing call-frame and handoff bodies are unchanged
except for two imports in the call-frame module. Cleanup preserves guest writes
and the original outcome or retryable metadata; owned storage and backing
disposal remain the caller's responsibility. The next step is promotion through
existing/default checked admission. Owned derived arguments, aggregate results
and guest/public promotion remain gaps. No full native, other M2, full M1,
Linux, isolation, packaging, allocator, native-size/stack or timing rerun was
performed. This work is local only; no push was made. See the
[execution contract](docs/engineering/m2-slice-derived-call-execution.md) and
[Windows evidence](docs/evidence/m2-derived-call-execution-windows-20261103.json).

## Private native derived CALL handoff

`slice_reborrow_call_vm::enter` now publishes checked child loans to callee
formals. Native tests perform real writes, recursive forwarding, exact ticket
and selected-view restoration, and abort cleanup that preserves writes. Rootless
derived sources resolve through their immutable formal anchor. Scalar/control
publication and shared VM dispatch are the next integration; public admission
remains gated.

Implemented at `cf18d2d`. Development passed 8 new native groups; release passed
those 8 plus 12 prior admission/CALL groups. All 401 current input hashes match.
CLI and Linux were not rerun. See the [handoff contract](docs/engineering/m2-slice-reborrow-call-vm.md)
and [Windows evidence](docs/evidence/m2-slice-reborrow-call-vm-windows-20261103.json).

## Private derived-source CALL preparation

Native `slice_reborrow_call_admission::prepare` authenticates live reborrow
children and stages a CALL's ticket generations, shared retention and roots.
It checks frame/combined-depth limits and preserves the original invocation and
payload on every result. Preparation exposes no publication or execution path;
return authentication, ticket restoration and abort coordination come next.

Implemented at `a4a1430`. New native tests passed six groups in each profile;
release also passed twelve existing helper regression groups. All 399 current
input hashes match. CLI and Linux were not rerun in this increment. See the
[admission contract](docs/engineering/m2-slice-reborrow-call-admission.md) and
[Windows evidence](docs/evidence/m2-slice-reborrow-call-admission-windows-20261103.json).

## Private suspended-reborrow CALL proof

`verifier::inspect_reborrow_calls` adds an analysis-only proof for synchronous
CALLs across suspended exclusive-reborrow forests. It preserves the caller's
exact live set, validates available leaf sources and exact modes/tags/origins,
and rejects duplicate exclusive sources, roots or formal origins. Existing
inspection and checked execution gates remain in place.

Implemented at `eb2a0ce`; development and release each passed 20 native groups
and 2,495 public slice/M1 CLI cases, with 397 matching current input hashes.
Native receipt authentication, combined-depth reservation and ticket-generation
restoration are the next step before enabling these calls for execution.
See the [proof contract](docs/engineering/m2-slice-reborrow-call-ir.md) and
[Windows evidence](docs/evidence/m2-slice-reborrow-call-ir-windows-20261103.json).

## Current public scalar slices

Public `check` and `run` support readonly `i32`, `bool`, `i64`, `u8`, `u32`
and `usize` slices over existing same-function owned lexical arrays, immutable
`let ref Tag[]` bindings and `ref Tag[]` parameters. Whole, ranged, computed,
open and empty bounds, exact-tag aliases, forwarding, recursion and explicit
`ref name` arguments are supported. UTF-8 predicates apply only to `u8`
arrays and slices. See the
[public scalar-slice contract](docs/engineering/m2-slice-element-public.md)
and the working [summing example](examples/slice-elements.brc). Implemented at
`ec73328`; development and release each passed 22 native groups and 2,833 CLI
cases, including all 2,007 M1 CLI cases. Both profiles matched 351 current input
hashes and their retained CLI identities. See the
[Windows evidence](docs/evidence/m2-slice-element-public-windows-20261101.json).

```text
browniec check examples/slice-elements.brc --json
browniec run examples/slice-elements.brc --fuel 1000000 --json
```

## Current public mutable scalar slices

`check` and `run` also support `let ref mut Tag[] p = ref mut a[lo..hi];`
and `p[index] = value` for all six scalar tags over same-function mutable owned
arrays. Whole, computed, open and empty ranges, relative reads, `.len`, selected
`u8` UTF-8 and lexical cleanup are supported. The root becomes accessible again
after the slice's scope ends. Version JSON reports `array_slice_mutable: true`.

```text
browniec check examples/mutable-slices.brc --json
browniec run examples/mutable-slices.brc --fuel 1000000 --json
```

See the [public mutable-slice contract](docs/engineering/m2-slice-exclusive-public.md)
and [working example](examples/mutable-slices.brc). Mutable aliases, subranges of
an existing slice, slice returns and readonly CALL coercions remain unsupported. The existing readonly slice and parameter behavior is unchanged.

Implemented at `ecfe96c`; development and release each passed 26 selected native
groups and 2,421 CLI cases, with 360 matching current input hashes. See the
[Windows evidence](docs/evidence/m2-slice-exclusive-public-windows-20261101.json).

## Current public mutable scalar-slice parameters

`check` and `run` support `ref mut Tag[]` formals and explicit `ref mut name`
arguments for all six scalar tags. Exact mode/type proof, bounded CALL execution,
normal caller restoration and mandatory invocation cleanup are connected.
Version JSON reports `array_slice_mutable_parameters: true`. Readonly/owned
programs retain their existing execution path and prices.

```text
browniec check examples/mutable-slice-parameters.brc --json
browniec run examples/mutable-slice-parameters.brc --fuel 1000000 --json
```

See the [public parameter contract](docs/engineering/m2-slice-mutable-parameters-public.md)
and [working example](examples/mutable-slice-parameters.brc). Mutable aliases,
subloans, coercions and returned borrows remain unavailable.

Implemented at `914ae79`; development and release each passed 33 selected native
groups and 2,495 CLI cases, with 372 matching current input hashes and rechecked
artifact/receipt identities. The CLI retains its one-million Fuel maximum;
native sufficient-Fuel tests cover 31 nested calls and the next-frame limit.
See the [public parameter Windows evidence](docs/evidence/m2-slice-mutable-parameters-public-windows-20261101.json).

## Current private canonical CALL execution

The [canonical coordinator](docs/engineering/m2-slice-record-result-authority.md)
now executes scalar, exact-shape array and exact-nominal record results with
scalar, owned array/record, shared and exclusive CALL arguments. Result validation
precedes canonical loan restoration; only infallible ownership-token movement
follows. Aggregate returns retain their existing payload and owner generation
without a second extent. Logical prices and public capabilities are unchanged.
Suspended/derived exclusive CALLs and guest/public reborrow promotion remain
gated. Next is suspended/derived exclusive CALL proof. Earlier adapter/proof
stages below describe their own checkpoints.

Implemented at `4a87cb1`. Development and release each passed 34 distinct native
groups (15 core, 19 regression) and 2,495 CLI cases. All 395 current input hashes
were rechecked; the core inventory's one unselected test update is documented in
[Windows evidence](docs/evidence/m2-slice-record-result-authority-windows-20261102.json).
Native size/stack, allocator and timing remain unmeasured. Local commits only.

## Private metered owned reborrow adapter

The [native instruction adapter](docs/engineering/m2-slice-reborrow-vm.md) now
executes owned op61/62 with 65,537 Fuel per transition, canonical receipt/site/frame
checks and atomic child/parent binding publication. Existing owned dispatch reads
and writes available child ranges. Abort drains before clearing metadata and
preserves prior writes and original outcomes. Implemented at `995e22f`.
Three fixed 31-entry maps add private metadata without duplicating receipts;
there is no native memory or speed claim. Rootless formal adaptation, canonical
CALL maps and shared VM-loop wiring remain pending. Public/internal reborrow
execution and suspended CALL inspection remain gated; existing prices and
capabilities are unchanged.

Development and release each passed 24 selected native groups and 2,495 CLI
cases, with 381 matching inputs and rechecked artifact/receipt identities. See
[adapter Windows evidence](docs/evidence/m2-slice-reborrow-vm-windows-20261102.json).

## Private independent-root reborrow order proof

The [IR order proof](docs/engineering/m2-slice-reborrow-order.md) now matches the
native authority stack's reverse restoration across independent roots. Immutable
begin-PC ranks and sixteen newer-child masks identify the pending order from
existing live words, including suspended children, without another per-PC stack.
Implemented at `0163a26`. Site allocation order does not determine restore order.
Public/internal reborrow execution and CALL during suspension remain gated;
metered site/binding and shared VM lifecycle integration precede admission.

Development and release each passed 23 selected native groups and 2,495 CLI
cases, with 379 matching inputs and rechecked artifact/receipt identities. See
[order Windows evidence](docs/evidence/m2-slice-reborrow-order-windows-20261102.json).

## Private combined CALL/reborrow authority

The [native authority stack](docs/engineering/m2-slice-authority.md) now owns
CALL/subrange receipts, counts all pending restores (including empty CALLs) in
one 31-entry bound and reserves generations using that combined depth. Returns
validate frame ownership and strict reverse order; abort atomically drains the
existing pool before clearing receipts while preserving writes. Implemented at
`d0567c6`. This adds fixed private metadata, with no measured memory or speed
claim and no change to public VM execution, source grammar or existing prices.
The IR order proof above now aligns independent-root restoration with this stack.
Metered VM binding/control/return integration and guest/public admission remain
separate deliveries.

Development and release each passed 24 selected native groups and 2,495 CLI
cases, with 378 matching inputs and rechecked artifact/receipt identities. See
[authority Windows evidence](docs/evidence/m2-slice-authority-windows-20261102.json).

## Private exclusive reborrow IR proof

[Private op61/62 and independent inspection](docs/engineering/m2-slice-reborrow-ir.md)
now prove child/parent lifetimes, parent suspension/restoration and exact flow
joins/backedges for owned and formal scalar slices. Implemented at `3987195`.
Public verification and both internal execution entries reject these instructions
before dispatch. CALL during pending reborrow remains gated; combined depth and
receipt ownership precede metering, VM execution and guest/public admission.

Development and release each passed 23 selected native groups and 2,495 CLI cases,
with 376 matching inputs and rechecked artifact/receipt identities. See the
[IR Windows evidence](docs/evidence/m2-slice-reborrow-ir-windows-20261102.json).

## Private exclusive subrange foundation

The [native reborrow foundation](docs/engineering/m2-slice-exclusive-reborrow.md)
suspends an exclusive parent by narrowing its existing ticket slot, then restores
its original range under a fresh generation. It retains the same owner write
session and uses no extra pool slot or payload extent. Implemented at `ab85195`.
The IR lifetime proof above extends this native foundation. Guest reborrow
syntax, combined CALL/reborrow admission and VM integration remain pending.

Development and release each passed 18 selected native groups and 2,495 CLI
cases, with 374 matching input hashes at that stage and rechecked artifact/receipt
identities. See the
[reborrow Windows evidence](docs/evidence/m2-slice-exclusive-reborrow-windows-20261102.json).

## Historical stages

The notes below record implementation stages and gated behavior at the named
commits. They are historical receipts, not current usage instructions.

### Private mutable parameter source stage

The [mutable parameter source stage](docs/engineering/m2-slice-mutable-parameters-source.md)
accepts `ref mut Tag[]` formals and explicit `ref mut name` arguments for all six
scalar tags. Native tests compile actual source, independently inspect the IR and
perform writes, nested CALLs, mixed arguments, returns and error cleanup through
the shared private VM. Access modes and tags must match exactly; aliases,
subloans and returned borrows remain unavailable. Implemented at `2f9cc0d`.

Public verification and CLI admission still reject mutable formals before
backing, Fuel or dispatch, including unused functions. Public promotion is the
next delivery; the owned mutable and readonly behavior above is unchanged.

Development and release each passed 22 selected native groups and 2,489 CLI
cases, with 370 matching current input hashes and rechecked artifact/receipt
identities. See the
[source Windows evidence](docs/evidence/m2-slice-mutable-parameters-source-windows-20261101.json).

The [private mutable-formal IR foundation](docs/engineering/m2-slice-mutable-parameters-ir.md)
now constructs and independently checks all six mutable argument descriptors.
Mutable CALL execution, runtime formal dispatch and source parameters
remain unavailable; public owned mutable slices keep the behavior above.
Implemented at `33da699`; development and release each passed 26 selected native
groups and 2,421 CLI cases, with 361 matching current input hashes. See the
[formal-IR Windows evidence](docs/evidence/m2-slice-mutable-parameters-ir-windows-20261101.json).

The [private exclusive CALL handoff foundation](docs/engineering/m2-slice-exclusive-call-handoff.md)
now transfers and restores fresh exclusive tickets atomically in the existing
pool slots, preserving owner sessions and invalidating older generations.
Native tests cover actual scalar writes, 31 nested handoffs, generation reserves
and abort cleanup in a full mixed pool. Mutable CALL runtime wiring and guest
parameters remain gated; this is a native protocol foundation. Implemented at
`88b96ff`; development and release each passed 26 native groups and 2,421 CLI
cases, with 363 matching input hashes. See the
[handoff Windows evidence](docs/evidence/m2-slice-exclusive-handoff-windows-20261101.json).

The [private mutable CALL IR proof](docs/engineering/m2-slice-mutable-call-ir.md)
now admits exact mutable arguments and formal forwarding during independent
inspection, rejects repeated exclusive sources/owned roots and preserves shared
duplicate arguments. Runtime frame handoff/restore and guest mutable parameters
remain gated. No public capability or Fuel price changes. Implemented at
`20afacd`; development and release each passed 21 native groups and 2,421 CLI
cases, with 364 matching input hashes. See the
[mutable CALL IR Windows evidence](docs/evidence/m2-slice-mutable-call-ir-windows-20261101.json).

The [private mutable CALL frame adapter](docs/engineering/m2-slice-mutable-call-vm.md)
now transfers mixed borrowed arguments after atomic owned copies, preserves
exclusive owner sessions across formal release and restores fresh caller tickets
on return. Native tests exercise actual writes, nested frames and abort cleanup.
Shared VM-loop/control wiring, mutable formal instruction dispatch and guest
parameters remain unconnected; the existing public admission gate stays intact.
Implemented at `6ea599c`; development and release each passed 15 native groups
and 2,421 CLI cases, with 366 matching current input hashes. See the
[mutable frame Windows evidence](docs/evidence/m2-slice-mutable-call-vm-windows-20261101.json).

The [private mutable CALL execution stage](docs/engineering/m2-slice-mutable-execution.md)
now performs mutable formal reads/writes through the shared VM core, publishes
scalar/control frames after successful transactions and restores callers across
scalar/tagged/array/record returns. Native tests execute nested and reused frames,
actual writes and abort cleanup. Mutable source parameters and public admission
remain gated; this is inspected IR execution. Implemented at `f22a6da`;
development and release each passed 16 native groups and 2,421 CLI cases, with
368 matching current input hashes. See the
[mutable execution Windows evidence](docs/evidence/m2-slice-mutable-execution-windows-20261101.json).

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
- Status: M1 scalar checkpoint verified; experimental M2 function-owned scalar arrays and source records implemented. Array parameters/results and record construction, field access, copies, extraction, and replacement are available. Immutable by-value record parameters are verified in development and release. Private record-result VM ownership transfer is verified for its original inputs. Bounded source record returns and typed call initializers are verified in development and release at `bb401a4` (14 native groups and 2,438 CLI cases per profile). Direct nominal record constructor returns are verified in development and release at `0a7b539`. Record calls in constructor child fields are implemented at `c4cd6ab` and verified in development and release. Record borrows, workers, DLL embedding, and full-profile conformance remain incomplete.
- Root constructor assignment: verified in development and release; child constructor assignment is verified in development and release.
- Private function-owned record IR/verifier and frame-local record VM execution
  are verified in development and release.
- Source helper-local records: implemented at `98a4525`; verified in development and release.
- Source record parameters: implemented at `d0ca7e7`; development and release each passed 51 native groups and 2,318 CLI cases in separate core/regression phases.
- Record-result signatures: verified for their original baseline (22 native groups and 2,317 CLI cases per profile). Nominal results are recorded separately from scalar and array metadata. The former blanket pre-IR gate and "source record returns unavailable" status are historical, superseded by the [bounded source successor](docs/engineering/m2-struct-result-source.md).
- Record-result IR/verifier: implemented at `dc1574b` and verified in development and release. Private metadata uses callee-owned shape anchors and `SRET` checks a single live exact-nominal record; its kind 11 runtime gate is historical and superseded by the VM transfer successor. See [the IR contract](docs/engineering/m2-struct-results-ir.md).
- Record-result VM: ownership transfer is implemented at `68552f0` and verified for its source-gated inputs. `SRET` prepays 42,113 Fuel, validates the complete result without payload writes, clears the child token, and publishes it into the caller-owned destination. The [bounded source successor](docs/engineering/m2-struct-result-source.md) now emits a subset of these calls and returns and is verified in development and release. See [the VM contract](docs/engineering/m2-struct-result-vm.md).
- Direct record return calls: implemented at `c23e6e4`. `return make(...);` forwards
  an exact-nominal result through the existing CALL/SRET ownership transfer.
  Development and release each passed 18 native groups and 505 CLI cases in
  separate core/regression phases, with 196 matching rechecked inputs. See
  [the source contract](docs/engineering/m2-struct-return-calls.md).
- Direct record constructor returns: implemented at `0a7b539` and verified in
  development and release. `return Pair { ... };` stages fields in declaration
  order, creates one anonymous immutable result site only after evaluation, and
  transfers it with the existing `SRET`. See [the constructor
  contract](docs/engineering/m2-struct-return-constructors.md).
- Design date: 2026-10-23
- Record call-result assignment: implemented at `0a6a759`. `p = make(...);`
  retains the live mutable root through argument evaluation and CALL, copies
  the exact-nominal result with `SASSIGN`, then drops the anonymous result.
  Development and release each passed 30 native groups and 725 CLI cases.
  See [the contract](docs/engineering/m2-struct-call-assignment.md).
- Child record call-result assignment: implemented at `63be9e5`.
  `outer.child = make(...);`, including deep paths, copies the anonymous result
  into the existing child with `SSUBASSIGN` and releases the temporary with
  `SDROP`. Development and release each passed 26 native groups and 575 CLI
  cases. See [the contract](docs/engineering/m2-struct-child-call-assignment.md)
  and [Windows receipt](docs/evidence/m2-struct-child-call-assignment-windows-20261028.json).
- Constructor child record calls: implemented at `c4cd6ab` and verified in
  development and release, each with 23 native groups and 529 CLI cases across
  separate core/regression phases. See the [Windows
  receipt](docs/evidence/m2-struct-child-calls-windows-20261028.json).
  An exact-nominal `R { .child = make(args) }` stages the returned child's scalar
  leaves and drops the temporary before later fields or the parent `SINIT`,
  `SREPLACE`, or `SSUBREPLACE`. See [the contract](docs/engineering/m2-struct-child-calls.md).
- First delivery target: Windows 11 x64

Brownie C is a small, statically typed source language and JIT-free bytecode VM.
The implementation direction is primarily Fairy C. A native Brownie VM executable
accepts .brc source and runs it without starting Go, MSVC, or a C compiler.

The native `browniec` compiles and runs the experimental scalar and source-array
pipelines, including records in ordinary helpers and recursive VM frames. The bool/branch increment extends its i32 functions with bool parameters,
results, and locals, `! == != < <= > >= && ||`, short-circuit evaluation,
`if`/`else if`/`else`, standalone lexical blocks, and early returns. `main` remains
zero-argument and returns i32. Parsing, scalar type checks, private bytecode
generation, CFG verification, and VM dispatch are Fairy C. Fuel bounds every
executed instruction. Direct calls and bounded VM recursion continue to work. The
loop increment adds `while`, classic `for`, `break`/`continue`, and metered
backedges with a bounded inductive initialization check. The tagged increment adds
shallow `Option<i32|bool>` and `Result<i32|bool, i32|bool>` values plus exhaustive
`switch` statements. The propagation increment adds postfix `?` for those scalar
wrappers, returning the payload on success and the enclosing wrapper on failure.
The switch-expression increment extends exhaustive `switch` to expression position,
with value yields or direct returns in exhaustive shallow-wrapper arms. The i64
increment adds full-width signed scalars in typed locals, functions, calls,
assignments, loops, and switch joins, with checked arithmetic and no implicit
conversions. The unsigned increment adds `u8`, `u32`, and 64-bit guest `usize` at
the same source positions, with checked arithmetic and unsigned ordering. Explicit
widening adds `EXPR as TYPE` for seven domain-preserving integer pairs, with no
implicit conversion or promotion. The [widening contract](docs/engineering/m1-widening.md)
owns that addition. [Integer operators](docs/engineering/m1-integer-operators.md)
add fixed-width `~`, `&`, `^`, `|`, and checked `<<`/`>>` for every integer type.
The [arm-statement increment](docs/engineering/m1-switch-arm-statements.md) adds
branches, blocks, loops, and lexical transfers inside expression arms. Full-profile
conformance remains unverified. The [source-array read increment](docs/engineering/m2-array-source.md)
adds immutable scalar-array declarations in the outermost `main` body and exact
`usize` indexed reads through the entry-array VM. The [source-array write
increment](docs/engineering/m2-array-write.md) adds mutable outermost declarations
and exact `usize` element assignment; focused verification passed in development and release. The
[source-array copy-initializer increment](docs/engineering/m2-array-copy-source.md)
adds `let|var T[N] dest = source;` for exact matching visible arrays and independent
snapshot semantics through the existing `ACOPY` IR/runtime; focused checks passed
in development and release. The [array-length increment](docs/engineering/m2-array-length.md)
adds `NAME.len` as an exact `usize` constant, including in pure scalar `for` headers.
The [lexical-scope increment](docs/engineering/m2-array-scopes.md) admits arrays in
`main` blocks, branches, loops, and switch arms, with cleanup at scope exits and
loop transfers. [Whole-array assignment](docs/engineering/m2-array-assignment.md)
adds `dest = source;` for exact matching arrays, overwriting existing mutable storage
without allocating another extent. The [private frame foundation](docs/engineering/m2-array-frames.md)
separates function ownership and recursive VM array tokens. The
[helper-local increment](docs/engineering/m2-array-helpers.md) extends source
arrays to scalar and shallow wrapper-returning helpers, including reverse cleanup
on `?` failure returns. [Source array parameters](docs/engineering/m2-array-parameters.md)
add immutable exact-shape arguments with left-to-right snapshots, forward/mutual
calls, and cleanup of pending captures on normal and early exits. Named array results
and typed call-result initializers are supported by the [source result increment](docs/engineering/m2-array-result-source.md).
[Direct return calls](docs/engineering/m2-array-return-calls.md) additionally admit
`return make(arguments);` with the same argument capture and ownership rules.
[Repeated return literals](docs/engineering/m2-array-return-literals.md) also admit
`return [value; N];`, evaluating the fill once in the declared element context.
[Call-result assignment](docs/engineering/m2-array-call-assignment.md) admits
`array = make(arguments);`, copying the result into existing mutable storage.
[Repeated-literal assignment](docs/engineering/m2-array-literal-assignment.md)
admits `array = [value; N];`, evaluating once and filling existing storage in place.
Borrows, slices, workers, and DLLs remain later work.
Source [helper-local records](docs/engineering/m2-struct-function-source.md) are implemented at `98a4525` for ordinary scalar, wrapper-returning, and array-returning helpers. Constructor, copy, and subrecord-extraction paths use `ir::record_in` with the lowering function. Existing record forms run in callee frames under the shared sixteen sites and owners, 128-byte roots, sixteen-leaf staging, and 32 VM frames. Array-returning helpers drop local records in reverse mixed array-record order before `ARET`, preserving the returned array. Version JSON reports `struct_helper_locals: true`; opcodes, Fuel, and profile strings are unchanged.

Development and release each passed 48 native groups and 2,860 CLI cases, including 89 helper-local record cases. The native report was retained after correcting the aggregate expected count from 47 to 48; CLI matrices ran individually, including a fresh nested matrix after updating an obsolete root-replacement expectation. Release completed the `--function-source --profile release` aggregate. The [receipt](docs/evidence/m2-struct-function-source-windows-20261027.json) records 153 input hashes, compiler and artifact identities, and equal native identities across profiles. At `98a4525`, source record parameters/results and borrows were unavailable; [record parameters](docs/engineering/m2-struct-parameters-source.md) and a [bounded record-result subset](docs/engineering/m2-struct-result-source.md) now have successors, while record borrows remain unavailable. Full native suites, other struct/array matrices, Linux, packaging, DLL, isolation, and performance were not run.

The [record-parameter signature foundation](docs/engineering/m2-struct-parameter-signatures.md) recognizes bare nominal parameter types and stores each record ID separately from scalar tags and array lengths. The bounded signature table adds 128 bytes. Its pre-lowering rejection was the source gate at that checkpoint; the [source parameter successor](docs/engineering/m2-struct-parameters-source.md) removes it. The signature receipt therefore remains historical for the gate implementation. Record results now have a separate [bounded source successor](docs/engineering/m2-struct-result-source.md); record borrows remain unavailable. That increment added no opcode, Fuel charge, profile, or version capability.

Development and release each passed 16 native groups and 2,226 CLI cases: 88 signature-gate, 89 helper-record, 80 array-parameter, and 1,969 M1 cases. Development ran individual commands; release completed `--parameter-signatures --profile release`. The [receipt](docs/evidence/m2-struct-parameter-signatures-windows-20261027.json) records compiler/artifact identities, 181 input hashes, and equal native identities across profiles. This is focused signature verification; full native/array suites, M0, Linux, isolation, DLL, packaging, allocation instrumentation, and performance were not run.

The private [record-parameter IR foundation](docs/engineering/m2-struct-parameters-ir.md) adds immutable callee-owned record sites and 128 zero-tag parameter placeholders. CALL arguments distinguish scalar registers, array sites, and record sites; record arguments require exact nominal identity, caller ownership, liveness, and an immutable source or explicit snapshot. Parameter lifetimes occupy bits 16..31, participate in joins/backedges, and must be dropped before scalar or array returns. Its initial VM availability gate is superseded by the metered record-call successor below. Its source-gate claim is also historical and superseded by the current source parameter lowering.

The complete `--parameter-ir` aggregate passed 28 native groups (7 new record-parameter, 9 array-call, 6 record function-IR, 6 source signature) and 2,226 CLI cases per development/release profile without result reuse. The [receipt](docs/evidence/m2-struct-parameters-ir-windows-20261027.json) records 182 input hashes, compiler/artifact identities, commands and outcomes. Matching native identities, all input hashes, and the current compiler/release binary were rechecked before archival. Implementation: `9b43e0d`. Full native suites, other CLI matrices, M0, Linux, packaging, DLL, isolation, allocation instrumentation and performance were not run.

The private [mixed argument-copy foundation](docs/engineering/m2-call-argument-copies.md) stages 0..8 array/record arguments as one transaction. It checks every source against the original owner table, normalizes record padding, validates nested bools, and admits all owner/payload reservations before publishing bytes or tokens. Failed batches preserve all backing bytes and owner metadata. That storage-only increment changed no VM gate, source grammar, Fuel or capabilities. Its statement that source lowering remained unavailable was historical and is superseded by the source parameter slice.

The complete `--call-copies` aggregate passed 70 native groups (9 new, 61 affected) per development/release profile without result reuse. The [receipt](docs/evidence/m2-call-argument-copies-windows-20261027.json) records 62 input hashes and matching native identities. All inputs, compiler and unchanged SDK identities were rechecked before archival. No CLI build/matrix, full native suite, M0, Linux, packaging, DLL, isolation, allocation instrumentation or performance measurement was run. Earlier receipts remain historical for changed owner/storage, root-lock and harness inputs.

The [private record-call VM](docs/engineering/m2-struct-call-vm.md) now executes verified record-parameter IR through one mixed array/record copy transaction. It prepays the complete CALL before frame admission or payload/token changes, binds aggregate tokens, then publishes scalar arguments and the child return frame. Array-only/scalar-only prices are unchanged; record calls add 2,048 batch Fuel plus 43,008 per record and existing array work. The kind 11 VM gate is removed. That slice's source-gate statement is historical; the current source successor emits the verified forms. Opcodes, other charges, profiles and version capabilities are unchanged.

Implementation: `97bf1e2`. Development and release each passed 47 unique native groups in two separate invocations: [core, 21 groups](docs/evidence/m2-struct-call-vm-core-windows-20261027.json) followed by [regressions, 26 groups](docs/evidence/m2-struct-call-vm-regressions-windows-20261027.json). This is stepwise verification, not a single combined aggregate run. Both receipts have the same 58 input hashes, compiler and SDK identities, and disjoint test selections; all were rechecked before archival. No CLI build/matrix, full native suite, M0, Linux, isolation, DLL, packaging, allocation instrumentation or performance measurement was run. Earlier receipts remain historical for changed VM, root-lock, test and harness inputs.

Source [record parameters](docs/engineering/m2-struct-parameters-source.md) are implemented at `d0ca7e7` and verified in development and release. A formal is an immutable nominal record; at that checkpoint each argument was one bare visible record binding, and mutable sources are captured with `SCOPY` before later arguments evaluate. All formal sites are predeclared after the record catalog scan, then bound by owning function and record-formal ordinal within the unchanged 16 static sites. No extra 128-byte signature site map is introduced. The source path reuses the existing record-aware `release_from` cleanup and array-result finisher, including scalar-return drops before `RET` and non-result record drops before `ARET`. Record returns were unavailable at that checkpoint; the [source result successor](docs/engineering/m2-struct-result-source.md) adds the bounded subset.

Development and release each passed 51 unique native groups and 2,318 CLI cases. The [core receipt](docs/evidence/m2-struct-parameters-source-core-windows-20261028.json) records 14 native groups and 180 CLI cases; the [regression receipt](docs/evidence/m2-struct-parameters-source-regressions-windows-20261028.json) records 37 native groups and 2,138 CLI cases. The CLI selections comprise 114 source parameter, 66 signature, 80 array parameter, 89 helper-local record and 1,969 M1 cases per profile. These are two separate phase runs with disjoint native selections, matching profiles, and identical 206 input hashes, compiler and SDK identities; all inputs were rechecked before archival. Native stress tests use 16,000,000 Fuel; the CLI retains its 1,000,000 ceiling, with four costly fixtures expected to pass `check` and report `fuel` on `run`. Other native/CLI matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.

The [record-result signature foundation](docs/engineering/m2-struct-result-signatures.md)
stores a bare nominal result as record ID + 1 in a new 16-byte signature array and
keeps the scalar tag and array length at zero. At its original baseline, the
compiler rejected every scanned record result at the function name before IR,
aggregate catalogs, or bodies were lowered. `main` remains a zero-argument scalar
`i32` entry point. That increment added no IR, VM, opcode, Fuel, profile, or version
capability. Development and release each passed 22 native groups and 2,317 CLI cases. The [Windows receipt](docs/evidence/m2-struct-result-signatures-windows-20261028.json) records the original baseline, executed commands, compiler/SDK and CLI identities, input hashes, and outcomes. The native selection comprises 6 new record-result, 6 record-formal, 6 array-result and 4 scalar-function groups. CLI coverage comprises 72 new record-result, 66 record-formal, 114 source record-parameter, 96 array-result and 1,969 M1 cases per profile. All 209 input hashes, the compiler, SDK and final release CLI were checked before archival. Full native suites, other CLI matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.

The blanket gate in that receipt is historical and superseded by the
[bounded source result slice](docs/engineering/m2-struct-result-source.md). At
`bb401a4`, a bare visible exact-nominal `return name;` and an exact-nominal
`let`/`var` call initializer lower through the existing result IR and VM. Result
anchors reuse a matching formal or reserve a dead function-owned site before body
lowering. Development and release each passed 14 native groups and 2,438 CLI
cases. The result-signature checker's loop-label metadata was repaired after the
aggregate, followed by a 70-case per-profile CLI rerun against retained binaries.
Native, build, and other CLI selections were not rerun. The [Windows
receipt](docs/evidence/m2-struct-result-source-windows-20261028.json) records 219
rechecked input hashes and the stepwise repair.

The [direct constructor-return slice](docs/engineering/m2-struct-return-constructors.md)
adds `return Pair { ... };` for an exact-nominal record result. The compiler peeks
past the `return` and lets the shared constructor check consume the matching type
name and `{`. Fields evaluate from left to right into depth-first staging slots;
exact-nominal child bindings, child paths, and nested constructors use their
existing staging. Only after all fields and the terminator are complete does the
compiler allocate one immutable anonymous function-owned site and emit `SINIT`.
The parent owner and binding name are not published while a field expression
can return or transfer out of a loop. The shared reverse mixed finisher then drops other visible arrays
and records and emits `SRET`. Transfer adds no payload extent, though the result
root has its normal constructor extent; a reconstructed parameter keeps its old
formal copy and the new result live together until cleanup. General expressions
and parenthesized constructor returns remain unsupported. The [child call-assignment
successor](docs/engineering/m2-struct-child-call-assignment.md) adds an
exact-nominal child path as a call-result destination. There is no new opcode,
VM charge, profile, or version flag. The [constructor child-call
successor](docs/engineering/m2-struct-child-calls.md) now accepts an
exact-nominal record call as a child field value, verified in development and
release in the [Windows
receipt](docs/evidence/m2-struct-child-calls-windows-20261028.json). General aggregate arguments outside the exact-record-formal call position,
  parenthesized child calls, and call-result
field selection remain unsupported. The [Windows
receipt](docs/evidence/m2-struct-return-constructors-windows-20261028.json) records
199 matching rechecked inputs and both retained CLI identities. Earlier receipts
remain historical for their original inputs. Development and release each passed
26 native groups (6 new plus 20 named-result, direct-call, and
signature regressions) and 532 CLI cases (144 new, 152 direct return-call, 166
named source-result, and 70 result-signature).

The [subrecord return-path successor](docs/engineering/m2-struct-return-paths.md)
accepts `return outer.child;` for an exact-nominal record result, including deep
paths. The shared extractor emits consecutive `SREAD` operations into consecutive
registers, allocates one anonymous immutable site, and emits one `SINIT`; the
source stays live through creation. The shared finisher then performs reverse mixed
cleanup and emits `SRET`. There is no temporary owner, staging store/load sequence,
new opcode, Fuel charge, profile, or version field. This slice is implemented at
`d4aa643` and verified in development and release. Each profile passed 25 native
groups and 579 CLI cases across four separate phases; 205 inputs matched. Record
borrows, general or parenthesized expressions, and `call().child` returns remain
unsupported. Earlier receipts remain historical for their original inputs.

A [private struct-layout planner](docs/engineering/m2-struct-layout.md) now plans
acyclic record metadata, and a [scalar-only storage slice](docs/engineering/m2-struct-storage.md)
initializes and accesses selected scalar records in caller-backed arena bytes.
A [private copy/assignment slice](docs/engineering/m2-struct-copy.md) appends
independent scalar records and overwrites existing storage, including self and
partial overlap. A [private nested-storage slice](docs/engineering/m2-struct-nested-storage.md)
initializes selected acyclic records from depth-first scalar leaves and reads or
writes scalar field paths; selected roots are capped at 128 bytes while
unselected valid records may be larger. A [private nested copy/assignment
slice](docs/engineering/m2-struct-nested-copy.md) appends nested records by value
and overwrites existing extents without changing the cursor, including self and
partial overlap. A shared [struct-owner foundation](docs/engineering/m2-struct-owners.md)
now puts record descriptors in the existing 16-slot table, verifies catalog layout
on access, and rejects record tokens in array APIs. A [private struct-owner
copy/assignment slice](docs/engineering/m2-struct-owner-copy.md) appends independent
record owners and requires exact record identity for assignment. Its 17-group
Windows selection passed development and release; the previous 34-group owner receipt is historical for changed
inputs. A [private entry-owned struct IR and verifier](docs/engineering/m2-struct-ir.md)
adds opcodes 41..46 for initialization, copy, scalar leaf access, drop, and exact-ID
assignment; record lifetimes use bits 16..31 beside array lifetimes. The original
[private struct VM](docs/engineering/m2-struct-vm.md) contract executed those
private instructions with fixed prepaid Fuel charges, sixteen entry tokens, and
the shared array owner table and payload arena. Development and release each
passed all 38 selected native groups and the existing 115-case CLI suite for that
slice. A
[function-owned record IR foundation](docs/engineering/m2-struct-function-ir.md)
assigns each static record site to one function and verifies all opcodes 41..49
against that owner, including same-function copy/assign/subassign sources. A
[frame-local record VM](docs/engineering/m2-struct-function-vm.md) now executes
verified helper IR in up to 32 guest frames. Each frame owns sixteen record token
slots over the same 16 shared owners and payload arena, using the same indexing as
arrays. Opcodes, Fuel, frontend lowering, and version are unchanged. The 13-group
smoke suite passed in one native invocation. The complete `--function-vm` invocation passed 46 native groups and
2,383 CLI cases per development/release profile without result reuse. The
[receipt](docs/evidence/m2-struct-function-vm-windows-20261027.json) records 109 input hashes,
compiler/artifact identities, commands and outcomes. Implementation commit:
`80ed712`. Other CLI matrices, full native suites, Linux, packaging,
isolation and performance were not rerun. Frame entry
allocates no separate table or arena, while `SINIT`/`SCOPY` reserve shared owners
and payload and require dead destination tokens. Writes and assignments require
live mutable destinations. Drops clear frame tokens; dead middle extents stay
charged until suffix reclamation. Source helper records were unsupported at
`80ed712`; the [source helper successor](docs/engineering/m2-struct-function-source.md)
enables those declarations. At `80ed712`, record parameters/results and borrows
were unsupported; the [record-parameter successor](docs/engineering/m2-struct-parameters-source.md)
and [record-result successor](docs/engineering/m2-struct-result-source.md) now
implement their bounded source subsets, while record borrows remain unsupported.
The 512-slot token array carries no measured
allocation, stack, or speed claim. The earlier
`--function-ir` 31-group and 2,383-CLI result remains historical for its original
scope at `3380b10`; its
[receipt](docs/evidence/m2-struct-function-ir-windows-20261027.json) records those
inputs and outcomes. Its test file changed one of six function-IR groups to expect
helper execution; the other five are unchanged. A
[declaration-only source struct slice](docs/engineering/m2-struct-source.md)
parses forward-referencing scalar and nested named fields into immutable layouts.
Both profiles passed 23 native groups and 2,208 CLI cases each for that
declaration-only slice, recorded in the
[stepwise receipt](docs/evidence/m2-struct-source-windows-20261026.json).
The [bounded source struct-value slice](docs/engineering/m2-struct-values.md)
is the historical read baseline: entry-only scalar-field construction with exact
declaration order and one-level scalar field reads. Typed field expressions are
staged left to right, then consecutive loads feed `SINIT`; the compiler declares
the binding after emitting that initializer, and a runtime failure aborts.
Read-only record programs select
`brownie.m2-struct-read/1`, while declaration-only programs keep their existing
profile. For that baseline, development and release each passed 28 native groups
and 2,352 CLI cases, plus three supplemental cases, recorded in the
[historical receipt](docs/evidence/m2-struct-values-windows-20261026.json). That
baseline left nested construction, field chains, struct parameters/results, and
borrows unsupported; successors implement all three named capabilities, while
record borrows remain unavailable. A
[source struct-field write slice](docs/engineering/m2-struct-write.md) adds
entry-only `NAME.FIELD = EXPR;` for one mutable scalar leaf. It resolves the
binding and field before a single exact-typed RHS, emits `SWRITE` after the
expression and terminator, and mutates the existing record extent without a new
copy, owner, or payload extent. For-header writes remain rejected; condition
reads and body writes are accepted. Programs with nonempty record bindings and
opcode 44 select `brownie.m2-struct-write/1`; version JSON adds
`struct_write_profile`.
The full `--write` selection passed 24 native groups and 2,472 CLI cases per
development/release profile; the
[historical receipt](docs/evidence/m2-struct-write-windows-20261026.json) records
both artifacts and the executed checks. The later source-copy compiler change
makes both the read and write receipts historical for the current inputs. A
[source struct-copy slice](docs/engineering/m2-struct-source-copy.md) adds
entry-only `let|var P q=p;` initialization and `p=q;` assignment for exact nominal
scalar-record types. `SCOPY` creates an independent owner and extent; `SASSIGN`
reuses a mutable destination's existing extent, including for self-assignment.
Programs with nonempty record bindings and opcode 42 or 46 select
`brownie.m2-struct-copy/1` ahead of the write and read profiles, and version JSON
adds `struct_copy_profile`. Development and release each passed 39 native groups
and 2,582 CLI cases, including 110 new copy cases. The
[stepwise receipt](docs/evidence/m2-struct-source-copy-windows-20261026.json)
records development native/build reuse after CLI fixture corrections. The complete
aggregate harness was not rerun.
The [source nested-struct slice](docs/engineering/m2-struct-source-nested.md)
adds inline named child constructors, multi-segment scalar read/write paths, and
whole-root copies for entry-owned nested records. The constructor cursor walks the
record tree iteratively in source order. Each scalar leaf's tag comes directly
from the cursor, and its staging slot is allocated immediately before that
expression is parsed; no tag array is returned. Leaves stage left to right before
consecutive loads and one `SINIT` for the root. Child constructors add no owner, site, or
extent, so a root still occupies one site and one extent. Paths resolve to
depth-first scalar-leaf ordinals, including leaves in preceding nested siblings.
Source staging is limited to 16 scalar leaves total, record nesting and path
length to 16, and a selected root to 128 planned bytes; the existing 16 sites, shared 16 owners,
65,536-byte arena, and scalar limits remain. A bound record with a nested field
selects `brownie.m2-struct-nested/1` ahead of the copy, write, and read profiles;
unused nested declarations do not promote another program. Development and release
each passed 36 native groups and 2,710 CLI cases, including 128 nested cases,
through the complete `--nested` harness on the corrected source. The
[receipt](docs/evidence/m2-struct-source-nested-windows-20261027.json) records
inputs, artifacts, commands and the corrected release regression; it is historical
for the current child-binding compiler inputs. Implementation commits: `576d062`
and `716c14b`.
The [child binding initializer slice](docs/engineering/m2-struct-child.md) admits
`R { .i = i }` when the child field's nominal type exactly matches a visible
whole record binding. The compiler emits one `SREAD` and `STORE` per source scalar
leaf into the parent's staging at that field, before a later sibling expression
can mutate the source. The resulting snapshot is independent; the source stays
live and its normal cleanup is unchanged. Child capture adds no `SCOPY`, temporary
owner, site, or extent, while the new parent root still consumes one owner and
extent. The existing leaf, depth, root, site, owner, arena, register, and
instruction limits remain. Programs stay on `brownie.m2-struct-nested/1`, and
version JSON adds `struct_child_binding_initializers: true`. The complete
`--child` harness passed 21 native groups and 2,798 CLI cases, including 88 child
cases, in each development/release profile. The
[receipt](docs/evidence/m2-struct-child-windows-20261027.json) records 90 input
hashes, compiler and CLI artifact hashes, commands, and outcomes. Implementation commit:
`ed63d1550ffd820e2ad197fe1be9d6b2e0b197a0`.
[Subrecord declaration initializers](docs/engineering/m2-struct-extract.md) now
also accept `let I i = p.i` with an exact nominal record endpoint. The new value
owns an independent copy; changing either value does not affect the other.
The compiler uses consecutive `SREAD` results and one `SINIT`, with no temporary
owner or staging instructions. Subrecord assignment is handled by its
[successor](docs/engineering/m2-struct-subassign.md). Version JSON adds `struct_subrecord_initializers: true` under the
existing nested profile. Development and release each passed 26 native groups
and 2,915 CLI cases stepwise. Development reuses its unchanged native result after
two CLI-only diagnostic fixes; final CLI matrices and release native groups ran
afterward. The [receipt](docs/evidence/m2-struct-extract-windows-20261027.json)
records 92 input hashes, compiler/artifact hashes, commands, and reuse provenance.
Implementation commit: `f65a1d7`. Earlier child-binding and
nested receipts are historical for changed compiler and fixture inputs.
The [historical per-leaf assignment slice](docs/engineering/m2-struct-subassign.md)
admitted
`p.i = q.i`, `p.i = i`, and `i = p.i` for exact nominal types and mutable
existing destinations. Source leaves are captured before writes; self/sibling
copies preserve value semantics. Assignment uses the existing target storage
without a temporary owner and retains the nested profile. Fatal errors abort the
invocation without transactional rollback. Version JSON adds
`struct_subrecord_assignment`. The complete `--subassign` invocation passed 15
native groups and 3,044 CLI cases in each development/release profile. The
[receipt](docs/evidence/m2-struct-subassign-windows-20261027.json) records 91
harness input hashes plus four CLI fixture hashes, compiler/artifact hashes,
commands, and outcomes. Implementation commit: `666da70`. The extraction receipt
is historical for changed compiler and fixture inputs.
[Atomic subrecord assignment](docs/engineering/m2-struct-subassign-atomic.md)
replaces per-field lowering with one checked `SSUBASSIGN` instruction. It stages
at most 128 canonical bytes before changing the destination, retains existing
owners/storage, and uses no new scalar registers. The assignment charge is
131,072 Fuel, so 16 scalar leaves now fit the CLI allowance. Failure leaves the
selected destination unchanged; earlier statements and external effects are not
rolled back. Version JSON adds `struct_subrecord_assignment_atomic` under the
existing nested profile. The complete `--atomic` invocation passed 26 native
groups and 3,046 CLI cases per development/release profile. The
[receipt](docs/evidence/m2-struct-subassign-atomic-windows-20261027.json) records
99 input hashes, compiler/artifact identities, commands, and outcomes. Integration
commit: `5589803`; foundation: `2b5917c`. The per-leaf receipt is historical for
changed verifier/VM/compiler inputs.
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

The declaration-only contract and its receipt remain historical evidence for
declarations without record bindings.
The earlier nested-storage 18-group receipt is historical for changed
inputs; nested-copy 24-group checks passed development and release. The copy
receipt passes 28 groups per profile in development and release. The planner's
earlier 14-group and storage's 20-group receipts remain historical for changed
inputs.
The [array parameter signature foundation](docs/engineering/m2-array-signatures.md)
records element types and exact lengths; the subsequent source increment removes
its original compilation gate.
The [atomic argument-copy foundation](docs/engineering/m2-array-arguments.md)
preflights a complete batch of independent storage copies before mutation.
[Private array calls](docs/engineering/m2-array-calls.md) connect those copies to
the verifier and VM, with immutable exact-shape parameters and independent frame
owners. The source parameter increment supplies argument capture and cleanup.
The [array result signature foundation](docs/engineering/m2-array-result-signatures.md)
records exact return shapes; its original source gate is removed by the source result increment.
The [private array-result increment](docs/engineering/m2-array-results.md)
adds independent verification and owner transfer between VM frames. Returning
the callee's sole live array copies no payload and needs no additional owner;
source return lowering now connects typed call initializers and bare-name returns to it.

```powershell
./build/toolchain/fairyc.exe build
./build/browniec.exe run examples/answer.brc --json
./build/browniec.exe run examples/branches.brc --json
./build/browniec.exe run examples/loops.brc --fuel 1000 --json
./build/browniec.exe run examples/tagged.brc --json
./build/browniec.exe run examples/propagation.brc --json
./build/browniec.exe run examples/switch-expression.brc --json
./build/browniec.exe run examples/i64.brc --json
./build/browniec.exe run examples/unsigned.brc --json
./build/browniec.exe run examples/widening.brc --json
./build/browniec.exe run examples/bitwise.brc --json
./build/browniec.exe run examples/switch-arm-statements.brc --json
# array source requires explicit fuel for arena preparation
./build/browniec.exe run examples/array-read.brc --fuel 100000 --json
# return_i32 is 42; process exit is 0
./build/browniec.exe run examples/array-write.brc --fuel 100000 --json
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice write
python -B tools/record-m2-array-write-evidence.py
# The recorder can later add all 1,969 scalar CLI cases with --scalar-regression.
./build/browniec.exe run examples/array-copy.brc --fuel 100000 --json
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice copy
python -B tools/record-m2-array-write-evidence.py --slice copy --scalar-regression
# After a completed matching receipt, docs-only updates can reuse it:
python -B tools/record-m2-array-write-evidence.py --slice copy --reuse-scalar-regression
./build/browniec.exe run examples/array-length.brc --fuel 100000 --json
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice length
python -B tools/record-m2-array-write-evidence.py --slice length --scalar-regression
./build/browniec.exe run examples/array-scopes.brc --fuel 100000 --json
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice scopes
python -B tools/record-m2-array-write-evidence.py --slice scopes --scalar-regression
./build/browniec.exe run examples/array-assignment.brc --fuel 100000 --json
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice assignment
python -B tools/record-m2-array-write-evidence.py --slice assignment --scalar-regression
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice frames
python -B tools/record-m2-array-write-evidence.py --slice frames --scalar-regression
./build/browniec.exe run examples/array-helpers.brc --fuel 100000 --json
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice helpers
python -B tools/record-m2-array-write-evidence.py --slice helpers --scalar-regression
```

See [Development](DEVELOPMENT.md) to provision the pinned compiler and for build
prerequisites. The [toolchain setup contract](docs/engineering/toolchain-setup.md)
records host outputs, validation, and verification evidence. This CLI is for trusted
local source only; Windows isolation is not implemented.

## Product intent

The first expected workloads are application data validation, byte transforms, and
rule evaluation. They are starting assumptions, not evidence that Brownie C should
replace a general-purpose language such as Python.

The planned brownie.safe/0.3 profile provides:

- bool, u8, i32, i64, u32, and 64-bit usize
- scalar arrays with 1 to 4096 elements
- limited acyclic plain structs
- ref and ref mut, static ref str, and explicit text byte views
- Option and Result, including transferable Buffer values
- checked arithmetic, fallible owned Buffer operations, and explicit output staging

The profile excludes user resources, generics, enums, raw pointers, FFI, JIT,
dynamic strings, Map, closures, and guest garbage collection for this first slice.
Those limits describe the profile, not the language forever.

## Delivery boundary

| Level | Intended capability | Current state |
| --- | --- | --- |
| core | Source compile, verify, and native VM CLI | Experimental i32/i64/u8/u32/usize/bool expressions, explicit widening, branches, loops, shallow tagged values, switch statements and expressions, `?` propagation, source arrays, declaration-only source struct layouts, function-owned struct IR execution, helper-local record construction/read/write lowering, bare-name record copy initialization/whole-record assignment, bounded nested constructors/scalar paths/whole-root copies, whole-record child binding initializers, subrecord declaration initializers, atomic subrecord assignment, immutable by-value record parameters with bare binding, constructor, subrecord path, or exact-result call arguments, bounded bare-name, direct-call, and direct-constructor record results with exact-nominal `let`/`var` call initializers, and exact-nominal record calls in constructor child fields (verified in development and release); private record-result IR/verifier metadata is verified for its original inputs (39 native groups and 2,317 CLI cases per profile), and source record parameters passed 51 native groups and 2,318 CLI cases per development/release profile in two separate phase runs. Bounded source record results passed 14 native groups and 2,438 CLI cases per development/release profile at `bb401a4`, followed by a focused 70-case-per-profile checker metadata repair. Direct constructor returns are verified in development and release at `0a7b539`. Exact-nominal subrecord return paths are implemented at `d4aa643` and verified in development and release; each profile passed 25 native groups and 579 CLI cases. Nested results are historical after the child compiler change, the child feature passed the complete combined harness in development and release; scalar M1 and array reads verified, focused array and struct VM checks recorded, the struct construction/read and field-write baselines recorded historically, and source-copy checks verified stepwise in development and release |
| restricted | Windows worker plus parent broker | Not implemented; M4 |
| embed | Trusted native host through a DLL ABI | Not implemented; M5; no public C export |

The native VM is source-only. Bytecode is private compiler output; there is no
external bytecode input or disk runtime code cache. Program values are immutable
and reusable, Instance values are one-shot, and an Engine is owner-thread bound.

Untrusted source requires an independently OS-tested restricted worker. The embed
path is for trusted native hosts only. Passing a VM check does not prove the truth
of a policy result, the safety of an external effect, or the absence of native bugs.

## Documentation map

- [Architecture](ARCHITECTURE.md): system shape and trust boundaries
- [Development](DEVELOPMENT.md): current build reality and future workflow
- [Validation](VALIDATION.md): evidence rules and unimplemented checks
- [M0 probes](probes/m0/README.md): native signatures, build and verification
- [Direct functions](docs/engineering/m1-functions.md): calls, VM frames, and bounds
- [M1 scalar slice](docs/engineering/m1-scalar-slice.md): current grammar, limits, and CLI
- [M1 bool and branches](docs/engineering/m1-branches.md): typing, scopes, CFG, slots, and branch Fuel
- [M1 loops](docs/engineering/m1-loops.md): while/for, transfer, backedges, and loop limits
- [M1 shallow tagged values](docs/engineering/m1-tagged.md): Option/Result, switch, packing, and CASE verification
- [M1 `?` propagation](docs/engineering/m1-propagation.md): payload extraction, wrapper failure, precedence, and Fuel
- [M1 switch expressions](docs/engineering/m1-switch-expressions.md): expression-position arms, typed joins, and verifier boundaries
- [M1 i64 scalars](docs/engineering/m1-i64.md): literal context, checked arithmetic, limits, and evidence
- [M1 unsigned scalars](docs/engineering/m1-unsigned.md): `u8`, `u32`, `usize`, representation, and limits
- [M1 explicit widening](docs/engineering/m1-widening.md): seven integer pairs, precedence, lowering, and Fuel
- [M1 integer operators](docs/engineering/m1-integer-operators.md): fixed-width bitwise operations, checked shifts, and precedence
- [M1 arm statements](docs/engineering/m1-switch-arm-statements.md): branches, loops, transfers, typed joins, and inherited depth budgets
- [M1 checkpoint audit](docs/engineering/m1-checkpoint-audit.md): scalar exit requirements and remaining profile limits
- [M2 array layout](docs/engineering/m2-array-layout.md): historical layout foundation for compact scalar payloads, arena preflight, and checked offsets
- [M2 array storage](docs/engineering/m2-array-storage.md): scalar codecs, repeated initialization, and element access in caller-owned backing bytes
- [M2 array owners](docs/engineering/m2-array-owners.md): typed descriptors, generation checks, independent copies, explicit release and bounded reclamation
- [M2 array IR](docs/engineering/m2-array-ir.md): historical private entry-array instructions and independent lifetime/CFG verification
- [M2 array VM](docs/engineering/m2-array-vm.md): historical native array dispatch, owned payload storage, Fuel, and runtime failures
- [M2 source array reads](docs/engineering/m2-array-source.md): current grammar, lifetimes, caps, profiles, and verification for `let T[N] name = [EXPR; N];` and `name[EXPR]`
- [M2 source array writes](docs/engineering/m2-array-write.md): mutable declarations, element assignment, evaluation order, profiles, and verification for `var T[N] name = [EXPR; N];` and `name[EXPR] = VALUE;`
- [M2 source array copy initialization](docs/engineering/m2-array-copy-source.md): matching visible arrays, independent storage, resources, profiles, and verification for `let|var T[N] dest = source;`
- [M2 source array length](docs/engineering/m2-array-length.md): exact `usize` length constants, pure scalar composition, resources, and focused verification for `NAME.len`
- [M2 lexical array scopes](docs/engineering/m2-array-scopes.md): nested declarations, reverse cleanup, loop transfers, and bounded storage reuse
- [M2 whole-array assignment](docs/engineering/m2-array-assignment.md): exact-shape copies into existing mutable storage, preflight, private IR, and Fuel
- [M2 private array function frames](docs/engineering/m2-array-frames.md): function ownership, recursive frame tokens, shared quotas, and parameter work sequencing
- [M2 helper-local arrays](docs/engineering/m2-array-helpers.md): function-local source declarations, recursion, and cleanup on wrapper propagation
- [M2 array parameter signatures](docs/engineering/m2-array-signatures.md): bounded shape metadata and the historical gate replaced by source parameter lowering
- [M2 atomic array argument copies](docs/engineering/m2-array-arguments.md): exact-shape copy batches with no partial publication on failure
- [M2 private array calls](docs/engineering/m2-array-calls.md): mixed parameter metadata, immutable caller snapshots, independent frame copies and metered CALLs
- [M2 source array parameters](docs/engineering/m2-array-parameters.md): immutable exact-shape source parameters, left-to-right captures, forward/mutual calls and cleanup on early exits
- [M2 array result signatures](docs/engineering/m2-array-result-signatures.md): exact return-shape metadata and the historical source gate
- [M2 source array results](docs/engineering/m2-array-result-source.md): named returns, typed call initializers, capture cleanup and ownership transfer
- [M2 direct array-return calls](docs/engineering/m2-array-return-calls.md): exact-shape forwarding, nested early exits and shared return cleanup
- [M2 repeated array-return literals](docs/engineering/m2-array-return-literals.md): typed single-evaluation fills, exact lengths and shared ownership transfer
- [M2 array call-result assignment](docs/engineering/m2-array-call-assignment.md): ordered calls, temporary cleanup and copies into existing var storage
- [M2 repeated-literal assignment](docs/engineering/m2-array-literal-assignment.md): preflighted in-place fills without additional owners or array storage
- [M2 private array results](docs/engineering/m2-array-results.md): verified result lifetimes, zero-copy owner transfer, recursive frames and prepaid return work
- [M2 private struct layout](docs/engineering/m2-struct-layout.md): verified planner-only record catalog, declaration-order offsets, dependency bounds, and Windows receipt
- [M2 private struct storage](docs/engineering/m2-struct-storage.md): scalar-only record preparation, complete initialization, and indexed field access in shared caller-backed arena bytes
- [M2 private struct copy and assignment](docs/engineering/m2-struct-copy.md): scalar-record snapshots, padding normalization, old-plus-new quota, and overlap-safe assignment
- [M2 private nested struct storage](docs/engineering/m2-struct-nested-storage.md): iterative depth-first initialization, scalar field paths, selected-root quota, and shared arena staging
- [M2 private nested struct copy and assignment](docs/engineering/m2-struct-nested-copy.md): iterative snapshots, padding normalization, old-plus-new quota, and overlap-safe nested assignment
- [M2 shared struct owners](docs/engineering/m2-struct-owners.md): shared record/array descriptors, catalog-bound field access, generation-safe release, and mixed-arena reuse
- [M2 private struct-owner copy and assignment](docs/engineering/m2-struct-owner-copy.md): independent record owners, exact-ID assignment, shared descriptor pressure, and source-release survival
- [M2 private struct IR](docs/engineering/m2-struct-ir.md): entry-owned bindings, opcodes 41..46, flattened scalar leaves, combined lifetimes, and independent verification
- [M2 private function-owned record IR](docs/engineering/m2-struct-function-ir.md): static function ownership for record sites, opcodes 41..49, and development/release verification
- [M2 private frame-local record VM](docs/engineering/m2-struct-function-vm.md): 32 guest-frame token slots over shared owners and payload, unchanged opcodes and Fuel, development/release verification
- [M2 source helper-local records](docs/engineering/m2-struct-function-source.md): function-owned source declarations, recursive frame isolation, mixed cleanup, and `struct_helper_locals` capability
- [M2 record parameter signatures](docs/engineering/m2-struct-parameter-signatures.md): nominal signature metadata and the historical source gate before executable argument lowering
- [M2 private record parameter IR](docs/engineering/m2-struct-parameters-ir.md): zero-tag formal placeholders, exact nominal mixed-call verification, lifetime invariants, and the historical VM availability gate
- [M2 private record-call VM](docs/engineering/m2-struct-call-vm.md): prepaid mixed argument copying and frame publication; its source-gate claim is historical
- [M2 source record parameters](docs/engineering/m2-struct-parameters-source.md): immutable by-value formals, bare binding arguments, predeclared sites, mutable-source captures, reused record cleanup, limits, and verified two-phase Windows evidence
- [M2 record result signatures](docs/engineering/m2-struct-result-signatures.md): nominal ID metadata, zero scalar/array fields, the historical pre-IR compilation gate, bounds, and focused Windows evidence
- [M2 record-result IR/verifier](docs/engineering/m2-struct-results-ir.md): callee-owned shape anchors, `SRET`, record CALL destinations, exact lifetimes, the historical VM availability gate, and focused Windows evidence
- [M2 private record-result VM](docs/engineering/m2-struct-result-vm.md): prepaid `SRET` transfer into caller-owned destinations, complete snapshot validation, zero extra owners or payload, unchanged limits, and focused Windows evidence
- [M2 source record results](docs/engineering/m2-struct-result-source.md): bare exact-nominal returns, typed call initializers, result anchor reuse, pending-destination cleanup, mixed reverse drops, unchanged limits, and verified stepwise development/release evidence
- [M2 direct record constructor returns](docs/engineering/m2-struct-return-constructors.md): exact-nominal constructor operands, declaration-order staging, deferred site allocation, `SINIT`/`SRET`, constructor-only payload extent, rejected forms, and focused development/release evidence
- [M2 exact-nominal subrecord return paths](docs/engineering/m2-struct-return-paths.md): consecutive leaf reads, one independent result site, reverse mixed cleanup, unchanged limits, and verified development/release evidence
- [M2 child record call-result assignment](docs/engineering/m2-struct-child-call-assignment.md): shared root/child argument evaluation, `SSUBASSIGN` and `SDROP`, live destination ownership, deep paths, limits, and verified development/release evidence
- [M2 record calls in constructor child fields](docs/engineering/m2-struct-child-calls.md): exact-nominal child result sites, scalar-leaf staging, `SDROP` before later fields and parent publication, unchanged limits and Fuel, verified development/release evidence
- [M2 record call results as arguments](docs/engineering/m2-struct-result-arguments.md): nested exact-nominal result captures, left-to-right evaluation, shared cleanup, and focused Windows evidence.
- [M2 subrecord paths as arguments](docs/engineering/m2-struct-path-arguments.md): exact-nominal snapshots, left-to-right evaluation, shared cleanup, and focused Windows evidence.
- [M2 record constructors as arguments](docs/engineering/m2-struct-constructor-arguments.md): deferred owner publication, ordered field staging, mixed cleanup, and focused Windows evidence.
- [M2 array call results as arguments](docs/engineering/m2-array-result-arguments.md): exact-shape captures, mixed cleanup, nested calls, quota boundaries, and focused Windows evidence.
- [M2 private struct VM](docs/engineering/m2-struct-vm.md): shared owners and payload, private execution semantics, fixed Fuel charges, and current check status
- [M2 declaration-only source structs](docs/engineering/m2-struct-source.md): historical bounded parser, forward named fields, immutable layouts, name rules, and stepwise verification
- [M2 bounded source struct values](docs/engineering/m2-struct-values.md): historical entry construction and one-level reads, ordered typed staging, `SINIT`/scalar-leaf access, mixed cleanup, bounds, and recorded verification
- [M2 source struct field writes](docs/engineering/m2-struct-write.md): entry-only one-level `SWRITE`, target-before-RHS resolution, single typed evaluation, for-header rejection, profiles, and recorded verification
- [M2 source struct copy initialization and assignment](docs/engineering/m2-struct-source-copy.md): exact-name `SCOPY`/`SASSIGN` lowering, independent copies, mutable destination reuse, lifetimes, profiles, and stepwise development/release verification
- [M2 source nested structs](docs/engineering/m2-struct-source-nested.md): inline child constructors, depth-first scalar paths, whole-root copies, iterative traversal, limits, profiles, and historical development/release verification
- [M2 child binding initializers](docs/engineering/m2-struct-child.md): whole visible record bindings as child values, ordered leaf capture, independent snapshots, unchanged ownership and Fuel, profiles, and verification status
- [M2 constructor child paths](docs/engineering/m2-struct-child-path.md): exact nominal subrecord snapshots without intermediate owners
- [M2 metered root replacement](docs/engineering/m2-struct-replace-vm.md): independent verification, prepaid atomic replacement and existing ownership
- [M2 scalar-value record replacement](docs/engineering/m2-struct-replace-values.md): private staged overwrite without another owner or extent
- [M2 entry-only root constructor assignment](docs/engineering/m2-struct-replace-source.md): source-order staging, consecutive loads, one `SREPLACE`, existing ownership, and verified results retained for its original commit
- [M2 entry-only child constructor assignment](docs/engineering/m2-struct-subreplace-source.md): exact nominal child staging, one `SSUBREPLACE`, existing ownership, and development/release verification
- [Product specification](docs/product/02-spec.md): observable first-profile behavior
- [Roadmap](docs/product/01-roadmap.md): M0 through M5 delivery gates
- [Design baseline](docs/design-baseline.md): source provenance, evidence, and findings

The private [record-result IR/verifier](docs/engineering/m2-struct-results-ir.md)
passed 39 unique native groups and 2,317 CLI cases per development/release profile
for its original inputs.
The [core receipt](docs/evidence/m2-struct-results-ir-core-windows-20261028.json)
records 21 native groups and all CLI cases; the separate
[regression receipt](docs/evidence/m2-struct-results-ir-regressions-windows-20261028.json)
records 18 native-only groups. That slice's kind 11 runtime gate is historical.
The [record-result VM successor](docs/engineering/m2-struct-result-vm.md) implements
verified token transfer for its source-gated inputs. The
[source result successor](docs/engineering/m2-struct-result-source.md) now lowers a
bounded subset; development and release each passed 14 native groups and 2,438
CLI cases, followed by a focused checker metadata repair and 70-case-per-profile
CLI rerun.

The expanded M0 run exercises arithmetic, codecs, storage, allocator, owner, and
frame primitives on Windows x64. Exact commands and results belong to
`build/m0/receipt.json` and `docs/evidence/m0-windows-20261023.json`. Running with an
empty runtime `PATH` does not establish clean-machine packaging or a sandbox.

The function/local, branch, loop, tagged, propagation, switch-expression, and i64
receipts are historical for their narrower slices. The switch-expression receipt
records 41 native groups and 580 CLI cases; the i64 receipt records 49 native groups
and 760 CLI cases in each development and release profile. The
[unsigned receipt](docs/evidence/m1-unsigned-windows-20261023.json) remains
historical at 59 native groups and 1,159 CLI cases in both development and release,
including 399 unsigned cases. The
[widening receipt](docs/evidence/m1-widening-windows-20261023.json) records
67 native groups and 1,272 CLI cases in each profile, including 113 widening cases.
That receipt is historical after the integer-operator increment. The
[integer-operator receipt](docs/evidence/m1-integer-operators-windows-20261023.json)
records 75 native groups and 1,898 CLI cases in each profile, including 626 new cases.
That receipt is historical after arm statements. The
[arm-statement receipt](docs/evidence/m1-switch-arm-statements-windows-20261023.json)
records 81 native groups and 1,969 CLI cases in each profile, including 71 new cases.
The M2 IR and VM receipts are historical after the source compiler changes. The
[source-array receipt](docs/evidence/m2-array-source-windows-20261024.json) records
18 native groups and 67 CLI cases per profile. The subsequent full scalar regression
also passed 81 native groups and 1,969 CLI cases per profile in development and
release. That read receipt remains previous proof and is historical after the write
compiler changes. The [write receipt](docs/evidence/m2-array-write-windows-20261024.json)
records nine native groups, 67 read CLI cases, and 61 write CLI cases per profile
in development and release. The scalar CLI regression also passed all 1,969 cases per profile on those same binaries.
The read and write receipts remain historical after the copy compiler change. Copy
[evidence](docs/evidence/m2-array-copy-source-windows-20261025.json) records
12 native groups, 67 read CLI cases, 61 write CLI cases, and 58 copy CLI cases in
each development and release profile. Scalar CLI regression also passed all
1,969 cases per profile on the same binaries. The recorder can reuse matching
completed scalar CLI receipts after documentation-only changes instead of rerunning
the 1,969 tests. That integration also skips the 81-group scalar native rerun
because the VM and verifier are unchanged. The prior
[source-parameter receipt](docs/evidence/m2-array-parameters-windows-20261025.json)
records 28 focused native groups and 2,475 CLI cases per development/release
profile (426 existing array, 80 parameter, 1,969 scalar). Completed outputs were
combined stepwise; the aggregate harness was not rerun after the fixture correction.
Thirty unchanged backend source hashes match the private call receipt; this is
a comparison, not a rerun of their full native suites. The prior
[result-signature receipt](docs/evidence/m2-array-result-signatures-windows-20261025.json)
records 16 native groups and 2,242 CLI cases per profile (96 result-signature,
80 parameter, 97 helper-local, 1,969 scalar) on both Windows builds. This covers
metadata and honest rejection at that historical checkpoint.
Thirty-one unchanged backend hashes match the parameter receipt, which remains
historical for the changed frontend and fixture inputs. The current
[private result receipt](docs/evidence/m2-array-results-windows-20261025.json)
records 43 native groups and 2,571 CLI cases per development/release profile.
It covers zero-copy owner transfer, recursive frame limits, caller argument
independence, deferred-hole cleanup, and exact Fuel. The subsequent
[source result receipt](docs/evidence/m2-array-result-source-windows-20261025.json)
records 26 native groups and 2,690 CLI cases per profile, including 119 new
source-result cases. Development combines 18 unchanged groups from the first
selection with eight passing source-result groups after a corrected mutual-call
fixture; release selects all 26 together. Earlier receipts remain historical
for changed inputs. The focused [direct-return receipt](docs/evidence/m2-array-return-calls-windows-20261025.json)
records 12 native groups and 509 CLI cases per profile, including 117 new direct-return
cases. Other array/scalar CLI matrices and full native suites were not rerun for
that increment. The subsequent [literal-return receipt](docs/evidence/m2-array-return-literals-windows-20261025.json)
records 16 native groups and 628 CLI cases per profile, including 119 new literal
cases. It is focused evidence; the unchanged backend and omitted matrices are not
rerun. The subsequent [call-assignment receipt](docs/evidence/m2-array-call-assignment-windows-20261025.json)
records 15 native groups and 609 CLI cases per profile, including 115 new cases.
Its focused selection covers existing assignment and source-result behavior;
other array/scalar CLI matrices and full native suites were not rerun.
The [in-place fill receipt](docs/evidence/m2-array-literal-assignment-windows-20261025.json)
records 36 unique native groups and 2,693 CLI cases per profile, including 115
new fill cases. The CLI total is 724 array cases plus 1,969 scalar cases. The
final 36 combine 17 reused backend identities with 19 fresh frontend groups in
each profile; development reuses backend from `b5e0c98`, release reuses the same
identities from its earlier 36-group selection, and the aggregate harness was not
rerun. Reuse validation matched 28 unchanged source and test files to their
`b5e0c98` Git blobs and confirmed matching SDK and compiler identities.

The final lowering separates array statement, copy, and index handling into
helpers. Scalar and composed fills return 42 at depth 10; depth 11 is the
`compile_limit` boundary. Two permanent CLI cases cover the composed boundary.
The pre-fix binary reproduces `0xC00000FD` at depth 10. These checks make no
stack-byte or performance claim. No full-profile conformance,
DLL ABI, Windows isolation,
clean-machine packaging, or performance target is claimed.

The [private struct IR receipt](docs/evidence/m2-struct-ir-windows-20261026.json)
passes 46 groups per development/release profile, including 9 new struct groups
and 37 control-flow/array regressions. The focused
repeated-literal assignment CLI suite passed 115 cases in each development and
release profile, including the prior composed depth-10/11 boundary. Full CLI
matrices were not rerun.

The [struct VM native receipt](docs/evidence/m2-struct-vm-windows-20261026.json)
passes 38 groups in each development and release profile. The
[focused CLI receipt](docs/evidence/m2-struct-vm-cli-windows-20261026.json) passes
115 cases per profile. The earlier 46-group IR and 115-case CLI receipts remain
historical for changed runtime, test, harness, and root-lock inputs.

The CLI Fuel default is 256; an explicit `--fuel` accepts 0..16000000. Version
JSON reports `fuel_default`/`fuel_limit`. For an eight-writer CALL that exceeds
the former one-million ceiling, run `examples/fuel-wide-call.brc` with
`--fuel 16000000`. See [public Fuel costs and limits](docs/engineering/public-fuel-limits.md).

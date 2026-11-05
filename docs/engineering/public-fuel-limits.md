# Public Fuel costs and CLI ceiling

Date: 2026-11-04. This is a narrow C05 successor to the
[returned-view schedule](m2-slice-result-fuel.md), not full-profile limit adoption.

## Deliberate limit change

The trusted local CLI accepts `--fuel 0..16000000`; its default remains 256.
`src/fuel.fy` supplies both argument validation and the additive `fuel_default`
and `fuel_limit` numbers in `--version --json`. Existing profile strings and
feature flags keep their meanings. Native VM APIs still accept a host-selected
`usize` budget independently of CLI policy.

The previous 1000000 ceiling could not fund a legal eight-writer CALL: its
retention/restoration reserve alone is `65537 * (1 + 2*8) = 1114129`, before
nine units for dispatch/formal transfer, root OPENs or backing preparation.
Existing record-loop stress cases also needed larger native budgets. The new
16000000 ceiling uses the established stress-test budget; selecting it is explicit.
It does not enlarge backing, frame, owner, source or operand capacities, change
any operation price, grant a capability or imply that arbitrary loops terminate.
Fuel exhaustion remains a runtime error. Policy/Engine/step/deadline limits from
the accepted full profile remain separate work.

## One slice price source

All rooted/formal, shared/exclusive, canonical and legacy slice adapters now use
`fuel::slice_base`, `utf8_scan` and `slice_call`, including formal CLOSE and
BEGIN/END. Every caller authenticates bounded metadata first; runtime tickets,
payload access and publication still follow the Fuel preflight. Call pricing
requires at most eight readers plus writers, element stride is at most eight,
and validated root length is at most 4096, so these additions/multiplications are
bounded without host-sized arithmetic overflow.

| Existing public work | Exact charge |
| --- | ---: |
| OPEN/SUB/BEGIN/END | 65537 |
| CLOSE/length | 4097 |
| Scalar read | 4130 + stride |
| Scalar write | 4130 + 2*stride |
| UTF-8 | 4097 + 4*root length |
| CALL retention/restoration | 0 without borrows; otherwise 65537*(1+readers+2*writers) |

Public instruction charges already include their dispatch unit; CALL adds its
existing `1 + arity + aggregate-copy cost` once. Return restoration and emergency
cleanup remain prepaid. The private returned-result coordinator keeps its
explicit per-dispatch unit and entry/handoff/leave reserves as documented in the
prior schedule. The [public Program successor](public-program.md) now connects
that coordinator to public literal/shared-byte source admission with its distinct
result profile. Whole-invocation costs differ from the legacy path; no retry or
fallback chooses another schedule. Array/record pricing is unchanged.

## Element-list declarations

The 2026-11-06 [source successor](array-list-source.md) makes the previously
native list operation reachable through inferred/annotated local declarations.
Programs without lists still pay zero list setup; all pre-existing prices remain.

| List work | Exact charge |
| --- | ---: |
| Invocation scratch, with maximum M cells and S encoded bytes | `257 + 2*M + S` |
| One N-cell list with B encoded bytes | `56 + N + 3*B` |

The ordinary list instruction price includes dispatch; the retained coordinator
keeps its separate one-unit dispatch, as for existing aggregate instructions.
The public default and ceiling remain 256 and 16000000. A standalone CLI oracle
for `let a=[20,22];return a[0]+a[1];` requires 66017 Fuel with public backing:
66016 fails, and 66017/66018 succeed. See the source successor's focused native
and CLI evidence; it does not replace the historical full public-Fuel selection
below or close Instance/step/accounting work.

The [contextual list successor](array-list-contexts.md) adds direct by-value CALL,
returned-list and temporary-borrow source routes without changing this schedule.
An ordinary `take([20,22])` summing callee requires 66340 public Fuel; a direct
`return [20,22]` with a summing caller requires 66083. Both fixtures check exact,
one-short and one-more budgets. Their native eight/sixteen-byte backing oracles
also prove the existing result-token move and argument copy behavior. Retained
invocations continue to use their distinct additive coordinator prices.

The [native list replacement prerequisite](array-list-replace-execution.md)
adds opcode 81 at `49 + N + 3*B`, retaining the existing owner/extent and removing
creation's seven-unit padding reserve. Replacement-only programs also prepare
and pay the same once-per-invocation maximum scratch; the retained coordinator
adds its usual dispatch unit. Existing prices/default/ceiling are unchanged.
Exact native ordinary/retained and one-short/one-more boundaries are covered by
that focused selection. The [source assignment successor](array-list-assignment.md)
now adds whole-array `a=[x,y];` and its public capability with the same schedule.
For `var a=[0;2];a=[20,22];return a[0]+a[1];`, public backing requires 66083:
66082 fails and 66083/66084 succeed. Native backing-eight and retained coordinator
oracles require 555 and 410152 respectively; they retain their distinct schedules.

The [scalar literal projection successor](array-literal-projections.md) adds no
price or limit changes. `return [20,42][1];` requires 450 native Fuel with eight
backing bytes, 65978 with public backing, or 410045 in the retained coordinator.
`return [42;2][1];` requires 170 native or 65698 public Fuel. Exact/one-short/
one-more checks preserve each distinct schedule and original temporary cleanup.

## Verification

`python -B tools/verify-public-fuel.py --profile development` runs focused native
checks, builds the standalone CLI and executes it with a tool-free PATH. Repeat
with `--profile release`. Native phases can run independently with `--phase
native`; serialize CLI phases (`--phase cli`) because builds share the output
artifact. Each phase fingerprints inputs, compiler and test discovery, checks the
lock and rejects compiler/stack overrides and changed inputs.

New native cases use an independent numeric oracle for straight-line source:
exact budget succeeds, one-short fails and one-more succeeds, for shared roots,
exclusive roots and all eight writer arguments. The eight-writer example also
uses the standard public 65536-byte backing. Scalar two-unit execution, native
host budgets above the CLI cap and proof-before-Fuel/backing are covered.
Affected canonical/legacy six-scalar, UTF-8, returned-binding and cleanup suites
are included. CLI cases exercise default/zero/one/exact scalar budgets, old and
new ceilings, invalid/overflowing/duplicate arguments, version discovery and four
record stress sources at both 1000000 and 16000000. The old budgets still produce
Fuel errors; explicit larger budgets complete with 42.

At the original 2026-11-04 checkpoint, Windows development and release each
passed 25 native groups and 33 standalone
CLI cases on 129 matching inputs and the 211-file test-discovery identity. All
117 production files are LF; an LF mirror passed `check --locked`. Final runs
used no compiler/stack overrides or historical-result reuse.

See [focused Windows evidence](../evidence/public-fuel-windows-20261104.json).

The 2026-11-05 [Static alias successor](static-alias.md) reran this runner's
CLI-only phase on both current profiles: all 33 tool-free cases passed, with
136 matching CLI input hashes and unchanged reported limits. Its separate
32-group private image/proof/VM selection verifies ALIAS costs exactly 17
including dispatch, rejects a seventeenth Static definition, and publishes no
alias on Fuel shortage. These private checks do not rerun the original public
native selection or promote guest alias syntax. The
[successor evidence](../evidence/static-alias-windows-20261105.json) records both
current CLI artifacts and the focused private native results.

The 2026-11-05 [Static CALL analysis successor](static-call-admission.md) reran
the CLI-only phase after canonical verifier integration. Development and release
each passed all 33 tool-free cases on 140 matching CLI input hashes and the
229-file discovery identity, with the same 256 default and 16000000 ceiling.
Its [focused evidence](../evidence/static-call-admission-windows-20261105.json)
records both artifacts and the separate 38-group private native selection.
The original public Fuel native selection was not rerun by this successor.

The subsequent [canonical Static CALL transfer](static-call-transfer.md) reran
both CLI-only profiles after connecting actual frame/image words. All 33 cases
passed per profile on 141 matching CLI inputs and a 230-file discovery identity.
Its separate 24-group native selection covers private transfer/exact budgets and
affected scalar-entry/range regressions. Existing public prices and reported
limits are unchanged; new private CALL/RETURN prices do not promote source syntax.
See [the focused evidence](../evidence/static-call-vm-windows-20261105.json).

The [shared byte-access successor](reference-access.md) reran the CLI-only
phases on both final profiles: 33 cases per profile on 142 matching CLI inputs
and a 232-file discovery identity. Existing public prices/default/cap remain;
the private coordinator still pays its separate dispatch unit. Its independent
numeric byte READ/LEN/WRITE/CLOSE boundaries and other affected routes passed
18 focused native groups per profile on 139 matching native inputs. The
[focused evidence](../evidence/reference-access-windows-20261105.json) records
the final artifacts and source identities; the original public native selection
was not rerun.

The [shared byte-formal analysis](reference-formals.md) subsequently reran both
CLI-only profiles after canonical argument-proof integration. All 33 cases per
profile passed on 142 matching CLI inputs and a 233-file discovery identity;
prices and reported limits remain. Its separate 18-group native selection is
analysis plus existing Static execution regression evidence, not execution of
the new shared-byte formal kind. See
[the focused evidence](../evidence/reference-formals-windows-20261105.json).

The [shared byte-formal VM successor](reference-vm.md) reran both serialized
CLI-only profiles: 33 cases each on 144 matching CLI inputs and the 236-file
discovery identity. Default 256, cap 16000000 and existing public prices remain.
Its separate 18-group native selection checks private mixed-backing CALL/PARAM,
independent exact reference budgets and affected canonical regressions on 141
matching inputs. The [focused evidence](../evidence/reference-vm-windows-20261105.json)
records those final artifacts; the original public Fuel native selection was
not rerun. The new private reference charges do not enable public source syntax.

The [generic byte-result VM successor](reference-return-vm.md) reran the original
public native selection as well as both serialized CLI phases. Windows development
and release each passed 25 public Fuel native groups and 33 tool-free CLI cases
on 147 matching public input paths and a 240-file discovery identity. The separate
18-group returned-byte/receipt/formal VM selection passes per profile on 142
matching paths. Existing public prices, default 256 and cap 16000000 remain;
private returned-selector lookup costs 64 and generic RETURN metadata costs 512,
excluding dispatch and existing access/native phase charges. The complete RETURN
price is checked before native receipt authentication. See
[focused evidence](../evidence/reference-return-vm-windows-20261105.json) for all
151 distinct committed inputs, native reports and final CLI artifacts.

The [shared byte source CALL successor](reference-call-source.md) reran both
serialized CLI-only phases on its final source state. All 33 cases passed per
Windows profile on 148 matching CLI inputs and a 241-file discovery identity,
with unchanged public prices/default/cap. Its separate 18-group native selection
covers source CALL execution, legacy Static bindings and mixed native CALLs on
143 matching paths. The original public Fuel native selection was not rerun.
See [focused evidence](../evidence/reference-call-source-windows-20261105.json).

The [returned-byte source successor](reference-return-source.md) reran both
serialized CLI-only phases: 33 cases per Windows profile on 149 matching input
paths and a 242-file discovery identity, with unchanged prices/default/cap.
Its separate 18-group native selection covers new source returns/temporary owner
lifetimes, existing result VM numeric oracles and source CALL regressions on 144
matching paths. The original public Fuel native selection was not rerun. See
[focused evidence](../evidence/reference-return-source-windows-20261105.json).

The [public retained successor](public-program.md) additionally checks the literal
source oracle 344103 at exact/one-short/one-more budgets through both standalone
CLI artifacts. Its separate reference result profile preserves the canonical
147456 entry and 196608 leave reserves. Both source routes keep the existing
32-deep expression limit; the added 33/64-depth rejection regressions exercise
check and run without native stack overrides. Version Fuel discovery is unchanged.

After the native project-source binding increment, the original public Fuel
selection was rerun on source baseline `6d7ab75`. Windows development and release
each passed all 25 native groups and 33 tool-free CLI cases on the same 160
matching input hashes, 148 production modules and the 253-file test-discovery
identity. Native and CLI phases ran afresh in both profiles with `check --locked`,
without compiler/stack overrides or historical-result reuse. The default remains
256 and the ceiling 16000000; operation prices and host-selected native budgets
are unchanged. Development started at `6d7ab75`; release started at the
documentation-only successor `757e837`. The evidence rechecks all inputs and
records each starting head, compiler, report and CLI artifact hash. See the
[current-source evidence](../evidence/public-fuel-windows-20261105.json).
This rerun does not repeat the retained-source numeric oracle suite or an LF
mirror check.

After scalar, aggregate, reference and Option inference, the original public
Fuel selection was rerun on source baseline `624eac6` on 2026-11-06. Windows
development and release each passed all 25 native groups and 33 tool-free CLI
cases on the same 166 matching input hashes, 154 LF production modules and the
260-file test-discovery identity.
The inputs also match Git raw bytes. The locked native and CLI phases ran afresh
without compiler/stack overrides or historical-result reuse. Default 256, ceiling
16000000, operation prices and independent native host budgets are unchanged.
Development started at `624eac6`; release started at its documentation-only
successor `7c8f0f4`. The archive records each starting head, report, receipt and
CLI artifact hash. See the
[inference-source evidence](../evidence/public-fuel-windows-20261106.json).
This rerun does not repeat the retained-source numeric oracle suite or an LF
mirror check, and does not implement other C05 or Engine/Instance budgets.

Full M1/M2, Linux, restricted delivery, ABI, packaging and elapsed-time/allocator/
stack-size benchmarks are outside this increment. The [public Program successor](public-program.md)
now admits the shared-byte result subset; general mutable/non-byte/Buffer/input
results, other C05 capacities and the complete objective remain open.

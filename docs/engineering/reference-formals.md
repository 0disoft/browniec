# Shared byte formal analysis across backing kinds

Date: 2026-11-05. This B04/B05 increment follows the instruction-local
[byte access interface](reference-access.md). It implements independent IR
analysis. The [native VM successor](reference-vm.md) now connects canonical
CALL/PARAM transfer; source lowering and generic results remain subsequent steps.

## Signature and proof

The existing private CALL unit reserves parameter kind 3 for a shared byte
reference whose backing may be an immutable image or a runtime loan. PARAM 77
uses kind 3 at the exact logical formal register. That register remains a
type-zero non-slot placeholder and cannot become a scalar value/destination or
an ordinary array, record or slice formal. Program and proof layouts are unchanged.

At CALL 78, that position accepts a live image byte site or universal byte site
encoded as 192..207, or a runtime shared byte slice encoded as 160..175. Ordinary
scalar/aggregate/loan positions retain their canonical signature checks. Image
text cannot coerce to bytes; scalar cells and owned-value encodings cannot create
a reference. Mutable actuals require an explicitly shared view; exact access
modes are preserved.

`static_call_ir::inspect_references` independently reconstructs definitions,
formal positions, CFG liveness and logical origins. ALIAS and RANGE preserve
kind 3; READ and LEN produce fresh exact u8/usize registers. Forwarding to another
kind-3 formal preserves byte kind and logical input position. Image-only formals
cannot silently receive a value with unknown backing. Equality and kind-3
results are deliberately rejected until their runtime/lifetime paths exist.

`verifier::inspect_reference_calls` then combines those recipes with complete
canonical scalar, aggregate, ordinary loan and CFG analysis. Runtime actuals must
be live shared u8 views in the caller and keep their live owner or exact rootless
formal ancestry. Recipe-only analysis intentionally does not certify those
properties; the new tests distinguish recipe acceptance from canonical rejection
of a closed, wrong-element or exclusive runtime actual.

Possible image roots propagate through formals, aliases, ranges and forwarding;
runtime actuals contribute no image root. An empty image-root set can therefore
describe a runtime-only formal. It is not an empty runtime view or evidence of
runtime ownership. The existing sixteen-round/sixteen-site bound and exact image
windows remain. No descriptor table, payload allocation/copy or runtime price is
added by this analysis.

## Execution boundary

The result has the distinct `ReferenceCallProof` type. It is copyable analysis,
without retained image, frame, ticket or executable Program authority. Existing
`verify_static_calls`, `retain_calls`, bare/public admission and executable
entry points retain their prior signature gates. They reject the new kind.
At this analysis checkpoint there was no new source syntax, VM result support,
public capability or ABI export. The successor adds a separate private retained
ReferenceProgram/scalar-entry API; generic results and public gates remain closed.

Generic references are currently formal-only and cannot escape via a returned
reference. Callees may return existing ordinary values or independently proved
image-only results. This avoids treating a runtime-backed result as an immutable
image or allowing a caller-owned root to die behind a retained generic result.

## Verification

Run `python -B tools/verify-static-execution.py --profile development --selection
reference-proof`, then repeat for release. Eight new groups cover mixed backing,
aliases/ranges, all eight shared positions, scalar prefixes, transitive forwarding,
rootless ordinary inputs, canonical lifetime/type/access failures, forbidden
encodings, scalar/result confusion and legacy admission gates. Eight existing
Static admission groups and two actual canonical Static CALL execution groups
cover the changed shared verifier/recipe paths. Public Fuel CLI-only phases run
separately and serialize their builds.

The main fixtures construct actual bounded IR. The rootless-input fixture patches
an unused scalar marker in real compiler output with a private kind-3 formal;
it does not claim source signature support. No new kind-3 CALL is executed here.

Windows development and release each passed all 18 selected native groups and
33 tool-free public Fuel CLI cases. Native inputs match across 137 paths and
CLI inputs across 142 paths: 146 distinct committed inputs in total. The common
test-discovery identity covers 233 files. All 130 production modules are LF;
both locked LF mirrors pass. Implementation commit: `68826d4`.
See [focused Windows evidence](../evidence/reference-formals-windows-20261105.json).
Final runs use no compiler/stack overrides or historical-result reuse; earlier
core probes and the corrected fixture borrow-checker rejection are excluded.
The original public Fuel native selection, full profiles, general native
stack/RAM, allocator/OOM/timing, Linux, restricted delivery and ABI/package
checks were not rerun. Public default 256, cap 16000000 and prices remain.

## Native execution successor and next integration

The [native VM successor](reference-vm.md) now retains a distinct ReferenceProgram
and connects CALL/PARAM through the existing ownership transaction. Compact words
select exact issued-formal receipts and windows; aliases/ranges share that input
without extra leases. Complete Fuel precedes entry/publication and failures use
prepaid zero-Fuel abort. Development/release each passed 18 focused native groups
and 33 public Fuel CLI cases on final inputs. The analysis results above remain
historical for their own commit; the successor records current execution scope.

The [returned-reference recipe successor](reference-return-ir.md) now reconstructs
shared-byte result signatures and actual grounded image/input/local origins.
Complete canonical lifetime proof and native result transfer remain open.
Next implement returned generic references with origin-selected retention,
caller destination publication, close and image lifetime handling, followed by
source signatures/actuals/returns and ordinary public admission. Text/non-byte
references, Buffer/input backing and the full [inventory](../product/04-remaining-work.md)
remain separate completion obligations. The complete objective stays open.

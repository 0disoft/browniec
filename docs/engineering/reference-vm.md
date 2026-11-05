# Shared byte formals through canonical VM frames

Date: 2026-11-05. This B04/B05 increment connects the independently proved
[shared byte signature](reference-formals.md) to the existing native coordinator.
The same private kind-3 formal now executes image or shared runtime u8[] actuals.
Generic returned references and source/public admission remain subsequent work.

## Admission and actual authority

`program_image::retain_references` produces a distinct `ReferenceProgram` owning
the exact proved code/image snapshot and applying the existing image quota.
`run_reference_scalar` repeats complete reference-aware canonical proof before
entry. Changing the original copyable IR cannot rewrite retained code. Existing
Program/CallProgram, bare/static admission and external kind-3 entry retain their
previous gates; this API is not an embedding ABI or public capability.

Internal CALL 78 captures each runtime actual exactly once into the canonical
native entry transaction, alongside ordinary loan and aggregate arguments.
PARAM 77 authenticates the exact logical formal position and issued native
receipt. Mixed image, runtime and scalar positions keep their original indices,
including scalar prefixes and all eight actuals. Shared-byte formals reject
exclusive actuals; an ordinary exclusive formal can still coexist independently.

## Compact words and checked windows

Image words retain their existing 13-bit start/length representation. Runtime
words reuse the high bit plus three formal-position bits and the same checked
relative span. Reserved bits reject. The physical full-generation ticket stays
in the existing native frame receipt; a word is never authority by itself.
The existing 32 x 16 u32 table remains 2048 logical bytes, with no second dense
ticket table or additional alias/range pool reservation. This is a table-size
invariant, not a measurement of total process RAM or native stack consumption.

A runtime word names a window relative to the captured ticket, rather than the
entire owner or the proof's possible-root union. Forwarding repacks the selected
window for the child's exact formal position. ALIAS/RANGE preserve backing and
cannot broaden their source; logical CLOSE removes the view without prematurely
closing the transaction-owned input. Native leave/abort owns physical cleanup.
READ/LEN revalidate the full ticket, root/lease, byte kind and selected window.
An empty relative span, including packed zero, remains valid for length; reads
outside it fail. A copied word/receipt cannot revive a ticket after native leave.

`reference_words` and checked loan-window access landed at `87cfba1`; the
canonical execution connection is `d9f1929`. No payload copy is introduced by
an image view or by logical alias/range. Existing owned-value CALL copies remain.

## Fuel and failure ordering

Let N count Static/universal reference actuals and R count runtime-backed
kind-3 actuals. Bounded metadata limits keep both at most eight.

| Private operation | Additional charge, excluding normal dispatch |
| --- | ---: |
| CALL metadata and runtime authentication | 32 + 32*N + 4097*R |
| PARAM, image-backed | 16 |
| PARAM, runtime-backed | 16 + 4097 |
| READ, image/runtime | 17 / 4131 |
| LEN, image/runtime | 16 / 4097 |

CALL also prepays native entry, logical arity and existing aggregate-copy work
before runtime actual authentication, child entry or caller publication. The
usual one-unit private dispatch remains. ALIAS/CLOSE still cost 17 and RANGE
128 including dispatch. Native ordinary leave and prepaid zero-Fuel abort remain
shared with the existing coordinator. Bounds failures keep their first error;
failed calls drain their owned roots, captures and frame authority. Abstract
Fuel units are not elapsed-time or machine-instruction measurements.

Public operation prices, default 256 and explicit ceiling 16000000 remain.
Private invocation phase reserves differ from ordinary public execution; these
checks do not claim equal whole-invocation prices between the two paths.

## Verification

Run `python -B tools/verify-static-execution.py --profile development --selection
reference-vm` and repeat for release. Seven new execution groups and four word/
window groups cover the same formal reading distinct image/runtime values,
alias/range parent close, forwarding, empty ranges, all eight actuals, scalar
prefixes, wrong receipt positions, stale tickets, retained immutability and
Fuel/bounds failure cleanup. Straight-line examples use independent numeric
oracles with one-short/exact/one-more budgets; image-only examples use zero guest
backing. Three mixed-CALL groups also cover ordinary record values, shared and
exclusive loans, and array/record results, using measured Fuel boundaries.
Two existing Static VM and two scalar-entry groups cover affected regressions.

Windows development and release each passed all 18 selected native groups and
33 tool-free public Fuel CLI cases. The CLI builds were serialized. Native
inputs match across 141 paths, CLI inputs across 144 paths: 150 distinct committed
inputs. Discovery covers 236 files. All 132 production modules are LF and both
locked LF mirrors pass. See [focused evidence](../evidence/reference-vm-windows-20261105.json).
No compiler/stack overrides or historical-result reuse; earlier probes and the
corrected fixture borrow-checker rejection are excluded from final counts.
The original public Fuel native selection, full profiles, general stack/RAM,
allocator/OOM/timing, Linux, restricted delivery and ABI/package were not rerun.

## Remaining work

The [returned-reference recipe successor](reference-return-ir.md) now reconstructs
shared byte results and exact image/input/local origins through actual IR. Next
use the [complete canonical lifetime proof](reference-return-lifetimes.md),
then connect native origin-selected retention, caller publication and image/owner
lifetime handling. Then lower source
signatures, actuals and returns and complete ordinary public admission. Equality
for kind 3, text/non-byte references and Buffer/input backing remain open.
The [complete inventory](../product/04-remaining-work.md) and
[completion plan](completion-plan.md) remain active.

# Byte reference access across backing kinds

Date: 2026-11-05. This is a private B04/B05 execution prerequisite following
[canonical Static CALL transfer](static-call-transfer.md).

## Access contract

`reference_access::Source` selects either an immutable image site or a runtime
`u8[]` loan ticket for one instruction. Both use the same `read` and `length`
interface. Inactive fields have canonical sentinel values; an unknown tag or
mixed selector rejects rather than falling back to another backing kind.

The selector owns no bytes, lease, frame or image lifetime. Its caller retains
the independently proved frame, exact immutable image borrow and native runtime
state. Image access authenticates the current site's function, byte kind,
liveness and actual frame span. Runtime access requires the byte element tag
before reusing existing full ticket-generation, pool, root and lease validation.
Other scalar slice types continue through the existing loan adapter.

Canonical dispatch routes Static READ/LEN 71/72 and runtime byte READ/LEN 58/57
through this interface, publishing the destination and remaining Fuel only after
success. The compatibility Static executor shares the checked byte bounds/codec;
its existing admission and metering remain in place. No payload is copied or
allocated by the selector, and neither access mutates ownership metadata.

## Fuel and errors

| Backing | Read access charge | Length access charge |
| --- | ---: | ---: |
| Immutable image | 17 | 16 |
| Runtime byte loan | 4131 | 4097 |

These are the existing access charges. The private canonical coordinator adds
its existing dispatch unit exactly once. They do not change the public schedule,
CLI default 256 or explicit cap 16000000, and do not imply identical whole-call
prices between private and public execution paths.

Canonical selector and bounded image-span authentication can reject invalid
metadata before payment. Once that metadata is admitted, complete access Fuel
precedes index/bounds checks and payload reads. Runtime ticket authentication
follows this preflight: a stale ticket with 4130 remaining reports Fuel 8; with
4131 it reports invalid IR 5. Invalid guest indices report Bounds 14 after full
payment. Empty spans remain valid for length and fail any read with Bounds.
After successful entry, the canonical invocation's existing prepaid abort drains
loans and owners on failure, preserving the first error and any earlier writes.

## Verification

Run `python -B tools/verify-static-execution.py --profile development --selection
reference-access`, then repeat for release. The selection includes five new
access/dispatch groups, four Static execution groups, four Static transfer
groups, two mixed CALL groups and three canonical scalar-entry groups. Exact
identities select the affected routes without rerunning unrelated equality/proof
cases from those files.
Run serialized public Fuel CLI phases with `tools/verify-public-fuel.py --profile
development --phase cli` and the corresponding release command.

New tests cover both backing kinds, negative indices, empty shared/exclusive
ranges, stale tickets, mixed/unknown selector tags and non-byte type rejection.
Actual canonical byte dispatch has independent numeric enter/leave, arity,
dispatch, READ, LEN, WRITE and CLOSE prices, exact/one-short budgets and
Fuel-before-bounds checks. Both successful and failed invocations drain state.
Existing scalar-entry cases retain non-byte dispatch coverage; Static and mixed
CALL cases exercise the changed canonical image/runtime routes.

Windows development and release each passed all 18 focused native groups and
33 tool-free public Fuel CLI cases on final inputs. The native phases match on
139 inputs, CLI phases on 142 inputs, with 148 distinct committed inputs and a
232-file test-discovery identity. All 130 production modules are LF and both
locked LF mirrors pass. Implementation commit: `648d4bd`.
See [focused Windows evidence](../evidence/reference-access-windows-20261105.json).

Final runs use no compiler/stack overrides or historical-result reuse. Earlier
helper probes, the rejected narrowing fixture and its superseded broad run are
excluded. The original public Fuel native selection, full profiles, general
stack/RAM/allocator/OOM/timing, Linux, restricted delivery and ABI/package checks
were not rerun. These focused results do not certify the complete profile.

## Remaining integration

This increment unifies instruction access only. The subsequent
[shared byte-formal analysis](reference-formals.md) now proves mixed image/runtime
actuals through one private IR signature, including canonical loan validation.
Its VM transfer and source lowering remain open; a single guest source formal
cannot yet select either backing kind. Storage-independent guest reference signatures/actuals/
returns, text and non-byte references, source CALL lowering, ordinary public
Program admission and host-visible returned-image lifetime APIs remain open.
Buffer/input views and the complete [inventory](../product/04-remaining-work.md)
retain their separate completion conditions.

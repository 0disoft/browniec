# Returned byte references through canonical VM frames

Date: 2026-11-05. This B04/B05 increment connects the complete
[returned-reference proof](reference-return-lifetimes.md) and
[sparse native receipts](reference-receipts.md) to private CALL/RETURN execution.

## Retained admission and transfer

`program_image::ReferenceReturnProgram` owns the exact proved code and immutable
image. Retention checks complete canonical proof and the image quota; execution
repeats proof before entry. The external entry and completion remain scalar.
Ordinary Program admission and generic-result source syntax remain gated.

CALL 78 selects the declared logical input only when its actual is runtime-backed.
RETURN 79 validates the exact child, sole live source, recipient CALL and absent
caller destination before transfer. Image results leave normally and publish the
existing image word. Runtime results use canonical native handoff, retain its full
Held ticket in the existing sparse table and publish a returned-selector word.
Publication follows native success. The consumed child frame is retired only
after handoff; an execution failure uses the existing prepaid zero-Fuel abort.

Aliases, narrowed ranges, forwarding and subsequent CALL actuals preserve the
selected relative window. Closing the original loan does not invalidate a live
returned alias. Last-alias CLOSE consumes the native receipt and any retained
owner obligation. No image payload copy, extra dense ticket map, frame field or
pool lease is introduced by a logical alias or range. The existing 32 x 16 u32
word table remains 2048 logical bytes; this is not a total RAM/stack measurement.

## Complete Fuel preflight

All numbers below exclude the coordinator's existing one-unit dispatch.

| Private operation | Charge |
| --- | ---: |
| Returned-selector lookup for READ/LEN, ALIAS/RANGE or each CALL actual | 64 |
| Generic reference RETURN metadata and publication | 512 |
| Image result native leave | 196608 |
| Runtime result native handoff, including later cleanup reserve | 294912 |
| Returned-selector CLOSE metadata | 128 |

Lookup covers the bounded 47-entry sparse search. RETURN covers bounded selector,
destination, frame and receipt publication work. Both complete RETURN terms are
checked before receipt authentication or native mutation. Lookup is additive to
the existing image/runtime access or CALL price; CLOSE's 128 already includes
its searches and alias scan. Native entry, arity and owned-value copies remain
separate existing charges. Physical finalization/abort remains prepaid.

Public prices and limits remain unchanged: default 256, CLI range 0..16000000.
Native hosts may choose a separate usize budget. Private phase reserves do not
establish equal whole-invocation costs with the ordinary public execution path.

## Verification

Run `python -B tools/verify-static-execution.py --profile development --selection
reference-return-execution` and repeat for release. The selection includes eight
new execution groups, eight receipt groups and two existing shared-byte formal
VM groups. New successful examples use an independent numeric schedule and
one-short/exact/one-more budgets. They cover distinct image/runtime values,
narrowing, empty windows, scalar prefixes, eight actuals, forwarding, last-alias
lifetime, zero guest backing for image-only results, retained immutability and
Fuel/bounds failure cleanup. A direct invalid-receipt case proves complete RETURN
Fuel takes precedence over native formal authentication.

Windows development and release each passed all 18 selected native groups,
25 public Fuel native groups and 33 standalone tool-free CLI cases. CLI builds
were serialized. Native inputs match across 142 paths and public inputs across
147 paths: 151 distinct committed inputs, 135 LF production modules and 240-file
test discovery. Both locked LF mirrors pass. No compiler/stack overrides or
historical-result reuse; earlier direct probes and the corrected scratch-quota
fixture are excluded. Final identities and outcomes are recorded in
[focused Windows evidence](../evidence/reference-return-vm-windows-20261105.json).

## Remaining work

Lower source signatures, actuals and returns, then connect ordinary public
Program/CLI admission with end-to-end proof. Kind-3 equality, returned text and
non-byte references, Buffer/input backing and host-visible reference lifetimes
remain open. Engine/Instance lifecycle, cancellation, restricted delivery and
ABI/package work remain in the [complete inventory](../product/04-remaining-work.md).
Full profiles, general RAM/stack, allocator/OOM/timing, Linux and delivery checks
are outside this increment.

# Checked frame-local Static ranges

Date: 2026-11-05. This prepares dynamic image-backed byte ranges after
[source equality](static-equality-source.md). The new `static_views` module is
bounded metadata preparation at this checkpoint. The
[execution successor](static-range-execution.md) now adds independently proved
RANGE 76 and actual frame spans. Source range syntax and public promotion remain
open; the preparation itself introduced neither.

## Compact range metadata

A range contains an absolute start and length within the retained image's
4096-byte maximum. Each coordinate needs thirteen bits. A `u32` packs the two
fields in 26 bits; high/reserved bits reject. Sixteen descriptors per frame and
32 frames require exactly 2048 descriptor bytes. Existing liveness words remain
separate. This is fixed table geometry, not complete Engine/Instance/process
accounting or evidence of peak native stack/RAM usage.

The pinned SDK has no usize-to-u32 narrowing helper. After complete bounds
preflight, each pack performs at most 26 conversion iterations. Decoding does
not repack the actual word; inspection separately validates the admitted maximum
window through the bounded packer. Bounds are
checked before multiplication/addition/subtraction, including host-sized forged
values. Empty end ranges at absolute offset 4096 are representable.

## Proof, kinds and liveness

`inspect` checks a packed range against an independently admitted site's maximum
image window, exact function and kind. `live` also requires exactly sixteen frame
words, a legal site and a live bit in a sixteen-bit mask. A valid packed integer
alone cannot establish a live view, pin an image, authenticate a Program, validate
UTF-8 or select another frame's authority.

Byte ranges may narrow within the proven window, including empty ranges at its
end, and may never broaden it. Text words must match the exact already-validated
text window. A raw byte subrange cannot request a text kind. Metadata preparation
does not rescan image text; owning Program/image validation remains mandatory at
the actual invocation boundary.

`crop` validates the native parent coordinates before guest-relative endpoints.
It accepts `0 <= lo <= hi <= actual parent length` and returns a new packed word,
without publishing a destination or mutating its parent. Invalid metadata uses
IR error 5; valid-parent endpoint violations use Bounds 14, preserving offsets.
The future VM operation must prepay its complete price before endpoint checking
and publication, preserving Fuel as first cause when both would fail.

## Verification and integration next

Run `python -B tools/verify-static-execution.py --profile development --selection
views`, then repeat with `--profile release`. Seven focused groups cover round
trips at payload edges, reserved bits, host-sized overflow attempts, exact proof
windows/functions/kinds, text boundaries, separate frame slices/liveness, empty
and invalid relative crops, and proof obtained from an actual retained source
Program. The other selection modes retain their prior scope; `all` adds these
new cases.

Windows development and release each passed all seven focused native groups on
131 matching inputs and the same 225-file test-discovery identity. All 126
production modules are LF and both locked LF mirrors passed. No compiler/stack
override or historical-result reuse was used. The early check against an absent
SDK narrowing helper was corrected before final input capture and is excluded.
See [focused Windows evidence](../evidence/static-view-ranges-windows-20261105.json).
No CLI/full-profile, general native stack/RAM/allocator/timing, Linux, restricted
delivery or C ABI/package verification was run for this preparation.

The [execution successor](static-range-execution.md) now adds independently
proved RANGE 76 and routes OPEN/BYTES/ALIAS/READ/LEN/EQUAL through actual frame
spans, including recursive CALLs and aliases after parent close. Publication
follows complete Fuel and bounds preflight. Next connect computed source
endpoints, cleanup on endpoint exits and source-to-execution examples. Existing prices and capacities are not
changed by this preparation. The complete accepted objective remains open.

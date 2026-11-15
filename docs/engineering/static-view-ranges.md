# Checked frame-local Static ranges

Date: 2026-11-05. This prepares dynamic image-backed byte ranges after
[source equality](static-equality-source.md). The new `static_views` module is
bounded metadata preparation at this checkpoint. The
[execution successor](static-range-execution.md) now adds independently proved
RANGE 76 and actual frame spans. The [source successor](static-range-source.md)
now lowers computed endpoints and exit cleanup; public promotion remains open.
The preparation itself introduced no source syntax or public capability.

## Compact range metadata

A range contains an absolute start and length within the retained image's
4096-byte maximum. Each coordinate needs thirteen bits. A `u32` packs the two
fields in 26 bits; high/reserved bits reject. Sixteen descriptors per frame and
32 frames require exactly 2048 descriptor bytes. Existing liveness words remain
separate. This is fixed table geometry, not complete Engine/Instance/process
accounting or evidence of peak native stack/RAM usage.

The pinned SDK has no usize-to-u32 narrowing helper. After complete bounds
preflight, each pack performs at most 26 conversion iterations. Decoding does
not repack the actual word. Inspection separately validates the admitted maximum
window through a coordinate-only predicate; crop encodes only its result. Bounds are
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
follows complete Fuel and bounds preflight. The
[source successor](static-range-source.md) now lowers computed endpoints and
their nonlocal exit cleanup, with retained-image source execution cases. Existing prices and capacities are not
changed by this preparation. The complete accepted objective remains open.

## Coordinate-only preflight maintenance (2026-11-16)

Every concrete image-backed READ/LEN/EQUAL and several CALL/RET checks reach
`static_views::inspect`. Its maximum-window check used to call `pack` and discard
the resulting word. `crop` similarly packed its parent only to validate it, then
packed the actual result. Both now use the same private coordinate predicate as
`pack` and `unpack`: payload <= 4096, start <= payload, length <= payload-start.
Short-circuit evaluation retains the guard before subtraction and every later
addition. Metadata errors still precede guest endpoint errors, preserving kind 5
versus 14 and the original offset. Generic root traversal and byte/text rules
are unchanged. No validity cache, caller proof, state or allocation is added.

A concrete-window inspection removes one discarded encoding and its 0-26 bit
conversion iterations. A window at start 2048 with length 2048 needs 25 such
iterations in the original packer: 1024 inspections therefore remove 25600
iterations. At the empty 4096-byte end the original conversion takes 26. Crop
reduces pack calls from two to one; encoding the child remains necessary. The
4096-byte cap makes both versions O(1) overall, with O(1) auxiliary space. These
are source-level operation counts; throughput and physical peaks were not measured.

Run `build/toolchain/fairyc.exe check`, then
`python -B tools/verify-static-view-validation.py --profile all`. Its thirteen
native groups run in development and release with byte-identical input mirrors
and default native settings. An exact original implementation from `b6e054c`,
with only local function/type aliases and visibility changed, provides the oracle:

- 24576 concrete/generic window comparisons combine byte/text kinds, malformed
  words, boundary coordinates and near-maximum host integers.
- 32768 crop comparisons preserve parent/endpoint failure precedence; 512 pack
  comparisons cover the same coordinate matrix. All 4097 full-image suffixes
  and their empty ends remain representable. Successes and exact errors agree.
- Existing tests cover range/frame/liveness isolation, bounds and text rejection,
  CALL/PARAM/RET preflight, exact Fuel and RANGE failure atomicity before
  publication. Full retained invocation and recursive execution are not covered
  by this focused selection.

See [Windows evidence](../evidence/static-view-validation-windows-20261116.json).
Full Engine transport, public CLI, standalone memory and full release gates were
not rerun. An initial nineteen-group attempt failed: development hit native
stack exhaustion in `retained_calls_execute_narrowed_bytes_and_exact_text_at_exact_fuel`;
release exceeded the compiler's default 60-second MSVC command timeout. The
same development test reproduces the exact stack failure at unchanged baseline
`b6e054c` in an isolated locked mirror. These are recorded failures, not passes.
The final selection exercises the changed module and direct VM/transfer gates
with default settings; it does not claim to fix either integration limitation.
The known legacy source failure was not retested or claimed fixed.
Broader completion remains paused; this change is local only.

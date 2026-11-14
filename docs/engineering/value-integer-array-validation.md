# Validate integer arrays by retained shape

`value_codec::inspect` checks canonical bytes before private typed/value frame
initialization, copies, moves, tags and cleanup. Previously its scalar-array
branch decoded every element for all six scalar tags. This repeated arithmetic,
byte reads and cell conversion even for a maximum 4,096-element integer array.

The retained Layout privately owns a snapshot of the catalog and independent
shape proof. `value_properties` admits only i32, i64, u8, u32, usize or bool in
scalar arrays; `array_layout::scalar` proves 1..4096 elements with stride equal
to the exact scalar width. `inspect` checks the exact outer byte length before
following any active wrapper path. Array elements contain no padding or owner
authority. Every fixed-width integer byte pattern is a valid two's-complement
or unsigned value, including the upper usize half encoded by `cells::pack`.
Consequently only bool arrays can contain invalid scalar payload bytes.

The integer-array leaf now needs no payload scan. Its validation drops from
O(N*W) byte reads and N scalar decodes to O(1) retained-shape/length checks,
where N is element count and W is width. At usize[4096], one inspect eliminates
32,768 payload-byte reads and 4,096 scalar decode calls. The i64[4096] decoder
also probes each sign byte before accumulation, so it removes 36,864 source-level
byte reads (the same 32,768-byte payload plus 4,096 repeated sign-byte probes).
For u8[4096] it eliminates 4,096 byte reads and the same 4,096 decode calls. Bool
arrays still inspect every byte for >1, retaining O(N) work without per-cell
decode calls. Counts describe source-level work, not elapsed native time or
compiler-optimized machine instructions. Copying bytes remains O(N*W), and all
existing Fuel prices, quota accounting and physical copy operations are unchanged.

The shared outer length/type checks, record/scalar inspection, wrapper tag and
padding validation, zero inactive payloads, Buffer serial interpretation and
overlap rejection remain unchanged. Inactive or alternate wrapper branches may
still require O(payload size) zero checks. No unchecked-layout API, metadata
cache, allocation, native layout, ledger field or memory reservation is added.
This is private typed/value support, not new public CLI admission.

`tools/verify-value-integer-array-validation.py` selects six native groups.
The new array tests compare the original decode-every-cell branch with the new
inspection for all five integer tags at lengths 1,17,4096 and six byte patterns
(zero, all-ones, sign-bit minimum, signed maximum and two mixed patterns).
Short and oversized inputs must retain Bounds errors. Every u8 and bool byte
value 0..255 is exercised. Maximum bool arrays test all-zero/all-one and invalid
bytes at indices 0,2048,4095; failed bool copies preserve destination sentinels.
An Option<usize[4096]> fixture preserves inactive-zero, active-padding and tag
checks while mutating the original catalog after retain. Invalid scalar tags,
zero extents and extent4097 reject during layout retention. Existing record/
padding/tag/opaque-word tests and real frame initialization, independent copies,
maximum-array moves and four-wrapper operations exercise the actual owners.

Run development and release separately with the pinned compiler and default
native stacks. Receipts are written to
`build/value-integer-array-validation/<profile>/receipt.json`. Full Engine,
standalone memory, public CLI and release gates are outside this focused change.

Development and O2 each passed all six native groups in byte-identical locked
mirrors. All final inputs match implementation be38901. See the
[evidence](../evidence/value-integer-array-validation-windows-20261115.json).

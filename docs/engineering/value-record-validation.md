# Validate record domains without reconstructing integers

`value_codec::record` validates plain-record bytes during private typed-value
inspection, frame initialization, copies, wrappers and cleanup. It used to call
`scalar_codec::decode` for every scalar field, discarding every decoded value.

`retain` independently validates and privately snapshots the complete record
catalog, offsets, scalar widths, size and depth. `inspect` checks the exact byte
extent before reaching this walker. Admitted record fields contain only the six
scalar domains or another plain record. Every exact-width i32, i64, u8, u32 and
usize bit pattern is valid, including signed minima and the upper usize half.
Only bool has invalid scalar bytes: values greater than one.

The walker now checks bool directly and traverses integer fields using their
retained metadata. Nested traversal and every interior/tail padding check remain
unchanged. This does not bypass catalog admission, accept caller-supplied proof,
cache payload validity, or change value decoding at actual scalar-read sites.
Malformed bool and padding still reject before a copy can publish any bytes.

## Structural effect

For a 4096-byte record containing 512 i64 fields, one inspection removes 512
scalar-decoder calls and all 4096 byte-accumulation iterations. It also removes
512 source-level sign-byte reads. The 546 field visits in its repeated record
tree remain: two root fields, 32 intermediate fields and 512 scalar fields.
The u8 version has 4096 fields and removes 4096 decoder calls. No new state or
allocation is added; the existing fixed depth-16 cursor remains.

With F visited fields, B integer payload bytes and P padding bytes, the old
walker performs O(F + B + P) work and the new one O(F + P). Since scalar width is
at most eight bytes, B <= 8F, so both are O(F + P) overall. This is elimination
of unused payload reconstruction, not an asymptotic improvement or a measured
throughput claim. Actual copying still reads and writes the complete payload.

## Focused verification

Run `build/toolchain/fairyc.exe check`, then
`python -B tools/verify-value-record-validation.py --profile all`. The latter
uses byte-identical selected-test mirrors, the pinned compiler and default
native settings in development and release. Its eleven groups cover:

- The exact original record walker from baseline `eb4df78`, with only explicit
  type/field aliases changed, serves as the oracle. All five integer tags use
  4096-byte repeated record trees, six byte patterns and short/exact/long spans.
- All 256 values at every byte of a 96-byte nested mixed record: 24576
  mutations compare success, canonical active metadata and exact error kinds.
  Late bool/interior-padding/tail-padding failures preserve a dirty copy target.
- Record depth sixteen, four wrappers, active and inactive payloads, tag/padding
  corruption, retained snapshot isolation, cycles and unsupported scalar tags.
- Existing nested-record and canonical-byte tests, scalar byte round trips,
  rejected writes, frame initialization/copy independence and failure cleanup.

See the [Windows evidence](../evidence/value-record-validation-windows-20261116.json)
for final results, source identity and limitations. Full Engine transport, public
CLI, standalone memory and full release gates are outside this focused change.
The known legacy source-test failure is not retested or claimed fixed.

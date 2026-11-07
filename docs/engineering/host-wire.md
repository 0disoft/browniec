# Typed host wire codec

`src/host_wire.fy` implements the accepted revision-one TLV payload format in
Fairy C. This is the H02 codec prerequisite. It does not bind a catalog, grant
capabilities, dispatch a host operation or implement WAITING_HOST/reply adoption.
Public host and embedding availability remain false.

Requests contain a u16LE argument count and at most 32 positional fields. Every
field has a tag, three zero reserved bytes, a u32LE data length and exactly that
many data bytes, without padding. Replies contain one field for success or error;
fatal replies are empty. Error replies always use the u32 tag, independently of
the catalog success type. Unknown reply kinds and trailing bytes reject.

| Wire tag | Type | Data width | Existing scalar codec tag |
| --- | --- | --- | --- |
| 1 | bool | 1; only 0/1 | 2 |
| 2 | u8 | 1 | 10 |
| 3 | i32 | 4 signed LE | 1 |
| 4 | i64 | 8 signed LE | 9 |
| 5 | u32 | 4 unsigned LE | 11 |
| 6 | usize | 8 unsigned LE on x64 | 12 |
| 7 | bytes / Buffer reply | Exact supplied byte count | None |

The scalar values reuse `scalar_codec`, including sign-extended accumulation for
i32/i64 MIN and reversible packed i64 cells for the upper unsigned usize domain.
Byte fields carry no owner token and require no UTF-8 validation. Field tags must
match every expected catalog parameter or success result exactly.

`decode_request` returns fixed storage for up to 32 field descriptors only after
validating the entire message. Byte descriptors contain checked offsets and
lengths into caller storage. They do not retain or authenticate that storage;
callers must keep the original input immutable while using them. Scalar fields
also contain the decoded packed cell. Fatal replies return an empty descriptor.

`encode_request` and `encode_reply` accept typed scalar cells and checked ranges
into a separately borrowed byte blob. Scalar descriptor ranges are unused.
Both encoders validate all fields, ranges, totals, types, scalar domains and
output length before writing the first byte. Output must have exactly the
calculated size. Failure preserves all caller output bytes. Emission needs no
allocation, growth or fallible publication; scalar encoding follows its already
checked domain/width contract. The type system keeps mutable output exclusive.

The caller supplies a payload limit within the accepted 1MiB hard ceiling. All
headers count toward the limit. Totals use subtraction checks before addition;
untrusted u32 lengths never determine allocations. One byte-field request can
contain at most 1MiB-10 data bytes, and a byte-field reply at most 1MiB-8.
Zero-argument requests still require two bytes. Fatal replies may use limit zero.

Decoding visits at most 32 headers and eight bytes per scalar, without scanning
byte payloads. Encoding preflights at most 32 fields before copying their bytes:
O(argument count + copied bytes), with fixed descriptor/small scalar scratch and
no payload staging or heap allocation inside the codec. These synchronous helpers
do not establish R03 work-unit bounds; resumable host snapshot/adoption, accounting,
deadlines, request identities and external-effect rules remain separate work.

Run `python tools/verify-host-wire.py --profile all` for the focused Windows
development/release checks. The verifier uses locked independent mirrors,
default native stacks and the pinned compiler. It runs six codec groups and four
existing scalar-codec groups. The included original three wire vectors are
checked against literal test bytes; the original ZIP is not required to verify.
Tests cover exact encodings, signed/unsigned extremes, count 0/32/33, truncated
prefixes, reserved/tag/bool/length corruption, reply contracts, output atomicity
and real 1MiB payloads backed by native Buffers rather than large stack arrays.

Catalog admission/canonical SHA-256 binding, registry synchronization, Engine
lifecycle, HOST_REQUEST/WAITING_HOST/adoption and OS broker validation remain open.
No opcode, VM limits, existing Fuel price or public CLI admission changes.

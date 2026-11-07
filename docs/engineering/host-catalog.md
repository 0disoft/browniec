# Strict host catalog admission and binding bytes

`host_catalog` is the concrete H02 metadata prerequisite following `host_wire`.
It admits host-owned catalog JSON and produces immutable decoded descriptors,
exact revision-one canonical bytes and their SHA-256. It does not grant a
capability, resolve dynamic symbols, dispatch a host call, implement WAITING_HOST
or adopt a reply. Public host and embedding availability remain unchanged.

## Admission

`parse(ref u8[]) -> Result<Catalog, Error>` limits the complete input, including
whitespace, to 16,384 bytes before UTF-8/token scanning. There are at most 64
imports and 32 parameters per import. Grammar depth is fixed; unknown values
are rejected without recursive extension parsing. All required root/import
fields are checked, decoded duplicate keys reject, and exactly one root is
required. Empty imports and zero parameters are valid.

IDs must be unsigned decimal integer tokens 0..63, equal to their array index.
Fractions, exponents, signs and nonnumeric IDs reject. Imports must already be
strictly increasing by the ASCII bytes of the complete `module::symbol` spelling.
Admission never silently sorts or renumbers. Duplicate decoded module/symbol
pairs reject; comparing only a `(module, symbol)` tuple would mishandle prefix
cases such as `host::a0::x` versus `host::a::x`.

Names use the accepted ASCII spelling, without applying source keyword bans:
module `host::` plus identifier segments (maximum 128 bytes), symbol identifier
(64), dot-separated lowercase/alphanumeric capability segments (128), and
alphanumeric/underscore/dot adapter revision (64). Decoded NUL, non-ASCII,
malformed UTF-8, malformed escapes and invalid surrogate pairs reject. String
lengths apply after JSON decoding; escaped ASCII is equivalent to literal ASCII.
Capability metadata remains a declaration, including for read effects.

Parameters are exactly `bool`, `u8`, `i32`, `i64`, `u32`, `usize`, `ref u8[]`.
Results are exactly `Result<T,u32>`, where T is one of those six scalars or
`brownie::bytes::Buffer`. Effect is exactly `read` or `write`. The Buffer result
spelling is 34 bytes. Alternate whitespace/type aliases, ref str, mutable views,
arbitrary aggregates and other error types reject.

## Read-only APIs and storage

`Catalog` privately owns decoded names, independent of the original input's
lifetime/mutation. It exposes no mutable descriptor storage. Import indices are
their admitted IDs. Accessors return `Bounds` for invalid import/argument indices.

- Bounds: `byte_limit`, `import_limit`, `argument_limit`, `canonical_limit`.
- Imports: `count`, `module_name`, `symbol`, `capability`, `adapter_revision`, `effect`.
- Types: `parameter_count`, `parameter_tag`, `parameter_type`, `result_tag`, `result_type`.
- Binding: `canonical_bytes -> Result<bytes::Buffer, Error>`,
  `digest -> Result<u32[8], Error>`.

Parameter/result tags match `host_wire`: bool=1, u8=2, i32=3, i64=4, u32=5,
usize=6, bytes=7. Buffer success uses 7; Result errors still use u32 tag 5 in the
wire decoder. `Error` includes a failure kind and original JSON byte offset;
non-parser allocation/bounds failures use offset zero. Error categories are not
a public CLI or ABI contract.

Storage is one bounded decoded byte pool plus a fixed table of 64 import
descriptors and 2,048 parameter tags. Array-bearing records are not copied as
mutable table elements. Parsing scans at most 16KiB, with bounded duplicate and
qualified-order comparisons. There is no recursive parse, ambient filesystem
access or untrusted-size allocation. Allocation failures drop unpublished state.
No allocation-failure injection or resumable R03 work-unit evidence is claimed.

## Exact canonical identity

The output is `BRC-CATALOG-1` plus LF, import count u32LE, and each import's ID
u32LE followed by six u32LE-length-prefixed ASCII strings in this exact order:
module, symbol, result, effect, capability, adapter_revision. Next are parameter
count u32LE and each parameter's length-prefixed canonical type. There is no
padding or trailing byte. Schema maxima bound this below 58KiB; a defensive
65,536-byte output ceiling checks additions using subtraction first.

The returned Buffer is freshly owned. Failure exposes no partial canonical
output. JSON key order, whitespace and ASCII escapes do not affect identity;
changing effect, capability or adapter revision does. Hash equality does not
authorize a host request or replace separate grant checks.

`catalog_digest` is a small pure Fairy SHA-256 helper adapted from fairyc's
`examples/lexer_candidate/src/sha256.fy`. It accepts at most 65,536 bytes, returns
eight SHA words in standard order (serialize each word big endian), and uses
checked 16-bit-limb modular sums plus masked rotations. It invokes no compiler,
external crypto process or runtime shim. `host_catalog::digest` hashes the entire
canonical Buffer. Digest implementation is included; Program/parent catalog
binding and immutable Program descriptor adoption remain later work.

The accepted ZIP vector is 125 bytes and hashes to
`bfec9acc23d667b2fe2bd5a11e801c4e2c42ffad6b58a5632d39583098092f94`.
Original schema/example/vector bytes and ZIP/member hashes are retained under
`tools/host-catalog/reference`. Reference documents supply data, never commands.

## Focused verification

After refreshing the lock in an isolated working copy using the pinned compiler,
run `python tools/verify-host-catalog.py --profile all`. No compiler overrides or
stack changes are used. The verifier reuses the existing locked native mirror
runner and preserves exact commands, compiler identity, raw source/test/lock/
fixture hashes, stdout/stderr and native reports per development/release profile
under `build/host-catalog`. Existing source modules are copied byte-identically.

Twelve native groups cover the original vector and empty catalog; decoded keys;
every missing field; strict grammar/UTF-8; spelling/type rejection; ID and full
qualified ordering; all seven parameter/result tags; binding-field changes and
equivalent JSON; byte/import/argument/name limits; owned storage/bounds; SHA
padding and hard limits; and real catalog-to-wire decoder composition. The last
group passes admitted parameter/result tags to `host_wire::decode_request` and
`decode_reply`, including i32 MIN's scalar mapping, Buffer success, u32 error and
parameter/result mismatches. This does not establish host execution state.

The Python reference check independently calculates canonical bytes and hashes,
checks original fixture provenance, and proves that each corpus input is present
byte-for-byte in a native assertion. It is an oracle/coverage check, not runtime
admission evidence. Native SHA known answers cover lengths 0, 1, 55, 56, 63, 64,
65, 119, 120, 127, 128, 16384 and 65536; 65537 rejects before hashing.

Root integration, a root lock refresh, broad VM/CLI regressions, public host
availability and remote delivery are outside this isolated patch slice.

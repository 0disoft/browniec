# Canonical native value bytes

`value_codec` is the byte-storage prerequisite for the [typed value IR](value-ir.md).
It retains an immutable, private-field Layout from independently checked type and
plain-record catalogs. Native byte operations borrow that exact snapshot. It is
not executable admission, a guest bytecode loader or an owner-token authority.

## Representation and active ownership

Scalar fields use the existing checked little-endian codec. Arrays contain only
their declared scalar domain; records retain nominal identity, declaration-order
aligned fields, nested record depth at most sixteen and canonical zero padding.
Record traversal uses an explicit fixed-depth cursor, not native recursion or
payload-sized scratch. It supports the target's 4096-byte plain-record layout
without widening the older executable record storage's separate bounds.

Wrapper storage uses the accepted one-byte layout: Option none0/some1 and Result
ok0/err1. The adapter explicitly translates the IR's logical some/ok1 and none/err0
convention. Payload offsets, union tails and alignment follow independently
planned whole-type sizes. Every published padding/inactive byte is zero; the
codec checks those bytes without interpreting an inactive scalar or owner word.

The active path selects at most four wrappers and one leaf. Since record and array
fields cannot contain Buffer, **at most one Buffer is active in a value**, even
when many inactive alternatives contain Buffer types. Buffer's eight logical
bytes encode a nonzero opaque serial. Inspection returns its exact byte offset
and complete 64-bit serial, including the maximum word, but cannot authenticate
its allocation. The future owning store must resolve that serial to its exact
live native root/descriptor and initialized value binding before use or cleanup.
Whole-type copyability still includes every inactive alternative.

## Atomic byte operations

`inspect` checks full shape, tags, scalar domains, canonical bool, record padding
and inactive bytes before a value may be published. `read_scalar` and
`write_scalar` preserve the existing signed/unsigned cell codec and stage failed
scalar writes. `select` validates a wrapper, translates its tag and returns exact
payload metadata on a matching case; mismatch and none do not expose payloads.

`copy_at` authenticates the complete source and both windows before writing.
Its direction-aware loop supports identical, disjoint and both overlapping copy
directions using one mutable backing view. `wrap_at` validates the selected
source and complete destination before zeroing the wrapper and copying payload
bytes. It rejects overlap that would destroy a source during destination zeroing.
Late invalid bool/tag/padding, oversized indices, unsafe overlap and invalid
variant errors preserve every destination byte.

These are byte helpers: copying a Buffer serial grants no ownership and cannot
publish another live owner. Future VM code must enforce the independent IR's
copy/move/Dead rules, native serial/root authentication and precharged work before
calling them. No helper allocates payload scratch or reserves a replacement
owner. Work is bounded by representation bytes plus visited plain-record fields;
type traversal is iterative. This is not an Engine stepping/deadline claim.

## Integration and verification

Run `python -B tools/verify-value-codec.py --profile development` and the same
command with `--profile release`. The six native groups cover all six scalar
domains and signed/unsigned edges, retained-layout isolation, exact tag bytes,
four wrappers with one active Buffer, inactive/scalar alternatives, nominal and
nested record padding, atomic late errors, both overlap directions, size/bounds
guards, maximum scalar arrays and 4096-byte/depth16 records.

The [owning root successor](value-roots.md) now retains actual native allocations,
serial/token/location bindings and metered movement/retirement with prepaid failure
drain. The next slice still needs metered value/frame operations,
CALL/RETURN and normal/failure cleanup, then compiler source binding. The pinned
compiler does not currently admit whole-Buffer replacement through a mutable
reference: a native capability probe of `*b = bytes::empty()` in
`fn void clear(ref mut bytes::Buffer b)` returned E1008. Do not work around it
with unchecked storage or modify the separate Fairy C checkout. Its existing
generic Vec push/pop APIs can transfer complete Buffer roots; a bounded secondary
vector can support removal while the invocation retains stable logical tokens.
A separate development native capability probe successfully moved an allocated
64-byte Buffer containing `keep` through two such pre-reserved vectors. This is
SDK primitive evidence, not an implemented owning Brownie value store.
This is an implementation route, not an added guest language restriction.

No public syntax, capability, opcode admission, price/default/ceiling or execution
path changes here. Public CLI/full language/native Fuel matrices, LF mirrors,
Linux, OOM injection, general stack/performance and clean-machine delivery are
not rerun for this private byte primitive. Full L04/L05/D01-D04 and the broader
Engine/Instance/host/delivery work remain open.

Windows development and release each passed all six final native groups on
`f5d3d1a`, without native overrides or historical reuse. Current input hashes
match checkout and Git raw bytes; see the [Windows evidence](../evidence/value-codec-windows-20261107.json)
and its [input manifest](../evidence/value-codec-inputs-windows-20261107.json).
Local commits only; no push, release or deployment.

# Private owned exclusive slice IR

This document records its named implementation checkpoint. The
[public mutable-slice successor](m2-slice-exclusive-public.md) now enables public
verification and execution; gate statements below describe the earlier stage.

The IR now represents function-local exclusive slices over mutable owned scalar
arrays. This is an independently inspected foundation. Public `verify` and VM
entry reject every exclusive declaration until metered exclusive dispatch and
cleanup are implemented. Public readonly scalar slices keep their behavior.

Implementation: `ae66b1b`.

The [write-instruction successor](m2-slice-write-ir.md) adds private opcode 60
construction and inspection. Exclusive VM execution and guest syntax stay gated.

## Metadata and construction

For owned sites, `Program.slice_elements` uses zero for readonly and the
reserved marker 128 for exclusive access. Rootless sites retain their exact
scalar tag (1, 2, 9, 10, 11 or 12). `ir::exclusive` reads the marker. It requires
an existing mutable owned scalar-array root.
Rootless formal/derived sites, immutable roots and orphan flags are invalid.
The existing root metadata determines the exact element tag and owning function;
equal-width tags are not interchangeable.

`ir::exclusive_slice` checks root mutability before reserving one shared slice
site. Free-site lookup includes the marker byte so malformed orphan metadata cannot
be silently reused. Failed admission and exhaustion leave declarations, code and
registers unchanged. There are still at most sixteen static slice sites per
Program, shared by readonly, exclusive, formal and derived declarations.

Existing open/read/length/UTF-8/close instruction encodings describe the private
trace. UTF-8 remains `u8`-only. Bounds must be defined ordinary `usize` values;
inspection does not prove their runtime values are within the selected root.
No slice write instruction or guest mutable-slice syntax is added here.

## Independent flow proof

`verifier::inspect` runs the complete metadata, type, function, register and
lifetime proof with these additional rules:

- An exclusive open requires a live mutable owned root and no live slice of that
  root. A readonly open rejects a live exclusive slice of the same root.
- Exclusion covers the entire root, including disjoint or empty selected ranges.
  Other roots remain independent. Closing a site removes its exclusion, allowing
  a later borrow of the same root.
- Ordinary root reads, UTF-8 scans, mutation, fill, destination assignment and
  drop cannot bypass a live exclusive slice. Array copies and assignment sources
  are checked independently of their destinations.
- A live exclusive site may be read, queried for length or scanned for UTF-8
  through its own typed site. It cannot be passed as a readonly CALL argument.
  Exclusive parameters, aliases, derived subranges and reborrows are unsupported.
- Existing exact live sets at branch joins and backedges also prove exclusive
  balance. All borrows must close before scalar or aggregate return and before
  root release. Site metadata fixes the borrow kind; no extra per-PC live mask
  is required.

Both the subslice builder and independent instruction validation reject exclusive
parents/destinations. Directly fabricated IR therefore receives the same checks
as constructed IR. Source instructions, array-result transfer and existing CALL
argument rules retain their other independent checks.

## Execution boundary and costs

Public `verify` first performs the full inspection, then rejects any exclusive
flag with the existing verification error at offset zero. This includes unused
exclusive declarations. VM entry rejects before backing preparation, Fuel
consumption or shared slice dispatch. The private inspection result is not
permission to execute through the shared-read adapter.

No opcode, profile, result schema, Fuel schedule or version capability changes.
The marker reuses existing site bytes without adding Program fields. Per-root
conflict checks scan at most sixteen sites; no payload clone or allocation path
is added.
These are structural bounds, not native-layout, stack, allocator or timing
measurements. Full M1 CLI includes accepted scalar-call nesting at depth 32 and
`compile_limit` at depth 33, so recursive compiler scratch remains covered.

Next integration needs a checked slice-write instruction, exclusive runtime
ticket storage, metered open/access/close dispatch and error cleanup. Guest
origins and syntax must follow that runtime work. The existing private
[owner-session foundation](m2-array-write-leases.md) supplies checked native
exclusive range reads/writes, but is not connected by this IR slice.

## Focused verification

```text
python -B tools/verify-m2-slice-elements.py --profile development --exclusive-ir
python -B tools/verify-m2-slice-elements.py --profile release --exclusive-ir
```

The selection includes six exclusive-IR groups, five existing borrow-flow groups
and three public scalar-slice groups. Development and release each passed all
14 selected native groups and 2,199 CLI cases: 192 public readonly scalar-slice
cases and all 2,007 M1 CLI cases on Windows. Both profiles matched 353 identical
current input hashes; compiler, retained CLI, public matrix and full M1 receipt
identities were rechecked. Both accepted depth 32 and rejected depths 33 and 64
with `compile_limit` in check/run. See the
[Windows evidence](../evidence/m2-slice-exclusive-ir-windows-20261101.json).

Full native and other M2 suites, Linux, M0, isolation, packaging, allocator and
timing checks are outside this selection. No mutable slice source execution,
returned borrows, mutable parameters, subloans or automatic exclusive cleanup is
claimed. Earlier receipts remain historical for their original source inputs.
No push, publication, packaged release or deployment was performed.

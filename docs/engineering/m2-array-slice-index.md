# Checked read-only slice indexing

Implementation: `b7eda85` on VM foundation `74ce29c`.

Lexical `ref u8[]` bindings support `part[index]` as a scalar u8 expression.
This extends [checked slice lengths](m2-array-slice-length.md) and the
[source slice contract](m2-array-utf8-slices.md). Version JSON adds
`array_slice_index: true`.

```c
module main;
fn i32 main() {
    var u8[4] bytes = [0; 4];
    bytes[1] = 20;
    bytes[2] = 22;
    let ref u8[] part = ref bytes[1..3];
    return (part[0] as i32) + (part[1] as i32);
}
```

## Source behavior

The index is an ordinary usize expression evaluated once at the access site.
Calls, mutable scalar loads, array/slice reads, scalar record fields, arithmetic,
widening casts and switch values reuse existing expression lowering. Multiple
accesses evaluate left to right. Original slice endpoints are not reexecuted.
The range remains the one captured when the slice opened.

Bounds are relative to the selected range: `part[0]` reads the first selected
byte; `part[part.len]` and every read of an empty range fail with bounds kind 14.
The complete usize domain is checked before address arithmetic. A returned u8
is an independent scalar snapshot and may outlive the slice. It is a byte, not
a decoded UTF-8 character.

Indexing preserves the lexical loan. Root writes stay blocked even after the
last read until scope exit. Writing `part[index] = value` remains a type error.
Existing reverse-order cleanup applies to normal completion, return, question
propagation, break and continue, including exits inside an index expression.
The runtime abort finisher still closes retained sessions after an error.

Reslicing, slice aliases, slice parameters/results, mutable slices, non-u8 source
slices and borrowing temporaries remain unavailable. General postfix chaining
is not added. Sixteen static sites, sixteen concurrent handles, sixty-four
lexical bindings and the 128-register ceiling are unchanged.

## IR and runtime

New private opcode 58 encodes `op,dst,a,b,0,0,0,0`. `a` is a live declared
slice site, `b` a defined nonslot usize register in the current function, and
`dst` a fresh nonslot scalar register of the origin element type. Independent
verification requires the live function-owned origin and slice, canonical
operands and the correct register partition. It changes no origin/loan live set.
The private builder supports existing scalar origin types; guest slices remain u8.

Execution prepays `4097 + (33 + stride)` Fuel before semantic ticket/index reads.
For u8 the price is 4131. The second term is the unchanged ordinary scalar array
read price. Open, UTF-8, close and length prices remain unchanged.

The runtime checks the current frame, origin shape and owner token, ticket
generation, active read session, retained range and full backing capacity, then
uses `array_slices.read` and the existing checked leased-view read and scalar
codec. The index must be below the selected length before offset construction.
Only a successful read publishes the destination scalar. Failed Fuel, bounds,
stale/forged metadata and missing backing preserve output and loan state.

Each access reads one scalar (one payload byte for source u8 slices), adds one
scalar register, and creates no owner, range handle, payload copy or allocation
path. Metadata validation is bounded O(D*O), with D=O=16; scalar payload work is
O(stride), independent of the selected/root length. These are structural bounds,
not measured timing or allocator/process-memory results.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --slice-index`
and repeat with `--profile release`. Each profile selects 27 native groups:
three new VM index, three source index,
four slice length, eight private slice VM, six lexical source slice and three
ordinary array length groups. The CLI selection has 546 invocations: 186 index,
104 length, 248 source slice and eight scalar/array/record/unsupported-Buffer
sentinels. Both profiles passed with 316 matching source/test/tool input hashes.

Coverage includes relative offsets, empty and 4096-byte ranges, high unsigned
indices, exact Fuel, once-only ordered effects, function-local scalar results,
index-expression exits, lexical write conflicts, malformed independent IR,
short backing, stale tickets/sessions and frame mismatch. Older rejection cases
for supported `p[0]` now reject boolean `p[true]` indices instead.

The four-byte comparison fixture uses exactly 73890 Fuel with a four-byte arena
and 139422 with the default CLI arena. One less fails with Fuel kind 8.

The [Windows evidence](../evidence/m2-array-slice-index-windows-20261031.json)
records compiler/SDK identities, matching profile inputs, native reports, CLI
matrix receipt hashes and retained executable hashes.

Full suites, other CLI matrices, M0, Linux, DLL embedding, isolation, packaging,
allocator instrumentation and timing benchmarks are outside this selection.

# Checked read-only subslice bindings

Implementation: `f1216c3` on VM foundation `5b37d6b`.

Lexical `ref u8[]` bindings can select another half-open range from a named live
slice. This extends [slice indexing](m2-array-slice-index.md),
[lengths](m2-array-slice-length.md) and [lexical slices](m2-array-utf8-slices.md).
Version JSON adds `array_slice_sub: true`.

```c
module main;
fn i32 main() {
    var u8[5] bytes = [0; 5];
    bytes[2] = 20;
    bytes[3] = 22;
    let ref u8[] parent = ref bytes[1..5];
    let ref u8[] part = ref parent[1..3];
    return (part[0] as i32) + (part[1] as i32);
}
```

## Source and lifetime rules

The range is relative to the selected parent, rather than the original array.
Both endpoints are ordinary usize expressions evaluated once, left to right,
before child publication. The parent endpoints are never reexecuted. Empty
ranges and nested selections are supported. Missing start means zero; missing
end reads the parent's checked `.len` after the start expression. The omitted-end
getter keeps its existing 4097 Fuel price and lifetime/backing checks.

Require `0 <= start <= end <= parent.len`. Reversed ranges, an endpoint past the
selected parent and high unsigned endpoints fail with bounds kind 14, even if
the corresponding root-relative range would fit inside the original array.
Empty children remain checked live handles; reading one fails with bounds.
Length, scalar indexing and `text::valid_utf8(child)` retain existing behavior.

Every child receives one independent range ticket sharing the original root's
read session. Closing a child does not close its parent or peers. The private VM
also permits closing the parent before a child: the child retains a flattened
root-relative view and stays readable. Only the last handle ends the session.
Root writes remain blocked until every lexical loan has closed, even after the
last use of a child. No parent pointer or payload lifetime depends on a retired
parent ticket.

Source bindings remain lexical and cannot escape their scopes. Reverse-order
cleanup is unchanged for blocks, value arms, return, question propagation,
break and continue. A pending child's endpoint exits close only previously
published loans/owners. VM abort cleanup drains all retained tickets and preserves
the original outcome when cleanup succeeds.

An explicit range is required: `ref parent[..]` creates another checked handle;
`ref parent` remains an unsupported alias. Reslicing is available only in a
slice declaration, not as a general expression such as
`text::valid_utf8(parent[..])`. Slice parameters/results, mutable slices, non-u8
source slices, borrowing temporaries and general postfix chaining remain
unavailable. Each child consumes one of sixteen static sites, one live handle
and one of sixty-four lexical entries. The shared sixteen-handle invocation
ceiling applies across functions and frames.

## IR, verification and runtime

Private opcode 59 encodes `op,dst,a,b,end,0,0,0`: dst is a declared inactive
child site; a is a declared live parent; b and end are defined function-local
nonslot usize registers. Parent and child catalog entries must name the same
live function-owned root. The independent verifier admits only the child's new
live bit, leaving scalar definitions, root and parent liveness unchanged. It
rejects active destinations, dead/mismatched parents and noncanonical operands.

The VM prepays 65537 Fuel, including conservative abort cleanup, before semantic
ticket or endpoint-cell reads. It validates frame/site bounds, matching Program
origins, current owner token and shape, destination inactivity, parent ticket
generation/session/range/backing and relative endpoints, then reuses the existing
`array_slices.subslice` operation. That operation flattens the range and publishes
one ticket only after successful validation and capacity admission. Fuel,
bounds, stale state, missing backing, occupied destination and full-pool errors
leave the destination unpublished and existing handles/session/output unchanged.

There is no payload scan, payload copy, new owner, extent or allocation path.
Metadata work is bounded O(D*O), D=O=16, independent of selection length. Source
endpoint expressions retain their ordinary work and register requirements;
opcode 59 itself produces no scalar register. These are structural bounds, not
allocator/process-memory or timing measurements. Existing open, UTF-8, close,
length, scalar-read and array prices remain unchanged.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --slice-sub`
and repeat with `--profile release`. The selection has 19 native groups: three
new subslice VM, three source subslice, three source index, four slice length
and six lexical source slice groups. The CLI selection has 670 invocations:
124 subslice, 186 index, 104 length, 248 lexical slice and eight sentinels.
Both profiles passed with 319 matching source/test/tool input hashes.

Coverage includes 4096-byte and empty parents/children, relative byte offsets,
nested/open/computed ranges, UTF-8 bytes, once-only ordered endpoint effects,
retained-bound snapshots, argument/result array roots, endpoint exits, write
conflicts, parent-before-child close, stale ticket/session/frame rejection,
atomic admission failures, full pool, independent malformed IR and exact Fuel.
The explicit four-byte child comparison fixture requires 143526 Fuel with a
four-byte arena, or 209058 with the default CLI arena; one less must fail.

The [Windows evidence](../evidence/m2-array-slice-sub-windows-20261031.json)
records matching profile inputs, compiler/SDK identities, native reports, CLI
matrix receipt hashes and retained executable hashes.

Full suites, other CLI matrices, M0, Linux, DLL embedding, isolation, packaging,
allocator instrumentation and timing benchmarks are outside this selection.

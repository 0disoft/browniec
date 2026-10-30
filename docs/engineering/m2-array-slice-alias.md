# Checked read-only slice aliases

Implementation: `1ed056f`.

`let ref u8[] other = ref part;` reborrows the complete retained range of a
named live lexical slice. It is shorthand for `ref part[..]`, using the existing
[subslice implementation](m2-array-slice-sub.md). Version JSON adds
`array_slice_alias: true`.

```c
module main;
fn i32 main() {
    let u8[4] bytes = [42; 4];
    let ref u8[] part = ref bytes[1..3];
    let ref u8[] other = ref part;
    return other[1] as i32;
}
```

## Semantics and lifetime

The alias preserves the parent's selected start and end, including an empty
selection. It does not expand to the original array. Aliases of aliases and
aliases of subslices are allowed; a named alias can itself be resliced. Existing
byte length, scalar indexing and UTF-8 predicates work on the alias. Original
endpoint expressions are never reexecuted.

Each alias receives an independent checked ticket sharing the original root
read session. It does not copy the parent's ticket identity or own another array.
Closing an alias preserves its parent/peers. The root remains borrowed until all
handles close. Source aliases are immutable lexical bindings: they cannot be
reassigned, written through or escape their scope. Scalar snapshots can escape
as before. Reverse-order cleanup on blocks, value arms, return, question,
break and continue is unchanged. The pending name is absent from its initializer,
so self-reference, duplicate names and expired parent names are rejected.

An alias consumes one static slice site, one live handle and one lexical entry.
Existing ceilings remain sixteen static sites, sixteen live handles per
invocation across frames and sixty-four lexical entries. The alias itself has
no scalar register; its zero bound and checked length use ordinary registers.
Source slice parameters/results, mutable/non-u8 slices, borrowing temporaries,
implicit scalar use and general slice expressions remain unavailable.

## Lowering, checks and Fuel

A bare parent lowers identically to its explicit `[..]` form: a usize zero,
checked parent length (57), and one existing subslice instruction (59), followed
by the existing close instruction (56) at lexical exit. Instruction bytes,
register types, constants and slice origins match; source offsets retain the
correct anchors for each spelling. No new opcode, verifier rule, VM dispatch,
storage operation, payload copy or heap allocation path is added.

Length and publication independently revalidate the parent/root/ticket/session,
range and backing. Opcode 59 also checks the inactive destination and capacity
before publishing an independent handle. The private subslice foundation
already verifies parent-before-child close, stale tickets/sessions, frame
mismatch, malformed IR, capacity admission and abort cleanup.

Prices remain 4097 Fuel for the length getter, 65537 for publication including
abort cleanup and 4097 for lexical close, plus ordinary scalar work. The simple
alias declaration executes one zero constant, so its pre-close instruction
cost is 69635 Fuel; with close, 73732. These are existing prices, not a cheaper
ticket copy. Metadata work is bounded O(D*O), D=O=16, independent of payload
length, with no payload scan. No allocator/process-memory or timing measurement
is claimed. Many sequential aliases can compile but exceed the CLI's 1000000
Fuel allowance before the static site limit.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --slice-alias`
and repeat with `--profile release`. The selection has 15 native groups: three
new alias, three private subslice VM, three source subslice and six lexical
source slice groups. The CLI selection has 500 invocations: 120 alias,
124 subslice, 248 lexical slice and eight sentinels. Both profiles passed with
321 matching source/test/tool input hashes.

Coverage includes selected/empty/4096-byte and UTF-8 ranges, alias chains,
subslice interoperation, captured endpoints, named array parameters/results,
bytecode equivalence, scope and exit cleanup, mutation/assignment/self-reference
rejection, selected bounds, lexical/static ceilings and exact Fuel. Historical
unsupported-alias checks now reject self-reference instead.

The four-byte comparison fixture needs exactly 147622 Fuel with a four-byte
arena, or 213154 with the default CLI arena; one less must fail with Fuel kind 8.
The [Windows evidence](../evidence/m2-array-slice-alias-windows-20261031.json)
records matching profile inputs, compiler/SDK identities, native reports, CLI
matrix receipt hashes and retained executable hashes.

Full suites, other CLI matrices, M0, Linux, DLL embedding, isolation, packaging,
allocator instrumentation and timing benchmarks are outside this selection.

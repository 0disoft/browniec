# Lexical read-only u8 slice bindings

The [checked length successor](m2-array-slice-length.md) now supports `.len`
as an ordinary usize value while preserving each root loan. Indexing, reslicing,
aliases, slice parameters/results and temporary roots remain unavailable. The
source checkpoint below records the earlier UTF-8-only consumer set.

Implementation: `718ab34`.

Brownie source now supports immutable local `ref u8[]` bindings over named live
u8-array owners. They use the [private slice VM](m2-array-slice-vm.md) and
[shared registry](m2-array-slices.md), without another array owner or payload copy.
The version JSON reports `array_utf8_slices: true` after this focused verification.

```c
var u8[4] bytes = [65; 4];
{
    let ref u8[] part = ref bytes[1 + 0..bytes.len];
    let ref u8[] whole = ref bytes;
    if (!text::valid_utf8(part) || !text::valid_utf8(whole)) { return 0; }
}
bytes[0] = 66; // Both read handles have closed.
```

## Accepted source and bounds

The binding is `let ref u8[] NAME = ref ARRAY[RANGE];`, or `ref ARRAY` for the
entire owner. The named owner may be an immutable/mutable local, an array
parameter or a named array-call result. Supported half-open forms are `[lo..hi]`,
`[..hi]`, `[lo..]` and `[..]`. Endpoints use ordinary strictly typed usize
expressions, including scalar names, calls, fields, indexed scalar reads, casts
and switch values. Missing bounds become zero and the fixed origin length.

Bounds evaluate once, left to right, before the session opens. A mutable start
expression is loaded/snapshotted before any end-expression effects. The pending
slice name is absent during both endpoints. Root and earlier-borrow cleanup
therefore remain correct when an endpoint returns, propagates `?`, breaks or
continues. A session is published only after both endpoints and the declaration
terminator have been checked. Source effects before runtime failure are retained.

All bounds, including literal bounds, use opcode 54's checked runtime range:
reversed/out-of-root/full-unsigned invalid bounds are kind 14. Arithmetic failure
happens during ordinary endpoint evaluation before publication. Empty ranges are
valid and still acquire a read handle; UTF-8 validity is true after validation.

The only consumer in this slice is `text::valid_utf8(NAME)`. The scalar result
is an ordinary bool. A binding cannot be used as a scalar, copied/assigned into
another slice, indexed, queried for `.len`, resliced or passed/returned as a slice.
Borrowing direct call results, literals or other slices is unavailable. `var ref`,
`ref mut`, non-u8 slice types, fixed-length ref syntax, inclusive ranges and
slice declarations in for headers remain unsupported. Qualified source forms
that were already supported retain their old lowering and Fuel prices.

## Scope, conflicts and transfers

Bindings use lexical table values 160..175, distinct from scalar registers,
array IDs 128..143 and record IDs 144..159. Each consumes one of the existing
64 active lexical binding entries and one of sixteen static slice sites per
program. Sites are not recycled after leaving a source block; a loop reuses its
single static site on every iteration. Live registry handles remain capped at
sixteen across all frames, not sixteen per frame.

The borrow lasts until its lexical scope exits, even after its last source use.
While any visible slice borrows a root, destination element writes, repeated
fills and whole-array assignments are source type errors. Existing independent
IR verification also rejects those operations on borrowed roots. Reads and value
copies from the root remain allowed, including ordinary array call arguments;
copies are independent owners and still require their own storage quota.

Scope cleanup visits bindings in reverse declaration order. It emits opcode 56
for each slice before dropping its earlier source owner. The same cleanup serves
normal block ends, scalar returns, `?` propagation, break/continue and value-arm
completion. Array/record return finishers now close slice bindings in the same
mixed reverse order, then transfer the selected unique result. Returning a named
array closes its local read handles before ARET; the slice itself never escapes.

Multiple bindings over one root share a session. Closing an inner binding keeps
outer/peer borrows active. Only the last close restores root writes; use an inner
block when the owner must be modified later. Existing invocation cleanup also
drains sessions on VM failure such as insufficient Fuel. This adds source lexical
lowering, not a nonlexical-lifetime analysis or automatic retry of guest effects.

## Costs and limits

Every declaration emits ordinary usize bounds and one open (54); each predicate
emits scan (55), and each lexical exit emits close (56). There is no payload copy,
extra owner, new opcode, new Fuel schedule or additional registry capacity.
The private prices remain 65537 for open (including deferred abort cleanup),
4097+4*N for a scan of an origin of length N, and 4097 for close. Selected empty
ranges pay the same price as other ranges on that origin. These are logical
charges, not measured execution times. Ordinary endpoint instructions pay their
existing charges separately.

The four-byte whole-slice source fixture with a four-byte arena needs exactly
73869 Fuel; with the CLI's default 65536-byte arena it needs 139401. The public
CLI's 1000000-Fuel maximum remains unchanged, so a source with sixteen sequential
open/close pairs can check successfully but exhaust CLI Fuel during execution.
A seventeenth static declaration fails with `compile_limit`. The existing
64-binding ceiling is checked before evaluating the new declaration.

The registry's fixed metadata and backing-association obligations remain. This
slice does not add Buffer/text ownership, scheduler cancellation, DLL embedding,
allocator instrumentation or timing/space measurements.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --slices`
and repeat with `--profile release`. Each profile passed 29 native groups: six
new source groups, eight slice VM, five temporary-computed range, five named
computed range and five named UTF-8 predicate groups. Each passed 762 tool-free
CLI invocations: 248 new slice cases, 310 temporary computed, 196 named computed
and eight scalar/array/record/unsupported-Buffer sentinels.

New tests cover multibyte and all-empty selections, 4096-byte roots, whole/open
ranges, named parameters/results, ordered computed bounds, multiple/looped loans
without extra owners, every lexical exit category, scalar/array/record returns,
source mutation conflicts, invalid scalar/escape uses, missing scope names,
malformed syntax, maximum unsigned bounds, arithmetic/Fuel failures, exact Fuel,
16/17-site and 64-binding limits, and verifier rejection after removing a close.

The [Windows evidence](../evidence/m2-array-utf8-slices-windows-20261030.json)
records matching profile inputs, compiler/SDK, native reports, original/matrix
receipt hashes and retained executable hashes. Full suites, other CLI matrices,
M0, Linux, DLL, Windows isolation, packaging, allocator instrumentation and timing
benchmarks were not rerun.

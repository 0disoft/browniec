# UTF-8 validation from guest source

This document records the named-array checkpoint. The
[direct-call successor](m2-array-utf8-calls.md) now also accepts array-result calls.
The original verification counts below remain historical for that checkpoint. The
later [range successor](m2-array-utf8-ranges.md) accepts explicit literal ranges
over the same named arrays; statements below about unavailable guest ranges
describe this checkpoint only.

`text::valid_utf8(bytes)` returns a `bool` for one visible, named `u8[N]`
array, including helper locals, immutable by-value parameters and named array
results. This qualified intrinsic uses the design baseline's spelling. It needs
no import declaration in the experimental grammar. It does not reserve bare
`text` or `valid_utf8` identifiers: ordinary bindings and functions retain their
existing lookup behavior. Whitespace and comments may separate its tokens.

```c
module main;
fn i32 main() {
    var u8[3] bytes = [128; 3];
    bytes[0] = 234;
    bytes[1] = 176;
    if (text::valid_utf8(bytes)) { return 42; }
    return 0;
}
```

The example encodes U+AC00. An executable copy is in
[`examples/array-utf8.brc`](../../examples/array-utf8.brc).

## Type, evaluation and ownership rules

Only a visible array name is accepted as the single argument. Other element
types, scalars, record roots, unknown/out-of-scope names and extra arguments fail
compilation. There is no implicit integer conversion of the bool result. Array
literals were added by the [literal successor](m2-array-utf8-literals.md).
Indexing, parenthesized array expressions and `ref` arguments remain outside
this slice. Direct array-result calls were initially excluded and are
now covered by the successor above. No general module resolver, text value or
guest Buffer API is introduced.

The frontend checks the current function and exact u8 catalog entry, then emits
one opcode 51 with the offset of `text`. It introduces no array copy, catalog
entry, owner or guest call. The independent verifier and existing VM remain
unchanged; see the [metered VM contract](m2-array-utf8.md). A parameter's existing
by-value call copy is separate from the predicate itself.

Validation neither moves nor modifies the array. Later reads, writes, copies,
assignment and scope cleanup keep their existing behavior. Each executed call
reads current initialized bytes without a cached result. Normal bool operators,
short circuiting, conditions, scalar function arguments and bool returns compose
with the predicate. Invalid UTF-8 is `false`, not a trap; NUL is valid UTF-8.

## Work bounds and discovery

Array length remains 1..4,096. Each executed scan prepays `33 + 4*N` Fuel before
reading bytes, for valid and invalid input alike. Source lowering adds no scan
charge beyond that instruction. Work is O(N) with O(1) scan scratch space, no
payload copy and no new owner. These are code-path bounds, not timing or process
memory measurements. The VM's existing arena preparation and all other
instructions retain their own charges.

The six-instruction source program used for exact-Fuel checks fills an array,
stores the predicate result and returns 42. Its total cost with an N-byte arena
is `144 + 6*N`; the CLI's existing 65,536-byte arena makes it `65,680 + 5*N`.
One unit short fails. A separate budget ending just before the scan completes
reports a Fuel error at the qualified intrinsic's byte offset. Reusing the
compiled program after failure succeeds with adequate Fuel.

Version JSON adds `array_utf8_predicate: true`. Existing result profiles and
CLI command grammar stay unchanged. The flag describes this named-array subset;
`restricted` and `embed` remain false.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development` and
repeat with `--profile release`. Each selection runs 18 native groups: five new
source groups, six existing UTF-8 backend groups, three array-length groups and
four direct array-call-read groups. The CLI selection runs 142 new source cases,
106 existing array-call-read cases and eight scalar/array/record/Buffer sentinels,
for 256 CLI invocations per profile with an empty runtime tool PATH.

Coverage includes actual UTF-8 byte boundaries and malformed sequences,
mutation between scans, exact arena capacity without a copy, helper parameters,
recursion, loop cleanup, name compatibility, unsupported argument forms and
exact/one-short Fuel at lengths 1, 4 and 4,096. The
[Windows evidence](../evidence/m2-array-utf8-source-windows-20261029.json) records
matching input hashes, compiler/SDK identities, native outcomes, CLI report
hashes and both retained verified CLI binaries. Earlier evidence remains scoped
to its original inputs.

Full suites, Buffer lifecycle/Provider probes, M0, Linux, DLL embedding, Windows
isolation, packaging, allocation instrumentation and timing benchmarks are not
part of this selection. Buffer/text integration and views remain future work. Direct call arguments
are covered by the successor above.

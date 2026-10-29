# UTF-8 validation of repeated-byte literals

Implementation: `3d569fa`.

`text::valid_utf8([value; N])` accepts a repeated-byte array directly. The filler
has exact `u8` context and N is an integer literal in 1..4,096, matching existing
fixed-array declarations. Integer literals infer u8; a typed wider integer or
bool is not implicitly converted. This extends the
[named-array](m2-array-utf8-source.md) and [call-result](m2-array-utf8-calls.md)
predicate without adding a general aggregate expression grammar.

```c
module main;
fn i32 main() {
    if (text::valid_utf8([65; 16])) { return 42; }
    return 0;
}
```

An executable copy is in
[`examples/array-utf8-literals.brc`](../../examples/array-utf8-literals.brc).

## Evaluation and ownership

The compiler evaluates the filler once, before creating the immutable anonymous
array. That evaluation uses the ordinary expression path, including calls,
switch arms, checked arithmetic, short circuiting and control-flow exits.
After validating both closing delimiters, it emits AINIT, opcode 51 and ADROP.
The scan and immediate drop share the same helper as direct call-result scans.
No guest expression runs between publication, scan and drop.

The literal is absent from lexical names and runtime owners during filler
evaluation. A filler `return`, `?`, `break` or `continue` therefore cleans only
already-live enclosing values. A short-circuited predicate does not evaluate
the filler, initialize storage or scan. Previously evaluated outer argument
captures retain their existing lifetime and effects.

Nested temporary fillers release their own storage before the outer AINIT:
`text::valid_utf8([choose(text::valid_utf8([0;1]));1])` needs one payload byte
when choose returns a u8, not two. Repeated successful literal scans also reuse
the same live payload capacity across loop iterations. Each literal still
occupies one static array catalog entry, with the existing sixteen-site limit.

All initialized bytes are scanned. Valid UTF-8 returns true and invalid input
returns false; NUL is valid. The literal introduces one owner and N initialized
bytes, with no extra payload copy for validation. This is an owned temporary,
not a borrowed view. Named arguments retain their existing owner unchanged.

## Fuel and discovery

No opcode, verifier, VM or existing Fuel price changes. AINIT retains its
initialization charge, the scan prepays `33 + 4*N`, and ADROP retains its normal
charge. The simple literal program that stores the predicate bool and returns
42 costs exactly `144 + 6*N` with an N-byte arena, or `65,680 + 5*N` with the
CLI arena. This equals the equivalent named-array program. More complex fillers
pay their ordinary expression and call costs before array initialization.

Version JSON adds `array_utf8_literals: true`. Existing result profiles,
command grammar and `restricted`/`embed` availability are unchanged. General
parenthesized array expressions, slices, borrowed views, module resolution and
Buffer/text ownership remain outside this slice.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --literals`
and repeat with `--profile release`. Development and release each passed 13 native groups:
four new literal groups, five named-source groups and four direct-call groups.
Each also passed 130 literal CLI cases, 142 named-source cases, 100 direct-call cases
and eight sentinels, for 380 CLI invocations per profile without runtime tools.

Coverage includes one-time evaluation at N=4,096, exact/one-short Fuel at lengths
1/4/4,096 for valid and invalid bytes, scan-offset errors, exact capacity, nested
temporary reuse, mixed record captures, all four filler exit forms, short
circuiting, missing-ADROP verifier rejection, and the sixteen/seventeen static
site boundary. Invalid filler types, byte values, lengths and delimiters fail
honestly. The [Windows evidence](../evidence/m2-array-utf8-literals-windows-20261030.json)
records input hashes, native outcomes, CLI receipts and both retained verified
executables. Earlier receipts remain historical for their exact inputs.

Unchanged backend/array-call-read suites, full suites, Buffer lifecycle/Provider
probes, M0, Linux, DLL embedding, Windows isolation, packaging, allocation
instrumentation and timing benchmarks were not rerun. Work and capacity checks
do not constitute a timing or process-memory measurement.

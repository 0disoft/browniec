# UTF-8 validation of direct array call results

The [literal successor](m2-array-utf8-literals.md) also accepts repeated-byte
array literals. This document records the original call-result checkpoint.

`text::valid_utf8(make(...))` now accepts a direct function call returning
`u8[N]`. Forward declarations and ordinary call arguments work, including
nested calls, array/record captures and control flow inside arguments. The
[named-array predicate](m2-array-utf8-source.md) keeps its existing behavior.

```c
module main;
fn u8[1] make() { return [65; 1]; }
fn i32 main() {
    if (text::valid_utf8(make())) { return 42; }
    return 0;
}
```

See also the [multibyte example](../../examples/array-utf8-calls.brc).

## Lowering and lifetime

The compiler resolves the callee, rejects local shadowing and requires an exact
u8-array return shape before reserving one anonymous immutable result site.
The existing CALL/ARET path evaluates arguments once in source order, releases
argument captures, then transfers the returned owner without copying its payload.
The result remains absent from lexical names while arguments are evaluated.

After CALL, the compiler validates the outer closing parenthesis, emits opcode
51 and immediately emits ADROP for that same result site. No guest expression
runs between CALL, scan and drop. This path therefore needs no lexical capture
for the result itself. Earlier enclosing captures retain their normal lifetime.

An argument's `return`, `break`, `continue` or `?` follows existing mixed cleanup
rules before the pending call executes. No result has been published at that
point. Short-circuited predicates execute neither CALL nor scan. Failures keep
their normal outcomes and do not replay earlier argument effects.

The bool can outlive the temporary array. Repeated successful predicates reuse
payload space, including in a loop: a one-byte returned array needs one live
payload byte, rather than one per iteration. A named temporary and the equivalent
direct expression have the same instruction and catalog-entry counts. The
direct form drops immediately instead of retaining the result until scope exit.
Removing its ADROP is independently rejected by the existing verifier.

## Bounds, Fuel and discovery

No VM, verifier, opcode, transfer cost or scan price changes. The existing scan
charge remains `33 + 4*N`; ordinary calls, argument copies and returns keep their
own costs. For the tested no-argument maker returning a repeated-byte array,
followed by one predicate and an unconditional return of 42, total Fuel is
`210 + 6*N` with an N-byte arena, or `65,746 + 5*N` with the CLI arena.
Exact Fuel succeeds; one less fails. A scan-short budget reports the offset of
`text`, while call/argument failures retain their own offsets.

Version JSON adds `array_utf8_call_results: true` alongside the existing
`array_utf8_predicate` flag. Result profiles and command grammar are unchanged.
Lengths remain 1..4,096, with the existing sixteen static array sites, thirty-two
frames, thirty-two call sites and instruction/register ceilings. A direct call
requires a static destination just like a named array result. Invalid UTF-8 is
false, and NUL remains valid. No normalization or result cache is introduced.

Unknown/scalar/record/non-u8-array callees, local callee shadowing, wrong arity
and extra outer arguments fail compilation. Array literals were added by the
successor above. Indexing the call result inside this argument, parenthesized
aggregate expressions, slices, views,
general module resolution and Buffer/text ownership remain outside this slice.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --call-results`
and repeat with `--profile release`. Development and release each passed 13 native groups:
four new call-result groups, five named-source groups and four array-call-read
groups. Each also passed 100 new call-result CLI cases, 142 named-source cases, 106 existing
array-call-read cases and eight sentinels: 356 CLI invocations with no runtime
tool PATH. One old named-source rejection now uses a scalar maker, since u8-array
makers are accepted by this successor.

The [Windows evidence](../evidence/m2-array-utf8-calls-windows-20261030.json)
records matching input hashes, native outcomes, CLI receipt hashes, compiler/SDK
identities and both retained executable hashes. New tests cover valid/invalid
results, multibyte bytes, exact capacity, loop reuse, nested and mixed calls,
pending-call exits, short circuiting, verifier rejection without cleanup and
exact/short Fuel at lengths 1, 4 and 4,096. Earlier receipts remain historical
for their original inputs. The unchanged VM/backend suites are not rerun here.

Full suites, Buffer lifecycle/Provider probes, M0, Linux, DLL embedding, Windows
isolation, packaging, allocation instrumentation and timing benchmarks were not
run. Payload and Fuel bounds are structural checks, not performance measurements.

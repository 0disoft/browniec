# Static byte-view equality

Date: 2026-11-05. This closes the private EQUAL operand gap identified by the
[literal decoder](literal-source.md), before guest text/source integration.

## Semantics and proof

The accepted design package's `docs/09-standard-library-and-cli.md` specifies
`text::equal(ref u8[] a, ref u8[] b)` as byte equality. Its positive text example
explicitly obtains `text::bytes(word)` before comparing with a byte literal.
The existing private opcode 73 only admitted text sites, preventing arbitrary
byte literals from using the same native equality operation.

Image-aware proof and execution now admit live immutable byte or text sites to
EQUAL, including mixed backing kinds. Text sites have already passed their
existing actual-image UTF-8/range checks; raw byte sites need no UTF-8 validation.
EQUAL produces only a bool and cannot manufacture text, mutable access, a loan,
an owner, or a returned receipt. READ/LEN still require bytes; BYTES still requires
text. Existing exact-image, function, liveness, definition, reserved-operand and
single-assignment destination checks are unchanged. Unknown kind tags reject.

This is a private IR extension. It does not implement guest argument checking or
allow implicit source `ref str` to `ref u8[]` conversion. Source lowering must
still implement the accepted byte-view signature and explicit `text::bytes`.
Ordinary bare admission, public syntax and version capabilities remain gated.

## Execution and cost

Both spans refer to the same retained immutable Program image. Equality reads
only their selected byte ranges, including NUL and invalid/incomplete UTF-8, and
uses existing byte equality. There is no new allocation or guest backing copy.
The exact charge remains **17 + left length + right length**, including driver
dispatch. Both complete lengths are prepaid even for immediate inequality or
unequal lengths. Insufficient Fuel publishes no result. This is not a
constant-time equality promise or a work-budgeted resumable operation.

## Focused verification

`python -B tools/verify-static-execution.py --profile development --selection
statics` selects the changed Static proof/execution and retained-Program suites;
repeat with `--profile release`. The default `--selection all` retains the prior
larger returned-CALL and source regression selection. Receipts are now isolated
by selection under `build/static-execution/<profile>/<selection>/`.

Five added native groups cover actual invalid UTF-8/NUL comparisons, equal,
unequal, empty and shorter spans, mixed kinds, exact/one-short/one-more invocation
Fuel, complete precharge before register publication, and rejected unknown,
not-yet-defined and closed operands. Existing text, image, branch, backedge,
return, cleanup, backing and admission checks remain in the selected 27 groups.

Windows development and release each passed all **27 native groups**, including
the five added groups. Both runs used the same 129 input hashes and 220-file
test-discovery identity; all 122 production files are LF and locked LF mirrors
passed. No compiler/stack overrides or historical result reuse were used.
See [focused Windows evidence](../evidence/static-byte-equality-windows-20261105.json).
Full profiles, general stack/RAM, allocator/OOM, timing, Linux, restricted delivery
and C ABI/packaging were not verified by this focused selection.
The [native source compiler successor](literal-compiler.md) now lowers immediate
byte/text projections. The [typed binding successor](static-bindings.md) now
supplies native byte/text locals and aliases. The [source equality successor](static-equality-source.md)
now enforces the byte-view signature and lowers immutable arguments through
EQUAL. General runtime/range views, Static CALL/return receipts and ordinary
public admission remain next. The complete accepted implementation remains open.

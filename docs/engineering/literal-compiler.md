# Compiling source literals into retained images

Date: 2026-11-05. This connects the [literal decoder](literal-source.md) to real
source execution through the existing [retained-image VM](static-execution.md).
It is a native compiler entry and immediate-expression increment, not public CLI
promotion, first-class Static locals, or complete text APIs.

## Source-to-image ownership

`compiler::compile_image(source, image_limit)` returns the owning native
`program_image::Program`. The compiler validates complete source UTF-8 and scans
bounded lexer tokens into a staged image builder. Kind-specific cooked payloads
are interned; original token bounds, literal IDs, kinds and cooked lengths form
a compiler-only index. A failure anywhere in collection leaves its caller's
builder byte-for-byte unchanged. No index contains a view into decoding scratch.

The source lowerer borrows this index through its signature context. Ordinary
`compile` and returned-origin analysis instead use a disabled index, preserving
their existing gates. The IR layout has no new compiler-scratch fields. Only
successful lowering freezes the exact used payload prefix. Retention then runs
independent code/image/scalar/CFG/owner/loan proof against that actual owning
image; the index is neither retained authority nor an execution proof.

Source/syntax/type/compile-limit and independent IR errors retain the Code error
branch. Image quota/allocation/provider failures retain Literal errors. No partial
Program escapes. `image_limit` bounds logical image metadata plus payload, not
complete compiler/Program/process memory. Engine accounting remains separate.

## Implemented expressions

The native constructor now accepts immediate byte reads/lengths and explicit
text-literal byte projections, for example:

```c
module main;
fn i32 main() { return b"\x2A"[0] as i32; }
```

`b"...".len`, `text::bytes("...")[index]` and `text::bytes("...").len` use the same
image. Reads produce u8; lengths produce usize byte counts, not Unicode scalar
counts. Indices use ordinary expressions with exact usize type, including
scalar CALLs. Existing explicit scalar widening remains mandatory where needed.
Empty byte literals are valid. Text validation applies to complete cooked UTF-8;
arbitrary escaped bytes remain byte-kind data.

Literal operands and their literal-only byte conversions are pure immutable
descriptors. Lowering materializes their runtime Static sites after the index
expression, so an early index exit has no hidden runtime alias to unwind.
OPEN/BYTES/READ-or-LEN/CLOSE use existing VM dispatch, actual image spans and
frame-local liveness. Closing the text site preserves its independent byte view.
No bytes enter the invocation's array arena; loop reentry uses the same verified
Static definition. The immutable Program remains alive for the whole invocation.

Both source occurrence count and globally allocated Static definitions are
bounded to sixteen at this checkpoint. A text byte projection uses two sites.
Builder helpers derive allocation from actual emitted code, so speculative pure
for-post rewinding also rewinds site allocation. The compiler now clears all
bytes of that discarded region before ordinary body instructions reuse it;
otherwise OPEN's nonzero range bytes could survive in a scalar instruction's
reserved fields. Source 4096 bytes, 1024 tokens,
128 registers, 256 instructions, function/frame limits and existing prices remain
unchanged. These are narrow implementation limits, not full-profile C05 adoption.

The one-byte example costs exactly **39** units after existing invocation
entry/leave reserves. Its retained image charge is **577 = 576 + 1**; a 576 image
limit rejects as image quota. Reads still precharge before runtime Bounds checks.
These are logical prices/charges, not native stack/RAM/timing measurements.

## Verification and remaining integration

`tools/verify-literal-compiler.py --profile development --phase native` runs the
new source cases and affected Static VM/core/function regressions. Repeat with
`--profile release`. `--phase cli` builds the standalone artifact and runs the
existing 52 literal and 36 source-byte cases with tool-free runtime PATH. Native
phases can run independently; serialize CLI builds across profiles because they
share the compiler's output artifact. The default `--phase all` runs both.

Eight new groups cover actual source execution, exact/one-short/one-more Fuel,
computed CALL indices, while/for-post reentry, arbitrary bytes, Unicode/byte lengths,
empty data, spelling deduplication, image quota versus source/type errors,
precharge versus Bounds, atomic collection rollback, both sixteen-site limits,
and ordinary compilation gates. Windows development and release each passed
all **32 native groups** and **88 tool-free CLI cases** on 134 matching final
inputs and the same 221-file test-discovery identity. All 124 production files
are LF and both locked LF mirrors passed. No compiler/stack overrides or
historical result reuse were used. The [focused Windows evidence](../evidence/literal-compiler-windows-20261105.json)
records exact selections and compiler/input/report/artifact identities.

Earlier development native/CLI and release CLI runs before the speculative-post
correction are excluded. The earlier release native run was intentionally stopped
for that correction and is not counted. Final runs include the classic-for
regression and follow final input capture. Full profiles, general stack/RAM,
allocator/OOM, timing, Linux, restrictions and C ABI/packaging were not verified.

Typed Static locals/aliases and ref str bindings, general view expressions,
byte-view text::equal argument lowering, Static CALL/return origin receipts and
ordinary public admission remain unfinished. Existing returned-reference source
declaration gates also apply to this constructor. Buffer/input text, Engine/
Instance/step, host exchange, restrictions, ABI and the complete inventory remain
open. No public capability flag is promoted by this native source increment.

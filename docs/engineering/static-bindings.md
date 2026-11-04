# Typed Static source bindings

Date: 2026-11-05. Native `compiler::compile_image` now lowers immutable byte and
validated text bindings through the retained Program image. This implements the
local/alias successor to [Static ALIAS](static-alias.md); ordinary public literal
and borrowed-result admission remain separate work.

## Accepted native source

```brownie
let ref u8[] bytes = b"*";
let ref u8[] alias = bytes;
let ref str word = "한";
let ref str another = ref word;
let ref u8[] encoded = text::bytes(another);
let usize length = encoded.len;
```

A view alias may use its existing name directly or an explicit `ref` prefix.
Byte bindings admit byte literal views, existing byte views and explicit
`text::bytes` conversion of validated text views. Text bindings admit validated
text literals and text aliases. Parentheses preserve the selected kind. There is
no byte-to-text coercion. `ref mut`, rebinding, stores, direct text indexing and
direct text length are rejected. Obtain bytes explicitly for byte indexing and
length; these are byte counts, not Unicode scalar/grapheme counts.

The new name is absent during initialization. Existing duplicate-name and
lexical visibility rules remain. Bounded lookahead separates Static declarations
from existing rooted, formal and returned runtime slices. Compiler-only local
encodings 192..207 and 208..223 identify byte/text sites respectively; they never
become scalar cells, mutable owner tickets or authenticated handles.

## Cleanup and execution

Literal definitions own no guest array allocation. Same-kind aliases use ALIAS;
text conversion uses BYTES, preserving the source view. Owned conversion
intermediates close promptly. Reverse lexical cleanup now also closes Static
bindings on normal block exits, scalar/array/record returns, value-arm exits,
propagation, break and continue. Aggregate result cleanup uses the same canonical
per-binding finalizer while preserving the selected returned owner.

An owned projected byte view joins the hidden lexical suffix before its computed
index runs. Early exits therefore close that view along with exactly the scopes
they leave. A simple `.len` has no guest expression/exit; it avoids the hidden
binding and full local-table snapshot. Existing immediate literal projection
order and prices are unchanged. Normal return still requires an empty Static
live set under independent image-aware CFG proof.

Native entry uses the existing canonical driver and exact retained image.
All Static definitions share the sixteen-site cap, including closed sites;
loops reenter an existing emitted site. Source occurrences, source bytes,
registers, instructions, frames and aggregate backing retain their existing
bounds. OPEN/BYTES/ALIAS/LEN cost 17, READ 18 and CLOSE 1 including dispatch.
The one-byte binding-plus-alias example costs 57 plus existing entry/leave
reserves, retains one payload byte with image quota 577, and needs zero guest
array backing. Fuel is abstract work, not a latency or stack-size bound.

## Verification and remaining work

Run `python -B tools/verify-literal-compiler.py --profile development --selection
bindings` and repeat with `--profile release`. Native and CLI phases can be
selected separately with `--phase native` or `--phase cli`; serialize CLI builds.
This selects the new binding cases, existing literal lowering and the image text
dispatch regression, plus standalone literal/lexical CLI gates.

Windows development and release each passed 16 native groups: seven new binding
groups, eight existing literal compiler groups and the image text dispatch
regression. Both standalone CLIs each passed 88 tool-free literal/lexical cases.
All four phase snapshots match on 137 inputs and the same 223-file test-discovery
identity. All 125 production modules are LF and both locked LF mirrors passed.
No compiler/stack override or historical-result reuse was used.

The [focused Windows evidence](../evidence/static-bindings-windows-20261105.json)
records source/compiler/report/artifact identities and exact selections. Earlier
smoke, the initial fixture syntax probe and the deliberately stopped
pre-correction native run are excluded. The fixture correction checks invisible
self-initialization through the new text declaration path rather than expecting
a type error from the legacy byte-reference grammar's missing `ref` prefix.

Remaining: general Static range/view expressions and byte-view `text::equal`
source lowering, Static CALL actuals and returned origin/lifetime receipts,
ordinary public admission, Buffer/input text and complete Engine/Instance
accounting. Full profiles, general native stack/RAM/allocator/timing, Linux,
restricted Windows delivery and C ABI/packaging are not established here. The
complete inventory and objective remain open.

# Compiler source stages

The private source-lowering foundations now have explicit continuations. The
owning compiler collects immutable module bytes through `source_context_work`;
ordinary lexer, literal-decoder, scoped-name and primitive/wrapper-type calls
drain their corresponding continuations synchronously. The complete proof
continues through the [preceding proof kernels](runtime-authority-metadata-stages.md#compiler-proof-stages).
This remains partial lowering, rather than a resumable compiler coordinator.
Untyped declaration/signature passes now compose the children below; typed/value
signature preparation still follows its original synchronous path.

## Implemented boundaries

Each advance admits one fresh 4096-unit logical allowance. A partially used
allowance defers without changing the continuation or meter. Child work runs
in separate advances; unused credit cannot accumulate into a later scan.

| Kernel | Work in one stage |
| --- | --- |
| `source_context_work` | Copy at most 64 immutable source bytes, pack one import/symbol row, or validate one sealed name of at most 64 bytes. |
| `source_utf8_work` | Validate a scalar-aligned cut of at most 259 bytes. |
| `literal_source_work` | Decode at most 16 scalar/escape transitions; raw and cooked UTF-8 checks use separate cuts. |
| `literal_scan_work` | Scan a token without constructing the decoder's 4096-byte cooked bank. |
| `lexer_work` | At most 16 byte/scan transitions, or one separately resumed literal-scanner stage. Qualified-name lookahead has its own continuation. |
| `source_context_check_work` | Validate one shape/metadata row or at most 64 bytes of a copyable, possibly forged name. |
| `source_name_work` | Resume context authentication, query tokenization, one alias/declaration row, or at most 64 spelling comparisons. |
| `type_parse_work` | One primitive/wrapper grammar transition or a separately resumed lexer stage. |
| `signature_type_work` | One array/borrow/nominal annotation transition, a primitive/name/token child, or an explicit unscoped nominal discovery request. |
| `declaration_skip_work` | One struct field/body-brace transition or lexical child, preserving the existing sixteen-field and depth-33 limits. |
| `struct_locate_work` | A single-source declaration/header/skip transition or at most 64 nominal spelling comparisons. |
| `signature_parse_work` | One function/parameter metadata transition or one separately resumed annotation/discovery/name/body child; duplicate comparisons use at most 64 bytes. |
| `source_state_work` | A context-authentication child, one module/import row, or fixed scoped-lexer preparation. |
| `function_scan_work` | One single-source/indexed declaration transition or one signature/skip/context/token child; publish only the complete Table. |
| `record_fields_work` | One source-state/type/name child, field metadata transition or at most 64 nominal/duplicate-name comparisons. |
| `struct_scan_work` | One declaration/field/layout child or declaration-name comparison; all declaration syntax is checked before type resolution. |
| `struct_layout_work` (reused) | Fixed scratch initialization, one sixteen-slot row, at most sixteen dependency visits, or one node of at most sixteen fields. |

The owner pins the exact source, Index/context and query across advances.
States are copyable analysis scratch, not independent authority to execute or
accept changed inputs. Initial fixed scratch construction is outside these
advance contracts. Logical entry/transition bounds are not instrumented scalar
field, byte, CPU or wall-clock measurements.

## Compatibility and evidence

Raw collection, decoder, token scanner, context validity, name binder and type
grammar remain comparison paths. Name lookup preserves the first matching
alias/declaration, cross-module visibility and the first-private-match result;
malformed queries still return the existing absent sentinel. Primitive/wrapper
parsing preserves exact tags, syntax/type/lexical error order and the observable
lexer state on failure, including qualified lookahead. Decoder checks preserve
escape-before-encoding diagnostics and exact source offsets.

Lexer and primitive-type compatibility adapters retain the historical raw path
for sources larger than this private 4096-byte profile. Public compilation still
uses its existing admission gates and remains synchronous. No public Pending
compile, cancellation protocol, time bound or peak-stack improvement follows.

The [source-stage evidence](../evidence/runtime-compiler-source-windows-20261111.json)
records the frozen unit receipts, exact integrated owner/test/input hashes,
both-profile adapter checks and complete Engine images on default stacks.
The combined adapter suite exercises 18 native groups per profile, including
4096-byte comments/names, forged contexts, insufficient-room deferral, terminal
idempotence, visibility ordering and exact raw diagnostics. Historical focused
receipts describe their original snapshots, rather than the final whole tree.

Integrated Engine development/O2 pass default 1MiB/4KiB stacks, exact Fuel/
output/error, compile/reuse, pins/moves, terminal/cancel and zero SDK heap at
exit. All 321 Engine input hashes match integration `c6e1cf8`; all 313 production
modules retain LF. Transport retains 36 bindings and 51 layouts. A recursive
bijective comparison of 176 referenced aggregate graphs confirms unchanged
structure despite generated C identifier renumbering. Core/Cursor/Machine
remain 172400/1184/1792 bytes.

## Untyped declaration and signature integration

Owning `functions::scan` / `scan_reference_returns` and scoped/input signature
adapters now drain `function_scan_work`. Untyped single-source and immutable
module inputs retain exact entry selection, record order, pub/import resolution,
parameter duplicates and reference-return candidates. Raw signature/single/index
scans remain independent ordering oracles. The unscoped compatibility adapter
keeps the raw fallback above 4096 bytes; typed/value signature catalogs remain
on their original path.

Every declaration/signature child resumes separately, including unscoped nominal
discovery. Struct/function skipping preserves early-match discovery and exactly
the previous brace/field limits. Private partial candidate metadata and observed
lexer failure state also match the raw signature oracle. A fixed signature
scratch copy bridges the compiler's sibling mutable-loan restriction without
replaying source or banking credits. This fixed framing is part of the logical
allowance, not an instrumented copy/CPU guarantee.

The [signature evidence](../evidence/runtime-compiler-signatures-windows-20261111.json)
records six new kernels with seventeen frozen groups per profile and six current
integrated groups per profile. Engine development/O2 pass default 1MiB/4KiB
stacks, exact Fuel/output/errors, compile/reuse, moves/pins, terminal/cancel and
zero SDK heap at exit. All 327 Engine inputs match integration `93f10db`; all 319
production modules retain LF. The 36 typed bindings/51 layouts and 176 referenced
aggregate graphs remain structurally equivalent after generated identifier
renumbering. Core/Cursor/Machine remain 172400/1184/1792 bytes. The preceding
foundation receipts continue to describe their own frozen snapshots.

## Struct declaration, field and layout integration

Owning `struct_source::scan` and `scan_scoped` now drain `struct_scan_work`.
The first pass retains declaration-name/body spans and validates every member
syntax (and single-source function skip) before any field type is resolved.
The second pass resolves nominal/scalar fields and duplicate field names; the
existing layout kernel then checks the complete catalog and dependency graph.
Only the finished Table is available through `prepared`.

Preserve raw quirks as well as successful tables: single-source layout errors
point to the first declaration, while scoped errors point to the first failing
root. A scoped packed span may be only a prefix of the actual lexer token;
primitive words must still query that metadata. The primitive lookup shortcut
is restricted to syntax-checked unscoped declaration names. Fixed field-frame/
catalog copies bridge sibling-loan restrictions within logical framing; they
do not establish instrumented byte/CPU bounds.

The [record evidence](../evidence/runtime-compiler-records-windows-20261111.json)
records two new kernels, six frozen groups/profile and six current owning adapter
groups/profile. Engine development/O2 pass default 1MiB/4KiB stacks and zero exit
SDK heap. All 329 Engine inputs match `da8fe2c`; 321 production modules retain LF.
Transport keeps 36 bindings/51 layouts and equivalent 176 aggregate graphs;
Core/Cursor/Machine remain 172400/1184/1792 bytes. Prior source/signature evidence
continues to describe its own frozen checkpoints.

## Required remaining lowering work

The following semantic work remains atomic, even where its helpers drain stages:

1. Literal collection, image interning and final builder publication/allocation.
2. Typed/value function signatures and catalog preparation.
3. Body-derived slice origin analysis, including its seventeen rounds and
   expression/atom/CALL/name/control-flow traversal.
4. Array/record parameter/result catalog preparation.
5. Function bodies, statements, operands, expressions and recursive control
   lowering. Use explicit continuations, not a metered whole `body` call.
6. Final entry-call restrictions and output normalization, plus raw context/
   nominal discovery outside the newly staged owners.

Keep exact diagnostics/emitted IR, immutable originals and final-only publication
while replacing these calls in small verified commits. The current authorization
covers this lowering work; broader completion stays paused. Public R02-R05
closure, post-proof cache planning, admission allocations and unrelated runtime
discovery remain separate work. Local only; no push, release or deployment.

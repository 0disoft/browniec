# Compiler source stages

The private source-lowering foundations now have explicit continuations. The
owning compiler collects immutable module bytes through `source_context_work`;
ordinary lexer, literal-decoder, scoped-name and primitive/wrapper-type calls
drain their corresponding continuations synchronously. The complete proof
continues through the [preceding proof kernels](runtime-authority-metadata-stages.md#compiler-proof-stages).
This is a partial lowering checkpoint, not a resumable compiler coordinator.

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

## Required remaining lowering work

The following calls still perform semantic scans or recursive lowering
atomically, even when their token/type/name helpers drain private stages:

1. Function signatures and declaration iteration (`functions::scan_mode` and
   `scan_index`), parameter duplicate checks, struct/body skipping and value
   signature/catalog preparation.
2. Struct members, nominal resolution, layouts, duplicate/cycle checks and
   unscoped declaration discovery (`struct_source`).
3. Literal collection, image interning and final builder publication.
4. Body-derived slice origin analysis, including its seventeen rounds and
   expression/atom/CALL/name/control-flow traversal.
5. Array/record parameter/result catalog preparation.
6. Function bodies, statements, operands, expressions and recursive control
   lowering. These need explicit continuations; charging one whole `body` call
   as a stage would not bound it.
7. Final entry-call restrictions and output return normalization, plus repeated
   context validation/state setup outside the new lookup kernel.

Keep exact diagnostics and emitted IR, immutable originals and final-only
publication while replacing these calls in small separately verified commits.
The current authorization covers this lowering work; the broader completion
goal remains paused. Public R02-R05 closure, post-proof cache planning,
admission allocations and unrelated runtime discovery remain separate work.
All changes and evidence here are local; no push, release or deployment.

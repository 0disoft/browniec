# Module-aware source and typed declaration context

Date: 2026-11-05. This L01 compiler increment extends the sealed
[module index](module-index.md) and retained [entry selection](module-entry.md).
It supplies actual scoped function signatures and nominal record catalogs.
Body lowering, executable multi-module IR and public project admission remain
subsequent work.

## Exact source bytes and compact lookup scratch

`source_context::collect` reads the exact immutable Index and creates bounded
copyable compiler scratch: up to 4096 original source bytes, 16 file ends,
64 direct alias words, 16 function-name words and 32 record-name words. Files
are copied in snapshot order without inserting separators, removing BOMs or
renaming identifiers. Original file identity is implicit in the checked file
ends. Declaration ordinals agree with the index's source/declaration order.

Words encode 13-bit absolute start/end offsets and either one `pub` bit or a
four-bit alias target. The four arrays contain 512 bytes of words, plus four
usize counters (544 logical bytes on the 64-bit target). This is compiler scratch,
not a complete compiler/process RAM measurement. It does not add VM frame, site,
backing or runtime ticket storage. Numeric packing checks bounds before at most
30 bit steps; no unsupported SDK narrowing operation or unchecked integer cast
is used.

All metadata queries validate counts, file ends, word flags, target IDs, name
bounds and same-file identifier spans before indexing. Query spans cannot cross
a file boundary. Lookup selects the caller's own module or one explicitly bound
alias and requires `pub` across module boundaries. A self alias retains local
access. Neither canonical module names nor transitive aliases imply a lookup.
No graph recursion, path search, builtin provider or host grant is introduced.

These public structs are caller-mutable candidates, not retained executable
proofs. A context alone does not authenticate arbitrary bytes against an Entry.
Executable admission must reconstruct its input internally from the exact private
retained Index, complete body/type/ownership checks and independently verify IR.
The scratch factory and signature APIs do not replace those obligations.

## File-fenced tokenization

`lexer::scoped` opts into an original-byte file fence using one packed u32 in
lexer State. Snapshots preserve it. A BOM is legal at that file's original start;
a line comment ending at that file's EOF cannot consume the next source. Scanning
stops at the exact fence even when raw copied bytes contain the following file.
Invalid fences/cursors fail before source reads. Ordinary `lexer::empty` keeps
the established single-source tokenization.

In scoped mode `alias::name` is token kind 5, distinct from plain identifier kind
2. Whitespace/comments between segments retain their original spelling and span.
Plain declaration names, local binders and record field labels still require kind
2. This avoids rewriting shadowing locals/labels or accepting a qualified binder.
An explicit alias called `text` selects that module; without one, `text::bytes`
and `text::equal` keep the existing builtin punctuation path. Extra qualifier
segments cannot silently become transitive lookup.

## Typed function and record candidates

`functions::scan_scoped` takes an explicit retained Entry and module context. It
reuses the existing scalar/wrapper/array/slice/record signature parser, maps record
results/parameters through scoped nominal lookup and selects the exact requested
function ordinal. Other functions called `main` remain ordinary helpers in this
mode. The legacy scanner keeps its existing fixed `module main`/entry convention.

`struct_source::scan_scoped` constructs the nominal catalog using the same global
record ordinals and scoped member types. Complete existing layout validation
rejects invalid fields, overflow, excessive depth and cycles, including cycles
through imports. `locate_scoped` resolves a name or revisits a selected record
without merging different modules' same-spelled types.

The existing expression/constructor compiler has not yet adopted these APIs. A
valid signature/catalog does not prove a body, a returned reference, a selected
entry's full IR or executable capability. No public syntax/profile flag, opcode,
Fuel price, CLI limit, source capacity or guest ABI is promoted by this increment.

## Focused verification and next integration

```text
python -B tools/verify-static-execution.py --profile development --selection source-context
python -B tools/verify-static-execution.py --profile release --selection source-context
```

The selection runs scoped-context groups, retained entry regressions and existing
function/lexer compatibility groups. It checks exact file bytes and independent
BOM/comment/EOF handling; local/private/exported function lookup; duplicate nominal
spellings; qualified signature/member types; cross-module record cycles; rejected
qualified field binders; explicit text aliases; and forged metadata/cross-file
queries. Existing single-source function execution and lexical compatibility are
part of the same focused native selection.

Next use the context throughout expression, record constructor/field and returned-
reference lowering, construct the selected complete IR, and retain/run it with
its exact source owner. Preserve independent Program/ownership admission and
source-local diagnostics. Public projects and filesystem/policy loading remain
separate accepted obligations.

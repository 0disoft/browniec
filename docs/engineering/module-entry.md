# Retained zero-argument i32 entry selection

Date: 2026-11-05. This L01 increment builds on the sealed
[module index](module-index.md). It proves the selected public function's exact
first-profile signature and retains its source owner. It does not compile a body,
construct executable IR, select an Engine/Instance entry or admit a CLI project.

## One immutable owner

`module_entry::select_i32` consumes a `module_index::Index` and takes an explicit
canonical module path and function name. The existing index first binds a public
function; missing modules/names, private declarations and struct selections retain
the existing binding failures. No implicit `main`, source path, import alias or
host capability is substituted.

The selected declaration must spell `pub fn i32 name()` followed by its opening
body brace. The original lexer handles whitespace and comments, including an
empty parameter list containing comments. Result types other than exact `i32`,
any parameter, array/reference results and extra signature tokens fail with
`module_index::Failure::Kind` at the original offending token. The function-name
token must match the selected declaration's exact source span, not merely another
identifier in its loosely scanned header.

This is an explicit narrow entry convention. Ordinary helper declarations remain
in the index even if they use different signatures; the selection routine checks
only the selected entry. Future input/host ABIs need their own accepted signature
proof and runtime admission. They must not reinterpret this proof as accepting
parameters or other result types.

On success, the private `Entry` resource owns the exact Index it checked, a
source-local signature span and the selected symbol ID. Accessors expose a shared
Index, a value ID and a value span. None exposes mutable metadata or source bytes.
The ID and span are owner-local metadata, not transferable executable authority.
There is no public constructor, candidate-proof import or operation that swaps
an Index underneath a proof. Failure drops the consumed private index and publishes
no Entry.

## Bounded work and original diagnostics

Signature scanning starts at the selected definition's original byte offset and
uses a source prefix fenced at that definition's end. Offsets are not rebased,
and later declarations cannot supply missing signature tokens. The retained
snapshot authenticates the complete file view first. BOM, UTF-8 comments, CRLF
and EOF keep the snapshot's byte-based diagnostic convention.

The additional scan is linear in the selected header's bytes and uses constant
lexer scratch. It does not concatenate/rewrite sources, walk an import graph,
change VM storage, charge guest Fuel, allocate guest backing or enlarge any
existing source/token/frame/site/operand capacity. Index construction has already
bounded all source bytes to 4096 and aggregate tokens to 1024.

The proof deliberately accepts a correctly shaped signature whose balanced body
mentions an unresolved function. Body semantics, qualified value/type lookup,
record cycles, returned-origin/ownership validation and independent IR proof
remain mandatory before any execution. `Entry` is not a `Program`.

## Focused verification

```text
python -B tools/verify-static-execution.py --profile development --selection module-entry
python -B tools/verify-static-execution.py --profile release --selection module-entry
```

The selection covers six new entry groups plus six module-index and six source-
snapshot groups. Cases include named non-first-module selection, same function
names in different modules, unselected helper ABIs, exact empty parameters,
unsupported result/parameter forms, ambiguous headers, missing/private/struct
entries, original BOM/UTF-8/CRLF locations and retained bytes after caller scratch
is changed. An unresolved body explicitly exercises the proof boundary.

Broader VM/CLI/full-profile, Linux, general allocator/OOM/stack/timing, restricted
worker, C ABI and package evidence must be recorded separately when executed.
Next carry this exact selected function through qualified source lowering and
complete independently verified executable admission. Public project loading and
entry flags remain unavailable until that path exists.

Implementation `86f7b78`: Windows development and release each passed all 18
native groups on 148 matching committed inputs, 141 LF production modules and
the same 246-file test discovery identity. Both locked LF mirrors passed without
compiler/stack overrides or historical-result reuse. The earlier test-source
syntax failure is excluded. See the
[focused Windows evidence](../evidence/module-entry-windows-20261105.json).

The [source-context successor](source-context.md) now uses the explicit selection
for scoped function signature tables and qualified nominal record declarations.
Complete body lowering/IR admission and public project entry selection remain
subsequent work; the Entry signature resource does not acquire executable authority.

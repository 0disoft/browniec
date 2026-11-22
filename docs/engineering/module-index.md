# Binding modules, imports and visible declarations

Date: 2026-11-05. This advances L01 using the immutable
[source snapshots](module-sources.md). `module_index::Index` proves header/name
binding only. It is not a typed Program, executable IR, public project loader or
proof that any body/entry signature is valid.

## Explicit identities and ownership

`build` consumes a sealed Snapshot, scans every source and owns both original
bytes and its private metadata. Each source declares one `module a::b;` header.
Path segments use the existing identifier/reserved-word rules. Whitespace/comments
between segments are ignored for canonical identity while the original path span
is retained. Duplicate canonical module names fail even when spelled with different
comments/spacing. Guest definitions rooted at `std` or `brownie` are rejected.

Imports must precede declarations and spell `import a::b as alias;`. Every target
must exist in the supplied snapshot, even when no later query uses that import.
All sources are scanned before binding targets, so source order does not determine
availability. Aliases are unique within a module and never imply a filesystem
search, builtin provider or host grant.

The namespace stores function and plain-struct declarations, including `pub`.
A function/struct name collision within one module fails; the same name in different
modules is distinct. Literals/comments inside balanced bodies do not create symbols.
The existing source lexer preserves original BOM/CRLF/NUL diagnostics.

## Policy declaration ceilings

Configured project and embedding compilers pass their function and type
ceilings into the header scan. An excess function or nominal record declaration
stops processing at its keyword, before scanning its signature or body and
before allocating the Index. The compile-limit diagnostic keeps its absent
location. Full image type counting still includes the other type identities.

The Windows development and /O2 Engine tests use incomplete bodies for both
excess declaration kinds and confirm that no SDK allocation is attempted.
Both restricted-worker profiles pass the existing compile-limit and broker
checks with zero net handles. Both embedding profiles pass the existing
catalog-backed and catalog-free policy tests. Local receipts:
`build/runtime-engine/20261122T074700277471Z/receipt.json`,
`build/restricted-worker/20261122T075344189987Z/receipt.json`, and
`build/embed-preview-c13nibhl/receipt.json`.

## Lookup and visibility

An empty qualifier selects the caller's own module, including its private symbols.
A qualifier names an explicit alias of that caller; a different module's canonical
name is not an implicit alias. Cross-module lookup requires an exported declaration.
Self aliases retain local access. There is no wildcard import or transitive reexport.

Pure import cycles are finite: binding matches the complete module table once;
lookup follows only the selected direct alias. This does not accept cyclic types
or ungrounded return origins. Their rejection belongs to the subsequent full
compiler/type/ownership proof.

`entry` binds a named public function; it rejects private symbols and struct names.
It deliberately does not prove zero arguments, i32 results or guest-input ABI
shape. The [entry signature successor](module-entry.md) separately retains and
checks a selected public zero-argument i32 function. The full compiler must still
connect that exact selection to complete body/type/ownership and IR admission.
`module_at`, `symbol`, `module_name` and the retained Snapshot expose shared views
or value metadata; no mutable Index field or source borrow escapes its owner.

Both embedding compile paths bind the public entry against the same Index
before inspecting its signature. The binding charges one unit of compile Fuel
per source identity, module candidate and symbol candidate visited. Each visit
checks the original compile deadline and the completed lookup checks it again
before updating the Index's remaining Fuel. On success, lowering starts with
that balance and reuses the selected symbol.

On Windows development and /O2, the native Engine verifier accepted a lookup
with seven Fuel for two source rows, two module candidates and three symbol
candidates. Six Fuel rejected the final candidate at its original source
span. An expired deadline rejected the lookup before any Fuel was committed.
Both profiles exited with zero live SDK allocations. Local receipts:
`build/runtime-engine/20261122T062300869307Z/receipt.json` and
`build/embed-preview-_6qs6pcx/receipt.json`.

Errors carry a checked original source-local span. Missing imports point to their
actual path; duplicate names point to the later declaration; visibility failures
point to the selected private definition. Missing external queries use explicit
no-source metadata when no input location exists. Index/module/symbol IDs are
native owner-local indices, not Engine or C ABI handles.

## Bounds and proof boundary

The native precursor keeps at most 16 modules, 64 imports, 16 functions, 32 records
and 48 total symbols. Canonical paths are at most 128 bytes, individual declaration/
alias names at most 64, and the canonical-name pool at most 4096. Aggregate source
remains 4096 bytes. Lexer work is bounded by 1024 tokens over all supplied sources;
body/parameter delimiter depth is bounded. These are explicit experimental
capacities, not promotion of the reference profile's larger limits.

Import binding performs at most 64 x 16 canonical-name comparisons. Lookup checks
at most 64 aliases and 48 declarations. There is no recursive graph walk, source
replay, mutable global state, compiler subprocess, file access or capability grant.
Bound targets stage separately before publication under the native whole-root
borrow rules. A failed build consumes/drops its private source owner and publishes
no Index. The [typed retention successor](native-module-retention.md) now keeps
the exact snapshot and completed table behind one private SDK storage owner;
allocation failure is reported separately as `Allocation`, without a source span.

Header scanning locates types/parameters/bodies without validating their full
language semantics. Missing returns, unknown types, invalid parameter syntax,
body name resolution and record cycles still require complete compilation. No
CLI syntax, version capability, VM opcode, runtime price or executable admission
is changed by this component.

## Verification and next integration

```text
python -B tools/verify-static-execution.py --profile development --selection module-index
python -B tools/verify-static-execution.py --profile release --selection module-index
```

The selection includes six new module-binding groups and all six source-snapshot
groups. It checks canonical path normalization, forward aliases, shared names in
distinct modules, public/private/self lookup, pure import cycles, named entry
binding, absent/duplicate/reserved/malformed declarations, source-local failures,
function/record/token overflow and retained source ownership. Final profiles and
input identities are recorded in the
[Windows evidence](../evidence/module-index-windows-20261105.json).
Implementation `99a1bff`: development and release each passed all 12 native groups
on 146 matching committed inputs, 140 LF production modules and the same 245-file
test discovery identity. Both locked LF mirrors passed, without compiler/stack
overrides or historical-result reuse. Earlier interrupted preliminary runs and
corrected fixture offsets/identifier generation are excluded. CLI/full-profile,
Linux, general RAM/stack/allocator/OOM/timing, restricted and ABI/package checks
were not rerun.

Next connect qualified value/type references and selected public entry signatures
to actual source lowering, independently verified IR and retained execution. Keep
original source identities/spans through that translation. Use explicit module
context for function/type lookup; rewriting every matching identifier would
incorrectly rename shadowing locals or record field labels. The selected entry
must receive complete parameter/result proof rather than merely a public-name
check. Project collection,
strict JSON/policy/grants and restricted delivery remain separate accepted work.

The [source-context successor](source-context.md) now supplies exact file fences,
scoped name lookup and typed qualified function/record declarations using this
Index. Expression/constructor/field lowering and complete executable module
admission remain open. Its copyable metadata is compiler scratch, not a substitute
for the private Index or independent Program/ownership proof.

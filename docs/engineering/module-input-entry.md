# Native selected input entry admission

This private I01 slice adds `module_input_entry::InputEntry` alongside the
unchanged zero-argument `module_entry::Entry`. It owns the exact immutable
`module_index::Index`, including its source snapshot, selected symbol, signature
span, full parameter span and parameter-name span. Fields are private; public
accessors borrow the owner and return copyable IDs/spans or a shared Index.

`select_i32_input(Index, path, name)` consumes the Index on success or rejection.
It uses actual `module_index::entry` binding, retaining Missing/Private/Kind
errors, then lexes only the selected declaration's fenced original-source range.
The accepted token grammar is exactly `pub fn i32 NAME(ref u8[] PARAM) {`.
NAME must match the selected symbol's exact source range. PARAM must be one
nonreserved identifier; it need not be spelled `input`. Comments/whitespace are
allowed between tokens. No mutable reference, other element/result types,
fixed/nested arrays, unnamed formals, extra arguments, trailing commas, defaults
or zero-argument signatures are accepted. Unsupported tokens produce Kind errors
at original file-relative spans. BOM, UTF-8 comments and CRLF offsets are retained.

APIs: `select_i32_input`, `index`, `selected`, `signature_span`, `parameter_span`,
`parameter_name_span`. This module performs no unsafe pointer/layout operations
or metadata replacement and introduces no new allocation beyond its consumed
Index. Its immutable references are scoped to the InputEntry owner.

Run `python tools/verify-module-input-entry.py` on Windows with the pinned
compiler. The verifier copies the real production import closure into its own
ignored build project, checks compiler/SDK hashes, and executes seven InputEntry
and all six unchanged zero-argument groups in development and release (/O2).
Compiler negatives reject field access/forgery, escaped owner borrows and use
after move. Timestamped receipts retain exact input/artifact/report hashes and
commands. The isolated bytes/text/vec SDK import closure has its own pinned
source digest (`e256aabf...`), distinct from the full-root SDK digest. The
compiler executable hash remains the repository pin. Native runs use default
stacks, with no CL/_CL_/LINK overrides.

This is signature admission, not executable input admission. In particular,
`module_program::compile` still takes only `module_entry::Entry`; no conversion
or success stub is supplied. Body/type/ownership/lowering proof, actual guest
input binding, Engine/Instance integration, CLI/stdin/file support, R03 chunk
bounds and complete Engine accounting remain subsequent work. Existing public
availability, zero-arg behavior, VM capacities and Fuel prices are unchanged.
Allocator failures are not injected in this signature-only slice.

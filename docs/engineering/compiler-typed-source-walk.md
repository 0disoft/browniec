# Typed/value source traversal

The 2026-11-14 checkpoint adds private continuations to the separate
`value_source` compiler. It covers advisory lexical walks and program/scope
iteration on source snapshots of at most 4096 bytes. The ordinary/public
compiler does not select this dialect. Owning adapters still drain synchronously.

## Advisory lexical walks

`value_probe_work` implements postfix-receiver, tail-control, tail-expression,
assignment and pure classic-for-header lookahead. One stage inspects a token or
advances its existing `lexer_work` child; long spelling, comments and literals
therefore retain the child's bounded scanning steps. Parenthesis/brace counters,
else chains, member/range ambiguity, pure-header restrictions and error offsets
retain their independent raw implementations' behavior.

The cursor is private. Neither success nor lexical failure publishes it to the
real parser, bindings, catalog or IR. General helpers with source longer than
4096 bytes retain their original raw paths, outside this bounded profile.

## Program and scope drivers

`value_walk_work::Program` initializes the program header, maps one function's
result metadata per stage, advances each first body token through `lexer_work`,
checks its closing offset and advances the function index separately. Result
enforcement, function admission, body lowering, implicit return cleanup/emission
and function finalization are explicit child requests. A whole function body is
never charged as one bounded parent stage.

`Scope` checks depth, records its lexical mark, requests one semantic statement,
checks terminal/tail-yield status, and requests scope cleanup separately. The
owner reports terminal and produced-value outcomes once. Waiting and denied
advances leave the driver unchanged; completed advances do not repeat work.
Unreachable trailing source, missing values, scope cleanup order and the
existing depth-32 admission/depth-33 rejection remain unchanged.

The old program and scope loops remain available through an invocation-local
routing bit for private comparisons. It is passed through recursive helpers so
the raw comparison uses the old loops at every nested scope. No binding, Bank,
Pratt or Semantic State field is added. Expression and ownership helpers remain
shared; this is an independent traversal oracle, not an independent evaluator.
Oversized direct compiles use the original raw traversal. There is no automatic
retry after a compilation failure.

## Verification and boundaries

The [evidence](../evidence/compiler-typed-source-walk-windows-20261114.json)
records each focused development/O2 snapshot and its committed input hashes.
Probe checks compare raw decisions/errors and complete lexer fields, including
oversized-helper compatibility and budget/completion guards. Traversal checks
compare all IR fields, canonical catalogs and value metadata, including mutated
candidates on failure. Accepted candidates are independently verified and run to
42. Existing nested bottom tails, classic-for transfers, terminal loop arms and
depth-32/depth-33 conditionals are retained on default native stacks.

An initial traversal selection stopped at frontend rejection: its comparison
test used a short-circuit expression that could leave a Result unconsumed.
Separating the assertions fixed the fixture without changing production inputs.
That incomplete attempt is not a native pass. An earlier root check also caught
a missing Result propagation in the new adapter; it was fixed before native
execution. No compiler, optimization, stack or timeout overrides were used.

The existing owning Engine receipt is reused only after matching every one of
its 367 input hashes against the current checkout and final implementation
commit. These private source modules are outside its unchanged source closure;
the transport is byte-identical. Its development/O2/default-stack/zero-exit-heap
results are prior Engine evidence, not a new typed/value allocator measurement.

All new cursors are inline. There is no new SDK heap class, scratch reservation,
or public Pending compiler. The 4096 logical allowance, scratch widths/slot caps
and existing 66,630,144-byte lowering reservation remain unchanged. These changes
establish no measured CPU, time, native stack or physical heap improvement.

Semantic statement/expression evaluation, recursive control helpers and their
ownership/CFG operations remain explicit synchronous child boundaries, with
their existing internal behavior. Catalog interning, origin inference,
function admission/finalization and cleanup internals are outside these named
walk bounds. Complete transitive evaluation, entry/final metadata and unrelated
implicit cleanup remain unfinished. Standalone memory, broad public-CLI and full
release gates were not rerun. Broader completion remains paused; local only,
without push, release, deployment or version change.

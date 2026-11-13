# Declaration header preparation

The 2026-11-14 checkpoint stages ordinary source declaration headers: inferred
binders, scalar/wrapper and fixed-array annotations, nominal records, lexical
slices and static byte/text views. These private continuations operate on the
pinned source and lexical table. Owning adapters still drain synchronously;
initializers are evaluated only after complete header preparation.

## Binder and lookahead cursor

`declaration_name_work` validates a binder, drives the existing first-match
`argument_name_work` cursor, checks capacity, then consumes its name and equals.
Lookup examines one row or at most 64 spelling bytes per stage. Duplicate names
still fail before a full lexical table; the record owner-site cap is checked at
the original binder offset. The cursor never publishes a name or emits IR.

Its inference-lookahead mode inspects one next token through `lexer_work` and
keeps the real lexer unchanged, including lookahead failures. The original
inference header and follows routines remain independent raw oracles. General
helper calls with source longer than 4096 bytes retain their raw compatibility
path; the private bounded claim applies to the lowering profile of <=4096 bytes.

## Annotation and header composition

`declaration_header_work` composes the existing token, annotation and binder
kernels. Scalar/wrapper tags, optional fixed-array lengths, reference access,
brackets and equals advance separately. Array length and declaration-context
failures retain the old token position and precedence over binder validation.
Slice scalar restrictions and static byte/text grammar keep their distinct error
rules. Prepared headers contain only small scalar fields, never an owner or IR
admission token.

Nominal record headers request declaration layout/size validation explicitly
before consuming the type token. Their owner drains the existing bounded
`declaration_limit` protocol and resumes once. Pending parent advances do not
charge or mutate. The original nominal lookup protocol remains separate.
Record, slice and static headers keep their original wrappers and raw oracles.

The semantic declaration continuation issues explicit request 3 for binder and
equals preparation after its existing annotation child finishes. Its owning
compiler adapter resumes with the checked span; the expression still executes
once and the binding is published after initializer/type/terminator checks.
Semantic State, Bank and Pratt fields do not grow. Array and specialized
reference/record routing keep their established explicit semantic children.

## Evidence and boundaries

The [declaration evidence](../evidence/compiler-declaration-header-windows-20261114.json)
connects focused development/O2 snapshots and final owning Engine integration
to committed source hashes. Direct comparisons cover lexer fields, errors and
prepared spans across typed/array/reference/record forms, duplicate/capacity
priority, bad lengths/annotations/delimiters and lexical errors. Protocol checks
cover budget denial, record-child waiting, duplicate resume, terminal guards,
200-byte spelling chunks and oversized-helper compatibility. Source fixtures
verify/run to 42, reject initializer self-reference, and exercise a wrapper
annotation inside 32 nested controls on default stacks. Existing exact raw IR
and CALL depth 32/33 regressions are retained.

The first header test attempt was rejected by the frontend for its oversized
mutable fixed-array fixture. The compatibility fixture was changed to build a
buffer from fixed-size chunks before native execution; production did not change
for that correction. No incomplete attempt is counted as a native pass.

Two inline cursors and one small Prepared result introduce no SDK heap class or
Bank/Pratt/Semantic State field. The existing 4096 logical allowance, scratch
widths/slot caps and 66,630,144-byte lowering reservation remain unchanged. Fixed
inline setup and synchronous owning drains remain atomic. This establishes no
public Pending compiler or measured CPU/time/physical-heap/stack improvement.

Complete transitive evaluation, advisory static/reference routing, typed/value
source walkers, catalogs/origins, entry/final metadata and unrelated implicit
cleanup remain outside these named header bounds. The standalone 28-group
memory, broad public-CLI and full-release gates were not rerun. Final Engine
retains its owning allocator/compile fixtures. Broader completion remains paused;
no push, release, deployment or version change.

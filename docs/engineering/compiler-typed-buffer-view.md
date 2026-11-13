# Typed/value Buffer and view operations

This private source checkpoint extends the typed/value evaluator with staged
Buffer calls, view operands/effects and Buffer/view copies. Owners still drain
synchronously with the existing 4096 logical allowance. Sources over 4096 bytes
retain raw parser routing; failed compilation is never retried in another mode.
The public CLI does not select the private dialect.

## Buffer operands and results

`value_buffer_call_work` separates namespace qualification, shadow lookup,
operation names, ref/mut prefixes, delimiters, recursive operand acquisition,
loan creation and scalar capture. A receiver loan is acquired before evaluating
a later argument. Bottom is admitted only at the same original operand positions;
nonlast bottom arguments still reject. Wrong ref/mut prefixes retain the ref
start offset. Construction and argument effects are never replayed.

`value_buffer_source::Finish` separates closing loans, each interned result type,
capacity/emission services, temporary drops and final context validation.
Ownership/property work is an explicit service child. APPEND closes its second
loan before the first and drops temporary sources before temporary receivers.
Scalar len/read retain their original context behavior; mutation/growth retains
the original must-use Result wrapper and failed candidate order.

## Views and lexical roots

The copied range probe uses bounded token work without publishing the real
lexer, including errors. Index/range handling captures its receiver before any
endpoint effect, then separates type preparation, zero/default length, endpoint
evaluation, scalar capture, delimiters and indexed-result preparation.
Whole view, .len, scalar read and range effects request authentication, loans,
IR/descriptor publication, close and type services separately. Named views keep
their descriptor; anonymous inspection closes its captured view at the original
point. Endpoints returning bottom do not emit the enclosing operation.

Lexical root validation authenticates structural roots first, then advances one
owner or owner-name row. It preserves retained-root permission and the original
error order. No source ledger, view ledger, loop State, Bank, Pratt or Semantic
field is added.

## Copy results and cleanup

`value_buffer_copy_source::Copy` has 37 phases. Its explicit children retain
result/size/growth type preparation, expected context, destination allocation,
empty owner construction, exactly one APPEND104 or APPEND_VIEW112, anonymous
view close, success/error CASE/tag/drop/JUMP operations, the impossible mismatch
trap, joins, snapshot release and final temporary cleanup. Failed candidates
preserve the complete original IR/catalog prefix. Branch snapshots use the
existing owning vector; no new SDK heap class or cross-invocation cache exists.

## Default-stack correction and verification

Actual special CALL depth 32/33 is tested alongside ordinary CALL depth 32/33.
The new nested bytes::read fixture exposed raw native stack overflow. A
pre-correction generated-C/MSVC diagnostic found a 9208-byte common raw Buffer
frame. The scalar-argument path now avoids unrelated operation branches, and
namespace calls avoid the large primary leaf frame. Staged operands share only
inactive lexer/type scratch with their waiting evaluator and isolate
nonrecursive services. Default compiler, optimization, stack and timeout settings
are retained. These fixture results are not a measured stack peak or performance
claim.

The [evidence](../evidence/compiler-typed-buffer-view-windows-20261114.json)
binds each focused development/O2 selection to its exact implementation commit.
It includes independent raw comparisons of all IR/catalog fields and diagnostics,
failed partial candidates, denied/waiting/completed/duplicate-service guards,
endpoint effect order, retained returned views, copy Result handling and accepted
execution to 42. The selections contain 8, 9 and 8 native groups respectively.
Incomplete fixture and overflow attempts remain separate from passes.

The complete owning Engine closure (352 sources), transport and all 367 input
hashes are unchanged and match the final implementation commit. Prior passed
Engine development/O2 evidence is reused; it is not a new typed allocator or
physical peak measurement. Working reservations and scratch caps are unchanged.
No public Pending compiler, measured CPU/time/heap/stack gain or R02-R05 closure
is claimed.

Existing authentication/property cursors compose within service children. Fixed
helpers still inspect up to 16 descriptors/roots, 64 names or 24 origin bits;
complete microstep staging of every such primitive is not claimed. Propagation,
recursive control/CFG joins and snapshot release, interning/origin/function and
entry/final/other cleanup internals remain explicit synchronous services or
outside these named kernels. Broader completion stays paused. Standalone memory,
broad public-CLI and full release gates were not rerun. Local only: no push,
release, deployment or version bump.

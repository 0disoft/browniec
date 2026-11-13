# Typed/value evaluation and ownership

The 2026-11-14 checkpoint extends the private value source compiler with
ownership authentication, operand evaluation, capture, CALL and constructor
continuations. Its owner still drains synchronously. The public compiler does
not select this dialect, and a failed compile is never retried in another mode.

## Ownership authentication and captures

The inline `value_view_bindings::Auth` cursor checks one descriptor, lexical name
or dependency per stage. Function ownership follows structural validation, in
the old error order. `value_source_bindings::Auth` composes those children,
checks one value slot, one view/owner pair, or one lexical row per stage.
Slot checks can also inspect the bounded 64-row owner-name table. These cursors
are read-only and introduce no new ledger field or executable authority.

`value_source_context::Capture` separates named capture allocation from
COPY/MOVE, scalar capture from read and DROP, and explicit discard from handling
and DROP. Borrowed aliases retain their root validation and lexical checks.
The existing binding operations authenticate through the new cursors. The
private `value_source_properties` adapter drains the existing record/layout and
catalog-node property continuations for bindings, source operations, interning
and staged CALL finalization. Common/runtime property inspection remains
unchanged; independent raw comparisons check complete Plans and error precedence. Parent requests do not
charge an entire ownership helper as one admitted stage. Rejection preserves
the original partial candidate, including a destination allocated before a
subsequent named-read failure.

## Operand evaluation

`value_expression_work` stages precedence operators, casts, postfix suffixes,
grouping, unary/ref operands and signed minima. Recursive operands are explicit
child requests. Capturing a left operand still precedes evaluation of its right
operand. Token and annotation work use the existing bounded children; casts use
the cast half of the existing lexical preflight before primary-context probing.
Named local/callee lookup uses the existing spelling cursor.

Capture/read, type checks, scalar IR emission, interning requests and temporary
DROP occur in their original order. A bottom operand does not manufacture a
destination or repeat terminal effects. Cast suffixes still validate their type
even after bottom; postfix suffixes retain their rejection behavior. Boolean
short-circuit CFG services remain explicit children.

## CALL and constructor ownership

`value_call_source_work::Arguments` separates delimiters, one argument's
evaluation, its capture, and CALL finalization. Shared, owning and scalar actuals
keep their old encodings. A bottom argument must still be last, consumes the
closing delimiter and skips CALL publication.

`value_source_calls::Finish` reserves the return destination before CALL
capacity checks, maps one actual per stage, emits CALL, requests property proof,
then handles and drops/consumes one captured actual at a time. The Result
obligation transfers only after CALL is published. The returned owning slot is
initialized last. Returned views preserve selected-origin retention and close
their captured aliases in the same order.

`Constructor` validates its variant/context, evaluates its payload, checks the
closing delimiter, interns an inferred wrapper when needed, captures the
payload, builds the tag and drops the temporary separately. Terminal payloads
skip construction. `.none` retains its payload-free grammar and existing partial
IR behavior on a later delimiter error.

## Default-stack CALL correction

The initial combined development selection and three follow-up diagnostics
stopped on native stack overflow at actual CALL depth 32. All four attempts are
recorded as incomplete. Separate diagnostics localized an overflow in the raw
route before the staged route could run independently. The staged owner also retained multiple intrinsic
control frames; those frames were reduced as part of the correction.

Raw dispatch avoids retaining stateful driver and large primary leaf frames
around CALL arguments. Boolean/binary completion, casts and postfix suffix
services move to functions called after their recursive child returns. Primary
catalog projections borrow the catalog instead of cloning it.

The staged owner keeps expression/cast/postfix/primary control in three inline
suspended States instead of four recursive host frames. One token/type scratch
is shared only while the parent is waiting with no active lexical/type work.
Actual recursive operands retain depth checks and separate control States.
No heap storage or compiler/optimization/stack/timeout override is added. The
final selection compares complete raw/staged candidates, accepts CALL depth 32,
rejects 33 and executes accepted code to 42. These checks establish default-stack
behavior for the fixtures, not a measured stack peak or performance improvement.

## Evidence and remaining boundaries

The [evidence](../evidence/compiler-typed-evaluation-windows-20261114.json)
connects each development/O2 selection to its exact implementation commit.
The four slices pass 5, 12, 16 and 8 native groups respectively in each
profile. Checks compare independent raw authentication and capture sequences, complete
raw/staged IR and catalogs, liveness and failed candidates. Accepted programs
are independently verified and run to 42. Tests retain mixed shared/owned CALLs,
selected returned ranges, negative origin/alias cases, bottom arguments and
short-circuit effects. Actual nested CALL depth 32/33 and control depth 32/33 run
with the pinned compiler's default stack and no overrides.

The owning Engine is outside the changed private source closure. Its complete
352-source closure, transport and all 367 receipt input hashes are checked
against the current checkout and final implementation commit before reusing its
prior passed development/O2 evidence. That is not a new typed/value allocator or
physical peak measurement. No new SDK heap class, ledger/Bank/Pratt/Semantic
field or scratch reservation is added. The existing logical allowance is 4096.
No public Pending compiler, measured CPU/time/heap/stack improvement or R02-R05
closure is established.

Specialized Buffer/view operations, propagation and recursive control/CFG join
services retain explicit synchronous child boundaries. Their complete internal
staging, catalog interning, origin inference, function admission/finalization,
entry/final metadata and unrelated cleanup remain outside these named kernels.
General source helpers over 4096 bytes retain their raw parser routes. The
standalone memory, broad public-CLI and full release gates were not rerun.
Broader completion stays paused. Local only: no push, release, deployment or
version change.

The subsequent [typed Buffer/view checkpoint](compiler-typed-buffer-view.md)
stages the specialized operand, view effect and copy boundaries named above.
Propagation, recursive control/CFG services and remaining metadata/cleanup
internals retain their separate boundaries.

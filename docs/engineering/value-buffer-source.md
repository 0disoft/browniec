# Private Buffer source operations and argument loans

The private typed-source implementation lowers namespace calls to the existing
Buffer value instructions. The integration is implemented and
verified in the focused Windows native profiles below. Public Buffer source admission,
methods, compiler/CLI routes and capability gates remain closed. These calls do
not introduce general references, native views/slices or a public AllocError.

## Call contract

Both `bytes::` and `brownie::bytes::` select the same private operations. The
leading namespace must not resolve to an active local binding. In the table,
`b` and `s` have exact type `Buffer`, `i` and `n` are `usize`, and `v` is `u8`.
Reference prefixes are required source syntax, not first-class reference values.

| Call (either namespace) | Result | Effect / lowering |
| --- | --- | --- |
| `bytes::empty()` | `Buffer` | New empty owner; EMPTY95. |
| `bytes::copy(ref b)` / `bytes::copy(ref view)` | `Result<Buffer,u8>` | [Owned Buffer copy](value-buffer-copy.md) or [selected view copy](value-view-copy.md), retaining the source. |
| `bytes::view(ref b)` | `ref u8[]` | [Readonly lexical view](value-view-source.md), ranges, length/index and ordered cleanup. |
| `bytes::len(ref b)` | `usize` | Retain owner; LEN99. |
| `bytes::read(ref b, i)` | `u8` | Read initialized byte; READ100. |
| `bytes::write(ref mut b, i, v)` | `void` (no value) | Write initialized byte; WRITE101. |
| `bytes::push(ref mut b, v)` | `Result<usize,u8>` | New length on success; PUSH102. |
| `bytes::reserve(ref mut b, n)` | `Result<usize,u8>` | Actual capacity on success, length unchanged; RESERVE103. |
| `bytes::append(ref mut b, ref s)` | `Result<usize,u8>` | New destination length on success; preserve source; APPEND104. |

Types use canonical exact catalog nodes. Scalar operands must have the stated
types; contextual integer literals do not authorize conversion of an already
typed `i32` index or `usize` byte. Growth returns exactly `Result<usize,u8>`,
not a boolean or a public allocator-error wrapper. The existing native contract
uses error byte `1` for allocator failure; bounds, Fuel and hard-quota failures
remain execution errors. See [Buffer execution](value-buffer-execution.md) for
native ownership, publication and Fuel details; this source layer adds no opcode
or Fuel schedule.

## Argument lifetime and ownership

Arguments evaluate once, left to right. After evaluating the receiver, lowering
opens its shared or exclusive loan before evaluating any later argument. Append
then evaluates and loans its source. Loans close in reverse order immediately
before instruction emission, restoring the enclosing loan masks exactly.

`State.reads` and `State.writes` are compiler-only masks over live exact Buffer
slots. Shared loans can nest on the same slot; an exclusive loan conflicts with
any loan on that slot. Snapshots preserve the masks and continuing joins require
them to match. Loan checks block overlapping moves, assignment, discard and
scope cleanup. They create no guest handle, runtime lease or owner alias; the
independent scalar/value CFG admission remains required for executable code.

A named shared receiver may be immutable. A named mutation receiver must be a
live mutable binding (`var`); `ref mut` alone cannot make a `let` mutable. Owned
temporary receivers are allowed, including mutation of `ref mut bytes::empty()`.
They stay live through argument evaluation and are dropped after the operation.
Append likewise drops a temporary source after emission, retaining named owners.
Self append rejects even for an empty Buffer: its shared source conflicts with
the destination loan, and the lowering helper also rejects identical slot IDs.

For example, `bytes::read(ref b, bytes::len(ref b)-1)` permits nested shared
access. `bytes::reserve(ref mut b, bytes::len(ref b))` rejects because the receiver
is already exclusively loaned while the length argument evaluates. Compute the
length before starting that call. Effects on distinct owners remain possible.

Loans follow control flow through argument expressions. Continuing branches and
successful `?` propagation retain enclosing loans until the call completes.
Explicit return abandons the pending call and clears its loans before evaluating
the return operand; propagated failure clears loans for function cleanup.
Break/continue restore the target loop's entry masks before cleaning transferred
scopes and anonymous values. Thus an inner loop entered during argument
evaluation preserves the enclosing call's loan, while an exit abandoning that
call releases its inner loans. Clearing a loan never acknowledges a Result or
restores a moved owner. Function boundaries require empty loan masks.

## Typed boolean short circuit

`&&` and `||` require `bool` operands and produce `bool`; `&&` binds more tightly
than `||`. Lowering stores the left value in a scalar slot and emits a forward
guard: false skips the RHS for `&&`, true skips it for `||`. The RHS is still
compiled and type/ownership checked. Only its selected runtime path executes;
calls, Buffer effects and propagation on the skipped path do not execute.

Evaluated and skipped paths use the existing branch join. If the RHS moves an
owner, the skipped path explicitly drops the still-live owner and
the joined binding is Dead. Subsequent use rejects until legal mutable
reinitialization. No runtime drop flag, owner resurrection or loan bypass is
introduced. Cleanup must also respect any enclosing argument loan.

Result handling is separate from copyability and ownership. Growth results must
be acknowledged by the existing predicate, match, propagation, explicit discard
or transfer rules. A Result handled only on the RHS remains pending on a skipped
edge: conditional `.is_ok`/`.is_err` does not acknowledge it on every path.
Joins union pending obligations; implicit cleanup cannot discard a pending
Result. Loop summaries retain their existing intersected kills, unioned
generation and monotonic requirements, including second-iteration checks. See
[typed loops](value-loops.md). Passing a captured Result to a call transfers its
obligation only after CALL emission, so an exit during later argument evaluation
cannot silently discharge it.

## Verification and remaining work

Implementation commit: `e8d2a7d`. Run
`python -B tools/verify-value-buffer-source.py --batch source --profile development`
and the release counterpart; use `--batch native` for the disjoint emitter/VM
selection. The four batch/profile combinations use separate locked mirrors and
output directories and can run concurrently. `--discover` only lists identities.

Development and release each passed 12 groups: seven source/boolean/loop/depth
groups and five emitter/VM groups, with 62 new guest programs (30 success and 32
rejection). The existing admitted 32/rejected 33 conditional fixture remains
byte-identical and executes in both profiles without native stack overrides.
All 217 inputs match checkout and committed Git raw bytes; all 206 production
modules use LF. No historical result reuse or native override was used. See
[Windows evidence](../evidence/value-buffer-source-windows-20261107.json) and the
[input manifest](../evidence/value-buffer-source-inputs-windows-20261107.json).

The source fixture initially reused an active outer name in a later switch
payload. Its corrected payload name preserves the no-shadowing contract; both
final profile runs use that corrected fixture. Loan rejection also covers the
native lowering helpers and direct ownership handoff before any publication.

Successor: [owned copy](value-buffer-copy.md) now connects `bytes::copy` through
the same private source/owner rules. Its evidence is recorded separately.

Remaining work: Buffer view/method syntax and copy-from-view, first-class references/native
views/slices, public AllocError and intentional public source/CLI/capability
admission, text/I/O and broader host/runtime composition. Actual allocator/OOM
failure injection, full language/public CLI/native Fuel matrices, Linux, general
performance and clean-machine delivery were not run. Existing opcode prices and
Fuel default256/ceiling16000000 remain unchanged. Local commits only; no push,
release or deployment. The full implementation objective remains open.

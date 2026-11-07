# Copying a Buffer view into a new owner

The private typed-source intrinsic `bytes::copy(ref source)` now accepts a
readonly Buffer-backed `ref u8[]`, including a relative range or an immediate
view of an anonymous Buffer. Its qualified spelling is `brownie::bytes::copy`.
The result remains exact move-only `Result<Buffer,u8>` with must-use obligations.
Existing owning-Buffer inputs retain their original APPEND104 lowering.
Public source/CLI admission and a public AllocError type remain separate work.

## Source lifetime and ownership

Evaluate the source once, capturing a named view as an anonymous alias before
creating the destination. EMPTY95 creates an independent owner. APPEND_VIEW112
copies only the authenticated view window into that owner, then the compiler
closes its anonymous source capture before joining the Result wrapper arms.
The original lexical view and its physical root lease remain live. An anonymous
root drops only after its final descriptor closes. An owning result can survive
that cleanup; the borrowed input itself never escapes or extends a temporary.

The existing five monotonic compiler slots are shared with owning-Buffer copy:
output wrapper, new Buffer, intermediate Result, success scalar and error scalar.
No per-element guest instruction loop or input-sized staging buffer is emitted.
The existing sixteen-slot whole-program limit and reference descriptor limits
still apply. Range endpoints preserve the existing receiver capture, bounds,
ordered effects and nonlocal return/break/continue cleanup.

## Independent instruction and native transaction

Private opcode112 has `dst=Result<usize,u8>`, `a=Buffer value slot` and
`b=local view ID`. Bytes4..7 are zero. Independent owning CFG proof requires a
live destination Buffer and initializes a Dead Result slot. Separate view CFG
proof requires a live view and rejects a pinned destination, including empty
self-append. It preserves source origins across joins and backedges. Legacy
admission remains closed; no guest scalar or canonical value contains a ticket.

The runtime authenticates the current frame, canonical Result destination,
Buffer identity and frame-local view binding. It prepays Result publication
before mutation and subtracts frame usage from remaining Instance/Engine quotas.
The registry authenticates the exact view row, root generation/lease and initialized
window. `value_roots::append_window` subtraction-checks the window before adding
its end or extracting the distinct destination. The source stays in its original
root/scratch vector while the destination uses the existing append transaction.
Both dense-vector index orders are supported; native views never escape.

Rejected bounds, stale/binding, Fuel and quota admissions preserve root bytes,
length, serial/generation and accounting. Already charged Fuel stays spent.
Allocation failure remains the canonical private error Result; hard failures stay
execution errors. Publication after native mutation is prepaid and cannot become
a recoverable rejection. Invocation failure closes views before draining owners.

The new native view bridge charges 256 plus the existing
`append_from_cost(old_length, view_length)`, with checked arithmetic. Its VM
adapter additionally pays existing Buffer authentication and Result publication
costs: for admitted sizes the adapter charges `6752 + 4*(old_length + view_length)`
Fuel, excluding invocation setup and surrounding source instructions. Existing
instruction prices, no-view setup costs and public Fuel
default256/ceiling16000000 are unchanged. Payload work is linear in the copied
window and any old destination prefix; source copy always starts from length 0.
No wall-clock performance or actual allocator-failure injection is implied.

## Verification and remaining work

The focused runner is `tools/verify-value-view-copy.py`, with disjoint `--batch kernel`,
`--batch core` and `--batch regression` selections and development/release profiles.
`--discover` lists exact tests without writes. Kernel commit: `3d158ba`;
integrated source/VM commit: `223260f`.

Windows development/release each passed 21 groups: kernel 3, core 9 (new
source 3/new execution 3/owning-copy regression 3), and source-view/depth regression 9.
They cover actual nonzero/nested/empty windows, both dense-vector index orders,
independent mutation and source pin retention, anonymous source compaction,
return/propagation/loop endpoints, malformed IR, independent owning/view proof,
fresh Results, stale frame/view identities and exact Fuel/quota failures. A
direct adapter test pays 6764 Fuel for a one-byte destination plus a two-byte
window, rejects 6763 without changing root/frame publication state, checks the
canonical success/error bytes and performs zero-Fuel terminal cleanup. Manual
allocation-error publication is not actual allocator/OOM injection.

All 224 union inputs match checkout and Git raw bytes; all 213 production modules
are LF. Each of six native runs uses a fresh locked byte-identical mirror with
no native override or historical result reuse. Production/tool inputs match
between batches and profiles. Kernel runs began before the kernel commit with
identical final production bytes; final source tests use the finalized test
bytes. The original admitted32/rejected33 fixture stays byte-identical and ran
in both profiles. See [Windows evidence](../evidence/value-view-copy-windows-20261107.json)
and the [input manifest](../evidence/value-view-copy-inputs-windows-20261107.json).
Full language/public CLI/native Fuel matrices, Linux, actual allocator/OOM
injection, general stack/performance and clean-machine delivery were not rerun.

General reference formals/results, view-valued joins, method syntax, public
AllocError/admission, text/I/O, full Engine/Instance/host/cancellation behavior,
isolation and platform/delivery remain part of the full objective.

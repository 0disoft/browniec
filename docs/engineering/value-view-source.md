# Buffer view source bindings and cleanup

The private typed-source path, `value_source::compile`, lowers the intrinsic
`bytes::view(ref Buffer) -> ref u8[]` and its `brownie::bytes::view` spelling to
the [independently retained view instructions](value-view-execution.md). This
contract covers lexical readonly Buffer views in that path. It does not admit
general reference parameters/results or select this path in the public
compiler/CLI.

```c
var Buffer b = bytes::empty();
_ = bytes::push(ref mut b, 42);
{
    let ref u8[] v = bytes::view(ref b);
    let child = v[..];
    let usize length = child.len;
    let u8 first = child[0];
}
bytes::write(ref mut b, 0, 7);
```

## Source operations and evaluation order

Explicit `let ref u8[]` and inferred local declarations are supported. The
intrinsic requires a shared `ref` to an exact live Buffer; `ref mut` and other
root types are rejected. The payload is always readonly: neither
`ref mut u8[]` nor indexed assignment is admitted.

| Expression | Result and check |
| --- | --- |
| `v.len` | Exact `usize`, the current view's initialized window length |
| `v[i]` | Exact `u8`, with exact `usize` index and `i < v.len` |
| `v[lo..hi]` | Relative half-open child window, `lo <= hi <= v.len` |
| `v[..hi]` | Child window with low endpoint zero |
| `v[lo..]` | Child window with high endpoint equal to the captured receiver's length |
| `v[..]` | Child window covering the captured receiver |

Nested ranges use the actual parent window, not the whole Buffer's coordinates
or spare capacity. Empty ranges, including `[v.len..v.len]`, are valid; indexing
an empty window or at its end is not. Named `i32` or `bool` operands are not
implicitly converted to `usize`. Invalid dynamic index/range bounds report
runtime bounds error kind 14.

The receiver is evaluated and captured **before** the index or either endpoint.
A named receiver gets a retained anonymous alias; an already anonymous receiver
is used directly. Each explicit endpoint executes once, low before high, and
the final read/range instruction checks bounds afterward. Thus an endpoint's
arithmetic failure is preserved even if the low endpoint would already make
the range invalid. Endpoint side effects are not rolled back.

Rebinding the lexical receiver during an endpoint expression cannot change
which bytes that operation inspects. The captured alias keeps the old root
pinned until the operation completes or its control path exits. For example,
if both branches of an index expression rebind `v` from `b` to `c`, the pending
read still reads `b`; subsequent uses of `v` read `c`. Endpoint effects that
write or move `b` remain rejected while that capture is live.

## Aliases, rebinding and root lifetime

Initializing a view local from a named view creates an independent alias of its
window. Closing one alias does not close its siblings or derived ranges.
`_ = named_view` leaves the binding live; discarding an unnamed whole view or
range closes that descriptor. These are lexical lifetimes: last use alone does
not release a named view's pin.

`var ref u8[] v` (or an inferred `var` view) permits rebinding, not payload
mutation. Assignment captures the RHS while the old binding is still live,
closes the destination descriptor, then moves the captured descriptor into the
destination's existing logical ID. This also accommodates self-aliasing RHS
expressions without closing their source too early. Other aliases of the old
root retain their windows and keep that root pinned. Only plain `=` is admitted
for a view binding; immutable `let` bindings cannot be rebound.

Any live descriptor pins its exact Buffer root, including an empty whole view,
an empty range, and an anonymous receiver capture. While pinned, source lowering
rejects:

- Byte writes and push/reserve/append destination loans, including requests that
  would do no work, such as `reserve(..., 0)` or appending an empty Buffer.
- Replacement of the root binding, owning moves, explicit owner discard and
  implicit owner drops that would leave a surviving view.
- Transfer of that root as an owning CALL argument or into an owning payload.

Shared root reads and independent `bytes::copy(ref buffer)` operations remain
available; using a Buffer as an append source does not require a write loan.
Mutation and owning calls involving other roots may proceed. Caller views stay
live across unrelated calls, and caller/callee logical view IDs are isolated by
activation. Copying directly from a `ref u8[]` view is separate work.

A named view must originate from a live lexical Buffer owner or an owning
Buffer formal. A view cannot outlive that owner: scope cleanup rejects a
departing root if a view outside the departing scope still pins it. Ordinary,
owning and view locals share the existing namespace; redeclaring a name still
visible in that namespace is rejected, including in an inner scope.

An anonymous Buffer can be viewed and inspected within its expression:
`bytes::view(ref bytes::empty()).len` is admitted. Binding that borrowed result
to a local, such as `let ref u8[] v = bytes::view(ref bytes::empty());`, is
rejected; declarations and reassignments do not implicitly extend a temporary
Buffer's lifetime. Anonymous descriptor cleanup drops its anonymous root only
after the last view closes. Named roots stay for ordinary lexical owner cleanup.

## Metadata, proof and control flow

`value_view_bindings::State` contains sixteen origin entries and sixty-four name
entries alongside the existing owning binding state. An origin is Dead (zero)
or an exact Buffer slot plus one. Name entries encode a descriptor ID plus one;
they do not create owning slots. Closed IDs may be reused, and closing a
descriptor detaches its name mapping so reuse cannot revive a stale name.
Canonical owning-value IDs are not recycled by this mechanism.

The lowering uses VIEW_BEGIN (105), RANGE (106), ALIAS (107), MOVE (108), CLOSE
(109), LEN (110) and READ (111). A whole view begins at zero and ends at the
root's actual Buffer length. The independent retained-IR verifier, rather than
compiler metadata, proves live sources, Dead destinations, exact scalar
operands and compatible view origins over the CFG. Native tickets, leases and
owner serial/generation words remain trusted runtime metadata, never guest
scalar handles or canonical owning values.

Compiler snapshots include view origins and names. Selecting a separately
reached branch restores that metadata without restoring runtime authority or
rewinding static owning allocations. Continuing joins require identical live
origins and lexical bindings. Matching origins may carry different actual
windows on different runtime paths; reads authenticate the selected window.
An `if` or `switch` that itself yields a view is not admitted by this slice.

Normal scope cleanup preflights departing bindings and instruction capacity,
closes all departing named views before dropping their roots, then removes
names. Branch-local views close on their respective exits. A surviving view
that would prevent a required root drop causes rejection rather than an
implicit lifetime extension.

Loop fallthrough, `break` and `continue` first close anonymous descriptors
introduced since loop entry, then clean the departing lexical suffix. This
orders a captured endpoint receiver before any departing Buffer owner. Enclosing named
views and anonymous expression captures present at entry are retained. The
surviving view state must match the loop baseline exactly; backedges do not
silently carry a view of a different root. A `for` continue performs body cleanup
before the shared post expression. Repeated runtime iterations reuse logical
descriptors through the registry's native generation checks.

An explicit return evaluates its result expression, closes remaining views,
then captures an owning return value and finishes owner cleanup. Consequently,
`return b;` may transfer a Buffer after inspecting a local view of `b`.
Operations *inside* the result expression still obey the live-view gates; the
later return cleanup does not authorize an earlier owning call or move.

The early-return path for Result/Option `?` closes lexical and anonymous views
before owner cleanup and RETURN. Successful propagation preserves the
continuing path's view state. Nonlocal returns from an index/range endpoint
also drain its receiver capture. On runtime failure or Fuel exhaustion, the
retained VM's prepaid registry shutdown releases views before frame/root drain;
external effects are neither replayed nor rolled back.

## Representation limits and admission gates

The source-only exact-type sentinel **65** denotes readonly `ref u8[]`; 64
remains the inferred context marker. Sentinel 65 is outside the canonical owning
type DAG. It is never serialized as an executable scalar type, owning type,
formal/result signature or legacy slice parameter/root encoding. Conversion to
an owning value or scalar rejects views; they cannot be returned as a Buffer,
passed as an owning argument, or converted to a `usize` handle. Independent
verification rejects forged scalar and return type tags containing 65.

The compiler has sixteen logical view entries and sixty-four shared lexical
name entries. Receiver capture, aliasing, range creation and assignment can
need an additional live descriptor before closing the old one. Admission must
therefore fit peak temporary usage, not just the count of named views. Existing
bounded IR limits also apply, including sixteen canonical owning slots,
sixty-four catalog nodes, 128 scalar registers and 256 instructions. CLOSE and
owner cleanup need instruction capacity too; exhaustion is a compile-time
capacity error (kind 4), not permission to omit cleanup.

The retained runtime's 32-row invocation registry is shared across activations;
it is not a promise of 32 source locals per function. Registry admission,
quotas, generation retirement and Fuel remain independent runtime gates.
View-enabled execution pays the retained view setup and instruction costs;
this source slice leaves existing opcode prices, no-view setup costs and public
Fuel default 256 / ceiling 16000000 unchanged. General reference composition and
public capability admission remain closed.

## Verification scope and remaining work

The contract is grounded in `src/value_view_source.fy`,
`src/value_view_bindings.fy`, their source binding/control-flow integration, and
`tests/m2/value_view_source.fy`. The eight source test groups contain fixtures
for actual nested byte windows and empty views, aliases/rebinding, pinned-root
rejections, receiver capture and endpoint order, unrelated calls, branch/loop
cleanup, owning return/Result propagation, runtime bounds/arithmetic failures,
fresh invocations after failure, and sentinel/escape rejection. The shared
Result/Option cleanup implementation does not imply a dedicated Option fixture
in this source test file.

The focused runner selects 23 groups: eight source-view groups, three Buffer
copy groups, three Buffer source groups, eight retained-view groups and the
existing admitted-32/rejected-33 conditional-depth regression. Its commands are:

```text
python -B tools/verify-value-view-source.py --discover
python -B tools/verify-value-view-source.py --profile development
python -B tools/verify-value-view-source.py --profile release
```

Implementation commit: `954cb96`. Windows development and release each passed
all 23 native groups, including the endpoint `break`/`continue` cleanup regression.
`--discover` lists the selection without writing. Both native runs used fresh
locked byte-identical temporary mirrors without native overrides or historical
result reuse. All 222 input hashes match checkout and Git raw bytes; all 212
production modules are LF. The original admitted-32/rejected-33 depth fixture is
byte-identical and executed in both profiles. See
[Windows evidence](../evidence/value-view-source-windows-20261107.json) and the
[input manifest](../evidence/value-view-source-inputs-windows-20261107.json).

The successful-propagation fixture stays within the unchanged sixteen monotonic
owning slots; its redundant extra return branch was removed after an early
compile-capacity failure. The final runs cover the finalized sources above.
Full language/public CLI/native Fuel matrices, Linux, allocator/OOM injection,
general stack/performance and clean-machine delivery were not rerun.

Remaining work includes general reference parameters/results, view-valued
expression joins, copy-from-view, public AllocError and intentional public
compiler/CLI admission. Text/I/O, complete Engine/Instance/host/cancellation
behavior, isolation and platform/delivery validation belong to the broader
objective; this slice does not establish them.

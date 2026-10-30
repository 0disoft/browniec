# Explicit array read sessions

The [private slice registry successor](m2-array-slices.md) now registers
independently closable ranges sharing one explicit session per root. It keeps
the source owner locked until the last entry closes. Guest syntax and automatic
lexical cleanup remain pending; bare views retain their earlier behavior.

Implementation: `f85bd4d`.

The private array owner layer now supports one explicit read session per array
root. Multiple checked range descriptors may share that session. This is a
bounded runtime guard, not guest borrow syntax, a loan-origin verifier or an
independently owned shared-loan handle for every derived view.

## Session identity and access

`begin_read(table, root, capacity)` validates the live array and full owner/arena
chain, rejects an already active or exhausted session, then marks the owner
reading. Its `ReadLease` ticket contains the root token and a separate read
generation. It creates no owner, extent, payload copy or heap allocation path.
The owner metadata adds a bool and a generation field; this is additional fixed
native state, not a claim of unchanged process memory usage.

`leased_read(table, ticket, view, index, bytes)` and
`leased_utf8(table, ticket, view, bytes)` first validate the active ticket and
require the view's exact root token. Existing range/type/backing checks then
run before payload access. One session can read a parent and its subviews;
a descriptor for another root is rejected. Ordinary readonly access remains
allowed. Invalid UTF-8 still returns false rather than an ownership error.

`end_read(table, ticket, capacity)` revalidates everything before clearing the
reading flag and advancing the read generation. Copied tickets are aliases of
one session: ending one invalidates them all. They do not count as independent
loans. An old ticket cannot read through or close a later session on the same
still-live root. Slot release/reuse also invalidates it through the root token.

An unsuccessful end leaves the session active for explicit retry. The last
generation may be used once; ending it sets zero and rejects another begin on
that root. It never wraps. The owner itself remains readable and writable after
the session ends. Releasing/recreating it gives a new root generation and a
fresh read generation, so old tickets remain invalid.

## Mutation and transfer gates

During an active session the following fail with the existing State error
before changing bytes, tokens or owner state:

- Element write, repeated fill, and destination array assignment, including
  self-assignment.
- Array result transfer preflight, which the existing CALL/ARET leave path
  invokes before changing frame tokens.
- Root release and whole-table clear. Clear preflights every reading flag before
  retiring any owner; unrelated roots are not partially cleared.
- A second begin on the same root.

Value copies remain allowed: a leased source may be copied into fresh owners,
used as an assignment source, or copied through array and mixed call-argument
batches. Newly published arrays and records start unleased. Planned table
snapshots preserve the original owner's read state. Unrelated owners may be
created, mutated or released. Record roots cannot begin an array read session.

The full metadata check rejects reading flags on dead/free owners, record
owners, or zero read generations. These checks fit the existing bounded owner
passes. Single-root gates add no new table traversal. Leased reads perform two
bounded resolutions; whole-table clear adds a separate sixteen-slot preflight.
Reads are O(16), UTF-8 is O(16+K), and all loops retain fixed table/array bounds.
This is structural accounting, not a timing or allocator measurement.

## Integration boundary

No source syntax, opcode, verifier rule, version field or existing guest Fuel
price changes. Explicit session entry/exit and leased helpers are private native
operations without guest metering. Whole-table clear is an explicit native
helper and has no VM dispatch entry. Guest integration must add borrow origins,
scope/exit balance, conflicts and appropriate charges before exposing sessions.

Bare [range descriptors](m2-array-views.md) still do not acquire or release a
session automatically. After an end, the leased-access wrappers reject the old
ticket; a still-live bare descriptor keeps its earlier unchecked-session
semantics. The trusted caller must balance session end, keep the matching table
and backing association, and route mutation through descriptor-aware APIs.
Raw native backing writes and foreign/cloned tables are not authenticated by
this guard. Session ownership and automatic Instance abort cleanup remain
future integration work.

## Focused verification

Run `python -B tools/verify-m2-array-utf8.py --profile development --read-leases`
and repeat with `--profile release`. Development and release each passed 34 native groups:
five new sessions, five range views, five owners, six array-result VM groups,
four repeated fills and nine mixed call-copy groups. Each also passed fourteen tool-free CLI
check/run sentinels covering existing public behavior and unavailable Buffer/view
syntax.

New tests compare every owner field, arena counter and backing byte after
blocked operations. They check old/copied tickets, retry after failed end,
exhaustion without wrap, sixteen simultaneous root sessions at full owner
capacity, malformed read metadata, independent copied owners, both call-copy
batch paths and array return transfer before frame-token writes. Existing view
snapshots now include both new owner fields.

The [Windows evidence](../evidence/m2-array-read-leases-windows-20261030.json)
records matching inputs, compiler/SDK identity, outcomes and retained CLI hashes.
Earlier receipts remain historical for their original inputs. Full suites,
other frontend/CLI matrices, Buffer lifecycle/Provider probes, M0, Linux, DLL
embedding, Windows isolation, packaging, allocator instrumentation and timing
benchmarks were not rerun.

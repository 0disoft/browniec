# M2 Returned Subrecords as Arguments

- Status: implemented at `7284da8c98f21500af44a2d97537497a8604cfb5`; verified in
  development and release.
- Scope: `take(make(...).child)` and deeper exact-nominal subrecord paths.
- Implementation: [`compiler::record_argument`](../../src/compiler.fy) and
  [`struct_value_source::extracted_call_argument`](../../src/struct_value_source.fy).
- Fixture: [native checks](../../tests/m2/struct_call_path_arguments.fy).
- Harness: [focused verifier](../../tools/verify-m2-struct-call-path-arguments.py).
- Evidence: [Windows receipt](../evidence/m2-struct-call-path-arguments-windows-20261028.json).

```brownie
module main;
struct Point { i32 x; }
struct Box { Point child; }
fn Box make() { return Box { .child = Point { .x = 42 } }; }
fn i32 take(Point p) { return p.x; }
fn i32 main() { return take(make().child); }
```

In a nominal record formal position, a call may return that exact record or a
record containing an exact-nominal child endpoint. The callee's actual result
type determines the anonymous destination. Existing CALL/SRET lowering evaluates
its arguments once, transfers the root owner, and releases the inner argument
captures. The destination remains absent from names during argument evaluation.

For a dotted endpoint, the existing bounded field resolver must finish at the
formal's exact nominal record. A scalar endpoint, unknown member, different
nominal identity or invalid following delimiter rejects compilation. Every
selected scalar leaf is read into consecutive scalar registers. The compiler
then emits `SDROP` for the anonymous returned root **before** `SINIT` creates the
independent immutable child capture. Scalar registers remain valid after the
root owner is released. There is no executable guest expression between these
reads, the drop and child initialization.

Dropping the returned root first lets suffix reclamation recover its extent and
any dead inner-call extents before creating the child. The child alone joins the
enclosing argument's empty-span lexical capture list. Later arguments cannot
change it. Existing mixed reverse cleanup handles normal CALL completion, early
`return`, `?`, `break` and `continue`; inner loops preserve outer captures. Source
argument effects are not rolled back on failure.

Visible binding/path extraction shares the leaf-copy helper with consumption
disabled. Its source remains live and its original diagnostic offsets are
preserved. Bare exact-record call arguments retain their existing direct result
capture without an extra child copy. This extends [named path arguments](m2-struct-path-arguments.md)
and [record result arguments](m2-struct-result-arguments.md), while
[scalar call-result reads](m2-struct-call-reads.md) retain their own grammar.

No opcode, VM, Fuel price, profile or version field changes. Each dotted result
argument uses two static record sites, one for the returned root and one for
the extracted child. At runtime the root is gone before child creation; parameter
entry still makes its independent formal copy. In the fixture, an eight-byte
parent containing a four-byte child completes under an eight-byte payload limit;
seven fails. A two-leaf, eight-byte child and its formal need sixteen bytes.
The nested `take(id(make().child))` case needs twelve bytes: returning the inner
formal keeps its extent above a dead four-byte argument prefix, which cannot be
suffix-reclaimed until the returned owner is released. Payload accounting includes
that dead retained prefix; live owners alone do not describe the peak. An
early return from pending callee arguments needs zero payload when no earlier
aggregate is live. All existing site, owner, leaf, depth, register, frame,
instruction, call and payload bounds remain unchanged.

Parenthesized aggregate calls/paths, record-result subrecord declarations,
assignments, child constructor fields and direct subrecord returns from calls
are outside this slice. Record borrows and implicit nominal conversions remain
unavailable. The callee's formal remains immutable.

## Verification

Development and release each passed seventeen native groups:
four new call-path-argument, six named-path-argument and seven record-result-
argument groups. Each profile passed 410 CLI cases: 102 new, 154 named-path-argument and
154 record-result-argument cases, with a tool-free runtime environment.

Two combined profile invocations rechecked 235 identical inputs and matching
compiler/SDK identities. Development ran from `0b504ce` with implementation files
uncommitted; release ran after `7284da8`. Both retained executable hashes
were confirmed against their CLI receipts before archival.

The new CLI matrix checks fifteen successful programs and ten type rejections
through `check`/`run` (50), six scalar tags at both extrema through one/two-level
child paths (48), and six/seven captured-call boundaries (4). Three existing
sites plus two sites per call allow six calls; seven exceeds the sixteen-site
limit. The six-call program is accepted by `check` but exhausts the unchanged
CLI 1,000,000 Fuel ceiling at runtime.

An earlier development invocation exposed an eight-byte ceiling that omitted
the retained dead prefix in the nested-call fixture. Its corrected ceiling is
twelve bytes; both final profile invocations use the corrected fixture.

Native checks additionally cover scalar-leaf ordering, `SREAD`/`SDROP`/`SINIT`
instruction order, missing-root-drop verifier rejection, eight/seven-byte
payload limits, early exits and loop reuse. The named-path fixture replaces
its formerly rejected call path with a still-rejected parenthesized call path;
its case counts remain unchanged. Earlier receipts remain historical for their
original inputs. Full suites, M0, Linux, isolation, DLL embedding, packaging,
allocation instrumentation and elapsed-time performance are outside this slice.

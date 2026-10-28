# M2 Returned Subrecords in Declarations

- Status: implemented at `e38f00ac92a7729efa8417982a8f096b0145838d`; verified for
  its original inputs. Its receipt is historical after later assignment changes.
- Scope: `let P p=make().child`, `var P p=make().child`, and deeper exact-nominal returned paths.
- Implementation: [`compiler::record_declaration`](../../src/compiler.fy) and
  [`struct_value_source::extracted_call`](../../src/struct_value_source.fy).
- Fixture: [native checks](../../tests/m2/struct_call_path_declarations.fy).
- Harness: [focused verifier](../../tools/verify-m2-struct-call-path-declarations.py).
- Successor: [returned subrecords as assignment values](m2-struct-call-path-assignment.md).
- Evidence: [Windows receipt](../evidence/m2-struct-call-path-declarations-windows-20261028.json).

```brownie
module main;
struct P { i32 x; i32 y; }
struct R { i32 pad; P child; }
fn R make() { return R { .pad = 0, .child = P { .x = 20, .y = 22 } }; }
fn i32 main() {
    let P p = make().child;
    var P other = make().child;
    other.x = 1;
    return p.y; // 22; p and other are independent copies
}
```

`record_declaration` resolves the callee and reserves its actual nominal record
destination. This is the callee's root result type, while the initializer path
must end at exactly the declared record identity. Scalar endpoints, unknown
members, different nominal types, shadowing locals, missing functions, and
non-record results reject compilation.

The inner call's arguments are evaluated once, left to right, through the existing
`call_value` path; extraction does not evaluate them again. The anonymous root
always stays unnamed; the pending declaration name is absent during those effects
and is published only after `CALL`, path resolution, and delimiter validation.
Therefore a malformed delimiter rejects before publication.

The bounded field resolver reads **all** selected scalar leaves into consecutive
registers with `SREAD`, including multi-leaf children. It then emits `SDROP` for
the anonymous root **before** `SINIT` creates the independent child copy. Releasing
first lets suffix reclamation reuse that extent. Changes to other independently owned records
leave the copy unchanged; `var` reserves a mutable child site and is not an alias.

The published child uses the shared mixed lexical cleanup, including
`array_source::release_from` for reverse-order record and array capture release.
Normal `CALL` completion, `return`, `?`, `break`, and `continue` retain their
existing behavior; inner loops preserve outer captures. Effects are not rolled
back on failure.

A bare whole-result initializer such as `let P p=make()` keeps direct ownership
transfer into the declaration and adds no child copy. This extends [named declaration
paths](m2-struct-extract.md) and [returned subrecord arguments](m2-struct-call-path-arguments.md).

Each dotted declaration uses two static sites: the returned root and extracted
child. Existing site, owner, leaf, depth, register, frame, instruction, call, and
payload limits remain. There is no opcode, VM, Fuel price, profile, or version
field change.

The native fixture requires a 12-byte parent with an 8-byte child to run at a
12-byte payload limit; 11 must fail through the quota error. It also requires the
`SREAD`/root-`SDROP`/child-`SINIT` order and verifier rejection if the drop is removed.

Parenthesized or general aggregate expressions, child constructor-field selection,
and record borrows remain unsupported. Returned-call child paths in
assignments belong to the successor.


The [direct returned-subrecord successor](m2-struct-call-path-returns.md) now
accepts `return make().child;` and deeper exact-nominal paths. Its focused
verification is separate; counts in this document remain historical for their
original inputs. Parenthesized/general aggregate returns remain unavailable.
The named-return fixture now rejects `(make().p)` instead of the newly accepted
bare call path, preserving its negative case count.

## Focused verification

Verified native selection: 22 groups, five new, five `struct_extract_source`, eight
`struct_result_source`, and four `struct_call_path_arguments`. Verified CLI
selection: 537 cases, from 152 new, 117 extract, 166 result-source, and 102
call-path-argument cases.

The 152 new CLI cases break down as follows:

- 14 positive and 10 negative programs through `check`/`run` (48);
- six scalar tags, two extrema, two bindings, two depths through `check`/`run` (96);
- seven- and eight-call site boundaries through `check`/`run` (4);
- two malformed delimiters through `check`/`run` (4).

At seven dotted declarations the 16 static sites are reached: `check` accepts,
while `run` exhausts the unchanged CLI 1,000,000 Fuel allowance. Eight declarations
report `compile_limit`. Both boundary outcomes were recorded in each profile.

Earlier receipts remain historical for their original inputs. Full suites, M0,
Linux, runtime isolation, DLL embedding, packaging, allocation instrumentation,
and elapsed-time performance are outside this slice.

## Archived verification

For the archived inputs, development and release each passed 22 native groups and 537 CLI cases.
Both invocations rechecked 238 identical input hashes and matching compiler/SDK
identities; both retained executable hashes matched their CLI receipts. Development
ran from `d492cae` with implementation files uncommitted; release ran after
`e38f00a`. This receipt remains historical for its original inputs.

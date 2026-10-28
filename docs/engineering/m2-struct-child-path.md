# M2 Constructor Child Subrecord Paths

- Status: implemented and verified in development and release.
- Implementation commit: `680f57a`.
- Evidence: [Windows receipt](../evidence/m2-struct-child-path-windows-20261027.json).
- Predecessors: [whole-binding child values](m2-struct-child.md),
  [subrecord extraction](m2-struct-extract.md).
- Tests: [native source cases](../../tests/m2/struct_child_path_source.fy),
  [CLI matrix](../../tools/check-m2-struct-child-path.py).
- Combined selection: `python -B tools/verify-m2-struct-values.py --child-path`.

## Source behavior

```brownie
module main;
struct I { i32 x; }
struct R { I i; }
fn i32 main() {
    var R p = R { .i = I { .x = 42 } };
    let R q = R { .i = p.i };
    p.i.x = 0;
    return q.i.x;
}
```

The example returns 42 with `--fuel 1000000`. A child initializer may be an
inline named constructor, a whole visible record binding, or a dotted path from
that binding to an exact nominal record endpoint. Deeper paths and preceding
nested siblings use the same bounded path resolver as declaration extraction.
Matching physical layouts do not establish nominal identity. Scalar endpoints,
unknown fields, invisible bindings, parentheses and computed paths fail. Calls
were rejected at this checkpoint; the [constructor child-call
successor](m2-struct-child-calls.md) now accepts bare exact-nominal child calls.
Locals sharing a type name remain unambiguous: only a following `{` introduces
a named constructor. Sources may be immutable or mutable.

## Capture, lifetime and cost

At the child field's position, each selected depth-first scalar leaf emits one
existing `SREAD` and one `STORE` into the parent staging slots. A later sibling
expression can mutate the source without changing this snapshot. The source
remains live; the parent becomes visible only after its complete `SINIT`.
Early return and loop transfers therefore never release a pending parent.

No opcode, verifier or VM change is required. There is no temporary owner,
record site or payload extent for the child. Compared with extracting a child
into a local first, this avoids that local's owner, site and extent, along with
its initialization, reads and drop. Each captured leaf still pays 41,281 Fuel,
plus its existing staging instructions; this is not a measured speed claim.
The one-i32 example needs two root owners and eight payload bytes. With an
eight-byte private arena it returns 42 at 174,997 Fuel, fails at 174,996 Fuel,
and fails with `array_limit` in a seven-byte arena. Its CLI Fuel boundary is
240,525, with failure at 240,524.

The complete parent still has at most 16 scalar leaves; depth/path length 16,
128-byte roots, 16 record sites, 16 shared owners, 65,536-byte arena, 128
registers and 256 instructions remain. At this checkpoint, source records were
entry-only and constructor RHS assignment and struct parameters/results were
open. Later slices add [helper-local records](m2-struct-function-source.md),
[root](m2-struct-replace-source.md) and
[child](m2-struct-subreplace-source.md) constructor assignment,
[source parameters](m2-struct-parameters-source.md), and
[source results](m2-struct-result-source.md). Record borrows remain unsupported.
Programs keep `brownie.m2-struct-nested/1`. Version JSON adds
`"struct_child_path_initializers": true`.

The later [constructor child-call slice](m2-struct-child-calls.md) shares the
owner-free `stage_part` leaf encoder with this path staging. A call result stages
the same scalar leaves and is then dropped before later fields; the path form
continues to hold its existing source owner without a temporary. The historical
source/evidence counts below remain specific to that earlier slice.

## Verification

The complete combined invocation passed in development and release without
reusing earlier results. Each profile passed 19 native groups (5 child path,
5 whole child, 5 extraction, 4 atomic) and 419 CLI cases (83 child path, 88 whole
child, 117 extraction, 131 assignment). The receipt records 99 input hashes,
compiler and executable identities, commands and outcomes. All input/compiler
hashes and the final release binary hash were rechecked before archival; both
profiles select the same 19 native identities. Cases include mixed scalar extremes,
nonzero leaf offsets, snapshot order, exact Fuel/payload boundaries, full owner
capacity, 16 leaves, 128-byte records and depth 16, with rejected depth 17.

Scalar/array and other struct CLI matrices, full native suites, M0, Linux,
isolation, DLL, packaging, allocation instrumentation and performance are outside
this selection. Earlier receipts remain historical for changed compiler, root
lock, fixture and harness inputs.

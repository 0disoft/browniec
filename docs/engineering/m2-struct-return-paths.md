# M2 Exact-Nominal Subrecord Return Paths

- Status: implemented at `d4aa643` and verified in development and release.
  Each profile passed 25 native groups and 579 CLI cases.
- Scope: `return outer.child;` for an exact-nominal subrecord, including a
  deeper path such as `return outer.middle.child;`.
- Implementation: [shared extractor](../../src/struct_value_source.fy),
  [record-result return and finisher](../../src/struct_result_source.fy).
- Fixture: [subrecord return paths](../../tests/m2/struct_return_paths.fy).
- Harness: [verify-m2-struct-return-paths.py](../../tools/verify-m2-struct-return-paths.py).
- Predecessors: [named source record results](m2-struct-result-source.md) and
  [direct constructor returns](m2-struct-return-constructors.md).
- Evidence: [Windows receipt](../evidence/m2-struct-return-paths-windows-20261028.json).

This slice lets a record-result function return a subrecord selected from a
visible record binding. The selected nominal type must exactly match the
function's result type. The callee creates an independent copy; the source
record stays live and is not moved or borrowed.

```brownie
module main;

struct Pair { i32 x; i32 y; }
struct Bundle { u8 tag; Pair pair; }

fn Pair pick() {
    let Bundle bundle = Bundle { .tag = 255, .pair = Pair { .x = 20, .y = 22 } };
    return bundle.pair;
}

fn i32 main() {
    let Pair pair = pick();
    return pair.x + pair.y; // 42
}
```

Run the program with the Brownie CLI built from this checkout. Aggregate
programs need an explicit Fuel allowance:

```sh
build/browniec run example.brc --fuel 1000000
```

The focused checks run in separate phase and profile invocations:

```sh
python -B tools/verify-m2-struct-return-paths.py --phase core --profile development
python -B tools/verify-m2-struct-return-paths.py --phase regressions --profile development
python -B tools/verify-m2-struct-return-paths.py --phase core --profile release
python -B tools/verify-m2-struct-return-paths.py --phase regressions --profile release
```

## Accepted form

`record_results::returned` inspects the token after `return`. An identifier
followed by `.` selects the path branch. `record_values::extracted` resolves the
visible record binding and walks the bounded field path to a record endpoint.
The endpoint must have the exact nominal identity of the function's declared
record result, and the path must end at a semicolon.

Deep paths select the matching depth-first leaf range. Preceding scalar fields
add one leaf and preceding record fields add their complete leaf count. The
selected record supplies the number of consecutive leaves to copy.

The operand is a bare path rooted at a visible binding. These forms remain
unsupported and fail during compilation:

- record borrows, `ref` results, and `var` results;
- general return expressions and parenthesized paths, such as `return (a.p);`;
- a field selected from a returned call, such as `return make().child;`;
- scalar fields, arrays, wrappers, and unknown endpoints as the record result;
- paths rooted at bindings that are not visible record bindings.

## Lowering and lifetime

The shared extractor performs the same independent copy used by subrecord
declaration initializers:

1. Resolve the source binding, path, exact nominal endpoint, and leaf count.
2. Emit one `SREAD` per consecutive leaf; their results occupy consecutive
   registers.
3. Allocate one immutable, anonymous, function-owned result site.
4. Emit one `SINIT` over the consecutive read results.
5. Pass the new token to `record_results::finish`.

There is no staging store/load sequence, `SCOPY`, or temporary owner. The
source remains live through path resolution, the reads, and initialization. No
binding is published for the new site before `SINIT` completes, so a nested
return or loop transfer cannot leave a pending destination to drop.

The shared finisher then walks visible bindings in reverse lexical order. It
drops other mixed arrays and records, retains the selected result, and emits
`SRET` (50). The source record remains independent of the returned copy; later
mutation of the returned record does not change the source, and mutation of the
source does not change the returned record.

## Ownership and resources

The return creates one new record owner and its payload extent. Extraction adds
no temporary owner, staging extent, or copy instruction. The source, any
parameters, and any argument captures remain live until cleanup, so peak use
includes both records.

Each syntactic subrecord return reserves one static record site. A runtime loop
reuses that site, and recursive invocations use frame-local tokens for the same
static site.

For `struct P { i32 x; } struct R { P p; }`, the live `R` and the returned
`P` require eight payload bytes. The focused IR case succeeds with an eight-byte
payload limit and fails with seven bytes. Transfer through `SRET` adds no
payload extent, but it cannot remove the source or result before the finisher
releases the source.

Existing bounds apply unchanged:

- 16 static record sites and 16 shared owner descriptors;
- 16 scalar leaves, path depth 16, and 128 planned bytes per selected source
  root;
- 128 registers, 256 instructions, 32 VM frames, and a 65,536-byte payload
  arena;
- eight call arguments and 32 call sites.

No opcode, Fuel charge, profile string, or version field changes. The existing
`SREAD`, `SINIT`, and `SRET` charges apply, and a full owner table cannot admit
the new destination even though extraction uses no temporary owner.

## Verification

The fixture has six native groups. They cover twelve successful programs and
twelve rejected programs, including forward declarations, deep paths, nonzero
leaf offsets, exact nominal identity, scalar extrema, independent mutation,
formal and recursive forwarding, mixed cleanup, and the 8-versus-7 payload
boundary.

One group compiles `return r.p;` directly and compares it with the named form
`let P p = r.p; return p;`. Both must verify and produce the same instruction
stream and record-site count. That group also runs the direct program at payload
limits eight and seven.

The harness selects 25 native groups per development or release profile:

- `core`: six new `struct_return_paths` groups;
- `regressions`: five `struct_extract_source`, eight
  `struct_result_source`, and six `struct_call_assignment` groups.

Only the regression phase builds the CLI. It then runs 579 cases per profile:
148 new return-path cases, 117 extract cases, 166 named-result cases, and 148
call-assignment cases.

Development and release each passed all 25 native groups and 579 CLI cases, in
four separate phase invocations. All four phases rechecked 205 identical inputs
and used matching compiler and SDK identities. The retained development
executable and the release `build/browniec.exe` hashes were rechecked. The
development core phase ran before implementation commit `d4aa643` with its
implementation files uncommitted; the other three phases ran after it.
The later [child call-assignment successor](m2-struct-child-call-assignment.md)
uses a direct record-result call as the source of an exact-nominal child
assignment. Its harness selects six of these return-path groups as regressions;
the counts above remain historical for this slice's original inputs.

Earlier receipts remain historical for their original compiler, fixture,
harness, and lock inputs. The focused selection does not cover full native or
CLI suites, M0, Linux, isolation, DLL embedding, packaging, allocation
instrumentation, or performance.

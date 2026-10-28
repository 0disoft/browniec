# M2 Direct Nominal Record Constructor Returns

- Status: implemented at `0a7b539`; verified in development and release.
- Scope: a direct nominal constructor as the operand of a record-result
  `return`.
- Implementation: [compiler return handling](../../src/compiler.fy), [shared
  constructor staging](../../src/compiler.fy), and [record-result
  finishing](../../src/struct_result_source.fy).
- Predecessors: [named source record results](m2-struct-result-source.md) and
  [direct record return calls](m2-struct-return-calls.md).
- Focused fixture: [constructor return cases](../../tests/m2/struct_return_constructors.fy).
- Harness: `python -B tools/verify-m2-struct-return-constructors.py`; pass
  `--phase core` or `--phase regressions`, and `--profile development` or
  `--profile release`.
- Evidence: [Windows receipt](../evidence/m2-struct-return-constructors-windows-20261028.json).

The compiler now accepts a constructor expression directly after `return` when
the enclosing function has a nominal record result and the constructor names that
exact nominal type. This extends the named-result and direct-call subsets without
adding an opcode, VM charge, profile, or version capability.

## Source form

```brownie
module main;
struct Pair { i32 x; i32 y; }

fn Pair make() {
    return Pair { .x = 20, .y = 22 };
}

fn i32 main() {
    let Pair pair = make();
    return pair.x + pair.y;
}
```

The return branch inspects the token after `return`. A type-name token followed
by `{` enters constructor-return handling. The shared
`record_values::constructor` check then requires the type name and the
constructor to have the exact nominal identity of the function's result. It
consumes the type-name and `{` prefix before field lowering starts.

Every field must appear exactly once in declaration order. Omission, reordering,
duplication, an unknown field name, a field type mismatch, and a constructor of a
different nominal type fail during compilation. Inline nested constructors and
the existing exact-nominal child binding and child path staging are accepted.

## Evaluation and publication

The return path reuses the shared `record_constructor` lowering used by
declarations, root replacement, and child replacement. It performs these steps:

1. Allocate staging slots for the record's depth-first scalar leaves.
2. Evaluate each field expression from left to right in its declared context.
3. Store each completed value into its staging slot. A nested constructor is
   traversed iteratively in source order; an exact-nominal child binding or path
   is read into the parent's slots without allocating another owner.
4. After the complete constructor has been parsed and evaluated, emit consecutive
   loads from the staging slots.
5. Allocate one immutable, function-owned, anonymous catalog site and emit
   `SINIT` for that site.
6. Pass the anonymous record token to the shared `record_results::finish` path.

The result site and any constructor binding name do not exist while field
expressions are being evaluated. A nested `return` inside a field expression
therefore leaves no pending record owner or constructor name behind. An outer
`break` or `continue` also exits before the pending constructor is published. On
the normal path, earlier local and parameter records stay live through field
evaluation and `SINIT`; only then does cleanup release them.

After successful initialization, the shared finisher walks visible bindings in
reverse order, drops mixed arrays and records other than the selected result, and
emits `SRET` (50). Formals and argument captures participate in that same
cleanup. The existing `SRET` VM path validates and transfers the record owner
without copying its payload or reserving another owner.

## Quota and ownership

Owner transfer adds zero payload extent. Construction still needs the result
record's planned extent, so a factory returning one four-byte record fits a
four-byte payload quota. Reconstructing a parameter is different: the existing
callee copy of the formal and the newly constructed result remain live together
until initialization and cleanup finish. Returning a four-byte formal through a
new four-byte constructor therefore uses eight callee payload bytes at that
point. Caller originals and any argument captures add to the same shared quota.

The direct constructor result uses one function-owned site and one immutable
anonymous token, matching the resource count of the equivalent named-local
return. The focused fixture compares the instruction streams for those forms and
exercises payload boundaries intended to distinguish constructor extent from
transfer extent.

## Limits and compatibility

Existing bounds apply unchanged:

- 16 static record sites and 16 shared owners;
- 32 VM frames, a 65,536-byte payload arena, and 256 instructions;
- 16 scalar leaves and 128 planned bytes per selected source root;
- eight call arguments and 32 call sites.

There is no new opcode, Fuel charge, profile string, or version field. Programs
use the existing record-result IR/VM selection and version metadata.

The following forms remain unsupported:

- general return expressions around a constructor;
- a parenthesized constructor, such as `return (Pair { ... });`;
- assignment of a record-result call into a child path;
- record-result calls in aggregate fields, such as `Outer { .inner = make() }`;
- scalar fields, scalars, arrays, or wrappers as the direct record-result operand;
- record wrappers, borrows, `ref` results, and `var` results.

These forms are rejected during compilation. They do not reach an uninitialized
caller destination or rely on a partial record owner.

The later [subrecord return-path slice](m2-struct-return-paths.md) supports a
bare exact-nominal `return value.inner;`, including deep paths, and is verified
in development and release with 25 native groups and 579 CLI cases per profile.
It copies the selected leaves into one independent result site and leaves the
source live. Record borrows, general or parenthesized expressions, and
`call().child` returns remain unsupported. The constructor counts below remain
historical for this slice's original inputs.

## Verification

The later [call-assignment slice](m2-struct-call-assignment.md) supports an
existing mutable root as a call-result destination. The counts below remain
historical evidence for this constructor-return slice's original inputs.

Development and release each passed 26 native groups and 532 CLI cases. The focused fixture contains six native test
groups covering eleven successful programs and eleven type rejections, plus the
direct-versus-named instruction comparison and payload quota boundaries.

The harness has two independent phases for each profile:

- `core` selects the six new `struct_return_constructors` groups.
- `regressions` selects twenty groups: eight named source-result, six direct
  return-call, and six result-signature groups.

The two phases therefore select 26 native groups per development or release
profile. The regression phase also builds the CLI and runs 532 cases per profile:
144 constructor-return, 152 direct return-call, 166 named source-result, and 70
result-signature cases. Development and release are separate invocations, so the
recorded selection is four phase/profile runs rather than one aggregate run.

The receipt records 199 matching rechecked input hashes and identical
compiler/SDK identities across all four phases; both retained CLI artifact
hashes were rechecked. Development core ran before implementation commit
`0a7b539` with those source changes uncommitted; the remaining phases ran after
it. This ordering is recorded explicitly without rerunning the completed core. Earlier named-result, direct-return, and
result-signature receipts remain historical evidence for their original compiler,
fixture, and harness inputs. The focused harness does not cover full native or
CLI suites, M0, Linux, isolation, DLL embedding, packaging, allocation
instrumentation, or performance.

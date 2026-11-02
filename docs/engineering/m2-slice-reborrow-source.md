# Lexical mutable slice reborrows

Implemented at `3a07820` after public IR admission at `409d77c`.
Windows development and release verification passed with matching inputs.

## Source contract

```text
let ref mut i32[] parent = ref mut values;
{
    let ref mut i32[] child = ref mut parent[lo..hi];
    child[0] = 42;
    let i32 answer = update(ref mut child);
}
return parent[lo];
```

All six scalar element types are supported. The parent may be an owned-array
slice, a mutable formal or another mutable child. Bare names select the entire
parent range; `[..]`, `[lo..]`, `[..hi]` and `[lo..hi]` use the existing `usize`
endpoint expression rules. Bounds are relative to the parent's selected range.
Endpoint expressions evaluate once, left to right, before the new child is
published. Exits from an endpoint expression clean only already-visible bindings.

A mutable parent permits one available mutable child at a time. Reads, writes,
length, UTF-8 predicates, another child or CALL arguments using a suspended parent
fail independent public verification before Fuel or guest effects. The parent
becomes available again when its child's lexical scope ends. Children cannot
escape through a returned borrow or an out-of-scope name. Readonly-to-mutable and
mutable-to-readonly conversions remain rejected.

Existing synchronous derived CALL admission applies: borrowed/scalar arguments
and scalar results are supported. A CALL receiving a derived mutable child with
owned array/record arguments or array/record results is rejected. Ordinary CALLs
may still create children locally and return owned arrays or records after
closing their children.

## Lowering and cleanup

The compiler reserves a derived site and emits existing BEGIN/END opcodes 61/62.
Reverse lexical cleanup emits END for children and ordinary close for other
slices. Block fallthrough, return, break, continue, tagged propagation, and array
and record result transfer all share that distinction.

`slice_cleanup_source::close` recovers a child's parent from its unique emitted
BEGIN. Each release scans at most 256 instructions during compilation. No parent
table is added to recursive lexical snapshots or `ir::Program`, and public proof
independently authenticates the forest. Bounds, opcode formats, instruction Fuel,
runtime state layouts and the external-bytecode prohibition are unchanged.

`--version --json` adds `array_slice_mutable_reborrow: true`. Existing source and
CLI profiles remain unchanged. The CLI retains its 1,000,000 Fuel cap; native VM
tests may use 16,000,000. Deep but admitted source can therefore stop with `fuel`
through the CLI while succeeding with the larger native budget. Static slice-site
capacity remains 16; a seventeenth site fails at compilation.

See [the runnable example](../../examples/mutable-slice-reborrow.brc).

## Verification

Each profile passed nine native groups: seven new source groups and the two
existing source-admission groups whose former negative fixtures are now valid.
Those fixtures were replaced with genuinely invalid mode/type combinations.
Each profile also passed 2,615 CLI cases: 68 reborrow, 74 mutable-parameter,
222 mutable-slice, 120 readonly-alias, 124 readonly-subslice and all 2,007 M1 cases.

All 438 input hashes match across the final profiles. Compiler, retained CLI
artifacts and every CLI receipt identity were rechecked. Six production source
paths differ from `101e36e`; 94 other sources match under Git LF normalization.
The [Windows evidence](../evidence/m2-slice-reborrow-source-windows-20261103.json)
records the inputs, commands, native outcomes, artifact identities and limits.

Coverage includes six scalar types, owned/formal/nested children, derived CALLs,
recursion, ordinary aggregate results, lexical exits, endpoint evaluation,
suspended-parent rejection, runtime bounds/arithmetic errors, Fuel and static-site
limits. The retained CLI harness runs with an empty tool PATH. The 16-site chain
passes source admission and reaches the CLI Fuel limit; the 17-site chain fails
compilation. Native recursive success uses the larger native Fuel budget and is
not counted as a successful CLI execution at that budget.

Full native suites, other M2 matrices, Linux, isolation, packaging, allocator,
native size/stack measurements and timing are outside this slice. Local commits
only; no push, release or deployment.

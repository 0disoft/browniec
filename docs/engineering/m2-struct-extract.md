# M2 Subrecord Declaration Initializers

- Status: implemented and verified stepwise in development and release.
- Implementation commit: `f65a1d7`.
- Evidence: [Windows receipt](../evidence/m2-struct-extract-windows-20261027.json).
- Predecessor: [child binding initializers](m2-struct-child.md).
- Tests: [struct_extract_source.fy](../../tests/m2/struct_extract_source.fy).
- Combined harness: `python -B tools/verify-m2-struct-values.py --extract`.
- CLI harness: `tools/check-m2-struct-extract.py`.

## Source and ownership

```brownie
module main;
struct I { i32 x; }
struct R { I i; }
fn i32 main() {
    var R p = R { .i = I { .x = 42 } };
    let I i = p.i;
    p.i.x = 0;
    return i.x;
}
```

The example returns 42. Use `--fuel 1000000` for aggregate programs. A `let` or
`var` record declaration may copy a record endpoint reached through a visible
record binding. The selected nominal type must exactly equal the declared type;
matching fields alone are insufficient. Source and destination may each be
immutable or mutable. A deeper path such as `p.c.right` may select a record that
itself contains nested records.

The source remains live. The result is an independent value with its own static
site, owner, and payload extent. The destination name is invisible throughout its
initializer and becomes visible after initialization. Normal scope, return,
break, and continue cleanup applies to both values. This operation copies; it
does not move or borrow the source.

## Resolution and lowering

The existing bounded path resolver now identifies both scalar and record
endpoints. Scalar reads and writes explicitly reject record endpoints. Extraction
requires a record endpoint and a terminating semicolon; calls, parentheses, and
general aggregate expressions are not admitted.

Preceding scalar fields add one to the source leaf ordinal; preceding record
fields add their depth-first scalar leaf count. The selected nominal record
supplies the number of consecutive leaves to copy. One `SREAD` per leaf produces
consecutive typed registers, which directly feed one `SINIT`. There are no
intervening user expressions, staging `STORE`/`LOAD` instructions, `SCOPY`, or
temporary owner. Existing initialization normalizes destination padding.

No opcode, verifier rule, or VM rule changes. Existing preparation, access,
initialization, and cleanup Fuel charges remain. Each copied leaf costs one
`SREAD` (41,281 Fuel), and the new root pays `SINIT` (46,145 Fuel), in addition to
the remaining program operations. These are abstract Fuel charges, not timings.
For the minimal `R { I i; }` example, CLI execution succeeds with 240,523 Fuel
and fails with `fuel` at 240,522. Its two four-byte roots fit an eight-byte private
arena; seven bytes fail with `array_limit`. Depth 2/8/16 extraction programs run
within the CLI allowance, and a 16-leaf, 128-byte selected record is admitted;
a 17-leaf source root reports `compile_limit`.

The source bounds remain: 16 scalar leaves, depth 16, a 128-byte selected root,
16 record sites, the shared 16-owner table, a 65,536-byte arena, 128 registers,
and 256 instructions. A full owner table cannot admit the new destination even
though copying uses no temporary owner.

## Discovery and unsupported forms

Programs using this syntax retain `brownie.m2-struct-nested/1`. Version JSON adds
`"struct_subrecord_initializers": true`.

Subrecord assignment is handled by the [successor](m2-struct-subassign.md).
Subrecord paths as constructor child values, constructor RHS assignment, helper-local records, for-header record
declarations, struct parameters/results, borrows, and general aggregate
expressions remain unsupported. Bare whole-binding copies keep their existing
`SCOPY` lowering.

## Verification

Development and release each passed 26 native groups and 2,915 CLI cases.
The native groups are 5 extraction, 5 child, 6 nested, 5 values, and 5 write.
CLI counts are 117 extraction, 88 child, 128 nested, 110 copy, 120 write, 144
values, 124 declarations, 115 array-literal assignment, and 1,969 scalar.
The selection includes extraction, child,
nested-constructor, value, and write native groups, plus their related CLI and
scalar regressions. Cases cover all scalar types, nominal identity, nonzero leaf
offsets, nested endpoints, independent mutation, lexical/loop cleanup, owner
quota, and depth/size bounds.

Full native suites, full array CLI matrices, M0, Linux, isolation, DLL, packaging,
allocation instrumentation, and performance are outside this selection.

Development's 26 native groups passed in the first aggregate attempt. Its CLI
run stopped on two old expectations that classified dotted record initializers
as syntax errors: scalar and missing endpoints now correctly report `type`.
Only those CLI expectations changed afterward. The unchanged development native
result is reused, while all final CLI selections and the complete release native
selection ran afterward. The original aggregate did not complete as one
invocation. The receipt records 92 input hashes, compiler and CLI artifact hashes,
commands, and native reuse provenance. All input and compiler hashes, the reused
native report hash, and the final release binary hash were rechecked before
archival. Both profiles select the same 26 native identities. The first
focused extraction test also needed a fixture correction: 42 aggregate loop
iterations exceeded its 1,000,000 Fuel allowance, so the cleanup test uses two
iterations. The passing 26-group result includes that corrected native fixture.

The assignment successor changes compiler and fixture inputs, making this receipt
historical for that successor.

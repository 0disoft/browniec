# Linear record dependency resolution

`struct_layout::plan` is used by record verification, field access, copies,
argument copies and result validation. Its former ascending readiness passes
rescanned unresolved records' fields until all children had a layout. Declaration
order could therefore make dependency resolution take O(R^2 F), where R is the
number of nominal records and F is their maximum field count.

The resolver now uses an explicit depth-first cursor. It resumes each parent's
field position after completing a child, skips children with a completed plan,
and rejects an edge to an active ancestor as a cycle. Each dependency field is
inspected once, so dependency resolution is O(R F). The complete fixed-capacity
metadata validation still runs first, and layout arithmetic is unchanged.

The cursor is initialized once per plan, including catalogs of independent flat
records. Its fixed arrays contain 32 usize record IDs, 32 u8 field positions and
32 bool active flags: 320 bytes on the verified x64 target, excluding other
locals. No heap allocation or native recursion is added. Temporary traversal
depth can reach 32 to diagnose cycles; admitted structural depth remains 16.
No partial plan is returned on failure. Multiple independent semantic defects
may be encountered in DFS order rather than readiness-pass order; metadata
validation still precedes semantic resolution.

## Counted work

The dense regression fixture fills all 32 records and 512 field slots with two
independent depth-16 chains. Each parent's dependency is its last field. All
scalar fields are bool, so the maximum record is 241 bytes and the graph is a
valid private layout at limit 241. This fixture exercises the planner directly;
it does not claim source support for a 241-byte record.

From the old and new loop structures, dependency field inspections are:

- Before: 16 * (32 + 30 + ... + 2) = 4,352.
- After: 32 * 16 = 512, an 88.2% reduction.
- Including the unchanged 512 validation and 512 layout field inspections:
  5,376 becomes 1,536, a 71.4% reduction in these field-loop iterations.

These are derived operation counts for the specified fixture, not elapsed-time
measurements. Existing conservative VM Fuel prices remain unchanged. Layout
revalidation at every public storage boundary is preserved; this change adds
no cache or caller-supplied trusted plan.

## Focused verification

Development and release each passed 24 native groups and 166 source record-result
CLI cases. Both builds passed locked compilation. These are focused checks of
this refactor, not a rerun of the full earlier source-result matrix.

The native selection is `struct_layout`, `struct_layout_order`,
`struct_nested_storage` and `struct_result_vm`. It covers scalar widths, padding,
forward/shared dependencies, invalid metadata, cycles, depth, quota, storage
operations, result transfers and Fuel failure. The two new groups compare all
sizes, depths, alignments and offsets under reversed record IDs, then exercise a
32-node cycle and an over-depth acyclic chain.

The [Windows receipt](../evidence/struct-layout-traversal-windows-20261028.json)
records exact commands, input hashes, compiler and binary identities, and actual
outcomes. Full suites, Linux, M0, packaging, isolation and elapsed-time benchmarks
are outside this focused change. Earlier receipts remain evidence for their own
original inputs.

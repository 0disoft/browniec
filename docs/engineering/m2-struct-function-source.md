# M2 Source Helper-Local Records

- Status: implemented at `98a4525`; verified in development and release.
- Scope: existing record declaration and field forms in ordinary scalar,
  wrapper-returning, and array-returning helper functions.
- Predecessor: [frame-local record VM](m2-struct-function-vm.md).
- Implementation: [source lowering](../../src/compiler.fy),
  [record source helpers](../../src/struct_value_source.fy),
  [record-site allocation](../../src/ir.fy),
  [array result cleanup](../../src/array_result_source.fy), and
  [version output](../../src/main.fy).
- Focused fixture: [helper-local record cases](../../tests/m2/struct_function_source.fy).
- Example: [recursive helper records](../../examples/helper-records.brc), returning 42:
  `browniec run examples/helper-records.brc --fuel 1000000 --json`.
- Aggregate selection: `python -B tools/verify-m2-struct-values.py --function-source`.
- Evidence: [Windows receipt](../evidence/m2-struct-function-source-windows-20261027.json).

The source compiler no longer reserves record declarations for the entry
function. Record-introducing forms inside ordinary helpers now allocate through
`ir::record_in` with the lowering function from `locals.function`, instead of
the entry-owned `ir::record` wrapper. Constructor lowering uses `table.function`;
copy and subrecord extraction use `names.function`. The binding is declared only
after the complete initializer and its allocation succeed.

## Supported helper forms

The existing record grammar is available in scalar helpers, helpers that return
an `Option` wrapper, and helpers that return an array. The supported forms are:

- nested and scalar constructors, including child values copied from visible bindings or field paths;
- scalar field reads and writes through multi-segment paths;
- whole-root copy initialization and assignment;
- child copy, subrecord extraction, and child assignment;
- root and child constructor replacement.

A callee can create, read, update, copy, extract from, and replace its own
records before returning a scalar, wrapper, or array value. Records owned by one
function do not become parameters, results, or borrows of another. Normal helper
returns release local records through the existing control-transfer cleanup.
For array-returning helpers, `array_result_source::finish` now also drops local
records in reverse lexical mixed array-record order before `ARET`, while
preserving the returned array. The previous finisher emitted only array drops
because records were entry-only. New focused cases cover named, literal, and
direct-call array returns beside local records. The fix adds no backend opcode
or Fuel change.

## Sites, frames, and cleanup

The sixteen static record sites remain shared by all functions. Each
`record_in` call reserves one site and records its owner; the verifier and VM
require constructor, copy, assignment, replacement, and extraction operands to
belong to the active function. The runtime still has sixteen shared owner
descriptors and one payload arena.

Record tokens are frame-local. The VM accepts up to 32 frames, so recursive and
forward or mutual scalar calls can each hold records for the same static sites
while parent records stay live. Owner and payload quotas remain shared, and a
record allocated in one frame cannot be accessed from another.

Lexical exits, returns, question-mark propagation, and loop transfers keep the
existing reverse-order cleanup across arrays and records. Only bindings visible
before the pending initializer are dropped; a name becomes visible after the
complete constructor, copy, or extraction finishes. Native VM opcodes and Fuel
charges are unchanged.

## Bounds and version

Source roots remain capped at 128 planned bytes, scalar-leaf staging at sixteen
leaves, record nesting and path length at sixteen, and record sites at sixteen.
The shared sixteen owners, 65,536-byte payload cap, 128 registers, 256
instructions, and 32 VM frames are unchanged.

`--version --json` adds the boolean `struct_helper_locals: true`. Existing
profile strings are unchanged; this slice introduces no new profile.

Record parameters, record results, borrows, aggregate record expressions, and
record declarations in `for` headers remain unsupported. Constructors are still
declaration initializers or assignment right-hand sides, and record values
cannot flow through helper signatures.
Programs containing aggregate sites still reject calls into the entry function.

## Status summary

Source helper-local records are implemented for ordinary scalar, wrapper-returning, and array-returning helpers. Constructor, copy, and subrecord-extraction paths assign sites with `ir::record_in` and the lowering function, so existing record forms run in callee frames under the shared sixteen sites and owners, 128-byte roots, sixteen-leaf staging, and 32 VM frames. Array-returning helpers now drop local records in reverse lexical mixed order before `ARET`, preserving the returned array. Development and release each passed 48 native groups and 2,860 CLI cases. Development completed stepwise; release completed the aggregate.

## Verification

Default harness: `python -B tools/verify-m2-struct-values.py --function-source`.

Evidence: [m2-struct-function-source-windows-20261027.json](../evidence/m2-struct-function-source-windows-20261027.json).

Each development/release profile passed 48 native groups and 2,860 CLI cases across nine matrices:
89 helper-local record, 146 value, 110 root-copy, 128 nested, 105 child replacement,
99 root replacement, 83 child-path, 131 subrecord-assignment, and 1,969 M1 cases.
The native selection completed before correcting its expected group count from
47 to 48; CLI matrices then ran individually. An obsolete root-replacement
expectation in the nested matrix was updated and that matrix rerun. Compiler,
source, and native fixture inputs did not change during these tooling fixes.

Release completed `python -B tools/verify-m2-struct-values.py --function-source --profile release`.
The default selection still verifies both profiles. Cross-profile native identities,
all 153 input hashes, the compiler hash and current release executable were
independently rechecked before archival. SDK lock identity is unchanged; the
compiler remains `4ce1264273be`.
Earlier receipts are historical for changed frontend, root lock, tests and tooling.
Full native suites, other struct/array matrices, M0, Linux, packaging, DLL,
isolation, allocation instrumentation and performance were not run.

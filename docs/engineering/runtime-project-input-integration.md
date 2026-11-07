# Private project sources and binary input integration

Three local implementation increments are now recorded on `main`:

| Slice | Commit | Native evidence per development/O2 profile |
| --- | --- | --- |
| Owning shared-byte input Program | `070ceaa` | Five groups: complete source/independent IR proof, returned input provenance, original source diagnostics, unchanged zero-argument execution and original captured depth 32/33 fixture |
| Anchored project source compile/run | `40f2c45` | 18 actual Unicode-root OS/project/compiler/VM cases, including explicit entries returning 42/99, retained sources after file rewrite, requirements-before-Fuel, traps and allocation/handle cleanup |
| Bounded Windows binary reader | `564bd6f` | Three hook-free production groups, six explicit test groups, four separate injected syscall-return cases and the old-branch expected failure |

The [input Program](module-input-program.md) is real owning executable admission,
not input execution. The [project loader](project-source-loader.md) now composes
explicit manifest members, anchored acquisition, exact source/header binding and
the actual unchanged zero-argument project compiler/VM. Its limits remain sixteen
files/4096 source bytes, and requirements are denied before Fuel/guest work.
It does not create an Engine association or public CLI capability.

The [binary reader](runtime-input-reader.md) owns exact bounded binary input from
an explicit trusted path or synchronous disk/byte-pipe handle, retaining NUL and
arbitrary bytes. No guest filesystem grant, ambient stdin, Fairy adapter or VM
binding is implied. Output is published only after EOF and internal handle close.
Failed reads release unpublished storage, but consumed cursor/pipe bytes cannot
be restored. Synchronous reads may block; deadline/R03 work remains open.

## Reviewed parallel integration and evidence reuse

The two workers edited disjoint ignored mirrors. Root integration and commits
were serialized. Cross-review found no project loader defect and one pipe EOF
edge: Windows documents a successful zero-byte pipe read after a zero-byte
[WriteFile operation](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-readfile#pipes).
The reader now rejects that no-progress result without publication or retry,
while preserving disk and broken-pipe EOF.

Four actual zero-byte-write probes ran in each normal production/test image.
None observed a successful zero-byte read on this host; those observations do
not reproduce that branch. A separate explicit `/FI` syscall-return seam checks
four boundaries, unchanged caller handle validity, no prefix publication, no
retry and zero retained staging owners. Restoring only the old EOF branch fails
the precise no-progress/no-publication assertion in both profiles. Normal builds
contain no syscall interception; production objects contain no allocator hooks.

The project verifier ran in the final root. Reader native results were reused
from its reviewed isolated mirror only after all six executed inputs matched
final root bytes; integration changed no implementation. Command logs, objects,
executables and default 1MiB/4KiB PE stacks were hash-checked. CL/_CL_/LINK and
stack overrides are rejected. No fairyc checkout was modified or rebuilt.

- [Input Program evidence](../evidence/module-input-program-windows-20261107.json)
- [Project loader evidence](../evidence/project-source-loader-windows-20261107.json)
- [Binary reader evidence](../evidence/runtime-input-reader-windows-20261107.json)
- [Aggregate input evidence](../evidence/runtime-project-inputs-windows-20261107.json)

All **258** union inputs match both raw final checkout bytes and committed Git
blobs, checked with one `git cat-file --batch`. All **232** production modules
retain LF. Project/reader integration adds no root source/lock change, so the
prior root check (240 sources/2703 MIR functions) and both unchanged five-group
input Program reports remain applicable. Their 241 inputs and exact receipts
were verified; these are retained results, not newly repeated execution.
Unchanged broad CLI/language suites and remote CI were not repeated.

## Next implementation slice

Actual input execution must preserve the accepted **1MiB** ceiling. Existing
image/array span words represent at most 4096 bytes. Add an immutable input window
domain per invocation/frame/site, borrowing the exact Snapshot throughout the
run; never relabel input as a literal or silently clip it into an array.

Connect PARAM/aliases/ranges, authenticated CALL staging and selected-origin
returns, then READ/LEN and `module_input_program::run`. Existing loan/image
paths, owner limits and dispatch/CALL/leave prices remain. Preflight input
metadata costs and publish child/parent windows only after native enter/leave
succeeds. Check every range by subtraction before addition.

Focused native coverage must include lengths 0/4096/4097/1MiB, the final byte,
empty/nested ranges, 1MiB+1 rejection, returned input subranges, mixed image/loan
origins, wrong-origin/range expansion, Fuel failure/trap cleanup and Program reuse
with a different Snapshot. Preserve unchanged zero-argument and depth fixtures.
Engine/OS reader association, actual staged guest output, complete accounting,
bounded resumability/deadlines, host/restricted/embedding and the full accepted
inventory remain open. Public gates/capacities and Fuel default256/ceiling16000000
are unchanged. Workers are closed; all changes are local, with no remote delivery.

# Native module retention

Date: 2026-11-05. This is a prerequisite for retained project execution and a
narrow R02 improvement. It preserves the module APIs, admission and capacities.

## Small owning values

`module_index::Index` now owns one initialized private `Stored` value through the
pinned SDK's typed `std::vec::Vec`. That value contains the exact original source
snapshot and the completed module/import/declaration table. Header preparation
and import binding finish before storage publication. Read-only accessors borrow
the same retained value; there is no serialization, source replay or raw pointer
interface.

`module_program::Program` similarly owns one private value containing both the
original source snapshot and the completely admitted `PublicProgram`. Keeping
only the executable behind storage would leave the large source snapshot in each
owning return slot. The complete payload now stays behind the typed owner.
Source duplication and storage publication run after recursive lowering and
independent code/image admission have returned.

Both constructors reserve space for one value before moving ownership into the
vector. SDK cleanup destroys the initialized value and its child resources once.
Failed construction consumes and cleans up its private inputs without publishing
an Index or Program. No mutable vector, source, declaration table or admitted
code borrow is exposed. Repeated execution borrows the same Program and still
creates fresh existing VM state.

## Allocation and compatibility

Index allocation failure is the new typed `module_index::Failure::Allocation`
with no fabricated source location. Program storage allocation failure uses the
existing diagnostic allocation code 15, also without a source location. These
paths remain separate from compile limits, image quotas and source errors.
The toolchain pin is unchanged; the lock now includes its optional typed-vector
SDK module.

This adds native retention allocations. It does not establish an Engine memory
ceiling, preallocation contract, allocation-failure injection result, peak stack
bound or process-RAM measurement. Complete accounting and OOM containment remain
R02 obligations. Compiler scratch, source/operand/file limits, runtime prices,
CLI limits, independent proof and public delivery flags are unchanged.

## Verification

Run the focused selection in both profiles:

```text
python -B tools/verify-static-execution.py --profile development --selection module-retention
python -B tools/verify-static-execution.py --profile release --selection module-retention
```

It selects the existing six module-index and ten module-program groups. These
cover original-byte identities and diagnostics, imports/visibility/cycles,
declaration bounds, exact scalar Fuel, array and record ownership, shared-byte
results, image quotas, repeated execution and the unchanged combined legacy and
retained depth-32 success/depth-33 rejection case. Results are recorded only after
the complete selected run passes on unchanged inputs.

The development foundation passed all 16 groups on 154 matching main inputs,
148 LF production modules and a 253-file discovery identity. Its locked LF
mirror passed. Two other discovery fixtures were updated only to handle the
new allocation error exhaustively; their hashes are retained separately.
See the [foundation evidence](../evidence/native-module-retention-windows-20261105.json).
The [project successor](project-program.md) subsequently passed all 16 foundation
identities within its 30-group integrated release selection on 157 matching final
inputs. Its separate 14-group development run covers the new project/source
behavior. The original development foundation remains scoped to its own earlier
snapshot; it is not reused as a final-input development result. See the
[integrated evidence](../evidence/project-program-windows-20261105.json).

Project-facade experiments and generated-C diagnostics are excluded from product
verification. The [project successor](project-program.md) now retains project
requirements and connects exact project binding to complete executable admission.
Filesystem collection, project CLI, grants, Engine/Instance and the full objective
remain open.

# M2 Private Struct VM Dispatch

- Status: private entry-only dispatch implemented. The original 38-group and
  115-case receipts are historical after atomic verifier/VM/test changes.
- Scope: metered execution of struct IR opcodes 41..46, with opcode 47 supplied
  by the [atomic successor](m2-struct-subassign-atomic.md). This slice adds no source struct grammar, record parameters or results, or borrows.
- Implementation: [src/struct_vm.fy](../../src/struct_vm.fy), [src/vm.fy](../../src/vm.fy), [src/array_vm.fy](../../src/array_vm.fy), and [src/array_owners.fy](../../src/array_owners.fy).
- Tests: [tests/m2/struct_vm.fy](../../tests/m2/struct_vm.fy).
- Harness: [tools/verify-m2-struct-layout.py](../../tools/verify-m2-struct-layout.py) with `--vm`.
- Evidence: [native receipt](../evidence/m2-struct-vm-windows-20261026.json) and [focused CLI receipt](../evidence/m2-struct-vm-cli-windows-20261026.json) record both profiles.
- Predecessor: [private struct IR and verification](m2-struct-ir.md).
- Successor: [declaration-only source structs](m2-struct-source.md), followed by the
  [source struct copy initialization and assignment](m2-struct-source-copy.md) and
  the [source nested structs](m2-struct-source-nested.md).

The VM now executes the private, entry-owned record instructions introduced by
the IR slice. Scalar registers still hold scalar values; record bindings hold
owner tokens. A record token names a descriptor in the same owner table used by
arrays. The [bounded source adapter](m2-struct-values.md) now attaches record layouts
and lowers entry-owned scalar-field construction and reads. The
[nested adapter](m2-struct-source-nested.md) folds inline child constructors into
one root `SINIT` and resolves scalar paths to leaf ordinals. Its source staging
cap is 16 leaves; this VM still accepts 128. Broader struct source conformance
remains incomplete.

## Dispatch and storage

`vm::run` verifies the complete program before creating runtime state. If either
the array binding catalog or record binding catalog is nonempty, it prepares one payload buffer
with capacity 0 through 65,536 bytes and charges `1 + capacity` Fuel before
allocation. Pure scalar programs keep their previous preparation and instruction
prices. An array limit above 65,536 is rejected before preparation.

`struct_vm::State` adds sixteen entry binding tokens. It has no owner pool of its
own: arrays and records share `array_vm::State.owners` and its single payload
arena. The existing sixteen-slot allocation order, generations, release path, and
quota therefore apply to both kinds. Record opcodes are accepted only in entry
frame 0. The verifier also rejects calls into entry while any array or record
binding exists.

## Instruction behavior

| Opcode | Name | Behavior |
| --- | --- | --- |
| 41 | `SINIT` | Consumes every depth-first scalar leaf, in declaration order, from consecutive registers. The destination must be dead. |
| 42 | `SCOPY` | Creates an independent record copy from a live source with the same nominal record ID. |
| 43 | `SREAD` | Reads the flattened scalar leaf selected by ordinal `b` into scalar register `dst`. |
| 44 | `SWRITE` | Writes scalar register `b` to the flattened leaf selected by ordinal `a`. The binding must be live and mutable. |
| 45 | `SDROP` | Releases a live record binding and clears its token. |
| 46 | `SASSIGN` | Overwrites a live mutable destination from a live source with the same nominal record ID. |

Leaf ordinals are resolved iteratively through existing owner field-path APIs;
they are not source field names or byte offsets. The traversal permits at most
128 scalar leaves and depth 16, with at most 4,096 traversal iterations. Initialization
needs two traversals: one for the register span and one inside encoded storage.
The other operations need at most one traversal.

Copy creates a new generation-checked owner and preserves the source. Assignment
writes the existing destination extent and allocates no new descriptor or extent.
Drop clears the binding; dead middle extents remain charged until suffix release.
Reads validate the selected scalar, including canonical bool bytes. Creation,
copy and assignment validate all supplied or copied bools before publication;
field writes validate the new scalar. Descriptor generations and nominal record
identities reject stale or substituted tokens.

## Fuel

Every struct instruction is charged before path traversal, owner validation,
snapshot staging, token mutation, or register mutation.

| Opcode | Charge | Breakdown |
| --- | ---: | --- |
| `SINIT` | 46,145 | `2 * 18,432 + 2 * 4,096 + 1,024 + 65` |
| `SCOPY` | 42,049 | `2 * 18,432 + 4,096 + 1,024 + 65` |
| `SREAD` / `SWRITE` | 41,281 | `2 * 18,432 + 4,096 + 256 + 65` |
| `SDROP` | 65 | `65` |
| `SASSIGN` | 60,545 | `3 * 18,432 + 4,096 + 1,024 + 129` |

The fixed 18,432 planning allowance covers at most 17,408 field visits. The
4,096 traversal allowance covers the 128-leaf, depth-16 bounds. These are
accounting units that cover complete record planning, staging, codec, padding,
and owner scans. They are not measured CPU instruction counts, stack bytes, or
throughput measurements.

Insufficient Fuel returns error kind 8 without changing the complete token,
owner, payload, and register snapshots tested by the suite. Fuel is a step input,
not a mutable budget shared by reference: a successful step returns its remaining
value. Owner, bounds, and malformed-state failures abort the invocation. Runtime
failure does not roll back earlier guest effects.

## Trusted helper boundary

Direct helpers require one verified immutable `struct_meta::Catalog` and a stable
backing region for the lifetime of the owner table. The contract does not provide
a catalog fingerprint, a cross-Instance capability, allocator integration, or
protection from a caller changing the catalog or backing region.

The private runtime covers six scalar types, nested records, independent copies,
exact-ID assignment, stale-generation rejection, and complete initialization.
Source declarations and immutable layout catalogs now exist at compile time.
Entry-owned scalar-field construction and reads now have source lowering. The
[field-write successor](m2-struct-write.md) adds one-level mutable scalar-field
writes through `SWRITE` and passed 24 native groups plus 2,472 CLI cases per
profile ([historical receipt](../evidence/m2-struct-write-windows-20261026.json)).
The current [source-copy successor](m2-struct-source-copy.md) connects bare-name
copy initializers to `SCOPY` and whole-record assignment to `SASSIGN`; its
development and release verification is stepwise complete. The
[nested successor](m2-struct-source-nested.md) folds an iterative depth-first
constructor tree into one `SINIT`, uses leaf ordinals for scalar paths, and
reuses `SCOPY`/`SASSIGN` for whole roots. Source staging allows 16 leaves while
this VM keeps its 128-leaf bound; subrecord values, struct parameters/results,
borrows, and full source conformance remain unsupported.

## Verification status

`python -B tools/verify-m2-struct-layout.py --vm` passed 38/38 groups in each
development and release profile: eight struct-VM, nine struct-IR, six array-VM,
nine array-call, and six array-result-VM groups. The new groups cover six scalar
types, exact Fuel and underfuel snapshots, shared payload/owner pressure,
corrupt bools, stale and substituted tokens, depth-16 and 128-leaf paths, full
record tables, retained holes and entry records across an array-using callee.
The complete all-opcode program returns 99 with exactly 231,452 Fuel and a
16-byte payload capacity; one fewer Fuel unit fails.

The native receipt binds matching test identities and stable input hashes to the
pinned Fairy C compiler `4ce1264273be` and SDK. The separate focused CLI receipt
records 115 passed existing repeated-literal assignment cases per profile,
including composed depth-10 success/depth-11 compile-limit and previous array
Fuel boundaries. These CLI cases do not implement source struct coverage.

The earlier `--ir` run passed 46 native groups per profile, and its focused CLI
suite passed 115 cases per profile. Those receipts are historical for changed
runtime, test, harness, and root-lock inputs. The current VM and CLI executions
above are separate results. Full native suites, scalar and array CLI matrices,
M0, Linux, isolation, DLL, packaging, allocation instrumentation, and performance
were not rerun.

Declaration-only source structs now attach layouts without record bindings or
struct opcodes. Its [bounded value successor](m2-struct-values.md) is the
historical read baseline for scalar-field construction and reads. The
[field-write successor](m2-struct-write.md) adds verified one-level mutation;
the [source-copy successor](m2-struct-source-copy.md) adds bare-name copy
initialization and whole-record assignment with stepwise development/release verification. The [nested adapter](m2-struct-source-nested.md) adds inline
child constructors, multi-segment scalar paths, and whole-root copies; its
complete harness passed 36 native groups and 2,710 CLI cases per development
and release profile on corrected inputs. The
[nested receipt](../evidence/m2-struct-source-nested-windows-20261027.json)
records both artifacts and the corrected release regression. Subrecord values remain unsupported. Struct VM dispatch and its
Fuel schedule are implemented privately. The earlier source declaration checks
passed stepwise in both profiles:
23 native groups and 2,208 CLI cases each, including 124 source cases. The
[receipt](../evidence/m2-struct-source-windows-20261026.json) records the executed
checks and the harness-only path correction. The corrected aggregate harness
was syntax-checked, not rerun.

The [atomic subrecord successor](m2-struct-subassign-atomic.md) adds opcode 47
through `struct_vm::subassign`, with one 131,072-Fuel prepayment and canonical
byte staging before target mutation. `step` retains the original 41..46 dispatch
interface. The successor selection includes all eight existing VM groups; the
unknown-cost negative case now uses opcode 48.

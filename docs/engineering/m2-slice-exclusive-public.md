# Public mutable scalar slices

Public `check` and `run` now admit independently verified owned mutable slices
over all six scalar tags: `i32`, `bool`, `i64`, `u8`, `u32` and `usize`.
Version JSON reports `array_slice_mutable: true`. Existing profiles, result
schemas, Program fields, opcodes, Fuel prices and CLI Fuel limits are unchanged.

```text
module main;
fn i32 main() {
    var i32[4] points = [0; 4];
    {
        let ref mut i32[] selected = ref mut points[1..3];
        selected[0] = 20;
        selected[1] = 22;
    }
    return points[1] + points[2];
}
```

The example is retained as [mutable-slices.brc](../../examples/mutable-slices.brc)
and returns 42 through the native CLI without runtime build tools:

```text
browniec check examples/mutable-slices.brc --json
browniec run examples/mutable-slices.brc --fuel 1000000 --json
```

## Admission and behavior

`verify` now calls the same complete validation as `inspect`, without the final
blanket exclusive-site rejection. Metadata, scalar tags, defined operands,
same-function mutable roots, exact branch/backedge live sets and reverse lexical
cleanup are still proved before VM allocation, Fuel or dispatch. Malformed IR,
readonly stores, root payload access/copies during a write loan, conflicting
sessions, escaping loans, rootless mutable formals and reborrows remain invalid.
Native negative tests check both `verify` and VM entry with zero Fuel and an
invalid payload limit, proving that validation wins over execution preparation.

Source declarations use `let ref mut Tag[] p = ref mut a[lo..hi];`. Both `mut`
markers are required. The root is an existing same-function mutable owned array.
Whole, explicit, computed, open and empty ranges are supported. Read and write
indices are relative to the selection. `.len` reads the selection length, and
`text::valid_utf8(p)` scans selected `u8` bytes only. Even an empty selection locks
its entire root. Other independent roots can retain shared or exclusive loans.

The binding cannot be rebound. Scalar stores evaluate index then value once,
and use opcode60 with the exact element tag. Endpoints run left to right before
ticket publication. Successful scope exit, return, propagation, break and
continue close loans before dropping roots. Execution errors use the existing
atomic mixed-pool drain; successful cleanup preserves the original error, while
cleanup failure remains visible and retains metadata. Earlier writes are not
rolled back. See the [source contract](m2-slice-exclusive-source.md) and
[metered adapter](m2-slice-exclusive-vm.md) for implementation details.

Readonly slices and CALL arguments retain their existing public behavior. This
stage does not add mutable parameters, slice results, temporary roots, mutable
aliases/subranges, readonly aliases of writers, or readonly CALL coercions.
`var ref mut` and whole-handle assignment remain rejected. These restrictions
apply in both source and independent IR validation.

## Bounds and Fuel

The existing ceilings remain: 16 declared slice sites per Program, 16 live shared
and exclusive tickets combined, 16 live payload owners, 32 VM frames, 128 scalar
registers and 256 instructions. The CLI payload arena remains 65,536 bytes.
Bounds, malformed scalar values, stale tickets and invalid backing fail through
checked pool/owner APIs before publication. Writes stage at most eight bytes.

Instruction prices remain open 65,537; close/length 4,097; read 4,130 + scalar
width; write 4,130 + twice the scalar width; and UTF-8 4,097 + four times the full
origin length. UTF-8 scans only selected bytes despite prepaying the full bound.
The public wrapper also pays the existing 65,537 CLI backing-preparation price.
Fuel is a logical work budget, not a CPU-time measurement.

## Verification selection

```text
python -B tools/verify-m2-slice-elements.py --profile development --public-exclusive
python -B tools/verify-m2-slice-elements.py --profile release --public-exclusive
```

The selection includes 26 native groups: six source, six exclusive VM, six
exclusive IR, five store IR and three public readonly groups. CLI coverage
includes 222 mutable cases, 192 readonly cases and all 2,007 M1 cases. The mutable
matrix executes all six tags, checks each simple store's exact Fuel and one-short
budget, scope recovery, runtime errors, a mixed thirteen-ticket pool, quota
failure with active writers, the site ceiling and the retained example. The
version capability is checked through a cleared, tool-free environment. A
sixteen-ticket attempt is admitted by check and hits the unchanged one-million
CLI Fuel ceiling during run; this is not a ticket-capacity failure. Native
adapter Fuel tests use separately supplied VM budgets.

The earlier source CLI selection is now an execution matrix with schema
`browniec.slice-exclusive-source-cli/v2`; dated v1 receipts retain their original
private-gate behavior. Historical selection names run against current public
admission. Full native and other M2 suites, Linux, M0, isolation, packaging,
allocator and timing checks are outside this selection. No push, publication,
packaged release or deployment is part of this local delivery.

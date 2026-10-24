# M2 Source Array Copy Initialization

- Status: implemented and focused-harness verified in development and release
- Scope: scalar-array copy declarations in the outermost `main` body
- Evidence: [Windows source-copy receipt](../evidence/m2-array-copy-source-windows-20261025.json)
- Implementation: [`compiler.fy`](../../src/compiler.fy) and [`array_source.fy`](../../src/array_source.fy)

This slice extends the [source-array read](m2-array-source.md) and
[write](m2-array-write.md) contracts with copy initialization. The compiler
reuses the private [entry-array IR](m2-array-ir.md) and [VM](m2-array-vm.md)
`ACOPY` instruction; it adds no new VM instruction or verifier rule.

## Grammar

```text
let|var TYPE '[' LENGTH ']' DEST '=' SOURCE ';'

TYPE ::= bool | u8 | i32 | i64 | u32 | usize
LENGTH ::= a decimal literal from 1 through 4096
```

The declaration is limited to the outermost body of `main`. `SOURCE` must be a
bare name for a visible array binding. Its element type and length must exactly
match `TYPE` and `LENGTH`; there is no conversion, inference, or resizing. The
source is resolved before `DEST` becomes visible.

`let` or `var` chooses only the destination's mutability. Each form may copy a
`let` or `var` source, so an immutable snapshot of a mutable source is admitted.
The source remains live until its normal lexical drop, and `ACOPY` copies its
bytes into independent storage. Later reads or writes to either binding do not
change the other.

Existing repeated initialization (`[EXPR; N]`), indexed reads, and element writes
retain their earlier evaluation and lifetime rules. Copy initialization is a
one-time declaration operation, not an implicit copy on assignment or argument
passing.

Whole-array reassignment, parenthesized or call/aggregate source expressions,
array declarations in nested blocks or helpers, copies in `for` headers, array
parameters or results, borrows, `len`, and slices remain unsupported.

## Example

`examples/array-copy.brc` returns `42`. The writes change both directions: the
source update leaves the snapshot's first element at `21`, and the snapshot update
leaves the source's second element at `21`:

```brownie
module main;

fn i32 main() {
    var i32[2] original = [21; 2];
    var i32[2] snapshot = original;
    original[0] = 0;
    snapshot[1] = 22;
    return snapshot[0] + original[1];
}
```

## Resources and Fuel

The source and destination descriptors share the existing 16-entry array catalog;
a source/destination pair therefore occupies two entries. Their retained payloads,
and any layout padding, share the same fixed 65536-byte arena. Older and newer
extents must fit together because the source remains live after the copy.

`ACOPY` costs:

```text
49 + payload_bytes + 7 + (bool ? length : 0)
```

`payload_bytes` is the element width times the array length. The runtime continues
to allocate one fixed array arena per run; `ACOPY` creates no separate heap backing
allocation beyond that arena. For bool arrays, the length term covers canonical
payload validation. The cost is a bounded work unit, not a performance claim.

## Profiles

After successful compilation, any program containing `ACOPY` reports
`brownie.m2-array-copy/1`, including after a later verification or execution
failure. The copy profile takes precedence over the mutable-array write profile.
Programs without `ACOPY` retain `brownie.m1-scalar/1`,
`brownie.m2-array-read/1`, or `brownie.m2-array-write/1` as before.

Version JSON retains every previous field and adds `array_copy_profile`:

```json
{"schema":"browniec.version/v1","profile":"brownie.m1-scalar/1","array_profile":"brownie.m2-array-read/1","array_write_profile":"brownie.m2-array-write/1","array_copy_profile":"brownie.m2-array-copy/1","core":true,"restricted":false,"embed":false}
```

The result schema, diagnostic kinds, and process exit classes are unchanged.

## Verification status

The focused harness passed in development and release:

```powershell
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice copy
python -B tools/record-m2-array-write-evidence.py --slice copy
```

Each profile passed 12 native groups (six read, three write, three copy), 67 read
CLI cases, 61 write CLI cases, and 58 copy CLI cases. Coverage includes all six
scalar element types, destination mutability independent of the source, copying
current bytes, independent writes, copy chains, nested use, early-return cleanup,
shape/scope rejection, descriptor and payload limits, and exact Fuel boundaries.
The one-element i32 copy/read fixture needs 65803 Fuel with the default arena;
65802 reports guest `fuel`. A quota failure does not poison a fresh invocation.

Full scalar CLI regression is pending. Run it against the same binaries with:

```powershell
python -B tools/record-m2-array-write-evidence.py --slice copy --scalar-regression
```

After a completed matching scalar receipt and documentation-only changes,
`--reuse-scalar-regression` rechecks the source, compiler, binary, profile, and
receipt hash identities without repeating the 1,969 cases. The full 81-group
native scalar rerun is skipped because the VM and verifier are unchanged.

The earlier [read receipt](../evidence/m2-array-source-windows-20261024.json) and
[write receipt](../evidence/m2-array-write-windows-20261024.json) remain historical
for their earlier compiler inputs. The
[private-copy receipt](../evidence/m2-array-copy-windows-20261023.json) verifies the
primitive, not this source frontend. No Linux, isolation, DLL, allocator,
clean-machine, or performance result is claimed.

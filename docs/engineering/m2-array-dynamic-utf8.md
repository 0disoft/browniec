# Register-bounded UTF-8 ranges (private VM foundation)

Opcode **53** validates UTF-8 over a `u8` array range whose endpoints come from
existing `usize` registers. This private IR/VM foundation originally had no guest syntax, source lowering
or version capability flag. The [named-array source successor](m2-array-utf8-dynamic-ranges.md)
now emits it for scalar usize endpoint bindings.
Callers build it through `ir::array_dynamic_utf8` and run it through the existing
array path.

## Instruction and builder

The instruction carries a bool destination, `a = array_id`, `b = start` register,
the `end` register in byte 4, and zero in bytes 5..7. The builder rejects an
unknown or non-`u8` catalog entry, either register at or above 128 or past the
current register count, a non-`usize` operand, a slot register, and a register
bound to an array or record parameter. A rejected request publishes nothing; the
valid path appends the instruction and returns a fresh bool register.

## Independent verification

The verifier requires both endpoint registers to be readable, defined `usize`
values in the same function, the catalog entry to be a live function-owned `u8`
array, and the destination to be a fresh bool register inside the function's
range. Bytes 5..7 must be zero; byte 4 is the only exempt byte because opcode 53
stores the end register there. Dispatch keeps 53 on the array path.

## Runtime checks

`array_range_vm::step` revalidates the program counter, frame, destination, array
catalog entry, element type, length in 1..4,096, both register indices and the
reserved bytes before touching state. It then charges the **full root length**,
`65 + 4 * N`, before reading either endpoint cell, so a short budget reports
Fuel (kind 8) ahead of any bounds evaluation. Reversed or out-of-range endpoints
after decoding report kind 14.

Endpoint cells are decoded as full unsigned 64-bit values. A `-1` cell decodes to
`usize` `MAX` and an `i64` minimum cell decodes to 2^63; both exceed the length
bound and are rejected with kind 14 rather than wrapping. A Fuel or bounds
failure returns no remaining Fuel value, and this page makes no claim about
measured error charges or refunds.

Wrong metadata, frame or register bounds, stale tokens and backing failures
return the existing state errors with the destination register unchanged. The
scan reuses the checked view and UTF-8 validator of the static range path: no
owner is minted, no payload is copied and no read session is retained. Pairing
the owner table with its backing buffer remains a caller obligation: these checks
validate bounds and shape, not foreign-origin authentication. Opcode 52
keeps its `65 + 4 * K` charge for `K` selected bytes.

## Fuel in the private harness

The direct-IR test program builds a custom arena of `N` bytes and runs for
exactly **180 + 6 * N** Fuel; `N = 4` needs **204**. That total describes the
private test program, not a CLI or guest-source charge.

## Source availability

At the foundation checkpoint, guest code could not spell a dynamic range: `text::valid_utf8(a[lo..1])` with a
`usize` local failed compilation, as did the temporary forms.
The source successor accepts named-array ranges with scalar usize bindings;
the [temporary dynamic successor](m2-array-utf8-temporary-dynamic-ranges.md)
extends this to calls and literals. The [computed-endpoint successor](m2-array-utf8-computed-ranges.md) accepts
ordinary usize expressions on named arrays. The [temporary-computed successor](m2-array-utf8-temporary-computed-ranges.md)
extends expression endpoints to direct calls and literals with lexical cleanup.
General slices and persistent borrows remain unavailable. Static forms keep their behavior.

## Focused verification

Run `python -B tools/verify-m2-array-utf8.py --profile development --dynamic-vm`
and repeat with `--profile release`. Each profile selects **30 native groups**:
five new dynamic-range groups, six static-range groups, six whole-UTF-8 groups,
five array IR groups and eight struct VM groups. It also runs **18 tool-free CLI
invocations** from nine programs, confirming that the existing static forms still
work and that guest source rejects wrongly typed endpoint bindings and Buffer
syntax. The original receipt below predates source integration and records the
then-required rejection of a usize bound.

The five new groups cover endpoint cells selecting multibyte boundaries without
touching the source, prepaid root-length Fuel for empty, partial, invalid and
4,096-byte ranges, independent verifier rejection of malformed operands and dead
roots, runtime errors and Fuel gates that leave the destination, owners and
payload untouched, and builder rejection without partial publication.

Development and release each passed all 30 native groups and 18 CLI invocations.
The implementation is committed at `4a076e5`. The [Windows receipt](../evidence/m2-array-dynamic-utf8-windows-20261030.json)
records matching source/tool hashes, compiler/SDK identities, original receipt
hashes and retained executable hashes. Earlier receipts remain historical for
their exact inputs.

Whole native and CLI suites, Linux, M0, DLL embedding, isolation, packaging,
allocation instrumentation and elapsed-time performance were not rerun for this
slice.

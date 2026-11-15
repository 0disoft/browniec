# Plan record initialization once

array_owners::create_record is the checked native owner boundary used by
struct_vm opcode 41. It previously planned the complete record catalog to
obtain owner size/alignment, then struct_nested_storage::initialize planned
the same immutable catalog again before staging the record. This repeated
metadata work occurs even when constructing a one-byte record.

The owner boundary now calls initialize_described, which returns Initialized
with the published base, size and alignment. These scalar values describe a
completed checked initialization; they are not a cached Plan or reusable
authority. The owner descriptor uses the exact shape selected by storage.
The existing initialize API delegates to this checked entry and returns base,
preserving its result and diagnostics for raw storage callers.

## Validation and publication

The diagnostic order stays complete table/arena validation, free owner slot,
whole catalog, record ID, 128-byte selected size, arena validity, field count,
checked alignment/reservation/quota, then canonical scalar encoding. Storage
still builds a fresh full plan on every call; callers cannot supply a plan.
Malformed unused catalog slots remain errors. An invalid table still wins over
a bad catalog, and an exhausted or retired owner table still wins over both
catalog and argument errors.

The 128-byte zeroed scratch, scalar encoding order, alignment arithmetic,
checked reservation and publication loops are unchanged. All fallible work
finishes before backing bytes or the allocation cursor are published. Owner
publication follows checked storage success without another fallible step.
Failure leaves all backing bytes, the arena cursor and owner table unchanged.
Token generations, shared array/record limits and VM Fuel prices are unchanged.
No caller-supplied proof, heap allocation or cross-call cache is introduced.
The new type/entry belong to private native storage, not public Brownie syntax.

## Structural cost

A successful owner creation makes one complete catalog plan instead of two.
The fixed validation loops therefore inspect 512 field slots and 32 record
rows instead of 1024 slots and 64 rows: a 50 percent reduction in those loops.
One complete dependency/offset planning pass is also removed. Over 4096
successful creations this removes 2097152 fixed slot inspections, 131072 row
inspections and 4096 dependency/offset planning passes.

Asymptotic cost remains O(T+S+R+F+B): T is full owner-table validation, S=512
fixed slots, R<=32 records, F<=512 active fields, and B<=128 staged bytes.
The full-catalog factor is halved; table validation and payload work are
unchanged. Payload scratch stays 128 bytes. These are source operation counts,
not measured throughput, CPU instructions or physical stack/memory peaks.
Other copy/replacement and record assignment APIs are unchanged.

## Focused verification

Run python -B tools/verify-record-create-plan.py --profile all.
The selection has six native groups per profile using locked byte-identical
production mirrors, the pinned compiler and default native stacks.

Two groups compare 1555 inputs against the frozen ce99a01 owner algorithm:
1024 catalog slot corruptions, 32 row corruptions, 448 owner/error contexts,
field counts, IDs, scalar values, arena limits, cycles, retired slots, depths
1 through 17, the 128-byte boundary and full owner tables. Each compares exact
tokens/errors, every owner/order/arena field and all 256 backing bytes. Failed
creations must also preserve the original table and bytes. The frozen owner
algorithm uses the compatible raw initializer; independent expected-byte
goldens cover storage encoding, padding and the new receipt shape.

Four existing groups cover all scalar encodings and padding, owner pressure
and quota rollback, generation retirement/clear, and direct VM exact Fuel plus
one-unit-short rejection before mutation. Receipts are under
build/record-create-plan/<profile>.

Full Engine, standalone memory, public CLI, Linux and full release gates are
outside this focused change; public admission is unchanged. The prior legacy
source failure recorded in subrecord planning was not rerun or claimed fixed.
Final profile results and tested input/commit identity are in the
[evidence](../evidence/record-create-plan-windows-20261115.json).

Development and O2 each passed all six selected native groups. All 377
receipt inputs match tested working bytes. Against implementation a891091,
376 inputs match raw Git bytes; the unchanged tests/m2/struct_vm.fy differs
only by CRLF/LF line endings;
normalized bytes match and both raw hashes are recorded in the evidence.
The root check passed with 375 sources and 4093 MIR functions; its lock update
is included in the implementation. The guidance body below its heading is
byte-identical to the prior checkpoint.

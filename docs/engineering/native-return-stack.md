# Native return transaction stack use

Date: 2026-11-05. This fixes a reproduced Windows development stack overflow in
the existing scalar-return coordinator. It advances R02 bounded native work;
complete Engine/Instance preallocation and stack containment remain open.

## Reproduction and cause

At `16aea0c`, combine the body of
`empty_catalog_program_runs_without_literal_payload` with
`retention_checks_exact_image_charge_and_hostile_limits` in
`tests/m2/program_image.fy`, removing the repeated `unit` declaration. The same
function then performs several image admission attempts and runs an empty-image
Program. The default Windows native test exits with stack-overflow status
`-1073741571`, without a valid guest trap. This is the combined case that the
earlier ownership increment separated; that separation was not a runtime fix.

Captured generated C and MSVC assembly identify
`slice_result_runtime::leave_call` as the final oversized frame. Diagnostic-only
entry probes reached its caller at about 873 KB of stack use before the next
frame could be entered. Those instrumented runs explain the call chain; they are
not counted as normal native verification and do not establish an overall bound.

The pinned backend materializes large intermediate value snapshots for chained
reads such as `state.runtime.authority.frame`. The old function also constructed
a complete `Runtime` value to publish three already-prepared fields. Reducing
Program return values alone or only changing the final publication did not fix
the reproduced combined case; those experimental implementations were discarded.

## Change and transaction semantics

The function now borrows the original authority once and uses that reference for
all guards. It explicitly borrows the original pool and owner table before making
the three existing private transaction copies. Borrowed originals have their last
use before publication. No reference is stored or escapes.

`restore`, shared closes and reverse capture cleanup still operate on those
unpublished copies in exactly the same order. All fallible operations precede the
three final plain field assignments. There is no allocation, callback, user
cleanup or fallible operation between those assignments. On success only, the
function marks `call.active=false`. Failed attempts preserve the original state,
active call, first error and prior guest payload writes.

Program ownership/API, VM depth/capacities, guest instructions, operation prices,
public limits and capabilities are unchanged. There is no new allocator or heap
representation and no compiler/stack override. The original combined regression
now stays in one test function rather than being hidden by fixture splitting.

## Measured native frame

Using captured generated C, the same MSVC 19.51 development `/Od` configuration
and `/FAs` listings, the function's stack allocation decreased from 263,544 to
58,152 bytes: 205,392 bytes, or 77.93 percent. This measures the function's emitted
allocation, excluding saved registers, return addresses and other call frames.
It is not a release, total-stack, process-RAM, allocator or elapsed-time benchmark.
Diagnostic binaries/listings are separate from the ordinary native selections.

## Verification

The focused verifier selects the six retained-Program groups and seven native
scalar-entry groups. These include the original combined reproducer, exact and
one-short Fuel, repeated runs and arithmetic failure, retained/anonymous input
restoration, independent owned arguments and late capture-drop rollback.

```text
python tools/verify-program-image.py --profile development
python tools/verify-program-image.py --profile release
```

The [Windows evidence](../evidence/native-return-stack-windows-20261105.json)
records 13 native groups per development/release profile on 125 matching final
inputs, with a 217-file discovery digest and 119 LF production files. Both LF
mirror checks passed. The baseline mirror was checked byte-for-byte against
`16aea0c`; its failing fixture is byte-identical to the passing final fixture.
Production changes are limited to this return function and its source lock.
All counted selections followed final capture without native overrides or result
reuse. The independent read-only review confirmed rollback, last-use borrows,
publication and first-error preservation. Other
native suites, standalone CLI, Linux, restricted delivery, ABI and packaging are
not established by this increment.

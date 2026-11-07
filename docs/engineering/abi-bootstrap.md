# Windows DLL ABI bootstrap

The first actual Brownie DLL surface now exports `bc_get_abi_info_v2`. Its
revision/capacity/null admission and metadata values are compiled from Fairy C;
the small native shim marshals pointers and the exact output layout. This is
bootstrap only. Engine, Program, Instance, handles and embedding execution remain
unimplemented, and the CLI's embedding availability stays false.

## Build and inspect

With the pinned Fairy compiler and installed Windows x64 MSVC/SDK:

```text
python tools/build-abi-bootstrap.py
```

The builder creates a fresh directory below `build/abi-bootstrap`, prints its
location and records commands, frozen input hashes, compiler/codegen identities,
PE identities and host results in `receipt.json`. Each profile produces
`brownie-bootstrap.dll` and `abi-bootstrap-host.exe`. `--output` selects a new
directory; `--profile development|optimized` limits the build. No root lock,
manifest or CLI build is changed by this tool.

Only two authored Fairy modules are compiled in an isolated package: the real
bootstrap logic and a small private root driver. The driver is not invoked by
the DLL. `native/abi_bootstrap.c` includes the compiler's private generated C
unit and calls its actual helpers. Whole-transport and compiler hashes prevent
using changed private `fy_fn_*` names silently. They are not a stable compiler
API. A toolchain refresh must review that transport binding as part of adoption.

The canonical ABI declaration/layout references are included under
`tools/abi-bootstrap/reference`; a checkout does not need the author's Downloads
ZIP. Optional `--design-archive` checks original-archive provenance. Reference
files are data; no instructions from the design archive are executed.

## Query contract

Windows x64 uses natural alignment and `__cdecl`; C and C++ independently assert
every public size/alignment/field offset. The bootstrap writes these eight u32s:

| Field | Value |
| --- | --- |
| struct_size | 32 |
| abi_revision | 2 |
| pointer_bits | 64 |
| diagnostic_size | 264 |
| event_size | 336 |
| entry_info_size | 32 |
| source_size | 32 |
| slice_size | 16 |

Revision other than 2 or capacity below 32 returns `BC_ABI_MISMATCH` (9), before
the NULL check. Valid revision/capacity with NULL returns `BC_BAD_ARGUMENT` (1).
Failure does not read or write caller storage. Success ignores its previous
contents and writes exactly 32 bytes, including when capacity is larger.
Successful native callers supply valid writable storage; arbitrary invalid
pointers are not made safe by this ABI.

The public header preserves the revision-2 declarations. Only the query is
implemented. Internal shim decoration exports that definition alone, avoiding
exports of undefined planned functions. The host dynamically resolves the actual
unmangled symbol and confirms all ten planned APIs are absent; there are no
engine-success stubs or availability promotion.

## Native evidence

Both development and optimized artifacts passed 53 real DLL calls each: the
revision/capacity cross product with non-NULL and NULL outputs, exact values,
failure byte preservation, surrounding canaries, PAGE_NOACCESS failure pointers
and exactly 32 writable bytes before a guard page with capacity UINT32_MAX.
`dumpbin` confirms the singleton export and absence of a Brownie host import
library dependency. The executed host is C11; a separate C++17 compile checks
header/layout compatibility. All four PE files retain default stack reserve
1048576 and commit4096, without CL/_CL_/LINK overrides or a /STACK option.

Integration builds without the original ZIP and runs both hosts with a cleared
environment and empty tool PATH. A Korean/emoji output directory exercises wide
Windows loading and UTF-8 build reporting. Corrupted header declarations,
metadata source/transport, vendored contract and empty LINK overrides each reject
before any native object/DLL is created.

Implementation `ad86fc9` passed the final self-contained integration above.
All 228 root/feature inputs match checkout and Git raw bytes, all 217 production
modules retain LF, and the native receipt freezes nine exact feature inputs.
Committed-root `fairyc check --locked` verifies 225 sources / 2450 MIR functions.
An additional development build validates optional original-archive provenance.
See [focused evidence](../evidence/abi-bootstrap-windows-20261107.json) for actual
commands, compiler/transport/artifact identities, rejection controls and limits.

## Remaining work

This supplies executable bootstrap evidence for E01, not the complete E01 or
embedding milestone. Typed process-wide handles, owner-thread Engine/Instance
lifecycle, VM compilation/execution, step/reply/cancel/destroy, stable event/data
lifetimes, other platforms and delivery/clean-machine evidence remain open.
The existing parser/VM source path and instruction/Fuel/public gates are unchanged.

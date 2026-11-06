# Metered invocation storage for array places

Date: 2026-11-06. Native dispatch prerequisite for the
[independent place IR proof](array-place-ir.md). The public execution gate remains
closed until both VM drivers and retained-reference guards are connected.

`place_vm.fy` supplies one invocation-owned `Vec<usize>` instead of a fixed
512-snapshot native stack array. The plan uses the largest place ID plus one,
W, independently bounded to 1..16. Each of 32 frames has one active-place counter
and nine words per location: eight captured owner/location words and one packed
element/root/phase word. Layout is checked before every use; dispatch performs no
allocation or token-table copy. Unused programs have an empty vector and no cost.

| W | Initialized words | Initialized metadata payload | Once-per-invocation Fuel |
| --- | ---: | ---: | ---: |
| 0 | 0 | 0 | 0 |
| 1 | 320 | 2560 bytes | 3457 |
| 16 | 4640 | 37120 bytes | 46657 |

These are initialized payload sizes on supported 64-bit targets; allocator/vector
overhead and spare capacity are separate. Setup is `257 + 10*32*(9*W+1)` when
W is nonzero: the fixed envelope plus eight byte-initialization units and two
publication/destruction visits per word. Callers must preflight this once before
preparation. The vector owns no guest loan or owner; its normal native destruction
also disposes of all unpublished snapshots after abort, including zero Fuel.

| Operation | Ordinary price, including dispatch |
| --- | ---: |
| SELECT | 65 |
| READ | 65 + scalar stride |
| STORE | 65 + 2*scalar stride |
| END | 17 |

The 65-unit envelope covers the existing 32 bounded owner-ledger visits plus
slot/snapshot metadata. Scalar payload terms reuse existing codec work units;
END clears nine words and updates its frame counter. A retained driver must add
its existing separate dispatch unit. Existing operation prices, CLI default 256
and ceiling 16000000 remain unchanged.

Selection authenticates bounds/type/shape before publishing any snapshot. READ
and STORE resolve the captured original token and location, even when a caller
changes the current descriptor/index during RHS evaluation. Old scalar values
remain separate registers. Current owner generation, reservation and writability
are rechecked on every payload access. Failed validation, phase or Fuel preflight
changes neither payload, output register nor the snapshot phase. END may abandon
an uncommitted location and permits subsequent reuse; empty-frame checks use the
per-frame counter before a driver releases or reuses that frame.

The instruction executor assumes immutable independently admitted IR and one
consistent owner table/backing lifetime. Native metadata is private, not a guest
capability or externally loadable serialized state. This layer is not Engine
memory-quota accounting, host-visible returned-place lifetime, source compound
assignment, or execution of new operations by the current public VM.

Verify with `python -B tools/verify-static-execution.py --profile development
--selection array-place-storage`, then repeat for release. The selection contains
the new executor cases plus the original native array-location suite. See
[Windows evidence](../evidence/array-place-storage-windows-20261106.json).

The [VM execution successor](array-place-execution.md) now connects actual driver
preflight, dispatch, CALL/return and retained guards. The earlier gate statements
above describe this prerequisite checkpoint, not the successor's current scope.

Development/release each passed 14 native groups (six new executor groups and
eight original location groups), using 169 identical input hashes, 163 LF
production modules and 281-file discovery. Both locked LF mirrors passed.
Executed inputs match staged Git bytes; 41 unselected legacy discovery fixtures
differ only by CRLF/LF, with both hashes recorded. No public CLI/full Fuel matrix,
Linux, OOM injection, general stack/performance, isolation or delivery rerun.

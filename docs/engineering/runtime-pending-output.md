# Owning canonical VM continuation

Implementation `1e1e47b` (2026-11-07).

This private output VM can return Pending to its caller and resume on the next
call. It preserves the existing opcode dispatcher and Fuel schedule. It is a
prerequisite for R03; the full Engine/Instance step contract remains incomplete.
[Engine-owned preparation](runtime-engine-prepared.md) now associates prepared
state with the actual Instance and accounts its heap; advancement is next.

## State and execution

- [Machine](../../src/slice_result_machine.fy) owns the register/static banks,
  frames, native runtime authority/owners/loans, admitted Static sites and input
  origin recipes, payload arena, list/place scratch, input windows and staged
  output. Small PC/Fuel/counter/terminal metadata is retained inline.
- [Saved dispatch](../../src/slice_result_execution.fy) shares entry initialization
  with the synchronous path. `step_output_saved` returns Pending after at most
  the requested instruction visits; it does not recreate entry or drain Pending
  in a hidden loop. Error cleanup uses the existing canonical abort.
- [Native Fairy coordinator](../../native/runtime-engine/runtime_pending_output.fy)
  supplies prepare, advance, cancel and once-only seal through the existing
  [internal facade](../../native/runtime-engine/runtime_engine.fy). The
  [C projector](../../native/runtime-engine/bridge.inc) only passes field addresses,
  constructs exact typed slices and supplies `sizeof(Core)`.

Preparation verifies the exact Program/image once and saves the execution proof
fields needed by every subsequent call. It retains the ordinary preparation,
entry, opcode, helper and seal prices. Moving the Machine moves owning handles;
its allocations and saved state do not move. Each advance returns fully; no suspended native function retains the VM state.

The trusted caller must keep the same immutable Program and input Snapshot alive
and pass them on each advance. This interface does not authenticate an Engine
ID, owner thread, pin or lifetime generation. The Engine preparation layer
authenticates its own association and ledgers; these low-level helpers are not public
CLI controls, C ABI exports or restricted execution.

## Storage and stack containment

An initial `Vec<Core>` implementation reproduced Windows stack overflow
`0xC00000FD` on the default 1MiB stack. By-value aggregate construction and the
generic container's move/drop paths materialized large Core temporaries.

The implementation instead reserves exactly one Core-sized byte allocation,
zeros its private storage in chunks and initializes individual fields in place
through a typed Fairy helper. The buffer is solely owned, never exposed as guest
bytes and never grows after construction. This also removes the unused seven
slots of the SDK Vec minimum capacity. The native layout contract checks the
actual Core and Machine definitions, bank element/counts and typed projections.

The pinned MIR builder needs a source call to retain the native initializer.
A separate cold type witness is guarded by `sizeof(Core) == 0`, which cannot be
true. The actual prepare/resume/drop paths never construct a by-value Core.
This is not a stack-size override or a claim of general R02 stack containment.

## Terminal behavior and verification

Quantum must be 1..4096. Invalid values reject before state mutation or allocation.
Each successful advance records one batch. Running calls make no SDK allocation;
all backing was prepared before entry. CALL/RET and bulk helpers remain atomic.

Cancel drains native metadata and discards staged output without guest execution
or replay. Repeated cancel preserves the first terminal cause. Success permits
one metered seal; repeated or premature seal cannot publish again. Dropping an
unsealed Machine releases its owning allocations, including a staged prefix.
Published bytes remain separately owned after the Machine is dropped.

The [native fixture](../../tools/runtime-engine/engine_pending_tests.fy) contains
eight groups: moves/nested output; aggregate places/CALLs; returned input ranges;
traps/Fuel/first cause; invalid quanta; cancellation/pending drop; every preparation allocation ordinal for the exercised array/input/output
recipe; and fixed/mixed valid quanta. Tests compare final bytes/value/Fuel with the
synchronous facade, exercise fixed quanta 1, 2, 3, 7, 64 and 4096 plus changes between calls,
check exact diagnostics,
assert zero resume allocations and verify heap restoration. Existing cursor,
quantum, Engine, input/output and OS fixtures run in the same image.

Native evidence and exact source/artifact identities are recorded in
[the Windows evidence](../evidence/runtime-pending-output-windows-20261107.json).
The [candidate generator](../../tools/review-runtime-engine-transport.py) emits
complete declaration/layout candidates, including the in-place initializer's
self marker. Inspect its candidate before using `--write-contract`.

## Remaining accepted work

- Advance and publish the prepared Instance through Engine ownership, preserving
  the existing Program/input pins and exact ledger charges. Preparation, cancel
  and teardown are now connected; Engine.step execution is not.
- Complete bounded setup/initialization, transfer/copy/tag/store/CALL/RET,
  planning, publication and cleanup recipes. Instruction visits alone do not
  bound payload bytes, metadata visits, elapsed time or native work.
- Add deadlines, in-flight cancellation routing, STOPPING/poison containment
  and zero-Fuel cleanup budgets. Full R03/R04/R05 remain open.

Public admission, capacities, existing Fuel prices/default 256/ceiling 16000000,
legacy synchronous availability and external-effect non-replay remain unchanged.

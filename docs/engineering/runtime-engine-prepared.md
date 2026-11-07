# Engine-owned VM preparation

Implementation: `23bb1fd`; preparation diagnostic fix: `7657873` (2026-11-08).
This extends the
[owning output VM](runtime-pending-output.md) with private Engine association and
heap admission. Its [stepping successor](runtime-engine-step.md) now advances
prepared Instances and publishes terminal output through the reserved slot.

## Ownership and state

`prepare_instance` authenticates the Engine's existing owner thread, guard and
admission epoch, then accepts only a Ready output or input-output Instance. The
Instance's Program pin remains valid after release_program. Input stays owned
by the Instance. Prepared VM storage is owned by the Engine's Output container;
moving the Engine moves owners without moving their backing allocations.

Preparation creates the publication slot, VM scratch, exact Core allocation and
entry state. It executes zero guest opcodes, exposes no output and returns
Pending (Event kind 4) with the exact remaining setup/entry Fuel. Repeated prepare
and execute_once reject with status 3 without replay or mutation. take_output
rejects until terminal publication. No external effect is replayed or rolled back.

Cancellation drops unpublished prepared storage, refunds its retained charge
and preserves the already-spent Fuel. Input stays owned until Instance teardown.
Repeated cancellation preserves the first cause. Direct Instance destruction
also frees input and releases the Program pin. These operations remain available
as owner maintenance after admission epochs are exhausted. Before any guest
opcode executes, all private authority can be revoked by dropping its sole owner.

## Exact admission and failure

The checked pending requirement is:

```text
sizeof(Core) + 8 * sizeof(Machine) + cached_execution_scratch + 616 + output_limit
```

Core has one exact allocation. The Machine Vec's SDK minimum capacity is eight.
Scratch already includes input windows and payload/list/place backing; it is not
counted again. The 616 bytes are Published Vec8 (576) plus staged header (40).
Existing retained input and Engine control are charged separately.

Instance, aggregate Instance and combined Engine ceilings are checked before
allocation. Only successful preparation publishes the new retained charge.
Native allocation failure returns status 6 and drops partial owners. Preparation
errors retain their original diagnostic (including Fuel exhaustion), preserving
Ready state, original Fuel, input, Program pins and current ledger balances.
Admitted reservation peaks remain historical pressure, including failed attempts.

Adding the inline pending Vec widens Output by 48 bytes. Native one-slot control
backing is 7744 bytes (previously 6976), and 64-slot backing is 61952 (previously
55808). The Engine owner remains 736 bytes. Output extraction's temporary Vec8
is measured from the emitted type, rather than using the previous 1088-byte
constant. The corresponding new width is 1472 bytes.

## Verification and next work

The [native fixture](../../tools/runtime-engine/engine_prepared_tests.fy) covers
zero dispatch, exact saved-carrier Fuel, duplicate rejection, released Program
pins, Engine moves, cancellation, direct teardown, automatic Engine destruction,
exact/one-less Instance/aggregate/combined quotas, every preparation allocation
ordinal for one input/array/place/output recipe, wrong mode, exhausted epochs
and original Fuel-exhaustion diagnostics with unchanged Ready state.
Seven [checked arithmetic groups](../../tests/m2/runtime_pending_memory.fy)
cover the size formula, zero sizes, output limits and every overflow boundary.

The [Windows evidence](../evidence/runtime-engine-prepared-windows-20261108.json)
records the actual development/O2 runs, default stacks, source identities and
heap-at-exit observations. Existing pending VM, synchronous Engine, output
ownership and OS guard regressions share the image. The native guard fixture
also rejects prepare from the wrong thread and during an active admission.

The [Program preparation cache](runtime-program-preparation-cache.md) retains
the immutable compile proof, list/place requirements, entry price and scratch
plan. New owning preparations reuse them; arbitrary raw IR still re-verifies.
Cached storage is charged through the actual Stored layout and Vec capacity.

Engine-owned advancement and terminal publication now use the reserved slot,
without resume allocations; see the stepping successor for current evidence. Setup/proof, bulk work, CALL/RET, publication
and cleanup remain atomic. Deadlines, in-flight cancellation, poison containment,
public lifecycle/ABI/CLI controls and the accepted inventory remain incomplete.
R03-R05 are open. Existing capacities and Fuel prices/default 256/cap 16000000
are unchanged.

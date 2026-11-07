# Canonical instruction-batch cursor

Implemented at `8bf120b7099a19d065798869c905b98ff33792e7` (2026-11-07).
The canonical returned-reference/input/output dispatcher preserves execution
state between instruction batches. The facade remains synchronous: it drains
Pending batches internally and returns only a terminal result. **R03, R04 and
R05 remain open.** This is not persistent `Engine.step` execution.

Current successor: [resumable VM output copies](runtime-output-chunks.md) now
count prepaid copy continuations as dispatch visits and bound output bytes per
caller return. The original evidence and counter description below record the
initial instruction-only checkpoint.

## Implementation and saved state

- [slice_result_cursor.fy](../../src/slice_result_cursor.fy) defines `Cursor`
  (`pc`, `active`), `Stats` and checked batch accounting.
- [slice_result_execution.fy](../../src/slice_result_execution.fy) owns the
  canonical `run` / `drive` / `dispatch` path. `drive` returns Pending as
  `Option::none`, Complete as `Option::some`, or an error; `run` immediately
  continues Pending without restarting entry or replaying prior instructions.
- [module_output_program.fy](../../src/module_output_program.fy) exposes private
  `complete_quantized`; existing `complete` uses quantum 4096. Output preparation,
  execution, failure handling and final publication remain one synchronous call.

Across batches, the same PC, scalar registers, static reference live/word banks,
input windows, frame maps, owners, loans, indexed-place/list storage, output
transaction and shared Fuel balance remain live. Register/static banks stay
separately borrowed because the pinned compiler treats loans of sibling array
fields as loans of the whole struct.

The cursor, banks and owning setup **remain invocation-stack locals** (with
borrowed backing), not persistent Engine Instance execution storage. A Pending
boundary neither publishes output nor releases these resources to a caller.

## Quantum and Stats contract

The valid quantum is `1..4096`. A batch checks its local visit count before
fetching the next instruction. Each admitted dispatch visit debits the existing
base Fuel charge and increments `visited` before executing the opcode; helper
charges retain their existing rules. **`Stats.dispatched` counts dispatch
visits/attempts, including an instruction that subsequently fails, not
necessarily completed guest operations.** A zero-Fuel rejection before that
increment adds no visit.

`Stats` contains:

| Field | Meaning |
| --- | --- |
| `calls` | Successfully begun batches, including terminal/error batches. |
| `yields` | Batches returning Pending. |
| `dispatched` | Accumulated dispatch visits/attempts. |
| `last` | Visits in the last recorded batch; reset to zero at `begin`. |
| `maximum` | Largest recorded batch visit count. |

`begin` validates history and reserves arithmetic headroom for the entire
quantum before changing counters. Dispatch uses one local `visited` counter;
`finish` aggregates history once on Pending, Complete or error, rather than
updating historical Stats for every opcode. Zero visits are allowed for
Complete/error, but not Pending. Invalid/malformed history and overflow reject
atomically. Stats is trusted private instrumentation, not guest authority or a
work budget; `calls`, `yields`, `last` and `maximum` may differ across quanta.
The dispatcher enforces its own quantum; Stats helpers do not pair each
`finish` with a particular `begin`. Invalid Stats are detected at batch entry,
after owning setup may already allocate and debit Fuel.

`complete_quantized` rejects invalid quanta before output preparation, allocation,
Fuel debit or Stats mutation. Tested invalid values are `0`, `4097` and
`18446744073709551615`: error kind 5, unchanged remaining Fuel and Stats, no
allocation attempts, and no published bytes or emissions. This rejection takes
precedence even when output limits and Fuel are also invalid.

## Recorded verification

The [canonical evidence](../evidence/canonical-dispatch-cursor-windows-20261107.json)
links the [native receipt](../../build/runtime-engine/20261107T134020580580Z/receipt.json)
(SHA-256 `9db78273205204b1421680abdf0b016110c346383a694195a3d7cdb5ff232062`).
These are existing recorded runs; documentation authoring did not rebuild or
rerun the executables.

- Windows x86-64 development (`/Od`) and release (`/O2`) both exited 0, with
  native Fairy/C assertions and zero live SDK heap allocations at exit. The
  default PE stack reserve/commit was 1048576/4096 bytes; compiler overrides
  were disabled and execution used a cleared runtime environment/empty tool PATH.
- In both profiles, quanta `1, 2, 3, 7, 64, 4096` preserve values, published bytes,
  emission counts, remaining Fuel, full original source diagnostics, dispatch
  visit counts and retained result heap. The quantum differential compares the
  new dispatcher against its own 4096 mode, not an independent prior
  implementation; legacy `complete` also uses this new 4096 path. Fixtures
  exercise repeated yields without replay and keep prior publications alive
  while later executions run. Detached publications survive Program/input
  destruction and move without replay or extra allocation.
- The archive records 231 repository inputs matching checkout/Git plus seven
  SDK runtime inputs at `eb274643bfcfe746617121ddc6f130b018978b53`; the isolated
  source closure is 217. Transport retains 25 typed bindings and 18 reviewed
  layouts. Root `build/toolchain/fairyc.exe check --locked` exited 0 with
  254 sources / 2899 MIR functions. Root locked check was rerun while archiving;
  native verifier/executables and public CLI were not rerun.

The [native suite entry](../../tools/runtime-engine/main.fy) invokes these
**11 new groups**. Five are in
[slice_result_cursor.fy](../../tests/m2/slice_result_cursor.fy):

1. `cursor_empty_moves_and_resets_only_resume_control`
2. `quantum_boundaries_and_begin_rejections_preserve_every_counter`
3. `finish_aggregates_pending_complete_and_error_histories_once_per_batch`
4. `begin_reserves_full_quantum_headroom_and_finish_overflow_is_atomic`
5. `malformed_states_and_compatibility_helpers_obey_atomic_bounds`

Six are in [module_dispatch_quantum.fy](../../tests/m2/module_dispatch_quantum.fy):

1. `loop_and_nested_void_output_resumes_without_replaying_emits`
2. `returned_input_and_static_ranges_keep_frame_maps_and_binary_loans`
3. `array_list_indexed_places_and_record_calls_preserve_owners_between_batches`
4. `runtime_errors_and_fuel_exhaustion_keep_exact_diagnostics_and_no_partial_output`
5. `invalid_quanta_reject_before_output_prepare_without_touching_stats_fuel_or_heap`
6. `detached_quantized_publications_outlive_program_and_input_and_move_without_replay`

## Limitations and remaining work

**Setup, proof, bulk helpers, copy, CALL, RET, cleanup and publication remain
atomic with respect to instruction-batch suspension.** They have no internal
quantum boundary here. Bounding instruction visits does not bound payload bytes,
metadata visits, native work, elapsed time or stack use.

- **R03 remains open:** move execution into persistent Instance storage and add
  resumable work recipes, including planning, transfers and final publication,
  before exposing bounded `Engine.step(1..4096)`.
- **R04 remains open:** no compile/run deadlines or in-flight cancellation;
  first-cause precedence, STOPPING cleanup, stable terminal snapshots and Engine
  poison containment remain required.
- **R05 remains open:** cleanup still runs atomically, including after Fuel
  exhaustion. Multi-chunk ownership commits, bounded root/group invalidation and
  broader result/Fuel invariance under equal resource/host outcomes remain due.

See the [remaining-work inventory](../product/04-remaining-work.md). Native stack
accounting/containment, host integration, complete Engine accounting, public
lifecycle APIs, restricted workers and embedding remain outside this slice.
The raw receipt's generic “No bounded step quanta” limitation refers to that
unfinished bounded-work contract; the canonical evidence records the narrower
instruction batching implemented here. It does not establish latency or
performance guarantees.

# CALL snapshot stack storage

Implementation commit: `37d365a`.
[Windows development/O2 evidence](../evidence/runtime-call-stack-snapshots-windows-20261108.json).

`call_work_execution::{begin,advance}` must stage fresh, unpublished authority
and loan-pool values before copying payload or publishing a frame. Those staged
copies and their ordering remain necessary for transactional admission.

The previous source read `state.runtime.authority` and `state.runtime.pool` as
values. The pinned C transport first materialized the entire intermediate
`state.runtime` value for each projection. The implementation now borrows the
exact field and copies through that reference. It removes the two intermediate
parent values while retaining the required independent staged snapshots.

Generated C removes two 26,048-byte intermediate parent values from each of
`begin` and `advance`: 52,096 bytes of declared temporary storage per function.
Other parent projections remain. This is not a measurement of peak stack usage.
The final native verification below retains default stack settings.
This is a storage change; it does not add a work quantum, change Fuel prices,
reorder publication, or prove a latency/throughput bound.

## Owning CALL66 prerequisite

An attempted immutable CALL capture cache exposed a separate missing connection:
the private output compiler calls `lower_prepared` with `origin_analysis=false`,
which rejects non-shared returned-slice declarations. Output admission also needs
the complete normalized returned-view proof, and synchronous/pending execution
must receive independently proved selected origins. Existing low-level returned
view execution does not establish that owning Engine source path.

The required actual-source direct/chained exclusive-return fixtures are retained
with the pending cache draft in local Git stash `39f1c91`
(full identity `39f1c91dcaa8edef5194f8d37b75069d20ce92a0`, 16 paths); they must pass before claiming owning CALL66 cache
coverage. The cache integration is deferred, not implemented or verified by this
commit. First connect the private compiler, verifier, retained metadata and VM
entry, then integrate and execute those fixtures. Keep public admission gates
separate and preserve output, exact Fuel, live loan authentication and refunds.

R03-R05, broader metadata/catalog work, setup/proof/seal/cleanup, deadlines,
STOPPING/poison and public lifecycle/ABI/CLI remain open in the
[remaining-work inventory](../product/04-remaining-work.md).

## Executed verification

`build/toolchain/fairyc.exe check --locked` passes 271 sources/3032 MIR
functions. Both native development and O2 runs pass the existing Engine/kernel
regressions, including record CALLs, exact Fuel/output, moves, cancellation,
pinning, OOM and retained accounting. Both images use the default 1,048,576-byte
stack reserve and 4096-byte commit, without compiler/stack overrides, and leave
zero SDK heap allocations at exit. The 33 typed binding and 32 layout shapes
remain unchanged. All 268 receipt inputs plus two audit inputs match raw
checkout and committed Git; all 263 production modules retain LF.

The emitted C analysis compares the prior verified transport with this one.
The two changed functions each remove two parent temporaries; other parent
projections remain. Full M2/public CLI matrices, Linux, separate OS I/O and
packaging were not repeated. Pending CALL66 cache code is not in this native run.


The next implementation slices are the private output compiler/proof bridge,
proved selected-origin wiring through retained and pending execution, and then
the preserved capture cache plus its actual-source parity/storage fixtures.
Keep compiler, test and documentation write sets disjoint and integrate native
transport review and local commits serially.

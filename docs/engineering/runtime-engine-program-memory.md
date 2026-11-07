# Retained Program memory admission

The private Engine now checks exact persistent Program backing before allocating
its image or stored executable. It enforces a per-Program limit, total retained
Program limit, and the combined fixed-control-plus-Program ceiling. This extends
[control storage](runtime-engine-control-memory.md); it is not yet complete
compile working-space, per-Instance or process-memory accounting.

## Actual allocation classes

A module Program owns a `Vec<Stored>` with one initialized element. The pinned
SDK reserves eight elements initially. Engine retention additionally owns a
`Vec<module Program>`, also with capacity eight and one initialized handle.
Only one Stored and one literal owner are initialized; unused slots are charged
for allocated capacity but do not duplicate owning obligations.

The native bridge supplies actual emitted `sizeof(Stored)` and `sizeof(Program)`
facts for ordinary, input and output Programs. Checked arithmetic in
`runtime_program_memory::fixed` computes eight times each. Literal backing is
exactly the deduplicated decoded payload size, obtained from the checked image
Builder before `freeze`. There is no native parser or quota decision.

| Variant | Stored | Program handle | Fixed heap backing |
| --- | ---: | ---: | ---: |
| Ordinary | 22,016 | 48 | 176,512 |
| Shared-byte input | 22,008 | 48 | 176,448 |
| Output / input-output | 22,016 | 48 | 176,512 |

Add only actual literal payload P (0..4,096 bytes). Snapshot, IR, image catalog,
Buffer descriptor and other fixed metadata are already inside Stored. Adding
source length, Snapshot size, IR size or logical image charge 576 again would
count the same storage twice. Empty images allocate no payload.

## Preparation and publication

`create_with_retention(limits, control_limit, memory_limits)` configures private
`runtime_program_memory::Limits { engine, program, programs }`. Relations require
`program <= programs <= engine`; maxima remain respectively 64 MiB, 512 MiB and
1 GiB. The existing creation APIs retain their signatures and choose these
private maximum ceilings. Immutable accepted policy/run binding remains separate.

The available reservation is the minimum of the per-Program ceiling, remaining
Program-set budget, and remaining combined control/Program budget. An impossible
fixed backing rejects before invoking the compiler. Each selected compiler has
an explicit `compile_with_retention` path. After source lowering, it checks exact
fixed backing plus planned literal payload before image copy and Stored allocation.
Ordinary `compile` APIs use an unlimited plan and preserve existing admission.

Engine admission is exclusive and synchronous throughout preparation and publish;
no guest work, callback or reentry can consume the reserved allowance meanwhile.
The local plan records the exact reservation before allocation. The Engine records
its historical reservation peak on return, including an admitted allocation that
later fails. Only successful owning publication increases retained bytes and
issues an object ID. Failed quota, source validation or allocation publishes no
Program and leaves existing owners and charges intact. Private quota diagnostic
kind 21 maps to Engine resource-limit status 8; actual allocation kind 15 maps to
OOM status 6. These are not new public CLI language gates.

The Engine wrapper's incoming Entry vector and caller-created Index already
exist outside this persistent-retention preflight. Array-list lowering can also
allocate temporary vectors before the image plan. They are compile working
storage, not silently included in Program bytes; their aggregate limit remains
unfinished. This guarantee is about persistent Program allocation, not zero
allocation for the entire compile operation.

## Lifetime and observations

`program_memory(ref engine)` checks owner-thread/reentry, consumes no work epoch
and returns detached current/peak observations. `program_bytes` counts all actual
retained Program backing, including released Programs with live Instance pins.
A pin release returns no bytes until the last Instance is destroyed; middle/front
removal and scratch relocation transfer the same charge without copying it.
Actual Program destruction returns the exact stored charge once.

Moves preserve the ledger. Explicit destroy requires no children and no remaining
Program charge, closes it and preserves both historical Program and tracked peaks.
A closed owner-thread observation remains available. Implicit owning cleanup
reclaims the resources normally. Detached guest output remains governed by its
separate Output lifetime; its payload is not counted as Program storage.

`program_peak` is a reservation high-water mark, not a measured CRT/RSS high-water
mark. `tracked_bytes`/`tracked_peak` include fixed control and retained Programs
only. Input/output payloads, VM state and compiler working storage still need
integration before an API can claim total Engine memory enforcement.

## Verification

[Executed evidence](../evidence/runtime-engine-program-memory-windows-20261107.json)
records the source/transport/compiler identities and native development/O2 results.
The image includes the original control, input, output and OS lifecycle fixtures,
retention-plan arithmetic tests and actual Engine retention boundary/lifetime tests.
Native SDK instrumentation independently compares live heap requests with the
sum of seven control vector blocks plus reported retained Program bytes.
The source/IR/proof/output regression image separately passes 39 groups per profile,
including the unchanged combined captured-call depth 32/33 fixture.

Compile working storage and its transient old/new peaks, Instance frames and
owner/loan/descriptors, input/output and pending host state, combined simultaneous
Instance quotas, bounded steps, deadlines and public delivery remain in
[the accepted inventory](../product/04-remaining-work.md).

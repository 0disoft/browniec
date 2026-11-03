# System Boundary

- Status: Accepted target; public scalar/aggregate/scalar-slice subsets, private foundations, M3-M5 pending (2026-11-03)
- Owner: Zerodi / Rodisoft

The [current implementation/remaining-work audit](../product/04-remaining-work.md)
separates executable core features from target responsibilities below. Engine
poison, host suspension, staged guest output, isolation and the embed ABI are not
implemented merely because they are invariants of the intended system.

## Owned responsibilities

Brownie C owns source validation, type/Flow analysis, private bytecode generation,
verification, VM state, quotas, typed host suspension, and staged output. The CLI,
restricted broker/worker, and trusted embed ABI are distinct delivery surfaces.

Parser, analysis, verifier, and dispatch remain Fairy C. Narrow allocator, codec,
and OS shims must expose explicit preconditions and fallible results.

## External authority

Fairy C and the native SDK own build-time capabilities. Their separate repository
is not modified here. Go bootstrap tooling does not imply a Go runtime dependency.
Windows owns AppContainer/Job enforcement; actual integration evidence is required.
Host adapters own credentials, destination authorization, and external effect state.

## Trust crossings

Treat source, project members, input, IPC, and host replies as untrusted. Validate
bounded snapshots before consumption. Reachable requirements must fit declarations,
run grants, and the trusted policy ceiling; source metadata grants no authority.
Private bytecode cannot be supplied externally. No disk runtime code cache exists.

## Failure containment

Guest failure ends one Instance. Internal runtime invariant failure poisons the
Engine. Native corruption is not assumed recoverable in process. Untrusted source
requires the tested restricted worker; failed isolation setup never falls back.
Output staging cannot undo host effects. The host owns reconciliation of unknown
outcomes and the VM never silently retries them.

See [Architecture](../../ARCHITECTURE.md) and [ADR 0001](../adr/0001-initial-architecture-boundaries.md).

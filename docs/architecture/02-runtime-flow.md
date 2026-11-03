# Runtime Flow

- Status: Target full flow; narrow scalar/aggregate/scalar-slice execution implemented (2026-11-03)

The flow below is the target architecture. The current CLI reads one bounded source,
compiles/verifies and executes scalar, array, record and scalar-slice programs with
Fuel and bounded VM frames. Private Buffer and returned-origin components do not
provide guest Buffer or returned-reference execution. Explicit projects/input,
Engine/Instance stepping, typed host suspension, guest-output staging, restricted
workers and embedding remain open in the
[complete remaining-work audit](../product/04-remaining-work.md).

## Source to result

1. Select explicit source/project, policy, catalog, entry, input, grants, and limits.
2. Read bounded source snapshots and reject invalid metadata or paths.
3. Parse, resolve, type check, and compute ownership/Flow facts.
4. Emit private typed bytecode; independently verify it into an immutable Program.
5. Create a one-shot Instance with reserved state and an owned input snapshot.
6. Step within Fuel and other limits. Guest calls use VM frames.
7. On a host operation, suspend with a typed request. Validate authority and the
   bounded reply before committing it to the Instance.
8. On normal completion, finish publication checks and publish staged output.
9. On failure, discard unpublished output and perform bounded runtime-ledger cleanup.

## Restricted path

The trusted parent prepares actual AppContainer/Job isolation and bounded private
IPC before collecting untrusted work in the worker. Compile untrusted source in
that worker. Preparation failure stops the operation.

The broker rejects illegal phase transitions before cancellation. After cancellation,
it may drain bounded lawful late frames without adapter dispatch or publication.
A staged RESULT alone is insufficient: normal exit, expected EOF, valid deadline,
and no failure/cancellation must satisfy the publication barrier. I/O lease storage
remains reserved until completion, even after cancellation is requested.

## Interruption and effects

The first terminal cause remains available through cleanup. An output sink can fail
after computation and may have partial writes. Host effects can complete despite a
lost reply or cancellation; report unknown state and leave reconciliation to the host.
Do not automatically rerun a failed Instance or replay host effects.

See [output semantics](../cli/output-and-exit-codes.md) and [Validation](../../VALIDATION.md).

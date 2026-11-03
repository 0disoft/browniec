# Domain Model

- Status: Designed full lifecycle; narrow reusable Program/fresh VM state and aggregate/slice owners implemented (2026-11-03)

Public arrays/records/scalar slices and private Buffer ledgers do not yet provide
the full Engine/one-shot Instance/host/output lifecycle below. See the
[remaining-work audit](../product/04-remaining-work.md).

| Concept | Meaning and lifecycle |
| --- | --- |
| Engine | Owner-thread-bound coordinator, policy ceiling, and failure state |
| Program | Immutable verified code, constants, layouts, maps, and bindings; explicitly reusable |
| Instance | One-shot run with input, frames, grants, loans, owners, pending work, and staged output |
| Buffer | Fallible owned dynamic bytes; moves as a whole |
| Owner/token | Runtime identity and generation checked before access; never a guest native pointer |
| Loan | Shared or exclusive whole-root borrow with checked lifetime and origin |
| Policy ceiling | Trusted maximum authority and limits |
| Run grant | Explicit authority for one run, bounded by the ceiling |
| Host request/reply | Typed bounded suspension protocol; does not transfer ambient authority |
| Publication | Release of staged output after successful completion and final checks |

## Invariants

Instances are not reset or replayed. Programs are reused explicitly, without an
implicit Program cache. Parallel execution uses separate Engines.
Owned values move together. Conflicts apply to the whole root even through distinct
fields or indices. A returned borrow has one input origin or Static storage.
Aggregates become readable only after complete initialization.

Pending host work owns its reservations until reply validation or bounded cleanup.
Moving a Buffer cannot invalidate live loans or leave unaccounted owner metadata.
An Engine invariant failure prevents further ordinary execution on that Engine.

## Observable outcomes

Normal guest integer results are data. Compilation rejection, guest trap/quota,
cancellation/deadline, internal error, and worker failure remain distinct outcomes.
Output publication does not establish rollback or exactly-once external effects.
The [specification](../product/02-spec.md) owns detailed source semantics.

# Operational Contract

- Status: Initial delivery expectations; no released runtime or service
- Delivery owner: Zerodi / Rodisoft

## Critical journeys

Protect source checking, bounded execution, and honest publication of result data.
The first supported delivery target is Windows 11 x64; support is not yet verified.
Restricted execution and trusted embedding remain unavailable until their respective
OS and DLL milestones pass.

## Failure tolerance

Reject denied authority, resource exhaustion, invalid input, or unavailable isolation
explicitly. Never fall back to an unrestricted worker. Discard unpublished output
on guest failure. Poison an Engine after an internal runtime invariant failure.
A native process crash is a failed operation, not a successful guest result.

## Recovery ownership

The host owns external effects, credential management, and reconciliation of unknown
outcomes. No automatic replay or rollback is promised. Bound worker termination and
retain I/O leases until actual completion. Recovery-time and data-loss SLAs are not
set for this unreleased local runtime.

## Release evidence

Tie validation to the delivered artifact and supported profile. Core delivery needs
native source execution; restricted delivery additionally needs real Windows isolation;
embed delivery needs actual DLL export/call. Clean-machine packaging must separate
build-tool requirements from end-user runtime needs.

Do not create service monitoring, backup jobs, or CI deployment infrastructure before
there is an implemented surface to operate. Other ops documents remain Draft prompts.
See [Validation](../../VALIDATION.md) and the [roadmap](../product/01-roadmap.md).

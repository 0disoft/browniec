# Operability and Failure Standard

- Status: Scalar compile/arithmetic/Fuel/CLI outcomes verified; wider failure behavior designed

## Outcomes

Distinguish invalid invocation, source rejection, authority denial, guest termination,
internal invariant failure, and worker/output-sink failure. A guest i32 is result data.
Retain the first terminal cause through bounded cleanup and report cleanup failures
separately. Internal invariant failure poisons the Engine.

## Completion and effects

Publish staged bytes only after normal completion and the delivery-specific barrier.
Cancellation closes publication. Forced worker termination and a staged RESULT alone
are not success. Output sinks can partially write before failing.

Do not describe VM cleanup as rollback of a host operation. A lost reply or cancelled
run may leave a completed external effect. The host owns reconciliation and any
explicit recovery decision; no automatic retry, replay, or exactly-once promise.

## Diagnostics

Report bounded source locations, operation/request identities, terminal cause,
publication state, and relevant quota usage. Keep credentials, raw source/input,
and unrelated paths out of default telemetry. Debug evidence must be opt-in and bounded.
Use [CLI output rules](../cli/output-and-exit-codes.md) for public framing.

## Evidence and ownership

Test representative failure boundaries in their native or OS environment. Models do
not establish process cleanup or isolation. The maintainer implementing each slice
owns its evidence; Zerodi / Rodisoft owns delivery decisions.
See the [operational contract](../ops/00-operational-contract.md).

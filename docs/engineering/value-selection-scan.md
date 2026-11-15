# Select canonical values with one scan

The private retained-value runtime previously inspected the same immutable
source twice in both `value_frames::tag_test` and `case_value`: once to discover
and authenticate its active Buffer, then again inside `value_codec::select`.
Valid wrappers paid for both passes even when the requested branch did not
match. Repeated predicates and pattern matching multiplied this byte work.

`value_codec::inspect_selection` now returns the active-root metadata and branch
decision from one fresh canonical inspection. A private helper derives the
decision without another scan. Both it and raw `select` use that same helper;
no caller-supplied inspection or unchecked public selection entry is accepted.
The frame coordinator authenticates the returned active root before accepting
the branch decision. Nothing is cached across operations.

## Ordering and ownership

The joint result deliberately contains a deferred `Result<Selection, Error>`.
An invalid requested variant or a non-wrapper is a branch Type error, but an
invalid byte sequence must still win first, followed by a native Owner error.
Returning the branch error directly from the codec would change that priority.
Raw `select` retains its existing kind/variant-before-byte-inspection order.

Frame address checks, canonical byte inspection, exact root binding lookup and
destination checks still execute. The existing matched/mismatched branch body,
payload copy, root handoff, source consumption and publication are unchanged.
The current Fuel prices, quotas and cleanup behavior are retained. Only small
transient metadata is added; no payload snapshot, persistent proof or cache is
introduced. This does not change public CLI admission.

## Quantitative scope

For each valid wrapper/variant, canonical inspection calls decrease from two
to one, including branch mismatches. The byte-dependent validation component
decreases by 50%; both versions remain O(Q * B) for Q selections scanning B
bytes, with O(1) auxiliary space and no additional allocation calls.

For a canonical `none` of `Option<i64[4096]>`, the wrapper is 32776 bytes. Each
inspection reads its tag and validates all 32775 zero padding/payload bytes.
Validation byte reads therefore decrease from 65552 to 32776 per selection.
The constant-time branch tag read is separate and unchanged. These are source
operation counts, not measured throughput, latency or physical memory peaks.
Integer arrays with active payloads already skip their unrestricted integer
bytes; no full-payload scan improvement is claimed for that case.

## Focused validation

Run `build/toolchain/fairyc.exe check` to refresh the source lock, then
`python -B tools/verify-value-selection-scan.py --profile all`. The focused
suite includes the independent inspect-then-select oracle, byte mutations,
four nested wrappers, a maximum inactive integer array, late invalid bools,
native root errors, exact Fuel boundaries, source preservation and recursive
ownership/payload extraction. Both development and release use default stacks
and byte-identical input mirrors without native overrides.
Development and release each passed all 14 groups; every one of the 376 input
hashes also matches the implementation commit.

See the [Windows evidence](../evidence/value-selection-scan-windows-20261115.json)
for executed results and implementation/input identities. Full Engine transport,
public CLI, standalone memory and full release gates are outside this check.
The known legacy `struct_subassign_source` failure was not retested or fixed.

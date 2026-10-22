# Security Baseline

- Status: Accepted design controls; no security verification
- Default: deny host capability

## Trust model

Source, project metadata, input bytes, host request contents, IPC frames, and child
messages are untrusted. The Brownie native runtime, platform allocator, trusted parent
broker, and configured host adapters form the trusted computing base for their paths.

The native VM does not call host callbacks directly. Guest code suspends with a typed
request, and the host returns a bounded typed reply. Reachable requirements, declared
requirements, run grants, and the Engine policy ceiling form a narrowing chain.
Manifest or catalog identity is binding information, not authorization.

## Isolation

Trusted native hosts may embed Brownie in process. Arbitrary external source requires
an independently tested Windows restricted worker. AppContainer access and Job limits
must be measured on the actual OS before restricted delivery is enabled.

The broker rejects pre-cancel phase violations, including illegal RESULT, HOST_REQUEST,
exit, or EOF ordering. After cancellation, already lawful late frames may be drained
only within phase/session caps and grace; they must not execute host work or publish
output. Malformed frames are faults but do not overwrite the first cancellation cause.

## Resources and publication

Quotas are checked before allocation and include old plus new memory peaks. Payload,
depth, token, metadata-work, owner, loan, descriptor, host-call, and output limits are
enforced independently. Output stays staged until normal completion and publication.

Buffer growth tries a preferred rounded candidate, then the minimum rounded required
capacity when the preferred candidate exceeds an object, Instance, or Engine ceiling.
Allocator OOM is distinct from quota rejection. External effects are not automatically
retried, rolled back, or reported exactly once.

## Residual risk

Native memory corruption is not proven recoverable inside one process. Worker restart
containment must be tested at the OS boundary. A successful format check does not prove
that returned policy data, bytes, or an external effect is correct.

No sandbox security, timing, or side-channel claim follows from the design package.
Every restricted or embed security assertion needs execution evidence in VALIDATION.md.

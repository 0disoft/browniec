# Dependency and Change Policy

- Status: Accepted policy; toolchain.json records the adopted compiler/SDK and platform artifact identities

## Necessity

Prefer existing Fairy C or platform capabilities. Before adding a dependency, record
its purpose, build/runtime role, alternatives, license, maintained owner, and removal
cost. Keep native shims narrow; do not replace the core VM with a foreign runtime.

## Versions and identity

Use supported major-version ranges where the ecosystem supports them, with a lock
or recorded build identity for reproducibility. Adopt compatible stable updates;
promote a new major after targeted compatibility checks. Do not freeze an old compiler
snapshot forever. Pre-stable Fairy C changes require explicit corpus/native review.

Record actual Fairy C, Go bootstrap, native compiler, and SDK identities at build
time. Separate development prerequisites from end-user runtime dependencies.
A dated design-package hash is provenance, not an adopted or latest toolchain.

## Change scope

Update affected contracts and consumers together. Layout changes touch compiler,
verifier, VM, codec, and independent vectors. CLI changes touch help, examples,
configuration, results, and exit codes. Isolation or ABI changes need real integration
evidence. Use a new ADR for material accepted-architecture changes.

Keep commits small and verified. Group authorized pushes to avoid redundant CI runs.
No automatic version bump, release, dependency installation, or external repository
edit is implied by a documentation task.

See [Development](../../DEVELOPMENT.md) and [ADR 0002](../adr/0002-contract-source-of-truth.md).

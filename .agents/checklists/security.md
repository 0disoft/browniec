# Security Checklist

- Status: Draft

## Source of Truth

- [AGENTS.md](../../AGENTS.md)
- [VALIDATION.md](../../VALIDATION.md)
- [docs/architecture/00-system-boundary.md](../../docs/architecture/00-system-boundary.md)
- [docs/engineering/00-project-invariants.md](../../docs/engineering/00-project-invariants.md)

## Failure Modes

Wrong trust or effect authority, alternate-path access, identity leakage, unsafe input interpretation, excessive capabilities, and sensitive data exposure.

## Checklist

Complete applicable items only with evidence. Record unresolved choices and the reason for any skipped or inapplicable item.

- [ ] Affected assets, trust crossings, caller capabilities, and protected effects are identified from the actual system boundary.
- [ ] Relevant resource, account, and tenant authority is enforced on every reachable protected path, including rejected or revoked access.
- [ ] Untrusted input is validated and interpreted as data at the responsible boundary; alternate entrypoints and unsafe output contexts are accounted for.
- [ ] Credentials and private data have appropriate access, redaction, retention, and deletion boundaries across logs, examples, caches, and artifacts.
- [ ] External integrations and capabilities stay within the agreed authority, with failure, revocation, and uncertain effects handled where affected.
- [ ] Evidence covers relevant accepted and rejected cases and the actual exposure path; unverified conditions and remaining risks are explicit.

## Validation

- Relevant validation names: lint, test, smoke, check
- Select configured checks from VALIDATION.md for the affected contracts and failure paths.
- Report skipped or unconfigured checks with reasons and remaining risk; they are not passing evidence.

# Contributing

- Status: Initial contribution policy; documentation-only repository

## Scope

Zerodi / Rodisoft owns product scope and delivery decisions. Start from the
[specification](docs/product/02-spec.md) and [roadmap](docs/product/01-roadmap.md).
The next implementation work is M0 native feasibility, followed by M1 scalar execution.

Do not expand the language profile, replace core Fairy C logic with a host-language
model, or expose the restricted/embed levels without the corresponding design decision
and milestone evidence. The external design package is reference material only.

## Changes and review

- Describe the observable problem, intended behavior, and affected contract.
- Keep one useful delivery slice per commit and preserve unrelated changes.
- Update the owning document and affected consumers together; use a new ADR for a
  material architecture change.
- Prefer the existing branch. Do not modify the separate fairyc repository here.
- Use gitmoji-style commit messages until the repository adopts another convention.

## Evidence and delivery

Follow [Validation](VALIDATION.md). There is currently no configured build or test
runner. Report only checks actually run, with failures, skips, and relevant artifact
identity. Choose narrow checks for the changed behavior; document checks do not prove
native execution or security.

The change summary should explain behavior, validation, and remaining limitations.
Local commits, remote pushes, releases, and deployments are separate actions. Remote
delivery requires the owner's authorization; a local commit is not a published release.

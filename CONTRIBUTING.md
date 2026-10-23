# Contributing

- Status: Initial contribution policy; experimental native M1 scalar implementation

## Scope

Zerodi / Rodisoft owns product scope and delivery decisions. Start from the
[specification](docs/product/02-spec.md) and [roadmap](docs/product/01-roadmap.md).
M0 and the first M1 scalar slice exist. Continue M1 in small source-to-VM increments.

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

Follow [Validation](VALIDATION.md). Use the root Fairy build and
`tools/verify-m1.ps1` for scalar source/VM changes, and the separate M0 harness when
its native primitive inputs change. Report only checks actually run, with failures, skips, and relevant artifact
identity. Choose narrow checks for the changed behavior; document checks do not prove
native execution or security.

The change summary should explain behavior, validation, and remaining limitations.
Local commits, remote pushes, releases, and deployments are separate actions. Remote
delivery requires the owner's authorization; a local commit is not a published release.

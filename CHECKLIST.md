# Checklist Router

- Parser stack containment: implemented at `10822ee` and `6cbe716`.
  Separate statement, identifier and local-read handlers keep unrelated scratch
  off recursive paths. Mixed-arm depth 10 and scalar-call depth 32 remain valid;
  excessive nesting returns `compile_limit`. Both Windows profiles passed six
  focused native groups and 2,335 CLI cases (full M1: 2,007; relevant M2: 328),
  with 127 matching input hashes. The full 84-group native suite, other M2
  matrices and Linux were not rerun. This resolves the parser follow-up from
  the historical toolchain adoption below without changing its evidence.
  See [the parser contract](docs/engineering/m1-parser-stack.md).

- Status: Draft

Use this file as a router. Choose checklists for affected contracts and failure paths, combining common, scope, and repository-type guidance when their responsibilities overlap.
Use the project's task routing and validation policy to select procedures and configured checks. This list does not require every checklist for every task or grant additional execution authority.

## Task Checklists

This list reflects the checklists generated for the selected scope, repository type, addons, and density. Select applicable items and record evidence, unresolved choices, and reasons for skipped or inapplicable checks. Update the list when the project retires or replaces a checklist.

- [Security Checklist](.agents/checklists/security.md)
- [Ops Change Checklist](.agents/checklists/ops-change.md)
- [Performance Checklist](.agents/checklists/performance.md)
- [Dependency Checklist](.agents/checklists/dependency.md)
- [CLI Tool Checklist](.agents/checklists/cli-tool.md)

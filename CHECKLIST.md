# Checklist Router

- Shared VM slice lifecycle: implemented at `eb8fcdd`.
  The shared execution loop tracks function/frame context, uses dynamic slice
  dispatch, and cleans borrowed roots before scalar/array/record returns.
  Invocation cleanup drains loans before clearing root bindings, preserving
  the original outcome or surfacing cleanup failure with metadata retained.
  Public borrowed execution remains gated; native integration exercises the
  shared loop after independent inspection. Public gate/CLI promotion is next.
  Development and release each passed five native groups and 2,541 CLI cases,
  with 372 matching input hashes and retained CLI identities.
  See [the lifecycle contract](docs/engineering/m2-array-slice-lifecycle-vm.md).

- Gated VM CALL frame publication: implemented at `89bd0bf`.
  CALL now uses mixed owner/borrow admission, stages at most eight scalar values,
  and publishes scalar arguments and child return metadata only after success.
  Non-scalar positions remain untouched. Public borrowed execution stays gated;
  dynamic slice dispatch and automatic normal/error cleanup are the next slice.
  Development and release each passed four native groups and 2,297 CLI cases,
  with 369 matching input hashes and retained CLI identities.
  See [the CALL frame contract](docs/engineering/m2-array-call-frame-vm.md).

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

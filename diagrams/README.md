# Diagrams

- Status: Draft
- Owner: UNASSIGNED

## Available Views

These diagrams are design prompts, not accepted architecture. Each view asks one question and points to the document that owns the corresponding decisions.

| Diagram | Reader question | Decision source |
| --- | --- | --- |
| [system-context](system-context.mmd) | Which actors and external systems interact with the owned system? | [Source](../docs/architecture/00-system-boundary.md) |
| [container-view](container-view.mmd) | Which components own entry, core behavior, state, and external integration? | [Source](../ARCHITECTURE.md) |
| [core-runtime-flow](core-runtime-flow.mmd) | How does an operation reach observable completion or recover from partial effects? | [Source](../docs/architecture/02-runtime-flow.md) |
| [release-flow](release-flow.mmd) | Which evidence permits promotion, and what happens if release health is unacceptable? | [Source](../docs/ops/release.md) |
| [rollback-flow](rollback-flow.mmd) | Can the observed state be reversed safely, or does it require forward recovery? | [Source](../docs/ops/rollback.md) |

## Maintaining a View

- Replace UNDECIDED identities, boundaries, edge actions, and branch conditions with evidence from the decision source. Remove branches that do not apply.
- Keep composition views separate from operation flows. Data-model edges do not assert cardinality until the project specifies it.
- Label all interactions and outcomes. For operation flows, record failure, interruption, partial state, recovery ownership, and bounded retry rules where reachable.
- Keep reported success consistent with observable completion; a cancellation or timeout does not by itself prove that external effects were undone.
- Update the source document and related decision record when meaning changes, then update the diagram. Preserve project-specific edits during scaffold updates.
- Review rendered Mermaid output in the project's chosen viewer; source generation alone does not verify layout or accessibility. Keep the reader question and decision source available as a text description.

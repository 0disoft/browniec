---
name: test-hardening
description: "Improve evidence for existing behavior or a demonstrated regression through independent expectations, meaningful failure fixtures, and proportionate execution cost."
---

# test-hardening

## Read First

- [AGENTS.md](../../../AGENTS.md)
- [VALIDATION.md](../../../VALIDATION.md)
- [CHECKLIST.md](../../../CHECKLIST.md)
- [.agents/context-map.md](../../../.agents/context-map.md)
- [docs/engineering/05-testing-standard.md](../../../docs/engineering/05-testing-standard.md)
- [docs/engineering/00-project-invariants.md](../../../docs/engineering/00-project-invariants.md)

## Work Guidance

- Identify the contract, invariant, or user-visible risk whose current evidence is weak. Determine what observation would disprove correctness rather than starting from an arbitrary coverage target.
- Define the expected result independently of the implementation. Include relevant rejection, interruption, partial-effect, or recovery states rather than checking only a successful call.
- Control ordering or failures where needed and report unsupported conditions as explicit gaps. Avoid timing repetition, swallowed fixture errors, and assertions that would pass after removing the protected behavior.
- Run the narrow checks that establish the risk. Remove redundant or obsolete checks only after confirming that their required evidence remains covered.

## Validation and Delivery

Use repository rules and the task routes in VALIDATION.md to select relevant configured checks. Repair missing setup within the authorized scope or report the gap; an unconfigured or skipped check is not passing evidence.

Report observable changes, actual checks and results, remaining gaps, and incomplete recovery or delivery work. Follow existing execution and delivery authority; this skill does not authorize additional publication or external mutations.

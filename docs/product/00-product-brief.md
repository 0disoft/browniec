# Product Brief

- Status: Accepted initial direction; delivery reconciled 2026-11-03
- Product owner: Zerodi / Rodisoft
- Implementation: M0/M1 checkpoint evidence; public M2 arrays, records and scalar slices; private Buffer/returned-origin foundations; M3-M5 unavailable

## Intended outcome

Application developers should run small validation, byte-transformation, and rule
programs with explicit resource limits and host permissions. Brownie C combines
Fairy-like syntax with a small native interpreter whose end users need no compiler.

These workloads are hypotheses. There is no demonstrated customer demand, measured
advantage over existing languages, or commitment to replace Python.

## First delivery

Windows 11 x64 is the first target. The experimental native CLI runs six scalar
types, arrays, nominal scalar/nested records, aggregate parameters/results and
shared/exclusive scalar slices, including inline ranged/temporary CALL arguments.
Fixed-array UTF-8 validation is public. Private Buffer components and returned-
origin analysis do not yet provide guest Buffer or executable returned references.

Full-profile language/reference completion, guest input/text/output, Engine/Instance
integration, typed host suspension, restricted workers, trusted DLL embedding,
clean-machine packaging and measured performance remain open. The
[complete remaining-work audit](04-remaining-work.md) distinguishes these states.

The [specification](02-spec.md) owns the source profile; the [roadmap](01-roadmap.md)
owns M0-M5. Do not delay the core CLI until every later delivery level exists.

## Success and constraints

Success starts with real native programs that produce expected results and explicit
failure outcomes. Record startup, compilation, execution, memory, and retained build
outputs separately. Performance numbers are targets until measured.

Keep the core implementation in Fairy C, with narrow native shims. Do not trade away
checked arithmetic, ownership, quota enforcement, or output staging for speed.
Do not accept untrusted source without the tested restricted worker.

## Review triggers

Revisit scope after M0 feasibility and the first representative workload experiments.
Use observed developer tasks and measured costs before broadening the language.
Zerodi / Rodisoft approves material scope changes; record rationale in an ADR.

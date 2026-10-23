# Product Brief

- Status: Accepted initial direction, 2026-10-23
- Product owner: Zerodi / Rodisoft
- Implementation: M0 verified; experimental scalar CLI/VM implemented; broader product pending

## Intended outcome

Application developers should run small validation, byte-transformation, and rule
programs with explicit resource limits and host permissions. Brownie C combines
Fairy-like syntax with a small native interpreter whose end users need no compiler.

These workloads are hypotheses. There is no demonstrated customer demand, measured
advantage over existing languages, or commitment to replace Python.

## First delivery

Windows 11 x64 is the first target. M0 native feasibility is complete; the scalar
source-to-VM CLI is not. Build that CLI next, then aggregates and bytes, typed host
suspension, restricted workers, and trusted DLL embedding.

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

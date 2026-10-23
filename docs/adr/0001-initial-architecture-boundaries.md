# Initial Architecture Boundaries

- Status: Accepted for design
- Decision owner: Zerodi / Rodisoft
- Decision date: 2026-10-23
- Implementation at original decision: not started

## Context

Brownie C needs a small native runtime for validation, byte transforms, and rules.
Low allocation cost, bounded execution, and small retained build outputs matter.
Fairy C is evolving; native failure handling and ABI support need direct probes.
The reviewed source is recorded in the [design baseline](../design-baseline.md).

## Decision

- Implement parsing, type/Flow analysis, private code generation, verification, and
  VM dispatch in Fairy C. Allow only narrow allocator, codec, and OS shims.
- Use a JIT-free typed register VM with ownership, whole-value moves, and no guest
  tracing GC or reference counting.
- Keep immutable reusable Programs separate from one-shot Instances and an
  owner-thread-bound Engine. Source is the only public executable input.
- Deny host access by default; suspend through typed host request/reply records.
- Deliver the source CLI first. Require actual Windows worker isolation before
  accepting untrusted source, and actual DLL export/call evidence before embed.
- Run source in the delivered binary without launching a compiler subprocess.

## Alternatives and consequences

A Go VM would simplify implementation but introduce runtime and GC costs to evaluate.
A Rust VM would offer mature memory-safety tooling but add a separate toolchain and
build-output management. C would reduce toolchain novelty but expand manual native
safety work. Fairy C fits the chosen implementation direction, at the cost of
unproven native capabilities; it is not presumed faster or safer by language choice.

M0 must expose feasibility gaps before the VM grows. M1 provides a usable scalar
path without waiting for the worker or DLL. OS isolation and trusted embedding are
separate delivery obligations, not properties inferred from bytecode verification.

## Verification and review

At the original decision, no native implementation was verified. Follow [M0-M5](../product/01-roadmap.md) and
[Validation](../../VALIDATION.md). Revisit the decision if native failures cannot be
returned as status, quotas cannot be enforced, or the required isolation is unavailable.
Material changes require a new ADR that links and supersedes this record.

## Implementation note (2026-10-23)

M0 and the first [M1 scalar source/VM slice](../engineering/m1-scalar-slice.md) now
have native evidence. This does not promote the full profile or later delivery
levels. The CLI JSON contract is manually owned; no schema generator is introduced.

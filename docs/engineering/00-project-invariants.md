# Project Invariants

- Status: Accepted design invariants
- Implementation: M0 verified; bounded i32/i64/u8/u32/usize/bool verifier/VM subset with branches, loops, shallow tagged switch, scalar `?` propagation, and switch expressions implemented; switch expressions, i64, and unsigned scalars verified; full invariants pending

## Runtime authority

Program is immutable and explicitly reusable. Instance is one-shot. Engine is bound
to one owner thread and may coordinate multiple instances sequentially. There is no
runtime Program cache, external bytecode input, or disk bytecode cache.

Parser, type checking, Flow analysis, verifier, and dispatch remain in Fairy C.
Allocator, scalar codec, and OS access may live in explicit bounded shims whose
signatures and failure modes are recorded by native probes.

M0 records signatures and failure modes for the first arithmetic, codec, storage,
allocator, owner, and frame probes. Those primitives do not implement the VM or its
verification pipeline described below.

## Execution invariants

Source is UTF-8 and every accepted local is initialized. Expressions evaluate once
from left to right unless a documented short-circuit applies. Numeric promotion is
explicit and value-preserving. Checked arithmetic fails as a guest outcome rather
than a native trap.

An exhaustive switch expression evaluates its subject once, snapshots a mutable
subject, and selects exactly one variant arm. A yielding arm produces one exact
typed value; direct-return arms leave the function. The subject, selected arm, and
any executed local initializer use the normal bounded evaluation and Fuel rules.

Owned values move as a whole. No guest GC or owned-value reference counting exists.
Borrow conflict applies to the whole root. Returned references have exactly one input
origin or Static storage. Aggregates become readable only after complete construction.

Quotas are reserved before allocation and include old plus new peak. Preparation,
commit, cleanup, and descriptor reclamation are bounded work. Guest recursion uses
VM frames. Output remains staged until successful completion and publication checks.

## Verification invariants

The independent verifier validates bytecode structure, control flow, value layout,
registers, initialization, ownership, roots, loans, selected stores, and metering.
Compiler metadata is not trusted over recomputation where safety depends on it.

Plain-struct depth, tagged-wrapper depth, and total traversal budget remain separate
limits. The current M1 tagged slice admits wrapper depth one with scalar payloads;
rejecting nested or aggregate wrappers does not settle later nested-depth or
struct-depth budgets. Buffer growth must try the minimum rounded required capacity when its
preferred candidate exceeds a reservation ceiling; old-plus-new peak and owner
metadata stay reserved. Allocator OOM retry is a separate policy decision.

## Failure and effects

Guest trap terminates the Instance. A detected runtime invariant violation poisons
the Engine. Successful checks do not prove native memory safety. External effects can
complete with unknown state and are never automatically rolled back or retried.

A capability is denied unless controls prove the relation from reachable requirement
through declaration and grant to the Engine ceiling. Compliance requires recorded
evidence in VALIDATION.md and the relevant milestone.

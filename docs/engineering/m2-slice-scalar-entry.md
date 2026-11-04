# Ordinary scalar entry in the canonical reference VM

Date: 2026-11-04. This is a private native integration step toward B04. Public
returned-reference declarations and result bindings remain gated.

`vm::run_slice_scalar` accepts the independently verified returned-view unit,
formal-indexed scalar cells, borrowed captures and optional array/record owner
tokens. The entry must return an ordinary scalar; borrowed and aggregate entry
results are rejected before entry. The existing borrowed-result APIs retain their
signatures and their borrowed-result requirement.

## Execution and ownership

Both entry kinds share admission, bounded frames, CALL/return dispatch, canonical
authority and the existing failure drain. Ordinary scalar entry can execute the
existing scalar, array and record value CALL paths. Its terminal return closes
its initial frame without trying to pop a nonexistent guest caller.

Success returns the scalar cell, remaining Fuel and eight formal-indexed resumed
tickets. A retained exclusive input receives its fresh generation. A closed input
has the dead ticket, unless closing an anonymous caller reborrow restores its
parent; that parent ticket is returned instead. Native hosts must use the returned
tickets rather than their pre-entry generations. Scalar values use the existing
i64 cell representation, including unsigned bit patterns.

Ordinary return now stages caller capture cleanup with its existing loan and
owner transaction. After callee loan restoration, anonymous captures close in
reverse argument order. Caller reborrows unwind through canonical child authority;
independently opened captures close through the pool. Requested root drops follow
all capture closes and deduplicate roots. A late close/drop failure publishes none
of this metadata. Owned entry arguments remain value copies of native tokens;
explicit borrowed capture drop directives retain their existing meaning.

After initial entry, a failure drains invocation metadata, preserves prior payload
writes and returns the first error. Admission or initial preflight rejection leaves
the original native state intact. This remains a trusted native module API, not a
hardened C ABI.

## Fuel and native storage

The existing [Fuel schedule](m2-slice-result-fuel.md) applies unchanged: entry
147456, ordinary return 196608, plus dispatch, formal arity and any existing value
copy charges. A two-instruction scalar entry completes with exactly 344066 units;
one fewer unit rejects the terminal return and drains at zero execution Fuel.
The public CLI default remains 256 and its explicit cap remains 1000000.

Ordinary return capture cleanup adds at most eight close/child operations to the
existing 70-operation upper bound. The reserved 80 pool primitives still cover
that work. Eight scans of the 31-entry child stack fit the existing fixed metadata
allowance alongside root cleanup. No cleanup reserve is refunded.

Entry snapshots are borrowed by the frame driver. The driver reads authority
availability through a reference to the authority stack itself. This avoids keeping
large compiler-generated copies of outer runtime metadata alive across ownership
transactions. The exploratory descendant test overflowed the default Windows
native stack before this change; it subsequently passed without changing stack
or compiler flags. This is a reproduced regression fix, not a stack-size benchmark.

## Verification scope

`tests/m2/slice_scalar_entry.fy` has seven groups covering nested value CALLs,
scalar limits, borrowed capture retention/close/drop, exact Fuel, first-error and
prior-write behavior, native value-copy inputs, anonymous parent restoration,
wrong entry/input rejection and transactional late cleanup failure.

Reproduce these groups with:

```text
build/toolchain/fairyc.exe test --native --capture-output --json --locked --file tests/m2/slice_scalar_entry.fy
```

Windows development passed **63 native groups and 217 tool-free CLI cases**, with
all 505 captured inputs rechecked. Native results are fresh; no stack/compiler
flags were overridden. The [retained evidence](../evidence/m2-slice-scalar-entry-windows-20261104.json)
records affected ownership, frame, entry, Fuel and execution regressions, input
hashes and standalone CLI checks. Release was not run in this increment. Public result
destinations, retained Held bindings, argument/projection use, Static backing and
full B04 admission/execution remain open. Engine/Instance, Linux, restricted
delivery, DLL/ABI, allocator and performance checks are outside this increment.

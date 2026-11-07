# Parallel policy and host-exchange integration

Two isolated GPT-6.1 Sol High workers implemented disjoint policy/run admission
and native host exchange slices from `845a056`. Integration writes were serialized
on main. The production compiler and the separate Fairy C checkout were unchanged.
This is incremental implementation of the accepted inventory, not full completion.

## Integrated behavior

[Typed policy and run configuration](runtime-policy.md) admits every required
`brownie.policy/0.3` and `brownie.run/0.3` field, decoded unique keys and capabilities,
canonical checked integers, typed ranges, cross-resource relations and narrowed
run limits. It enforces `requires <= grants <= policy.capabilities` and exposes
an explicit recheck against the actual binding policy. Implementation is
`c774ee0`; 21 native groups passed in each Windows development/release profile.
All 267 worker inputs initially matched the integrated checkout byte for byte,
including the regenerated root lock. The independent oracle checked 378 mutation
vectors. This accepts metadata ceilings; it does not enlarge actual VM limits.

[Native host exchange](host-exchange.md), implementation `dcbba76`, consumes an admitted immutable catalog
and explicit host grants, owns one request/reply at a time, snapshots typed TLV
bytes and transfers actual reply ownership to an opaque Output. It checks exact
run/request identities, nonwrapping request IDs, per-message/cumulative limits,
Fuel admission, adapter budgets, cancellation/deadline checkpoints and frozen
terminal causes. It does not invoke an adapter, issue a VM opcode or resume a VM.
The integrating host performs any external effect. Nothing automatically replays
that effect after cancellation, malformed input or output adoption failure.
Development/release each passed 13 native groups, generated-layout and maximum
request-ID hosts, plus two explicit allocation-failure cases per profile.
The initial raw-loop draft reproduced release heap corruption. Three explicit
no-growth SDK validation barriers make ownership metadata writes observable
before moves/cleanup; removing them reproduces the failure in a negative control.

`tests/m2/runtime_admission_exchange.fy` composes both APIs. The native harness
maps explicit RunConfig grants to admitted catalog capabilities, decodes a real
request carrying 41, constructs the typed reply 42 and takes its owning result.
A second case proves that an Engine policy capability without a RunConfig grant
cannot begin a request or change its identity, counters or Fuel. These are actual
native component transactions, not source Program capability-binding evidence.
The existing combined admitted32/rejected33 depth fixture is retained separately
in this selected suite. All three release groups passed on the final root
(`8846b0f`). Run:

```text
python tools/verify-runtime-admission-exchange.py --profile release
```

## Deliberate boundaries

Policy schema ceilings such as 4096 frames and Fuel 1000000000000 are accepted
metadata, not current implementation capacities. Existing public Fuel default
256 / ceiling 16000000, 32 frames, 256 instructions, 16 owners, opcodes and prices
are unchanged. Public Buffer/host/restricted/embed availability is unchanged.

Host copying is synchronous and bounded by message size, with charges/timestamps
supplied by the trusted integrating owner. Full R03 work quanta, resumable copy,
OS deadlines, shared Engine accounting, complete poison/cleanup propagation,
Program catalog/requirements binding and VM host dispatch remain open. No claim
of public Engine/Program/Instance lifecycle or C ABI execution follows from these
components. No Linux/macOS, clean-machine or performance result is implied.

The main-thread owning Engine prototype was not integrated: the pinned compiler
rejects direct mutable projection through nested resource fields, and a second
metadata-storage draft failed compiler invariant checking. Ignored prototype
files are investigation artifacts only. The subsequent [owning Store probe](runtime-store-probe.md)
(`5453574`) proves a typed synchronous C field projector over actual owning
Store/Vec/Buffer resources in both native profiles. Drops are exactly `[22,11,33]`
and live heap allocations are zero. This provides an implementable storage
prerequisite; actual reusable Program pins and one-shot Instance lifecycle remain
open. Fabricated object IDs cannot substitute for owners.

## Evidence

Final component and composition receipts, input identity comparisons and known
skips are recorded in the [combined evidence](../evidence/runtime-admission-exchange-windows-20261107.json).
All 283 aggregate inputs match checkout/Git raw bytes; all 228 production modules
retain LF. Native evidence uses default stacks. Explicit allocator failure seams, when
recorded, are separate from ordinary native profiles. No environment compiler or
linker overrides are admitted by this integration. All work is local; nothing
was pushed, published, released or deployed.

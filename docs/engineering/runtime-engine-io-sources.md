# Owning Engine, anchored sources and runtime I/O integration

This local checkpoint integrates three separate implementation slices on `main`:

| Slice | Commit | Executed evidence |
| --- | --- | --- |
| Actual owning Engine/Program/Instance | `5ccb424` | Native development/O2, actual compilation and fresh VM reuse, pins/image move/relocation, OS completion contention, exhaustion cleanup and heap zero |
| Anchored Windows source collection | `1a6f5c2` | Five real OS groups per development/O2 profile, explicit roots/identities, reparse/multi-link denial, bounded reads and allocation/handle cleanup |
| Immutable input and staged output | `0b7231a` | Ten native groups/profile, seven visibility/lifetime negatives, generated layout/cleanup per profile and four explicit allocator-failure seams |

The [Engine](runtime-engine.md) now executes admitted selected source through the
existing complete module compiler and native VM. Its Programs own actual code,
source and image backing; Instances pin that executable. It is a private
synchronous lifecycle module, not a public generation-handle API or bounded step.
Owner completion uses its admitted identity and exact epoch without reacquiring
the global guard. A deterministic actual-thread regression holds that guard
during completion, proving an already committed operation is not stranded Busy.
After epoch exhaustion, bounded owner maintenance retains terminal observation
and teardown without issuing/reusing epochs or running new guest work.

The [collector](anchored-sources.md) is a separate Windows OS primitive. Its owned
copied bytes are independent of later file edits; filesystem acquisition has not
yet been connected to the Fairy/project/Engine loader. It does not promise a
point-in-time consistent file or global multi-file transaction. The
[I/O component](runtime-io.md) similarly owns real native backing but does not yet
bind guest input or `output::emit` to an Instance. A trusted native seal alone is
not evidence that the VM succeeded. These distinctions remain in the inventory.

## Reproduction and input identity

Executed from the root, using the pinned `build/toolchain/fairyc.exe`:

```text
python tools/verify-runtime-engine.py
python tools/verify-anchored-sources.py
build/toolchain/fairyc.exe check
python tools/verify-runtime-io.py --native-from build/parallel-runtime-io/build/runtime-io/20261107T071836233118Z/receipt.json
```

The I/O command reuses only hash-matching normal native reports produced earlier
in this same session. It reruns all seven negative compiler cases and all actual
layout/cleanup and allocator-failure seams in the final root. Without
`--native-from`, the verifier builds/runs the ten normal groups/profile itself.
This reuse does not represent another fresh execution of those normal groups.

All explicit native builds reject CL/_CL_/LINK overrides, use ordinary `/Od` or
`/O2` and verify default 1MiB/4KiB PE stacks. Runtime seams use an empty tool PATH.
The Engine executable compiles/runs Brownie source there without Go/MSVC/C tools.
Runtime Git objects and compiler identities are recorded; no fairyc source was
edited or rebuilt.

The root check passed **238 source files / 2665 MIR functions** and refreshed the
root lock only for the two new I/O modules. All **230** `src/*.fy` files retain LF.
All **228** production modules from `f78a734` remain byte-identical. The
[aggregate input manifest](../evidence/runtime-engine-io-sources-inputs-windows-20261107.json)
contains **206** unique inputs, each matched against both checkout bytes and the
current committed Git blob. Individual receipts remain linked from
[Engine evidence](../evidence/runtime-engine-windows-20261107.json),
[collector evidence](../evidence/anchored-sources-windows-20261107.json) and
[I/O evidence](../evidence/runtime-io-windows-20261107.json).

Original public admission gates, VM capacities and opcode prices are unchanged:
32 frames, 256 instructions, sixteen owners, default Fuel 256 and ceiling
16000000. Unchanged broad CLI/language suites were not repeated; these focused
native proofs and the final root composition check cover this increment.
No push, release, publication or deployment occurred.

## Next implementation

The two Sol High workers continue in disjoint ignored mirrors: collector bytes
to an actual owning Fairy source Snapshot, and selected public i32 shared-byte
input-entry signature admission. Main serializes patch review/integration and
commits; neither worker writes the root checkout or commits shared changes.

R01/I01/I02/C01 remain partial. Their next connections are immutable executable
policy/run association, source loader admission, actual input entry/VM arguments
and guest emit/success/terminal disposal. Complete Engine reservation/peak
accounting, R03 work quanta, OS deadlines, in-flight cancellation and poison
containment remain. Host suspension/adoption, restricted Windows delivery, public
embedding/package work and the broader accepted language/evidence inventory
also remain open. This checkpoint does not close the full implementation goal.

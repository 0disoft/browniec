---
title: Host Integration, Isolation, and Embedding
description: Tell apart what the public CLI runs today, what lives in internal Engine code, and what is still planned.
---

When reading the Brownie C repository, you will see components like `Engine`, `Instance`, `Buffer`, `--isolated`, and a C embedding ABI. Because features are rolled out incrementally, it helps to separate what you can actually run from the public CLI today from what stays internal or planned.

## Status Breakdown

| Area | Public CLI Today | Internal Repo Code (Private) | Planned (`unavailable` today) |
| --- | --- | --- | --- |
| Compilation & run | Single `.brc` (`<= 4096` bytes), `fn i32 main()` | `Engine`, `Program`, `Instance`, step quanta, project loader | Public `--project` CLI and policy files |
| Guest input/output | None (returns `return_i32` only) | `1 MiB` input `Snapshot` & `output::emit` in tests | CLI `--input`, `output_b64`, output sinks |
| Byte buffers | Fixed arrays, plain structs, byte literals, slices | Guest `Buffer` (`bytes::empty`, `bytes::copy`) | Public `Buffer` compilation |
| Host calls & policy | Denied by default (no host calls) | Host-wire TLV codec & policy JSON parsers | VM host dispatch & grant enforcement |
| OS isolation | Windows scalar `check/run --isolated` (`restricted_scalar: true`) | AppContainer / Job | Broader restricted execution (`restricted: false`) |
| C embedding ABI | **Not yet** (`embed: false`) | `bc_get_abi_info_v2` metadata & 64-slot handle tests | Full Engine/Program/Instance C exports |

## Two Practical Rules

1. **Internal `Engine` / `Buffer` APIs are not public CLI features yet.** They remain gated inside internal modules and native test harnesses until policy binding and accounting are complete.
2. **Isolation setup failure stops execution.** The CLI reports `unavailable` (exit `4`) and does not run the source outside the worker.

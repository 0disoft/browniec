---
title: Host Integration, Isolation, and Embedding
description: Exact boundary between public CLI features, internal Engine/Buffer primitives in the repo, and planned isolation or C embedding work.
---

Brownie C's design separates untrusted rule execution from host resources through explicit policy ceilings, restricted workers, and a C embedding ABI. Because the project is built in increments, it is essential to separate **what the public CLI exposes today**, **what exists internally in repository modules**, and **what remains planned**.

## Three-Tier Status Matrix

| Capability Area | Public CLI Today | Internal Repo Code (Private) | Planned / Unavailable |
| --- | --- | --- | --- |
| Compilation & execution | Single `.brc` file (`<= 4096` bytes), `fn i32 main()` | `Engine`, `Program`, `Instance`, step quanta (`1..4096`), anchored project loader | Public multi-file `--project` CLI and policy/grant files |
| Guest input & output | None (zero-arg `main()`, `return_i32` only) | `1 MiB` `Snapshot` input adoption & `output::emit` staging in tests | Public CLI `--input`, `output_b64`, binary/text sinks |
| Guest memory & bytes | Fixed arrays, structs, byte literals, scalar/byte slices | Owned guest `Buffer` (`bytes::empty`, `bytes::copy`) & `Result<Buffer, u8>` joins | Public guest `Buffer` admission & text allocation |
| Host calls & policy | Denied by default; no host calls reachable | TLV codec (`host-wire`), request/reply coordinator, policy JSON parsers | Live VM host-dispatch bridge & capability grant enforcement |
| OS isolation | **None** (`--isolated` fails with `unavailable`, exit `4`) | Design & boundary docs (`W01..W06`) | Windows AppContainer + Job object worker & broker (`restricted: true`) |
| C embedding ABI | **None** (`embed: false`) | `bc_get_abi_info_v2` bootstrap + 64-slot handle table tests | Full Engine/Program/Instance C lifecycle exports (`E01..E04`) |

## Why Private Repo Components Are Not Public CLI Features

You may see references in engineering notes to `Engine`, `Instance`, `step()`, `Buffer`, `Snapshot`, `output::emit`, or `bc_get_abi_info_v2`. Those components are developed and regression-tested inside internal modules, but they are intentionally **gated off** from the public CLI until full policy binding, memory accounting, work-bounded cleanup, and security-boundary tests are complete.

In particular:

- **No silent unrestricted fallback**: Passing `--isolated` today always rejects with exit code `4` (`unavailable`) rather than silently running code without isolation.
- **No ambient host authority**: Public `.brc` code cannot touch files, environment variables, clocks, sockets, or C functions.
- **Fuel is not an OS sandbox**: Do not treat `--fuel` as a substitute for `--isolated` worker containment or OS deadlines.

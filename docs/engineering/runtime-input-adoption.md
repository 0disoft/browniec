# Private Windows input adoption into a Fairy Snapshot

Integrated into the checkout from the verified `build/parallel-input-adoption` mirror.
All 13 executed inputs matched checkout bytes at integration; native results are
reused explicitly rather than described as a second execution.
This is an owning-copy adoption API, not zero-copy native allocation adoption.
The ordinary CLI, Engine/Instance association and public ABI are not changed.

`native/runtime-input-adoption/adoption.fy` exposes:

- `handle(handle: usize, limit, charge, ref mut fuel)` duplicates an explicit
  synchronous host disk/byte-pipe handle through the existing Windows reader.
- `path_utf16le(path: ref u8[], limit, charge, ref mut fuel)` takes exact UTF-16LE
  bytes for an absolute drive path, without a terminator. This representation
  avoids unsupported `u16[]` in the pinned compiler. Odd lengths, embedded NUL,
  relative paths and paths over the reader ceiling are rejected. The shim copies
  the path into an aligned `wchar_t` array before calling the existing reader.

Both return `Result<runtime_input::Snapshot, Failure>`. Failure contains `kind`
(`Limit`, `Fuel`, `Allocation`, `Native`) plus the original reader status and
Windows error. Those two codes are zero for Fairy admission/copy errors. The
caller supplies a trusted explicit charge; no guest instruction price is added.
Limit above 1MiB or charge above available Fuel rejects before opening/reading.

The reader initially owns a bounded native staging allocation. A private Fairy
`Native` resource closes that owner on every normal return, including allocation
failure. A temporary immutable byte slice borrows that resource only for the
call to the existing public `runtime_input::snapshot`. That function allocates
the actual pinned SDK `bytes::Buffer`, copies exact bytes and then publishes its
real owning Snapshot and debits Fuel. No C code constructs, copies metadata for,
or guesses the layout of Snapshot, Buffer, Result or a Fairy slice. No source
change to `src/runtime_input.fy` is necessary. Its returned Snapshot remains
valid after native staging, original handles and files are destroyed.

Payload adoption copies `length` bytes once beyond the OS read. Native staging
holds up to `limit` bytes plus its header, and coexists with the SDK allocation
during that copy; peak storage is therefore not just the final Snapshot size.
Empty snapshots require no SDK payload allocation. Path transport adds a
bounded aligned path copy and the existing reader's terminated path copy.
Full Engine reservations/accounting and a charge formula covering this work
remain integration obligations.

No result is published until the whole read, internal handle close and complete
Fairy copy succeed. On failure, existing Snapshots and caller Fuel are unchanged.
This does **not** undo external effects: the reader's duplicate shares disk cursor
or pipe consumption with the original handle. A copy OOM occurs after all input
was consumed, and an over-limit pipe consumes its one-byte EOF/overflow probe.
There is no seek-back, automatic retry or replay. Synchronous reads/EOF probes
may block indefinitely. Caller pointer/handle lifetime and serialized access,
trusted host path authority and all existing unsupported handle-kind rules still
apply. This adds no filesystem containment, deadlines or in-flight cancellation.

## Reviewed transport and verification

`bridge.c` forwards only primitive pointer/integer extern-C arguments to the
[existing reader](runtime-input-reader.md). Snapshot construction, ownership and
Fuel remain in Fairy. All five actual emitted declarations, the emitted C hash,
three Fairy source inputs, compiler identity and five exact runtime Git objects
are frozen in `native/runtime-input-adoption/transport.json`. A mismatch fails
before native compilation. `--emit-only` writes a candidate under ignored build
output for deliberate review; it does not overwrite the reviewed contract.

Run from the checkout:

```powershell
python tools/verify-runtime-input-adoption.py --fairyc-repository <absolute-fairyc-repository>
```

The verifier copies only the three required Fairy modules into an isolated
project, checks the pinned compiler/SDK and emits C once. It uses `git show` for
the pinned runtime, without modifying/building fairyc. Both `/Od` and `/O2` run
actual Windows images with empty tool PATH and default PE stacks (1MiB reserve,
4KiB commit); CL, _CL_ and LINK must be absent, including empty values.

Each profile runs a normal reader image without `BC_RIR_TEST` symbols and a
separate explicit native allocator seam image. SDK allocation observation is
explicit verifier-only runtime instrumentation in both images. The seam image
also arms the next SDK malloc return and the native reader allocator separately;
these are injected allocation failures, not whole-process heap exhaustion.

Executed checks cover exact binary patterns containing NUL and non-UTF8 bytes,
empty and exact-1MiB disk/path/pipe inputs, a partial-chunk pipe, zero-limit empty
inputs, over-limit disk and pipe behavior, pre-I/O Fuel/hard-limit denial,
invalid handles and embedded-NUL paths. Snapshots are checked after originals
are closed and files deleted. Repeated failures retain a separate `keep` Snapshot
and unchanged Fuel. Each profile injects 48 Fairy copy failures and 24 native
allocation failures; original handles prove bytes remain after admission/native
OOM and are consumed after copy OOM. Over-limit pipes expose only the unconsumed
suffix. Zero SDK live allocations and stable process handle counts are asserted.
Native staging live counts are measured in the seam image, including immediately
after every adoption return; the normal image has no native allocation counter.

The [recorded evidence](../evidence/runtime-input-adoption-windows-20261107.json)
retains hashes and the full receipt location. Initial local construction failures
remain in separate ignored build receipts; only the named successful run supports
the pass. Unchanged full language/CLI/Engine suites were not rerun. Successful
adoption is not guest execution, an Instance association or a public CLI feature.

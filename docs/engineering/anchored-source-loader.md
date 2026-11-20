# Windows anchored collector to Fairy Snapshot adapter

`src/anchored_source_loader.fy` is shared by the Windows CLI and private Engine
admission. The Windows application build links the collector and bridge via
`fairy.windows.json`. The focused verifier copies the adapter into its own project.

`open_project` resolves the selected manifest to an absolute local drive path.
It opens its parent directory and reads the exact manifest leaf through that
anchor. `load_from` uses the same owner to collect the declared source paths.
The owner closes on every return, including manifest parse and requirement
denials before source collection.

`load(root, names, ends, source_bytes, name_bytes)` accepts an explicit UTF-8 local
root and packed exact member names with exclusive end offsets. It validates all
spans, at most 16 names of at most 240 bytes, and ceilings of 4096 source bytes and
4096 identity bytes before OS access. Relative spelling/reparse/hardlink and
handle-relative containment remain the existing collector's responsibility.
The root is strictly decoded into a bounded UTF-16 array before allocation.

A private owning Fairy resource closes the opaque C owner on every success and
error return. That owner holds the real collector anchor and native Snapshot.
After collection it closes the anchor; scalar copy calls copy each exact name
and source into fixed Fairy scratch arrays. The adapter calls the unchanged
`source_snapshot::builder`, `add` and `freeze`, so existing UTF-8, identity,
duplicate and quota admission owns the resulting immutable Fairy Snapshot.
Failure publishes no partial Fairy Snapshot. Root handles, native Snapshot and
bridge storage are released before return. The result owns its bytes after
native owners and caller buffers are gone. Invalid requests, native failures and
Fairy admission failures have separate results. Native quota failures return
Limit and collection expiry returns Deadline.

The bridge accepts only scalar integers and live pointer/length pairs. It never
reads or writes an emitted Fairy struct/resource/slice layout. Copy checks bounds
before writing and returns SIZE_MAX on failure. Native callers serialize access
and provide valid buffers; these are private trusted-pointer APIs. Collection is
synchronous. The deadline-aware entry points pass an absolute Windows interrupt
time deadline to the collector. See [collection checkpoints](runtime-engine-compile-memory.md#configured-compile-deadlines). Returned bytes are an
owned bounded copy, not a point-in-time filesystem snapshot, including against
preexisting writable mappings. See [project source admission](project-source-loader.md)
for the public CLI and private Engine gates.

Run `python tools/verify-anchored-source-loader.py` on Windows with MSVC/SDK and
the repository's exact pinned compiler/runtime Git objects. Generated projects,
locks, C, binaries, fixtures and receipts stay in ignored `build/anchored-source-loader`.
Development and O2 compile actual emitted Fairy C unchanged and link the actual
collector. Checks cover a real Unicode root, exact ordered names, CRLF/UTF-8/NUL bytes, source changes
after ownership transfer, empty files, 16/17 members, exact/over 4096 bytes,
invalid UTF-8 after a successful preceding file, identity-pool exhaustion,
malformed packed spans, duplicates, traversal, missing files and a real outside
hardlink alias. An already-expired collection returns Deadline and releases all
owners. Explicit bridge/root/native-Snapshot allocation failures exercise
each owning boundary; repeated failures assert stable handle counts and zero
live bridge/collector allocations. C copy/state error tests require unchanged
destinations. Test hooks exist only in separate test objects; the production
bridge's symbols are checked. Both images must use default 1MiB/4KiB stacks,
no CL/_CL_/LINK overrides, and execute with an empty tool PATH. Receipts retain
exact source/compiler/runtime/transport/artifact identities and fixture cleanup.

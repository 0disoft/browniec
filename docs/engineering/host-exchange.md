# Private native host exchange coordinator

This H03/H04 source slice consumes the actual `host_catalog` and `host_wire`
modules at base `845a05623d28e9eea348500debedbe264905c5f9`. The standalone
coordinator is also used by the private scalar execution path below. The public
ABI and public host gate remain pending.

## Verified scalar Program and execution

The private `host_program` dialect admits a single scalar function, with opcode
117 for a catalog import taking one `i32` and returning `Result<i32,u32>`.
The ordinary verifier rejects 117. Before retaining the original image, the
host verifier checks the catalog signature and uses a temporary ADD proxy to
prove control flow and register definitions independently. The proof rejects
unreachable instructions. Each required import needs a declaration and grant
under the supplied Policy. The Program retains the canonical entry and the
SHA-256 binding of its exact immutable catalog.

`create_scalar` rechecks admission, copies the catalog, checks its binding, and
materializes a private eight-byte-per-instruction image. Each execution owns a
2,656-byte header including its coordinator, program counter and 128 scalar
registers. The header is fixed for the lifetime of the resource. The standalone
coordinator keeps its 80-byte header. Its mutation entry points cannot publish,
commit or remove a scalar VM request. The caller supplies a unique nonzero run
ID, monotonic time and sampled cancellation.

A step either dispatches one instruction or installs one committed reply. The
request PC remains parked while waiting. The 14-byte request costs 15 Fuel
including dispatch, and a 12-byte reply costs 12 Fuel at acceptance. Installing
the reply and polling while waiting cost zero Fuel. Wrong run or request IDs,
malformed replies and duplicate replies preserve the outstanding transaction.
Success stores one signed `i32` in the verified destination and advances the
PC. A kind-1 reply preserves the full `u32` as a terminal host error. Fatal
replies, cancellation, deadlines and quota/Fuel exhaustion use the coordinator's
first-cause rules. Reply installation and retirement use the existing snapshot
handoff. This path has no adapter callback.

Engine handle and quota integration, general typed destinations with guest
error arms, compact scalar replies, OS deadline sampling and public delivery
remain open. The scalar price is local to this path. The guest-facing general
host contract remains incomplete.

### Scalar verification

Program binding at `a43cff8` passed two Windows development groups. The scalar
VM composition passed five focused native groups in each Windows profile with
Fairy C preview.2 (`801c5d8caa64d19aab8925763d6bf07f65f26418`), default stacks,
and 375 hashed inputs. The selected groups cover exact catalog and grant binding,
invalid operands, the standalone fake adapter, interleaved scalar execution,
and stable host error/deadline outcomes. The `41 -> 42` path spends 29 Fuel in
total across literal, publication, reply and return. Wrong identities, malformed
replies and a second waiting poll spend zero. Root `fairyc check --locked`
passed 376 source files and 4,156 MIR functions.

| Windows profile | Native report SHA-256 |
| --- | --- |
| development | `ddbdd6722b70062b5aa745948cae4a04fda3db2777bd507fdbc4f9b11ed118ce` |
| release | `f1ba750f948689c15dd483496983cb730b4758b839539d5a82db4f060e383f04` |

The run used `fairyc test --native --capture-output --json --locked` with the
four exact `tests::m2::host_program` identities and
`tests::m2::host_exchange::fake_adapter_decodes_actual_request_and_encodes_reply_42`.
The release profile adds `--release`. The focused runner kept commands, hashes
and reports under `build/host-scalar`. Scalar allocator fault injection, public CLI,
Linux and the full native suite remain outside this verification.

## Standalone coordinator ownership and API

`create(Catalog, grants, Limits, run, fuel, deadline) -> Result<Exchange, Error>`
moves the admitted Catalog into a resource with private fields. It retains the
canonical SHA-256 binding, independent decoded catalog, explicit per-import host
allowlist, fixed private state header and owned request/reply Buffers. Metadata
does not grant access: callers must explicitly allow each import. This allowlist
does not replace future policy/declaration/capability grant validation. The native
owner must supply a unique nonzero run ID, monotonic time and trusted charges.

`begin(exchange, import_id, wire_payload, snapshot_fuel, adapter_cost, now, cancel)`
validates the exact catalog signature and whole envelope before snapshot/publication.
IDs start at one, increase only on successful publication, and terminate before
wrap. One request may wait at a time. Detached observations and binding words
are copies; they cannot forge or rewind the private authority.

`request_bytes` returns an immutable view only while Waiting; `request_fields`
decodes checked offsets against that same owned storage. Polling, invalid replies
and preparation OOM preserve the snapshot. Valid commit/cancellation retire it.
The type checker rejects replacement while an externally borrowed view is live.

`reply(exchange, run, request, kind, payload, snapshot_fuel, now, cancel)` applies
the first-cause checkpoint before identity, shape and signature checks. Success,
u32 source error and empty fatal use the actual typed decoder. Malformed replies,
wrong IDs, wrong runs and allocation failures retain pending bytes/Fuel/counters.
Valid success/error snapshots consume the request once and enter Install; duplicate
or late submissions cannot recopy or recharge. Fatal consumes the request and
selects HostFailure. `take_reply` moves the single owned TLV snapshot into Output
and returns to Ready, with no payload recopy or extra charge. Typed VM destination
installation is still required by the future integrating owner.

`output_field`, `output_kind`, `output_run`, `output_request`, `output_bytes`
inspect the private Output resource. Byte views retain Output, which can outlive
the input array, cancelled coordinator and coordinator destruction.

Phase codes: Ready=0, Waiting=1, Install=2, Terminal=3. Cause codes: None=0,
Cancelled=1, Deadline=2, HostFailure=3, Quota=4, Fuel=5, Identity=6. Native enum
comparisons are unavailable in the pinned compiler, so observations use u8 codes.
`poll` is a checkpoint, not a VM step. Cancel wins over a simultaneously sampled
deadline; any previously selected cause wins over both. Terminal state, timestamp,
Fuel and counters freeze. External effects are unknown after a published request
when terminated. Cancellation never asserts rollback or exactly-once execution.
There are no adapter callbacks, source replay, automatic resubmission or retries.

## Bounds and preparation

Limits separately bound per-message request/reply bytes, cumulative bytes, call
count, per-call adapter cost and cumulative adapter cost. Complete envelopes,
including all headers, are charged; each message is at most 1 MiB. Subtraction
checks precede addition. Policy/Fuel exhaustion is terminal and retains the first
cause; invalid message/type/identity is an API rejection. Preparation first reserves
the complete Buffer; failed preparation drops unpublished storage and preserves
all observations. This synchronous transaction charges the owner-supplied cost
once at publication. No existing Fuel schedule is changed or claimed connected.

Copies and catalog operations are bounded by envelope/schema limits, but have no
resumable chunks or mid-copy deadline checks. This does not establish R03 per-step
work-unit, allocator latency or quantum invariance guarantees. All nonfatal replies,
including scalar and empty-byte headers, currently use owned TLV Buffers; the
accepted compact-inline optimization is not implemented. Full Engine/Instance
memory accounting, typed owner reservations and prepaid cleanup remain separate.

## Pinned compiler ownership seam

The pinned compiler cannot mutate/project nested owning resource fields. The
coordinator therefore privately owns an 80-byte fixed header and stores scalar
state there. Its header pointer is captured from its own Buffer and never escapes;
that Buffer is never grown or replaced. No source-facing state struct is authority.

`replace_buffer` moves exactly one native Buffer owner record through exclusive
whole-owner byte views and zeroes the source record. Nonallocating SDK `reserve(0)`
companion calls then validate the destination, emptied source and removed owner
before whole-resource moves/cleanup. No memcpy/memset foreign symbols are added. For this Windows x64 compiler,
Buffer is four pointer-width cells, **32 bytes**, with data/capacity/alignment/length
at 0/8/16/24; Exchange backing/header/header_data/catalog start at 0/32/64/72, and Exchange
is 7,632 bytes. One backing alternates request and reply ownership. The verifier emits
actual C from the pinned compiler, asserts these sizes/offsets at compile time and
runtime, and executes the actual maximum-ID transition through a private C test
hook. The hook is generated under build only and is absent from production APIs.
The all-zero source is the SDK empty Buffer representation, accepted by its normal
cleanup. Instrumented allocator runs require zero live allocations at process exit,
including repeated handoff, cancellation and empty-source cleanup.

The earlier unvalidated raw-loop implementation passed development but reproduced
optimized native access violation/heap corruption (`C0000005` / `C0000374`), also
seen by main's independent composed grant/exchange check. The request/reply-42 and
1 MiB lifetime tests are the regressions. The corrected path uses one backing and
explicit SDK companion validation boundaries before ownership moves/drops; it does
not change compiler flags or stacks. A separate negative control removes only those three SDK validation calls and
reproduces the release heap corruption in the same request/reply-42 test. This
isolates an optimized raw-metadata visibility/ownership problem; it is not evidence of a general Catalog move defect.
The previously attempted libc memcpy/memset alternative was rejected by pinned
native linkage and is absent from the final production source.

## Verification and delivery

Run `python tools/verify-host-exchange.py --profile all`. Only ignored build output
and its mirror locks change. Each run retains byte-identical dependency sources,
tests, commands, native reports, pinned compiler identity, emitted C, executable
layout assertions, exact pinned runtime Git objects and SHA-256 input/artifact
hashes. `build/host-exchange/latest.json` identifies the latest complete receipt.
Normal native runs use default stacks and no overrides. `--native-from` can reuse
current-session normal reports only after compiler/dependency/test/report hash
checks; it reruns all layout, negative-control and allocator seams. Two separately labelled
explicit `cl /FI` allocator seam cases reuse the existing heap probe (no
CL/_CL_/LINK environment or /STACK overrides): real request
and reply allocation failures, explicit same-byte resubmission, no hidden retry,
unchanged pending/Fuel/counters and zero live allocations. Negative compiler cases
reject private-field mutation, private state publication and live-view replacement.

The bounded suite covers real fake-adapter request/reply 42, catalog/request/output
lifetimes, duplicate/late/wrong-run/ID, malformed/truncated/reserved/type/kind replies,
u32 error/fatal, cancellation/deadline ordering, frozen terminal observation,
quotas/Fuel/adapter totals and actual 1 MiB envelopes. It does not execute a VM host
opcode, Engine lifecycle, public CLI, DLL, broker, worker isolation or network host.

The worker changes only the named new files in an ignored archive mirror. Its
patch excludes mirror locks, generated hooks, build artifacts and all existing
source files. Root integration, root lock refresh and public promotion belong to
main. The design ZIP was read as reference only: SHA-256
`9786d2d2a0d0cd9048a47d17f6fd5c4574cdbcaeec00d17570602fa541b7dc5e`,
especially docs 04/08/16/17; no package instructions were executed.

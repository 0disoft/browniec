# Windows x64 scalar embedding preview

Build the DLL and its native C host with `python -B tools/build-embed-preview.py`.
The build uses the pinned Fairy C compiler, its runtime sources, and the Windows
x64 MSVC/SDK. Each selected profile writes `brownie-preview.dll`, its import
library, and `preview-host.exe` under a fresh `build/embed-preview-*` directory.
The C API is declared in [`brownie_preview.h`](../../include/brownie_preview.h)
and uses `BC_PREVIEW_REVISION`. The existing revision-2 bootstrap build remains
separate.

Create an Engine with `bc_preview_engine_create`, then compile one UTF-8 source
with `bc_preview_compile`. It must declare `module main;` and a public
`fn i32 main()` entry. The source is limited to 4096 bytes and copied during
compile. The native Engine owns the verified Program. Preview Instances take
no guest input and receive no host or output capabilities. Run trusted rules
in-process on the Engine's creating thread.

Call `bc_preview_instance_create` more than once with that Program. Each
Instance owns its own Fuel balance and continuation. Set `event.struct_size`
to `sizeof(event)` before calling `bc_preview_step`. A quantum of 1 through
4096 advances the Engine's saved dispatcher and returns a yield or terminal
event. Scheduler work and guest Fuel have distinct units. Every successful
step reports cumulative guest Fuel consumed. Subsequent steps on a terminal
Instance return the same event. `bc_preview_cancel` requests cancellation of
one Instance. Continue stepping it through any remaining cleanup. A terminal
result already committed by the Engine stays intact.

Fuel may be set up to `BC_PREVIEW_MAX_FUEL` (16,000,000). When the balance
cannot cover preparation, creation returns `BC_RESOURCE_LIMIT`. Exhaustion
after creation appears in a terminal trap event.

Release the Program handle once no more Instances need to be created. Live
Instances retain their pins and can continue. Destroy each Instance before
destroying the Engine. The Engine rejects destruction while it has live public
children. Handles are generation-checked integers in the shared 65,536-slot
process registry. The preview caps each Engine at eight Programs and sixteen Instances.
The creating OS thread owns the Engine and its children for life. Separate
owner threads can compile and step independent Engines concurrently. The
registry guard protects handle and admission updates, and compilation and VM
execution run outside the guard. Calls on a foreign Engine return
`BC_WRONG_THREAD`. Each preview handle and event output remains unchanged on
API failure.

### Process ownership

The first lifecycle call elects one preview DLL image as the process owner.
Other copies with the same private dispatch protocol route their lifecycle
calls to that image even if loaded from different paths. The owner interprets
all native objects, owns their registry and thread identities, and stays loaded
until process exit. A caller may release its DLL reference and later use the
same live handle through another compatible copy on the creating thread.
Destroy each object when it is no longer needed.

The election uses a session-local mutex named for the process ID and creation
time. Dispatch pointers are resolved from modules in the current process,
with a module reference held during each lookup. A client caches the elected
dispatch table after resolution. A discovered owner with an incompatible
protocol causes `BC_ABI_MISMATCH`. Failure to resolve an owner returns a status
before accessing any runtime state. Revision-2 creation calls clear the handle
output on resolution failure. The ABI query remains local to each DLL. Call
the preview outside `DllMain` and other loader callbacks.

Windows x64 `/Od` and `/O2` test simultaneous first calls through two DLL
copies, 75 live handles across two shared pages, cross-DLL creation through
destruction, a client reload, stale-handle rejection, and incompatible-owner
refusal. The standalone registry build provides the full-capacity evidence.
Local receipt: `build/embed-preview-6cj2auor/receipt.json`.

The native test host compiles one Program, overwrites its original source
buffer, and advances two Instances with quanta 1 and 64 to the same result and
Fuel consumption. A third Instance is cancelled after its first step. The host
also verifies exact terminal observation, exhausted Fuel, Program pins,
wrong-thread access, cross-Engine handles, and stale generations.
The concurrency check starts four owner threads together. Each compiles,
steps, and destroys its own Engine without retrying calls.

On Windows x64, the development and `/O2` hosts both returned 77 and consumed
2,753,628 Fuel with either quantum. All four owner threads also completed in
both profiles. The previous DLL rejected creation in the concurrency check.
Both builds used the default MSVC stacks.

## Revision-2 Engine lifecycle

The same DLL exports `bc_get_abi_info_v2`, `bc_engine_create`, and
`bc_engine_destroy` from [the revision-2 header](../../include/brownie.h).
The query validates revision and capacity before touching its output.
`bc_engine_create` takes an explicit `brownie.policy/0.3` JSON document of at
most 65,536 bytes. The Fairy policy parser validates it and transfers the
parsed policy into the real Engine. The caller may reuse the input buffer
when the call returns. Set the diagnostic's `struct_size` to
`sizeof(bc_diagnostic)`. Creation zeros the output handle at entry and
publishes a handle only after registration. Malformed policies return
`BC_POLICY_ERROR`. The size ceiling and an insufficient Engine control budget
return `BC_RESOURCE_LIMIT`.

Creation diagnostics have no source index or byte span. A successful
diagnostic has code zero and an empty message. A revision mismatch leaves
the diagnostic untouched. An invalid diagnostic size leaves its fields
untouched. Destroy a revision-2 Engine on its creating thread with
`bc_engine_destroy`. Scalar preview calls reject these Engine handles.

## Revision-2 control memory

The Engine charges the native wrapper's additional fields with its initial
control reservation. It also reserves the requested bytes for each live
Program wrapper and its entry names, each Instance wrapper, and any
allocated capability JSON against both `engine.control_bytes` and
`engine.memory_bytes`. Allocation and publication failures return the
provisional charge. Program release and Instance destruction return the
native charge when they free the wrapper. A Program pinned by an Instance
continues to consume its separate retained-code charge until its last pin
is released.

These charges track requested bytes. Windows heap metadata and the
process-wide handle registry remain outside the Engine's ledger.

Windows /Od and /O2 measured an initial 210,672-byte control reservation for
the policy fixture. Each default-entry Program wrapper consumes 80 bytes,
each Instance wrapper 448 bytes, and the empty allocated capability JSON
2 bytes. Both profiles verify exact admission, one-byte-short refusal, and
reuse of the budget after failed preparation and destruction.
Local receipt: `build/embed-preview-sizi64hq/receipt.json`.

## Revision-2 scalar Programs

`bc_compile` accepts 1 to 16 `bc_source` rows and up to 4096 total source bytes,
subject to the Engine's `compile.modules` and `compile.source_bytes` limits.
Each canonical module name must match its source declaration. Imports resolve
within the supplied set. The default entry is public `main::main`.
The Windows extension `bc_preview_compile_entry` accepts an explicit public
module/function pair and copies the two names into Program-owned storage.
Both compile calls accept an i32 return with either no parameters or one
`ref u8[]` parameter. Provide up to 16,384 bytes of
`brownie.catalog/1` JSON to resolve host imports under the Engine policy.
The caller can reuse the source and catalog storage when compilation returns.
The Engine applies its configured deadline, working-memory limit and Program
retention limits.

Initialize the diagnostic's exact `struct_size`. The call zeros the output
handle on entry and publishes a Program only after compilation and handle
registration succeed. Diagnostics report the API result code and preserve the
original source span when available. An absent span uses `UINT32_MAX` and
byte offsets `0/0`. Catalog syntax and policy failures return `BC_POLICY_ERROR`.

`bc_program_release` accepts the originating revision-2 Engine and a live
Program handle on its owner thread. Successful release invalidates the handle.
An Engine with a live Program returns `BC_BUSY` on destruction. Preview and
revision-2 Program handles use separate API entry points.

`bc_program_entry_info` queries the compiled entry on the same Engine and
thread. Pass the exact module and function names selected at compilation.
Initialize both output structure sizes. The query returns ABI revision 2,
the retained signature's input kind (`BC_INPUT_NONE` or `BC_INPUT_BYTES`),
and a Program-owned JSON capability array. The array contains each distinct capability referenced by the verified image,
including `brownie.output.emit` when applicable.
The slice is read-only and expires at Program release. Failed queries leave
entry info storage unchanged.

The native C host passed both Windows `/Od` and `/O2` builds. It verifies
4096-byte admission and 4097-byte rejection, exact source diagnostics,
cross-Engine and cross-revision rejection, and stale Program handles.
An Engine configured for 42 source bytes accepts exactly 42 and rejects 43.
The two-module fixture returns 77 after source storage is overwritten and the
Program handle is released. Both profiles verify original byte ranges in the
second source, duplicate and mismatched names, a policy limit of one module,
and the shared 4096-byte source ceiling. Local receipt:
`build/embed-preview-ow92mzge/receipt.json`.
Both builds also verify the entry info fields, failure output preservation,
and rejection across threads, Engines, ABI revisions and stale handles.

The named-entry fixtures pass in both Windows profiles. A shared-byte rule
returns 77 after the caller overwrites both name buffers and releases the
Program. A separate named rule calls a host import through another module and
returns 77 and 78 in two Instances. Private entry selection and mismatched
entry metadata and run configurations are rejected. Local receipt:
`build/embed-preview-0vhxmny3/receipt.json`.

## Revision-2 scalar Instance preparation

`bc_instance_create` accepts guest input and an explicit
`brownie.run/0.3` configuration. The entry must match the compiled Program. A Program
with host requests or a reachable emit requires those capabilities in both
`requires` and `grants`, and the Engine policy must allow them. With an empty
catalog, the lists contain just the emit capability when required, or are empty
for a pure Program. The Engine validates the configuration against
its own policy and reserves the prepared continuation under the requested
memory and Fuel limits. It records the monotonic deadline before preparation.
A zero-argument entry requires empty input. A shared-byte entry copies the
input into an immutable Instance-owned snapshot. Empty input is a valid
snapshot. The Engine checks `limits.input_bytes` and charges snapshot storage
alongside the continuation against the memory limit. The caller can reuse
the input and configuration buffers once the call returns.

Creation zeros the output handle and issues a handle only after successful
preparation and registration. Multiple Instances can pin one Program. The
caller can release the Program handle while Instances still own their pins.
`bc_instance_destroy` discards the continuation and releases its pin on the
Engine's owner thread.

The Windows preview extension `bc_preview_instance_create_cancellable` accepts
a borrowed manual-reset event that another thread can signal. With an event,
the owner thread checks for cancellation after authenticating the Program and
again before publishing a successfully prepared Instance. A signaled event
returns `BC_RUN_TERMINATED` with a zero output handle. The final check releases
the provisional continuation, input and Program pin through ordinary Instance
destruction. Keep the event open until the call returns and leave it signaled
once cancellation is requested. The event is scoped to preparation. Use
`bc_cancel` on a published Instance. The synchronous Fairy constructor runs to
its next native boundary before the cancellation is observed.
Both Windows profiles signaled the event from a second thread at the first
input read, verified that creation returned no handle, and retried the same
Program to return 77. Local receipt: `build/embed-preview-nee8smeg/receipt.json`.

Both Windows builds verified rejected input and run configurations, setup
Fuel exhaustion, two Program pins, and foreign-thread and stale-handle
rejection during Instance destruction.

Both builds also verified that two Instances sharing a byte-input Program
retain different snapshots of the same caller buffer. After the buffer was
overwritten and the Program handle released, they returned 42 and 77. An
empty snapshot returned -1. A three-byte ceiling admitted three bytes and
refused four, and the peak accounted bytes increased by exactly three over
the empty snapshot.

## Revision-2 scalar stepping

`bc_step` advances the saved dispatcher with a quantum of 1 through 4096.
Pass an event with the exact `struct_size`. Each event reports cumulative
Fuel use, the peak accounted bytes of the prepared continuation and its
input, and elapsed microseconds from run admission. The Engine
reports yield, return, guest trap, and execution failure. Cancellation and
deadline expiry are failed events with diagnostic codes 33 and 30.
When a trap has a source span, its diagnostic identifies the input source row
and reports byte offsets relative to that row. This includes a trap in an
imported function, regardless of the order of the source rows passed to
`bc_compile`. A diagnostic without a source span uses `UINT32_MAX` and
zero byte offsets.

`bc_cancel` uses the Engine's existing first-cause rule. Keep stepping if
cleanup yields. The ABI retains each terminal event and its metrics for
subsequent observation, including after a later cancel call. General ABI
resource accounting remains open.

The native C host passed both Windows `/Od` and `/O2` builds. Two Instances
sharing a released Program handle returned 77 at quanta 1 and 64 and reported
the same cumulative Fuel and peak accounted bytes. Additional Instances verified
independent cancellation and that an already expired deadline wins over cancel.
Repeated successful and cancelled terminal events matched byte for byte.
An imported divide-by-zero trap reported byte range `[55, 56)` in both
source orders, with source index 0 or 1 matching its input row. Repeated
terminal events preserved the diagnostic and metrics. Local receipt:
`build/embed-preview-_sldwa4t/receipt.json`.

`limits.call_frames` includes the entry frame. The saved dispatcher checks
the Instance's limit before starting a CALL. A limit of one traps when
`main` calls a helper, while a limit of two lets the same Program return 77.
Both profiles verified this boundary and the source location of the trap.

Configured Instances in the saved array/record VM honor `limits.owner_entries`
for the shared array and record owner table. `limits.descriptor_entries` bounds
the combined number of live input views and array slice tickets. The fixed
owner and array ticket tables each have sixteen slots. Admission disables
slots beyond each configured ceiling with the zero generation used for
retired slots. Input views can occupy up to sixteen sites in each of 31
frames, so the combined limit is capped at 512. The fixed storage and input
grant metadata are charged to memory at preparation.

The dispatcher checks the combined number of live descriptors before opening
an array slice, creating an input view, or publishing a child frame. A formal
grant stores the provenance of its matching input view. Closing a site or
retiring its frame returns its descriptor entry. An input return retires the
child's entries before installing the result in the parent. Exhaustion traps
with code 13 at the operation requesting an entry. Each Instance keeps its own
quota. Catalog-backed execution has a separate representation.

The C host tests the existing one-slot traps and two-slot successes for arrays
and owners. It also runs one Program holding an array ticket and an input view
across three calls that return an input range. Ceilings of one, two, and three
trap at array opening, CALL entry, and creation of the input range respectively.
Four entries let all three calls finish and return 77.

The saved array/record VM reserves a shared payload arena of
`min(limits.object_bytes, 65536)` bytes for Programs with aggregate layouts.
Programs without aggregate layouts reserve zero payload bytes. The same
capacity drives memory admission, setup Fuel, and the arena's allocation
checks. Alignment padding counts toward the arena limit.

The native host creates three Instances from one Program with two live
four-byte arrays. An eight-byte ceiling allows the Program to return 77.
Seven bytes traps with code 13 at the second allocation. The reported peaks
differ by one byte. With the default run configuration, the Program still
returns 77, with 65,528 additional bytes of peak accounting and 65,528
additional setup Fuel compared with the eight-byte run.

## Revision-2 guest output

`BC_DONE` exposes the sealed bytes in a read-only `payload` slice. The
Instance retains the buffer and its memory charge until destruction. Empty
output is represented as NULL/0. Yields, traps, cancellation and deadline
expiry have empty payloads. Staging and sealing use `limits.output_bytes`
and the saved Engine dispatcher. Repeated observations return the same
slice and terminal metrics.

The Windows preview extension `bc_preview_copy_output` copies a successful
revision-2 Instance's sealed output into caller storage. Query the exact size
with a NULL destination and zero capacity. A short destination returns
`BC_RESOURCE_LIMIT` with the required size and writes no bytes. Pending
Instances return `BC_BUSY` and failed or trapped Instances return
`BC_RUN_TERMINATED`. Both leave the caller's destination and size untouched.
The call uses the same owner-thread admission as step. It does no guest work,
does not change the stored terminal event and allocates no SDK memory. The
caller owns the copy after destroying the Instance and Engine.
Both Windows profiles verified independent binary storage after teardown,
one-byte-short refusal without writes, and rejection of pending, failed,
foreign-thread and stale handles. Local receipt:
`build/embed-preview-yl5xttwz/receipt.json`.

Both Windows builds verified the two-byte payload `41 00` from zero-argument
and byte-input entries. The latter keeps its output view valid across Program
release, peer Instance destruction, a late cancel, and repeated observation.
The C host also verified rejection without a run grant or Engine permission,
and empty payloads on cancellation and a guest trap after emission.

## Engine admission for catalog-backed embedding

The Engine can retain a catalog-backed Program from a source set with a public
i32 entry before receiving a run configuration. It verifies
the lowered image against the exact catalog, retains its digest, and checks all
referenced capabilities against the Engine policy. Preparing an Instance still
requires a matching entry and explicit declarations and grants. The catalog
alone provides no grant.

The Windows Engine verifier passed development and /O2 with default stacks and
zero live SDK allocations. It exercised policy denial, private entry rejection,
missing run declaration rejection and a typed i32 reply that returned 77.

## Revision-2 host requests and replies

### Catalog-backed trap locations

Catalog-backed Programs retain the source lengths in caller order and reuse
the verified instruction offsets. On a guest trap, the Engine resolves the
faulting instruction before it releases execution storage. The terminal
event keeps the source row and half-open byte range even after Program
release. Cancellation and fatal host replies carry no guest source location.
The Windows x64 map occupies 128 bytes per retained Program slot, with no
separate allocation and at most 16 source lengths inspected per trap.

The native C host passed /Od and /O2. In both source orders, replying with
i32 maximum triggered an overflow at the imported function's addition
operator. The C host cleared the original source buffers before stepping,
released the Program before the reply, and observed an identical terminal
event on the next step. Local receipt: `build/embed-preview-08jv26bx/receipt.json`.


In the catalog-backed preview, `bc_step` returns `BC_HOST_REQUEST` once per
request with the catalog import ID, a nonzero reply ID, and the read-only
[typed TLV](host-wire.md) payload. Copy the payload before stepping, replying,
cancelling, or destroying that Instance. Further steps while waiting return
`BC_WAIT` with the same reply ID and an empty payload. Reply IDs are unique
across the DLL's Engines and Instances during its lifetime.

`bc_host_reply` accepts a full TLV success or Result error, or an empty fatal
reply. The caller may reuse the buffer on return. The synchronous C call checks
the live request and samples the deadline between receipt chunks of at most
4096 bytes. The saved dispatcher installs the complete reply under subsequent
step budgets. A malformed or mismatched reply leaves the request available
for a valid response while the run is live. If the run has terminated,
`bc_step` reports its terminal event. An accepted fatal reply returns `BC_OK`
and produces a failed event on the next step. When the guest evaluates a host
call as its success value and the host sends a Result error, installation
terminates with BC_FAILED and diagnostic code 20. A guest Result error arm
can handle the same reply and continue execution.

The Windows /Od and /O2 C hosts verified this with the maximum u32 error.
The failed Instance exposed no output and charged the 12-byte TLV once.
Its terminal event was identical after a late cancel. The explicit guest
error arm still returned 17. Local receipt: build/embed-preview-354b5coz/receipt.json.

The Windows C host passed /Od and /O2 with default stacks. The entry calls a
function in a second module, which sends the host request. Two Instances pinned
one Program and returned 77 and 78 at quanta 1 and 64 with equal Fuel and peak
accounted bytes. Tests cover the second module's name-mismatch span, capability
metadata, missing grants, cross-Instance and duplicate replies, malformed TLV,
overwriting caller buffers, cancellation, fatal reply, and stale handles.
Local receipt: `build/embed-preview-rlagj8hv/receipt.json`.

Both profiles also received an 8193-byte Buffer reply in three receipt chunks.
After the caller overwrote its reply buffer, the next guest host request
contained every original byte. One Instance cancelled after a 4096-unit
installation step without publishing a follow-up request or output. The
explicit Result error arm returned 17. The fixture saves the host reply in a
`Result<brownie::bytes::Buffer,u32>` local, with a comment between components
of the qualified name. The indexed lexer preserves its source span and the
host annotation parser accepts the same qualified Buffer type as the
single-source route.

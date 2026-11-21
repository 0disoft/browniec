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
children. Handles are generation-checked integers in the shared 64-slot
registry. The preview caps each Engine at eight Programs and sixteen Instances.
The creating OS thread owns the Engine and its children for life. Separate
owner threads can compile and step independent Engines concurrently. The
registry guard protects handle and admission updates, and compilation and VM
execution run outside the guard. Calls on a foreign Engine return
`BC_WRONG_THREAD`. Retire all handles before unloading the DLL. Each handle
and event output remains unchanged on API failure.

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

## Revision-2 scalar Programs

`bc_compile` accepts one `bc_source` whose module slice is `main` and whose
source declares `module main;` with a public `fn i32 main()`. Pass an empty
catalog slice. The source is copied during the call and may be reused when
it returns. The existing Engine applies its configured compile deadline,
working-memory limit and Program retention limits. The source ceiling is the
smaller of 4096 bytes and the Engine's `compile.source_bytes` limit. Wiring
the remaining compile policy fields into source admission is still pending.

Initialize the diagnostic's exact `struct_size`. The call zeros the output
handle on entry and publishes a Program only after compilation and handle
registration succeed. Diagnostics report the API result code and preserve the
original source span when available. An absent span uses `UINT32_MAX` and
byte offsets `0/0`. A nonempty catalog returns `BC_POLICY_ERROR`.

`bc_program_release` accepts the originating revision-2 Engine and a live
Program handle on its owner thread. Successful release invalidates the handle.
An Engine with a live Program returns `BC_BUSY` on destruction. Preview and
revision-2 Program handles use separate API entry points.

`bc_program_entry_info` queries `main::main` on the same Engine and thread.
Initialize both output structure sizes. The query returns ABI revision 2,
`BC_INPUT_NONE`, and the Program-owned, two-byte JSON capability array `[]`.
The slice is read-only and expires at Program release. Failed queries leave
entry info storage unchanged.

The native C host passed both Windows `/Od` and `/O2` builds. It verifies
4096-byte admission and 4097-byte rejection, exact source diagnostics,
cross-Engine and cross-revision rejection, and stale Program handles.
An Engine configured for 42 source bytes accepts exactly 42 and rejects 43.
Both builds also verify the entry info fields, failure output preservation,
and rejection across threads, Engines, ABI revisions and stale handles.

## Revision-2 scalar Instance preparation

`bc_instance_create` accepts empty guest input and an explicit
`brownie.run/0.3` configuration. The entry must be `main::main` and `requires`
and `grants` must be empty. The Engine validates the configuration against
its own policy and reserves the prepared continuation under the requested
memory and Fuel limits. It records the monotonic deadline before preparation.
The caller can reuse the configuration buffer when the call returns.

Creation zeros the output handle and issues a handle only after successful
preparation and registration. Multiple Instances can pin one Program. The
caller can release the Program handle while Instances still own their pins.
`bc_instance_destroy` discards the continuation and releases its pin on the
Engine's owner thread.

Both Windows builds verified rejected input and run configurations, setup
Fuel exhaustion, two Program pins, and foreign-thread and stale-handle
rejection during Instance destruction.

## Revision-2 scalar stepping

`bc_step` advances the saved dispatcher with a quantum of 1 through 4096.
Pass an event with the exact `struct_size`. Each event reports cumulative
Fuel use, the peak accounted bytes of the prepared continuation, and elapsed
microseconds from run admission. It carries an empty payload. The Engine
reports yield, return, guest trap, and execution failure. Cancellation and
deadline expiry are failed events with diagnostic codes 33 and 30.

`bc_cancel` uses the Engine's existing first-cause rule. Keep stepping if
cleanup yields. The ABI retains each terminal event and its metrics for
subsequent observation, including after a later cancel call. Host exchanges
and the remaining general ABI resource accounting are future work.

The native C host passed both Windows `/Od` and `/O2` builds. Two Instances
sharing a released Program handle returned 77 at quanta 1 and 64 and reported
the same cumulative Fuel and peak accounted bytes. Additional Instances verified
independent cancellation and that an already expired deadline wins over cancel.
Repeated successful and cancelled terminal events matched byte for byte.

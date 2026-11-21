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

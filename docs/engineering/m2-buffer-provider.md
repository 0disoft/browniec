# Native Buffer Provider inconsistency probe

Verified in development and release on Windows by
`python -B tools/verify-m2-buffer-provider.py`. The
[receipt](../evidence/m2-buffer-provider-windows-20261029.json) records inputs,
native runtime Git objects, generated C, native toolchain and both binaries.
No production Fairy source, root lock or Fairy checkout is changed by this slice.

## Instrumentation boundary

The tool checks the pinned compiler checksum/revision/SDK and root locked check.
It copies fifteen production modules byte for byte into an isolated project with
the committed probe manifest/main. Its SDK lock must match the root SDK lock.
`experimental emit-workspace-c --target x86_64-windows-msvc --locked` supplies
unmodified product code and external ABI declarations; it does not emit providers.

The verifier reads five native runtime Git objects at the compiler revision from
the configured local Fairy repository: system heap, Buffer, Windows console,
Windows process arguments and scalar traps. Working-tree runtime files are not
used. The Windows heap alignment override is 16, matching the compiler's target
adapter. Scalar trap template placeholders select exit base 128 and no receipt
transport; any trap/nonzero exit fails the probe. This is a test binary build,
not evidence for shipping the compiler's normal packaged CLI binary.

The test-only native provider copy receives three exact, uniquely matched
insertion anchors. Changed/missing/ambiguous anchors fail verification. Four
one-shot hooks alter only the planned 384-byte replacement; seed allocation is
256 bytes. Metadata shortening stays within the real allocation and preserves
valid destruction. No pointer corruption, invalid allocation size or deliberate
out-of-bounds memory access is used.

| Fault | Injected provider behavior | Product check exercised |
| --- | --- | --- |
| `capacity` | Initialization succeeds but reports capacity 320 for a real 384-byte block | `buffer_storage::prepare` rejects capacity mismatch as Provider before copying |
| `copy` | Append copies the four-byte prefix but reports initialized length 3 | `buffer_storage::prepare` rejects copied length mismatch as Provider |
| `append` | Growth append writes all 253 suffix bytes, then returns invalid-argument status | `buffer_replacement::extend` destroys its private replacement; caller cancels the active Plan |
| `resize` | Resize zeroes through length 257, then reports length 256 | `buffer_replacement::resize_prepared` rejects length mismatch and cancels its active Plan |

The original emitted product C and pristine/composed and injected native runtime
C are retained under the ignored build directory with hashes in the receipt.
MSVC compiles the separate product/runtime units with C11, `/W4 /WX /MT`, `/Od`
or `/O2`; deterministic linking is enabled. Product and fixture copies, source
hashes, generated lock and retained artifacts are rechecked after execution.
The test header reuses the existing FY system-heap allocator counter seam.

## Failure containment and explicit retry

Every scenario first acquires a registered UTF-8 read lease. Replacement must
return State before provider invocation, allocation, Fuel or registry changes.
Explicit abandonment releases that lease but preserves the 2,112-byte Pool
charge. The selected native fault then causes exactly one Provider error.

After rejection the fixture verifies the original `keep` bytes, 256-byte capacity,
live owner token, complete descriptor table and inactive replacement Plan. Used
Instance/Engine accounting returns to 2,432/2,464; observed peaks retain the
2,880/2,912 reservation high-water marks, and all pending fields clear. Pool
admission, retired Ticket generation and Fuel remain unchanged by the failure.

Only an explicit second call retries. It succeeds once, publishes capacity 384,
advances the Buffer owner generation exactly once and leaves the expected data:
the original prefix for capacity/copy, 253 `x` bytes for append, and zero-filled
new bytes for resize. Shutdown returns the registry charge while preserving
the Buffer and unrelated 32 bytes of Engine usage (448/480 remain).

Each profile also runs four controls with all hooks disabled. Control cases
allocate/free exactly two payloads; injected cases allocate/free exactly three.
Thus a hidden retry or missed release fails the exact counter check. Each injected
process must report exactly one native hook hit. All runs require the success
line, zero stderr and zero exit status, with an empty runtime tool PATH.

Development and release each passed four faults and four controls: **16 processes,
zero tracked live allocations at exit**. Counts cover FY system-heap allocations,
not process RSS. Product sources already contained the required rejection/cleanup
logic, so no runtime fix was necessary.

## Scope

This closes four concrete Provider failure paths previously left unexecuted by
the [allocator failure probe](m2-buffer-failure.md). Arbitrary provider memory
corruption, all failure/status combinations and cleanup failures of malformed
native roots remain outside this evidence. Full lifecycle/native/CLI suites,
M0, Linux, DLL embedding, isolation, packaging, performance and common Instance
shutdown/guest integration were not run or implemented by this verification slice.

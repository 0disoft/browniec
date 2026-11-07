# Private bounded Windows binary input reader

`native/runtime_input_reader.c/.h` provides an opaque owning native snapshot of
exact binary input, including NUL and arbitrary non-UTF8 bytes. No parser, type
checker, VM dispatch or guest filesystem authority is implemented in C here.

`bc_rir_path(path, UTF16_length, limit, out, error)` takes an explicit trusted
absolute drive path. It rejects relative roots, embedded NUL and overlong paths,
opens exactly that file without discovery/CWD/environment expansion and reads
from its beginning. Trusted host path resolution follows normal Windows rules;
this is not the anchored source collector or a filesystem containment policy.
`bc_rir_handle(handle, limit, out, error)` duplicates an explicit caller handle
and closes only the duplicate. Synchronous disk and blocking byte-pipe handles
are supported; character, async, message and nonblocking pipes are rejected.
The disk duplicate shares the caller cursor and starts at its current position.
Caller must serialize access and keep supplied pointers/handles valid for the
call. No ambient stdin or default path is selected.

Both APIs check limit <= 1MiB and an initially NULL output slot before OS work.
Disk remaining size is checked against the limit before allocation. Pipe length
is unknown until EOF: after validating the limit, staging allocates exactly one
bounded payload capacity plus native metadata, never an untrusted stream length.
Checked allocation sums and ReadFile request sizes bound every write. A one-byte
probe distinguishes exact/zero-cap EOF from over-cap input. Short reads continue
from their actual byte count; broken byte-pipe EOF is accepted. Successful zero
bytes on disk is EOF. Successful zero bytes on a pipe is explicitly rejected as
`BC_RIR_OS` / `ERROR_NO_DATA`, with no publication or retry. A pipe writer can
produce such a result using a zero-byte WriteFile; it is not EOF. See the
[Microsoft ReadFile pipe contract](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-readfile#pipes). No text decoding,
terminator or newline conversion occurs. Returned length excludes metadata and
uninitialized capacity. Accessors expose immutable bytes only for owner lifetime.

A single staging owner is published only after EOF and successful close of the
internal read handle. Every failure frees staging and closes internal handles;
existing caller output slots remain unchanged. `bc_rir_close(NULL)` is harmless.
No resource/array/slice layout crosses a Fairy boundary; this slice has no Fairy
FFI adapter. Bytes remain owned after original handles/files are closed/deleted.

Reading consumes the underlying cursor or pipe, even when a later quota/read
failure rejects the result. No rollback, hidden retry or replay is attempted.
Synchronous OS reads and EOF probes may block indefinitely. Neither R03 bounded
steps, deadlines, cancellation nor point-in-time file consistency are promised.
Payload storage is bounded; complete Engine accounting and guest input/CLI/stdin
binding remain later work. No public availability or Fuel prices change.

Run `python tools/verify-runtime-input-reader.py` on Windows with MSVC/SDK.
The verifier builds actual production and explicit `BC_RIR_TEST` objects under
/Od and /O2, rejects CL/_CL_/LINK and /STACK overrides, checks default PE stacks,
and verifies production objects contain no test hooks. Three groups separately
execute the hook-free production disk/pipe binary. Six test groups test
exact/over/zero disk and pipe limits, partial pipe reads, binary bytes, cursor and
original-handle lifetime, wrong/invalid/write-only/async handles, missing paths,
allocation failures and repeated cleanup. Test allocation failures are explicit
seam evidence, not actual whole-process heap exhaustion. Every failure checks no
partial publication; stable process handle counts (after explicit pipe/thread
initialization before the baseline) and zero counted snapshot
allocations are asserted. Receipts retain input, compiler, object, executable and
command/log hashes under ignored `build/runtime-input-reader`.

Zero-byte pipe evidence is deliberately split. Real anonymous byte-pipe probes
use zero-byte WriteFile calls during a pending reader operation, with empty and
three-byte prefixes, spare/exact/zero capacity, and a queued suffix (four cases).
They run in hook-free production and normal test builds in both profiles. On
this Windows host all four probes per image observed NO successful zero-byte
ReadFile: normal data or limit behavior retained the exact suffix; this is not
an OS reproduction of the no-progress branch. Observations are recorded rather
than called a regression pass for that branch. Broken-pipe EOF remains covered.

A separate explicit `cl /FI` header redirects only the reader translation unit's
ReadFile calls. The host wrapper uses actual ReadFile for ordinary reads and
returns TRUE/zero once at the selected boundary. Four injected cases (before any
bytes, after a three-byte prefix, and exact/zero capacity) require BC_RIR_OS /
ERROR_NO_DATA, no owning output, exactly one failing-boundary call, no retry,
zero retained staging allocations, and a valid original caller handle. Reading
a new suffix through that original handle proves the duplicate was cleaned up
and no subsequent bytes were consumed. Baseline production/test runs have no
syscall interception. All images retain the default stack and no compiler env
flags. No actual OS pass is invented for the injected result.

A negative-control build artifact restores only the old `got == 0` EOF branch
and links the same injected-return host. It must fail the precise no-progress /
no-publication assertion in both profiles; the actual fixed reader passes. The
receipt retains the control source/executable hashes and expected failure logs.

# Windows restricted worker launch

The private [launcher](../../native/restricted_worker.h) takes a trusted broker's
absolute executable and working directory, provisioned AppContainer SID, and
three distinct inheritable pipe endpoints for stdin, stdout, and stderr. Policy
supplies the Job commit and user CPU limits. The Job also limits active
processes to one and terminates its members when the last Job handle closes.

The launcher requests an AppContainer with zero capabilities, an explicit
handle list, and creation-time Job membership. It passes a bounded environment
allowlist for Windows profile and system directories. Windows can use those
entries to redirect AppContainer storage. The ordinary broker environment is
excluded. Before returning a suspended worker, the launcher confirms membership
in the specific Job and queries the primary token for AppContainer identity,
the expected SID, and zero capabilities. A setup failure leaves the worker
owner empty. Resuming consumes the primary-thread handle. Closing the Job
initiates termination, and the owner retains its process handle until exit.

## Private pipe setup

The [pipe owner](../../native/restricted_worker_pipes.h) creates three
one-directional byte channels with one instance and a 4096-byte buffer request
per channel. It uses a fresh system-generated 128-bit suffix for each name,
rejects remote connections, and applies a protected DACL with one ACE for the
broker's logon SID. The ACE excludes the right to create another instance.
The broker opens both ends before launch and confirms that each endpoint
reports the broker PID for its peer. Only the blocking child endpoints are
marked inheritable. The broker endpoints support overlapped I/O.

Setup publishes all six handles together. Failed setup closes the handles
already opened. No I/O is pending at publication. After suspended launch,
the broker closes its copies of the child endpoints and retains its own
endpoints until it has reaped any pending I/O.

## Session frame headers

Each pipe owner generates a separate 128-bit session nonce when it opens the
endpoints. The broker sends it in an empty HELLO on the inherited stdin; the
worker echoes it in an empty READY on stdout. Each direction starts at sequence
1, then uses the next sequence for each accepted frame. Receivers also check
the expected kind and correlation ID for the current phase.

The [header codec](../../native/restricted_worker_frame.h) uses a fixed 48-byte
header. All numbers are little endian.

| Byte offset | Size | Field |
| --- | ---: | --- |
| 0 | 4 | Magic `BCWK` |
| 4 | 2 | Protocol revision, currently 1 |
| 6 | 2 | Message kind |
| 8 | 4 | Payload length |
| 12 | 4 | Reserved, must be zero |
| 16 | 8 | Directional sequence |
| 24 | 8 | Correlation ID |
| 32 | 16 | Session nonce |

Preflight checks the complete header and caller's per-message ceiling before
any payload read. It also caps a single header and body at 4 MiB combined.
The body must match the declared length. Session-wide budget accounting and
byte-stream EOF and trailing-data checks belong to the transport and broker.

The native fixture exercised HELLO, READY, START and RESULT on the inherited
pipes in development and /O2, with a HELLO split into two writes. It checked all
48 one-bit READY header mutations and all 48 truncated header lengths, plus
duplicate sequences, crossed correlations and size boundaries. Both profiles
retained zero net warm-launch handles. The RESULT stays fixture data.
Local receipt: `build/restricted-worker/20261121T152949567319Z/receipt.json`.

## Bounded pipe stream

The [RX and TX cursors](../../native/restricted_worker_stream.h) offer a
48-byte header window and then body windows of at most 4096 bytes. RX clamps
the phase limit to the caller's buffer capacity. A rejected header exposes
zero body bytes for reading. The cursor returns a frame only after the entire
declared body arrives. RX distinguishes EOF before a header from truncation
inside a header or body. TX keeps the header and body in separate windows and
preserves its position across short writes.

Development and /O2 verify the real AppContainer exchange and stdout EOF with
these cursors. The same fixture checks a 4097-byte body, one-byte-short storage
and body, a seven-byte header followed by EOF, and zero-byte progress in cursor
tests. Session-wide limits and the decision to publish remain broker concerns.
Local receipt: `build/restricted-worker/20261121T153306970209Z/receipt.json`.

## Result publication gate

The [gate](../../native/restricted_worker_gate.h) starts after START. It
borrows an immutable candidate only after receiving a complete RESULT and
passing the payload validator. It releases the candidate to its caller once,
after the broker observes stdout EOF and exit code 0 on the signaled process.
The publication deadline is exclusive, sampled on the same monotonic clock
as cancellation and failure observations. A duplicate RESULT, early EOF,
trailing byte, bad payload, nonzero exit, cancellation, or expiry discards
the candidate. Later events preserve the first terminal cause.

The native AppContainer fixture checked withheld delivery after a complete
RESULT, delivery after actual EOF and exit 0, and rejection of a complete
RESULT after Job CPU termination. Deterministic gate cases cover ordering,
validation, cancellation and the exact deadline tick. Both profiles had zero
net warm-launch handles. The fixture's validator accepts one byte; the
production worker still needs strict result schema validation.
Local receipt: `build/restricted-worker/20261121T153623372644Z/receipt.json`.

## Overlapped I/O lease

The [I/O owner](../../native/restricted_worker_io.h) submits one read or write
of at most 4096 bytes with a private event. While the operation is pending,
the owner retains its `OVERLAPPED` storage and borrows the pipe and buffer.
Only polling a terminal Windows completion releases that borrow. The owner
rejects both a second submission and an event close before collection.

The native fixture observed a pending read, then cancellation and a collected
`ERROR_OPERATION_ABORTED`. A second read completed before the cancellation
request and still held its lease until collection. The real AppContainer
exchange also uses this owner. Both profiles returned to the warm handle
count. Local receipt: `build/restricted-worker/20261121T153823462884Z/receipt.json`.

## Serialized broker session

The [Windows broker](../../native/restricted_worker_broker.h) owns the verified
worker, private endpoints and overlapped I/O leases. It sends HELLO, accepts
READY, sends START, accepts a complete RESULT, probes stdout for EOF and
observes process exit. Each step submits or collects at most one operation
or polls the process. The gate releases a validated result only after these
steps and while the session deadline remains live.

Admission reserves five 48-byte headers, the START bytes, the caller's
RESULT ceiling and a one-byte trailing probe before opening handles. The
borrowed request and result storage stays reserved through teardown. Close
on an unfinished session records cancellation or expiry and retains the owner
through both completion collection and process exit.

The initial Windows development and /O2 runs verified five AppContainer sessions. Clean completion
delivers once. An early RESULT and a trailing stdout byte fail the protocol.
Cancellation and expiry reap an outstanding read. The initial wire limit was
195 bytes for a one-byte request and reply. Reserving CANCEL raised that
limit to 243 bytes. Warm handle delta is zero. The fixture validates one-byte
results. Production payload schemas and host exchange remain integration work.
Local receipt: `build/restricted-worker/20261121T154216262890Z/receipt.json`.

### Shared admission budget

Sessions under one serialized owner reserve one slot, the broker's control
size plus both borrowed spans, the child Job's commit ceiling, and the wire
envelope before opening handles. Each dimension checks available capacity
before any counter is changed. Reaping still occupies all four reservations.
Closing after both process exit and I/O collection returns the exact charges.
These are admission reservations; process and kernel overhead are outside
the measured parent charge.

Windows development and /O2 ran two overlapping AppContainer sessions with
one read pending. The second session was rejected at each exhausted slot or
one-byte-short aggregate limit, admitted when all four limits fit, and reaped
without returning the first session's charge. Startup rollback restored the
same counters, all reservations returned to zero, and warm handle delta was
zero. Local receipt: `build/restricted-worker/20261121T154433211461Z/receipt.json`.

### Phase deadlines

The broker starts the startup window before opening handles and requires
READY by its end. After READY it starts an idle window and renews it only
when a pipe transfer makes progress or stdout reaches clean EOF. No phase
window extends the absolute session deadline. The broker samples Windows
interrupt time before processing a completion or accepting process exit.
Close records expiry if that phase window already elapsed and preserves an
earlier terminal cause.

Windows development and /O2 verify separately expiring startup before
READY and idle after START. Both cases hold an outstanding read when the
phase expires, while the overall session deadline is still live. Reaping
returns the reservation with zero net warm handles in each profile.
Local receipt: `build/restricted-worker/20261121T154634779864Z/receipt.json`.

The private parent settles explicit cancellation through the broker before
teardown. One monotonic sample chooses cancellation or an already expired
phase, and the parent reports that latched outcome. The native fixture checks
cancellation on an actual pending pipe read both before and after the startup
deadline. The earlier cancellation survives a later expiry during cleanup.
Development and /O2 passed those cases and the parent publication checks.
Local receipt: `build/restricted-worker/20261121T162851207548Z/receipt.json`.

### Graceful cancellation

Cancellation freezes the result gate immediately. If START is in flight,
the broker finishes that frame before sending an empty CANCEL with the next
TX sequence. The cancellation write uses a separate overlapped lease so the
broker can retain an already pending stdout read. With START sent, the broker
drains at most one correctly framed RESULT and probes for EOF without calling
the result validator or delivering output. A second frame, malformed framing
or non-boundary EOF ends the drain. Before START, the broker can stop directly.

The grace window starts when the owner requests shutdown and applies only to
cleanup. When it expires, the broker terminates the Job with `ERROR_TIMEOUT`
and reaps the process and both I/O leases. The cancellation or expiry already
recorded by the gate remains the session outcome.

Windows development and /O2 ran two additional real AppContainer cases. A
4,097-byte START survived cancellation after the header. The worker verified
the complete payload and separate CANCEL, sent a late RESULT and exited
normally. The broker drained the byte without calling the validator or
publishing. A second worker received CANCEL, stayed blocked, and was forcibly
terminated after a 300 ms grace window. Both cases refunded their exact
reservations and the full fixture reported zero net warm handles.
Local receipt: `build/restricted-worker/20261121T155129609214Z/receipt.json`.

### Scalar RESULT payload

The private [Fairy codec](../../src/worker_scalar_result.fy) caps JSON RESULT
payloads at 256 bytes. Every object requires schema
`browniec.worker-result/v1` and a status. A checked result has those two
fields. A completed run adds a decimal `return_i32` in signed 32-bit range.
An error adds `kind`, `location` and `offset`. Source positions can point
to EOF, verifier instruction indices must be below the supplied instruction
ceiling, and an absent position has offset zero. The parent supplies the
expected operation and ceilings. Field names are matched after JSON escape
decoding. Duplicate, unknown, missing, nested or trailing content is rejected
before a typed outcome is returned.

The same codec creates the payload from the typed outcome. This schema is an
internal scalar transport contract shared by the worker and the parent's
publication validator. Projects, output bytes and host exchange need their
own integrated payloads.

The focused native case passed Windows development and /O2 with the same
root sources and lock in a test checkout containing only that case. Native
test loading with the full test tree reports `E4503` at
`tests/m2/struct_function_ir.fy:28`. The same error was reproduced from the
preceding commit with the existing CLI locations case selected. Local
reports: `build/worker-result-thda5j4j/development.stdout`,
`build/worker-result-thda5j4j/release.stdout` and
`build/worker-result-btngpe_b/development.stderr`.

### Scalar source in the actual worker

The Windows CLI image contains a private one-shot worker entry. The
[Windows shim](../../native/windows-scalar-worker.c) checks Job membership,
the AppContainer token and byte-pipe client endpoints from the same server
process before accepting HELLO. It validates the START header and length
before reading the body. START holds one operation byte (0 check, 1 run),
four little-endian Fuel bytes, and up to 4096 original source bytes. Check
requires zero Fuel and run uses the existing CLI Fuel ceiling.

The [Fairy command](../../src/worker_scalar_command.fy) compiles only inside
the admitted worker. Check verifies the Program without running it. Run uses
the existing VM and sends a typed RESULT for guest success or failure. The
worker emits its frames exclusively on the inherited stdout pipe.

The locked development and /O2 CLI images each ran four actual sessions
through the native broker: check, `examples/answer.brc` returning 77,
zero-Fuel failure, and invalid UTF-8 with source offset 0. The fixture
validates the expected payload and publishes only after EOF and exit 0.
Direct use of the worker entry from the ordinary process returned 4 and
produced zero stdout and stderr bytes. Warm handle delta remained zero.
The native check accepts the images with
`python -B tools/verify-restricted-worker.py --scalar-images build/restricted-scalar-images`.
The directory contains `development/browniec.exe` and `release/browniec.exe`
from `fairyc build --locked` and `fairyc build --release --locked`.
Local receipt: `build/restricted-worker/20261121T161049790834Z/receipt.json`.

The broker passes each session's immutable expectation to its result
validator. The expectation is bound at admission and remains borrowed until
close. The fixture no longer needs shared mutable validation state. An
additional native case received a complete run result under a check
expectation and rejected it before publication. Both profiles passed all
five scalar sessions with zero net warm handles.
Local receipt: `build/restricted-worker/20261121T161323928124Z/receipt.json`.

### Scalar parent publication

The [Windows parent bridge](../../native/windows-scalar-broker.c) launches its
own image with an explicitly supplied AppContainer profile. The private
parent path expects the caller to provision that profile and grant image
read/execute. It uses a 128 MiB Job commit ceiling and a 2 s user CPU ceiling
for scalar verification. The parent snapshots the source from the selected
disk file; the child gets the original bytes over START.

The gate calls the [Fairy validator](../../src/worker_scalar_broker.fy) on the
complete result using the parent's operation and source size. The validator
borrows at most 256 bytes and invokes the same strict codec as the worker.
After EOF and a successful child exit, the parent reads the typed result and
uses the existing CLI formatter. A profile or transport failure cannot fall
back to local compilation. This route is private pending profile/image
provisioning and broader policy, source and host integration.

Locked Windows development and /O2 passed check, run returning 77,
invalid UTF-8 producing a lexical error at byte 0, and invalid profile
producing unavailable. Each invocation returned exactly one expected CLI
result. The first ordinary parent launch added one handle to each fixture
process; the remaining success and failure launches showed zero handle
growth. Local receipt: `build/restricted-worker/20261121T162302104825Z/receipt.json`.

### Managed scalar worker setup

The private `--internal-scalar-broker check|run SOURCE` route provisions a
fresh zero-capability AppContainer profile with a 128-bit random name. It
stages a copy of the running CLI in a new directory under the Windows temp
root. The [stage owner](../../native/restricted_worker_stage.c) caps the copy
at 64 MiB and uses a 16 KiB transfer window. The directory and image use
protected DACLs for the current user, SYSTEM and the specific worker SID.
The worker gets read and execute rights. The original image's ACL is untouched.

The broker uses the staged directory as the worker's working directory and
keeps the image pinned through process reaping. It attempts deletion of the
image, directory and profile after reaping, including on setup or execution
failure. A successful worker result is delivered only after cleanup succeeds.
Abrupt termination of the parent can leave its uniquely named stage and
profile behind. The public restricted option is still gated on the broader
authority and broker integration.

Locked Windows development and /O2 each returned 77 with exit 0 and empty
stderr using a fresh staging root. Both returned unavailable with exit 4 when
the root was absent. Native checks inspected the protected image DACL, rejected
deletion while the image was pinned, verified profile-name reuse after
cleanup and removed the partial image after a rejected empty input image.
Local receipt: `build/restricted-worker/20261121T163857490321Z/receipt.json`.

### Project source snapshots and entry selection

The private `--internal-project-broker check|run MANIFEST` route uses the
anchored collector to read the manifest and its declared source files. The
parent rejects nonempty requirements before reading any source member. It
passes only the selected bytes to the AppContainer, which reparses the
manifest, rebuilds the snapshot, binds each module against its manifest row
and compiles the manifest's named public entry. The worker opens no project
files.

Project START uses operation 2 (check) or 3 (run), four little-endian Fuel
bytes, a little-endian 32-bit manifest length, the original manifest, and one
little-endian 16-bit length per manifest source row followed by each member's
bytes in that order. Limits are 65,536 manifest bytes, 16 source members and
4,096 aggregate source bytes, for at most 69,673 request bytes. The worker
checks that the declared member sizes cover exactly the bytes received.

Project RESULT prefixes the existing scalar JSON payload with the profile,
source index and little-endian span end. The broker validates the operation
and original per-file boundaries before publication. The parent uses those
same source bytes to render the JSON v2 diagnostic, including the path, line
and byte column. Project setup and RESULT publication use the same managed
stage, deadline and completion gate as the scalar route.

Locked Windows development and /O2 each checked and ran the two-module hello
example using a START body over 4 KiB, returning 42 on run. An error in
`src/math.brc` retained the same byte range, path and line as the ordinary
project check. Both profiles denied an ungranted requirement before reading
a missing member, rejected direct worker entry outside AppContainer, and
dropped two malformed member length tables without a RESULT. The managed
staging directory was empty after each profile. Local receipt:
`build/restricted-worker/20261121T164903771680Z/receipt.json`.

### Project policy and worker limits

The private project broker accepts an explicit `POLICY RUN` pair after
`MANIFEST`. The parent parses the standard policy and run schemas and checks
the run against the policy ceiling. The run's module and function must match
the manifest. The no-host route requires empty manifest requirements, run
requirements and run grants. It checks these alongside the module count
before reading members.

The parent narrows member count and total source bytes to the policy's
compile limits and the native snapshot limits. START carries the requested
run Fuel, bounded by the current VM ceiling. The parent projects the
policy's Job memory and user CPU ceilings, one-process limit, transport
ceiling, startup and idle windows, shutdown grace and absolute session
deadline into the existing broker. The deadline starts before managed
staging. Job limits and result gating remain under the parent's control.
### Engine policy inside the worker

Configured START uses operation 4 (check) or 5 (run). Two additional
little-endian 32-bit lengths follow the original START prefix. The
original manifest, policy and run bytes follow in that order, followed by
the existing member length table and member bytes. Each document is
bounded to 65,536 bytes, for a maximum START of 200,753 bytes. The parent
sends the same policy and run snapshots that it admitted.

The worker reparses the snapshots and checks the policy ceiling, entry,
empty capability grants and effective Fuel. It creates a policy-owned
Engine, compiles the selected entry with the bounded output-capable
compiler and checks the retained Program's emit requirement against the
admitted grant. The worker uses the configured Engine for compile working
memory, Program and Instance memory, supported VM limits, Fuel and the
separate compile and execution deadlines. It advances the Instance in
quanta of at most 4,096 units and destroys it before releasing the Program
and delivering a result. The configured path reports the reference
profile used by this Engine.

During module binding, the Engine checks aggregate lexical tokens excluding
per-file EOF, declared functions, and declared record types against policy.
After proof and before publishing the Program, it checks the verified
image's instruction count, function count and registers per function
using the same image check as the host compiler. The native token cap
including EOF still applies to the ordinary module index.

The configured worker also applies the policy depth ceiling to nested
parentheses, brackets and braces inside declaration bodies. The module index
counts lexer tokens during its existing scan, starting inside the declaration's
outer braces. Comment and literal contents do not count. The first excess
opener produces a source-local `compile_limit`. The existing parser still
validates delimiter pairing and enforces its own grammar limits.

Compile Fuel, semantic depth outside this delimiter check, and type accounting
beyond declared records remain open. Host requests still need worker
transport integration.

The nesting follow-up passed twenty configured project cases per Windows
profile. A nested block and parenthesized value returned 42 at depth two,
with a sibling block and a delimiter-bearing comment in the same body. The
depth-one check returned exit 3 with the half-open span of the excess opener
in the second module. Local receipt:
`build/restricted-worker/20261121T172355590261Z/receipt.json`.

Locked Windows development and /O2 each passed eleven configured project
cases. The two-module project returned 42. The new cases reject a compile
working budget equal to the source bytes, a one-byte execution memory
budget, and an execution deadline shorter than a long-running loop. The
execution deadline case uses an independent ten-second broker session.
When Fuel runs out during Engine preparation, the diagnostic has no source
location. Local receipt: `build/restricted-worker/20261121T170631218424Z/receipt.json`.

The compiler-limit follow-up passed eighteen configured project cases per
Windows profile. The two-file fixture ran at exactly 44 lexical tokens and
two functions. It failed at 43 tokens or one function. A second fixture
ran with two declared records and failed with a one-record ceiling or a
one-register-per-function ceiling. A check with a one-instruction ceiling
also failed. Every policy rejection returned `compile_limit` with exit 3.
Local receipt: `build/restricted-worker/20261121T171541509700Z/receipt.json`.

Locked Windows development and /O2 each passed eight configured project
cases. The two-module project returned 42 at its exact source-byte limit;
one byte less and one module less were denied. Fuel exhaustion retained
the source location. A run above the policy ceiling, a mismatched entry
and a nonempty grant were denied. A one-millisecond session expired
without publishing a guest result. The temp staging root was empty after
every case. Local receipt:
`build/restricted-worker/20261121T165734114642Z/receipt.json`.

### Configured binary input

The private broker accepts `--internal-project-broker run MANIFEST POLICY
RUN INPUT`. The parent opens the explicit file under the lower of the run's
input and memory ceilings and the 1 MiB input cap. START operation 6 adds
a little-endian u32 input length at byte 17. The payload follows the last
source member. The maximum START is 1,249,333 bytes. After native framing
admits the message, the worker allocates the announced size and reads that
exact body. It validates the input length separately from the source
directory, compiles the named public entry, and binds a policy-checked
input snapshot to the Instance. A shared-byte run requires an explicit
file, which can contain zero bytes. A scalar run rejects an input file.
Check accepts either supported signature without opening an input file.
Result publication still requires the existing broker gate.

Windows development and /O2 each passed 29 configured project cases. A
file of 8,193 bytes passed at that limit and failed with `input_limit` one
byte below it. A 1 MiB file returned the unsigned final byte, and an empty
file took the empty-input branch. The matrix also checks entry/input
mismatches, check-only behavior, the input Program's instruction ceiling
and a clean staging directory after every case. Local receipt:
`build/restricted-worker/20261121T173313253515Z/receipt.json`.

### Configured sealed output

The configured project can declare `brownie.output.emit`. The policy must
permit it and the run must declare and grant it. The worker checks the
retained Program's emit requirement before execution. A completed run with
output authority sends a RESULT envelope containing marker 128, a little-endian
u16 metadata length, the existing project RESULT metadata, and the sealed
binary bytes. Unprivileged runs and failed results use the existing metadata
format. The parent permits the envelope only for a successful run with an
admitted grant and bounds its byte tail to the run's output ceiling.

The native broker receives into the caller-owned buffer and retains it through
I/O completion, clean process exit, stdout EOF and staging cleanup. The parent
renders `output_b64` only after the broker returns success. No guest bytes
are copied by the native broker during handoff.

Windows development and /O2 each passed 36 configured project cases. The
output cases verify run and manifest authority, a check with no output,
an exact 8,193-byte round trip, rejection one byte below the output size,
a trap after emit with no published bytes, and a zero-argument emit.
Local receipt: `build/restricted-worker/20261121T174415853814Z/receipt.json`.

The focused native codec tests passed in both Windows profiles. They reject
unwrapped success on a granted run, an output envelope on check or without
a grant, a truncated metadata envelope, and a payload over the requested
limit. A granted run accepts an empty envelope at a zero-byte ceiling and
preserves output-limit diagnostics without output. Local reports:
`build/worker-output-frame-i0pip5nv/development.stdout` and
`build/worker-output-frame-i0pip5nv/release.stdout`.

### Broker host exchange

An opted-in session borrows one request span and one reply span, reusing
them for sequential calls. Admission reserves both spans once and reserves
two header and payload ceilings per allowed call against the wire budget.
The read cursor accepts a RESULT or the next HOST_REQUEST. It checks the
directional sequence, session nonce, next correlation ID and request ceiling
before selecting the request span. It dispatches only a complete, nonempty
request to the bounded parent callback. The reply echoes the correlation
and consumes the next parent sequence. RESULT keeps correlation zero and
still requires clean EOF and exit before publication.

Cancellation finishes an already-started reply before sending CANCEL at the
next parent sequence. The broker can drain a request already in flight
without dispatching it, then accepts only a terminal frame during that drain.
Both request and reply spans remain reserved through reaping. This is
native transport; the AppContainer fixture uses a bounded byte callback.
Brownie catalog and VM host requests still need integration.

Development and /O2 each passed seven AppContainer cases: two successive
calls, wrong correlation, oversized request, call quota exhausted, callback
rejection, cancellation before a request body is processed, and cancellation
after a reply header is sent. Both cancellation cases receive a late RESULT
without publishing it. Local receipt:
`build/restricted-worker/20261121T175242080375Z/receipt.json`.

## Windows verification

Run `python -B tools/verify-restricted-worker.py`. The development and optimized
x64 fixtures use the default 1 MiB reserve and 4 KiB commit stack. They create
temporary zero-capability profiles and grant read/execute to the fixture EXE.
They inspect the suspended Job's one-process, 128 MiB commit, and 500 ms user
CPU limits, reject an ordinary SID and a noninheritable pipe, and reap a
suspended worker without resuming it.

The resumed fixture verifies denial of a parent-readable file and an unrelated
inheritable event handle. It confirms that a marker environment variable is
absent, exchanges bytes over approved pipe endpoints, fails a 128 MiB commit
attempt, and is terminated by Windows after reaching its user CPU limit. Both
profiles observed three additional process handles during cold initialization
and zero net change across the repeat launch and its cleanup.

Local receipt: `build/restricted-worker/20261121T152043609866Z/receipt.json`.

The named-pipe follow-up ran the same native AppContainer fixture in both
profiles. It inspected each live pipe's single logon-SID ACE, one-instance
limit, connecting PID, and inheritance flags. The child exchanged bytes over
all three pipes and the repeat launch again had zero net handle growth.
Local receipt: `build/restricted-worker/20261121T152431466055Z/receipt.json`.

Broader Engine policy enforcement, broker phases and aggregate budgets are
still required for the public restricted CLI.

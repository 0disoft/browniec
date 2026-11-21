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

[Scalar expression depth](#scalar-expression-depth),
[statement control depth](#statement-control-depth), and
[aggregate expression depth](#aggregate-expression-depth) apply during
lowering. The policy also covers [nominal record depth](#nominal-record-depth),
[signature type depth](#signature-type-depth), and [local type depth](#local-type-depth).
[Scalar and nominal type quota](#scalar-and-nominal-type-quota) also
checks the image before publication, including [array types](#array-type-quota)
and [view types](#view-type-quota). [Host signature types](#host-signature-type-quota)
come from the verified import set.

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

### Project worker host exchange

The native project worker keeps the inherited input pipe after consuming
START. It sends a nonempty HOST_REQUEST at the next worker sequence, then
waits for a matching HOST_REPLY or CANCEL at the next broker sequence.
The reply header must match the nonce, sequence, correlation and buffer
ceiling before the worker reads the body. The function reports a reply
length only after receiving every byte. CANCEL has a separate outcome and
prevents another host call. A failed transfer closes the RESULT path.

The fixture uses the production worker functions for two successive calls
and for CANCEL while awaiting the first reply. The cancelled call retains
the caller's length sentinel and cannot be repeated. The broker drains
the late RESULT and preserves cancellation. All nine native host cases
passed in Windows development and /O2. Local receipt:
`build/restricted-worker/20261121T175501251899Z/receipt.json`.

The locked Brownie executable also built in both profiles using the
root-qualified native headers required by Fairy C's generated bridge.
Each profile passed the nine native host cases and the five managed and
36 configured project cases using the freshly built executable. Local
receipt: `build/restricted-worker/20261121T180147737119Z/receipt.json`.

## Catalog-backed project execution

The internal project host broker accepts an explicit catalog and, for run, a
digest-bound table of typed replies. The broker sends the catalog in START
with the exact policy, run configuration and project snapshot. The reply
table stays in the parent. The worker verifies manifest requirements, run
grants and Engine policy before it retains a Program. Host project admission
uses the same source, token, declaration, delimiter and IR ceilings as the
configured project path.

The worker steps its Instance until it needs a host reply. It copies the
pending request, claims it once and sends the four-byte import ID followed
by the typed payload. The parent resolves the import in its explicit catalog,
checks the capability against its own declaration and grant, and matches the
exact request bytes in the prevalidated table. A reply is a one-byte kind
followed by its typed payload. The worker submits it to the originating
Instance with the original Engine request ID after IPC correlation and
complete frame receipt. Engine validation and the existing sealed output
path govern guest resumption and publication.

The private adapter caps each payload at 4096 bytes in addition to the run
policy. The broker reserves both staging spans and the worst-case wire bytes
for the configured call count. The current adapter serves explicit in-memory
replies. Trusted process dispatch from the broker and public restricted
admission are still open.

Locked Windows development and /O2 builds each passed eleven catalog
project cases, including two calls yielding 77, explicit input, successful
output publication, and no output on a missing lookup or quota failure. Both
profiles also passed nine native host transport cases, five managed project
cases, and 36 configured project cases. Native fixtures cover correlation and
cancellation while transferring a request or reply. Local receipt:
`build/restricted-worker/20261121T181726030809Z/receipt.json`.

## Project index Fuel

The configured worker starts indexing with the policy's compile Fuel.
It prepays one unit for each byte of a member before scanning the member,
then charges one unit before each lexer advance, including EOF. Members
share one balance. A deficit returns a source-local compile limit before
the next scan and prevents the Index from being retained. Both Engine paths apply this budget during indexing.

The indexing checkpoint in Windows development and /O2 admitted the
index of the two-file hello project at 179 units (133 bytes plus 44 tokens and two EOF advances) and rejected
178 at the second file. Both rejected a one-unit compile budget on the
catalog-backed path. The complete focused run passed 38 configured cases,
12 catalog project cases, five managed project cases and nine native host
transport cases per profile. Local receipt:
`build/restricted-worker/20261121T182525039194Z/receipt.json`.

## Project lowering and proof Fuel

The output-capable worker passes the index's unspent compile Fuel to its
source preparation, literal and signature passes, body lowering and
independent output proof. Each dispatch prepays the existing 4,096-unit
metadata batch allowance. Exhaustion returns `compile_limit` before the next
dispatch. The same policy balance applies to zero-argument and shared-byte
input entries.

The two-file hello project needs 179 units for indexing and 863 prepaid
batches for the following stages. Both Windows development and /O2 return
42 at 3,535,027 and reject 3,535,026 without a guest result. A budget of
179 finishes indexing and fails at the first source preparation dispatch.
Both profiles pass 40 configured project cases, 12 catalog project cases,
five managed project cases and nine native host transport cases. Local
receipt: `build/restricted-worker/20261121T183550192986Z/receipt.json`.

The charges at this checkpoint covered the staged compiler dispatches and
output proof. [Execution scratch preparation](#execution-scratch-preparation-fuel)
now uses the same balance.

### Catalog-backed lowering Fuel

The catalog-backed worker uses the same unspent index balance during host
binding, source collection, signature scanning, body lowering and candidate
finalization. The budget prepays each existing dispatch or synchronous
top-level lowering step. Host binding and raw body lowering also check the
compile deadline at these boundaries.

The two-call catalog fixture needs 255 indexing units and 401 prepaid
4,096-unit batches. Both Windows development and /O2 return 77 and publish
the expected bytes at 1,642,751 units. At 1,642,750, both return `compile_limit`
without a guest result or output. Each profile passed 14 catalog project
cases, 40 configured project cases, five managed project cases and nine
native host transport cases. Local receipt: `build/restricted-worker/20261121T184432127814Z/receipt.json`.

### Catalog-backed proof Fuel

The independent catalog verifier continues with the balance left after
lowering. It prepays catalog digest binding, type metadata, opcode checks,
CFG metadata, each function and instruction in the CFG pass, and final
capability validation before allocating the retained Program. Verification
checks the compile deadline at the same boundaries. The explicit IR charges
use the existing 4,096-unit compile batch allowance.

The two-call fixture spends 28 additional batches in verification. With
only the 1,642,751 units needed by indexing and lowering, check returns
`compile_limit` in verification. Windows development and /O2 both check and
run at 1,757,439 units, yielding 77 and the expected output on run.
At 1,757,438, run returns `compile_limit` with no guest result or output.
Each profile passes 16 catalog project cases, 40 configured project cases,
five managed project cases and nine native host transport cases.
Local receipt: `build/restricted-worker/20261121T185334424916Z/receipt.json`.

Two existing host-proof cases also pass in an isolated /O2 fixture. Root
test discovery reached the unrelated general specialization limit in
`tests/m2/struct_copy.fy` before it could run those selected cases.

### Execution scratch preparation Fuel

After independent output proof, configured projects prepay one compile Fuel
unit per instruction in each list or place requirement scan. Programs
without list operands skip the list scan. Aggregate places skip the ordinary
place scan when they determine the storage format. Scratch sizing reuses
the verified plans, removing a second pass through each selected scan.
The deadline remains active during planning and before retention.

The two-file hello project adds eight units for two scans of its four
instructions. Windows development and /O2 return 42 with 3,535,035 units
and fail with `compile_limit` at 3,535,034. At the previous proof boundary
of 3,535,027, check also fails during preparation before retaining a Program.
Both failures yield no guest result or output. Each profile passes 41
configured, 16 catalog and five managed project cases plus nine native host
transport cases. Local receipt:
`build/restricted-worker/20261121T190335773644Z/receipt.json`.

### Call-capture preparation Fuel

The configured output compiler charges one unit for each instruction,
argument, binding marker and creator lookup entry visited when building
the immutable capture plan. Each visit checks the compile deadline before
charging or reading the next entry. A failure discards the plan before
retention. The trusted unmetered callers use the same recipe logic.

The two-file hello fixture adds four instruction visits after scratch
planning. Windows development and /O2 return 42 at 3,535,039 units and
return `compile_limit` at 3,535,038. Check also fails at the previous scratch
boundary of 3,535,035. Failures yield no guest result or output. Both
profiles pass 42 configured, 16 catalog and five managed project cases
plus nine native host transport cases. Local receipt:
`build/restricted-worker/20261121T191130662101Z/receipt.json`.

A focused Windows /O2 fixture executes the nested capture regression from
`tests/m2/call_capture_live.fy`. A balance of 12 fails inside the first
creator lookup, 29 fails on the last instruction, and 30 produces the same
two-END recipe as the unmetered path. An expired deadline leaves all 30
units available. This fixture uses the production Windows clock shim.

### Project indexing deadline

The configured ordinary and catalog-backed snapshot routes pass their
existing absolute compile deadline into manifest path and header matching,
index construction, and import binding. The staged scanner checks the same
clock between its bounded continuations and before committing the token.
The index also checks immediately before allocation and before returning
its owner. Expiration returns the existing deadline diagnostic with no
source location. Index Fuel charges keep the same accounting.

Windows development and /O2 each pass 42 configured, 16 catalog and five
managed project cases plus nine native host transport cases on the real
monotonic clock. The development lexer fixture passes all three native
groups. An isolated /O2 index fixture runs seven index tests and uses a
controlled monotonic clock to expire inside a block comment and at the
last check before returning an index. Both ordinary and host indexing
return a deadline error at those boundaries, and an interrupted token
leaves the caller's lexer state untouched. The configured worker matrix
does not force a particular index phase to time out. Local worker receipt:
`build/restricted-worker/20261121T192158299111Z/receipt.json`.

### Scalar expression depth

The index carries the effective scalar expression depth into the signature
table. Recursive expression and operand lowering and staged scalar frames
check it at semantic depth transitions. The native depth ceiling is 32.
Unconfigured indexes use that native ceiling, and signed-minimum literal
handling keeps its existing precedence at the ceiling.

Two nested unary operators require depth two even without nested delimiters.
In both Windows profiles the ordinary fixture returns 42 at depth two and
reports the operand location in the second file at depth one. The catalog
fixture returns 77 and seals its output at depth two. At depth one it
returns `compile_limit` with neither a guest result nor sealed output.
Each profile passes 44 configured, 18 catalog and five managed project
cases plus nine native host transport cases. Local receipt: `build/restricted-worker/20261121T193124257651Z/receipt.json`.

The native test command cannot link the runtime clock companion. A focused
Windows /O2 executable with the production clock shim runs the three
existing unary regressions, including 32/33 boundaries and signed minima.

### Statement control depth

The indexed semantic depth limit also governs control frames and block
entry in the raw and staged compilers. This includes the structural
nesting of else-if clauses even when their blocks are lexical siblings.
Unconfigured compilation uses the native depth ceiling of 32.

The three-clause fixture returns 42 in the ordinary worker and 77 with
sealed output in the catalog worker at depth three. At depth two, the
ordinary check reports `compile_limit` at the third block opener in
`src/math.brc`. The catalog run fails with the same error kind and no
guest result or output. Windows development and /O2 each pass 46
configured, 20 catalog and five managed project cases plus nine native
host transport cases. Local receipt: `build/restricted-worker/20261121T194032051119Z/receipt.json`.

An isolated Windows /O2 executable with the production clock shim
passes five existing control regressions, including raw/staged IR
parity, exact diagnostic offsets and the native 32/33 boundary.

### Aggregate expression depth

Grouped array and record lowering uses the indexed semantic depth limit
when entering the operand and adding groups to its enclosing expression
depth. The staged array projection and conditional arm paths use the same
limit. Unconfigured compilation retains the compiler's native ceiling of
32.

A grouped array length and a grouped record field each occur beneath two
unary operators. Both fixtures returned 42 at depth two before this
change. Both Windows worker profiles now accept them at depth three and
reject them at depth two, with `compile_limit` at the group's opening
parenthesis in the second source and no guest result. Each profile passes
50 configured, 20 catalog and five managed project cases plus nine native
host transport cases. Local receipt: `build/restricted-worker/20261121T195339017629Z/receipt.json`.

A separate /O2 aggregate test executable exited with assertion status 134
on both the previous and current sources. That executable supplies no
additional evidence for the native aggregate 32/33 boundary.

### Nominal record depth

Indexed project lowering passes the effective compile depth into record layout
validation. A record with scalar fields has depth one. Each nominal field can
add one level above its child's computed depth. The native limit of 16 still
caps the configured depth. The existing memoized walk checks the limit while
laying out each node, including unused declarations, with no second catalog
traversal. Layout errors point to the record whose layout exceeds the limit.

The previous Windows development and /O2 images both ran the two-level record
fixture at depth one and returned 42. Both rebuilt profiles accept the same
project at depth two and reject it at one with `compile_limit` at `Outer` in
`src/math.brc`. The catalog path also accepts at two, returns 77 and seals its
output, then rejects at one without a guest result or output. Each profile
passes 52 configured, 22 catalog and five managed project cases plus nine
native host transport cases. All 455 receipt input hashes matched.
Local receipt: `build/restricted-worker/20261121T201053673711Z/receipt.json`.

### Signature type depth

The indexed signature scan applies `compile.depth` before recording compound
return and parameter annotations. The admitted shallow Option, Result,
scalar array, and slice each have one layer around a scalar leaf, for depth
two. Catalog-specific Result returns go through the same depth gate after
parsing their success and error types. Plain scalar and nominal names are
leaves. A depth denial points to the first byte of the annotation.

The preceding /O2 image ran each of the Option return, Result return and
array parameter fixtures at depth one and returned 42. Both rebuilt Windows
profiles admit them at two and reject them at one with `compile_limit`.
The shared-byte entry also rejects at one in both worker routes, with the
ordinary check pointing to `ref` in the entry source. Each profile passed
59 configured, 23 catalog and five managed project cases plus nine native
host transport cases. All 455 receipt input hashes matched.
Local receipt: `build/restricted-worker/20261121T201938837937Z/receipt.json`.

### Local type depth

The staged and synchronous lowering paths apply `compile.depth` to explicitly
typed locals before evaluating their initializers. Option, Result, scalar
arrays and reference views require depth two. A denial points to the first
byte of the annotation. Nominal record names use the existing layout check,
and inferred locals have no type syntax to check.

The preceding /O2 image ran all four ordinary local fixtures at depth one
and returned 42. Both rebuilt Windows profiles accept the ordinary Option,
Result, scalar array and static byte reference fixtures at two and reject
them at one. A catalog-backed local Result likewise returns 77 and seals
its output at two, and fails without either at one. Each profile passed
67 configured, 25 catalog and five managed project cases plus nine native
host transport cases. All 455 receipt input hashes matched.
Local receipt: `build/restricted-worker/20261121T202938733353Z/receipt.json`.

### Scalar and nominal type quota

The image admission check includes the distinct scalar and wrapper tags in
registers and ordinary return metadata, the scalar leaves of those wrappers
and of declared record fields, and each nominal record declaration. A
catalog Result counts its exact success type and its u32 error type. Void
and opaque pair markers are metadata. Reference return metadata suppresses
the scalar placeholder in the underlying IR.

For this subset the maximum is 52 identities, so policies at or above that
bound skip the scan. Smaller policies visit at most 128 register tags, 16
returns and 512 record fields, using a fixed 143-entry seen table and no
heap allocation. The check does not add a compile Fuel debit. The array and view extensions
below count additional image metadata. The host extension also counts the
verified signatures of used imports.

Both Windows profiles accept one type across the original two modules.
Two records sharing an i32 field require three identities. An ordinary
`Result<i32,bool>` also requires three, including both payload types. Both
fixtures reject at two, a quota at which the preceding /O2 image returned
42. The saved catalog Result fixture uses four identities including the
branch predicate and rejects at three without a result or sealed output.
Each profile passed 71 configured, 26 catalog and five managed project
cases plus nine native host transport cases. All 456 receipt input hashes
matched. Local receipt: `build/restricted-worker/20261121T204100875891Z/receipt.json`.

### Array type quota

Each distinct array element tag and length contributes one identity. Array
bindings with different mutability, function owners or allocation sites
share an identity when their element and length match. The scalar element
joins the same deduplicated tag set as scalar registers and record fields.
With 16 possible array sites the scan makes at most 120 pair comparisons
and allocates no heap storage.

The two same-shaped arrays and i32 require two identities. A different length,
a bool array and its bool element raise the total to five. Both Windows worker
profiles return 42 at the exact limits and reject one less with
`compile_limit`. The previous /O2 image returned 42 at both lower limits.
Each profile passed 75 configured, 26 catalog and five managed project cases
plus nine native host transport cases. All 456 receipt input hashes matched.
Local receipt: `build/restricted-worker/20261121T204937694281Z/receipt.json`.

### View type quota

Shared and exclusive slices have distinct type identities per scalar element.
Input and literal byte views share the same `ref u8[]` identity and u8 leaf.
Static text views use a separate `ref str` identity. The check reuses verified
static kinds and resolves up to 16 slice sites using existing IR metadata.
Repeated origins and allocation sites share identities without heap allocation.

Both Windows profiles admit two static byte views at a quota of three, byte
and text views at four, and shared and exclusive i32 slice views at five
including the lowered usize bounds. All three fail one below the exact
quota. An input view and a literal byte view together fit three identities,
as does a catalog worker's shared-byte entry. At two, neither worker
publishes a result or output. Each profile passed 83 configured, 27 catalog
and five managed project cases plus nine native host transport cases.
All 456 receipt input hashes matched.
Local receipt: `build/restricted-worker/20261121T210210736772Z/receipt.json`.

### Host signature type quota

The catalog-backed compiler combines its image types with the parameter and
Result identities of each import in the verifier's required-import mask.
An implicit Result still contributes the wrapper and u32 error type after
lowering projects it to its success value. Repeated calls and saved Results
share their type identities. Unused catalog rows do not spend the quota.
The check walks at most 64 imports with at most 32 parameters each and
runs before Engine publication. It shares the image scan's fixed storage
and currently adds no compile Fuel debit.

The two scalar calls to the same import fit three identities and fail at
two. Adding an unused import with distinct parameter and result types
preserves the three-type limit. The shared-byte entry fits five identities,
including u8 and its view, and fails at four with no guest result or output.
Both Windows profiles passed 83 configured, 29 catalog and five managed
project cases plus nine native host transport cases. All 456 receipt input
hashes matched.
Local receipt: `build/restricted-worker/20261121T211242201356Z/receipt.json`.

### Project compile cancellation

Configured and catalog-backed project workers probe the private input pipe at
existing compile deadline checkpoints. During that scope, a complete CANCEL
must match the session nonce, sequence, zero correlation and empty body. An
incomplete header does not block a checkpoint. The first observed stop is
latched and the probe is removed before Instance preparation. A local compile
deadline observed first keeps its existing diagnostic. A valid CANCEL unwinds
the compile and closes the worker stream without a RESULT. A broken pipe or
invalid frame fails the transport. The broker continues to own the terminal
outcome and the worker reaping window.

The native fixture queues START and CANCEL together in one pipe write before
the first compiler probe. It checks EOF and a clean exit on the configured and
catalog routes, plus EOF and exit 4 for a mismatched nonce. The checks observe
the real confined worker's stream, including absence of both RESULT and
HOST_REQUEST. Gaps between existing checkpoints still rely on the
broker's Job shutdown window.

Windows development and /O2 each passed all three compile-stop cases, 83
configured, 29 catalog and five managed project cases, and nine native host
transport cases. All 456 input hashes matched, with zero net repeat handle
change. Local receipt: `build/restricted-worker/20261121T212429068756Z/receipt.json`.

The policy-free managed project route also opens the same probe before
snapshot binding and closes it before VM execution. Its existing compiler
checkpoints can observe CANCEL even with no local deadline configured.
Windows development and /O2 passed four compile-stop cases each, including
the queued CANCEL on this managed route. Both also passed 86 configured, 32
catalog and five managed project cases, with all 456 input hashes matching.
Local receipt: `build/restricted-worker/20261121T220501954469Z/receipt.json`.

### Output authority preparation Fuel

Once independent proof succeeds, the selected output Program walks the
reachable instruction graph to determine whether its entry can emit. The
worklist follows both conditional edges and called functions, visits an
instruction at most once, and stops at the first emit. Each visit checks the
compile deadline and spends one compile Fuel unit before reading the opcode.
The verified Program retains the flag beside its input flag, so Engine
authority binding and entry queries read the cached result in constant time.

The two-member scalar project visits four instructions. Exactly four units
after the capture plan allow the compile and run to return 42. Three units
reject compilation. Windows development and /O2 each passed 84 configured, 29
catalog and five managed project cases, plus all three compile-stop cases.
All 456 receipt input hashes matched.
Local receipt: `build/restricted-worker/20261121T213249516074Z/receipt.json`.

### Catalog output authority retention

The catalog verifier records the presence of EMIT while checking each opcode
under its existing compile Fuel charge. The immutable Program stores that flag
with the required import mask. Compile authority, the worker's entry query,
and each new Instance then read the same flag without rescanning the image.
The catalog rule covers every verified instruction, including instructions
outside the selected entry's reachable graph. Each Instance still checks its
own grants.

With the host import granted and the output grant absent, `check` returns
`unavailable`. With both grants, the two-call project still fits 1,757,439
compile Fuel and returns 77 with the sealed output. Windows development and
/O2 each passed 84 configured, 30 catalog and five managed project cases.
All 456 receipt input hashes matched.
Local receipt: `build/restricted-worker/20261121T214058194194Z/receipt.json`.

### Catalog type quota Fuel

After proof, the catalog compiler prepays one 4,096-unit batch when the
configured type limit requires an explicit count. The scan visits at most 128
registers, 16 return types, 17 view positions, 64 import rows and 2,112 entries
in their signatures. Catalog proof excludes array and record layouts. The
compiler checks its deadline before and after the scan, then publishes the
Program only if the count fits. A limit at or above the conservative type
ceiling bypasses the scan and spends zero Fuel at this stage.

With a three-type quota, the two-call project fits 1,761,535 compile Fuel
and returns 77 with sealed output. At 1,761,534, compilation fails before
guest execution or output publication. Windows development and /O2 each
passed 84 configured, 32 catalog and five managed project cases. All 456
receipt input hashes matched.
Local receipt: `build/restricted-worker/20261121T214911975597Z/receipt.json`.

### Configured type quota Fuel

The configured project compiler uses the same 4,096-unit batch for a type
limit that needs an explicit count. Both scalar and shared-byte entry paths
check this after independent proof and before retaining the Program. The scan
covers verified registers, function returns, record fields, array identities
and view sites. It checks the compile deadline before and after the batch.
The conservative upper bound still allows a sufficiently high type limit to
skip the count with zero Fuel debit.

With a one-type quota, the two-module project returns 42 at 3,539,139
compile Fuel. At 3,539,138 the compiler rejects the project before execution.
Both Windows profiles passed 86 configured, 32 catalog and five managed
project cases. All 456 input hashes matched.
Local receipt: `build/restricted-worker/20261121T215712277486Z/receipt.json`.

### Literal image preparation Fuel

Configured project compilation prepays the two 16-row catalog checks
before independent image proof. Freezing the literal image also charges one
unit per literal row, one per validated UTF-8 byte, and one per copied byte.
Each UTF-8 window contains at most 259 bytes, extending a 256-byte cut to
include the rest of a scalar. The copy uses one exact allocation for up to
4,096 bytes. Fuel admission precedes the copy, and compile stop checks
surround the copy and separate the validation windows.

A 260-byte text literal crosses the first cut with a four-byte scalar
beginning at byte 255. The image admission needs 553 additional units.
At 4,781,108 units the fixture returns 77 and emits all 260 original bytes.
At 4,781,107 it returns `compile_limit` with no guest result or output.
Windows development and /O2 each passed 88 configured, 32 catalog, five
managed project and four compile-stop cases. All 456 input hashes matched.
Local receipt: `build/restricted-worker/20261121T221556387417Z/receipt.json`.

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

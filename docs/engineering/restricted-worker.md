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

The caller still needs production image and profile provisioning, broader
broker phases and aggregate budgets.
The restricted CLI remains unavailable while those pieces are built and verified.

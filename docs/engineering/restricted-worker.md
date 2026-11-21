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

The caller still needs trusted image and profile provisioning, strict payload
parsing, broker phase integration, session-level reaping and budgets. The launcher
fixture executes native test code.
The restricted CLI remains unavailable while those pieces are built and verified.

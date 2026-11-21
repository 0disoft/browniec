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

The caller still needs trusted image and profile provisioning, session
framing and correlation, the broker publication barrier, and I/O completion
and budget integration. The launcher fixture executes native test code.
The restricted CLI remains unavailable while those pieces are built and verified.

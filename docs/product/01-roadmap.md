# Roadmap

- Status: Accepted delivery sequence for design, 2026-10-23
- Current progress: no implementation milestone started

This roadmap orders learning and evidence. It is not a release promise or a claim
that any command, binary, worker, or DLL already exists.

## Guiding rules

Build the smallest real native path before expanding documents or platform support.
M0 and M1 must not wait for the Windows restricted worker or DLL milestones.

Every milestone must produce a runnable artifact, observed evidence, skipped checks,
and a short record of unresolved risk. A model or fixture does not satisfy a native gate.

## M0: native feasibility probes

Goal: prove that the smallest required Fairy native boundary is real and safe enough
to continue.

Evidence:

- actual compiler and SDK signatures used by a tiny native executable;
- fallible storage with pre-allocation failure;
- signed little-endian codec for i64 MIN/MAX and usize MAX;
- checked arithmetic for overflow-to-status paths, including i64 MIN and -1;
- quota reservation, old-plus-new peak, and rollback;
- stale generation rejection without dereferencing a dead owner;
- a short source path that does not invoke Go or a C compiler at run time.

Exit condition: the required scalar boundary is demonstrated, or the specific Fairy
capability gap is recorded with a minimal reproduction.

## M1: scalar source to native VM

Goal: run real .brc source through lexer, parser, type checking, Flow analysis,
private code generation, independent verification, and the native VM.

The first usable slice includes functions, scalar Option/Result, question-mark
propagation, shallow switch, checked arithmetic, and bounded Fuel. It produces a
small CLI path for local engineering use.

Exit condition: the same source and input produce the expected guest value through
the actual native binary. Guest nonzero is data. Compile or runtime failure returns
an explicit diagnostic and does not crash the host.

## M2: aggregates, borrows, and bytes

Goal: connect arrays, plain structs, borrows, Buffer, input, output, and UTF-8.

Required evidence includes independent array copies, complete record construction,
root conflict rejection, mutable views, returned borrows, Buffer growth and movement,
staged output, and chunked UTF-8 validation.

Exit condition: source end-to-end cases exercise normal and rejected paths without
using a Python model as the product runtime.

## M3: typed host suspension

Goal: run a fake in-memory host adapter with request and reply, grants, timeouts,
pending state, and cancellation.

No live service credential or network call is needed. Tests cover malformed replies,
allocation failure before copy, late replies, duplicate replies, Engine poisoning,
and terminal snapshot stability.

## M4: restricted Windows worker

Goal: compile and run untrusted source inside an independently tested worker.

Use actual Windows AppContainer and Job controls, private bounded IPC, a parent
broker, I/O leases, a publication barrier, and bounded cleanup. Preparation failure
must stop; it must not fall back to an unrestricted process.

Required negative cases include cancellation before late RESULT delivery, HOST_REQUEST
after cancellation, exit/EOF ordering, pending I/O completion, and output rejection.

## M5: embed and clean-machine delivery

Goal: expose the planned DLL ABI to a trusted native host and verify packaging.

The milestone must prove actual symbol export and calls, public handle validation,
clean-machine execution without developer compilers, and full startup, allocation,
latency, and artifact measurements. The current Fairy pub path is not a public C export.

## First workload experiments

Before fixing performance targets, benchmark small data validation, byte transform,
and rule-evaluation workloads. Report reuse separately from cold compile, process
startup, host serialization, and build-cache cost.

Initial unmeasured targets are:

- reused small Instance setup p95 at or below 1 ms;
- 10 KiB pure compile plus verify p95 at or below 10 ms;
- empty Instance accounted memory at or below 32 KiB;
- zero heap allocation in a warm scalar loop;
- 100 retained edit builds at or below 32 MiB for project outputs.

These targets guide measurement; they are not current results or universal guarantees.

## Stop or revise

Narrow or stop a milestone if the native boundary cannot return failures without a
trap, a stale token can be dereferenced, quotas cannot be reserved before allocation,
cancellation can publish output, or the worker cannot be isolated on the actual OS.

Do not trade away these boundaries to meet a performance target or schedule.

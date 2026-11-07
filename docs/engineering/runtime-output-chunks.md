# Resumable VM output copies

Implementation: `d929fca` (2026-11-08). The canonical output dispatcher and
[Engine step](runtime-engine-step.md) now copy at most 4096 output payload bytes
per caller-visible step, shared across all emits in that batch. An actual 1MiB
input emit therefore takes 256 copying batches instead of one contiguous 1MiB
copy. This bounds output payload work; the full R03 work contract remains open.

## Admission, progress and publication

The first EMIT visit authenticates its input/image/arena source once and charges
the existing instruction, access and whole-emit Fuel. Complete quota and Fuel
admission precede any source payload copy. A saved recipe retains source kind,
span, copied count and original error offset. The Program/input/arena and source
loan remain pinned, and the PC does not advance to another guest opcode while
that emit is incomplete.

Each continuation copies only the batch's remaining byte allowance and consumes
one dispatch visit, without charging instruction/access/emit Fuel again. A batch
can return Pending before its dispatch quantum is exhausted when 4096 bytes have
been copied. Empty emits commit once without consuming payload allowance. The
byte allowance spans multiple emits, rather than restarting at each instruction.

The reserved output transaction tracks its admitted length and physical copy
progress separately from committed output length and emit count. Only the final
chunk commits that emit. Atomic appends, another begin and sealing reject an
incomplete copy. Cancel/failure discard both committed staging and an incomplete
suffix, preserve spent Fuel and freeze the first cause. No bytes are externally
published before VM success and final sealing; effects are never replayed.

The existing standalone atomic emit API remains available. Source resolution
and the existing prices are shared. The forty-byte heap header, Published size,
output/input limits and public Fuel default 256/ceiling 16000000 are unchanged.
Transaction inline storage grows from 88 to 112 bytes; the copy recipe adds
56 bytes to the saved cursor. The exact native Machine stride is remeasured by
the existing checked pending planner, including its Vec8 minimum capacity.
There is no new resume allocation, payload snapshot or source re-evaluation.

`output_copy_progress` is guarded private Engine inspection while pending; it
reports actual cumulative and last-batch copied bytes. Terminal states no longer
retain a Machine and reject that query. These helpers do not expose public CLI
or C ABI controls.

## Native verification

Six [Engine groups](../../tools/runtime-engine/engine_output_chunk_tests.fy) and
eight [transaction groups](../../tests/m2/runtime_output_chunks.fy) pass Windows
development/O2, together with existing Engine/pending/cursor/quantum regressions:

- A real 1MiB binary input yields exactly 256 copying batches of 4096 bytes and
  one final emit, with byte-for-byte output validation.
- Fixed/mixed quanta preserve synchronous output/value/Fuel, PC/source identity
  during continuation and exact per-batch/cumulative byte counters.
- Three 3072-byte emits share each 4096-byte allowance, including partial second
  and third emits; an empty fourth emit still counts once.
- Mid-copy cancellation hides a committed prefix and incomplete suffix, refunds
  VM backing once and retains the original input owner.
- Exact run Fuel succeeds. Exact emit admission permits prepaid continuations
  at zero Fuel; one less rejects before copying even the first byte.
- Input/returned ranges, literal and arena sources, original trap/quota/range
  errors, invalid chunks, interleaved/moved transactions and frozen first causes
  retain their existing behavior.

Every Engine resume is tested with the next SDK allocation denied and zero
allocation attempts. All images exit with zero retained SDK heap. The unchanged
owning I/O and metered output suites also pass both profiles, actual generated
112-byte layout checks, ownership moves and their explicit allocation failures.
The [evidence](../evidence/runtime-output-chunks-windows-20261108.json) pins the
actual commands, artifacts, compiler/runtime and committed source identities.

## Remaining accepted work

Stats counts dispatch attempts, including prepaid copy continuations; it is not
a guest instruction counter or a universal work budget. Setup/proof, array and
record bulk operations, transfer/tag/store, CALL/RET, final seal and cleanup still
need bounded recipes. Metadata visits, deadlines, in-flight cancellation,
STOPPING/poison, public lifecycle/ABI/CLI and the accepted inventory remain open.
R03-R05 are incomplete. The 4096-byte output bound alone makes no latency or
general native-work guarantee.

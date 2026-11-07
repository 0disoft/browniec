# Private guest output execution and completion

This private successor connects source `output::emit(ref bytes);` to canonical
IR, independent verification, actual VM execution and success-only publication.
It extends the [native output transaction](runtime-io.md)
and [exact input completion](module-input-completion.md).
It is not public CLI admission or completion of the accepted full runtime.
Engine/Instance output ownership has separate native lifecycle evidence in
[the Engine successor](runtime-engine-outputs.md).

## Source to independently verified opcode 116

[The owning output Program](../../src/module_output_program.fy) separately
admits either the selected zero-argument entry or the shared-byte input entry.
It retains exact source Snapshot, lowered code, immutable image and input mode.
Legacy ordinary/input Program compilers do not acquire output admission.

[Source recognition](../../src/output_source.fy) accepts the exact unresolved
namespace spelling `output::emit`. Real functions, imported aliases and local
bindings take precedence; source metadata cannot grant emission. The private
statement requires `ref` byte-view input. Existing expression/CALL/range lowering
evaluates its receiver, endpoints and helpers once, then releases only temporary
bindings. It can observe an existing exclusive byte loan without consuming it.

[Output IR](../../src/output_ir.fy) encodes eight-byte PRIVATE EMIT 116 as
`[116, 0, site, kind, 0, 0, 0, 0]`, with `site < 16`, kind 1 for a shared byte
view and kind 2 for a live byte loan. It defines no register and neither creates
nor closes a loan. This is a separately admitted dialect, not external bytecode
loading or opcode rewriting into an otherwise trusted instruction.

`verifier::inspect_output_returns` combines the recipe/image proof with the
canonical scalar, owner, loan and control-flow proof. It checks output admission,
canonical operands/reserved bytes, current-function provenance and prior live
shared-view definitions, or a live, unsuspended byte loan and valid owner/formal
origin. Identical site numbers in another namespace confer no authority. The
VM entry independently revalidates through the same verifier; successful source
lowering alone is not its proof. These are inspected source contracts, not a
claim of a separate malformed-opcode test suite in this receipt.

## VM execution and publication barrier

`module_output_program::complete(program, snapshot, budget, output_limit, allowed)`
first rejects an output limit above 1 MiB and nonempty input for a zero-argument
Program. It preflights preparation Fuel, reserves one owning publication slot and
opens a private reserved output Transaction. The native caller supplies `allowed`;
full immutable policy/grant binding is a separate integration obligation.

The actual VM borrows this Transaction and one mutable Fuel balance through
nested calls. [Output execution](../../src/output_execution.fy) authenticates
frame/function, canonical instruction and the selected image/input/runtime-loan
provenance, then performs one contiguous append. Checked range, allowlist, byte
quota, emit count and complete copy Fuel admission precede the payload copy.
Setup reserves the full requested output capacity once; metered appends copy only
the new suffix, with no intermediate payload allocation or prefix recopy.

A VM error calls `fail`, discards staging and returns the original-source
diagnostic where available plus the actual committed remaining Fuel. Final seal
Fuel failure also discards staging. `Completion.output_bytes` is zero,
`has_output` is false and `view` is empty on failure; an earlier successful emit
never exposes its failed prefix. Emit counts may remain observable as metadata.
The transaction and its seal authority never escape this invocation.

Only real VM success followed by successful `seal_metered` transfers one immutable
`Published` owner into the already-reserved result slot. Success can publish empty
output even without a grant if no emit occurred. An empty emit is still a counted,
Fuel-priced operation and requires the grant, including at zero byte limit.
Published bytes remain independent across reuse of the retained Program and input
Snapshots. Publication here is an owning in-memory result, not sink delivery.

## Shared Fuel schedule

All output prices come from [the shared schedule](../../src/fuel.fy):

| Operation | Fuel |
| --- | --- |
| Reserve output capacity `limit` | `512 + 2 * limit` |
| Authenticate an emit source | `8192` |
| Append `length` bytes | `512 + 2 * length` |
| Seal successful output | `512` |

The VM also charges its ordinary instruction dispatch (one for EMIT) and existing
expression, CALL, input and runtime setup work. Output does not receive a second
independent execution budget. Bounds at or below 1 MiB precede output pricing;
checked sums and subtraction-based quota tests prevent overflow. Preparation and
successful append/seal debits share the actual VM balance. Prior committed debits
survive later failure; an uncommitted atomic operation does not charge its full
price. Provenance/dispatch work already performed can still consume Fuel on a
rejected emit. `Completion.remaining`, not the staging observation's output-only
charge field, is the authoritative invocation remainder. No VM replay derives
consumption, reconstructs a result or retries external effects.

## Recorded native evidence

The [executed evidence](../evidence/module-output-execution-windows-20261107.json)
records source/input identities, the original receipt hash, both native images,
compiler/runtime identities and all 39 groups in each development/O2 profile.
The reproducible command is `python tools/verify-module-output-execution.py`.

- Ten source/proof groups cover operand and reserved-byte mutation, stale and
  foreign-function views, byte-loan initialization/suspension, complete owner/
  scalar/return proof, dead blocks, once-only receiver/endpoint evaluation,
  imported-name shadowing and unchanged legacy admission.
- Seventeen execution groups cover grant denial (including empty emit), binary
  literals/text/ranges/helpers, nested void calls/loops, input/image/array loans,
  quota atomicity, prefix discard after division/range/Fuel failure, exact and
  one-less seal Fuel, independent reused owners, input/output through 1 MiB,
  wrong input mode and unchanged legacy output gates.
- Twelve regressions cover actual input completion and execution, reusable
  module Programs, returned-loan lifetimes and the unchanged complete combined
  captured-call depth 32/33 fixture.

The adapters change only test module names and visibility; each original body
executes in a separate native process. Both PE images retain default 1 MiB stack
reserve / 4 KiB commit. There are no compiler/stack overrides or VM replay.
These results cover the current integrated sources, not the earlier worker
snapshot. Engine tests separately cover retained owners and native OS guards.

## Remaining runtime and public work

The full runtime remains incomplete. This synchronous private slice does not
establish full Engine memory/work accounting, bounded steps, in-flight
cancellation, deadlines, poison containment, immutable policy/run/grant binding,
public CLI/ABI controls, binary/JSON/text sinks, restricted workers or embed
lifecycle behavior. A sink may fail after ownership publication; computation and
external effects must not be replayed. Existing public gates and existing prices,
defaults and ceilings are not promoted by this private opcode.

The older unmetered `runtime_output::open/emit/seal` API remains a trusted native
component: it recopies prefix plus suffix and accepts caller-supplied charges.
The new reserved `open_metered/emit_metered/seal_metered` path is distinct. The
Engine successor independently checks its own ownership integration.

## Retention-budget successor

[Program memory admission](runtime-engine-program-memory.md) supplies bounded
ordinary/input/output compiler entry points. Their default entry points retain
unlimited retention plans and existing behavior. The successor reruns these
39 native groups on the changed compiler wrappers in development/O2; its Engine
evidence separately checks exact image/Stored preflight and retained lifetimes.

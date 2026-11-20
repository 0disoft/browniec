# Private native host exchange coordinator

This H03/H04 source slice consumes the actual `host_catalog` and `host_wire`
modules at base `845a05623d28e9eea348500debedbe264905c5f9`. The standalone
coordinator is also used by the private scalar execution path below. The public
ABI and public host gate remain pending.

## Scalar host calls from source

The private Engine can compile a single Brownie C source with an i32
return value and the configured entry `main::main`. For example:

```text
module main;
fn i32 main() {
    return host::example::check(40 + 1) + 35;
}
```

The frontend lowers one i32 argument using the ordinary expression parser.
It resolves the canonical qualified name against the exact catalog passed to
the Engine. The import must take one i32 and declare `Result<i32,u32>`.
The resulting i32 expression receives the host success value. A host error
ends the scalar run with the existing host error diagnostic.

The private verifier checks the candidate and binds its immutable catalog
digest before Program retention. Run declarations and grants still control
admission. Each prepared Instance suspends with its own request and resumes
with its own matching response. This slice supports a single function within
the existing scalar host IR subset and its 4,096-source-byte bound.
See [direct Result switches](#guest-result-branches) for explicit error handling.

Windows development and /O2 verify one source-compiled Program reused by two
Instances. Both request i32 41 at catalog import 1. A cross-run response is
rejected, and matching replies of 42 and -7 produce 77 and 28. The verifier
also exercises unknown imports, wrong argument types, mismatched digests and
the ordinary compiler gate. Both profiles exit with zero live SDK allocations.
Root fairyc check --locked passes 377 sources and 4,206 MIR functions. The
local receipt is build/runtime-engine/20261119T085228115292Z/receipt.json.

The Engine applies policy source bytes and lexical tokens (excluding EOF),
then checks the lowered function and instruction totals and each function's
register range before retention. The native global register capacity also
applies. The same admission path backs the Windows single-source host check.

## Catalog module aliases from source

The private single-source Engine accepts imports after the module header
and before declarations:

```text
module main;
import host::example as api;
fn i32 main() {
    return api::check(40 + 1) + 35;
}
```

The compiler resolves each alias to an exact catalog module and resolves
each call to a symbol in that module. Whitespace and comments inside the
qualified path preserve its canonical identity. Unknown modules and symbols,
duplicate aliases and late imports fail compilation at original source byte
offsets. The same alias works in expressions, direct Result switches and
annotated Result bindings. The emitted import IDs still require authorization
under the retained Program's catalog digest, run declarations and grants.

Windows development and /O2 passed with zero live SDK allocations. The
aliased request selected catalog import 1, and two Instances sharing the
same Program returned 77 and 28 after their own replies. A cross-run reply
and an aliased call without a capability declaration were rejected.
Native coverage also exercised direct and stored Result handling with aliases.
Root locked check passed 377 sources and 4,266 MIR functions.
Local receipt: `build/runtime-engine/20261120T094754745682Z/receipt.json`.

## Calls from guest helper functions

The private host entry accepts scalar guest helper functions, including
forward calls and recursion. It uses the existing CALL verifier for
exact formal types, initialized arguments and continuation edges. Entry
starts at the verified `main` instruction even when a helper is declared
first. A suspended request retains its guest frame and the caller's PC,
registers and return destination in the same Instance.

CALL charges one Fuel plus one per argument at entry. Each argument
copy takes one subsequent work unit, and the callee is published once
the final argument is stored. Cancellation or expiry while copying stops
the run. The entry frame uses the existing register bank. Programs with
CALL reserve 272 bytes of metadata and 1,026 bytes per additional frame
up to the RunConfig limit. The byte reply arena ends before this suffix,
and the reservation is refunded on terminal transition or destruction.

Windows development and /O2 verified two Instances returning 77 and 28
from one Program, cross-run reply rejection, cancellation between argument
copies, and the 128-frame limit. Fixed and mixed quanta spent the same Fuel.
Both profiles ended with zero live SDK allocations. Root locked check passed
377 sources and 4,278 MIR functions.
Local receipt: `build/runtime-engine/20261120T100343560778Z/receipt.json`.

## Host Result propagation in guest helpers

A guest helper returning `Result<T,u32>` can apply postfix `?` to a
catalog Result. Success extracts the typed payload and continues. Failure
returns the unchanged u32 to the guest caller, which can handle it with
`.is_ok` or an exhaustive `switch`. The helper's success type can differ
from the operand's success type. The entry still returns i32.

```text
module main;
import host::example as api;

fn Result<i32,u32> check(i32 n) {
    let Result<i32,u32> reply = api::check(n);
    return .ok(reply? + 35);
}

fn i32 main() {
    return switch(check(41)) {
        case .ok(value): { value }
        case .err(_): { 0 }
    };
}
```

The verifier checks both cells and the exact return type at each CALL
and RETURN. The runtime copies the tag and payload to the caller before
resuming it. A Buffer payload refers to the Instance's reply arena, so
returning it across guest frames performs no second byte copy. Host
failure and cancellation retain their existing terminal paths.

Windows development and /O2 verified the helper success path returning 77,
early propagation of `u32::MAX` to the caller, and a Buffer returned across
guest frames and forwarded to a second host request. The compiler rejected
propagation from the i32 entry and an incompatible helper return type.
Both profiles exited with zero live SDK allocations.
Root locked check passed 377 sources and 4,285 MIR functions.
Local receipt: `build/runtime-engine/20261120T101449651790Z/receipt.json`.

## Catalog-typed scalar arguments from source

The same private entry accepts zero to 32 scalar arguments of the exact
catalog types and a scalar success result. The compiler resolves each
qualified source span against the catalog, uses the parameter type to lower
each expression from left to right, and checks arity before emitting the
request. An existing contiguous argument range is used directly. Otherwise
private COPY122 stages the already evaluated cells contiguously; each copy
spends one Fuel and one dispatch unit. No expression is evaluated again.

The independent host verifier still checks operand definition, exact type and
import binding before retaining the Program. Compiler binding scratch is
discarded before admission. The one-i32 fast path keeps its original
instruction and costs. Typed arguments can borrow the ordinary compiler's
checked signed negation, including i64. The ordinary verifier and public
CLI/ABI entry retain their host admission gates.

Windows development and O2 both decoded the exact source-generated
`(bool, i64, u32)` request and returned 77 with 9,999,938 Fuel remaining.
The fixture forces register staging and rejects missing, extra and mistyped
arguments before Program publication. Both Engine runs ended with zero live SDK
allocations. Root locked check passed 377 sources and 4,236 MIR functions.
Local receipt: `build/runtime-engine/20261119T203041503024Z/receipt.json`.

## Variable-length bytes from source

A `ref u8[]` catalog parameter accepts a byte literal or an explicit `ref` to
an immutable local initialized by a Buffer reply. For example:

```text
let reply = host::example::check(b"a\x00\xff");
return host::example::next(ref reply) + 35;
```

The compiler finalizes decoded literals after clearing its catalog scratch.
The private verifier checks the final ranges and the exact types before
retention. Replies use the existing Instance arena and become readable only
after installation completes. The source subset denies implicit borrowing,
copying reply owners into another local, and mutable reply locals.

Windows development and O2 passed a source-generated 1,202-byte literal
request and a reuse test with two Instances. The replies carried three bytes
and zero bytes respectively; each subsequent request forwarded its own reply
and the Instances returned 77 and 42 with zero live SDK allocations at exit.
Root locked check passed 377 sources and 4,239 MIR functions.
Local receipt: `build/runtime-engine/20261119T204125690892Z/receipt.json`.

## Verified scalar Program and execution

The private `host_program` dialect admits a single scalar function, with opcode
117 for a catalog import taking one `i32` and returning `Result<i32,u32>`.
The ordinary verifier rejects 117. Before retaining the original image, the
host verifier checks the catalog signature and uses a temporary ADD proxy to
prove control flow and register definitions independently. The proof rejects
unreachable instructions. Each required import needs a declaration and grant
under the supplied Policy. The Program retains the canonical entry and the
SHA-256 binding of its exact immutable catalog.

`create_scalar` rechecks admission, copies the catalog, checks its binding, and
materializes a private eight-byte-per-instruction image. Each execution owns a
2,656-byte header including its coordinator, program counter and 128 scalar
registers. The header is fixed for the lifetime of the resource. The standalone
coordinator keeps its 80-byte header. Its mutation entry points cannot publish,
commit or remove a scalar VM request. The caller supplies a unique nonzero run
ID, monotonic time and sampled cancellation.

A step either dispatches one instruction or installs one committed reply. The
request PC remains parked while waiting. The 14-byte request costs 15 Fuel
including dispatch, and a 12-byte reply costs 12 Fuel at acceptance. Installing
the reply and polling while waiting cost zero Fuel. Wrong run or request IDs,
malformed replies and duplicate replies preserve the outstanding transaction.
Success stores one signed `i32` in the verified destination and advances the
PC. A kind-1 reply preserves the full `u32` as a terminal host error. Fatal
replies, cancellation, deadlines and quota/Fuel exhaustion use the coordinator's
first-cause rules. Reply installation and retirement use the existing snapshot
handoff. This path has no adapter callback.

The scalar Fuel price is local to this path. The [typed host path](#typed-host-arguments) adds wider destinations and a [guest error arm](#guest-result-branches).

### Scalar verification

Program binding at `a43cff8` passed two Windows development groups. The scalar
VM composition passed five focused native groups in each Windows profile with
Fairy C preview.2 (`801c5d8caa64d19aab8925763d6bf07f65f26418`), default stacks,
and 375 hashed inputs. The selected groups cover exact catalog and grant binding,
invalid operands, the standalone fake adapter, interleaved scalar execution,
and stable host error/deadline outcomes. The `41 -> 42` path spends 29 Fuel in
total across literal, publication, reply and return. Wrong identities, malformed
replies and a second waiting poll spend zero. Root `fairyc check --locked`
passed 376 source files and 4,156 MIR functions.

| Windows profile | Native report SHA-256 |
| --- | --- |
| development | `ddbdd6722b70062b5aa745948cae4a04fda3db2777bd507fdbc4f9b11ed118ce` |
| release | `f1ba750f948689c15dd483496983cb730b4758b839539d5a82db4f060e383f04` |

The run used `fairyc test --native --capture-output --json --locked` with the
four exact `tests::m2::host_program` identities and
`tests::m2::host_exchange::fake_adapter_decodes_actual_request_and_encodes_reply_42`.
The release profile adds `--release`. The focused runner kept commands, hashes
and reports under `build/host-scalar`. Scalar allocator fault injection, public CLI,
Linux and the full native suite remain outside this verification.

## Engine-owned scalar host execution

`retain_scalar_host` accepts internal scalar IR and verifies it once under the
Engine-owned Policy before assigning a Program ID. Program release blocks new
Instances. Existing pins keep the verified Program alive through their final
destroy. `prepare_scalar_host` rechecks the run's entry, declarations, grants
and limits and opens a fresh exchange for the new Instance ID.

`step_instance` exposes `Event.kind == 4` at suspension. `scalar_host_request`
returns detached request bytes plus the Instance-scoped run ID and request ID.
`reply_scalar_host` selects the target Instance and validates both IDs against
its own exchange. Accepting the reply stages it for the next step. The normal
Engine observe, cancel and destroy paths own the terminal state and cleanup.
Run IDs are scoped to the Engine. See the [scalar run deadline](#engine-scalar-run-deadline)
for cancellation and expiry ordering.

The Instance reserves its exchange vector, fixed header, exact catalog copy and
capacity for its permitted scalar envelopes. See [pending memory accounting](#engine-scalar-pending-memory)
for the reservation and refund rules.

Windows development verification ran `python -B tools/verify-runtime-engine.py
--profile development` with Fairy C preview.2, 366 source inputs, 41 checked
transport bindings, 60 reviewed layouts and a default 1 MiB stack reserve.
One Program stays pinned by two Instances with identical request IDs and distinct
run IDs. Swapped run IDs, a wrong request ID and a malformed payload preserve
pending Fuel. The independent accepted results are `42` and `-7`. Duplicate
replies and replies to destroyed Instances reject. The last destroy releases
the Program, and the native process exits with zero live SDK allocations.

The executable SHA-256 is
`76001ff3619f81ffdf3f0ebfde7ddfc8e56488b264b10973ac4dbb56bd3e4e47`.
Root `fairyc check --locked` passed 376 sources and 4,161 MIR functions.
Windows optimized verification ran `python -B tools/verify-runtime-engine.py
--profile release` with MSVC 14.51.36231 and the default stack.
The first attempt timed out after 180 seconds while compiling the generated
Engine transport. The runner now allows 900 seconds for that optimization
step. The next build reached an admission failure in the existing configured
output fixture. Its retained module and function names had the correct lengths
but started with zero bytes. Filling local arrays before constructing the entry
binding preserves the exact names in the optimized build.

With the fix, the same Engine suite exited 0. Both crossed replies were rejected,
the two Instances returned `42` and `-7` independently, and the native heap probe
reported zero live SDK allocations after teardown. The optimized executable
SHA-256 is `204e6adbdc4f073f9731fe4682e79e7ab92332900db8faede174c494c82cd51a`. The local receipt
is `build/runtime-engine/20261118T105620621886Z/receipt.json`. This verifies the
private Engine path. Public delivery remains open.

### Typed routing metadata

`host_request_info` returns the Engine-scoped run ID, request ID, import ID,
exact payload length, and the retained catalog's SHA-256 words. An adapter
can select a registration by catalog digest and import ID before decoding
the TLV from `host_request_payload`. Metadata is detached. The payload borrow
ends before any Engine mutation. Reading either field leaves Fuel and the
exchange unchanged. Both reject after expiry or once reply receipt begins.
The accessor does not advance expiry or claim the request for dispatch.

To deliver a request, an internal adapter copies its validated TLV and then
calls `claim_host_request` with the matching routing metadata. The owner-thread
Engine authorizes one claim for the still-pending request. Crossed or stale
metadata, repeated claims, and claims at or after the deadline fail. A later
request on the same Instance starts with a fresh claim. This step changes
neither Fuel nor reply state. The caller owns dispatch and returns a typed
reply through the existing Engine path.

The owning Engine suite passed Windows development and /O2 with zero live
SDK allocations after teardown. The tests cover independent claims on two
Instances, duplicate and crossed claims, exact-deadline rejection, and a new
claim after the next byte request. The local receipt is
`build/runtime-engine/20261120T150615755033Z/receipt.json`.

Windows development and /O2 passed the owning Engine suite with zero live SDK
allocations after teardown. The suite checks distinct run IDs with the same
request ID, a 39-byte typed request, and rejection after expiry, complete reply,
or partial receipt. The local receipt is
`build/runtime-engine/20261120T145534752830Z/receipt.json`.

## In-memory adapter

The internal adapter registers an import against a host-owned Catalog. A route
retains the canonical digest, import ID and argument/result tags. Each dispatch
matches the active Instance's digest and import ID, decodes the caller's expected
request, and compares it to the entire live request before releasing the borrow.
The request and reply are each limited to 4096 wire bytes in this adapter.
The caller supplies immutable request and response bytes for this synchronous
operation. The adapter does no I/O and needs no separate copy of the request.

The adapter validates the complete response, including its Result arm, before
claiming the request. A mismatch or malformed response leaves the request
available. A successful claim leads to one response submission through the
Engine's existing receipt path. A failed submission after the claim returns an
error to the caller without automatic retry. The Engine still checks the
deadline and reply quota and publishes the result only after installation.

Windows development and /O2 both passed the owning Engine suite with zero live
SDK allocations after teardown. One verified Program returned 77 and -7 in
separate Instances through the success and guest error arms. The suite also
checks wrong catalogs and imports, mismatched request bytes, malformed reply
rejection without allocation, duplicate claims, cancellation and exact-deadline
rejection. The local receipt covers 392 hashed inputs at
`build/runtime-engine/20261120T153907045621Z/receipt.json`.

## Engine scalar pending memory

Admission charges the SDK backing for a Vec of eight Exchange slots, the
2,656-byte execution header and the initialized bytes of the catalog string
pool. The catalog clone copies these exact bytes and inherits the verified
Program's digest, so preparation needs no canonical serialization buffer.
The Engine reserves an additional 14 bytes if the run can publish a request
and another 12 bytes if a scalar reply fits the run's reply limit. Both
envelopes can be live while accepting a reply. This is a per-run reservation.
The same charge applies to the live Instance ledger and to the combined Engine
ceiling. Program pins and control storage are accounted for separately.

Completion and cancellation free the exchange and return the entire run
reservation. The terminal observation remains in the preallocated Instance
slot, which now uses an additional 120 bytes per slot on Windows x64.
A waiting Instance can also be destroyed directly. Destroying a terminal
Instance does not refund the same bytes twice. Program release and pins keep
their existing lifetime rules.

Windows development and /O2 passed `python -B tools/verify-runtime-engine.py
--profile all` under the default 1 MiB stack reserve. The fixture's exact
reservation is 63,776 bytes, including 26 bytes of envelope overlap. One byte
less rejects before any allocation attempt. The allocator probe confirms
the exact overlap peak and injects failures at all three preparation
allocations. With two waiting Instances, cancelling one refunds only its
reservation. Repeated cancel and subsequent destroy leave the peer's
reservation intact. Direct destroy of a waiting Instance and successful
completion also refund the full reservation. Both native profiles exit 0 with
zero live SDK allocations. Root `fairyc check --locked` passes 376 sources
and 4,163 MIR functions. The local receipt is
`build/runtime-engine/20261118T111819576719Z/receipt.json`.

## Termination with staged guest output

An output quota failure commits an exchange termination with its own cause and
timestamp. If a host call already happened, the terminal observation reports
that external effects may be unknown. Later cancellation preserves the failure
and the remaining Fuel.

The fixed-clock Engine test covers cancellation while waiting for a host reply,
expiry on the last chunk of a second emit, and a one-byte-short output quota.
Each failure leaves the output unavailable. The exact-fit peer publishes 8194
bytes once, with two emits and unchanged terminal Fuel and result after the
deadline. Taking the output clears the Engine's charge, and the detached result
outlives the Engine. Both Windows profiles passed with zero live SDK allocations.
The local receipt is `build/runtime-engine/20261120T174149316579Z/receipt.json`.

## Engine scalar run deadline

The Windows Engine samples interrupt time with [QueryInterruptTimePrecise](https://learn.microsoft.com/en-us/windows/win32/api/realtimeapiset/nf-realtimeapiset-queryinterrupttimeprecise).
Scalar preparation sets an absolute deadline from the admitted run limit in
milliseconds. The sample is taken before allocating the exchange. The Engine
converts the duration to 100 ns ticks and checks the addition for overflow. The Engine uses
the same clock before each scalar instruction or reply installation and at
reply and cancel entry. A waiting caller drives expiry by stepping or submitting
a reply. A read-only observation reports the last committed state, and request
export refuses expired requests without committing a state transition.

Each owner-thread checkpoint serializes competing outcomes. At the first
checkpoint that observes both cancellation and expiry, cancellation takes
precedence. A committed terminal result freezes its cause, Fuel, counters and
timestamp. A staged success reply can still expire before installation. A fatal
reply accepted before the deadline commits its host failure immediately. Expiry
produces a failed Engine event with the deadline diagnostic, retires the exchange
and returns its reservation. The Engine's host terminal timestamp uses the
Windows tick units.

Windows development and /O2 passed `python -B tools/verify-runtime-engine.py
--profile all` with MSVC 14.51.36231 and the default 1 MiB stack reserve.
The fixed-clock fixtures cover one tick before the deadline and exact expiry,
late and staged replies, a committed success and fatal reply, cancellation
precedence, expiry before the first step and timestamp overflow before allocation.
A separate fixture waits on the real Windows clock and checks the deadline cause
and timestamp. Both profiles exit 0 with zero live SDK allocations. Root
`fairyc check --locked` passes 376 sources and 4,165 MIR functions. The local
receipt is `build/runtime-engine/20261118T152530683517Z/receipt.json`.

## Typed host arguments

Private opcode 118 reads up to 32 contiguous scalar registers in catalog order
and writes one scalar success destination. Catalog tags, arity and capability
grants are checked at retention. The host verifier checks each register's
definition on every incoming path. Ordinary admission still rejects opcode 118.
The Engine exposes the pending envelope through an immutable, deadline-checked
borrow. It retains the existing detached scalar accessor for opcode 117.

The Windows development and /O2 fixture sends a 39-byte request with bool, i64
and u32 arguments. It rejects invalid arity, wrong tags and an undefined third
register. Both native profiles exit 0 with zero live SDK allocations. Root
fairyc check --locked verifies 376 sources and 4,184 MIR functions. Receipt:
build/runtime-engine/20261118T154037971398Z/receipt.json.

## Variable-length host values

Typed requests accept byte ranges alongside scalar arguments. Private opcodes 119
and 120 install an immutable literal range and read its length. A success reply
carrying bytes is copied into Instance-owned storage. The guest can inspect its
length and forward the range as another request. Admission accounts for the
literal pool, the byte arena bounded by the run's object limit, and overlapping
request and reply envelopes. Byte ranges are typed separately from scalar
registers. The byte arena is retained until the execution ends.

Windows development and /O2 pass the round trip across two Instances, including
embedded zero and non-UTF-8 bytes, six-byte and empty replies, malformed replies,
and cross-run rejection. The final values are 48 and 42 with zero live SDK
allocations. Root fairyc check --locked verifies 376 sources and 4,191 MIR
functions. Receipt is in build/runtime-engine/20261118T154919582849Z/receipt.json.

## Bounded byte reply receipt

The private Engine accepts byte success replies in pieces of at most 4,096 wire
bytes. The first piece must include the eight-byte TLV header. Its declared
length must agree with the supplied envelope total. Every piece identifies the
same run and request and supplies its exact contiguous offset. The first
successful receipt reserves the full bounded snapshot and copies just its
piece. Further pieces append without growth or retaining caller memory. The
single-call Engine reply API remains available for envelopes up to 4,096 bytes.

The receiving Exchange stays in phase 4 until the final byte, with guest
execution paused and the reply byte counter and Fuel unchanged. Completion
commits the reply once and makes it available for step-budgeted installation.
Each receipt and Engine step checks cancellation and deadline through the
existing checkpoints. Terminal cleanup discards any prefix and returns the
Instance reservation.

Windows development and /O2 verify 8,203 wire bytes received in pieces of
4,096, 4,096, 10 and 1 byte. The test rejects oversized pieces, wrong
totals, wrong runs and duplicate or skipped offsets. Allocation failure
on the first piece preserves the original request. Continuations allocate
nothing. A cancelled Instance and an expired peer both discard their
prefixes, preserve uncharged Fuel and reply counters, and release their
reservations. The complete reply reaches the next guest request byte for
byte. Both profiles exit with zero live SDK allocations. Root fairyc
check --locked verifies 376 sources and 4,199 MIR functions. The local
receipt is build/runtime-engine/20261118T180948817537Z/receipt.json.

## Compact and empty reply receipt

The private Engine uses the same 4,096-wire-byte receipt path for scalar and
byte-range successes, host Result errors, and empty fatal replies. Each piece
identifies the Instance, run, request and reply kind. A nonempty envelope starts
with the complete eight-byte TLV header, even when its body is empty. Later
pieces must match the kind, declared total and exact next offset. Compact
scalar bodies are validated before the final piece is appended. Invalid values
leave the retained prefix available for a corrected piece.

The guest stays paused until receipt completes. Completion charges reply Fuel
and the byte counter once. The next step installs the scalar or selects the
Result arm. An empty byte-range success uses an eight-byte envelope. An empty
fatal reply uses zero wire bytes and completes in one call. The same deadline
checkpoint runs before accepting that call. Cancellation and expiry discard the
prefix and release the Instance reservation.

Windows development and /O2 pass fragmented i32 success and u32 Result
error replies, empty byte success, and zero-byte fatal replies. Cancellation and
deadline expiry before the final i32 fragment or before submitting an empty
fatal reply leave the guest result, reply byte count and Fuel unchanged. Both
stop paths return the Instance reservation. Both profiles exit with zero live SDK
allocations. Root fairyc check --locked passes 376 sources and 4,200 MIR
functions. The local receipt is
build/runtime-engine/20261118T190054125071Z/receipt.json.

## Resumable byte reply installation

Complete receipt validates the wire envelope and charges its Fuel once.
Installation spends one unit of the Engine step allowance per byte copied into the preallocated arena, up to 4,096 bytes per step. An empty reply
uses one work unit. Guest instructions and other reply installations use one
unit each from the same allowance.

While a copy is pending, the reply stays in phase 2 and the guest PC, destination
register and committed arena end stay unchanged. The final chunk publishes the
range and advances the PC together. Each chunk starts at the existing
cancellation and deadline checkpoint. If either ends the run, the Engine drops
the reply and arena and refunds their reservation.

Windows development and /O2 verify an 8,195-byte reply with step allowances
of 1, 4,096, 4,096, 1 and 1. The following guest request gets the exact
reply bytes only after installation completes. Two peers stop mid-copy,
one by cancellation and one by deadline. Neither emits a following
request. Fuel stays fixed during copying, no allocation is attempted,
and the stopped Instances return their reservations. Both profiles exit
with zero live SDK allocations. Root fairyc check --locked verifies
376 sources and 4,194 MIR functions. Receipt is in build/runtime-engine/20261118T164215423735Z/receipt.json.

## Guest Result branches

Private opcode 121 binds a typed host call to two successors. A success
reply defines only the catalog-typed success register and falls through.
A kind-1 reply defines only the u32 error register and transfers control
to a verified forward error target. The verifier merges independent
register definitions on both edges. A kind-2 reply is a terminal host
failure. The Engine continues to validate reply identity and deadline
before acceptance and to enforce the existing Fuel and storage limits.

Private source accepts a direct host call as the subject of a `switch`
statement or expression. Both `.ok(payload)` and `.err(code)` are required,
in either order. The arms bind only their own payload, and a switch expression
joins continuing scalar values using independently verified slot accesses.
Each source call uses the same request and reply charges as opcode 121.
Control flow instructions spend their regular one-Fuel dispatch charge.
See [host Result propagation in guest helpers](#host-result-propagation-in-guest-helpers). Public delivery remains open.

An annotated immutable local such as
`let Result<i32,u32> reply = host::example::check(41);` retains the full
reply for later `.is_ok` or an exhaustive `switch`. The annotation must
match the catalog, including `Result<brownie::bytes::Buffer,u32>` for byte
success. Ordinary argument and return operands cannot read the private
storage cells. A projection checks the selected variant before reading its
payload. Byte success installs the tag and range together after the last
copy, while a recoverable error retains only its u32 value. The call is
issued once even when the local is inspected more than once.

Windows development and O2 verified saved scalar and Buffer replies, including
error payload forwarding, rejection of a mismatched annotation and a raw read
of an opaque payload cell, and byte installation with one-unit steps. Both
profiles ended with zero live SDK allocations. Root locked check passed 377
sources and 4,259 MIR functions.
Local receipt: `build/runtime-engine/20261119T210640288629Z/receipt.json`.

Windows development and O2 verified both source forms and both arm orders.
The success arm returned 77. The error arm forwarded `u32::MAX` as a typed
host argument and returned -7 after the second reply. Duplicate arms and
cross-arm binding access were rejected before Program registration. Both
profiles ended with zero live SDK allocations. Root locked check passed
377 sources and 4,247 MIR functions.
Local receipt: `build/runtime-engine/20261119T205223989971Z/receipt.json`.

Windows development and /O2 verify a successful reply, forwarding
u32::MAX from the error arm, and fatal host termination. Wrong arity,
an illegal error target and a read of the other arm's register are
rejected before execution. Both profiles exit 0 with zero live SDK
allocations. Root fairyc check --locked verifies 376 sources and 4,193
MIR functions. Receipt is in build/runtime-engine/20261118T155705204963Z/receipt.json.

## Standalone coordinator ownership and API

`create(Catalog, grants, Limits, run, fuel, deadline) -> Result<Exchange, Error>`
moves the admitted Catalog into a resource with private fields. It retains the
canonical SHA-256 binding, independent decoded catalog, explicit per-import host
allowlist, fixed private state header and owned request/reply Buffers. Metadata
does not grant access: callers must explicitly allow each import. This allowlist
does not replace future policy/declaration/capability grant validation. The native
owner must supply a unique nonzero run ID, monotonic time and trusted charges.

`begin(exchange, import_id, wire_payload, snapshot_fuel, adapter_cost, now, cancel)`
validates the exact catalog signature and whole envelope before snapshot/publication.
IDs start at one, increase only on successful publication, and terminate before
wrap. One request may wait at a time. Detached observations and binding words
are copies; they cannot forge or rewind the private authority.

`request_bytes` returns an immutable view only while Waiting; `request_fields`
decodes checked offsets against that same owned storage. Polling, invalid replies
and preparation OOM preserve the snapshot. Valid commit/cancellation retire it.
The type checker rejects replacement while an externally borrowed view is live.

`reply(exchange, run, request, kind, payload, snapshot_fuel, now, cancel)` applies
the first-cause checkpoint before identity, shape and signature checks. Success,
u32 source error and empty fatal use the actual typed decoder. Malformed replies,
wrong IDs, wrong runs and allocation failures retain pending bytes/Fuel/counters.
Valid success/error snapshots consume the request once and enter Install; duplicate
or late submissions cannot recopy or recharge. Fatal consumes the request and
selects HostFailure. `take_reply` moves the single owned TLV snapshot into Output
and returns to Ready, with no payload recopy or extra charge. Typed VM destination
installation is still required by the future integrating owner.

`output_field`, `output_kind`, `output_run`, `output_request`, `output_bytes`
inspect the private Output resource. Byte views retain Output, which can outlive
the input array, cancelled coordinator and coordinator destruction.

Phase codes: Ready=0, Waiting=1, Install=2, Terminal=3. Cause codes: None=0,
Cancelled=1, Deadline=2, HostFailure=3, Quota=4, Fuel=5, Identity=6. Native enum
comparisons are unavailable in the pinned compiler, so observations use u8 codes.
`poll` is a checkpoint, not a VM step. Cancel wins over a simultaneously sampled
deadline; any previously selected cause wins over both. Terminal state, timestamp,
Fuel and counters freeze. External effects are unknown after a published request
when terminated. Cancellation never asserts rollback or exactly-once execution.
There are no adapter callbacks, source replay, automatic resubmission or retries.

## Bounds and preparation

Limits separately bound per-message request/reply bytes, cumulative bytes, call
count, per-call adapter cost and cumulative adapter cost. Complete envelopes,
including all headers, are charged; each message is at most 1 MiB. Subtraction
checks precede addition. Policy/Fuel exhaustion is terminal and retains the first
cause; invalid message/type/identity is an API rejection. Preparation first reserves
the complete Buffer; failed preparation drops unpublished storage and preserves
all observations. This synchronous transaction charges the owner-supplied cost
once at publication. No existing Fuel schedule is changed or claimed connected.

Copies and catalog operations are bounded by envelope/schema limits, but have no
resumable chunks or mid-copy deadline checks. This does not establish R03 per-step
work-unit, allocator latency or quantum invariance guarantees. All nonfatal replies,
including scalar and empty-byte headers, currently use owned TLV Buffers; the
accepted compact-inline optimization is not implemented. Full Engine/Instance
memory accounting, typed owner reservations and prepaid cleanup remain separate.

## Pinned compiler ownership seam

The pinned compiler cannot mutate/project nested owning resource fields. The
coordinator therefore privately owns an 80-byte fixed header and stores scalar
state there. Its header pointer is captured from its own Buffer and never escapes;
that Buffer is never grown or replaced. No source-facing state struct is authority.

`replace_buffer` moves exactly one native Buffer owner record through exclusive
whole-owner byte views and zeroes the source record. Nonallocating SDK `reserve(0)`
companion calls then validate the destination, emptied source and removed owner
before whole-resource moves/cleanup. No memcpy/memset foreign symbols are added. For this Windows x64 compiler,
Buffer is four pointer-width cells, **32 bytes**, with data/capacity/alignment/length
at 0/8/16/24; Exchange backing/header/header_data/catalog start at 0/32/64/72, and Exchange
is 7,632 bytes. One backing alternates request and reply ownership. The verifier emits
actual C from the pinned compiler, asserts these sizes/offsets at compile time and
runtime, and executes the actual maximum-ID transition through a private C test
hook. The hook is generated under build only and is absent from production APIs.
The all-zero source is the SDK empty Buffer representation, accepted by its normal
cleanup. Instrumented allocator runs require zero live allocations at process exit,
including repeated handoff, cancellation and empty-source cleanup.

The earlier unvalidated raw-loop implementation passed development but reproduced
optimized native access violation/heap corruption (`C0000005` / `C0000374`), also
seen by main's independent composed grant/exchange check. The request/reply-42 and
1 MiB lifetime tests are the regressions. The corrected path uses one backing and
explicit SDK companion validation boundaries before ownership moves/drops; it does
not change compiler flags or stacks. A separate negative control removes only those three SDK validation calls and
reproduces the release heap corruption in the same request/reply-42 test. This
isolates an optimized raw-metadata visibility/ownership problem; it is not evidence of a general Catalog move defect.
The previously attempted libc memcpy/memset alternative was rejected by pinned
native linkage and is absent from the final production source.

## Verification and delivery

Run `python tools/verify-host-exchange.py --profile all`. Only ignored build output
and its mirror locks change. Each run retains byte-identical dependency sources,
tests, commands, native reports, pinned compiler identity, emitted C, executable
layout assertions, exact pinned runtime Git objects and SHA-256 input/artifact
hashes. `build/host-exchange/latest.json` identifies the latest complete receipt.
Normal native runs use default stacks and no overrides. `--native-from` can reuse
current-session normal reports only after compiler/dependency/test/report hash
checks; it reruns all layout, negative-control and allocator seams. Two separately labelled
explicit `cl /FI` allocator seam cases reuse the existing heap probe (no
CL/_CL_/LINK environment or /STACK overrides): real request
and reply allocation failures, explicit same-byte resubmission, no hidden retry,
unchanged pending/Fuel/counters and zero live allocations. Negative compiler cases
reject private-field mutation, private state publication and live-view replacement.

The bounded suite covers real fake-adapter request/reply 42, catalog/request/output
lifetimes, duplicate/late/wrong-run/ID, malformed/truncated/reserved/type/kind replies,
u32 error/fatal, cancellation/deadline ordering, frozen terminal observation,
quotas/Fuel/adapter totals and actual 1 MiB envelopes. It does not execute a VM host
opcode, Engine lifecycle, public CLI, DLL, broker, worker isolation or network host.

The worker changes only the named new files in an ignored archive mirror. Its
patch excludes mirror locks, generated hooks, build artifacts and all existing
source files. Root integration, root lock refresh and public promotion belong to
main. The design ZIP was read as reference only: SHA-256
`9786d2d2a0d0cd9048a47d17f6fd5c4574cdbcaeec00d17570602fa541b7dc5e`,
especially docs 04/08/16/17; no package instructions were executed.

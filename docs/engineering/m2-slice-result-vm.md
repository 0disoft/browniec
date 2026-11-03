# Private returned-view VM integration

The first integration slice adds invocation-private result destinations and
bounded VM frame/site bindings in `slice_result_frames`. Native Call receipts
use flat fixed columns: the adopted Fairy C toolchain does not admit mutating
array fields whose element records themselves contain fixed arrays.

Each frame records its caller continuation, CALL argument map and logical result
identity. Preparation stores a ticket outside scalar registers. Native handoff
must succeed before pop installs the fresh ticket in the caller destination and
updates named actuals from resumed tickets. Pop clears the consumed callee's
result/site bindings. A forward consumes the inner receipt through the outer
transaction; intermediate results never escape to a native client.

## Executable private dialect

`vm::run_slice_result` independently checks the complete immutable preparation
unit, then starts one chosen borrowed-result function with native Capture inputs.
It does not run the ordinary source entry point. Parallel scalar input cells use
formal argument order, with zero placeholders for borrowed inputs and absent
Capture tickets for scalar inputs. Scalar inputs admit the six scalar types;
bool cells must be zero/one. Tagged scalar formal inputs are gated.

The bounded iterative VM executes op63 preparation, op64 forwarded CALL and op65
handoff/return. Returned tickets occupy private logical destinations, never guest
scalar registers. Named actuals regain fresh resumed tickets. Selected mutable
parents remain suspended; forwarding transfers through the outer Call transaction
and invalidates intermediate receipts. The result is a native Returned receipt,
whose Held value must be closed using the existing runtime API.

Scalar arithmetic shares `vm_execution::scalar` with the ordinary VM. Branches,
loops, lexical shared subviews, mutable BEGIN/END, slice reads/writes/length and
UTF-8 run on the canonical invocation metadata and original external payload.
The proved cleanup-only recipe after preparation defers physical CLOSE/END to
the atomic handoff. Other lexical exits perform their ordinary loan cleanup.

This first dialect rejects any owned array/record site, owned-root slice, ordinary
CALL or tagged scalar formal before entering. Consequently guest-owned temporary
argument creation/drop and mixed owned CALL cleanup are not integrated. Native
Capture close/drop flags can still retain an external selected temporary root;
the existing native runtime owns that lifetime. General result locals/expressions,
argument use, direct return-range syntax and Static remain gated.

## Failure and Fuel boundary

Admission/initial-enter failure leaves caller metadata unchanged. After enter,
any execution failure ends this entire native invocation: zero-Fuel abort drains
its authority/pool/owner metadata, preserving the original error and prior payload
writes. No Held receipt escapes on failure. The supplied State is invocation-owned;
its input owners must not be reused after such a terminal failure.

Private entry/forward/return use the provisional `80 * 65537` native transaction
reserve. Each dispatched instruction costs one in addition; slice metadata/read/
write cost 65537/4097 and UTF-8 costs a conservative 81921. Deferred recipe cleanup
uses the transaction reserve rather than performing a second physical release.
This budget exceeds the public one-million Fuel cap and is not a public price
contract. Result close separately needs its existing native charge; abort is the
zero-execution-Fuel terminal path.

Public source compilation, ordinary VM opcode admission, capability flags, profile
names and public prices/Fuel limits remain unchanged. This is not public source
returned-reference support, Engine/Instance integration or a C ABI.

## Initial verification

Windows development passed nine native VM groups: twelve direct scalar/access
roundtrips, branches/loops/subviews, reordered forwarding, grounded recursion and
depth exhaustion, Fuel failure with retained writes/first offset, malformed result
identity, returned descendants, UTF-8/scoped aliases/empty views and initial gates.
The frame component separately passed two native development groups.
Final reproducible development/release verification is recorded separately.

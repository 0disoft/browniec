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
The proved cleanup-only recipe after preparation defers physical CLOSE/END/DROP
to atomic handoff, including callee-owned root cleanup. Other lexical exits perform their ordinary loan cleanup.

The [owned-array increment](m2-slice-result-owned-vm.md), implemented at `5cccbd3`,
now admits owned locals, temporary repeated arrays and owned CALL results,
scalar/array ordinary CALLs and owned argument copies. The
[record successor](m2-slice-result-record-vm.md) adds record sites and mixed CALLs.
The [explicit native entry](m2-slice-result-entry.md) now accepts owned arguments;
the legacy entry stays scalar/borrowed-only. Source results still require the independently
proved borrowed input origin: callee-local/by-value/temporary roots cannot escape.
General result locals/expressions/argument use, direct return-range syntax and
Static remain gated.

## Failure and Fuel boundary

Admission/initial-enter failure leaves caller metadata unchanged. After enter,
any execution failure ends this entire native invocation: zero-Fuel abort drains
its authority/pool/owner metadata, preserving the original error and prior payload
writes. No Held receipt escapes on failure. The supplied State is invocation-owned;
its input owners must not be reused after such a terminal failure.

Private entry/forward/return use the provisional `80 * 65537` native transaction
reserve. Each dispatched instruction costs one in addition; SUBSLICE/CLOSE/BEGIN/
END cost 65537, LEN/READ/WRITE cost 4097 and UTF-8 costs a conservative 81921. Deferred recipe cleanup
uses the transaction reserve rather than performing a second physical release.
This budget exceeds the public one-million Fuel cap and is not a public price
contract. Result close separately needs its existing native charge; abort is the
zero-execution-Fuel terminal path.

Public source compilation, ordinary VM opcode admission, capability flags, profile
names and public prices/Fuel limits remain unchanged. This is not public source
returned-reference support, Engine/Instance integration or a C ABI.

## Initial rootless increment verification

The owned-array increment has its own verification record linked above.

Final Windows development and release each passed **11 native groups and 2,215
CLI cases**, with 485 matching source/tool/fixture input hashes and no final native
result reuse. Native groups comprise two frame groups and nine instruction-loop
VM groups: twelve scalar/access roundtrips, branches/loops/subviews, reordered
forwarding, grounded recursion/depth exhaustion, Fuel failure with retained writes
and first offset, malformed identities, returned descendants, UTF-8/scoped aliases/
empty views and initial admission gates. Mutable loop children END before parent
reuse; terminal cleanup is performed once by handoff.

CLI coverage per profile is 2,007 M1, 88 borrowed-result rejection and 120 temporary
array borrow cases. Retained reports, CLI artifacts, compiler and every input were
rechecked. All production files match `af4aa13` under Git LF. The final test-only
mutable-loop strengthening and new verification harness are included in both
snapshots. See [Windows evidence](../evidence/m2-slice-result-vm-windows-20261104.json).

The first development M1 audit exposed a pre-existing native stack regression:
32 nested scalar calls also overflowed in the retained prior runtime artifact.
`af4aa13` splits scalar-only argument parsing away from aggregate capture parsing,
removing its 64-binding lexical snapshot. Existing depth-32 check/run cases now
succeed, while 33/64 produce the original compile limit. Both final profiles rerun
all checks after this fix; pre-fix results are not reused as final evidence.

To reproduce:

```text
python3 tools/verify-m2-slice-result-vm.py --profile development
python3 tools/verify-m2-slice-result-vm.py --profile release
```

Full native M1/other M2 suites, Linux, OS isolation, ABI, packaging, allocator
instrumentation and native size/stack-usage/timing were not verified. Local only;
no push, release or deployment. Public returned-reference promotion remains gated.

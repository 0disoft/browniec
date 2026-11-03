# Record CALL and local ownership in the private returned-view VM

Implementation: `e01a9b1`; shared byte-view adapters: `bcd56f4`.

This increment extends `vm::run_slice_result` with the existing nominal scalar
and nested-record operations and ordinary record value parameters/results. It
continues the [owned-array integration](m2-slice-result-owned-vm.md); no public
returned-reference source syntax, capability, opcode, price or Fuel cap changes.
Initial native entry still accepts scalar cells and borrowed captures only.
Admission explicitly rejects array/record parameter descriptors before creating
any Call, including parameters whose IR scalar slot is a placeholder.

## Shared storage and identities

Each private frame now has a record token map beside its array token map. Both
maps address Runtime's one sixteen-slot owner table and original payload arena.
The private record registry retains at most sixteen exact-generation tokens and
locations, indexed by owner slot, instead of a permanent 512-token frame map.
It owns no additional payload. Frame push/pop clears the relevant locations,
preventing stale tokens from surviving recursion or lexical site reuse. The
existing full compatibility map is expanded only during record operations/result
validation. Frame initialization also occurs after independent admission, outside
its verification call stack.

Raw byte-view adapters in `struct_vm` and `struct_result_vm` execute the same
record create/copy/read/write/drop/assign/subassign/replace/subreplace and result
validation used by the public Buffer entry points. Buffer wrappers delegate to
these adapters. No backing Buffer, second owner table or full payload copy is
introduced by dispatch.

## CALL and owned return

`runtime::enter_records` stages borrowed authority and the complete mixed
array/record value-copy batch in one metadata transaction. The existing
`owners::copy_call_arguments` validates nominal layouts, nested bools and all
reservations before writing any destination bytes. Failed bool validation or a
later quota reservation leaves the original owner table, writer ticket and
payload unchanged. Arrays-only calls retain their prior path and charges.

Mixed calls prepay the existing `struct_call_vm::cost` in addition to the private
transaction reserve. Value parameters copy independently of the source. SRET
validates the unique remaining record, nominal destination and absence of other
array/record locals before ordinary Call restoration. It then moves the same
token into the caller's dead record destination and consumes the child map.
There is no result payload copy or result allocation. Scalar and array returns
also require that all record locals have been dropped.

## Borrowed return and failure

After PREPARE_VIEW/PREPARE_FORWARD, proved terminal SDROP is deferred alongside
array DROP and loan CLOSE/END. The adapter compacts both maps into at most sixteen
live roots and passes them to `handoff_roots`. Record cleanup, loan restoration
and selected-result installation therefore publish together. A duplicate local
root that fails after a staged release rolls the entire metadata transaction back.

Once native entry succeeds, any terminal failure drains the invocation's shared
owner/loan/authority metadata at zero Fuel while preserving the first error and
earlier payload writes. Admission/initial-entry failure preserves native inputs.
Source-origin proof continues to forbid local/value/temporary roots escaping as
borrowed results.

## Verification and remaining gates

Final Windows development and release each passed **58 native groups and 506
CLI cases**, with 494 matching input hashes and no final result reuse. All
110 production sources match `e01a9b1` under Git LF. Both final profiles start
at that implementation commit and retain their fresh native phase receipts.
Early dense-map stack failures and preliminary probes are superseded, excluded
from final results and replaced by fresh profile runs without stack/compiler
overrides. See [Windows evidence](../evidence/m2-slice-result-record-vm-windows-20261104.json).
CLI scope is 88 borrowed-result rejections, 120 temporary-array borrow cases,
144 record return-constructor cases and 154 record constructor-argument cases.

The focused verifier runs the prior returned-view/owned-array native groups,
record function/result adapter regressions and the new record VM/runtime checks.
The no-copy test uses exactly 20 payload bytes: 16 for the borrowed input and 4
for its helper's record result. Mixed-batch tests cover a later quota failure,
invalid bool storage, independent value copies and writer restoration.
Other cases cover six scalar record fields, nested record mutation, recursive
results, lexical reuse, deferred cleanup, Fuel/quota/arithmetic failures and
first-error/write retention.

```text
python3 tools/verify-m2-slice-result-record-vm.py --profile development
python3 tools/verify-m2-slice-result-record-vm.py --profile release
```

The verifier also supports `--phase native` followed by `--phase cli`. Native
phases can run per profile in parallel; CLI phases run sequentially because they
share the root build artifact. CLI continuation rechecks all input/compiler and
report hashes against the retained fresh native receipt. Failed native stdout
is retained as diagnostic evidence; it never qualifies for continuation.

Native owned entry arrays/records, general returned-reference source bindings,
Static and public promotion remain gated. The provisional private reserve remains
`80 * 65537`; public metering needs reconciliation before promotion. Full M1/
other M2 suites, Linux, isolation, ABI, packaging, allocator instrumentation and
native size/stack/timing are outside this increment's verification scope.

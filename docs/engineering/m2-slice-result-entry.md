# Native owned inputs for the private returned-view VM

Implementation: `8bf37de`.

`vm::run_slice_result_owned` accepts native array and nominal record value
arguments together with scalar cells and borrowed captures. It extends the
[record ownership integration](m2-slice-result-record-vm.md). Public compilation,
capabilities, Program layout, instruction prices and the public Fuel cap stay
unchanged. The existing `run_slice_result` entry remains scalar/borrowed-only.

## Explicit formal-indexed inputs

The private native signature adds `ref owners::Token[] inputs` after `values`.
The vector has the function's arity; an empty vector preserves legacy entry.
Admission independently verifies the complete private unit before reading its
formal mappings. Every position must match the checked declaration:

| Formal | Scalar cell | Owned token | Capture |
| --- | --- | --- | --- |
| Scalar | Exact type/range, including canonical bool | Exact `(0,0)` | None |
| Borrowed slice | Zero | Exact `(0,0)` | Live, exact element/access |
| Owned array | Zero | Live, exact element/length | None |
| Owned record | Zero | Live, exact nominal record | None |

Wrong vector length, misplaced/dead tokens and nonzero aggregate placeholder
cells reject before entry. Runtime validates capture flags, source generations,
owner access, layouts and bool encodings. Native records must be constructed
against the admitted unit's record layout catalog in this invocation's table;
this is not a cross-unit nominal identity or public C ABI contract.

## One initial transaction

The adapter derives a dense aggregate batch from the admitted formal mappings,
prepays `runtime::cost() + struct_call_vm::cost(...)`, and uses the existing
`runtime::enter_records` transaction. All borrowed authority and all native
array/record value copies stage together. Source/type/bool and every reservation
check finish before the first payload write. No second Runtime clone, owner
table or backing Buffer is introduced.

The initial frame binds copied tokens in formal order. Ordinary CALLs, array/
record results and borrowed forwarding then use the existing execution paths.
Array-only and mixed arguments follow the same language value semantics: repeated
source tokens produce independent copies. Shared sources may also be copied;
exclusive sources reject. Native input payload/owner capacity must accommodate
the originals and their guest copies together.

Value copying does not consume source tokens. Successful handoff drops guest
copies with other callee roots, leaving native originals available to their
caller. Borrowed Capture flags still govern any aliased root's retention/drop.
Callers release retained native roots explicitly after their outstanding loans
end. A borrowed result still needs its independently proved borrowed input
origin; a by-value array/record parameter cannot become an escaping result.

## Failure boundary

Admission, initial Fuel, capture, owner, encoding, owner-slot or quota failure
preserves native owner/pool metadata and every payload byte. There is no guest
execution or abort on these paths. A late reservation failure therefore cannot
publish an earlier copy or rotated writer ticket.

After initial entry commits, terminal VM failure aborts the whole invocation at
zero execution Fuel, including native original owners and guest copies. Earlier
payload writes and the first error remain. Native input tokens must not be reused
after this boundary; it is the existing invocation failure contract, not a new
transactional rollback of guest effects. Error kind alone does not identify
which boundary was crossed; native callers revalidate source tokens before
reuse after any error.

## Focused verification

Final Windows development and release each passed **30 native groups and 208 CLI
cases**, with 497 matching input hashes. All 111 production files match
`8bf37de` under Git LF. The development entry batch began before this commit
with identical final inputs; its original HEAD is retained. Both profiles use
fresh native batches without historical result reuse or stack/compiler overrides.
CLI scope is 88 borrowed-result rejection and 120 temporary-array borrow cases.
See [Windows evidence](../evidence/m2-slice-result-entry-windows-20261104.json).

The verifier separates seven new entry groups from 23 existing private VM,
temporary-array and record CALL groups. Each saved batch records its original
HEAD and input/compiler/report hashes. CLI continuation requires identical
inputs and fresh successful batch receipts; native failures invalidate that
batch's continuation receipt and retain diagnostic stdout.

```text
python3 tools/verify-m2-slice-result-entry.py --profile development --batch entry
python3 tools/verify-m2-slice-result-entry.py --profile development --batch regression
python3 tools/verify-m2-slice-result-entry.py --profile development --batch cli
```

Use the same three batches for release. Native profile batches may run in
parallel; serialize CLI batches because they share the root build artifact.
`--batch all` runs a complete profile sequentially.

Public metering and general returned-reference source admission remain pending.
The provisional private reserve stays `80 * 65537`. Full M1/other M2 suites,
Linux, isolation, ABI, packaging, allocator instrumentation and native size/
stack/timing are outside this increment's verification scope.

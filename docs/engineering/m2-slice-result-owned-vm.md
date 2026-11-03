# Owned arrays and ordinary CALLs in the private returned-view VM

This increment extends `vm::run_slice_result` with owned array locals, temporary
array borrow arguments, and ordinary scalar/array CALLs. Initial native entry is
still a borrowed-result function with scalar/borrowed inputs. Records, native
owned entry arguments, general returned-reference locals/arguments, Static and
public source/capability promotion remain gated.

The [record successor](m2-slice-result-record-vm.md) now connects record locals
and scalar/array/record CALLs. The record gate above describes this earlier slice.
Native owned entry inputs and public promotion remain pending.

## One owner table and original backing

Each private VM frame now maps array catalog sites to owner tokens. Array
creation/copy/read/write/fill/assignment/drop, UTF-8 ranges, owned argument copies
and array-result validation reuse the existing array VM operations through raw
byte-view adapters. The public Buffer entry points delegate to those same
operations. No temporary backing Buffer or second authoritative owner table is
created. Local array-state copies are unpublished metadata plans only.

An array value argument copies its payload according to existing value semantics.
ARET validates the sole retained result and moves its token into the caller's dead
destination; it does not copy that result payload. Frame pop consumes the callee
token map. Repeated factory CALLs and temporary captures can therefore reclaim
and reuse owner slots without resurrecting stale tokens.

## CALL publication and ordinary return

`runtime::enter_arrays` stages canonical borrowed authority and owned argument
reservation/copy in one transaction. All source, quota and reservation checks
precede the first owned-argument byte copy. No fallible payload operation follows
successful copying. The returned Call/Copies receipts are bound to prevalidated
caller/callee sites before guest execution resumes.

The adapter deliberately does not stage an entire Runtime and then call a second
staging transaction. That duplicate metadata copy overflowed the Windows native
development stack during integration. The single-plan entry passes both ordinary
forwarding and owned argument/result cases without changing stack configuration.

Ordinary CALL supports scalar and array returns, including mixed scalar, owned
array, readonly slice and mutable slice inputs. Formal CLOSE ends the logical
site; the Call transaction retains its physical session until restoration.
`leave_call` unwinds lexical children, restores writers, closes callee-created
readers and returns fresh caller tickets. Source cleanup closes local independent
views and drops local owners. Ordinary frames never publish a Held result.

## Borrowed return with owned temporaries

Inline repeated arrays and owned CALL results are initialized/moved before OPEN.
Endpoint and later argument evaluation reuse the same VM, so bounds, arithmetic,
Fuel or quota failure drains all invocation owners/loans and preserves earlier
writes and the original error.

After op63/op64 prepares a borrowed result, the independently checked terminal
recipe defers CLOSE/END/DROP to `handoff_roots`. It unwinds callee descendants,
restores the Call, installs the selected result, closes remaining callee-owned
views and releases their roots before publishing any metadata. A failed local
cleanup rolls back the whole handoff. Local-root input cannot name a borrowed
formal's owner. A local/by-value/temporary root still cannot escape as a function
result: the existing single-input origin proof rejects it before execution.

The provisional private transaction reserve remains `80 * 65537`. Existing owned
instruction/copy/result charges are also applied. Public prices and the public
one-million Fuel cap are unchanged; public metering still needs reconciliation.


## Verification

Final Windows development and release each passed **33 native groups and 2,215
CLI cases**, with 489 matching input hashes and no final native result reuse.
The native groups include all 12 prior transaction groups, three new runtime
groups, two frame groups, nine existing VM groups and seven owned-array VM groups.
They cover six temporary scalar/access modes, factory/range evaluation, ordinary
writer restoration and recursion, value-copy independence, token-moving returns,
lexical owner-slot reuse, argument bounds/arithmetic failure, quota/Fuel failure
and zero-Fuel cleanup with retained writes. Existing range UTF-8 semantics also run
through the shared byte-view adapter.

CLI scope per profile is 2,007 M1, 88 borrowed-result rejections and 120 temporary
array borrow cases. Every input/compiler/report/artifact hash was rechecked, and
all 108 production files match `5cccbd3` under Git LF. Development started at
`9be6c7e` before the implementation commit, with identical final recorded inputs;
its original HEAD remains explicit. Early stack-failure probes are superseded and
are not reused as final native evidence. See
[Windows evidence](../evidence/m2-slice-result-owned-vm-windows-20261104.json).

```text
python3 tools/verify-m2-slice-result-owned-vm.py --profile development
python3 tools/verify-m2-slice-result-owned-vm.py --profile release
```

Full native M1/other M2 suites, Linux, OS isolation, ABI, packaging, allocator
instrumentation and native size/stack-usage/timing were not verified. Local only;
no push, release or deployment.

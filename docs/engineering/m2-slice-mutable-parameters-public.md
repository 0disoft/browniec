# Public mutable scalar-slice parameters

Public `check` and `run` admit `ref mut Tag[]` parameters and explicit
`ref mut name` arguments for i32, bool, i64, u8, u32 and usize. This promotes
the existing [source lowering](m2-slice-mutable-parameters-source.md) and
[shared CALL execution](m2-slice-mutable-execution.md) together with invocation
receipt ownership and mandatory cleanup. Version JSON reports
`array_slice_mutable_parameters: true`.

```text
browniec check examples/mutable-slice-parameters.brc --json
browniec run examples/mutable-slice-parameters.brc --fuel 1000000 --json
```

The example writes through a selected mutable range, reads the restored caller
binding, leaves its lexical scope and reads the modified owner. Mixed shared,
exclusive, scalar, owned-array and owned-record arguments retain source order.
Scalar, tagged, array and record returns restore caller authority. Recursive,
mutual and reused frames use the existing bounded VM frame arrays.

## Public boundary and lifecycle

`verify` and `inspect` now use the same complete metadata, operand, control-flow,
type and lifetime proof. Removing the final blanket rootless-exclusive gate does
not bypass any independent validation. Exact modes and tags remain required;
repeated exclusive arguments and copies of borrowed roots still fail proof
before backing preparation, Fuel or dispatch. Unused valid mutable functions
are accepted, and malformed unused functions are still rejected.

After verification the public VM preserves its existing array quota and backing
preparation order. A bounded scan of sixteen sites selects mutable execution
when a rootless exclusive formal exists. A separate helper owns exactly 32
initialized invocation-private receipts, passes them to `execute_mutable` and
calls mutable `finish` on every returned outcome. Programs without mutable
formals retain the legacy execution and cleanup path. No receipts are stored in
Program or exposed to guest source, and no additional payload extent is created
for an exclusive handoff.

Normal formal close releases its binding into the receipt while preserving the
owner write session. Normal return restores fresh caller tickets. Abort drain
handles live and detached capabilities before returning the original error;
previous payload writes are not rolled back. Native integration tests inspect
the internal state after abort and verify receipt/session cleanup. Public calls
also test repeated independent invocations after Fuel failures.

Mutable CALL prepays `1 + arity + existing owned-copy cost +
65537*(1 + shared formals + 2*exclusive formals)`. Transfer restoration is prepaid;
formal read/write/length/UTF-8/close retain their existing instruction prices.
These are the existing mutable-core charges, now reachable publicly. Existing
readonly and owned mutable program prices remain unchanged. The native receipt
collection has no extra guest Fuel charge. No native memory or stack reduction
is claimed.

Program and signature-table fields, opcodes, profile identifiers and existing
capability meanings are unchanged. Mutable aliases/subloans, shared/exclusive
coercions, non-scalar slices, temporary roots and escaping/returned borrows remain
unsupported. Existing readonly slices and same-function owned mutable slices
keep their public behavior.

## Verification selection

```text
python -B tools/verify-m2-slice-elements.py --profile development --public-mutable-parameters
python -B tools/verify-m2-slice-elements.py --profile release --public-mutable-parameters
```

The 33-group selection includes three public-boundary groups and six groups each
for source lowering, mutable shared-core execution, mutable frame transactions,
formal metadata/body proof and CALL argument proof. All selected files are passed
to one native test invocation per profile, retaining exact per-module identity
and count checks. Every profile executes its own native tests without cross-profile report reuse.

The public CLI matrix covers 74 mutable parameter cases, 222 owned mutable
cases, 192 readonly scalar cases and all 2007 M1 cases on Windows. It exercises
actual writes and caller restoration, six scalar tags, nested calls, mixed and
aggregate returns, Fuel/bounds/arithmetic errors, source errors and rejected
aliasing. The CLI retains its existing maximum of 1,000,000 Fuel; deep recursive
source cases therefore report Fuel exhaustion. Native tests with sufficient Fuel
exercise 31 nested calls and the next-frame kind12 limit. Native tests also check verification before quota/Fuel, repeated calls,
exact and one-short Fuel, two simultaneous exclusive roots and shared helpers.

Full native, other M2, Linux, M0, isolation, packaging, allocator and timing checks
are outside this selection. Local commits only; no push, publication, packaged
release or deployment.

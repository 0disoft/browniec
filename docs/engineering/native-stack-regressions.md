# Combined native stack regressions

This follow-up addresses the three development overflows left by the
[public adapter repair](public-compile-stack.md), one local commit at a time.
Each original combined fixture stays intact. The pinned Windows preview.2
compiler, native default stack and existing host timeout stay unchanged.
Diagnostic generated C is never substituted for an acceptance executable.

## Public image quota

Baseline `5e45f9a` reproduces Windows `0xC00000FD` in
`public_program::image_quota_is_exact_and_independent_of_the_public_backing_limit`.
This fixture checks image charges 576/577 and 575/576, executes accepted images,
and executes a returned view of an independently backed 4096-byte array.

The public compiler now shares candidate lowering and final reference admission
with the private API without keeping that API's owning Result frame active.
Construction and error/publication temporaries are separated from recursive
lowering. The full-capacity image builder is infallible by construction; the
checked variable-capacity builder retains its original bound. Statement and
return semantic states are constructed after expression-bank initialization.

Expression list cells contain register IDs checked below 128 before storage.
They now use 1024 byte cells instead of 1024 native-size cells. On Windows x64
this reduces their logical storage from 8192 to 1024 bytes, saving 7168 bytes
per bank without reducing capacity. The cast uses the SDK's checked numeric
conversions. IDs 127, 128 and 256 have a direct boundary regression: the last
two must fail before changing a cell or its initialized count. No additional
allocation, cache or native shim is introduced. Image ownership, exact quota
errors, source routing, Fuel, validation and cleanup remain in their original
shared kernels.

After lowering was repaired, the unchanged fixture exposed a second overflow
during CALL execution. Zero owned arguments still entered the generic copy
planner, constructing a provisional owner table and Table-bearing result
temporaries on validation/advance. `call_copy_work` now checks empty argument lists in a small adapter.
`array_owners::validate_empty_call_copy` preserves complete table authentication,
arena/depth identity, all eight origin/target comparison rows and inactive cursor
checks. It returns the same empty copies without planning targets or touching
payload, owner metadata, progress counters or Fuel. Nonempty lists continue
through the unchanged generic implementation. The independent complete planner
remains the differential oracle: 53 valid/hostile cases exercise both `validate`
and `advance` (106 calls), including ignored fields and allowance/capacity edges.
CALL begin still uses its original admission/planning path; this optimization
only removes repeated copy-plan construction during empty copy validation and advance.

Focused verification command:

```text
python -B tools/verify-native-stack.py --case quota --profile development
```

The original combined quota fixture passes in a separate development native
run. All six final focused development groups pass, with all recorded input
hashes matching. These cover the original combined quota and CALL depth fixtures, image
admission boundaries, checked/full builder equivalence, compact register cells
and empty-copy reauthentication. Whole-process peak stack and elapsed latency
are not measured. See the [quota evidence](../evidence/native-stack-quota-windows-20261118.json).

The final public O2 attempt selects the original quota/routing groups plus the
existing private-API/Fuel gates, but MSVC exceeds its unchanged 60-second host
limit before a native report completes. Zero groups are counted as release
passes. There is no timeout/stack override or identical retry. See the
[public O2 attempt](../evidence/native-stack-public-release-windows-20261118.json).

## Public source routing

The original combined routing/execution fixture reproduces `0xC00000FD` on
baseline `5e45f9a`, but passes unchanged immediately after `c9930a3`. All 367
production source files match that commit's executed snapshot; the full root
lock and original test bytes also match. The shared quota repair already fixes
this second case, so its follow-up is an evidence-only commit. No additional
implementation change or weaker replacement fixture is needed.

The complete original group checks scalar profile 0 with Fuel 1 rejection and
Fuel 2/256 execution, array profile 1, literal/returned-reference profile 8,
body/entry borrows and execution to 42. See the
[routing evidence](../evidence/native-stack-routing-windows-20261118.json).

For an independent rerun of this exact group:

```text
python -B tools/verify-native-stack.py --case routing --regression-only --profile development
```

## Private local annotations

The four-wrapper local annotation with 32 controls must execute to 42; the
33-control input must reject with kind 4 and an in-source offset. The original
combined fixture remains the acceptance boundary. The historical 2026-11-12
pass does not replace verification with the current preview.2 toolchain.

The unchanged local fixture reproduces `0xC00000FD` after the first two follow-up
commits, at `0a6962c`. Separating Program construction and Result publication
alone still overflowed. A diagnostic-only native image reached constructor
preflight and binding/view authentication underneath 32 recursive controls.
The generated transport retained full nested IR/catalog copies for scalar reads
in the owning preflight and staged authentication routines, including reads in
branches that were not currently executing.

The final repair separates candidate construction/publication from recursive
lowering and borrows the exact IR, catalog, name table and view metadata before
scalar projections in `value_source_ops::preflight` and
`value_source_bindings::advance_auth`. All validation conditions, ordering and
stage-budget updates remain unchanged. The must-use Result query also runs through a small borrowed
catalog helper, keeping its projection temporaries out of recursive statement
frames. No condition, validation order, budget debit, IR emission, cleanup,
allocation or public admission rule is changed. The raw compile traversal stays
independent and is never used as a retry.

All three focused development and O2 groups pass with identical input sets.
Both original combined depth groups
remain byte-identical: local annotations and function signatures execute to 42
with 32 controls and reject 33 with kind 4 and an in-source offset. The existing
must-use group preserves unused-result, parameter, overwrite, scope-exit and
diagnostic-name rejection. All recorded input hashes match. See the
[annotation evidence](../evidence/native-stack-annotation-windows-20261118.json).

```text
python -B tools/verify-native-stack.py --case annotation --profile development
python -B tools/verify-native-stack.py --case annotation --profile release
```

Public O2 verification is recorded separately from the annotation passes. These three
repairs do not establish a general native-stack bound for other control/type/
CALL compositions, full Engine safety, elapsed latency or peak stack usage.

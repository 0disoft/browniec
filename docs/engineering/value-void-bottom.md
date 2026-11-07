# Terminal operands in private void returns

Private retained-value void functions now accept `return <bottom>;`. Bottom is
control metadata for an expression whose every continuing alternative already
returns, breaks or continues. It is distinct from an ordinary nothing-valued
void CALL.

```c
module main;
fn void work(bool early) {
    return if (early) { return; } else { return; };
}
fn i32 main() { work(true); work(false); return 42; }
```

## Lowering

Bare `return;` is unchanged. When a void return has an operand, the existing
expression parser uses the inferred context and requires `Value.bottom`, then
requires the semicolon. The existing terminal continuation emits no additional
return82, read/capture, view close or owner cleanup. Real terminal edges already
performed their checked cleanup. Existing non-void and shared-return paths are
unchanged.

A terminal break/continue operand still transfers within its loop; it does not
return from the enclosing function. While/classic-for mutations and post steps
retain their original control flow. Grouping, nested exhaustive control and
[safe-cast suffixes](value-safe-casts.md) compose without manufacturing a value.

Actual scalar, Buffer, view and void-CALL operands reject, including a value arm
that continues. Missing terminators, malformed targets, nonexhaustive/duplicate
cases, unhandled Results and trailing unreachable statements still reject.
General bottom conditions/receivers/operands and unreachable parsing remain in
the [terminal-expression inventory](value-bottom.md).

## Verification

Five new groups execute 16 positive guests, 20 private source rejections and one
public-compiler rejection. Successful guests independently verify before native
VM execution. Unselected arms and a suppressed enclosing CALL would trap if
executed. Earlier argument effects, Buffer-producing CALL results and both
branches are observed. Four reference comparisons check exact instruction bytes,
constants, register tags/slots, function ranges, value-frame and CALL metadata,
plus exact return/drop/view-close/read/capture counts.

The independent development worker passed all five groups on the final frozen
bytes in two disjoint selections of two and three. Integration checks all 220
candidate inputs, including every production module, the new test, root manifest,
lock and toolchain metadata, against the checkout. This development evidence is
reused explicitly; it is not presented as a new integrated five-group run.

The first comparison harness retained two large Programs and exceeded the default
native stack. Compact IR snapshots resolved that harness failure without changing
production code or stacks. Initial assertions also incorrectly assumed Option
construction/case cleanup would have no captures/drops; final tests compare the
complete reference IR and exact counts, including nonzero real cleanup.

Integration uses `tools/verify-value-void-bottom.py`: development
`--regressions-only` selects four existing bottom/cast/depth checks; release runs
those four and all five new groups. They run concurrently in disjoint locked
mirrors with default stacks and no CL/_CL_/LINK overrides. A normal unfiltered
invocation runs all nine groups in both profiles.

Implementation `37c3994` passed all nine distinct groups in each Windows native
profile: development combines the five current independent worker groups with
four fresh integrated regressions; release ran all nine together. All 226 union
inputs match checkout and Git raw bytes, all 216 production modules retain LF,
and all 220 frozen worker inputs match integration. The complete combined
admitted32/rejected33 fixture is byte-identical to `f7d8627` and ran in both root
profiles. See [focused evidence](../evidence/value-void-bottom-windows-20261107.json)
for the exact batch split, candidate identity and current input manifest.

## Scope

This is a four-line private source-lowering extension. VM, verifier, opcodes,
existing prices, public admission, source/depth/operand capacities and public
Fuel default256/ceiling16000000 are unchanged. Fresh loop-carried owners, wider
bottom/reference composition, methods/public AllocError and the full runtime,
host, isolation, embedding, platform and delivery inventory remain open. No
public CLI, other-platform, allocation-failure or full leak/accounting evidence
is claimed.

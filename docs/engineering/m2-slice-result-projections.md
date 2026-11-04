# Immediate scalar projections of returned CALLs

Date: 2026-11-04. This extends private [lexical returned CALL execution](m2-slice-result-call-execution.md)
with ordinary scalar operands produced by indexing, length and UTF-8 inspection.
The accepted [full objective](completion-plan.md) and public B04 admission remain open.

## Source behavior

```brownie
let i32 x = select(ref values)[computed_index];
let usize n = select(ref values).len;
let bool valid = text::valid_utf8(select_bytes(ref bytes));
```

Both shared and exclusive returned slices support indexing for all six exact
scalar types. Length and indexing use the actual returned range, including a
callee-selected subrange. UTF-8 requires u8 and accepts either access mode.
The caller may use an existing array/slice or the already supported temporary
literal/owned CALL capture. No ref result is converted to a scalar identity:
only the verified read/length/predicate produces an ordinary scalar register.

CALL and arguments finish before the projection. The index executes once after
CALL and can use ordinary computed expressions and lexical control flow. Bare
returned slices in scalar expressions, non-usize indices, unsupported members,
wrong UTF-8 elements and whole-root conflicts remain errors. A temporary result
remains borrowed throughout its index expression; the expression cannot access
its suspended root through another name.

## Lifetime and cleanup

`compiler::slice_call_read` first completes the existing CALL_BIND recipe using
the shared caller lexical table. A separate projection helper then snapshots it,
publishes only the selected retained anonymous owner/parent dependencies, and
captures the returned Held site. The hidden names have empty spans and cannot be
resolved by a guest identifier. Keeping this snapshot after CALL avoids adding a
64-entry table copy to every recursive scalar/argument CALL parser frame.

Index-expression returns, propagation and loop exits use the existing reverse
lexical cleanup. A completed projection first materializes its scalar value,
then closes the returned result, its anonymous parent and any temporary owner.
A named mutable parent receives its fresh generation before the next expression
uses it. Runtime/Fuel traps still enter the canonical invocation drain,
retain the first error and prior writes, and do not fabricate a successful value.
No selected input, payload or source argument is copied/reexecuted by projection.

The existing independently admitted CALL/CFG/origin proof remains mandatory.
No IR opcode, Program field, operation price, CLI limit or capability is added.
The private coordinator retains its documented per-dispatch units, metadata
prepayment, zero-Fuel final close and failure cleanup.

## Verification and remaining work

The focused [Windows record](../evidence/m2-slice-result-projections-windows-20261104.json)
retains commands, compiler identity, raw inputs, test discovery and limitations.
Windows development passed 14 native groups (five new plus nine affected
regressions); release passed six (five new plus the existing owned UTF-8 CALL
regression). All 124 raw inputs and the 212-file discovery digest match. All
117 production files are LF; a separate LF mirror passed `check --locked`. The
first fresh five-group run preceded raw snapshot capture without intervening
input edits; subsequent phases require that snapshot. No compiler/stack overrides
or historical results were used.

New native cases cover six-scalar shared/exclusive reads, actual range length,
valid/invalid UTF-8, once-only argument/index effects, mutable parent reuse,
temporary owners, return/propagation/continue/break, invalid types/root conflicts,
exact/one-short Fuel, bounds failure and retained writes. Existing borrowed CALL,
owned array CALL reads and UTF-8 CALL paths are selected for regression.

Ordinary public compilation still rejects borrowed-result declarations. Direct
returned CALL arguments, reference-valued range projections, Static backing,
general references and public Program/CLI integration remain pending. This
increment neither completes B04 nor the full accepted objective. Standalone CLI,
full M1/M2, Linux, restricted delivery, ABI, allocator and timing/stack-size
benchmarks are not claimed.

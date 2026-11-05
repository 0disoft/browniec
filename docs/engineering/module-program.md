# Retained native module programs

Date: 2026-11-05. This connects the retained named entry and scoped declarations
to native multi-module compilation and execution. It advances L01/C03; public
project loading and CLI entry/module flags remain unavailable.

## Candidate lowering and complete admission

`module_program::compile` consumes an exact `module_entry::Entry`. It accepts no
caller-supplied scope table, module-name hints or executable proof. Its small-result
`compiler::lower_modules` phase reconstructs exact concatenated original bytes and
file fences from the selected private Index. This phase writes only candidate IR
and literal scratch in caller-owned storage. The candidate is not execution
authority; native callers of this lower-level API must still admit the whole IR
and image independently.

The selected public zero-argument i32 declaration becomes the actual IR entry,
even when it is not the first function or is named differently from `main`.
Every function body, including unused private helpers, receives ordinary type,
scalar/aggregate, ownership and control-flow checks. Qualified calls, record
constructors, arguments/results, field paths and shared-byte returned references
retain the owning module's exact nominal identities. Same-spelling local names
and fields do not become module references. Imports resolve only explicit aliases;
public visibility, private local helpers, cyclic imports and an explicit `text`
alias keep the declaration index's existing rules. There is no transitive or
built-in fallback for a failed qualified lookup.

After lowering scratch returns, legacy admission performs both the ordinary
executable verifier and the empty-reference proof. The retained reference route
freezes the actual literal image and performs complete reference/origin/owner/
loan verification before publishing `PublicProgram`. Failed admission publishes
no executable resource and never retries another compiler, VM or Fuel schedule.
A private `module_program::Program` owns that sealed executable and a duplicate
of the immutable original source/name snapshot through the
[typed retention owner](native-module-retention.md). Compiler-only module tables are
not retained at runtime. Read-only body/snapshot access cannot mutate authority.

## Native stack boundaries

The original combined record constructor/argument/result/field group reproduced
Windows stack-overflow status -1073741571 during compilation. A minimal
compile-only record case also failed. Diagnostic generated-C probes separated
source lowering from complete retained admission; those probes are excluded from
normal verification.

Module lowering now returns only a small candidate status into caller-owned IR
and image scratch. Independent admission and final source/executable resource
construction run after the source-context/signature/recursive-lowering frames
have returned. Legacy empty-reference verification borrows its candidate before
owning publication; it does not keep intermediate owning reference-program
return values across the verifier. Empty record catalogs authenticate all unused
layout and binding slots without constructing the unused 4,872-byte logical
32-record Plan (on the 64-bit target). Nonempty declarations retain the full
layout/cycle/depth proof. Both admission proofs, image quota checks and failure
cleanup remain. Identifier operands use a thin parser path; literal/unary/group construction
scratch stays outside each nested named CALL frame. The original combined record
group remains combined, and the 32-deep scalar and retained source CALL cases remain accepted while depth 33 is
rejected. That original checkpoint used no compiler/linker stack override, new
heap representation or larger language limit. The
[retention successor](native-module-retention.md) now moves the owning payload
behind typed SDK storage while preserving those limits. This is regression evidence, not a general peak-stack,
process-memory, allocator/OOM, timing or Engine preallocation bound.

## Source-local diagnostics and execution

Original source bytes are copied exactly, without inserted separators or line
normalization. Each file keeps its original BOM, CRLF, trailing comments and EOF.
`source_error::Error` carries the underlying error and an original-byte source
span. Verifier instruction indices are translated through the admitted candidate's
original instruction offsets before source mapping; image quotas and header-wide
proof failures carry no fabricated source span. Ungrounded recursive return origins
identify the actual function declaration. Scoped layout failures use the same
checked resolver to identify the first root depending on the invalid layout;
cycle/type errors remain kind 3 and depth/overflow/quota/limit failures use kind 4.
This diagnostic-only second pass runs only after a failed layout plan and grants
no layout or execution authority. Body lowering carries the active file identity so an intermediate EOF does
not become byte zero of the following source. Runtime instruction offsets map to
the retained snapshot; offset zero from non-instruction admission/preparation
failures has no source span. Source identities remain opaque native labels, not
paths or granted filesystem access.

`run` borrows the whole resource and uses fresh existing VM state each time.
Only the selected i32 value crosses this interface; no guest reference or native
ticket escapes. `profile` preserves ordinary profiles or the existing retained
reference profile. Prices and capacities are unchanged: public default 256 and
CLI cap 16000000, native host-selected Fuel, 16 source files, 4096 total source
bytes, 4096 name bytes, 16 functions, 32 record declarations, 256 instructions,
128 registers and the existing ownership/backing/image limits. The literal image
allowance stays independent of ordinary guest backing. A tiny legacy module CALL
has an independent exact budget of four units; one short fails and one more passes.

## Verification and remaining work

The focused native selection is `module-program-core`; `module-program` adds
public retained single-source and record assignment/child-path regressions.
`source-context` adds declaration, entry, function and lexical compatibility checks.
Run the selected verifier with both Windows development and release profiles:

```text
python -B tools/verify-static-execution.py --profile development --selection module-program
python -B tools/verify-static-execution.py --profile release --selection module-program
python -B tools/verify-static-execution.py --profile development --selection source-context
python -B tools/verify-static-execution.py --profile release --selection source-context
```

Implementation commits `65e0b5a` and `7ab2eb8` passed 50 native groups in each
Windows development/release profile: 29 module/public/record/metadata groups and
21 scoped declaration/entry/function/lexer groups, with no native overrides or
historical-result reuse. The 157 distinct verification inputs were rechecked;
155 match committed blobs byte for byte. Unchanged `tests/lexer_compatibility.fy`
and `tests/m2/struct_call_assignment.fy` use working-tree CRLF and Git LF; their
exact normalization relations and both hashes are recorded. All 144 production
modules remain LF, both selections' locked LF mirrors pass, and discovery covers
249 test files. These results followed the final origin/layout diagnostic fixes.

Exact input/compiler/report identities are recorded in
[focused Windows evidence](../evidence/module-program-windows-20261105.json).
Preliminary diagnostic tests/probes are not counted. General mutable/non-byte/
Buffer/input references, equality involving generic runtime-capable byte views and host-visible lifetimes, public project resolution,
CLI module flags, broader language completion and the full accepted implementation
remain open. Public CLI/Fuel matrices, full native suites, Linux, restricted
workers, ABI, packaging and general resource/performance bounds are outside this
increment unless separately recorded.

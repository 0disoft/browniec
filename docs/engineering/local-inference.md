# Local type inference: existing scalar and tagged expressions

Date: 2026-11-05. Implementation: `6edab73`. This advances L02; it does not complete local inference or the
remaining language profile.

## Available syntax and semantics

Initialized declarations can omit the type in `let name = value;` and
`var name = value;`, matching the accepted Fairy surface. One token of lookahead
distinguishes the unqualified binder from an explicit type; annotations keep
their existing path. No `auto`, parameter inference or function-result inference
is added.

The initializer is lowered exactly once without an expected local type. Ordinary
integer expressions therefore retain their existing default i32 and checked
range; large literals do not silently choose i64 or usize. Already typed function
results, lexical values, indexed elements, scalar fields, comparisons, widening,
switch results and postfix propagation keep the exact type produced by their
existing expression lowering. All six implemented scalar domains are preserved.
Existing complete Option/Result expression types are also retained; this does not
extend their payload set or infer an ambiguous constructor such as `.none` or
`.ok(42)` without the missing wrapper context.

`local_inference::header` checks name, duplicate and 64-binding limits before
lowering the initializer. The new name remains absent during its initialization.
`bind` accepts a checked scalar/tagged register only after the complete initializer
and terminator, then publishes the immutable register or existing typed mutable
slot. Inferred `var` remains statically typed; later stores cannot change its type.
Scopes, value copies, evaluation effects, cleanup and independent IR admission
remain the same as for annotated declarations.

Pure for-header handling retains the current scalar and call restrictions; this
does not silently expand or certify the entire target pure-header grammar.
Native module compilation uses the same lowering with exact qualified function
resolution and original source-local diagnostics. Retained byte/read expressions
and scalar locals inside explicitly typed returned-borrow bodies use the existing
reference path. No source rewriting, hidden retry, runtime type tag, allocation,
opcode, Fuel price, limit, execution profile or full-profile capability is added.

## Remaining inference work

The [owned aggregate successor](aggregate-inference.md) now adds repeated arrays,
nominal record constructors, bare value copies, aggregate CALL results and exact
record child paths through the existing initializers. Element lists/general
aggregate expressions remain separate work. The [reference/text successor](reference-inference.md)
now infers existing image views, runtime loans, aliases and returned shared-byte
bindings through their original initializers and origin/lifetime proof.
The [Option constructor successor](option-constructor-inference.md) now derives
`.some(value)` from a checked i32/bool payload. Context-free `.none`/`.ok`/`.err`
remain ambiguous; branch-order-independent constructor context and wider
payloads still need their respective inference/type integration.
General mutable/non-byte/Buffer/input results remain separate. Results below retain this
foundation's original input snapshot; the successor has separate final evidence.

Before adding `void` returns, separate the current `result_type == 0` pure-header
sentinel from actual function return types throughout lowering; a future void
body must not inherit the for-header restrictions. This increment does not yet
admit void functions.

L02 also retains `void` returns and `if` expressions; wider/resource-bearing tags,
must-use handling and the complete target source/profile limits remain open.

## Verification

```text
python -B tools/verify-static-execution.py --profile development --selection local-inference
python -B tools/verify-static-execution.py --profile release --selection local-inference
python -B tools/verify-local-inference-cli.py --profile development
python -B tools/verify-local-inference-cli.py --profile release
```

The native selection includes eight inference groups, four existing function
groups, six existing loop groups and eleven retained module groups. It checks
exact scalar and complete tagged types, one-time effects and value copies,
lexical rejection, ordinary loop headers, scoped module calls and diagnostics,
64/65 bindings and the combined legacy/retained depth-32 success/depth-33 limit
case inside an inferred initializer with an owned aggregate formal. A scalar
fixture compares complete emitted instruction bytes, register types/slots and
constants against its annotated form, including exact and one-short Fuel.

The CLI selection builds the real executable with the pinned locked toolchain,
then runs twelve checks with an empty runtime tool path. It includes check/run,
mutable/default/wide values, loop scope, invalid self-reference/type changes,
ambiguous constructors, exact and one-short scalar Fuel and retained byte reads.
The latter use explicit Fuel under the unchanged public metering schedule.

Profile results and complete input identities are recorded in the
[Windows evidence](../evidence/local-inference-windows-20261105.json).
Development and release each passed 29 native groups on the same 159 input
paths and twelve CLI cases on the same 155 input paths. The union of 160 paths
includes 151 LF production modules; all match the checkout and Git raw bytes at
`6edab73`. Native discovery is the same 256-file identity; both locked LF mirrors
passed. The current CLI build matches the retained release artifact.
Development native and both CLI runs completed before the implementation commit;
release native continued across it on unchanged inputs. The static verifier
observed its `startingHead` field after execution at that historical checkpoint;
the CLI verifier captured it at launch. Complete input hashes identify the
executed code in both cases. `8fb1ea4` corrects future native receipts to capture
the head before execution; it does not rewrite those historical receipts.
No native override or historical-result reuse was used.
Preliminary syntax/borrow-check errors and the initial default-Fuel CLI probe are
excluded. Other CLI matrices, full M1/M2/full-profile conformance, general native
stack/RAM/timing, allocator failures, Linux, worker and ABI/package behavior are
not established by this increment.

# Public retained source admission

Date: 2026-11-05. This connects the implemented literal/shared-byte source
compiler and canonical VM to public `check` and `run`. It is a bounded B04/D05
increment; the complete accepted profile remains unfinished.

## Admission and ownership

`compiler::compile_program` chooses a single compiler from lexer tokens: byte/text
literals or a `fn ref` declaration select retained reference compilation. Comments
and identifiers do not opt in. Ordinary scalar/aggregate programs retain their
existing compiler and VM schedule. A failed compilation or execution is never
retried through another path.

`PublicProgram` owns one sealed `ReferenceReturnProgram` and a private routing
flag. The complete resource moves as a unit; no resource field is moved out and
no caller can substitute its proved IR or immutable image. Native API legacy
candidates pass the ordinary verifier and the empty-reference proof before retention. Read-only
body access uses explicit intermediate borrows to avoid copying large nested IR.
Mutually exclusive compiler temporaries live in separate native functions; the
combined multi-admission/execution regression remains in one test function.

The CLI uses the same token selector with two thin branch functions. Its legacy
branch calls the original compiler/verifier/VM directly; its retained branch owns
the sealed ReferenceReturnProgram and calls the same local execution adapter as
PublicProgram. Keeping inactive owning return slots off the native parser stack
preserves the existing source expression-depth limit. Reference lowering,
signature selection and final image admission also use separate small-result
phases. Both routes accept 32 nested call expressions and reject 33/64 with a
compile-limit error, without a compiler or linker stack override.

`check` completes admission without executing. `run` uses fresh native state for
each invocation and returns an i32 value, never a guest reference or native ticket.
Changing the caller's source buffer after compilation cannot change the retained
code/image. Existing lower-level compiler and bare-IR gates remain separate.

## Public language and discovery

The result profile `brownie.m2-reference/1` identifies the retained execution
path. Version JSON adds `reference_profile`, `byte_literals`, `text_literals`,
`immutable_byte_views`, `shared_byte_parameters` and `shared_byte_results`.
Existing scalar/aggregate profiles and flags retain their meanings.

The admitted subset includes byte/text literals, immutable local views, byte
ranges, explicit `text::bytes`, immutable `text::equal`, `ref u8[]` arguments and
single-origin `fn ref u8[]` results. Image results and selected temporary array
owners reuse the complete independent lifetime proof and native CALL/RETURN
transactions. Dangling local returns, writes/drops through retained shared
results, exclusive results and non-byte results remain rejected here.

## Fuel and capacities

The CLI default remains 256 and its explicit ceiling remains 16000000. Native
host APIs still accept a host-selected usize budget above that ceiling. Choosing
the retained path uses the existing canonical entry, per-dispatch, reference and
leave prices; it does not silently use the legacy scalar schedule. Even a small
literal program generally needs an explicit larger budget. For
`module main;fn i32 main(){return b"*"[0] as i32;}`, the independent oracle is
147456 entry + 196608 leave + 17 OPEN + 1 index + 18 READ + 1 widening +
1 CLOSE + 1 RETURN dispatch = 344103. The CLI checks 344102/344103/344104;
ordinary `return 42` still needs exactly two units on the legacy path.

Image-only programs use zero guest backing. Programs with aggregate catalogs use
the existing 65536-byte backing and prepay `1 + 65536` before allocation, in
addition to canonical entry. The image allowance is independently the existing
576 metadata units plus at most 4096 decoded bytes. Frame, root, loan, register,
source, instruction and image-entry capacities are unchanged. Low Fuel cannot
publish a reference or skip native cleanup.

## Verification

Run the selected native tests and serialized CLI builds with the pinned compiler:

```text
python -B tools/verify-static-execution.py --profile development --selection public-program
python -B tools/verify-static-execution.py --profile release --selection public-program
python -B tools/verify-public-fuel.py --profile development --phase cli
python -B tools/verify-public-fuel.py --profile release --phase cli
python -B tools/check-reference-cli.py --exe build/public-fuel/development/browniec.exe --output build/public-program-cli/development
python -B tools/check-reference-cli.py --exe build/public-fuel/release/browniec.exe --output build/public-program-cli/release
python -B tools/check-m1-cli.py --exe build/public-fuel/development/browniec.exe --profile public-program-development
python -B tools/check-m1-cli.py --exe build/public-fuel/release/browniec.exe --profile public-program-release
```

The focused source suite keeps the combined quota/admission/execution case;
it also checks retained source immutability, repeated invocations, zero-length
views, mixed image/runtime arguments, selected temporary lifetimes and honest
private/public boundaries. The standalone checker clears the runtime environment
and PATH and checks JSON, exits, profiles, literal decoding, bounds, lifetime
rejections, version discovery and isolation denial.

Implementation: `63c8fb7`. Windows development and release each passed 18 native
groups (eight public API, eight returned source, two existing Static bindings)
and 2112 tool-free CLI cases: 33 Fuel, 72 retained/depth and 2007 M1 regressions.
All 164 distinct recorded inputs match committed Git bytes; native selections
cover 145 paths and Fuel CLI builds cover 150. Both locked LF mirrors passed on
138 production modules with the same 243-file test-discovery identity. No compiler/
stack overrides or historical-result reuse were used in the final runs.

Final results and artifact/input identities are recorded in the
[Windows evidence](../evidence/public-program-windows-20261105.json).
Preliminary failing fixtures/probes are excluded from passing counts.

## Remaining work

General mutable/non-byte returned views, Buffer/input-backed text/references,
runtime mixed-backing equality, host-visible reference lifetime APIs and the
`array_slice_results` capability remain open. Restricted/embed stay false.
Engine/Instance accounting, cancellation/deadlines, Windows worker isolation,
DLL/C ABI, packaging, Linux and full-profile conformance are separate requirements.
This increment does not establish a process RAM/stack bound, allocator/OOM or
elapsed-time benchmark. See the [remaining inventory](../product/04-remaining-work.md).

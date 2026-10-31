# Typed slice element source

Status: source/private typed-slice IR implemented and verified at `5401efb`;
non-`u8` borrowed VM execution remains gated. Both profiles passed the selected matrix.

The scanner and lowering accept readonly borrowed slices of `i32`, `bool`,
`i64`, `u8`, `u32` and `usize`. `verifier::inspect` proves well-formed private
IR for all six tags. `verifier::verify` still rejects every non-`u8` borrowed
signature before VM admission, so typed non-`u8` execution is not enabled.

## Accepted source shapes

Declarations such as `fn i32 first(ref i32[] values)` lower and inspect. Current
CLI `check` and `run` return exit 6 for a non-`u8` formal. Accepted tags are:

| Tag | Element type |
| ---: | --- |
| 1 | `i32` |
| 2 | `bool` |
| 9 | `i64` |
| 10 | `u8` |
| 11 | `u32` |
| 12 | `usize` |

## Signature metadata

`functions.Table` has `u8[128] param_slice_elements` beside the existing
`bool[128] param_slices`. The latter identifies a borrowed position; the
former stores its exact scalar tag. `param_types`, `param_lengths` and
`param_records` remain zero, so borrowed positions are not scalar, fixed-array
or record parameters. Kinds are recorded before bodies, so forward and
recursive calls do not depend on later register allocation.

The initial full development M1 hit `0xC00000FD` at `arm-stack-calls-33-run`
(`check` returned `compile_limit`; `run` crashed). The repair moves `param_slice_elements`
lookup from recursive `compiler::call_value` into borrow-only
`slice_call_source::capture`. The prior/regressed/fixed comparison keeps depth
32 valid and makes fixed depth 33/64 return `compile_limit` in both modes.
No stack-size measurement is claimed.

## Lowering and exact types

`slice_call_source.bind` calls `slice_builders::parameter_typed` with the tag
from `param_slice_elements`. It reserves one non-scalar parameter position and
creates a self-anchored rootless formal site. The tag is stored in
`ir::Program.slice_elements`; the parameter position stores its site in
`slice_parameters` and has no scalar payload.

Local immutable aliases must use the lexical parent's exact type. Computed,
open, empty and nested subranges derive from a matching slice. A formal-derived
slice stays rootless and inherits its anchor's tag. `var ref` is unsupported.

An explicit call argument is `ref` followed by one visible slice name.
`slice_call_source.capture` requires exact equality between that site and the
callee formal, including same-width distinctions such as `i32` versus `u32`.
Forward, recursive, repeated-reference and mixed scalar/fixed-array/record
arguments are represented in IR. No payload copy or caller-side close is made.

Reads return the site's exact tag. `.len` returns `usize`. `text::valid_utf8`
is accepted only for `u8`. Subslice sites retain their tag and rootless origin.
Reverse lexical cleanup covers aliases and formal-derived ranges at normal
exits, `?` propagation, loop transfers and aggregate exits. This is lowering
order only; non-`u8` VM cleanup is absent.

## Verification boundary

`verifier::inspect` checks Program metadata, registers, instruction types,
dataflow, borrow liveness and closes. It admits the private non-`u8` IR.
`verifier::verify` scans the whole Program and rejects any non-`u8` borrowed
site with verification kind 5 at offset 0, including an unused helper. This
happens before VM backing, Fuel checks or dispatch; CLI `check` and `run` both
exit 6 for such signatures.

For `u8`, source and borrowed execution remain supported with the existing
costs and version/profile surface. `u8` owned bindings also work.

## Owned-root limitation

Only a non-`u8` typed local slice over an owned array is unsupported. The
owned-root branch still uses `u8`-only `text_source::argument`, so
`let i32[1] a = [42; 1]; let ref i32[] p = ref a;` fails during source lowering
with a source TYPE error. Non-`u8` owned-root syntax and execution remain
unavailable.

Mutable slices, non-scalar elements, slice results, escaping references,
temporary roots and direct array/literal call arguments remain unsupported.
Limits remain sixteen sites, eight arguments and 32 frames. No opcode, Fuel
price, capability, Program version or profile field changes.

## Focused verification

```text
python -B tools/verify-m2-slice-elements.py --profile development --parameter-source
python -B tools/verify-m2-slice-elements.py --profile release --parameter-source
```

Both profiles passed 14 native groups (5 new source, 5 old source, 4 typed IR)
and 2,641 CLI cases (252 new, 64 public `u8`, 74 old source, 120 alias, 124
subslice, 2,007 full M1). They produced 347 identical current source/input
hashes. Both retained CLI identities verified; the three comparison images
and 18 outcomes were identity-checked.

The [Windows evidence](../evidence/m2-slice-element-source-windows-20261101.json)
records the actual commands, profiles and stack comparison. Historical parser
stack documents and evidence remain unchanged.

Full native suites, other M2 suites, Linux, M0, isolation, packaging and
performance tests were not rerun. No push, publication or release/deployment
was performed.

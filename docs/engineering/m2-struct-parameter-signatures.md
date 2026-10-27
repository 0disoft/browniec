# M2 Nominal Record Parameter Signatures

- Status: implemented at `4a6792b`; focused development/release verification passed.
- Scope: immutable bare nominal record parameter signatures in `functions::scan`
  plus a compiler gate that rejects them before lowering.
- Implementation: [`functions::scan`](../../src/functions.fy),
  [compilation gate](../../src/compiler.fy),
  [bounded declaration lookup](../../src/struct_source.fy); fixture
  [signature and gate cases](../../tests/m2/struct_parameter_signatures.fy),
  CLI [record-parameter gates](../../tools/check-m2-struct-parameter-signatures.py).
- Selection: `python -B tools/verify-m2-struct-values.py --parameter-signatures`
  with `--profile development` or `--profile release`.
- Evidence: [Windows receipt](../evidence/m2-struct-parameter-signatures-windows-20261027.json).

## Recognized signatures

A non-reserved word at a parameter's type position is tried as a nominal record
name. Primitive, wrapper and reserved spellings keep the existing type parser
and `ELEMENT[LENGTH]` keeps the array parser, so neither path rescans the
module. A bare name resolves through the existing bounded `structs::locate`
search with sentinel 32, which walks the module and skips function and struct bodies
with the lexer. The caller accepts only declaration indexes 0..31; forward and interleaved
declarations resolve, while an unknown name fails with `type`.

A recognized parameter stores record ID plus one in
`param_records[function * 8 + arity]`, where zero means scalar or array. Its
`param_types`, `param_lengths` and `param_arrays` entries stay zero, keeping
record identity disjoint from scalar tags, array lengths and prepared array
catalog IDs. `param_begins` and `param_ends` still address the parameter name.
`u8[128] param_records` is the whole new metadata: exactly 128 bytes, with
unused slots zero. Declaration grammar is checked by the existing skip parser;
full field-type and layout validation remains in `structs::scan`. This signature
lookup does not create storage or validate an executable argument ABI.

## Rejected shapes

Scanning or the gate rejects `P[1]`, `P<P>`, `Option<P>`, `Result<P,i32>`,
`ref P`, `var P`, duplicate names, a trailing comma, an unknown nominal
name, a record result, a ninth parameter (`compile_limit`), and more than 16
functions. `main` keeps its zero-argument scalar `i32` rule. Record results,
arrays of records, wrappers of records and borrows remain unavailable, and
because every record parameter is rejected, so do source calls that pass one.

## Compilation gate

`compiler::compile` scans all signatures, then walks the 128 parameter slots
before `ir::empty`, array catalog preparation (`array_calls::prepare`,
`array_results::prepare`), record scanning and body lowering. A nonzero
`param_records` slot returns `type` at `param_begins[slot]`, the record
parameter name, in declaration order. Because the gate runs on declarations
alone, an unused helper, an invalid `main` body, or a function whose parameters
would exhaust the 16 array sites is rejected for the record parameter first.
The zero record tag never reaches scalar binding, argument capture or arrays.

## Bounds and cost

Sixteen functions with eight parameters each cap record parameters at 128 over
at most 4,096 source bytes, and each nominal name pays one bounded
`structs::locate` walk: worst-case O(P * S) lexer steps, with an O(128) gate.
No payload byte, owner, IR site, frame, register or instruction is reserved,
and no runtime allocation, stack byte or speed change is measured or claimed.
Opcodes, verifier, VM dispatch, Fuel charges, version capability and profile
selection are unchanged. No record-parameter capability or result profile is added.

## Status summary

Bare immutable nominal record parameters are implemented as
`param_records = record ID + 1`, 128 bytes of new metadata, and are rejected
by a pre-lowering gate that reports `type` at the first record parameter name.
Executable record arguments, results, arrays/wrappers of records, borrows and mutable
parameter syntax remain unavailable; opcodes, Fuel, profiles and version output
are unchanged. Both profiles passed 16 native groups and 2,226 CLI cases.

## Verification

The harness is `python -B tools/verify-m2-struct-values.py --parameter-signatures`;
pass `--profile development` or `--profile release` for one profile.
Each development/release profile passed 16 native groups (6 new signature, 6 array signature,
4 function) and four CLI matrices totaling 2,226 cases (88 new record-parameter,
89 helper-record, 80 array-parameter, 1,969 M1).

Development ran the native selection and CLI matrices individually. Release completed
`python -B tools/verify-m2-struct-values.py --parameter-signatures --profile release`.
Before archival, 181 input hashes, compiler/release executable identities, and
equal native identities across profiles were rechecked. The compiler remains
`4ce1264273be`; the SDK lock identity is unchanged. Earlier receipts are
historical for changed frontend, root-lock, test, and tooling inputs.

Full native suites, other CLI matrices, M0, Linux, isolation, DLL, packaging,
allocation instrumentation and performance are outside this selection.

The [private IR successor](m2-struct-parameters-ir.md) adds independent verification
and changes IR, verifier, VM preflight, and root-lock inputs. This signature
receipt remains evidence for `4a6792b`; executable source calls stay gated.

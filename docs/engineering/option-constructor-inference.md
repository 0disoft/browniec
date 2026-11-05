# Payload-derived Option constructor inference

Date: 2026-11-06. Implementation: `92ca0d4`.
This advances L02 within the existing scalar tagged profile.
It does not complete general expression inference or widen tagged payloads.

## Available behavior

An uncontextualized `.some(value)` now infers `Option<i32>` when the checked
payload has type i32, or `Option<bool>` when it has type bool:

```brownie
let answer = .some(42);
var enabled = .some(false);
enabled = .none;
```

The payload follows ordinary expression lowering exactly once. Untyped integers
still default to checked i32; already typed values keep their exact type. Inferred
mutable bindings remain statically typed. Parentheses, calls, switch scrutinees,
value arms with available context and compatible postfix propagation use the
same constructor path. A first typed/inferred value arm can supply the existing
context for a following `.none` arm.

Missing domains are not guessed. Standalone `.none` lacks a payload type;
standalone `.ok(value)` and `.err(value)` lack the other Result domain. They still
require an annotation, function signature or another already available expected
type. The current switch parser does not infer a first `.none` arm from a later
`.some` arm. Branch-order-independent/contextual unification remains L02 work.

Only the existing i32/bool payloads are admitted. i64/u8/u32/usize, nested tags,
arrays, records, text, loans and Buffer payloads remain L05 work. An inferred
constructor does not silently widen a typed u8 to i32 or choose a wider integer
domain for an overflowing literal. No context-free Result default is added.

## Implementation and invariants

`compiler::compound_operand` keeps one constructor parser/emitter for annotated
and inferred cases. A zero expected type permits only `.some`, lowers its payload
without an expected type, checks that the resulting register has one supported
payload domain, then emits the existing CONSTRUCT 23 with tag 3 or 4. Existing
nonzero expected types keep their original exact-payload and variant checks.
Independent tagged/scalar/CFG admission remains authoritative.

Local publication still follows full initialization and the terminator. Existing
captures, returned temporary owners, early returns and propagation use their
original cleanup; type discovery does not replay guest work. Pure for headers
still reject tagged bindings and retain their existing call restrictions.
No type ID, opcode, runtime descriptor, allocator, Fuel price, profile, feature
flag or limit changes. Public Fuel remains default 256, CLI ceiling 16000000.

## Verification

```text
python -B tools/verify-static-execution.py --profile development --selection option-inference
python -B tools/verify-static-execution.py --profile release --selection option-inference
python -B tools/verify-local-inference-cli.py --profile development --options
python -B tools/verify-local-inference-cli.py --profile release --options
```

The native selection includes constructor inference, ambiguous/unsupported type
rejection, existing annotated wrapper/copy/CALL and exact Fuel admission, and
complete tagged-local inference. It compares annotated/inferred instruction
bytes, register types/slots and constants. The straight-line fixture costs four
units: constant, CONSTRUCT, selected case and return; three fails with Fuel.
Other cases check mutable snapshots, i32 minimum, bool, one-time mutable argument
effects, owned arguments, propagation, switch context and retained result reads.

CLI checks run the actual executable with an empty runtime tool path. They retain
the scalar inference cases and add constructor check/run, exact/one-short Fuel,
bool/mutable values, propagation, switch context, retained byte projections and
ambiguous/unsupported/type-changing rejection. The evidence records each executed
source, verifier, compiler, report and artifact identity, with explicit skips.

Windows development and release each passed five native groups and 25 standalone
CLI cases. The native/CLI phases fingerprint 161/158 paths respectively; their
162-path union matches checkout and Git raw bytes at `92ca0d4`. Both locked LF
mirrors pass, with 154 LF production modules and the same 260-file test-discovery
identity. All four runs captured their starting head before execution; inputs
remained unchanged through the implementation commit. See the
[Windows evidence](../evidence/option-inference-windows-20261106.json).
No compiler/stack override or historical result reuse was used. Broader native/
CLI matrices, full profiles, general RAM/stack/timing/allocator/OOM, Linux,
Engine/worker/ABI/package behavior were not verified by this increment.

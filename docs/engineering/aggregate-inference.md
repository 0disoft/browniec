# Owned aggregate local type inference

Date: 2026-11-05. Implementation: `6c7d94f`. This extends [scalar local inference](local-inference.md) with
the existing owned array/record initializer forms. L02 and the full objective
remain open.

## Available forms

`let name = value;` and `var name = value;` now infer:

- repeated scalar arrays `[filler; N]`, including the filler's existing exact
  scalar type and positive literal length;
- bare owned-array copies and owned-array CALL results;
- exact nominal record constructors, including existing field shorthand and
  nested constructors;
- bare record copies, whole record CALL results and exact record child paths
  from a local owner or returned record.

Integer fillers without a type context remain i32; a known u8/i64/u32/usize
expression retains its existing element type. No implicit narrowing or dynamic
shape change is added. Owned bindings remain independent by-value copies, and
inferred mutable arrays/records keep the original element/length/nominal type.
Scoped module constructors, qualified CALLs and original source diagnostics use
the same module context as annotated declarations.

Scalar projections such as `make()[0]`, `make().len`, `make().inner.x` and
`owner.inner.x` retain scalar expression lowering. A final record endpoint such
as `make().inner` creates the existing independently owned exact nominal child.

## Type selection and ownership

`aggregate_inference::inspect` is advisory source-shape lookup. It borrows the
existing signatures/catalog and inspects a separate lexer snapshot; it never
executes an argument, emits IR, rewrites source or advances the active lexer.
Only aggregate-result calls require bounded parenthesis scanning. Scalar-result
calls return immediately to scalar lowering. Delimiters in comments/literals
are handled by the existing lexer and its source/token bounds.

Record paths resolve through the same scoped field/nominal lookup used by real
lowering. The selected initializer then rechecks the exact declaration/path.
Classification is not executable authority or an admission bypass.

Annotated and inferred arrays share `array_initializer` and
`array_local_source::repeated`. The latter receives a filler already evaluated
once and parses the existing exact count/terminator before creating the IR
owner and publishing the binding. Annotated/inferred records share
`record_initializer`, the same record layout/128-byte check and existing ordered
field staging, copy, CALL, child extraction and drop paths.

Pending names/owners remain absent during initialization. Early exits therefore
clean the prior lexical owners and captures through their existing finalizers.
There is no new runtime descriptor, opcode, allocator, Fuel price, profile flag
or capacity. Six scalar element types, 64 names, sixteen array/record sites,
existing record leaf/size budgets and independent IR/image/loan proof remain.

## Remaining boundaries

This implements the current direct initializer forms, not general aggregate
expressions. Element-list arrays and their inference remain L03 work. Parenthesized,
conditional and other general aggregate-expression forms, inferred reference/text
bindings, tag constructor context, wider/resource tags, void and if values still
need their respective lowering and ownership integration. Current annotated
reference/text forms remain available. Do not mark L02 or the full profile complete.
The pure-header sentinel separation required before void remains documented in
[the scalar foundation](local-inference.md).

## Verification

```text
python -B tools/verify-static-execution.py --profile development --selection aggregate-inference
python -B tools/verify-static-execution.py --profile release --selection aggregate-inference
python -B tools/verify-local-inference-cli.py --profile development --aggregate
python -B tools/verify-local-inference-cli.py --profile release --aggregate
```

The native selection contains eight new aggregate groups, eight existing scalar
inference groups, twelve retained module groups and four array scope groups.
It covers all six elements, exact copies/nominal paths and scoped declarations,
one-time effects, nested CALL argument syntax, scalar versus aggregate suffixes,
early returns, fixed-shape/type rejection and the original 16/17-site limits.
One mixed array/record fixture compares emitted instruction bytes, register
types/slots, constants and owner shape/mutability against annotated source.
Existing scalar inference tests retain the combined legacy/retained 32-deep
initializer success/33-deep rejection case without stack/compiler overrides.

The real native CLI selection retains all twelve scalar inference cases and adds
twelve aggregate/projection/early-exit/negative/retained cases. Both profiles run
with an empty runtime tool path. Aggregate cases use explicit Fuel under the
unchanged metering schedule. Profile results and exact identities belong to the
[Windows evidence](../evidence/aggregate-inference-windows-20261105.json).
Development and release each passed 32 native groups on the same 161 inputs and
24 real CLI cases on the same 157 inputs. The 162-path union includes 153 LF
production modules; all match checkout and Git raw bytes at `6c7d94f`. Native
discovery is the same 257-file identity and both locked LF mirrors passed. The
current native CLI matches the retained release artifact.
Development native and both CLI runs completed before that code commit;
release native continued across it on unchanged inputs. As in the scalar
foundation, the static verifier observes `startingHead` at the end while the CLI
verifier captures it at launch; input hashes establish the executed code identity.
There were no native overrides or historical-result reuse.

The preliminary eight-group probe is excluded from final-input profile counts.
Other CLI matrices, complete M1/M2/full-profile conformance, general stack/RAM/
timing, allocation-failure injection, Linux, Engine/Instance, host/worker and
ABI/package claims are not established by this increment.

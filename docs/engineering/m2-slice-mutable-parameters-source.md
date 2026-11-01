# Private mutable slice parameter source lowering

Source functions can now declare `ref mut Tag[] name` parameters and pass an
existing exact mutable slice as `ref mut name`. `Tag` is one of i32, bool, i64,
u8, u32 and usize. The compiler lowers these forms to the existing independently
inspected mutable CALL IR and shared private VM execution path.

Public verification and CLI admission still reject every rootless exclusive
formal after complete proof and before backing allocation, Fuel or dispatch.
This includes unused functions. This stage adds source lowering, not a public
mutable parameter capability. Existing owned mutable slices remain public.

Implementation: `2f9cc0d`.

```text
module main;
fn i32 fill(ref mut i32[] p) { p[0] = 42; return p[0]; }
fn i32 main() {
    var i32[2] values = [0; 2];
    let ref mut i32[] selected = ref mut values[1..];
    let i32 result = fill(ref mut selected);
    return selected[0];
}
```

The example compiles and inspects, then runs through `execute_mutable` in native
tests. Public `check` and `run` return a verification error, including at zero
Fuel. Public promotion is the next separate delivery.

## Exact signatures and arguments

The bounded signature pass stores the exclusive bit in the existing scalar
element byte, matching IR bit128. No signature-table or Program fields grow.
The body binder strips the bit for `parameter_exclusive`; readonly parameters
continue to use `parameter_typed`. Formal positions still reserve one non-scalar
position and one rootless slice site without creating an owned array.

Argument capture requires explicit `ref mut` for exclusive destinations and
explicit `ref` for shared destinations. Both the mode and scalar tag must match
the existing named source. There is no shared/exclusive coercion, array or
temporary coercion, expression argument, implicit subrange or caller-side close.
Forward and recursive calls use signatures rather than future runtime tickets.
The existing independent argument proof rejects repeated exclusive sources and
owned copies of a borrowed root; shared duplicates retain their existing rules.

The ordinary CALL argument loop remains unchanged. Scalar expressions, owned
arrays/records and shared/exclusive slices retain source order. Capturing a
borrow does not begin the runtime handoff; later argument expressions can still
access that caller binding before CALL. The synchronous transaction restores it
before caller execution resumes.

Existing lexical exit lowering emits `slice_close` for a formal. In an active
mutable frame this releases its binding into the private receipt, retaining the
owner write session until return restoration. Scalar, tagged, array and record
returns use the existing coordinator. Native callers must inspect immutable IR,
supply 32 unique initialized receipts and invoke mutable `finish` on every
result. Abort cleanup preserves earlier writes and the original outcome.

No opcode, capability, profile, public/readonly price or private CALL price
changes. Mutable aliases/subloans, escaping/returned borrows, non-scalar slices
and direct owned-array arguments remain unavailable.

## Verification

```text
python -B tools/verify-m2-slice-elements.py --profile development --mutable-parameters-source
python -B tools/verify-m2-slice-elements.py --profile release --mutable-parameters-source
```

The selection includes six new native source groups, five readonly parameter
source groups, five scalar element source groups and six exact mutable CALL IR
groups. New source tests perform all six scalar writes, selected-range caller
restoration, forward/recursive/mutual/reused calls, mixed scalar/owned/shared
arguments, scalar/array/record/tagged returns, argument evaluation order, exact
mode/type rejection and bounds/arithmetic abort cleanup preserving earlier writes.
They compile actual source without patching its IR.

The CLI selection includes 68 private source admission/rejection cases,
222 existing owned mutable cases, 192 readonly scalar cases and 2007 M1 cases on
Windows. Native mutable recursion accepts 31 nested CALLs and rejects the next
frame with kind12 when sufficient Fuel remains.

Development and release each passed all 22 selected native groups and 2,489 CLI
cases, with 370 matching current input hashes. Compiler, retained CLI and
matrix/M1 receipt identities were rechecked. Both profiles accept parser depth32
in check/run and reject depths33/64 with `compile_limit`. Program and signature
table fields remain unchanged from `6eabce5`. See the
[Windows evidence](../evidence/m2-slice-mutable-parameters-source-windows-20261101.json).

Next is public mutable parameter admission: connect the public VM entry to
invocation-owned receipts and mandatory mutable cleanup, promote the version
capability and change the CLI matrix from private rejection to public execution.
These changes must be delivered together; this source stage keeps the gate.

Full native, other M2, Linux, M0, isolation, packaging, allocator and timing checks
are outside this selection. No performance or native stack measurement is claimed.
Local commits only; no push, publication, packaged release or deployment.

# Private owned mutable-slice source lowering

The source compiler now lowers a lexical exclusive slice declaration and element
stores for all six exact scalar tags (`i32`, `bool`, `i64`, `u8`, `u32`, `usize`):

```text
var i32[4] a = [0; 4];
{
    let ref mut i32[] p = ref mut a[1..3];
    p[0] = 20;
    p[1] = 22;
}
// a[1] and a[2] are now accessible again.
```

This is a private lowering checkpoint. Native tests independently inspect and
execute the generated IR through the shared internal VM. Public CLI `check` and
`run` still reject exclusive metadata with `verification` at offset zero, before
backing allocation, Fuel or dispatch. The example above is not yet a public CLI
feature. Public admission is the next delivery slice; no version capability,
profile, instruction encoding, Fuel price or Program field changes here.

Implementation: `e0a0ec0`.

## Source boundary

Both declaration and initializer require `mut`. The binding uses `let`; `var ref
mut` and rebinding `p = ...` are rejected. The binding's internal write-permission
flag allows only `p[index] = value`, and never treats its handle as a scalar slot.
The root must already be a same-function mutable owned scalar array, with the
exact declared element tag. Immutable arrays and readonly by-value parameters
cannot supply mutable roots.

Whole (`ref mut a`), full (`a[..]`), explicit, computed, open and empty bounds use
the existing range grammar. Bounds must be `usize`. The root is locked for the
entire lexical loan, even for an empty selection. Relative reads, `.len` and
selected `text::valid_utf8(p)` for `u8` reuse the existing slice operations.
Stores require a `usize` index and an exact-element value.

Mutable parameters, slice results, temporary roots, whole-handle assignment,
mutable aliases/subranges, readonly aliases of writers and readonly CALL
coercions are rejected. A writer cannot be passed as `ref p`; explicit `ref mut`
CALL arguments remain unsupported. Independent shared roots can still be passed
to ordinary readonly callees while another root has an exclusive slice.

## Evaluation, proof and lifetime

Endpoints run once from left to right while the pending binding is absent from
the local-name table. The exclusive site/open and local binding publish only
after endpoint evaluation. Stores evaluate the index once, then the value once,
and emit opcode 60 without a scalar definition, temporary owner or copy. A store
inside a switch value arm uses the same statement/read distinction as arrays.

Existing reverse lexical cleanup emits closes before dropping roots on block
exit, scalar or aggregate return, propagation, break and continue. Transfers from
inside pending endpoints do not close an unpublished ticket. The internal VM
retains the existing checked relative writes, selected UTF-8, exact Fuel prices
and invocation error drain. Earlier writes are not rolled back on later errors.

Source shape/type rejection and independent Program inspection remain separate.
Some root conflicts can still lower successfully and are rejected by `inspect`:
direct root payload reads, source copies, root UTF-8, and shared/exclusive or
exclusive/exclusive overlap. They cannot become executable Programs. The public
gate follows the complete proof; it does not stand in for that proof. Runtime
range and arithmetic errors remain runtime errors in native internal execution.

## Verification selection

```text
python -B tools/verify-m2-slice-elements.py --profile development --exclusive-source
python -B tools/verify-m2-slice-elements.py --profile release --exclusive-source
```

The selection includes six new source groups, six existing exclusive-VM groups
and five existing readonly source groups. CLI checks include 164 private source
gate cases, 192 public readonly scalar-slice cases and all 2,007 M1 cases. Native
tests perform actual source-to-IR-to-VM execution; the new CLI cases prove honest
rejection rather than mutable-slice execution. Zero-Fuel runs still reach the
public exclusive gate first. The scripts retain artifacts and record input,
compiler, executable and receipt identities.

Development and release each passed all 17 selected native groups and 2,363 CLI
cases. Both matched 359 identical current input hashes; pinned compiler, retained
CLI, both matrix and full M1 receipt identities were rechecked. Both profiles
accept parser depth 32 and reject depths 33/64 with `compile_limit` in check/run.
Program fields remain unchanged. See the
[Windows evidence](../evidence/m2-slice-exclusive-source-windows-20261101.json).

Full native and other M2 suites, Linux, M0, isolation, packaging, allocator and
timing checks are outside this selection. Earlier receipts remain historical
for their original inputs. No push, publication, packaged release or deployment
is part of this local delivery.

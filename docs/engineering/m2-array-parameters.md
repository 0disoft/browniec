# M2 Source Array Parameters

- Status: source lowering implemented and verified stepwise on Windows x64
- Scope: immutable exact-shape by-value parameters for the six scalar array elements
- Evidence: [Windows receipt](../evidence/m2-array-parameters-windows-20261025.json)
- Example: [`array-parameters.brc`](../../examples/array-parameters.brc)

The [signature foundation](m2-array-signatures.md), [atomic copy primitive](m2-array-arguments.md),
and [private call implementation](m2-array-calls.md) now connect to the source
compiler. Array parameter declarations are no longer gated.

```c
fn i32 sum(i32[2] values, i32 extra) {
    return values[0] + values[1] + extra;
}
fn i32 main() {
    let i32[2] values = [21; 2];
    return sum(values, 0);
}
```

## Parameters and arguments

Parameter shapes are exact: element tags are `bool`, `u8`, `i32`, `i64`, `u32`,
and `usize`, and lengths are integer literals from 1 through 4096. Each array
argument must be a bare visible binding name with exactly matching element and
length. A scalar, indexed element, parenthesized array name, `.len`, array
literal, or implicit conversion cannot satisfy an array parameter.

Scalar, shallow wrapper, and array parameters may occupy any of the eight
argument positions. Array parameter names are immutable. Element writes and
whole-array assignment through them fail compilation. A function can read
elements, use `.len`, copy a parameter into an independent local array, and
forward it to another call. Every callee invocation receives its own payload and
owner, including repeated arguments and recursion.

All parameter catalog entries are declared before any body is lowered, so
forward and mutual calls have their complete shapes available. Body lowering
binds parameter names to the predeclared catalog entries while reserving the
existing argument-order register positions. The independent verifier and VM
contract is unchanged by this increment.

## Evaluation and cleanup

Arguments evaluate exactly once, left to right. An immutable array binding is
already a stable snapshot and needs no additional caller-side copy. A `var`
array is copied immediately into a new immutable caller-owned capture, before
the next argument is evaluated. The existing VM CALL then independently copies
each snapshot into its callee parameter owner. Later effects cannot change an
earlier captured argument, and the caller's original array stays independent.

For example, the supplied example captures `[2]`, changes the source to `[4]`
while evaluating the scalar argument, then captures `[4]`. Its result is
`2 * 10 + 18 + 4`, or 42.

Mutable captures are anonymous bindings in a private snapshot of the caller's
lexical name table. Their empty source spans cannot match a guest identifier.
No global temporary-owner state or new VM opcode is introduced. Subsequent
argument expressions inherit that table, so existing lexical cleanup covers:

- Normal CALL completion: release only that call's captures, in reverse order.
- Nested CALLs: inner cleanup preserves the pending outer captures.
- `?` failure and explicit return: drop captures, locals, and parameters in
  reverse binding order before returning the scalar or wrapper result.
- Transfers to an enclosing loop: release captures when leaving their lifetime.
- Loops inside a later argument: preserve captures owned by the pending outer
  call while dropping only the inner loop's local arrays.

Success paths retain pending captures until their call completes. Runtime
failures abort the run and reclaim its owned payload; argument evaluation and
external effects are not replayed or rolled back. Callee copy failure still
uses the existing atomic batch preflight without partial owner publication.

## Limits and work

The existing limits remain: 16 shared static array catalog sites, 16 live owners,
32 VM frames, and a 65,536-byte payload arena. Each call has at most eight
arguments; each lexical table holds at most 64 active bindings.
Parameter sites and mutable capture sites count toward the
catalog cap; anonymous captures also count toward the lexical binding cap.
Unused helper parameters count as static sites. Nothing silently expands these
budgets.

Immutable arguments need the original plus the callee copy. Mutable arguments
also retain the caller capture until CALL completes, so all three extents and
alignment padding count at the peak. Eight repeated immutable arguments fit
when catalog and owner space allow; eight mutable captures plus eight parameter
sites and an original array exceed the 16-site limit and fail honestly.

The existing `ACOPY`, `ADROP`, and array CALL Fuel prices apply. With the default
arena, passing a one-element i32 array to a function returning `a[0]` takes
66,013 Fuel for `let`, or 66,122 for `var` including capture and cleanup. One
Fuel less fails. These are executed instruction-work checks, not time or memory
benchmarks.

Array results, wrapper element arrays, borrows, slices, and for-header calls
remain unavailable. `main` remains zero-argument i32, and calls to `main` in
array programs remain rejected.

## Verification

```powershell
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice parameters
./build/browniec.exe run examples/array-parameters.brc --fuel 100000 --json
```

The focused selection covers eight source-parameter groups, six signature
groups, six helper-local groups, four propagation groups, and four scalar
function groups. The new CLI matrix covers all six element domains, immutable
and mutable inputs, mixed parameter positions, three distinct eight-argument
orders at the catalog/owner caps, snapshot timing, nested Option/Result failure,
loop transfers, recursion, maximum payload peaks, exact Fuel, unsupported forms,
and the checked example. A malformed IR test independently rejects missing
cleanup for a pending capture.

Both development and release passed 28 native groups and 2,475 CLI cases each:
426 existing array, 80 parameter, and 1,969 scalar cases. The receipt baseline is
`c53eb4fbbb16d729dadc99ee0ffd26914c6ea4e6`, following implementation commit
`ca7846e70359ee7e13c26f92ef4896387fbab9cb`. Fairy C revision `4ce1264273be`,
compiler SHA-256 `572395f7f1e425d613c5a69f50b30ed177cda37ca2b1638bd0c11cf79fcbcc77`,
and Python 3.14.6 identify the executed Windows x64 environment.

| Profile | Native CLI SHA-256 |
| --- | --- |
| development | `a797e148f48ec37ad17b692920c4873a75baa3408053e097925604ec66013eee` |
| release | `dd76f2d554c1358504388579a8ea2fcdbfbb4f6f90a615b0c781844455cb3427` |

The aggregate attempt stopped at a CLI fixture name collision. After correction,
the affected CLI matrix and remaining steps passed individually. Completed native
selections were retained on unchanged source/test inputs. The aggregate command
above was not rerun after that correction and final receipt-guard tightening.
The stepwise receipt records executed commands, native reports, all 18 CLI receipt
hashes, and exact source inputs; generated fixture hashes match those receipts.

Thirty backend source hashes, including IR, verifier, VM, layout, codec, storage,
and owners, match the private call checkpoint. Their complete native suites are
not rerun. The full
scalar native suite, M0, allocator instrumentation, Linux execution, isolation,
DLL, clean-machine packaging, and performance measurement are skipped.

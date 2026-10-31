# Public readonly u8 slice parameters

Implemented at `6a7d206` on the shared VM lifecycle. Development and release each
passed eleven native groups and 2,605 CLI invocations, with 373 matching input
hashes and retained CLI identities. Public `check` and `run`
now admit readonly `ref u8[]` parameters and explicit `ref name` arguments over
existing lexical slice bindings. Version JSON advertises
`"array_slice_parameters": true`. Result schemas, selected profile names,
default Fuel and the CLI Fuel ceiling are unchanged.

```c
module main;
fn i32 first(ref u8[] bytes) {
    return bytes[0] as i32;
}
fn i32 main() {
    let u8[1] bytes = [42; 1];
    let ref u8[] part = ref bytes;
    return first(ref part);
}
```

Save this as `sample.brc`, then use:

```text
browniec check sample.brc --json
browniec run sample.brc --fuel 1000000 --json
```

## Admission and lifetime

The temporary unconditional borrowed-signature rejection is removed. `inspect`
and public `verify` now call the same complete validator. Origin metadata,
parameter kinds, register partitions, types, initialization, exact borrow live
sets, joins/backedges, call arguments and nonescaping exits still require proof.
Malformed IR remains rejected before Fuel checks or backing preparation.
Unused well-formed borrowed helper signatures no longer reject an ordinary entry.

CALL stages scalar values, atomically copies owned arguments and retains checked
borrowed handles before publishing the child frame. Formal and derived sites
resolve full-width owner tokens through that frame. Caller handles survive child
return. Normal scalar/tagged/array/record return and invocation error cleanup use
the [shared lifecycle](m2-array-slice-lifecycle-vm.md); `?`, lexical blocks and
loop transfers retain the existing reverse cleanup lowering.

The eight-argument, sixteen-static-site/handle and 32-frame bounds remain.
Empty selected ranges and repeated arguments are supported. Forwarding and
recursion remain subject to Fuel and the shared handle pool; they may exhaust
those resources before the frame ceiling. Mutable/non-u8 slices, slice results,
escaping references, temporary-root arguments and borrowing an array directly
as a call argument remain unsupported. Keep an explicit lexical slice binding.

## Fuel and failures

The existing price is unchanged: `1 + arity + owned work + borrowed reserve`.
The borrowed reserve is zero without borrowed formals, otherwise
`65537 * (borrowed formal count + 1)`. Existing slice instruction prices and
full-origin UTF-8 charging still apply. Cleanup uses prepaid reserves even when
execution runs out of Fuel. No payload clone, owner or heap allocation path is
added by this promotion.

The CLI still defaults to 256 Fuel and permits at most 1,000,000. Array backing
preparation alone costs 65,537 at the default capacity. Explicitly budget Fuel
for array/slice programs. The compact one-byte read fixture costs exactly
274,590: preparation 65,537, main instructions 200,822 and callee instructions
8,231. It returns 42 at that budget and reports `fuel` at 274,589. Whitespace in
the example does not change that instruction count.

Static syntax/type/limit failures retain exit 3; invalid IR uses verification
exit 6. Runtime Fuel, arithmetic, bounds and capacity failures use exit 5 and
retain their source offset. `check` proves admissibility without executing code;
an admissible program can still fail during `run`.

## Verification

```text
python -B tools/verify-m2-array-utf8-source.py --profile development --slice-parameters-public
python -B tools/verify-m2-array-utf8-source.py --profile release --slice-parameters-public
```

The selection runs six lifecycle and five borrow-flow native groups in two
bounded compiler invocations, retaining both original reports. Public wrappers
execute the lifecycle fixtures, including capacity failures. Corrupted IR tests
assert rejection by inspect, verify and zero-Fuel public VM entry points.
The CLI selection covers 64 new public cases, 74 promoted source/limit cases,
452 existing related M2 cases, 2,007 M1 cases and eight basic sentinels.

The [Windows receipt](../evidence/m2-array-slice-parameters-public-windows-20261101.json)
records actual commands, outcomes, input hashes and retained CLI identities.
The public host VM also tests handle-pool exhaustion with a higher explicit host
budget; the CLI keeps its existing ceiling. Full native suites, other M2 matrices,
Linux, M0, isolation, packaging and performance were not rerun.

# Ordered exclusive-slice element assignment

Date: 2026-11-06. Successor to [slice-place execution](slice-place-execution.md)
and [owned-array source assignment](array-place-assignment.md).

## Source semantics

An exclusive scalar slice now lowers `p[index] = value` to kind-one SELECT,
STORE and common END. The index evaluates once and SELECT checks its bounds
before the RHS executes. A bad index therefore fails before a RHS return or
divide by zero. Source no longer emits the legacy slice STORE opcode 60.

The five existing integer domains admit statement-only `+=`, `-=`, `*=`, `/=`,
`%=`, `<<=`, `>>=`, `&=`, `^=` and `|=`. Compound lowering inserts READ before
the RHS and applies the existing exact-type checked scalar operation before
STORE. Plain bool assignment remains supported; bool compounds, assignment
expressions and pure-for-header writes remain rejected.

The selected index and old scalar survive RHS mutation, nested owned-array and
slice places, mutable CALLs and lexical reborrows. Array and slice places share
the same sixteen frame-local IDs and pending mask. Runtime authenticates the
original snapshot against the canonical ticket after restoration; the compiler
does not cache a suspended ticket or guess a replacement one.

A lexical snapshot carries pending-place obligations into the RHS. Returns,
failed propagation, break and continue end abandoned places before existing
owner/view/handoff cleanup. Inner loops preserve surrounding selections. This
reuses the existing cleanup mechanism without consuming a guest local/register;
all 64 bindings remain available and thirty sequential compounds reuse an ID.
Aborts retain prior payload effects and use prepaid cleanup without replay.

Version JSON adds `slice_selected_place_assignment` and
`slice_element_compound_assignment`. Existing instruction prices, source/profile
limits, public default 256 and ceiling 16000000 remain unchanged. Record-field,
scalar-local and grouped places, generic aggregate overlap, broader resource
joins and full L04/C05/Instance/host/delivery remain separate work.

## Deliberate source Fuel change

Earlier source plain stores used a late-checking single instruction. Ordered
selection now pays extended setup and SELECT/STORE/END; compounds also pay READ
and checked arithmetic. This changes emitted source IR and its total Fuel,
without repricing existing instructions or increasing the public allowance.

For one place ID, setup is `257 + 10 * (1 + 32 * (14 + 1)) = 5067`.
An i32 slice SELECT/READ/STORE/END costs 4129/4166/4170/22. Public backing setup
costs 65537. The following complete bodies return the actual stored element:

```c
var a=[0;1];  let ref mut i32[] p=ref mut a; p[0]=42;  return p[0];
var a=[20;1]; let ref mut i32[] p=ref mut a; p[0]+=22; return p[0];
```

| Entry | Plain write | Compound |
| --- | ---: | ---: |
| Native ordinary, four backing bytes | 87285 | 91452 |
| Public ordinary, 65536 backing bytes | 152817 | 156984 |
| Forced retained public entry, no marker | 496889 | 501057 |
| Public retained source with an unused byte marker | 496907 | 501075 |

Ordinary bodies cost 82213/86380. Retained execution adds 147456 entry,
196608 leave and eight/nine dispatch units; the source marker adds eighteen
units. Native tests check exact and one-short boundaries; public CLI checks
one-short, exact and one-more independently. The existing slice-write CLI
oracle now includes the new lowering rather than its old opcode-60 price.
The independent public Fuel oracle also recognizes kind-one place operations
and invocation setup. Eight mutable arguments still fit the public ceiling.

## Verification

Run `python -B tools/verify-static-execution.py --profile development
--selection slice-place-assignment`, repeated for release. The focused selection
contains six new source groups and eleven existing assignment, mutable-slice,
reborrow, public Fuel and captured-call boundary groups. It covers all fifty
integer/operator pairs, mixed nested places, bounds-before-RHS, checked errors,
nonlocal cleanup, all return kinds, exact Fuel, 64 bindings and ID reuse.

For each profile, build and check public CLI Fuel using
`tools/verify-public-fuel.py --phase cli`, then run these checkers against that
profile's copied executable:

- `tools/check-slice-place-assignment.py`
- `tools/check-m2-slice-exclusive-source.py`
- `tools/check-m2-slice-mutable-parameters-source.py`
- `tools/check-m2-slice-reborrow-source.py`

The CLI checkers use a cleared, tool-free PATH. Final identities and executed
results are recorded in
[Windows evidence](../evidence/slice-place-assignment-windows-20261106.json).
Full language/original full native Fuel matrices, Linux, OOM injection, general
stack/performance characterization, worker isolation and clean-machine delivery
are outside this focused check.

Windows development and release each passed **17 native groups** and **533
tool-free CLI cases**, using fresh executions and no native stack overrides.
Native/public Fuel receipts cover 178/180 inputs; the union with four CLI
checkers and their examples contains 194 checkout-matching paths. Of these,
189 match staged Git raw bytes; two selected legacy test files, two
unchanged legacy checker scripts and one example differ only by CRLF/LF. Both
raw hashes are recorded, without rewriting historical receipts or normalizing
unrelated files.
The three old CLI checkers lack their own input snapshots; their unchanged
scripts/examples were identified after execution and every generated case hash
was checked. Both locked LF mirrors pass with 167 LF production modules
and common 289-file discovery. 38 unselected legacy discovery fixtures also
differ only by CRLF/LF. Existing earlier receipts keep their historical scopes;
the skipped scopes above remain unverified by this selection.

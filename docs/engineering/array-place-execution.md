# Owned-array places in both VM drivers

Date: 2026-11-06. Successor to the [independent IR proof](array-place-ir.md)
and [metered snapshot storage](array-place-storage.md).

## Admission and dispatch

Ordinary executable admission now accepts the four independently proved owned
scalar-array place instructions. The ordinary and retained/reference-aware VM
drivers use the [common binding adapter](slice-place-execution.md), delegating
owned arrays to `place_vm::step` over their actual invocation owner table,
frame token bindings, backing bytes and register window. A parent snapshot stays
in its own frame during nested CALLs, even when the child uses the same place ID.
Frame reuse and every normal scalar/aggregate/reference/void return require an
empty place counter before existing ownership/loan transfer or frame release.

Both entry routes preflight snapshot setup alongside existing list/backing/entry
work before allocating backing or transferring owners. Setup is charged once;
the instruction loop never allocates place metadata. Native vector destruction
disposes of all snapshots on every result. Existing VM failure cleanup still
drains owners/loans at zero remaining Fuel and preserves earlier payload effects;
no failed guest work is replayed.

Returned-reference lifetime analysis rejects SELECT, compound READ and STORE on
a protected owned root, including after its original source loan closes but a
returned alias still exists. The repeated array operand is checked independently
against SELECT. The recipe proof also counts the usize index of SELECT and scalar
operand of STORE as reads: a private returned-result selector cannot be reused as
an ordinary scalar. END is an allowed cleanup instruction before terminal handoff
and inside a proved CALL-binding cleanup recipe; it does not transfer authority.

The gates for other reference domains and place kinds retain their existing
meanings. No guest source place/compound syntax, capability flag, bytecode loader,
Engine quota/stepping/deadline API or generic aggregate overlap proof is added.

## Exact Fuel example

The native fixture initializes `i32[2]` with 20, selects index zero, reads its old
scalar, adds 22, stores through the captured location, ends the place and returns
the actual array element. It has twelve instructions and a 387-unit ordinary
body, plus one 3457-unit snapshot setup. Independent numeric boundaries are:

| Entry | Required Fuel |
| --- | ---: |
| Ordinary native, backing eight bytes | 3853 |
| Public ordinary, backing 65536 bytes | 69381 |
| Public retained/reference driver | 413452 |

The retained total adds 147456 for entry, 196608 for leave and seven additional
aggregate/place dispatch units. Its five scalar/return instructions already pay
their single dispatch unit; these are not counted twice. Exact and one-more
budgets return 42; one-short traps. Every run starts with fresh invocation state,
including repeated execution of the same retained Program.

Existing operation prices, CLI default 256 and ceiling 16000000 remain unchanged.
Only programs containing the new operations pay snapshot setup. The full accepted
Engine memory-accounting and cooperative execution requirements remain separate.

## Verification and remaining source work

Run `python -B tools/verify-static-execution.py --profile development
--selection array-place-execution`, then repeat for release. The selection uses
native IR/VM execution, retained Program admission, returned-owner/recipe checks,
existing void exact costs and original ordinary/retained 32/33 CALL bounds.
See [Windows evidence](../evidence/array-place-execution-windows-20261106.json).

Windows development/release each passed 23 native groups and 57 tool-free public
Fuel CLI cases. Native selection used 173 inputs; CLI selection used 176 inputs;
their 183-path union matches staged Git bytes and the checkout. Both profiles
share 282-file discovery, 163 LF production modules and successful locked LF
mirrors. The original 32/33 ordinary/retained CALL boundaries and existing void
exact/full-register checks pass. Forty-one unselected discovery fixtures retain
only CRLF/LF differences, recorded with both hashes. No old result or native
stack/compiler/linker override was reused. Full language/original full native
public Fuel matrices, Linux, OOM injection, general stack/performance, isolation
and delivery were not rerun.

At this checkpoint source assignment still used the earlier lowering. Next, emit selection and its
bounds check before RHS evaluation, retain old scalars before compound RHSs, and
end pending places on every normal exit. Then extend to exclusive slices, record
fields and scalar locals/grouped lvalues. Complete L04, wider language/resource
types, Engine/host/isolation/platform/delivery work remain open.

The [compiler cleanup prerequisite](array-place-cleanup.md) now tracks pending
locations through lexical snapshots and loop scopes, ending them before normal
return/propagation/loop-transfer cleanup. Source selection/compound emission is
still the next step; the preceding execution evidence retains its checkpoint.

The [source successor](array-place-assignment.md) now connects ordered selection,
old-scalar capture, all ten integer compounds and nonlocal cleanup for owned
scalar-array elements. Its changed source Fuel oracles supersede the old plain
write values; other place kinds and full L04 remain open.

# Aggregate conditional joins

Date: 2026-11-06. Private source-lowering foundation; guest aggregate-valued
conditionals are not enabled by this increment.

`value_join_source` describes an initially absent destination for one exact
scalar/tagged type, fixed scalar array shape or nominal plain record. A first
owned whole value can supply the destination. Named values copy, and subsequent
arms can initialize the same destination directly. Constructor record leaves
initialize it without an intermediate record owner. The recipe is compiler
scratch, never runtime authority or a new VM opcode.

Every continuing branch must initialize the same result. Arm-local owners must
be released after capturing the value, and terminal branches must use existing
nonlocal-exit cleanup. The independent CFG verifier remains responsible for
matching live sets and definite initialization; a source recipe cannot bypass it.

Windows development native execution passed two groups in
`tests/m2/value_joins.fy` with:

```text
build/toolchain/fairyc.exe test --native --capture-output --json --file tests/m2/value_joins.fy
```

Both selected boolean outcomes run for arrays and records using one catalog site
and exactly four backing bytes. A three-byte quota fails. Canonical branches
with missing or duplicate initialization are rejected by independent admission.
This is focused native evidence, not public source or retained-execution evidence.
Release, public CLI and complete profile checks were not run for this foundation.
Existing operation prices, default 256 and CLI ceiling 16000000 are unchanged.

The [source successor](aggregate-if-expressions.md) now connects these recipes
to public array/record conditional values; its separate evidence owns that claim.

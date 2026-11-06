# Constructor constraints for value joins

Date: 2026-11-06. Private source-lowering foundation; public branch inference is
not connected by this increment.

`value_join_source` can intersect constructor constraints over the six existing
Option/Result types. None supplies two Option alternatives; some supplies its
exact i32/bool domain. Ok/err supplies one Result domain without guessing the
other. A complete typed value contributes one exact alternative. Every
continuing arm constrains the same recipe, including mixed nested value tails.

The recipe records provisional constructor registers in two 64-bit words.
Once exactly one type remains, finish assigns that existing type to those
registers and the result slot before emitting its load. Payloads are evaluated
once; their values, types and instructions are never replayed or rewritten.
Ambiguous/conflicting constraints fail instead of publishing a guessed result.
The final patch visits at most 128 existing registers and allocates no heap
storage. Scalar/aggregate paths without constructor candidates retain their
original behavior.

No type ID, opcode, runtime tag, verifier authority or price is added. The
ordinary independent type/CFG verifier must admit the complete final Program;
changing a constructor register to an incompatible existing tag is rejected.
Wider/resource-bearing wrappers remain separate L05 work.

Windows development native execution passed four groups with:

```text
build/toolchain/fairyc.exe test --native --capture-output --json --locked --file tests/m2/constructor_joins.fy
```

The tests cover all six existing types, both branch orders and selected paths,
known-value constraints, pending registers above/below 64, ambiguous domains,
conflicting families and independent rejection after tag corruption. The root
locked package builds with 160 LF modules. Release, source and CLI verification
remain for the source successor; no public capability is enabled here. Existing
Fuel default 256, ceiling 16000000 and all other limits remain.

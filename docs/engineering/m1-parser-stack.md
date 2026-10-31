# Parser stack containment

Status: Implemented at `10822ee` and `6cbe716`; Windows verification is recorded
in the [dated receipt](../evidence/m1-parser-stack-windows-20261031.json).

## Failure and repair

The development CLI crashed with Windows `0xC00000FD` while checking the valid
`arm-depth-mixed-10` fixture. This was already present before the Fairy C upgrade;
the [adoption record](toolchain-setup.md#known-baseline-failure) remains historical.
A separate valid chain of 32 nested scalar calls reproduced the same crash.
Both failures occur in `check`, without guest VM execution.

The expression and structural limits were already checked. However, the native
development backend reserves scratch for every branch of a function at entry.
The combined statement handler and operand handler accumulated that scratch on
recursive paths before reaching their existing depth limits.

`control` now dispatches to separate transfer, switch, for, while, return and if
handlers. `operand` delegates identifiers to `named_operand`, which delegates
local scalar, array, record and slice reads to `binding_operand`. Nested calls do
not carry the scratch for local indexing or field reads. Context, evaluation
order, scope restoration, owner cleanup and error propagation are preserved.
All parsing and lowering remain in Fairy C. The SDK/compiler selection is unchanged;
only the root source identity in `fairy.lock` changes.

The depth checks and budgets are unchanged: mixed switch/statement depth 10 is
accepted and 11 is rejected with `compile_limit`; call-expression depth 32 is
accepted and 33 is rejected. Separate structural and expression budgets still
allow 32 blocks containing 32 parenthesized expression levels. No source
capability, opcode, Fuel schedule, VM frame rule or borrowed-signature gate changes.

## Native frame inspection

For the adopted compiler, emitted Windows C was compiled with MSVC 14.51.36231,
`/std:c11 /TC /MT /Od /c /FAs`. This inspection measures prologue stack
reservations; the emitted inspection unit is not substituted for the native CLI.

| Handler | Before, bytes | After, bytes |
| --- | ---: | ---: |
| Common statement dispatcher | 20,920 | 1,464 |
| Operand dispatcher | 10,424 | 5,208 |
| Identifier handler | Included above | 2,408 |
| Local binding reader | Included above | 3,304 |

The common statement reservation falls by 93%. The selected statement helper
also has a frame: for example, `control_if` reserves 2,680 bytes. The nested-call
operand path uses the operand and identifier frames but not the binding-reader
frame. These values exclude saved registers, call overhead and other active
frames. They are not peak process stack measurements or cross-platform guarantees.
Parsing still uses bounded native recursion; this change adds no heap allocation.

## Verification and reproduction

Both development and release passed the full M1 CLI matrix of 2,007 cases and
six focused native switch-arm groups. The CLI matrix includes 38 new check/run
cases covering mixed, block, return, while and for arms at depths 10, 11 and 32;
scalar calls at depths 32, 33 and 64; and combined structural/expression budgets.
Each profile also passed 328 M2 CLI cases: array call reads (106), record call
reads (102), and slice aliases (120). CLI checks run with a cleared environment
and tool-free PATH. The receipt records compiler/image hashes, commands, outcomes,
127 input hashes and the shared regression fixtures.

Reproduce builds with `fairyc build --locked` and `fairyc build --release --locked`.
For each retained image, run `python -B tools/check-m1-cli.py --exe IMAGE --profile
PROFILE`, plus the three `tools/check-m2-*.py` commands recorded in the receipt.
Run focused native groups with `fairyc test --native --capture-output --json
--file tests/switch_arm_statements.fy --locked`, adding `--release` for release.
The receipt records the equivalent explicit-target CLI build commands actually used.

The full 84-group native M1 suite and other M2 matrices were not rerun. Linux,
M0, clean-machine packaging, isolation and throughput were not tested. This closes
the reproduced parser crashes for the recorded Windows profiles and fixtures;
it does not establish safety for every possible source or host stack size.

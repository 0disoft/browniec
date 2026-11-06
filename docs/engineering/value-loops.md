# Private typed lexical loops

The private typed-source path connects while and classic for with lexical break
and continue. Conditions are bool, bodies reinitialize their own declarations on
each runtime visit, and every loop remains possibly zero-trip for return proof.
A while owns transfers in its condition and body. A for continue reaches its
shared post; break and return skip the post. For headers retain the existing pure
scalar restrictions: no CALL, propagation or control-value expressions. Post
validation occurs before the body; only scalar scratch IR is rewound and an
unreachable post is not emitted. Typed allocation is never rewound.

## Owners and Result fixed points

Each loop keeps indices into the bounded compiler snapshot pool. Break and for-
continue snapshots survive nested branch-scratch release by stable-prefix
compaction and checked index rebinding. They close only when their loop resolves.
Transfers close
all names and anonymous values created since the loop entry. Backedges preserve
the exact header initialized set; a moved outer owner must be restored before
repetition. Break exits may differ. Explicit exit trampolines converge through
real reverse cleanup to their initialized-set intersection, including the zero-
trip path. No conditional drop flags or owner restoration is added.

Result policy uses compiler-only summaries F(p) = generated | (p & ~kills).
Fresh evaluations generate their own bit; acknowledgments kill incoming bits.
Implicit drop, replacement and return preflight record required input bits.
Continuing joins intersect kills and union generated bits; required bits remain
monotonic even across terminal alternatives. A loop header's least pending fixed
point is H = initial | backedgeGenerated. Requirements are checked against H and
all exits apply their own summary to H. Nested loops compose summaries, so a
second-iteration discard cannot pass just because first entry was already handled.
A Result produced in a body may be acknowledged by the next condition. Cleanup
on break still checks it because that edge skips the condition.

All instructions use the existing independent scalar/typed CFG proof and native
VM. BACK22 remains the only backward branch. No opcode or existing Fuel price
changes; default 256 and CLI ceiling 16000000 remain. Public source/CLI gates and
capabilities remain unchanged.

## Validation and remaining work

Run `python -B tools/verify-value-loops.py --batch source --profile development`
and its native/release counterparts. The disjoint selections contain seven
source and three summary-helper groups. Final results and identities are recorded
after validation. Preserve the existing admitted 32/rejected 33 combined fixture
without a native stack override. Public composition, useful Buffer operations,
general aggregates/references/modules and the wider runtime/Engine/Instance/host/
isolation/embed/platform/delivery work remain open.

# Native element-list IR and execution

Date: 2026-11-06. Successor to [atomic list storage](array-list-storage.md).
This connects native IR, complete admission and both VM drivers. Guest element-list
syntax remains a separate L03 integration step.

## Candidate encoding and independent proof

Opcode 80 is `op, destination array, pool start low, pool start high, 0, 0, 0, 0`.
The destination's canonical array length gives its exact arity. A copyable
Program owns a 4096-byte scalar-register operand pool and its used count. Each
instruction owns the next dense span in instruction order; spans cannot overlap,
skip bytes or leave dangling entries. Unused pool bytes must be zero. Repeated
references to an immutable scalar register are valid.

`ir::array_values` checks the complete candidate before appending it. Complete
admission reconstructs spans from actual instructions and combines them with the
existing canonical function CFG. Every cell must be defined on every incoming
path, belong to the exact function, carry the exact element type, and be neither
a mutable slot nor an aggregate/reference-formal position. All reserved bytes
are checked. Existing live-owner, formal-owner and borrow exclusions govern the
new destination. Returned-call identity analysis also recognizes all list reads.
Image/reference recipe analysis accepts the new ordinary operation, while full
scalar/owner/loan proof remains mandatory before retained admission.

The existing 128-register, 256-instruction, sixteen-array-site and 4096-element
bounds remain. The operand pool is a separate 4096-entry whole-Program compile
budget; it is not a new permanent source-language arity rule. The copyable Program
grows by the pool and its count, not by a payload or runtime owner table. No
external bytecode loading or stable bytecode ABI is introduced.

## Invocation scratch and publication

Each invocation computes the maximum element count M and encoded byte count S
across every list instruction, including callee bodies. It initializes one
`Vec<i64>` and one byte Buffer before guest execution, reuses them across loops
and CALLs, and destroys them on every exit. Programs without list instructions
allocate neither scratch backing nor pay its setup charge. Scratch stays outside
the copyable owner/token state and outside the per-frame maps.

Each instruction preflights Fuel, checks its fresh destination and scratch bounds,
gathers register cells and invokes the atomic storage/owner primitive. Token
publication follows complete initialization. Errors preserve prior backing and
owner metadata; only discardable scratch may change. The retained driver stages
its existing owner/token plan and publishes that plan only after success.

The ordinary entry includes scratch setup in the budget check before backing
allocation. Retained public entry does likewise; its native coordinator prepares
scratch before entering or copying borrowed/owned arguments, and subtracts setup
exactly once. Scratch allocation failure therefore cannot first change incoming
owner/loan state. The mandatory retained abort still covers later execution errors.

Initialized scratch payload is `8*M + S`, at most 65536 bytes. This is separate
from the guest aggregate backing limit. Full Instance accounting must also cover
actual allocator capacity, metadata and all other VM storage; this increment does
not implement R02/R03/R04 or resumable/chunked list initialization.

## Fuel

| Work | Charge |
| --- | ---: |
| Setup without lists | 0 |
| Setup with lists | `257 + 2*M + S` |
| One list of N cells and B encoded bytes | `56 + N + 3*B` |

Setup covers a bounded 256-instruction scan, cell initialization and prepaid
vector destruction, and encoded-byte zeroing. Instruction cost covers register
gathering, full codec staging, payload copying, existing bounded owner metadata
and worst-case alignment padding. Its ordinary price includes dispatch. As with
existing aggregate operations, the retained coordinator also charges its separate
one-unit dispatch; no retry selects another schedule. Existing operation prices,
the 256 CLI default and the 16000000 ceiling remain unchanged.

## Verification commands

```text
python -B tools/verify-static-execution.py --profile development --selection array-list-execution
python -B tools/verify-static-execution.py --profile release --selection array-list-execution
```

The selection includes six list groups and three affected regressions. Independent
numeric oracles check exact/one-short/one-more ordinary and retained budgets.
Other cases cover all six scalar domains, full 4096-operand/32768-byte execution,
quota and bad-cell rollback, no scratch growth, forged pool/type/definition/owner
metadata, ordinary by-value array returns through three CALLs, legacy Fuel/loop
behavior and both compiler routes' original 32-deep call boundary.

## Next source step

Lower `[x, y]` and inferred declarations with left-to-right one-time evaluation,
exact type/arity and nonlocal-exit cleanup. Distinguish `[filler; N]` without guest
evaluation in lookahead, and keep names unpublished until the final initialization.
Preserve existing repeated initializers. Native full-length operand support does
not remove the separate source/register/compile limits or complete all of L03/C05.

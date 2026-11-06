# Ordered aggregate assignment source lowering

Date: 2026-11-07. Source successor to
[aggregate-place execution](aggregate-place-execution.md) and
[compiler selection/cleanup](aggregate-place-cleanup.md).

## Capture the destination before the RHS

Whole fixed scalar-array copy, self-copy, repeated fill and element-list
assignment now emit kind 3 SELECT before evaluating their RHS. Whole-record and
exact nominal child assignment emit kind 4 SELECT after resolving the target
path and before RHS expressions or CALLs. Bare and parenthesized targets/RHSs
use the same path. Existing if/switch values and CALL-result projections compose
through their existing typed staging and exact-shape checks.

The compiler snapshots its lexical table with the new pending ID, then passes
that snapshot through RHS expression lowering. Inner assignments, value arms,
argument evaluation, returns, propagation and loop transfers therefore see the
pending outer destination. Successful copy/value stores are followed by END,
then anonymous result-owner drops. Existing slot staging preserves one-time,
left-to-right list and constructor evaluation. Repeated fillers execute once.

Array fill/list and record constructor replacement allocate no extra guest owner
or payload extent. Array/record CALLs retain their existing anonymous result
site until the selected store completes. Child projections retain the complete
source owner until its selected subtree has been copied. Native transactions
continue to revalidate the captured destination before atomic publication.

All five place kinds share sixteen frame-local IDs and preserve all sixty-four
lexical names. An inner loop exit ends its own selections while keeping those
surrounding the loop. Ordinary, aggregate, reference and void returns and `?`
cleanup end abandoned selections before owner release or result handoff.

Immutable destinations, borrowed-array writes, wrong element types/lengths,
wrong nominal record types and aggregate compound assignment remain errors.
There is no new source grammar or capability flag. The public Fuel default 256,
ceiling 16000000 and all existing per-instruction prices remain unchanged.

## Source Fuel changes

Programs with aggregate selected places use the existing eighteen-word rows,
one invocation setup and END 26. Old whole-array/record source assignments now
emit selection and finalization, so their complete source budgets deliberately
change. Unaffected source keeps its original lowering and prices. Program-wide
setup includes the highest pending ID in every admitted function and is not
repeated on CALL. Native APIs retain host-selected budgets independently of CLI
policy.

The five straight-line fixtures in `tests/m2/aggregate_place_assignment.fy`
have one aggregate ID, setup 6367 and the default 65536-byte public backing:

| Assignment fixture | Ordinary public | Forced retained public | Actual retained marker |
| --- | ---: | ---: | ---: |
| Two i32s copied from another owner | 72496 | 416568 | 416586 |
| Two i32s filled with 42 | 72351 | 416421 | 416439 |
| Two i32s replaced with `[20,22]` | 72670 | 416741 | 416759 |
| Two-field nominal record copied | 460112 | 804185 | 804203 |
| Two-field nominal record constructor | 369935 | 714006 | 714024 |

These independent numeric oracles include backing preparation, complete source
IR and terminal cleanup. Slot allocation consumes a bounded register cell but
emits no instruction; constructor literals, slot STOREs and LOADs are charged.
The unused marker adds an OPEN charge 16 and two dispatch units, total 18.

For the two-element i32 array fixtures, old copy/fill/list transaction charges
are 89/65/75. Their selected stores cost 186/162/172; each additionally pays SELECT 97,
END 26 and setup 6367, a 6587 increase where no earlier place setup existed. Record
SELECT is 41057; selected copy/constructor stores cost 172129/128162. Mixed
scalar/slice/record programs derive their larger shared setup and END costs from
the same existing schedule, rather than applying a blanket fixture delta.

The pre-existing list-assignment oracle in `public_fuel.fy` changes 66083 to 72670.
The other twenty-three shared public source oracles stay unchanged. Earlier
assignment contracts retain their historical IR and verification scope; the
table above is the current source checkpoint.

## Verification and remaining work

Run `python -B tools/verify-aggregate-place-assignment.py --profile development`
and repeat for release. `--phase native` and `--phase cli` expose the selections
separately. Four native groups cover ordered IR, no extra owner, exact Fuel,
grouped/CALL/child/if values, mixed place kinds, return/propagation/loop cleanup,
type/borrow rejection and all sixty-four names.

Each profile also runs 169 aggregate source CLI cases with PATH/TEMP/TMP cleared
to a directory without runtime tools. The matrix covers all six scalar array
domains, bare/grouped copy/self/fill/list, actual retained routing, five independent
Fuel triplets in both public routes, nested owner/field updates, once-only fill
and left-to-right list effects. The existing 105 public Fuel CLI cases run through
the same final executable, for 274 CLI cases per profile.

Resource/tag copy/move rules, grouped borrows, reference/Buffer joins, complete
L04/C05/Engine/Instance/host/isolation/platform/delivery remain open. Full language/
native Fuel matrices, LF mirrors, Linux, OOM injection, general stack/performance
and clean-machine delivery are not covered by this selection. Local commits do
not authorize push, release or deployment.

Windows development/release each passed **4 native source groups and 282 CLI
cases**, implemented at `de0b4a0`. The total combines the main 274-case selection
and eight additional public array/record reference-return and switch cleanup
cases, whose sources, commands and results are embedded in the evidence. Both final native
selections run fresh. The 197 current inputs match checkout and Git raw bytes;
all 178 production modules are LF, and discovery has 307 test files / 1834 annotations.
The helper prerequisite's 182 inputs separately match historical commit `ecf9cbb`;
its two-per-profile native result is not counted as a fresh source-suite pass.
See [Windows evidence](../evidence/aggregate-place-assignment-windows-20261107.json).
The discovery inventory is not a full-suite pass. No native overrides or
historical runtime result reuse, push, release or deployment was used.

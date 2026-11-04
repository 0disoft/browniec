# Returned-view Fuel and CLI limit reconciliation

Date: 2026-11-04. Scope: the independently admitted private returned-view VM,
including explicit native owned inputs. Public returned-reference declarations
and result bindings remain unavailable. This supersedes the provisional private
`80 * 65537` reserve in earlier increment documents.

## Schedule

`src/fuel.fy` owns the schedule. Fuel counts abstract bounded work, not CPU
instructions, milliseconds, compiler-generated copies or allocator bytes.
Each dispatched instruction still consumes one unit, including deferred terminal
cleanup markers. Array/record operations keep their existing public prices.

| Work | Fuel, in addition to instruction dispatch |
| --- | ---: |
| CALL/native entry metadata, including emergency cleanup reserve | 147456 |
| Borrowed return metadata, including final Held cleanup reserve | 294912 |
| Ordinary scalar/array/record return metadata | 196608 |
| Formal argument transfer | arity, once per entry |
| Owned argument copying | Existing `struct_call_vm::cost`, once per entry |
| Slice OPEN/SUB/BEGIN/END | 65537 |
| Slice length or nonterminal CLOSE | 4097 |
| Slice read | 4130 + element stride |
| Slice write | 4130 + 2 * element stride |
| Slice UTF-8 predicate | 4097 + 4 * validated root length |
| Held final close / terminal invocation abort | Prepaid; no additional Fuel |

The UTF-8 price uses the complete root length, as existing public formal-slice
execution does, conservatively covering a shorter subview. Resolve the ticket
under the base allowance, then check the scan allowance before reading payload
or writing the destination register. Six scalar types have stride at most 8;
the u8 root length is at most 4096, so pricing arithmetic cannot overflow.
Both existing public shared/formal helpers and the private adapter use the same
slice price functions. Other public helper paths retain their equivalent prices.

## Bounded metadata audit

One logical visit examines a bounded metadata record, or copies/writes one
bounded record/array cell; scalar arithmetic within that record is constant work.
These are conservative algorithmic allowances, not measured CPU limits. A change
to capacities or nested scans requires re-auditing the schedule.

- Owner validity visits at most 16 allocation-order entries and 16 slot-tail
  entries: 32 owner visits. Record allocation metadata does not traverse payload.
- Pool validity visits 16 entries. Charging every entry both the most expensive
  shared-owner resolution (two owner-validity passes) and the exclusive alias
  scan over 16 pool slots overestimates even an impossible mixed worst case:
  `16 + 16 * (2 * 32 + 16) = 1296` visits.
- A pool primitive allowance is 2048. Besides that validity pass it covers
  bounded free-slot/alias scans, direct owner validation, the 31-entry authority
  check and 8-ticket receipt get/put used by a child operation. Payload codecs,
  copying, catalog planning and UTF-8 walks are priced separately.
- Entry authenticates at most eight actuals, validates/rotates at most eight
  writers, and retains each reader once. With `w + r <= 8`, there are at most
  `8 + 2*w + r <= 24` pool primitives. The fixed 32768 allowance covers bounded
  metadata staging/publication, capture comparisons and VM binding/frame setup.
- Handoff selects once, unwinds at most 30 callee lexical children, authenticates
  eight issued arguments, validates/rotates eight writer restores, unwinds eight
  anonymous caller children and creates one selected child. Across capture,
  callee-readonly and local-root cleanup, at most sixteen live slots can close:
  `1 + 30 + 8 + 16 + 8 + 1 + 16 = 80` successful pool primitives. Any early
  failure stops the transaction; 96 allowances include that failing attempt
  and margin. Sixteen local-root scans of sixteen slots, at most sixteen owner
  releases and 8-by-31 pending-child scans fit the separate 32768 fixed allowance.
  Lexical CALL binding publication additionally scans at most 8 * 256 = 2048
  instruction records for masked BEGIN parents and at most two 47-record Held
  registry passes, plus direct frame-site updates. These bounded additions remain
  within that fixed allowance and add no payload-length term.
- Ordinary return has no selected result installation/caller-capture cleanup:
  `30 + 8 + 16 + 16 = 70` pool primitives; reserve 80 plus the fixed allowance.
- Abort validates the pool once, closes at most sixteen slots, clears sixteen
  owner records and 31 authority entries/248 ticket-lease pairs. Held close uses
  at most three pool primitives plus a single root release. The cleanup reserve
  is `24 * 2048 + 16384 = 65536`, covering either finalizer's bounded metadata.

Therefore entry is `32768 + 24*2048 + 65536`, handoff is
`32768 + 96*2048 + 65536`, and ordinary return is `32768 + 80*2048`.
All are independent of payload length. The native coordinator's lower-level
`enter_arrays`/`enter_records` allowances cover metadata only: their VM callers
must also prepay the separately computed public aggregate-copy cost. These
trusted building blocks are not independent public guest execution entry points.

## Prepayment and failure semantics

Entry and handoff reject insufficient Fuel before transactional mutation.
Initial owned entry includes aggregate-copy and formal-transfer costs in the
same preflight. Internal CALL does the same; ordinary return prepays its phase
and any existing aggregate-result transfer charge. No phase gets charged twice.
The historical native `runtime::cost()` now names entry only; native handoff and
ordinary return callers use `handoff_cost()` and `leave_cost()` respectively.

Entry prepays emergency abort; successful handoff prepays its issued Held's
finalizer. `close` consumes that linear receipt, preserves the supplied remaining
Fuel, and can execute with zero. It still validates the live generation, view,
descendant restoration and root ownership transactionally. Invalid or consumed
receipts cannot close again. No cleanup reserve is refunded. Native hosts must
not forge/clone receipts or mutate canonical state, as in the existing contract;
this is not a hardened C ABI.

After initial entry, execution failure drains the invocation at zero execution
Fuel, retaining prior payload writes and the first error. Revalidate original
native tokens after any error. Initial admission/preflight failure preserves
owners, pool and payload. Existing quota/payload rejection remains transactional.

## Limit scope and public gate

CLI default remains 256 and accepted `--fuel` remains 0..1000000. `main` reads
both values from the common schedule. The native VM APIs, including existing
ordinary `vm::run`, accept an explicit host-sized Fuel budget; the CLI argument
limit is not a new native API restriction. Deep recursion/longer native tests
may therefore deliberately supply more than 1000000.

Tests separately prove exact whole-invocation/entry/handoff boundaries, one-short
rejection, zero-budget final close, unchanged payload before admission, prior
writes after failure, no duplicate copy charge, and full owner/pool/authority
capacities. Shared and mutable forwarding, an ordinary CALL and native owned
entry finish including final close within 1000000. This does not promise every
admitted program can finish within that CLI budget.

Reproduce on the pinned compiler with `python -B tools/verify-m2-slice-result-fuel.py
--profile development --batch entry`, then `--batch regression`, `--batch runtime`
and `--batch cli`. Repeat with `--profile release`. Native batches may run in
parallel; CLI builds must be serialized because they share `build/browniec.exe`.
Continuation validates input/compiler/report hashes and never accepts historical
native results under changed inputs.

Additional tool-free CLI boundaries use `module main;fn i32 main(){return 42;}`
and `run SOURCE --json [--fuel N]`: default, 2 and 1000000 complete with 42;
0 and 1 return Fuel error/exit 5; 1000001, -1, 9223372036854775807 and
9223372036854775808 return usage error/exit 2. These nine cases are separate
from the verifier's 208 origin/temporary-array CLI regression cases.

This reconciles prices and demonstrated CLI-sized budgets. B04 still requires
general result bindings/lowering, ordinary Program admission/dispatch integration,
end-to-end public source proof and capability promotion. Full-profile limits,
Engine/Instance stepping/cancellation and restricted/embed delivery remain open.

## Recorded Windows validation

Implementation: `275abfd`. Development and release each passed 56 native groups
and 217 tool-free CLI cases, including six new Fuel groups and nine CLI Fuel
boundaries. All 500 final input hashes match across profiles; all 112 production
files match the implementation commit under Git LF. Native batches started at
`c455e54` with the same final inputs, before the implementation commit; their
original starting heads are retained. No changed-input/historical native result
reuse. The exploratory four-group run is not included in final totals.

See [retained evidence](../evidence/m2-slice-result-fuel-windows-20261104.json)
for compiler identity, OS, commands, batch/report/artifact hashes and outcomes.
Full M1/other M2, Linux, isolation, ABI, packaging, allocator instrumentation and
native size/stack/timing were not verified. Local commits only; no push, release
or deployment.

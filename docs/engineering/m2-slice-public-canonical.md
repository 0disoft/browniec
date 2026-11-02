# Public canonical routing for exclusive mutable formals

Status: engineering draft; Windows development and release verification passed.
The production delta is confined to [`src/vm.fy`](../../src/vm.fy); this is a public
routing prerequisite, not public derived opcode or source promotion. See the
[native derived-CALL baseline](m2-slice-derived-call-default.md).

## Entry order and route selection

`run_with_array_limit` still calls `verifier::verify` first. Failure returns before
array-limit checks, Fuel reservation, payload backing, loan/frame construction and
dispatch. Aggregate limit kind 13 and Fuel kind 8 retain their prior order.

After preparation, an existing branch selects canonical routing for exclusive
formals. Programs with no exclusive formal, including ordinary readonly dispatch,
keep `execution::execute` and `lifecycle::finish`.

## Canonical invocation path

The exclusive formal branch now enters `execution::execute_canonical` instead of
the legacy 32-entry mutable Frame receipt path. Before execution it constructs:

- exact empty reborrow Sites, because strict public verification still rejects
  private reborrow opcodes 61 and 62;
- one fresh local `authorityState[1]` from the canonical constructor;
- one fresh local `callBindings[1]` from its constructor; and
- one fresh local `childBindings[1]` from its constructor.

The constructors provide fresh unique roots with empty bindings. There is no second
complete verifier or proof pass and no additional native wrapper. It does not
bypass verification or widen scope. Initial verification remains the Program
authority; empty Sites describes the still-gated private forest.

Every canonical outcome, including a Fuel, bounds, arithmetic, CALL or detached
formal error, passes through `context::finish`. Normal CALL returns perform
canonical restoration. Termination or abort drains the authenticated pool first,
then clears receipts and local maps; abort does not replay reverse CALL return
restoration. A cleanup failure returns its error and preserves the local maps until
scope exit. The public wrapper then disposes its local payload backing and
array/loan/frame views; the native caller-owned contract remains unchanged.

## Unchanged contracts and gates

Instruction and CALL Fuel prices, signature/layout widths, owner and pool formats,
payload limits and profile strings are unchanged. No native size/stack or speed
measurement is reported. The native default wrapper `vm_reborrow_execution` is
unchanged, and its callers retain the native-owned backing and disposal contract.

Public verification, compiler, parser and capability reporting remain unchanged.
Public VM execution of private reborrow opcodes remains gated; native execution
remains available. Public derived source grammar remains gated. The empty Sites
construction is correct only under the current strict public-verify gate; any later
public opcode promotion must change both together in one reviewed slice.

Derived owned and aggregate CALL support remains unsupported and is outside this change.

## Verification status

Windows development and release each passed five native groups (the two new
differential groups plus three existing public mutable groups) and 74 public
mutable CLI cases. [`tests/m2/slice_public_canonical.fy`](../../tests/m2/slice_public_canonical.fy)
compares full results, errors, offsets and exact minimum Fuel with the frozen legacy
engine across mixed owned record/array arguments, ARRAY/RECORD/tagged returns,
shared duplicates and scalar helpers, recursion 29 success/30 frame limit, quotas,
bounds and division.

All 403 current inputs exactly match across both phase manifests; compiler,
native-report, retained CLI artifact and CLI receipt hashes were rechecked. The
[verified Windows evidence](../evidence/m2-slice-public-canonical-windows-20261103.json)
records the passed phases. The sole production delta is [`src/vm.fy`](../../src/vm.fy)
against baseline `a023542`; 97 other production sources match under Git LF. The
public entry body is byte-identical, including verifier-before-Fuel/quota/backing/
selection; the native wrapper, verifier and dispatch helpers are unchanged.

Full native suites, other M2, full M1, Linux, isolation, packaging, allocator,
native size/stack and timing were not rerun. No native size/stack or speed
measurement is reported. Public reborrow opcode admission and derived source
grammar remain separate, as do derived owned and aggregate forms. Local commits only; no push was made.

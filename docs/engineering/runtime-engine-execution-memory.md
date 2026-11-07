# Engine execution and retained output heap admission

The private Engine reserves the reachable SDK heap before VM setup and retains
actual output backing under the same per-Instance, simultaneous-Instance and
tracked Engine ceilings as immutable input. These named classes do not include
native stacks, pending host state, public policy binding or process RSS.

## Exact heap requirements

`runtime_execution_memory::prepare` reads immutable proved IR without allocating.
It uses actual fresh SDK Vec capacity (minimum eight, then doubling), the maximum
list element/encoded-byte requirements and one selected place descriptor format.
It checks every sum/product before evaluating it. Pinned private Windows x64
widths are word/i64=8, input Cell=24 and Published=72 bytes.

For C(n)=0 when n=0, otherwise the first 8*2^k capacity at least n:

```text
S = optional 65536-byte array/record arena + 8*C(list_elements)
    + list_encoded_bytes + 8*C(place_words) + optional 24576 input metadata
ordinary/input transient = S
output/input-output transient = S + 576 + 40 + output_limit
```

Only one selected place Vec exists. With w=max place ID+1, its initialized count
is zero for w=0, otherwise array `32*(9*w+1)`, slice `1+32*(14*w+1)`, record
`2+32*(14*w+1)` or aggregate `3+32*(18*w+1)`. Input descriptors initialize 768
24-byte Cells in a capacity-1024 Vec even for empty input. List element and byte
maxima can originate from different instructions and must coexist.

The Engine caches S when publishing each immutable Program. Budget lookup at
execution is O(1), with no additional scan/heap allocation per instruction or
nested guest CALL. Existing VM verification/preparation work remains unchanged.
`required_execution_bytes` exposes the same cached transient requirement for a
Program and output limit. The explicit typed-value/custom-arena paths are outside
these owning Engine entry variants.

## Reservation and ownership

Let B be the selected Instance's current retained input/output bytes, X the full
simultaneous retained set, C fixed control, P retained Programs and T the next
execution transient requirement:

```text
B + T <= instance_limit
X + T <= instances_limit
C + P + X + T <= engine_limit
```

Quota rejection occurs before VM allocation and leaves the Instance Ready,
its Fuel, existing owners and pins intact. Ordinary operation admission still
consumes its epoch; it issues no object ID. Admitted peaks are reservations,
including allocations that may later fail or Fuel checks that stop setup early.
They are not measured process high-water memory. External effects remain outside
rollback and are never replayed.

After execution, scratch and transaction header have ended. `heap_bytes` measures
Published Vec capacity plus actual backing capacities, including an empty Vec
left by a late failure. A success retains `576+output_limit`, even with zero
emitted bytes; a late failure can retain 576; an early failure retains zero. The
Engine commits only those actual bytes, together with its still-owned input.
Cancellation, completion and Program release do not refund owners. Actual
Instance destruction drops input/output first and refunds their charge once.

## Output transfer

`take_output` performs guarded preflight before reserving its outgoing Vec8,
using the emitted Output width (currently 136 bytes, hence 1088 transient bytes).
The typed operation independently rechecks actual transport backing. Early quota
and reserve OOM spend no epoch/ID and preserve the existing output owner. The
whole Output owner then moves, and its retained bytes leave Engine accounting;
Instance input stays charged. Dropping the Instance cannot refund that output a
second time. A detached result remains valid after Engine destruction. Exhausted
epochs still permit this bounded owning maintenance when memory headroom exists.

## Verification and limits

[Windows evidence](../evidence/runtime-engine-execution-memory-windows-20261107.json)
records implementation `18c93c8`. Native development/O2 each pass seven new
Engine groups, eight planner groups and six output-observation groups, plus all
nine updated input-memory groups and the existing compile/control/retention/
input/output/OS/depth fixtures. The exact-boundary successful dispatch cases
match predicted and measured transient peaks, across all four modes, Vec16 list
scratch and compound indexed places. Ordinary scalar execution allocates zero.
The calibrated failure sweeps inject every allocation ordinal in each mode and
prove SDK high-water bytes never exceed the admitted reservation. Failed owners
are reclaimed, terminal Fuel/events remain stable, and fresh owners recover.

Tests also cover retained peer output plus simultaneous input, independent
combined Engine limits with a peer Program/pin, late failure's empty Vec8,
output extraction's exact/one-less 1088-byte headroom before allocation, moves,
cancellation, detached lifetime and no double refund. Six direct result-query
groups independently measure zero/576/576+limit bytes, header/backing OOM, seal
failure, empty emits, reserved but unused backing and allocation-free observation.
The eight planner tests include all place formats and separately attained list
maxima. Maximum-component shapes are not executable-source admission evidence.

All 228 source/config/tool inputs match checkout and committed Git; seven pinned
SDK runtime objects match their reviewed revision. The transport pins 25 typed
bindings and 18 layouts, including a new concrete Program witness for cached
metadata. Both native images retain default 1MiB/4KiB stacks and zero SDK heap
allocations/bytes at exit, with no compiler overrides. Inline Engine is 736 bytes,
Instance 136; one-slot control heap is 6976 bytes versus 55808 at all-64 counts.
The seven initial SDK control allocations are unchanged in count. The root locked
check passes 253 sources/2885 MIR functions; all 245 production modules retain LF.
The standalone compiler/public CLI were not rebuilt in this accounting slice.
The owning public CLI gates, VM capacities, opcode prices and Fuel defaults/cap
remain unchanged. Native stack accounting/containment, host scratch, immutable
policy binding, bounded steps/cleanup, deadlines/poison, restricted workers and
public lifecycle/embedding remain in the accepted inventory.

# Retained Buffer view execution

This slice connects the native Buffer view registry to independently retained
private IR. Views occupy a separate logical lane rather than canonical owning
value slots or scalar registers. This is an executable runtime foundation.
The [source successor](value-view-source.md) connects lexical `bytes::view`
bindings, ranges and nonlocal cleanup. General reference signatures, returned
Buffer views and public capability admission remain separate work.

## Instruction and proof contract

The eight-byte private instruction format adds the following operations. `v`
denotes one of sixteen view bindings in the current activation, `s` an exact
Buffer value slot, and `r` an ordinary scalar register.

| Opcode | Operands | Effect |
| --- | --- | --- |
| 105 VIEW_BEGIN | dst=v, a=s, b=lo-r, byte4=hi-r | Create a checked Buffer window |
| 106 VIEW_RANGE | dst=v, a=parent-v, b=lo-r, byte4=hi-r | Derive a relative child window |
| 107 VIEW_ALIAS | dst=v, a=source-v | Retain a sibling with the same window |
| 108 VIEW_MOVE | dst=v, a=source-v | Transfer the logical binding |
| 109 VIEW_CLOSE | dst=v | Release this binding |
| 110 VIEW_LEN | dst=usize-r, a=v | Read the initialized window length |
| 111 VIEW_READ | dst=u8-r, a=v, b=usize-r | Read one checked byte |

Unused operands and reserved bytes must be zero. Only 105 and 106 use byte4;
existing CASE keeps its separate byte4 contract. Scalar inputs must be defined
with exact types and scalar outputs must be fresh. VIEW_BEGIN requires a live
exact Buffer. View destinations must be Dead, and accesses require Live sources.

`value_view_flow` independently carries sixteen origin entries per instruction
over the canonical CFG. Each entry is either Dead or the exact current-function
Buffer slot plus one. Aliases, ranges and moves preserve that origin. Forward
joins and backedges require identical origin/liveness states, independently of
the existing owning-value and ordinary scalar proofs. The fixed proof table is
4096 bytes plus 256 seen flags; it introduces no input-sized allocation. Programs
without view instructions skip this additional function analysis.

Any surviving alias, including an empty range, pins its origin against write,
push, reserve, append destination, owning MOVE/DROP, wrapper construction and
owning CALL argument transfer. Reading the root, using it as an append source,
and changing unrelated roots remain valid. Normal returns require no live views
in the returning activation. Views cannot enter owning parameter/result slots;
there is no new signature encoding or escaping guest ticket.

Dynamic bounds remain runtime checks. BEGIN checks `lo <= hi <= Buffer.len`;
RANGE uses the parent's actual initialized window and relative endpoints. A
join may select different windows of the same origin; subsequent operations
authenticate the window actually published on that executed path.

## Native lifecycle

The invocation owns one registry alongside its exact frame/root stores. Logical
view binding identity includes the activation index; recursive calls cannot
confuse equal static view IDs in different activations. Actual ticket and owner
serial/generation words stay in trusted coordinator metadata. Native root
mutation and ownership transfers continue through the existing lease gates.

The registry retains its existing 32-row invocation capacity, shared physical
read leases, generation retirement and prepaid cleanup. These are private
implementation limits, not newly advertised source limits. Caller views remain
live across unrelated calls. Terminal cleanup closes views and refunds registry
metadata before frame abort drains roots, including after execution failure or
Fuel exhaustion. No external effects are replayed or rolled back.

Programs without views retain their prior setup costs. View-enabled invocations
account for the registry's 4096 logical metadata bytes and 256 Fuel admission.
Existing opcode prices and public Fuel default 256 / ceiling 16000000 remain.
No native borrowed slice or owning Buffer escapes through a guest descriptor.

Successful VIEW_BEGIN pays 2080 Fuel for exact frame/Buffer authentication,
then 512 for the descriptor and 256 only when acquiring the first root lease.
Further views on the same root share that lease. RANGE/ALIAS pay 512, MOVE/LEN
256, and READ 513. CLOSE and terminal registry shutdown require no new Fuel.
These private costs compose with setup and ordinary instructions; they do not
change existing instruction prices.

## Verification and follow-up

The focused runner is `python -B tools/verify-value-view-execution.py`, with
`--discover` and `--profile development|release|all` selectors. Verification
results are recorded in [Windows evidence](../evidence/value-view-execution-windows-20261107.json)
and the [input manifest](../evidence/value-view-execution-inputs-windows-20261107.json).
Implementation commit: `10db833`.

Both Windows profiles passed 24 native groups: eight new view execution/proof
groups, fourteen native Buffer/value/registry regressions, and two focused source
regressions. Actual byte reads cover nested ranges, aliases after parent close,
logical moves, empty windows and mutation after last close. The independent
proof rejects pinned owner changes/transfers, stale/moved bindings, malformed
operands, undefined scalar inputs and incompatible origin joins/backedges.
Caller and callee simultaneously use logical view0 over distinct roots.

The actual driver cleanup boundary is called after a zero-Fuel read failure
with two live aliases. It releases the physical read lease and registry metadata
before draining all native root/frame backing; the original error is preserved.
Other fixtures exercise range/read bounds, exact Fuel boundaries and terminal
failure with live views. Existing no-view exact Fuel/quota tests still pass.
The admitted 32/rejected 33 conditional-depth fixture is byte-identical and
executes in both profiles without native stack overrides.

All 221 inputs match checkout and Git raw bytes; all 210 production modules are
LF. Both profiles use fresh locked byte-identical mirrors without historical
result reuse. Full language/public CLI/native Fuel matrices, Linux, allocator/OOM
injection, general stack/performance and clean-machine delivery were not run.

The [source successor](value-view-source.md) now connects the whole-view
signature `bytes::view(ref Buffer) -> ref u8[]`, ranges, lexical bindings and
nonlocal cleanup. Its own evidence owns source behavior; this receipt retains
its original 24-group scope. Next: copy-from-view and general reference
parameter/result composition. Public
AllocError, text/I/O, full Engine/Instance/host behavior, isolation and delivery
remain part of the broader implementation objective.

Successor: [Buffer view copying](value-view-copy.md) now copies a selected readonly
window into an independent owning Result. Its new112/kernel/source evidence is
recorded separately; the verification counts above retain their historical scope.

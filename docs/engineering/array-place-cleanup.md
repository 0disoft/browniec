# Compiler cleanup for pending selected places

Date: 2026-11-06. Successor to [native VM integration](array-place-execution.md).
This prerequisite prepared source exit lowering while guest assignment still
used earlier instructions. The [source successor](array-place-assignment.md) now
connects ordered owned-array selection and compound source syntax.

## Construction state and scope

`locals::Table` carries one private 16-bit pending-place mask in a usize. Its
snapshot preserves the mask alongside the existing lexical names. A selected
location consumes neither a guest register nor one of the 64 name slots. SELECT
reserves the first free ID; an explicit END releases it for sequential reuse.
The seventeenth simultaneous selection fails before emitting another instruction.

This adds eight bytes per native x64 lexical-table snapshot. It does not add an
array to recursive parser frames or change Program, runtime storage, guest
register/local/frame capacities, existing instruction prices, CLI default 256
or ceiling 16000000. Construction state grants no runtime authority: final
independent IR analysis still proves selecting PCs, roots, phases and joins.

Each existing loop binding word now packs its 0..64 lexical count into seven low
bits and its surrounding pending mask into the next sixteen bits. There is no
additional loop-state array. A loop transfer ends only selections created inside
that loop, then releases its exiting lexical suffix. This distinction also works
when an inner loop creates no new bindings: the surrounding RHS selection must
survive its `break` or `continue`. Scalar pure-for restrictions remain unchanged.

## Normal exits

Full visible cleanup, including scalar/void returns and failed `?` propagation,
emits END for every pending place before dropping owners or closing views.
Array and record return finalizers do the same before selective cleanup and
ownership promotion. Generic byte/reference returns end pending places before
their existing selective view cleanup and terminal handoff.

Exit emission leaves the lexical construction mask unchanged. Other branches
still compile with the same obligations; a successful `?` path keeps the selected
location, including an already captured old scalar, for its eventual STORE/END.
Ordinary completed assignment will explicitly end its own construction snapshot.
Aborts retain the VM's zero-Fuel draining rule, without fabricated normal ENDs.

Reservation and exit selection each inspect at most sixteen bits. Full cleanup
adds at most sixteen END instructions to existing lexical cleanup, bounded by
the unchanged 256-instruction limit. Empty masks emit no extra instruction and
preserve the earlier guest bytecode and Fuel schedule.

## Verification

Run `python -B tools/verify-static-execution.py --profile development
--selection array-place-cleanup`, then repeat for release. The selection covers
five new construction/VM groups, current selected-place execution, existing array
writes/void costs and original ordinary/retained CALL limits, plus value-arm loop
transfers and propagation. Public Fuel CLI regression remains a separate phase:
`python -B tools/verify-public-fuel.py --profile development --phase cli`, repeated
for release.

See [Windows evidence](../evidence/array-place-cleanup-windows-20261106.json).

Windows development/release each passed 21 native groups and 57 tool-free public
Fuel CLI cases. Native selection used 174 inputs; CLI selection used 177 inputs;
the 184-path union matches staged Git bytes and the checkout. Both share
283-file discovery, 164 LF production modules and passed locked LF mirrors.
Forty-one unselected fixtures differ only by CRLF/LF, with both hashes recorded.
The current native IR exact Fuel, original ordinary/retained 32/33 CALL bounds,
void 128-register case and earlier source array-write behavior all pass. No old
result or native stack/compiler/linker override was used. Full language/original
full native public Fuel matrices, Linux, OOM injection, general stack/performance,
worker isolation and delivery were not rerun.

The injected native IR cases exercise cleanup before both VM drivers. They do
not prove new guest source syntax or RHS order, which is the next source slice.
Exclusive-slice/record/scalar-local places, grouped lvalues, aggregate overlap,
Engine memory quotas/cooperative execution and full L04 remain open.

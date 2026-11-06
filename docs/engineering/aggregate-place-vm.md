# Metered native aggregate places

Date: 2026-11-06. Native execution successor to the
[independent aggregate-place IR proof](aggregate-place-ir.md).

## Invocation storage and selection identity

`aggregate_place_vm` prepares one invocation-owned `Vec<usize>`. Its authenticated
three-word prefix records format/width, row size and the next selection ticket.
Each of 32 frames has one active counter and up to sixteen eighteen-word rows.
A row stores the thirteen original destination words, static root ID, SELECT PC,
kind, ticket and phase. The initialized vector length is `3+32*(18*width+1)`:
611 words at width one and 9251 words (74008 bytes on 64-bit targets) at width
sixteen. Legacy-only vector lengths are 0, 1 or 2 modulo 32; this format is 3
modulo 32. The [shared dispatcher](place-dispatch.md) now permits legacy kinds
in this format while keeping the old adapters' aggregate-IR gates. No new owner
or guest extent is allocated.

Tickets increase across selection, END, frame reuse and abort. They never wrap;
an exhausted serial rejects selection before publication. Tickets are local to
one invocation vector, not process-global identities, cryptographic capabilities
or owner pins. As with legacy native adapters, the trusted coordinator must bind
one independently admitted immutable Program/prepared catalog and one unchanged
table/backing lifetime to the vector. Native callers must not transplant rows.
The pinned Fairy C compiler does not support mutable resource-field projection,
so this uses its existing move-only Vec directly rather than a mutable wrapper.

SELECT captures the original token/generation, shape/reservation and exact
nominal/ordinal subtree before RHS work. STORE and REPLACE use that capture;
the caller's later destination binding cannot redirect it. Native owner storage
revalidates the current original owner, generation, byte window and source
payload before publication. A location stores once; END accepts a pending or
stored location and clears all eighteen words. Abort clears every row/counter
using setup-prepaid work and preserves the serial, including at zero Fuel.

## Fuel and scratch

All new prices live in `fuel.fy`. Setup validates width/cost and prepays
`257+10*(3+32*(18*width+1))` before reserve/initialization. It costs 6367 at width
one and 92767 at width sixteen. No aggregate place means no new allocation or
setup charge. Existing scalar-array/slice/record formats and prices stay intact.

Ordinary native operation prices include dispatch; retained dispatch remains
additive when the retained driver is connected:

| Operation | Price |
| --- | --- |
| Whole-array SELECT | 97 |
| Record-subtree SELECT | 41057 |
| Whole-array copy/self-copy | `178+bytes+(bool ? length : 0)` |
| Whole-array fill | `146+2*stride+bytes` |
| Whole-array list replacement | `146+length+3*bytes` |
| Record/subtree copy | 172129 |
| Record/subtree constructor replacement | 128162 |
| END | 26 |

Record selection budgets two complete catalog plans (18432 each), one bounded
ordinal walk (4096) and 97 metadata units. Stores add the existing complete
subrecord copy/replacement envelopes. The replacement envelope also covers the
extra leaf-count planning/gathering. Array selection adds ledger/row work to the
existing array transaction prices. Self-copy keeps the full price even when
authenticated numeric identity allows storage to skip byte traffic.

The shared list requirement now recognizes new list REPLACE87 operands through
the canonical list helpers, alongside LIST80/REPLACE_LIST81. It retains the
maximum actual cell count and encoded size, bounded by 4096 and 32768. Existing
and selected replacements reuse those two scratch allocations; scalar gathering
and codec staging complete before destination bytes are published. Stores do not
allocate. Scratch and RHS effects need not roll back on failure; destination
payload and selected phase remain unchanged on a failed final store.

## Execution frontier and verification

This adapter executes all five native final stores. It does not grant ordinary,
image or returned-reference executable admission. Both VM coordinators, retained
dependency guards and ordered source lowering remain to be connected. The
[common native dispatcher](place-dispatch.md) supplies the shared ID/storage
integration. No public capability, CLI default 256 or explicit
ceiling 16000000 changes. Complete L04/C05/Engine/Instance/host/isolation/platform
delivery and the broader language work remain open.

Run `python -B tools/verify-aggregate-place-vm.py --profile development` and repeat
for release. The focused runner records actual input/compiler hashes, exact
native identities and results. The public Fuel CLI runner remains a separate
check. Full language/native Fuel matrices, Linux, OOM injection, general stack/
performance and clean-machine delivery are outside this selection.

Windows development and release each passed **15 native groups and 105 tool-free
public Fuel CLI cases** on implementation `48f6ef2`. Both final native selections
ran fresh on the same production inputs. The union of 196 recorded inputs matches
the checkout and Git raw bytes; all 176 production modules are LF. Test-source
inventory contains 303 files and 1817 annotations, not a full-suite execution
claim. The final scope includes nine new adapter groups, six legacy price/gate
regressions and the complete 105-case public CLI selection in each profile. See
[Windows evidence](../evidence/aggregate-place-vm-windows-20261106.json).

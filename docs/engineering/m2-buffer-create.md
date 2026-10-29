# Private empty Buffer registration

Implemented and verified in development and release. Root `fairyc check` passed
with a lock refresh (67 sources, 548 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`.
See the archived [Windows receipt](../evidence/m2-buffer-create-windows-20261029.json).

`buffer_create::empty` registers a distinct caller-owned empty native root through
a shared reference and admits its 64-byte logical owner charge. It allocates no
payload and enables multiple empty owners and registration after final
[close](m2-buffer-close.md). The caller still owns each native root.

## Admission and publication

`growth::unowned()` returns a ledger with all nine fields zero. The legacy
`growth::empty()` remains unchanged: it already prepays one 64-byte owner.
New Instances use `unowned()` before the first charged registration; do not charge
the same owner again through create when using the legacy prepaid ledger. After
final close, reuse the existing ledger for registration without resetting peaks
or Engine background usage.

Registration proceeds as follows:

1. Copy the 16-slot table onto the stack and call `owners::create` on that copy.
   This validates the table/root metadata and selects an available, non-retired
   slot. The staged root must have both length and capacity zero. Malformed state
   returns `State`; unavailable slots return `Owners`.
2. Sum every existing live descriptor's `capacity + 64` with checked addition.
   Overflow returns `Overflow`; `ledger.used` below that sum returns `State`.
   Extra admitted usage is permitted; the sum is a minimum coverage requirement.
3. `growth::admit_empty` checks counter ordering and idle transaction state across
   all nine fields: `used`, `engine_used`, `peak`, `engine_peak`, `pending`,
   `old_capacity`, `new_capacity`, `before_used`, `before_engine_used`. The five
   pending/snapshot fields must be zero. It checks addition overflow, then current
   quotas including room for 64 more bytes in both Instance and Engine usage.
4. Add 64 to both usage counters, raising peaks only as needed, then publish the
   selected staged slot. No fallible work follows admission; unrelated slots stay
   unchanged. The supplied root is never mutated.

Failure preserves the real table, ledger and root. `limits.object = 0` is valid
for this empty root even if another registered root has payload: existing table
charges must be covered, but their object limits are not rechecked here. Shared
Instance/Engine limits must cover current usage plus the new 64-byte charge.

Distinct fresh native-root binding, root/table/ledger association and exclusivity
remain trusted caller responsibilities. Shared empty-root metadata cannot detect
duplicate registration of the same root or a cross-Instance association. The
64-byte charge is logical accounting; physical table memory is not admitted.
Guest syntax, VM integration, borrow enforcement and whole-Instance integration
remain unfinished. Provider fault injection is absent.

## Focused Windows evidence

Development and release each passed 39 native scenarios: four create cases plus
35 existing regressions. The fixture is `probes/m2-buffer-failure/src/create.fy`.
Every new case starts unowned with 32 bytes of Engine background usage, registers
its first empty root at Instance/Engine usage 64/96, then grows it to capacity 256
through replacement at 320/352 with peaks 384/416.

- `create-success`: registers a second empty root at 384/416, closes the first
  after native destruction to reach 64/96, then closes the second to reach 0/32.
  Registration reuses slot 0 at generation 3 and usage 64/96; closing again reaches
  0/32 with peaks preserved. The earlier token returns exactly `Token`.
- `create-preflight`: rejects Instance/Engine limits 383/415 and registration of
  the capacity-256 root without mutation; an empty root succeeds at object limit 0.
- `create-state`: rejects all nine malformed ledger fields, insufficient table
  coverage, malformed table state, existing-charge sum overflow and admission
  overflow without mutation. Adding 64 to `MAX - 64` succeeds at exactly `MAX`.
- `create-slots`: rejects full tables and retired slots; free slot 2 at generation
  `MAX` can register, then close retires it at generation zero. Further creation
  cannot reuse it. Slot and extreme-usage tests use synthetic descriptors/counters,
  not 16 real roots or giant allocations.

Each new process reports one payload allocation for the seeded 256-byte root,
one final free and `live=0`; other empty registrations add no allocations. Only the
FY system-heap seam is instrumented. All 78 processes exit with `live=0`.
The archived receipt records 18 input hashes, twelve generated sources (nine
byte-identical production modules plus
`main.fy`, `grow_resize.fy` and `create.fy`) and two retained binaries. Full
native/CLI suites, M0, Linux, isolation, DLL embedding, packaging and elapsed-time
performance were not run. Earlier receipts retain their original inputs.

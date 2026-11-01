# Private metered exclusive slice execution

The internal execution loop now dispatches owned exclusive sites (marker `128`)
through `slice_exclusive_vm::step`. It executes open (54), selected UTF-8 (55),
close (56), length (57), relative scalar read (58) and relative scalar write (60)
against the existing unified sixteen-ticket pool. Readonly dispatch and its
prices are unchanged. Public `verify` still rejects every exclusive site before
payload allocation, Fuel consumption or execution. No mutable guest syntax or
public capability is enabled.

Implementation: `b8b3d58`.

The private execution boundary requires an immutable Program that passed
independent `inspect`. Metadata/type/control-flow/lifetime inspection remains
mandatory; calling the adapter is not a replacement for it. Owned roots must be
mutable and belong to the current function. Rootless mutable formals, exclusive
aliases/subranges, CALL retention and returned borrows remain unsupported.

## Admission and publication

The adapter validates instruction/frame bounds, zero reserved bytes, owned-site
metadata and the canonical scalar layout. It prepays the entire instruction
before resolving runtime roots, checking sessions or touching payload bytes.
Open requires an empty frame/site ticket entry, validates the full owner token
and original shape, and acquires the checked exclusive range session before
publishing its ticket. Pool capacity and root conflicts fail before publication.

Every later operation authenticates the ticket's exclusive mode, owner token and
original element/length, then uses the pool's checked session/generation API.
Indices are relative to the selected range. `usize` cells preserve all 64 bits;
the packed value `-1` denotes the maximum unsigned index and fails range checks.
Scalar stores stage at most eight encoded bytes before writing one element.
Invalid values, bounds, stale generations and invalid backing preserve payload
and ticket metadata. Scalar read/length/UTF-8 destinations publish only on success.
Close retires the ticket only after the matching owner session ends successfully.

## Fuel

Let `w` be the canonical scalar width (1, 4 or 8 bytes), and `N` the full origin
array length (1 through 4,096). Prices are logical bounded-work reserves, not CPU
timings. Open includes the existing eventual-abort cleanup reserve. Metadata
reserves cover the fixed pool and owner tables; reads and writes add the ordinary
array access reserve and scalar codec work.

| Instruction | Fuel |
| --- | ---: |
| Open | 65,537 |
| Close or length | 4,097 |
| Read | 4,130 + w |
| Write | 4,130 + 2w |
| UTF-8 (`u8` only) | 4,097 + 4N |

UTF-8 prepays the full origin bound even for an empty or smaller selected range,
but scans only the selected bytes. Underpayment by one unit returns `fuel`
before any runtime publication or payload access. Success returns exactly the
remaining budget, including zero at the exact price. Earlier successful writes
survive later execution errors; there is no invocation-wide payload rollback.

## Execution and cleanup

`vm_execution` selects this adapter only for exclusive sites; existing readonly
sites continue through `slice_frame_vm`. Source-lowered explicit closes and the
independent flow proof define normal lexical lifetimes. The new private tests
build inspected IR directly and execute the shared loop. No new Program fields,
per-frame pool, payload owner or extent is introduced.

The existing `slice_lifecycle_vm::finish` / `slice_vm::drain` path closes mixed
shared/exclusive tickets atomically. Successful cleanup preserves the original
result or error. Cleanup failure surfaces its own error and retains session,
pool and frame-ticket metadata for diagnosis. Cleanup ends loans; it does not
erase backing bytes or undo earlier stores. Full Engine/OS isolation is outside
this private runtime contract.

## Verification selection

```text
python -B tools/verify-m2-slice-elements.py --profile development --exclusive-vm
python -B tools/verify-m2-slice-elements.py --profile release --exclusive-vm
```

The selection covers six new exclusive-VM groups, six exclusive-pool groups,
five write-IR groups, five typed borrowed-VM groups and six lifecycle groups.
The CLI selection includes 192 public readonly scalar-slice and all 2,007 M1
cases. New native tests exercise all six scalar tags, signed/unsigned edges,
every exact/one-short instruction price, selected/empty UTF-8, failed writes,
stale/corrupt metadata, cleanup failure and execution-loop bounds/arithmetic/Fuel
errors with live writers. Public VM admission is checked separately and remains
gated.

Development and release each passed all 28 selected native groups and 2,199 CLI
cases. Both matched 357 identical current input hashes; pinned compiler,
retained CLI, public matrix and full M1 receipt identities were rechecked. Both
profiles accept parser depth 32 and reject depths 33/64 with `compile_limit` in
check/run. Program fields remain unchanged. See the
[Windows evidence](../evidence/m2-slice-exclusive-vm-windows-20261101.json).

Full native and other M2 suites, Linux, M0, isolation, packaging, allocator and
timing checks are outside this selection. Earlier receipts remain historical
for their original source hashes. No push, publication, packaged release or
deployment is part of this local delivery.

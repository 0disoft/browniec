# Private owned Buffer copy

`bytes::copy(ref source)` and `brownie::bytes::copy(ref source)` return exact
`Result<Buffer,u8>` in the private typed-source dialect. This checkpoint accepts a live
Buffer; an immutable binding or owned temporary is allowed. The
[view-copy successor](value-view-copy.md) adds readonly view inputs. The explicit shared
prefix is required. Public Buffer admission, method syntax, general reference
composition and a public AllocError contract remain separate work.

## Ownership and lowering

Copy evaluates its source once and uses the existing argument-loan checks. An
outer shared loan may coexist; an outer exclusive loan rejects. Copy neither
moves the source nor changes its initialized bytes, length or generation. The
returned Buffer has an independent owner even when both Buffers are empty.
Mutating, moving or dropping either successful owner does not affect the other.

The source intrinsic composes existing EMPTY95, APPEND104, CASE92, TAG_BUILD91,
DROP90 and ordinary forward jumps. Its internal parser selector 105 is not an
executable opcode. There is one native append of all initialized source bytes
into the fresh empty owner: payload work is O(n) with one payload allocation for
nonempty input and no input-sized scratch buffer or per-byte guest loop.

The intermediate `Result<usize,u8>` is handled on both compiler paths. Success
drops its length payload and moves the new Buffer into the output Result. Error
preserves the allocator error byte and drops the empty unpublished destination.
Both paths initialize the same exact Result destination, then join with the
original source still live. A temporary source drops only after this join. The
output remains move-only and subject to the existing Result must-use rules.
Exhaustive cases retain a real unreachable failure edge for independent CFG
admission; compiler branch snapshots never restore native owner authority.

`value_source_ops::tag_into` initializes an already allocated Dead Option/Result
slot rather than allocating a separate destination on every arm. It admits
exact payload/variant, liveness, function, loans and instruction capacity before
publication. Move-only payloads transfer; copyable payloads remain live. It also
works at the existing sixteen-slot high-water mark. Copy itself allocates five
compiler value slots: output, new Buffer, intermediate Result and its two scalar
case payloads. Those slots are monotonic, not a runtime allocation per iteration.
The existing sixteen-slot private limit still applies to the complete program.

## Errors and Fuel

Native allocation failure remains an error Result; bounds, quota and Fuel remain
execution failures. The existing old-plus-new quota accounting, checked growth,
authenticated root binding and prepaid native cleanup cover the composed work.
Source values are not replayed after failure. All generated instructions pay
their existing prices; no opcode price or public Fuel default/cap changes.

Copy's generated control flow adds fixed metadata/cleanup overhead around the
existing linear append price. No wall-clock performance or native OOM guarantee
is inferred from the O(n) structure. General reference composition,
public allocator errors, text/I/O, Instance teardown and wider language/runtime
composition remain part of the full implementation objective.

## Verification

Implementation commit: `ee8a686`. Run
`python -B tools/verify-value-buffer-copy.py --batch source --profile development`
and its release counterpart; select `--batch native` for the helper groups.
`--discover` lists identities without writing. Each batch/profile uses a distinct
locked byte-identical mirror and output directory and may run concurrently.

Windows development and release each passed 13 native groups: nine source
(copy, existing operations/boolean joins and depth) and four helper groups. The
22 new guest programs contain eight successes and fourteen exact rejection
cases. They execute independent mutation/length/content, empty and temporary
copies, qualified and forward calls, `?`, Result handling/moves, wrong types,
overlapping loans and moved source rejection. Helper native programs exercise
Buffer success and scalar error into an existing destination at all sixteen
allocated slots, plus nested wrappers, copyable children, inactive Buffer
alternatives, exact rejection state and complete instruction-byte preservation.

All 218 union inputs match checkout and Git raw bytes; all 207 production
modules are LF. Each batch hashes its own selected tests; all production/tool
inputs match between batches/profiles. The existing admitted 32/rejected 33
conditional fixture is byte-identical and executes in both profiles, with no
native stack overrides or historical reuse. See
[Windows evidence](../evidence/value-buffer-copy-windows-20261107.json) and the
[input manifest](../evidence/value-buffer-copy-inputs-windows-20261107.json).

The native helper fixture initially retained reserved-byte sentinels in later
raw instructions and merged distinct live sets at one failure target. Its final
program clears the future sentinels and uses separate failure targets; both
helper profiles ran fresh afterward. Production/source test inputs stayed
unchanged, so their original same-turn nine-group passes remain applicable.

At that checkpoint, actual allocator/OOM failure injection, copy-from-view,
general Buffer view lifetimes, full language/public CLI/native Fuel matrices,
Linux, general performance and clean-machine delivery were not run. Direct native error tag
construction does not establish actual allocator-failure injection. Public
Buffer admission, capability flags and Fuel default256/ceiling16000000 remain
unchanged. Local commits only; no push, release or deployment.

Successor: [Buffer view copying](value-view-copy.md) now copies a selected readonly
window into an independent owning Result. Its new112/kernel/source evidence is
recorded separately; the verification counts above retain their historical scope.

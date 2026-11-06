# Native typed values and frame storage

The [predicate successor](value-predicates.md) now adds non-consuming typed
Option/Result inspection through TAG_TEST98, including move-only Buffer wrappers.
The [propagation successor](value-propagation.md) now connects wide/resource `?`
and early cleanup. [Private must-use](value-must-use.md) now tracks Result
obligations. [Typed joins](value-joins.md) now connect scalar/Buffer/nested-tag
if/switch values. [Private loops](value-loops.md) now connect typed owner cleanup
and cyclic Result obligations; general public
integration remain separate work.

`value_frames` connects the [retained canonical layout](value-codec.md) to actual
native per-activation byte storage and the [owning Buffer root store](value-roots.md).
This is a native coordinator interface. The [private execution successor](value-execution.md)
now binds its immutable layout to a retained `value_program::Program` after full
independent typed-IR proof, then dispatches operations 88..98 through `vm::run_values`.
The [source foundation](value-source.md) now supplies typed signature and lexical
ownership preparation. The [private body bridge](value-body.md) now connects empty Buffer/nested-wrapper
construction, immutable locals and mixed CALL/RETURN. Complete typed-source
expressions and Engine handles remain separate work.

## Retained layout and activation identity

`value_frame_layout::Plan` owns an immutable codec Layout and copies all sixteen
slot type/function declarations. It independently derives aligned offsets,
per-function widths, final padding and maximum slot width. Function count is
1..16; absent slots require zero function metadata. Type IDs retain nominal record
identity and whole-type copyability, including inactive Buffer alternatives.
The Plan is checked layout metadata, not executable Program authority.

At most 32 activations coexist. Each entry allocates and initializes only the
selected function's byte extent, rounded to 64-byte capacity. There is no fixed
maximum-sized slab for unused activations. The frame vector reserves 32 native
Buffer headers once; one reusable scratch Buffer holds the largest slot. Neither
representation uses native recursive frame allocation or payload-sized stack
arrays. Existing ordinary scalar registers remain their separate domain.

Addresses contain frame index, monotonic nonzero activation generation and static
slot ID. The same slot ID in a recursive activation is distinct. Leaving/reusing
a frame never revives an old address. Exhausted generation allocation retires
instead of wrapping. Ready checks reconstruct exact frame accounting, canonical
unused rows, generation ordering and each selected native backing window before
payload access. Copyable State/Token/Address data are not cross-invocation authority.

The trusted coordinator must keep one exact Plan, matching frame State/vector/
scratch and root State/two vectors together for the invocation. It must not
transplant, duplicate, restore or edit these native contents independently. The
pinned compiler's mutable-resource-field restrictions still apply; named owning
vectors and checked SDK element borrows avoid an unsafe storage workaround.

## Publication and ownership

Each activation tracks an exact initialized/Dead mask and initialization order.
Native byte import admits only whole-type-copyable representations after full
canonical validation. Scalar writes reuse the staged checked codec. Buffer
creation binds a newly owned actual root directly to the exact destination
location; arbitrary externally supplied serial words cannot create an owner.

COPY requires exact equivalent types and whole-type copyability, and keeps its
source. MOVE requires a Dead destination, consumes its source and transfers the
same root serial/token/charge when active. Every active word resolves through the
retained native root binding. Source/destination windows, full representation,
scratch and root admission precede publication. A failed operation leaves live
slot bytes, masks and owner bindings unchanged; private staging bytes grant no
ownership. No fallible operation follows a successful root handoff.

Tag construction validates the selected exact-type payload and canonical staged
wrapper before publishing it. Copyable payloads survive; move-only payloads are
consumed. Option.none has no payload address. Logical some/ok1 and none/err0 map
to the existing canonical byte convention explicitly, including zero padding and
inactive tails. A matching CASE consumes a whole move-only wrapper even when the
selected arm is scalar or none. A mismatching CASE preserves it and does not
access a payload destination. Copyable wrappers survive extraction.

Cross-activation transfer uses the same checks and pre-reserved scratch. The
[execution successor](value-execution.md) now applies complete typed/ordinary
argument maps and atomic CALL/RETURN handoff through these primitives. Typed
actuals never enter ordinary scalar cells; recursive activations retain distinct
generations, and result publication requires the exact type and a Dead destination.

## Fuel, quotas and cleanup

`value_frame_meter` uses checked arithmetic for all templates and combined limits.
Frame metadata/backing and root usage count together against instance and Engine
ceilings; internal frame storage does not consume the per-guest-Buffer object cap.
Root admission receives limits reduced by current frame usage, including its
transient replacement peak. Explicit local policy accounting is not allocator
overhead, process RAM or complete Engine/shared-budget implementation.

Private frame metadata costs 12288 logical bytes. Scratch and frame backing each
cost rounded native byte capacity plus 64. Setup prepays `16384 + 4*largest`,
entry `32768 + 8*function_width` and ordinary value operations `2048 + 4*width`.
Scalar operations use width8. Buffer construction additionally prepays the
existing root creation template. Included root move/drop work is not charged
twice. Insufficient Fuel changes neither Fuel nor backing; admitted rejections
spend their template. Existing public opcode prices, default256 and cap16000000
are unchanged.

Entry prepays bounded normal frame cleanup. Leave destroys values in reverse
initialization order, retires/destroys active roots before refunds and then frees
the frame allocation. Failure abort ignores guest value bytes, tags and masks:
it drains runtime root ledgers and native owning vectors without executing guest
cleanup instructions or consuming additional Fuel. Repeated abort is idempotent.
Native resource cleanup also frees allocations on early coordinator exit.

## Verification and remaining integration

The focused runner is `python -B tools/verify-value-frames.py --profile development`
and its release counterpart. Its selected groups cover retained layout, checked
Fuel/combined quotas and actual native frame/value ownership. Executed results
and immutable input identities are recorded separately after final integration.

The runner checks locked production in the actual checkout, then runs native
tests in a fresh temporary project containing byte-identical production,
manifest/lock and only the three selected test modules. The pinned compiler
otherwise loads/checks all repository tests before applying exact selections.
The mirror preserves the locked package/source identity and selected native
checks while avoiding unrelated test compilation. Original and mirrored inputs
are hashed before/after execution. This is focused native evidence, not a claim
that the entire test tree was checked or executed.

Private typed-IR dispatch and complete atomic CALL/RETURN handoff are now
implemented in source by the [execution successor](value-execution.md). The
[source foundation](value-source.md) adds canonical types/signatures and lexical
COPY/MOVE/DROP metadata. The [private body bridge](value-body.md) now connects
empty Buffer/nested-wrapper construction, immutable locals and mixed CALL/RETURN.
The [control successor](value-control.md) now supplies mutable assignment and
statement joins. Typed value-expression joins, loops, propagation and public
integration remain next. General
reference/Buffer joins, must-use, full L04/L05/D01-D04 and broader language,
Engine/Instance/host/isolation/platform/delivery work remain open. Full CLI/
language/native Fuel matrices, Linux, OOM injection, general stack/performance/RAM
and clean-machine delivery remain separate validation work. No push, release or
deployment is implied by local verification.

At the frame-storage checkpoint, Windows development and release each passed all
twelve final native groups on `a1fb38c`: three layout groups, two checked-metering
groups and seven actual
frame/value groups. These include a 4096-element i64 array and four nested
wrappers with both active and inactive Buffer alternatives, plus a failed-leave
probe that proves reverse initialization order before ledger-only recovery.
At that checkpoint, all 194 inputs matched checkout and Git raw bytes; all 187
production modules were LF. Its static inventory was 315 test files / 1873
annotations, not an execution
claim for that full tree. See the [Windows evidence](../evidence/value-frames-windows-20261107.json)
and [input manifest](../evidence/value-frames-inputs-windows-20261107.json).
Both final checkpoint profile runs were fresh, without historical reuse/native overrides.
The focused commands took 87.142s development and 96.263s release on this machine;
these are verification-tool elapsed times, not VM performance measurements.

The private execution successor passed 26 native groups and 105 tool-free public
Fuel CLI cases per Windows development/release profile on `d025c6f`; see its
[evidence](../evidence/value-execution-windows-20261107.json).
The frame checkpoint above retains its separate scope.

# Native typed values and frame storage

`value_frames` connects the [retained canonical layout](value-codec.md) to actual
native per-activation byte storage and the [owning Buffer root store](value-roots.md).
This is a native coordinator interface. It is not typed-IR executable admission,
an Engine handle, or guest source syntax. The independent typed IR proof remains
required before a future driver may execute those operations.

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

Cross-activation transfer uses the same checks and pre-reserved scratch. This
provides the native movement prerequisite for CALL/RETURN, but does not yet apply
a complete argument map, execute either opcode or publish a guest return result.

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

Next connect these operations to verified typed-IR dispatch, complete atomic
CALL/RETURN argument/result handoff and compiler source bindings. General
reference/Buffer joins, must-use, full L04/L05/D01-D04 and broader language,
Engine/Instance/host/isolation/platform/delivery work remain open. Full CLI/
language/native Fuel matrices, Linux, OOM injection, general stack/performance/RAM
and clean-machine delivery remain separate validation work. No push, release or
deployment is implied by local verification.

# Immutable native literal images

Date: 2026-11-05. This is the owning-storage prerequisite for B04 Static origins
and D05 text literals. It is not guest literal syntax, Static IR/VM dispatch,
Program pinning or public returned-reference promotion. The full
[completion objective](completion-plan.md) remains active.

## Representation and ownership

`static_image::Builder` contains bounded compiler scratch: a 4096-byte array and
at most sixteen packed literal rows. Text and raw-byte literals are interned by
exact kind and bytes. Duplicates reuse their existing row even at capacity.
Appending does not allocate and validates every bound and UTF-8 text before its
first scratch write. Raw bytes may contain invalid UTF-8; they do not become text.
Scratch that claims more used bytes than its declared ceiling is rejected before
subtraction; failed interning and sealing preserve every scratch byte and row.

`freeze` independently checks packed/unused metadata and actual text bytes. It
preflights a caller-provided retention ceiling, then copies only the used prefix
into one move-only `Image` resource backed by `std::bytes::Buffer`. The image has
no mutable accessor; its resource fields are module-private. The copied bytes
survive input changes, scratch changes and the scratch function's scope exit.
No Instance array owner, scalar proxy, guest pointer or unchecked Static flag
stands in for this storage.

In the native checks, repeated three-byte text occupies one row and a payload
capacity of three, rather than retaining the 4096-byte scratch payload. The empty
image has zero payload capacity. These are logical Buffer capacities, not OS
allocator bucket sizes, process RAM, native allocation counts or benchmarks.
The native provider must report the exact requested capacity; an unexpected
provider shape is rejected and its unpublished owning resource drops normally.

## Admission, ranges and text

`inspect` independently validates the complete image, including UTF-8 bytes of
all text entries. Read/range operations validate packed metadata and subtraction
bounds before indexing. `Span` uses image-local literal and relative byte offsets.
It does not own or pin the image and is not an authenticated Program/Engine handle;
every access still requires a live reference to the exact owning image. Later VM
bindings must select that image from their retained Program, never a guest claim.

Relative subranges and empty ranges are checked without overflowing additions.
Byte views may split UTF-8 sequences. Text views require a text-kind literal,
character boundaries and successful validation of the selected actual bytes;
a forged compile-time text flag cannot admit invalid UTF-8 through sealing.
Byte equality compares exact content and makes no constant-time promise.

The current private limits are sixteen rows and 4096 decoded bytes per image.
They do not change public CLI limits and do not establish full-profile C05
capacities. The retention policy charge is 576 logical metadata bytes plus the
exact payload capacity. Admission subtracts metadata before comparing payload,
so quota failure precedes allocation and preserves scratch. This is a local
ceiling check; Engine/Program/compile-scratch accounting in R02 is still required.

Metadata validation visits sixteen rows. Complete text admission scans at most
4096 bytes across packed entries. Interning compares at most sixteen row headers
and 4096 existing payload bytes plus the bounded incoming text. A byte/range read
performs bounded metadata work without allocating or rescanning all text. A text
view additionally validates its selected bytes. These are algorithmic bounds,
not executed timing, allocator or stack-size measurements.

## Verification

The [Windows evidence](../evidence/static-literal-image-windows-20261105.json)
records six development and six release native groups on 122 matching final
inputs and a 216-file test-discovery digest. All 118 production files are LF; a
separate LF mirror passed `check --locked`. Both selections ran after final
capture without native overrides or historical-result reuse. Earlier probes and
selections preceding the final forged-limit regression are excluded. Six groups cover exact snapshot
ownership/deduplication, compiler-scope escape, quota and row/byte boundaries,
atomic failure, UTF-8/NUL/character boundaries, raw versus text kinds, relative
and empty spans, equality, hostile usize bounds and forged scratch metadata.

## Next integration

1. Implemented by the [retained native Program](retained-program-image.md): the
   private move-only owner retains the real image beside independently verified
   copyable IR. It exposes shared borrows and existing native scalar execution;
   Engine/Instance pinning and Static execution remain open.
2. Introduce independently checked Static definitions/origins, distinct from input
   origins and local owned roots. Program admission must inspect the real image
   and prove every literal index, exact read-only type, range and definition.
3. Route Static views through CALL/binding/return/close and failure cleanup while
   retaining the same Program image. Do not copy literals into each Instance's
   owned array arena or infer authority from a guest-selected numeric flag.
4. Add source literal decoding, `ref str` and explicit `text::bytes`/`text::equal`,
   and reconcile metering and Program/Engine lifetimes before public promotion.

Existing input-backed returned slices, guest Buffer, Engine/Instance stepping,
host exchange, restricted delivery, ABI, packages and full-profile evidence keep
their current scope. No existing opcode, cost, VM dispatch, CLI flag or public
capability changes in this storage increment.

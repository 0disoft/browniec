# Invocation input reference metadata

`input_reference_views` stores absolute `static_views::Span` metadata for one
immutable invocation input of 0 through 1048576 bytes. It neither owns nor copies
payload bytes and never uses the 4096-byte static descriptor codec.

## API

- `disabled() -> State` performs no allocation. `enabled(ref State) -> bool`
  reports a completed open, including `open(0)`.
- `open(usize length) -> Result<State, errors::Error>` reserves and initializes
  768 private `Cell { start, length, active }` entries before publishing State.
  Input length is retained once. The owning vector drops on every error.
- `get(ref State, frame, site, offset)` and `grant(ref State, frame, argument,
  offset)` return `Result<static_views::Span, errors::Error>` for active entries.
- `put(ref mut State, frame, site, Span, offset)` and `put_grant(ref mut State,
  frame, argument, Span, offset)` return `Result<usize, errors::Error>`.
  Success is zero. Existing active entries cannot be overwritten. Absolute
  bounds are checked by subtraction before publication, including empty spans.
- `close(ref mut State, frame, site, offset)` returns the same result type,
  succeeds with zero, and rejects inactive entries.
- `clear_frame(ref mut State, frame, offset)` returns the same result type,
  succeeds with zero, and zeroes exactly sixteen site and eight grant entries.
  A disabled State is a no-op for a valid frame. Invalid frames still fail.
- `contains(ref Span outer, ref Span inner) -> bool` rejects overflowing absolute
  intervals and checks containment using subtraction, including empty endpoints.
- `crop(ref Span, lo, hi, offset) -> Result<Span, errors::Error>` requires
  `lo <= hi <= length` and a representable parent endpoint before addition.
- `marker() -> u32` is 1073741824. `is_input(u32) -> bool` uses exact equality.

Frames are 1..31, sites 0..15, arguments 0..7. The 512 site cells use
`frame * 16 + site`; the 256 formal cells use `512 + frame * 8 + argument`.
Frame-zero entries remain inaccessible. State/Cell fields are module-private.
The pinned SDK rounds reserved capacity to 1024 cells (24576 allocation bytes);
exactly 768 cells are initialized and addressable internally.
Failures use error kind 5 for invalid state/index/span/size, 14 for crop range
endpoints or overflow, and 15 for allocation failure. Caller offsets survive;
`open` has no source-offset parameter and uses zero.

## Main integration obligations

Marker equality is a tag, never authority. Main must independently establish
admitted proof, the current live frame, exact input source, and containment in
the selected formal grant. No union of unrelated grants is authorized. An alias
is detached metadata; closing its source site does not invalidate another live
site. Clear all twenty-four entries before reusing a frame, including return and
error paths. No generation or source identity is supplied by this module.

Keep the input owner immutable and alive for the complete invocation. Main must
prepay setup (reserve/768 initializations), every operation, each 24-entry frame
cleanup, and final vector destruction. No Fuel prices or opcodes change here.
The integrating Main prepays setup32768, metadata128, frame cleanup2048 and
input argument staging128 per argument, with original prices unchanged. These
are Main-owned charges, not a dependency or implementation in this module.
After successful open this module performs no heap operation until resource
destruction; it only accesses existing cells. The pinned compiler forbids mutable
resource-field projection, so open captures the first cell's pointer through a
local `vec::at_mut` borrow. Private writes serialize start/length and active into
that fixed allocation. This relies on pinned Windows AMD64 little-endian Cell
layout: stride24, usize offsets0/8, bool offset16. Initial inactive bools are
zero; writes change its low byte and leave the remaining representation zero.
The supplemental native verifier asserts the actual generated layout. No
foreign companion declaration, payload codec or pointer escapes the module.
Native State and helper return
values stay small; no fixed 768-cell array is passed on the stack.

## Focused evidence

Run `python tools/verify-input-reference-views.py` for development and release
(O2) through the existing `verify-value-bottom` wrapper. Receipts are under
`build/input-reference-views/{development,release}/receipt.json` with input,
compiler and output hashes. Tests cover exact 0/4096/4097/1MiB spans, all 31 live
frames, aliases, crop, selected grants, inactive/cleared reuse, disabled state,
MAX arithmetic and marker equality. These are metadata tests, not payload IO or
VM integration evidence. The allocator test's OOM route needs the existing
explicit native allocator helper; ordinary native tests exercise its success
route. The wrapper then automatically runs the existing explicit allocator
helper with only its target size adapted from320 to24576 via a generated /FI
header. The instrumented process executes all six groups with exactly8
allocations/frees for8 successful opens, proving disabled operations allocate
nothing and post-open operations do not allocate. A separate process fails one
open, checks kind15 and an explicit successful retry:2 attempts,1 failure,1
free,0 live allocations. Both development/O2 images retain default1MiB/4KiB
stack reserve/commit. Supplemental receipt: `build/input-reference-views/seams/receipt.json`.
No compiler checkout mutation, stack override, or CL/_CL_/LINK override is
permitted. Ordinary public CLI and VM integration are outside this kernel check.

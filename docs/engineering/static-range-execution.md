# Frame-local Static byte-range execution

Date: 2026-11-05. This private B04/D05 increment connects the
[packed range metadata](static-view-ranges.md) to independently proved IR and
the canonical retained-image VM. The [source successor](static-range-source.md)
now supplies computed endpoints and exit cleanup. Static CALL/return origins
and ordinary public returned-reference admission remain separate work.

## Proof and frame storage

Opcode 76 RANGE is an eight-byte instruction: `dst=new byte site`, `a=live byte
site`, `b=defined usize lo register`, byte 4 is the defined usize hi register,
and bytes 5..7 are zero. Both endpoints are scalar values, never mutable slots
or aggregate/borrowed parameter placeholders. Definitions share the existing
Program-wide sixteen-site limit with OPEN, BYTES and ALIAS. The builder counts
actual retained definitions and rejects a seventeenth before emitting code.

Independent admission reconstructs the exact function, kind, definition order
and maximum immutable image window. RANGE requires read-only bytes; text cannot
be sliced or obtained by coercing a byte range. A dynamic bitset follows RANGE
and its aliases. Ordinary bare IR/VM admission rejects Static opcodes 69..76.
The original whole-program scalar/owner/loan and CFG checks still run, including
equal live sets at joins/backedges and no live Static sites at normal returns.

Execution owns 32 x 16 `u32` frame words: 2048 descriptor bytes, in addition to
the existing 32-word liveness table. This is fixed logical storage geometry,
not measured peak native stack/RAM or complete Instance accounting. Each frame
gets exactly sixteen words. The fixed-span `step` compatibility API rejects any
dynamic definition; canonical dispatch uses `step_frame` for every Static
instruction. Recursive calls therefore cannot overwrite a caller's actual range
by reusing the same instruction/site in another frame.

OPEN publishes its admitted image window; BYTES and ALIAS copy the actual word.
READ, LEN and EQUAL consult actual frame spans, including after a parent close.
RANGE checks `0 <= lo <= hi <= actual parent length`, then narrows relative to
that actual parent. Nested ranges cannot re-expand to their maximum proof window.
An empty range at the parent's end is valid. CLOSE clears only its own descriptor
and live bit. Normal lifetime checks and failure discard prevent stale frame
words from becoming live authority. The exact retained Program still owns the
immutable payload for the complete invocation; there is no payload copy or guest
array backing allocation.

## Fuel and publication

RANGE costs 128 abstract units including the driver's single dispatch unit;
`fuel::static_instruction` supplies the remaining 127. Packing remains bounded
to 26 conversion iterations per pack with the current SDK. This is a bounded
metadata price, not a machine-instruction or elapsed-time measurement. Existing
prices remain OPEN/BYTES/ALIAS/LEN 17, CLOSE 1, READ 18 and EQUAL 17 plus both
actual selected byte lengths. Entry/handoff/leave reserves, public default Fuel
256 and explicit CLI ceiling 16000000 retain their contracts.

Metadata validity is checked first. Complete operation Fuel is preflighted
before guest endpoint validation or publication. Only after endpoint checks,
packing and destination-window validation succeed is the destination word/live
bit published. Insufficient Fuel and bad endpoints leave source/destination
words and scalar registers unchanged. Guest endpoint failures use Bounds 14;
malformed IR/metadata uses IR 5; Fuel shortage uses 8 and remains first cause when
both budget and guest endpoints would fail. Existing native owner/loan abort
runs independently of remaining guest Fuel.

## Focused verification

Run `python -B tools/verify-static-execution.py --profile development --selection
ranges`, then repeat with `--profile release`. This selection runs nine new
range groups plus 26 existing Static execution/proof groups. It covers actual
read/length/equality spans, aliases after parent close, whole-invocation exact/
one-short/one-more Fuel, publication atomicity, empty/invalid endpoints, forged
kinds/registers/reserved bytes/liveness, ordinary admission rejection, recursive
same-site frame isolation, the sixteen-site limit, nested narrowing and loop
reentry with changing endpoints. The straight-line oracle is independently
specified as 188 plus existing entry/leave reserves; exact Fuel leaves zero.

Windows development and release each passed 35 focused native groups on 133
matching inputs and the same 226-file discovery identity. All 126 production
modules are LF and both locked LF mirrors pass. See
[focused Windows evidence](../evidence/static-ranges-windows-20261105.json).
Final counted runs use no compiler/stack overrides or historical-result reuse;
early core probes are excluded. No CLI/full-profile, general stack/RAM,
allocator/OOM/timing, Linux, restricted Windows or C ABI/package checks were run
for this increment.

The [source successor](static-range-source.md) now lowers computed byte
endpoints with cleanup on every endpoint exit, including effectful equality
arguments. Next connect Static CALL/return origins and retained receipts. Dynamic runtime,
Buffer/input views and ordinary public admission remain open in the complete
inventory. Focused private execution does not complete B04/D05 or the full goal.

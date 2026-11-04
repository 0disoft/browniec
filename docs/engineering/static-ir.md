# Private Static instruction proof

Date: 2026-11-05. This increment prepares B04/D05; it does not enable
Static source expressions or VM execution. It follows the owning
[literal image](static-literal-image.md) and [native Program](retained-program-image.md).

## Independent preparation

`verifier::inspect_statics` takes actual ordinary IR and a live immutable image.
It reconstructs every Static definition from the instructions and checks literal
IDs, exact byte/text kind, relative bounds and UTF-8 character boundaries against
the image. Site numbers are not pointers, scalar values or authenticated Program
handles. The returned copyable `Sites` is analysis metadata and does not retain
storage; a caller must keep the exact image alive.

The same entry then runs the ordinary whole-program metadata, function partition,
register definition/type, array/record owner and loan proof. Static instructions
participate in that register proof. They do not bypass it through a scalar proxy.
The analysis accepts the existing reborrow-CALL analysis forms; that does not
relax the separate ordinary executable-CALL admission rules.

Static liveness uses a separate 256-entry CFG state plane. The existing 64-bit
owner/loan plane is already allocated to array roots (0..15), record roots
(16..31), live slices (32..47) and suspended slices (48..63). Reusing those bits
would merge unrelated lifetimes. Equal numeric Static and owner/slice IDs are
therefore permitted and independently checked.

Forward joins require equal Static live sets. Backedges must preserve their
target's entry live set and existing scalar-definition invariant. Every normal
scalar/array/record return requires no live Static site; the existing terminal
match-failure instruction may abort with live sites. Duplicate definitions,
cross-function use, use after close, mismatched kinds, undefined indices and
invalid/repeated scalar destinations reject with the ordinary IR error.

## Private eight-byte dialect

| Opcode | Operands |
| --- | --- |
| 69 OPEN | `dst=site`, `a=literal`, `b=1` bytes or `2` text; bytes 4..5 lower and 6..7 upper relative bounds, little-endian u16 |
| 70 CLOSE | `dst=live site`; all remaining bytes zero |
| 71 READ | fresh u8 `dst`, `a=live byte site`, `b=defined usize index register` |
| 72 LEN | fresh usize `dst`, `a=live byte site`; remaining bytes zero |
| 73 EQUAL | fresh bool `dst`, `a/b=live read-only byte or text sites` |
| 74 BYTES | `dst=new byte site`, `a=live text site`; remaining bytes zero |
| 75 ALIAS | `dst=new same-kind site`, `a=live byte/text site`; remaining bytes zero |
| 76 RANGE | `dst=new byte site`, `a=live byte site`, `b=defined usize lo register`, byte 4 = defined usize hi register; bytes 5..7 zero |

The [byte-view equality successor](static-byte-equality.md) extends EQUAL operands
while retaining text validation and the independent live-state proof. The
[alias successor](static-alias.md) adds same-kind descriptor copying with
independent source/destination liveness and unchanged image ownership.

Bytes 4..7 are reserved zero except in OPEN and RANGE. The
[range successor](static-range-execution.md) independently checks both endpoint
registers and source liveness, retains maximum proof windows plus a dynamic
definition bitset, and executes actual ranges in separate frame words. Definitions are globally unique,
function-local and bounded to 16 sites across the Program. BYTES inherits the
exact image-relative span and requires a live text source. Its resulting
read-only bytes independently refer to the same immutable image, so closing the
text site does not invalidate the byte site. READ proves its index register;
actual runtime index bounds remain an execution obligation.

The forward/backedge solver needs one additional 256-element usize array:
2048 bytes of logical elements on the current 64-bit targets. This is not a
measurement of generated stack frames or process RAM. Definition preparation
visits at most 256 instructions and validates the image's at most 4096 bytes;
up to 16 text OPENs can additionally validate at most 4096 bytes each. No new
Instance storage or allocator is introduced; guest Fuel prices and public
capacities are unchanged.

## Execution boundary and next work

At this proof checkpoint, ordinary `inspect`, `verify`, VM admission and
`program_image::retain` rejected Static opcodes. The
[execution successor](static-execution.md) now admits real Static operations only
through retained-image native Program execution; bare ordinary admission stays
gated. Existing Program reuse and public Fuel behavior retain
their contracts. Static proof alone cannot promote an executable Program.

Next connect this proof to retained Program admission together with real Static
VM dispatch, exact precharged prices and image-backed lifetime handling. Then
connect source literals, `ref str`, `text::bytes` and `text::equal`, CALL/return
origins and retained receipts. Keep public syntax/capability flags gated until
the complete execution/admission/cleanup path exists. Engine accounting, general
references, Windows restriction and the C ABI remain separate open work.

## Verification

Run `python -B tools/verify-static-ir.py --profile development` and then
`--profile release`. The runner checks the pinned compiler, LF sources and a
locked LF mirror, fingerprints production inputs and the entire test discovery
tree, and executes focused Static proof/image, retained Program, scalar entry
and public Fuel cases. It rejects native compiler overrides and records fresh
results rather than historical reuse.

Windows development and release each passed 31 native groups, including eight
new Static groups, on 129 matching inputs and the 218-file test-discovery
identity. All 120 production modules are LF; both locked LF mirrors passed.
Counted runs follow final input capture without native overrides or result reuse.
Earlier fixture-checker corrections and the early eight-group development probe
are excluded. The [Windows evidence](../evidence/static-ir-windows-20261105.json)
records exact commands, input/compiler/report hashes and outcomes. No standalone
CLI, full profile, Linux, restricted delivery, ABI/package, allocator/OOM or
native stack/RAM/timing evidence is produced by this increment.

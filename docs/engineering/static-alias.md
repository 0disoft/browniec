# Static alias definitions

Date: 2026-11-05. This supplies the same-kind shared-view operation needed by
Static local and alias lowering after the [literal compiler](literal-compiler.md).
It is a private IR/VM prerequisite, not guest binding syntax or public promotion.

## Descriptor copying and authority

Opcode **75 ALIAS** has `dst=new site`, `a=live source site`, and all remaining
bytes zero. Its definition inherits the source's exact byte/text kind, literal,
relative range, absolute image start and function. It accepts byte and text
sources, including byte views previously produced by BYTES. It cannot request a
new kind, mutate bytes, manufacture an owner/loan, or pin a Program independently.

Independent image-aware definition proof rejects self/duplicate/undefined/forward
or cross-function sources, unknown kinds and nonzero reserved operands. The CFG
proof separately requires the source live at ALIAS and the destination absent.
The same existing join/backedge and normal-return cleanup rules apply. Numeric
scalar cells cannot manufacture a Static view. Ordinary bare admission still has
no image authority and rejects the extended dialect.

Both source and destination are independently live shared aliases into the exact
owning immutable Program. Closing a source view preserves its alias. Text aliases
retain validated UTF-8 boundaries; byte aliases remain bytes. READ/LEN still
require byte views and BYTES still requires text. Aliasing does not introduce an
implicit byte-to-text conversion or relax any mutable owner/loan rule.

The canonical VM reuses its existing 32 frame words. There is no new runtime
field, payload copy or allocator operation. ALIAS costs **17** including dispatch,
preflighted before publishing the destination. Its source stays live. The native
builder derives every definition from actual emitted code, including prior
ALIASES, and preserves the existing sixteen-site limit and speculative rewinding.
These remain narrow implementation bounds, not full-profile C05 adoption.

## Verification and source successor

Run `python -B tools/verify-static-execution.py --profile development --selection
statics` and repeat with `--profile release`. The focused selection now contains
32 groups: five new alias proof/execution groups and the prior 27 image/proof/VM
regressions. Cases cover exact image metadata inheritance, byte/text/converted
byte chains after parent close, exact/one-short/one-more Fuel, no publication on
shortage, preserved source liveness, invalid operands, live text misused as bytes,
closed and foreign-function sources, and all sixteen definitions plus rejection
of a seventeenth. The two-alias chain costs 75 after existing invocation reserves
and runs with zero guest backing.

Windows development and release each passed all 32 selected native groups on
131 matching input hashes and the same 221-file test-discovery identity. All
124 production files are LF and both locked LF mirrors passed. The public Fuel
CLI phase was rerun on both profiles: 33 cases each, with 136 matching CLI input
hashes, hashed executables and an empty runtime tool PATH. The default remains
256 and the explicit ceiling remains 16000000. No compiler/stack override or
historical result reuse was used. The public Fuel native selection was not rerun.

See the [focused Windows evidence](../evidence/static-alias-windows-20261105.json)
for exact native/CLI selections, inputs, compiler, report and artifact identities.
The earlier E2101 fixture compile failure was corrected before these final input
snapshots; it is not counted as a verification pass.

The [typed binding successor](static-bindings.md) now lowers native ref str/byte
locals, aliases and text::bytes projections with lexical/nonlocal-exit cleanup.
General Static view expressions and byte-view text::equal source arguments remain next. Static CALL/return receipts,
public returned-result admission and the complete inventory remain open. No
Engine/Instance pin, external result receipt, full-profile, general stack/RAM,
allocator/OOM, timing, Linux, restrictions or C ABI/packaging claim follows.

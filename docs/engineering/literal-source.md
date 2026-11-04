# Byte and text literal decoding

Date: 2026-11-05. This is lexical and compiler-scratch preparation for B04/D05.
The [retained-image VM](static-execution.md) already executes private literal
operations. Source binding/type lowering and actual guest text execution remain
separate work; recognizing a token does not admit an executable expression.

## Spelling and decoded data

`literal_source` recognizes `b"..."` before identifiers and `"..."` before
punctuation. The lexer emits kind 3 for bytes and 4 for text. Its unchanged State
retains original half-open source spans including prefix/quotes; token snapshots
do not contain decoded buffers. Adjacent literals stay separate tokens.

Both kinds support `\\`, `\"`, `\n`, `\r`, `\t`, `\0`, and exactly two hex digits
after `\x`. Text additionally accepts one through six hex digits in `\u{...}`.
Unicode scalars exclude surrogates and values above U+10FFFF; leading zeroes and
NUL are valid. Non-ASCII source characters retain their UTF-8 bytes without
normalization. Complete decoded text is validated as UTF-8, including bytes made
by `\xNN`; byte payloads may contain arbitrary escaped bytes.

These spellings follow the reviewed Fairy C string-family contract in
`docs/language/0006-lexing-parsing-and-recovery-v0.md` at the design-package source
snapshot `4f7798689bcd6a6ef797c9079ed4e28092647cca`. C strings, raw strings,
character literals, multiline literals, interpolation and implicit concatenation
are not added. The accepted Brownie profile has no guest CStr/FFI type.

Raw NUL, LF, CR and misplaced BOM bytes remain errors under Brownie's existing
[source-byte policy](lexical-compatibility.md). A BOM scalar may be represented
inside text with `\u{FEFF}`, or inside bytes with hex escapes. Complete raw token
bytes must be valid UTF-8; compiler entry still validates the complete source.

## Bounds and failure

Decoder scratch is a fixed 4096-byte array. `scan` retains only the raw end;
`decode` returns an owned scratch value whose initialized payload is
`data[..length]` and whose unused tail remains zero. No descriptor or reference
into decoder scratch escapes. The production intern bridge decodes completely
before inserting a kind-specific entry into an existing image builder. Distinct
Source/Image failures preserve decoding offsets and image quota errors, and leave
the complete prior builder unchanged. Existing freezing makes the separately
owned retained copy; returned IDs are builder-local, not Program authority.

Every input loop advances or fails. Six Unicode hex digits bound arithmetic to
U+FFFFFF before scalar validation; UTF-8 encoding checks destination space before
writing. Whole source remains capped at 4096 bytes, so spelling and quotes also
consume its budget; this does not promote full-profile C05 capacities. Payload
size is independently bounded by scratch capacity. Lexer tokens retain the
existing 1024 ceiling.

Malformed escapes report lexical kind 1 at the backslash. Unterminated literals
and invalid raw/cooked UTF-8 report kind 1 at the original token opener. Forbidden
raw bytes report their original byte position. Oversized source reports compile
limit kind 4 at byte 4096. Decoder writes are private staging; no token or image
entry is published on failure. A malformed escape detected before token
completion takes precedence over the completed-token UTF-8 checks. Lexer cursor
state after an error remains unspecified, as before.

## Integration and verification

Public compilation still rejects literal-valued expressions and `ref str`.
Version capabilities are unchanged. Native fixtures cover actual decoded bytes,
Unicode/UTF-8/escape failures, spans/snapshots and immutable image storage.
Standalone CLI checks prove diagnostics and honest source gating; they are not
positive source-to-Static execution evidence.

Windows development and release each passed 25 native groups: eight new literal
and image-bridge groups, five existing source-byte groups and twelve existing
core/function groups. Both profiles also passed 52 literal-diagnostic/gating and
36 existing lexical CLI cases with an empty runtime tool PATH. All 132 final
inputs and the 220-file test-discovery identity match; all 122 production files
are LF and both locked LF mirrors pass.

The [Windows evidence](../evidence/literal-source-windows-20261105.json) records
commands, pinned compiler/input/report/artifact hashes and results. Counted runs
follow final input capture with no native overrides or historical reuse. The
early CLI probe and the initial development selection before three fixture
corrections are excluded. Full-profile, general native-stack, RAM/timing,
allocator/OOM, Linux, restricted delivery and C ABI claims remain open.

Next connect compiler-owned literal collection, typed Static locals and
`text::bytes`, then Static CALL/return origins and public result admission.
The accepted `text::equal` API takes byte views. Its [private equality successor](static-byte-equality.md)
now admits byte operands through actual image proof/execution. Connect source
argument checking and explicit conversions before promoting the guest API.

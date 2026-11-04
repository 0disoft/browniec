# Lexical Compatibility

- Status: Implemented; five focused interpreter groups and 36 native CLI cases passed.
- Scope: Brownie source trivia and lexical byte positions. The compiler's public
  grammar and token kinds are unchanged.

## Source bytes

The compiler validates the complete source as UTF-8 before lowering it. The lexer
accepts the UTF-8 BOM (`EF BB BF`) only at source byte offset zero and consumes it
as trivia before the first token. A BOM anywhere else is lexical error kind `1` at
the BOM's first byte. Token spans remain zero-based half-open ranges over the
original bytes, so the first token after a leading BOM starts at byte 3.

LF and CRLF are accepted trivia. CRLF is one logical newline but advances over both
source bytes. A CR without a following LF is lexical error kind `1` at that CR,
including inside a comment. A raw NUL byte is lexical error kind `1` at that byte,
including inside a comment. Neither invalid byte is replaced or normalized.

## Comments

`//` starts a line comment and consumes through LF, CRLF, or EOF. `/*` starts a
block comment and consumes through its matching `*/`; block comments may nest.
Comment openers take precedence over `/` tokens. An unterminated block comment is
lexical error kind `1` at its original opener. Cursor state after an error is not a
compatibility promise.

The existing source-size and token ceilings remain in force. Brownie's 4,096-byte
source ceiling bounds the number of complete comment openers. The lexer additionally
rejects a would-be 2,049th nesting level with compile-budget error kind `4` at that
opener. Every comment and whitespace loop consumes bytes or returns an error.

## Token and error positions

BOM and comments do not increment `State.tokens`. Whitespace and CRLF advance raw
source offsets without changing a token's `begin` or `end`. The existing 1,024-token
limit still rejects token 1,025 with kind `4` at its first byte. Invalid BOM, NUL,
lone CR, and unterminated-comment input uses lexical kind `1`; parser and type error
categories are unchanged.

## Focused tests

[`tests/lexer_compatibility.fy`](../../tests/lexer_compatibility.fy) covers BOM
placement, LF and CRLF spans, lone CR, raw NUL in comments and source, nested and
unterminated block comments, line-comment interaction, and the token ceiling.

The intended focused command is:

```powershell
build/toolchain/fairyc.exe test --native --file tests/lexer_compatibility.fy --locked
```

The lexer-only semantic interpreter command passed five groups. The development
standalone CLI build passed 36 tool-free `check`/`run` cases through
`python -B tools/check-lexical-compatibility.py --exe build/m2-slice-result-ranges/browniec.exe`.
The direct native lexer command above was not run; native CLI cases exercise the
actual source loader/compiler, while the interpreter cases cover direct token spans
and the token ceiling. Release, Linux, full M1, performance measurement and
clean-machine packaging were not run. See the [combined evidence](../evidence/returned-ranges-lexical-windows-20261104.json).

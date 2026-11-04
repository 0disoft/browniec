# Preserve text predicate dispatch in retained-image compilation

Date: 2026-11-05. The literal compiler's speculative `text::bytes` lookup
advanced its lookahead past the qualified prefix, then tested the advanced
kind to decide whether to parse `text::valid_utf8`. Existing array predicates
therefore fell through to ordinary name lookup under `compile_image`.

The compiler now saves the qualified-prefix decision before inspecting the
method. Actual lexer state, plain `text` bindings, source syntax, operation
prices and all limits are unchanged.

The exact new fixture fails at `58c6b92` with an assertion failure. After the
fix, Windows development and release each pass one native group executing
valid ASCII, invalid UTF-8 and a plain scalar named `text`. Each execution also
checks native owner/loan teardown. Commands are `build/toolchain/fairyc.exe test
--native --capture-output --json --locked --file tests/m2/image_text_dispatch.fy`
and the same command with `--release`.

See [focused evidence](../evidence/image-text-dispatch-windows-20261105.json).
No full profiles, CLI, Linux, restrictions, ABI, allocator or general native
stack/timing checks were run. Static local/alias/ref str lowering remains next;
public literal and returned-reference admission stay gated.

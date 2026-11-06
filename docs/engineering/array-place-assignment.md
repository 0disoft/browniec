# Ordered owned-array element assignment

Date: 2026-11-06. Successor to [VM integration](array-place-execution.md) and
[compiler exit bookkeeping](array-place-cleanup.md).

## Source semantics

A mutable owned fixed scalar array now lowers `a[index] = value` through one
SELECT, one STORE and one END. The index expression evaluates once. SELECT
checks the original owner's generation, shape, extent and bounds before any
RHS guest work. An invalid index therefore wins over a RHS return or divide by
zero. This deliberately replaces the old source-write increment's late check.

The five existing integer domains additionally admit statement-only `+=`, `-=`,
`*=`, `/=`, `%=`, `<<=`, `>>=`, `&=`, `^=` and `|=`. The lexer takes the longest
operator, including three-byte shifts. Compound lowering inserts READ before
the RHS, then applies the existing exact-type checked scalar operation before
STORE. There are no promotions. Plain bool stores remain supported; bool
compounds, assignment expressions and increment operators remain unavailable.

The selected index and old scalar survive RHS index-variable changes, whole-array
replacement, nested assignments and mutable borrowed CALLs. Nested RHS places use
separate frame-local IDs; child CALLs may reuse the same ID in their own frame.
Every normal nonlocal exit abandons exactly the exited selections before owner,
view or returned-value cleanup. Inner loops preserve surrounding selections even
when lexical counts are identical. Scalar, array, record, void and shared-byte
returns, failed/successful propagation and loop transfers retain their existing
handoff and effect ordering. Aborts keep zero-Fuel drain without replay.

The new RHS lexical snapshot consumes no guest binding or register. All 64 local
slots remain available; thirty sequential compounds reuse place ID zero within
the existing register/instruction limits. All 256-instruction, 128-register,
32-frame, 4096-source-byte and 64KiB backing bounds remain unchanged.

This increment is owned scalar-array element assignment. Exclusive-slice, record
field, scalar-local and grouped lvalues, generic aggregate copy-overlap proof,
broader references/resources and complete L04 remain separate work. Pure-for
header restrictions are preserved. Version JSON adds
`array_selected_place_assignment` and `array_element_compound_assignment`; existing
profile strings, public capabilities, CLI default 256 and ceiling 16000000 remain.

## Deliberate source Fuel change

Existing instruction prices do not change. Source stores now emit different IR
and pay the invocation snapshot setup (3457 units for one ID). The earlier plain
write oracle of 205 with four backing bytes is superseded by 3776.

The following sources return the actual stored element:

```c
var a=[0;1];  a[0]=42;  return a[0];
var a=[20;1]; a[0]+=22; return a[0];
```

| Entry | Plain write | Compound |
| --- | ---: | ---: |
| Native ordinary, four backing bytes | 3776 | 3846 |
| Public ordinary, 65536 backing bytes | 69308 | 69378 |
| Forced native retained entry | 413378 | 413449 |
| Public retained source with an unused byte marker | 413396 | 413467 |

Ordinary bodies cost 314/384. Retained drivers add six/seven aggregate/place
dispatch units, 147456 entry and 196608 leave. Public backing adds 65537; setup
adds 3457. The marker adds eighteen Static dispatch/operation units. Exact and
one-short boundaries are checked independently; public CLI also checks one-more.
The default remains intentionally too small for aggregate backing setup.

## Verification

Use `python -B tools/verify-static-execution.py --profile development
--selection array-place-assignment`, repeated for release. The selection includes
source semantics, all fifty integer/operator pairs, cleanup, existing VM and array
write regressions, void full-register/exact cases, qualified modules and original
ordinary/retained 32/33 CALL bounds.

Build/public Fuel validation uses `tools/verify-public-fuel.py --phase cli` for
each profile. Run `tools/check-m2-array-write.py` and
`tools/check-array-place-assignment.py` with that profile and its copied native
CLI artifact. Each CLI runs with an empty tool PATH and fresh invocation state.
See [Windows evidence](../evidence/array-place-assignment-windows-20261106.json).

Windows development/release each passed 30 native groups and 230 tool-free CLI
cases: 61 existing array-write, 112 new selected-place and 57 public Fuel cases.
Native selection used 176 inputs; public Fuel used 177. Their union plus the two
additional CLI checkers totals 188 input paths, all matching staged Git bytes
and the checkout. The legacy checker identity is recorded after its unchanged
executions; its artifact identity matches both other CLI phases. Both profiles
share 284-file discovery and 164 LF production modules; locked LF mirrors
pass. Forty-one unselected fixtures differ only by CRLF/LF, with both hashes
recorded. No old result or native stack/compiler/linker override was reused.

Full language/original full native Fuel matrices, Linux, OOM injection, general
stack/performance characterization, Engine/isolation and delivery are not
established by this focused slice.

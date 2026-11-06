# Ordered owned-record scalar field assignment

Date: 2026-11-06. Successor to [record-place execution](record-place-execution.md)
and [exclusive-slice source assignment](slice-place-assignment.md).

## Source semantics

A mutable owned record now lowers `p.field = value` through kind-two SELECT,
STORE and common END. The compiler resolves the exact nested scalar ordinal;
runtime selection authenticates the original owner before RHS guest work.
Source scalar writes no longer emit the legacy record STORE opcode 44.

The five existing integer domains admit statement-only `+=`, `-=`, `*=`, `/=`,
`%=`, `<<=`, `>>=`, `&=`, `^=` and `|=`. A compound READ captures the old field
before RHS evaluation, then the existing exact-type checked operation computes
the value for STORE. Plain bool assignment remains supported. Bool/aggregate
compounds, assignment expressions and pure-for-header writes remain rejected.
Whole-record and child-record assignments retain their aggregate transaction
paths; this increment changes scalar field lowering only.

The saved location and old scalar survive whole/child replacement, nested field
writes, mixed array/slice writes and CALLs. Record, array and slice selections
share sixteen frame-local IDs and the existing pending mask. A lexical snapshot
passes those obligations into the RHS without consuming a guest local/register.
Returns of every existing kind, failed propagation, break and continue end the
exited selections before owner/view/handoff cleanup. Inner loops preserve outer
selections. Aborts retain earlier effects and use prepaid cleanup without replay.

All 64 bindings remain available; thirty sequential compounds reuse an ID.
Existing 256-instruction, 128-register, 32-frame, 4096-source-byte and 64KiB
backing bounds remain. Native record-layout maxima do not expand source
constructor staging limits. Version JSON adds `struct_selected_place_assignment`
and `struct_field_compound_assignment`. Kind-two STORE preserves the existing
`brownie.m2-struct-write/1` result profile.

## Deliberate source Fuel change

Existing instruction prices, default 256 and public ceiling 16000000 remain.
Source scalar writes now pay record-capable setup plus SELECT/STORE/END. The
earlier plain native oracle 128782 with four backing bytes becomes 174658.

For one ID, setup is `257 + 10 * (2 + 32 * (14 + 1)) = 5077`.
An i32 record SELECT/READ/STORE/END costs 41025/41029/41033/22. Public backing
costs 65537. Complete fixture bodies initialize one scalar and return its value:

```c
struct P { i32 x; }
// Each line is the complete body of a separate i32 main function.
var P p=P{.x=0};  p.x=42;  return p.x;
var P p=P{.x=20}; p.x+=22; return p.x;
```

| Entry | Plain write | Compound |
| --- | ---: | ---: |
| Native ordinary, four backing bytes | 174658 | 215688 |
| Public ordinary, 65536 backing bytes | 240190 | 281220 |
| Forced retained public entry, no marker | 584260 | 625291 |
| Public retained source with an unused byte marker | 584278 | 625309 |

Ordinary bodies cost 169576/210606. Retained execution adds entry147456,
leave196608 and six/seven dispatch units; the byte marker adds eighteen units.
Native tests check exact and one-short budgets. Public CLI tests independently
check one-short, exact and one-more. The existing struct-write checker uses the
new plain oracle and public maximum for larger legal source programs.

## Verification

Run `python -B tools/verify-static-execution.py --profile development
--selection record-place-assignment`, repeated for release. The focused selection
has seven new source groups and fourteen existing record execution/write,
array/slice assignment, qualified-module and original 32/33 CALL-bound groups.
It checks fifty integer/operator pairs, nested replacement and old-value order,
all return kinds, propagation/loop cleanup, checked errors, exact IR/Fuel,
64 bindings and ID reuse.

Build/public Fuel validation uses `tools/verify-public-fuel.py --phase cli` for
each profile, then `tools/check-record-place-assignment.py` and
`tools/check-m2-struct-write.py` against that profile's copied executable.
All CLI checks run with a cleared, tool-free PATH.

The initial new rejection test exceeded the native test process stack by
accumulating compiler-result temporaries in one frame. Each rejection now calls
a helper that releases its result before the next case. The same erroneous
guest inputs already returned structured errors through the standalone CLI.
No compiler, linker or stack-size override is used.

Scalar-local/grouped places, generic aggregate overlap proof, broader resource
joins and complete L04/C05/Instance/host/delivery remain open. Full language/
original full native Fuel matrices, Linux, OOM injection, general stack and
performance characterization, worker isolation and clean-machine delivery are
outside this focused verification.

Windows development/release each passed **21 native groups** and **286 tool-free
CLI cases**: 111 selected-place, 118 existing struct-write and 57 public Fuel.
The 193-path input union matches checkout and staged Git raw bytes;
native/public Fuel phases capture 181/183 inputs.
Both locked LF mirrors pass with 170 production modules and
294-file discovery. The 40 unselected CRLF/LF-only discovery
differences are recorded separately. The legacy checker lacks its own input
snapshot; its executed script/fixture and generated source hashes were checked
when collecting evidence. No historical result reuse or native overrides were
used. See [Windows evidence](../evidence/record-place-assignment-windows-20261106.json).
The skipped scopes above remain unverified here.

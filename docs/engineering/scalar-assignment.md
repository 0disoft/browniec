# Ordered scalar-local compound assignment

Date: 2026-11-06. Successor to [record field assignment](record-place-assignment.md).

## Source semantics and representation

The five existing integer domains now support statement-only `+=`, `-=`, `*=`,
`/=`, `%=`, `<<=`, `>>=`, `&=`, `^=` and `|=` on a mutable local. Source resolves
the visible binding once and saves its stable frame-local slot before RHS work.
A fresh ordinary LOAD captures the old scalar before evaluating the RHS. The
existing exact-type checked operation computes the value for ordinary STORE.
Nested assignments to that same variable cannot replace the captured old value.

No new guest opcode, native selected-place vector, pending ID, owner or payload
extent is required. Scalar slots already have independent type/initialization
proof and frame-local lifetime. A child CALL cannot redirect the caller's slot;
lexical scopes cannot reuse that slot during a suspended expression. Existing
nonlocal-exit cleanup continues to close outer array/slice/record selections.
Abandoned compounds do not execute their arithmetic or STORE. Runtime errors
retain earlier effects and use existing cleanup without replay.

The shared value-arm classifier recognizes every assignment token, so a compound
may precede the final expression of if/switch arms. Existing pure-scalar for
initializers and posts also accept integer compounds. Post validation rewinds
its new LOAD/operation exactly like existing scalar expressions. Body-only
bindings and effectful CALLs remain unavailable in a for header; dead posts
are type checked but do not execute or consume runtime Fuel.

Plain assignment retains its original emitted IR and accepts existing bool and
supported Option/Result slots. Compounds require an integer destination and the
RHS's exact type. Bool/tagged compounds, immutable destinations, assignment
expressions, increment operators and grouped lvalues remain rejected.
Version JSON adds `scalar_local_compound_assignment` without changing profiles,
existing operation prices, default256 or ceiling16000000.

## Independent IR and Fuel oracles

For these complete main bodies, ordinary scalar execution requires no backing
or selected-place preparation:

```c
var x=20; x=42;  return x;
var x=20; x+=22; return x;
```

The plain body costs six instruction units: constant, initial STORE, constant,
assignment STORE, final LOAD and RETURN. The compound body costs eight: it adds
the old-value LOAD and checked arithmetic. Its instruction bytes and register
count match `var x=20; x=x+22; return x;` exactly; diagnostic offsets may differ.

| Entry | Plain write | Compound |
| --- | ---: | ---: |
| Ordinary native/public | 6 | 8 |
| Forced retained public entry, no marker | 344070 | 344072 |
| Public retained source with an unused byte marker | 344088 | 344090 |

Retained entry/leave add147456/196608. The marker adds eighteen existing Static
dispatch/operation units. Native tests check exact and one-short costs; both
public CLI profiles check one-short, exact and one-more. Existing record-source
Fuel and old classic-for/local-slot exact budgets are separate regressions.

All 64 bindings remain usable. Thirty sequential compounds fit the existing
limits. A scalar-only fixture with 41 sequential compounds and a final read
fits 128 registers; its 42-compound counterpart exceeds that unchanged limit
and returns a structured compile-limit error. No instruction/register/source/
CALL/backing limit is raised.

## Verification and remaining work

Run `python -B tools/verify-static-execution.py --profile development
--selection scalar-assignment`, repeated for release. The thirteen groups are
six new source groups plus seven existing local-slot, classic-for, record Fuel
and ordinary/retained 32/33 CALL-bound regressions. They cover fifty
integer/operator pairs, old-value ordering, mixed pending places, pure headers,
all current return kinds, propagation/loop exits, checked failures, exact types,
IR/Fuel and original binding limits.

For each profile, build and check the public CLI with
`tools/verify-public-fuel.py --phase cli`, then run
`tools/check-scalar-assignment.py` against its copied executable. The CLI
checker runs with a cleared, tool-free PATH and verifies the capability flag.

The [grouped assignment successor](grouped-assignment.md) now admits grouped
mutable scalar/aggregate destinations through the same operations. Grouped
borrows, generic aggregate overlap proof, broader resource joins and full
L04/C05/Instance/host/delivery remain open. Full language/original full
native Fuel matrices, Linux, OOM injection, general stack/performance, worker
isolation and clean-machine delivery are not implied by this focused slice.

Windows development/release each passed **13 native groups** and **186 tool-free
CLI cases**: 129 scalar-assignment and 57 public Fuel. The 190-path
input union matches checkout and staged Git raw bytes; native/public Fuel phases
capture 179/183 inputs. Both locked LF mirrors pass with
170 LF production modules and 295-file discovery. The
40 unselected legacy CRLF/LF-only differences are recorded separately.
No historical result reuse or native compiler/linker/stack override is used.
See [Windows evidence](../evidence/scalar-assignment-windows-20261106.json).
The skipped scopes above remain unverified here.

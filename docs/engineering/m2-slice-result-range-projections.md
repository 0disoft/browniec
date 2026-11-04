# Range projections of returned slice CALLs

Date: 2026-11-04. This B04 increment connects reference-valued declaration and
terminal-return ranges to the existing private CALL-binding and handoff paths.
The complete [implementation objective](completion-plan.md) remains open.

## Source and evaluation

```brownie
let ref i32[] part = tail(ref [42; 4])[1..2];
return select(ref mut parent)[lo..hi];
```

Bounds are relative to the actual range returned by the CALL. All six exact
scalar types and both access modes use SUBSLICE or BEGIN with the existing site
metadata and independent definition/CFG/origin/loan proof. Rooted temporary
backing is supported for a local declaration, while independent origin proof
continues to reject its escape from a function.

CALL_BIND completes before hidden selected ancestors and its anonymous result
are published in acquisition order. Both exact-usize endpoints then evaluate
once, left to right. Their lexical exits see the existing result/parents/owner;
no range child or user name exists yet. Declaration delimiters finish before
range acquisition and user-name publication. The child has exactly one cleanup
binding. Scope cleanup closes the range, then the returned Held, then its hidden
ancestors/backing, restoring fresh mutable parents normally.

A returned writer already suspends its original parent during endpoint work.
Delaying the range child does not grant endpoints permission to reuse that parent.
This differs from a named-parent range whose child has not yet been acquired.

## Terminal handoff

A bounded lexer snapshot distinguishes `return f(...)[lo..hi]` from bare CALL
forwarding. It evaluates no argument, emits no IR, and does not advance the real
lexer. Bare forwarding keeps its existing PREPARE_FORWARD recipe and site use.

A ranged return uses a separate post-CALL lexical snapshot, followed by the range,
its length preparation, reverse cleanup and terminal return. The private IR bridge
turns the preparation into PREPARE_VIEW. Native dispatch defers physical terminal
cleanup to the existing handoff transaction, preserving actual bounds and
consuming each callee Held receipt exactly once. Source never reads the length
proxy as a returned reference. Native View.length retains the original root shape
for validation; the selected length is end minus start, checked through the live
ticket API. No new opcode, operation price, authority ledger,
CLI limit or public capability is introduced.

## Verification and remaining work

The [Windows evidence](../evidence/m2-slice-result-range-projections-windows-20261104.json)
records 14 development and eight release native groups on 125 matching final
inputs and a 215-file discovery digest. Eight new groups run in both profiles;
development also runs three named-range, one retained-CALL, one direct-argument
range and one scalar-projection regression. All 117 production files are LF; a
separate LF mirror passed `check --locked`. All counted groups ran after the
final snapshot without native overrides or historical-result reuse. Earlier
probes and the corrected bool-switch/View.length fixtures are excluded.
The selection covers scalar/access modes, real returned-relative and empty ranges,
selected temporary lifetime, endpoint order/snapshots, return/propagation/loop exits,
independent malformed-parent rejection, Fuel boundaries, bounds and endpoint traps,
preserved writes and complete invocation cleanup.

Static backing, general references and ordinary public returned-reference
Program/CLI admission remain open. Parenthesized temporary roots, repeated slice
chaining and access-mode coercions are not promoted by this increment. Full M1/M2,
standalone CLI, Linux, restricted delivery, ABI, packaging, allocator and native
time/stack measurements are outside the focused selection.

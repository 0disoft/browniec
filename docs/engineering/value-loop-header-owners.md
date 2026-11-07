# Deferred anonymous loop-header owners

Private retained-value source now permits the last view of a pre-existing
anonymous Buffer seed to be rebound on a repeating edge. Its real owner remains
initialized until safe cleanup, preserving the exact loop header without
inventing a dummy Buffer, moving a pinned root or replaying source/effects.

```c
module main;
fn ref u8[] id(ref u8[] v) { return v; }
fn i32 main() {
    let b = bytes::empty();
    var ref u8[] r = id(ref bytes::view(ref bytes::empty()));
    var n = 0;
    while (n < 2) { r = bytes::view(ref b); n += 1; }
    return 42;
}
```

This extends [loop origin inference](value-view-loop-origins.md). The actual seed
allocation remains charged while retained; this may outlive its concrete last
view to preserve the current exact-owner loop proof. No payload is copied.

## Compiler protection and cleanup

One compiler-only `usize` mask, `State.loop_roots`, protects already initialized
anonymous exact Buffer roots retained by header views. Named owners, ordinary
unretained temporaries, Result obligations and fresh body allocations do not gain
protection. Loops without live header views skip seed scanning.

Snapshots, exclusive alternatives and joins preserve the mask. Each loop frame
saves its parent mask, and repeating edges compare live/maybe/protection exactly.
Both branch normalization and loop trims preserve protected roots. Cleanup
preflight and emission omit them before IR is generated; an ordinary DROP of a
protected root rejects rather than concealing an already emitted instruction.

Each reached exit releases only its loop's protection. Departing roots still
referenced by descriptors keep their existing last-alias lifetime; unpinned roots
retire in reverse slot order through DROP90 or DROP_IF_LIVE115. Release admits
all loans and instruction capacity before publishing the mask or any retirement.
Repeated release and subsequent dead-slot drops emit no duplicate cleanup.

Terminal function cleanup releases all protection only after its complete
preflight, then closes views and drains owners through the existing paths.
Option/Result propagation restores only the separately reached success snapshot.
Canonical IR/native owner proof, generation checks, quotas, first errors and
prepaid failure drain remain authoritative. The compiler mask is not guest or
native root authority.

No runtime frame field, opcode, existing instruction price, public admission gate
or public Fuel default 256/ceiling 16000000 changes.

## Verification

`tools/verify-value-loop-header-owners.py` selects four new source groups, two
metadata drivers and nine existing origin/conditional/bottom/depth regressions.
Small helper scopes check live/maybe/mask snapshots, parent masks, protected DROP,
full-IR and loan atomic rejection, reverse DROP90/115 bytes and last-alias cleanup.
Those synthetic metadata fixtures do not claim executable CFG admission.

Real guests cover while/for/continue/nesting, zero-trip/break paths, both concrete
conditional seeds, orphaned possible-root trims, early returns, Option/Result
propagation, bounds/overflow failure and fresh-invocation recovery. Every
successful guest independently verifies before execution. Named owner loss,
fresh body roots, widened writes/pins and unhandled Results still reject.

An exploratory combined group first used an unsupported private widening cast
and exceeded the current compile budget with repeated static Option CALL sites.
Diagnostics separated source/verification/runtime outcomes. The return fixture
now returns u8 directly. One static Option CALL site executes two failure paths
and then a successful third call in the same VM invocation; no budget was raised
and recovery was not replaced by unrelated invocations. Private safe-cast
composition remains a separate language task.

Implementation `03c758a` passed all 15 selected groups in each Windows native
profile using fresh final inputs, locked mirrors, default stacks and no overrides.
Six new groups cover twelve positive source programs, one recovery program run
after each of two runtime failures, seven source rejections and metadata contracts.
Nine predecessor groups include the unchanged combined admitted32/rejected33
fixture. All 228 inputs match checkout and Git raw bytes; all
216 production modules are LF. See [focused evidence](../evidence/value-loop-header-owners-windows-20261107.json).


## Remaining work

Fresh anonymous owners carried from inside a loop still require general cyclic
ownership composition. Broader bottom/unreachable diagnostics, general references,
methods/public AllocError, Instance/Engine/host/I/O and platform/delivery remain.
The failure/recovery cases do not measure internal leak counters or prove all
runtime lifecycle accounting. Public CLI and Linux/macOS were not validated.

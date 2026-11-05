# Returned byte reference source lowering

Date: 2026-11-05. This B04/B05 increment connects source return expressions and
result bindings to the existing [canonical returned-reference VM](reference-return-vm.md).
It follows [shared byte CALL source lowering](reference-call-source.md).

## Source, origins and retained admission

`compiler::compile_reference_returns(source, image_limit)` returns a private
`ReferenceReturnProgram`. The ordinary compiler, image-only compiler, formal-only
reference compiler and CLI retain their previous returned-declaration gates.
The native entry/completion remain scalar; this is not a host reference ABI.

```brownie
module main;
fn ref u8[] same(ref u8[] input) { return ref input; }
fn ref u8[] literal() { return b"*"; }
fn i32 main() {
    let ref u8[] selected = same(ref [42; 3]);
    let ref u8[] alias = selected[1..2];
    return alias[0] as i32;
}
```

Shared byte functions can return their selected input, aliases/ranges of it,
another returned CALL, or immutable literal/text-byte views. Parameterless
literal providers are admitted only by this private source path. Result bindings,
immediate index/length projections, narrowed results and nested returned actuals
use the existing typed view syntax and canonical CALL/RETURN instructions.

The bounded source origin pass supplies construction hints: one exact logical
input, including scalar prefixes, or the immutable image. Branches must agree;
grounded forwarding/recursion is allowed, conflicting origins and ungrounded
cycles reject. Text aliases and explicit `text::bytes` retain image provenance.
Local arrays and owned value parameters cannot become a declared input/image
origin. Complete independent recipe and owner-lifetime proof reconstructs these
claims from the finished IR before the code/image snapshot can be retained.

## Selected temporary ownership and evaluation

Returned native receipts already survive closing their source actual. After
CALL, temporary source views and unselected owned captures therefore close
promptly. Only selected temporary array owners stay in caller lexical storage.
A bounded walk through actual PARAM/literal/alias/range/CALL definitions finds
those owners; this is construction metadata, never runtime authority.

Anonymous owners become visible to cleanup before a returned result's effectful
index/endpoints or later arguments execute. Narrowing closes its temporary parent
word while preserving the child's selected owner. Normal block/return cleanup
closes views before dropping hidden owners. Early return, propagation, break and
continue use the same exiting suffix. Named owner writes remain excluded while
any returned alias depends on them; unselected caller arrays can be mutated while
the result remains live. Alias/range lifetimes are independently proved.

No extra dense descriptor/ticket map, runtime frame field, pool reservation or
payload copy is introduced. The retained Program and invocation keep exact image
and full-generation native receipt authority. All existing runtime prices,
prepaid abort/finalization, public default 256, cap 16000000 and experimental
capacities remain. Source construction itself is not an Engine accounting or
general RAM/stack bound.

## Verification and remaining work

Run `python -B tools/verify-static-execution.py --profile development --selection
reference-return-source` and repeat for release. Eight new source groups cover
image/runtime returns, parameterless literals, aliases/ranges/empty results,
selected temporary owners, prompt unselected release, nested returned actuals,
forwarding/grounded recursion, conflicting origins and all supported nonlocal
cleanup exits. They also check measured one-short/exact/one-more Fuel, image
quota boundaries, bounds failure cleanup, retained source immutability and old
admission gates. Source Fuel boundaries are measured, not a new independent
numeric oracle. Eight existing result VM groups retain their independent numeric
schedule, and two source CALL groups cover affected regressions.

Windows development and release each passed all 18 selected native groups and
33 public Fuel CLI cases. CLI builds were serialized and ran with a tool-free
PATH. Native inputs match across 144 paths, CLI inputs across 149 paths: 153
distinct committed inputs, 137 LF modules and 242-file discovery. Both locked LF
mirrors pass. No compiler/stack overrides or historical-result reuse. Earlier
direct probes and corrected fixture borrow/narrowing/capacity errors are excluded
from final counts. Final identities, outcomes and limitations are recorded in
[focused evidence](../evidence/reference-return-source-windows-20261105.json).

Next connect ordinary retained Program/public source admission and CLI execution
with the corresponding ownership, image and cleanup proof before promoting
capabilities. Kind-3 equality, mixed-backing text/non-byte references, Buffer/input
backing and host-visible reference lifetimes remain open. Full profiles, original
public Fuel native selection, general RAM/stack, allocator/OOM/timing, Linux,
restricted delivery and ABI/package checks are outside this increment. The
[complete inventory](../product/04-remaining-work.md) and
[implementation plan](completion-plan.md) remain active.

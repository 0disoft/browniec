# Immutable byte-view equality from source

Date: 2026-11-05. Native `compiler::compile_image` now lowers `text::equal`
through the existing [image-backed EQUAL operation](static-byte-equality.md).
This extends [typed Static bindings](static-bindings.md) without promoting
ordinary public source admission or completing dynamic input/Buffer text work.

## Source signature and lifetimes

```brownie
let ref str word = "한";
let ref u8[] encoded = text::bytes(word);
let bool same = text::equal(encoded, b"\xED\x95\x9C");
```

Exactly two byte views are required. Immutable byte literals, named byte views,
optional explicit `ref` aliases, parenthesized views and explicit `text::bytes`
conversions are accepted. Text literals and `ref str` arguments need explicit
conversion; scalars, mutable/runtime owner-backed views and extra/missing
arguments are not coerced into image sites. Dynamic runtime views remain a
separate integration obligation, rather than a completed part of this signature.

Arguments are constructed left to right. The builder emits one EQUAL with a
fresh bool destination. Only owned argument temporaries close, in right-to-left
order after comparison; named views remain live. At this checkpoint arguments
were pure view construction. The [range-source successor](static-range-source.md)
now admits computed range endpoints with ordinary CALL/control effects and
retains the left temporary through every right-argument exit. No payload copy
or guest backing allocation is needed.

Independent image-aware admission still proves both real image spans, kinds,
functions and liveness, and the fresh bool destination. The source checker
requires bytes even though private EQUAL IR also permits validated text. A
scalar value can never manufacture a Static view or text validation.

## Pricing and limits

EQUAL costs 17 plus both complete selected byte lengths, including dispatch,
even for unequal lengths or an immediate mismatch. OPEN/BYTES/ALIAS/CLOSE retain
their existing prices. Equal one-byte source literals cost 58 for the selected
complete guest path, before existing native entry/leave reserves; two different
three-byte literals cost 62 and two empty views cost 56. These source costs
include argument opening/closing, branch and return. They require zero guest
array backing. Literal image quotas remain separate from execution Fuel.

All definitions, including closed conversion temporaries, share sixteen sites.
Short-circuit paths and loop backedges must join with identical Static live
sets. Pure for-post checking must discard speculative definitions before actual
body/post emission. Ordinary scalar calls preserve the caller's live image views
and close the callee's own sites before returning. Static CALL arguments and
returned-image views are not implemented by this scalar-call check.

## Verification and remaining work

Run `python -B tools/verify-literal-compiler.py --profile development --selection
equality`, then the same with `--profile release`. Native and CLI phases may be
selected separately; serialize CLI builds. The new five groups cover raw byte
contents including invalid UTF-8/NUL, empty and shorter spans, explicit text
conversion, named view liveness, loops, short circuit, for-post rewind, scalar
calls, independent exact/one-short/one-more Fuel oracles, kind/arity rejection,
public admission gates and the shared sixteen-site bound. The selection also
includes existing typed binding, literal and text-dispatch regressions.
Windows development and release each passed all 21 native groups: five new
equality groups and sixteen existing binding/literal/text-dispatch regressions.
Both standalone CLIs passed 88 tool-free literal/lexical cases. All four phase
snapshots match on 138 input hashes and the same 224-file test-discovery identity.
All 125 production modules are LF and both locked LF mirrors passed. No native
compiler/stack override or historical-result reuse was used. The
[focused Windows evidence](../evidence/static-equality-source-windows-20261105.json)
records exact selections and source/compiler/report/artifact identities.

The [range-source successor](static-range-source.md) now lowers immutable byte
range/view expressions and their nonlocal cleanup. Dynamic runtime/Buffer/input
equality, Static
CALL actuals and returned origin/lifetime receipts, ordinary public admission
and complete Engine/Instance accounting remain open. Full-profile, general
native stack/RAM/allocator/timing, Linux, restricted delivery and C ABI/package
claims require their own implementation and evidence. The complete goal remains
active.

# Call-scoped named-slice range arguments

This historical slice records `b8ab0eb`. Its temporary-root gate is superseded
by [temporary-array borrow arguments](m2-temporary-array-borrow-arguments.md).

Implemented at `b8ab0eb`, following owned-array ranges at `749f9bf`.

Existing scalar slice names may supply a relative range directly to an exact
slice formal: `ref part[lo..hi]` or `ref mut part[lo..hi]`. Owned-root lexical
slices, shared/exclusive formals and their derived children are supported.
This extends [owned-array range arguments](m2-array-borrow-range-arguments.md).
See the [example](../../examples/named-slice-range-arguments.brc).

## Source and lifetime

All six scalar types match exactly and access modes must agree. Explicit usize
endpoints evaluate once in source order before the new child is acquired. Open
forms and empty ranges work; the default upper bound uses the current parent's
length, and indexes are relative to its selected view. Existing captures remain
active while later endpoints evaluate. Parent reads/writes and nested CALLs in
endpoints use the existing rules while the new child is still pending.

A source-only capture carries either an owned root, a named parent or an already
ready argument. It stores no runtime ticket and creates no child before endpoint
completion. Bare named arguments retain their existing ticket behavior.

Readonly named ranges emit SUBSLICE and later CLOSE. Mutable named ranges emit
BEGIN and later END, using the existing lexical reborrow forest and canonical
CALL path. During a mutable child's lifetime its parent is suspended. CALL return
first restores the anonymous child; reverse capture cleanup then ends the child
and resumes the named parent. The caller may use the parent again after CALL,
including when the callee returns an array or exact-nominal record.

Endpoint exits clean up already-live captures, with no close for the pending
child. Later argument return/propagation/loop exits close the created child in
reverse mixed capture order. Runtime failures use the existing invocation drain;
earlier writes and original errors survive, without replay or external-effect
rollback. Nested formal forwarding and recursion use the same restoration path.

## Boundaries and cost

Independent proof rejects suspended-parent use and duplicate exclusive child
creation before Fuel and guest effects, including unreachable functions. Owned
root access remains restricted by active exclusive views. Disjoint ranges do not
introduce borrow splitting. Readonly duplicates remain legal.

A range consumes one static slice site and anonymous local. Explicit endpoints
use their existing expression instructions/registers. Omitted endpoints emit zero
or parent-length selection. Runtime state/layouts, instruction prices, aggregate
transfer, allocator and VM dispatch bodies are unchanged. No array owner, result
extent, payload copy or opcode is added. The source-only descriptor gains a parent
site discriminator, kept off the recursive scalar CALL frame.

Version JSON adds `array_slice_named_range_arguments: true`. Existing static-site,
local/register, argument, depth, quota and Fuel bounds remain; CLI Fuel stays at
1M. Literal/call-result temporary roots, repeated slicing, implicit mode conversion
and returned/escaping borrows remain unsupported.

## Verification

Development and release each passed **12 native groups and 854 CLI cases**.
Nine new groups cover source behavior, failure cleanup and immediate END after
CALL; three existing groups cover updated mutable, readonly and owned-range
admission. CLI coverage is 102 named-range, 108 owned-array range, 82 whole-array,
74 mutable-parameter, 74 readonly-parameter, 252 scalar slice source, 50 derived
record-result, 44 derived array-result and 68 lexical reborrow cases. All 454
final input hashes match across profiles; compiler, native-report, retained CLI
and receipt hashes were rechecked. Three production paths change: source capture,
endpoint lowering in the compiler and version JSON. The other 97 source files
match `4b6ab2c` under Git LF normalization. See the
[Windows evidence](../evidence/m2-named-slice-range-arguments-windows-20261103.json).

Both profiles ran native and CLI checks using final inputs. Development started
from uncommitted implementation inputs; every input is also checked against the
implementation commit under Git LF normalization.

Coverage includes scalar modes, owned/formal/nested parents,
relative/open/empty ranges, readonly duplicates, endpoint evaluation order and
parent mutation before suspension, recursion, aggregate results and early exits.
Native failure checks inspect canonical maps, owner sessions and surviving root
payload after invalid child creation, endpoint error and callee bounds failure.
An endpoint nested CALL writes before invalid child creation; that write survives.
An IR test checks that CALL is followed immediately by END for a mutable range.

The prior mutable source group also runs a legacy execution path. The newly
accepted reborrow-range fixture uses a separate public-source helper; legacy
production gates are unchanged.

Native source fixtures use 16M Fuel and 256-byte backing. CLI matrices run with a
cleared environment and tool-free PATH at 1M Fuel and 64KiB backing. Recursive and
16-total-site cases reach the CLI Fuel cap; 17 sites reject at compilation. Four
nested endpoint parentheses succeed and forty reject under the depth guard.
Full native suites, full M1, other M2, Linux, isolation, packaging, allocator,
native size/stack and timing are outside this verification. No performance claim
is made. Local only; no push, release or deployment.

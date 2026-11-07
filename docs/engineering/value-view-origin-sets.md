# Shared reference origin sets

The [conditional-owner successor](value-view-conditional-owners.md) now handles
anonymous roots created only on selected arms. This predecessor records `49dc33f`.

Private shared byte views can now join different already-live Buffer or formal
origins through `if` and exhaustive `Option`/`Result` switch values. The descriptor
names remain exact; only the possible root set widens. At runtime a native view
still identifies one concrete authenticated root/window. No guest mask, owner
word, new opcode, Program field or payload copy grants authority.

## Source lifetimes

Compiler metadata keeps the existing singleton origin encodings. Encoding 25
denotes a normalized multi-root set of the low 24 bits: local owners 0..15 and
formal ordinals 16..23. Singleton/dead set storage stays zero. Namespace and live
Buffer ownership are authenticated for every candidate before lowering publishes
an operation. All candidates remain pinned against write/growth/move/drop and
owning CALL arguments while a surviving alias might refer to them.

Aliases, ranges, moves and selected-input CALL results preserve the complete set.
Rebinding and lexical/nonlocal cleanup collect every possible local owner, close
views before roots, and drop an anonymous owner only when no other descriptor
depends on it. Arm-local owners still cannot escape. Distinct owners created
only on individual branches need a separate conditional-ownership transaction.

Retention is tracked per possible root. For alternatives with possible roots A/B
and retained roots RA/RB, the joined retention is
`(RA & RB) | (RA & ~B) | (RB & ~A)` within the bounded origin domain. An origin
absent on an edge does not revoke another edge's CALL retention; an unretained
occurrence does revoke it. A named Buffer and an already-retained anonymous root
can therefore share a view destination without inventing owner lifetimes.

Buffer view copying checks every local candidate and accepts formal origins;
it does not interpret a formal ordinal as a local owning slot. Native copying
uses the concrete authenticated view as before.

## Independent proof

The verifier derives masks from definitions and CFG edges, independently of all
compiler metadata. Incoming edges must agree on each descriptor's Live/Dead
state. Possible roots widen monotonically. A bounded pending-PC worklist revisits
loop headers and already processed successors after widening, so an earlier
mutation or return cannot bypass a later-discovered dependency. At most
`256 * (1 + 16 * 24) = 98560` transfers are processed per function; unreachable
instructions remain invalid. Reserved operand bytes still name slots, not masks.

CALL results inherit their selected actual's whole set. A function's shared
return must still be exactly its selected formal bit: unions of different
formals, local escape and occupied/stale descriptors remain admission errors.

On 64-bit targets the view proof uses 32 KiB of fixed origin storage plus bounded
flags, with no native stack override. Compiler source snapshots add two bounded
16-word mask planes. Runtime frame layouts, native registry limits, existing
prices, no-view setup and public Fuel default 256/ceiling 16000000 are unchanged.

## Verification and remaining work

`tools/verify-value-view-origin-sets.py` provides `core`, `source` and `regression`
batches. Both native profiles run concurrently in disjoint locked mirrors by
default. New source cases keep small helper scopes; every guest invocation is
fresh. The unchanged admitted32/rejected33 fixture remains a regression.

Conditional branch-created owners, general evolving source-loop origin inference,
bottom expressions, mutable/non-byte/Buffer-object references, public admission
and the remaining host/lifecycle/platform requirements are still open in the
[requirement inventory](../product/04-remaining-work.md). Public CLI, Linux/macOS,
restricted execution and embedding are not established by this increment.

## Executed verification

Implementation `49dc33f` passed 49 groups in each Windows native profile.
The disjoint batches contain core 19, source 11 and regression 19 groups. Core
includes seven new independent IR groups, eight predecessor join IR groups and
four native drivers for fourteen small compiler-metadata helper scopes. Source
includes five new groups with 38 fixtures and six predecessor join groups.

All 231 union inputs match checkout and Git raw bytes; all
216 production modules use LF. The unchanged admitted32/rejected33
fixture executed with default native stacks. Existing instruction prices and
ordinary/public gates remain unchanged. See [focused evidence](../evidence/value-view-origin-sets-windows-20261107.json).

# Private typed borrowed slice VM

Status: implemented and verified at `b8ba1e0`. Development and release each passed
19 native groups and 634 CLI cases. Both runs matched 348 identical current input
hashes; both retained CLI identities and all five matrix receipt hashes were rechecked.
See the [Windows evidence](../evidence/m2-slice-element-vm-windows-20261101.json).

The private VM executes readonly `i32`, `bool`, `i64`, `u8`, `u32` and `usize`
borrows. Shared `vm_execution` and `lifecycle.finish` accept such Programs after
complete `verifier.inspect`. Public `verifier.verify` still rejects every non-`u8`
borrowed site before VM backing, Fuel reservation or dispatch. This is a private
execution slice, not public promotion.

## Exact element tags

Borrowed and derived sites use the existing scalar tag values directly:

| Tag | Element | Read stride | Rootless read Fuel |
| ---: | --- | ---: | ---: |
| 2 | `bool` | 1 | 4,131 |
| 10 | `u8` | 1 | 4,131 |
| 1 | `i32` | 4 | 4,134 |
| 11 | `u32` | 4 | 4,134 |
| 9 | `i64` | 8 | 4,138 |
| 12 | `usize` | 8 | 4,138 |

The tag is a type identity, not a width category. Formal, derived and anchor sites
must match; owned sites keep zero and take their shape from the array catalog.

## Instruction checks

For a rootless instruction, the adapter checks opcode, function, frame, register
bounds, operand fields and static site metadata. A subslice requires matching
nonzero origin, function and exact parent/child tag. UTF-8 is `u8` only.

The runtime sequence is static type and operand checks; base Fuel; formal-root
and owner metadata checks; remaining full-range Fuel; then payload read or
ticket/register publication. No payload bytes are read before those checks pass.

Root resolution keeps the full owner generation token. Instructions compare both
slot and generation, the live descriptor's root, exact element tag and length
before changing a ticket or register. A stale generation, mismatched descriptor
or invalid runtime tag fails without publishing a result.

Rootless length and close cost 4,097 Fuel; a subslice costs 65,537. A typed read
uses the existing array rule, `4,097 + 33 + stride`, producing the table prices.
Owned-slice, scalar and other existing charges are unchanged. UTF-8 keeps its
full-origin cost, `4,097 + 4 * origin_length`, even for a shorter selected range.

## Borrowed calls

Borrowed CALL admission checks each borrowed formal's static site and scalar
element tag; borrow register types remain zero. It resolves the caller descriptor,
matches the destination formal and callee tag, then retains the full owner token.

For `n` borrowed formals, CALL reserves `65,537 * (n + 1)` Fuel: frame cleanup
plus one retained borrow each. Unborrowed calls add no reserve. Scalar arguments
and owned array/record charges keep their prices. New tickets and roots remain
staged until every retention succeeds; failure leaves the child frame empty.

Forwarding after the formal anchor closes resolves the origin back to the live
formal root. Reused child frames start with empty ticket/root bindings only;
scalar registers are not globally zeroed. Derived sites inherit the anchor tag
and matching origin/function identity, preventing type or stale-root drift.

## Leave and invocation cleanup

`leave` uses the prepaid cleanup reserve and does not refund Fuel. It checks each
actual owner type against its formal tag and verifies a nonzero bounded origin
length; selected ranges may be empty. Tickets are walked in reverse order, with
every root and descriptor authenticated before staging.

Pool and owner-table closes commit together. Ticket and root bindings are cleared
only after that metadata commit, so a late stale or duplicate ticket cannot
release part of the frame. `lifecycle.finish` then drains remaining sessions and
clears root bindings after complete inspection, preserving the original value
or error when cleanup succeeds.

## Public boundary

`verifier.verify` runs the full `inspect` proof, then rejects every nonzero
origin whose element is not `u8` with verification kind 5 before VM setup.
Public CLI `check` and `run` still return exit 6 for typed borrowed signatures.
A non-`u8` local slice bound to an owned array still fails source lowering with
a type error.

Public readonly `u8` slices, owned `u8` bindings and their existing CLI behavior
remain available. There is no new opcode, schema, version, capability, profile,
limit, heap allocation, payload clone, JIT or GC.

## Verification and limitations

```text
python -B tools/verify-m2-slice-elements.py --profile development --element-vm
python -B tools/verify-m2-slice-elements.py --profile release --element-vm
```

Development and release each passed 19 native groups: 5 new typed VM, 4 borrowed CALL,
4 dynamic frame and 6 lifecycle. Each profile passed 634 CLI cases: 252 typed
source-gate, 64 public u8, 74 source, 120 alias and 124 subslice. Both runs matched
348 identical current input hashes; retained CLI identities and all five matrix receipt
hashes were rechecked. The evidence records commands, inputs, artifacts and limitations.
Coverage includes scalar widths and signed edges, forwarding, cleanup, exact Fuel,
invalid bool, stale roots, UTF-8 and failure preservation.

Full M1 and full native suites were not rerun (`m1=null`); the parser and source-lowering implementation remains unchanged, while VM source and metadata checks changed.
Other M2, Linux, M0, isolation, packaging, allocator and timing were not rerun.

Public `u8` slices work; non-`u8` admission and typed owned-root source bindings remain gated. Mutable slices, slice results, escaping references, temporary roots and non-scalar elements remain unsupported.
No push, publication, release or deployment was performed.

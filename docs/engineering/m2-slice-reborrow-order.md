# Private reborrow creation order and reverse restoration proof

Independent inspection now aligns pending exclusive children with the strict
reverse restoration protocol of the [native authority stack](m2-slice-authority.md).
Two independent roots cannot restore the older child while the younger child's
receipt remains pending. Public and both internal execution entries continue
rejecting op61/62. CALL during suspension also remains gated.

## Immutable rank and pending mask

The existing immutable-code metadata pass records each derived child's unique
begin instruction PC in sixteen temporary words. It derives sixteen `newer`
bitmasks: bit j in `newer[i]` means child j has a later begin PC than child i.
Unused sites have zero masks. Ranks follow instruction position, not site ID,
root ID, origin number or range equality. Masks are internal verifier scratch,
never trusted Program metadata.

The existing live word already identifies pending children. An available child
has its bit in bits32..47; a child that suspended itself for a descendant has its
bit in bits48..63. Combining the two shifted words and intersecting with a
child's `newer` mask detects any younger pending child. Ordinary roots, formals,
shared views and unused sites are absent from these derived-child masks.

Both begin and end reject a nonzero intersection. Begin therefore pushes only a
rank greater than all pending child ranks. End pops the greatest pending rank.
Existing shape, parent availability, descendant exclusion, scalar bound
requirements and root conflict checks still apply. For independent roots this
also rejects an otherwise shape-correct crossing restoration.

## Flow invariant without another per-PC stack

Pending children are strictly ordered by immutable rank. A live word therefore
determines exactly one pending stack. Exact live-word equality at joins and
backedges already proves equal pending stacks; no extra per-PC order word,
worklist or mutable global verifier state is needed.

Balanced conditional lifetimes and repeated loop lifetimes remain legal. An old
begin instruction may repeat after all younger children have ended; it cannot
push underneath a still-pending younger child. This is an intentional private
IR admission rule, rather than an assumption about arbitrary backward edges.
Different functions have separate flow words; masks for other functions cannot
intersect a well-formed current function's pending children.

The metadata pass remains `O(N + S^2)` for N<=256 instructions and S<=16 sites.
Each begin/end order check is constant-time shifts, OR and mask intersection.
Additional logical scratch is sixteen mask words and sixteen temporary begin-PC
words. Program/signature/owner/pool/shared-frame declarations and per-PC live
storage do not grow. No measured native size, stack, allocation or timing claim
is made. Mask construction includes the highest site bit15.

## Scope and next integration

This tightens inspection of private op61/62 programs. Previously accepted
independent-root crossing restores now fail with kind5 at the offending end.
Such instructions were already rejected by public verification and both internal
execution entries, so no public source grammar, executable capability, opcode,
Fuel price or existing mutable CALL path changes.

The native authority stack itself is unchanged. The new tests compare actual
native independent-root restoration with IR admission, including failed older
restore followed by successful reverse restores. Native transactions still own
frame identities, combined CALL/reborrow depth, latest tickets and abort cleanup.
The proof is not dynamic bounds checking, metered reborrow dispatch or guest VM
execution. CALL while suspended remains rejected until the future adapter can
route every frame through combined admission and canonical receipt ownership.

Next is metered site/binding instruction adaptation and normal/abort lifecycle
integration with the shared VM, followed by deliberate private CALL inspection
admission. Guest syntax and public promotion remain separate deliveries.

## Verification selection

```text
python -B tools/verify-m2-slice-elements.py --profile development --reborrow-order
python -B tools/verify-m2-slice-elements.py --profile release --reborrow-order
```

Six new native groups cover all six scalar tags on owned/formal independent
roots, reverse/crossing restoration, balanced conditional/loop lifetimes,
unbalanced joins/backedges, reversed site allocation, synthetic available and
suspended pending masks, the highest child bit and actual native protocol
agreement. They run with six existing reborrow IR groups, five slice flow groups
and six native authority groups. Existing gate tests cover public and internal
execution, including private instructions in an unused function.

Implemented at `0163a26`. Development and release each passed all 23 selected
native groups and 2,495 CLI cases, with 379 matching current inputs. Compiler,
retained CLI and all matrix/M1 receipt identities were rechecked. Program and
signature declarations, owner/pool/native receipts/authority, verifier source,
execution core and CLI/compiler entries match `38c4a33`. Both profiles accept
parser depth32 in check/run and reject depths33/64 with `compile_limit`. See the
[Windows evidence](../evidence/m2-slice-reborrow-order-windows-20261102.json).

CLI regression covers 74 mutable-parameter, 222 owned mutable, 192 readonly
scalar and 2007 M1 cases on Windows. Full native, other M2, Linux, M0, isolation,
packaging, allocator, native size/stack and timing are outside the selection.
Local commits only; no push, publication, packaged release or deployment.

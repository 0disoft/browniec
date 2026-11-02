# Private canonical formal reborrow and data adapter

`slice_formal_reborrow_vm` connects private op61/62 and scalar range access to
[canonical CALL bindings](m2-slice-authority-call-vm.md). An immutable independently
inspected Program and the Sites derived from that same Program are prerequisites.
It supports owned roots and rootless exclusive formals, including nested and
empty selections. This is native adapter execution. It does not admit guest
syntax, public/internal op61/62 execution or suspended/derived CALL sources.

## Ownership and authentication

The adapter reuses `slice_reborrow_vm::Bindings`: three existing 31-entry site
columns, indexed by authority event position. It requires the existing canonical
CALL maps; no new persistent fields, duplicate Batch/Loan receipts, sessions or
payload extents are added. The owned-only adapter retains its previous API and
rootless rejection. Use one site-map collection and one canonical authority stack
for the complete invocation. With formal children, use this adapter for owned
children too; the legacy owned step rejects rootless maps. Do not alternate
finish helpers that omit live maps.

Static origin keys distinguish owned array IDs from exact formal anchors. Every
rootless derived site must reach its declared formal through the inspected forest.
Runtime validation checks the canonical CALL maps and every pending child map.
The first lexical child's original range, session and pool slot must match the
canonical formal CALL receipt. The formal must not be detached. Nested lexical
receipts must retain the previous child's exact selection, session and slot;
selected ranges must stay inside authenticated parents. Owned roots instead
match the frame-local owner token and immutable shape. All sessions are checked
against the live owner table. A child map cannot substitute an unrelated formal,
owned root, frame, range or session. Equal selected ranges still require the
correct site and reverse restoration order.

Available tickets must match their canonical issued slot, a current generation,
selected view and original write session. Suspended parents remain unavailable;
copying a child's ticket into a parent binding fails validation. Restored tickets
may have newer generations after nested work. No ancestor receipt is cloned or
replaced to accommodate that rotation.

## Transactions, data and Fuel

Begin/end cost 65,537 logical Fuel, checked after static guards and before runtime
map, owner, ticket or bound lookup. Begin checks combined restoration depth,
authenticates the parent, decodes relative usize bounds and invokes the canonical
native transaction. Only success publishes child maps and tickets. End requires
the exact top child event and an absent parent binding; only successful native
restoration publishes the fresh parent and clears the child map. Generation
headroom includes all outstanding CALL and lexical restorations, up to 31.

`access` implements op55 UTF-8, op57 length, op58 read and op60 write over available
formal or derived bindings, with the existing scalar widths and codecs. Prices
match existing adapters: length 4,097; read 4,130 + stride; write 4,130 + 2*stride;
u8 UTF-8 4,097 + 4*original_owner_length. The UTF-8 base is checked before runtime
lookup, and the full dynamic price before reading payload or publishing results.
These logical prices are not a measured timing or native operation-count claim.
Derived close must use op62; formal close uses canonical CALL release after its
children restore. CALL return requires all child events to have ended first.
Opening roots, shared slices, scalar/control copying, owned cleanup and aggregate
returns remain outside this adapter.

CALL exposes readonly `inspect` and `suspended` authentication. A shared `drain`
transaction drains the authentic pool before clearing CALL PCs, detached tickets,
all invocation ticket cells and shared origins. Both CALL-only finish and combined
finish use it. Combined finish clears the reused lexical site maps only after
drain succeeds. Failed drain retains every diagnostic map and overrides the
original result; successful cleanup preserves prior writes and the original
success/error. Owned roots are retained. No replay or rollback is introduced.

## Verification and remaining work

```text
python -B tools/verify-m2-slice-elements.py --profile development --formal-reborrow-vm
python -B tools/verify-m2-slice-elements.py --profile release --formal-reborrow-vm
```

The focused selection runs six new formal/data/lifecycle groups, six canonical
CALL groups and six owned reborrow groups. Public regression
covers 74 mutable parameter, 222 owned mutable, 192 readonly scalar and 2007 M1
CLI cases. New groups exercise all six scalar widths and actual writes, precise
Fuel boundaries, nested/empty ranges, stale and corrupt metadata, 29 recursive
CALL frames plus two lexical children at combined depth31, strict return order,
owned compatibility and failed/successful abort. Native transitions have their
own sufficient budget; no deep-call claim is made for the public CLI budget.

Shared execution-loop wiring and complete scalar/CALL/return/abort coordination
remain next. Suspended CALL proof, guest syntax and public promotion are separate
steps. Program/signature/owner/pool/shared-frame fields, existing public prices,
verifier admission and existing execution entries remain unchanged. Full native,
other M2, Linux, M0, isolation, packaging, allocator, size/stack and timing are
outside the selection. No push, publication, packaged release or deployment.

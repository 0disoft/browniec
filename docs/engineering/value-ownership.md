# Structural value properties and native Buffer handoff

## Structural prerequisite

`value_properties.fy` independently derives whole-type properties from a private
dependency-ordered type catalog. Its 64 nodes can describe six scalar types,
scalar fixed arrays, nominal plain records, Buffer, Option and Result. This is
analysis metadata, not executable admission or a guest type ID extension.

No caller supplies cached copyability, layout, depth or active-variant claims.
Scalar arrays retain lengths 1..4096. Plain records reuse the complete existing
field, cycle, depth-16 and layout proof with a 4096-byte ceiling. Their fields
remain scalar/plain-record only; Buffer, wrappers, arrays and references cannot
be introduced as record fields. References and void are not payload nodes.

Option and Result combine **both** payload types. Buffer makes the complete
type move-only, including Option.none, a scalar Result arm, and every enclosing
wrapper. The active variant cannot change that rule. Wrapper depth is at most
four and is independent of plain-record depth. Type bytes are checked against
65536 before addition/alignment. Every unused node and reserved field is checked;
forward/self/cyclic references fail instead of causing recursive traversal.
All node dependencies precede their parent, so shared subgraphs are evaluated
once. Work is O(nodes + record fields); there is no native recursive expansion.

Independent numeric examples include Option<i32> = 8 bytes, Option<Buffer> = 16,
Result<i64[4096],u32> = 32776 and four wrappers over Buffer = 40. Buffer tokens
occupy eight logical value bytes; those bytes are not its payload/accounting cost.
The `legacy` adapter derives layouts for the twelve current scalar/shallow-tagged
types. It does not alter their packed scalar-cell encoding, variant convention,
instruction prices or executable limits. The catalog's 64-node scratch bound is
private; it does not claim the full-profile compiler/type budgets are complete.

## Native Buffer handoff

`buffer_transfer::handoff` consumes a real `std::bytes::Buffer` and returns that
owning root in exactly one Result arm: success for admission, error for rejection.
The original native local cannot be used after the call. A successful handoff
keeps the same owner token, generation, payload length/capacity and logical
charge. It does not create a spare owner, copy payload bytes, allocate, retire
the token or alter any table/ledger field. An empty allocation still retains its
one 64-byte logical owner charge. A full table and a maximum generation do not
prevent a move because no slot or new generation is consumed.

The private template prepays 128 Fuel before token/table/backing checks. Less
than 128 returns the root and leaves Fuel unchanged. Admitted success and admitted
failure both spend 128. Owner-table validation and complete accounted-root
coverage, settled ledger counters, the shared close Plan and the selected
descriptor's read-lease state precede native length/capacity authentication.
The Plan matters even when another root is closing: its token is already retired
while its old charge remains, so settled ledger counters alone cannot detect
that pending destruction/refund. No fallible work follows successful admission.

This API follows the existing trusted native host association: the caller must
bind this exact allocation, token, table, ledger and shared close Plan together.
Matching length/capacity cannot authenticate a different same-shaped allocation.
It is not a guest token or a replacement for future independent guest source
binding/Dead-state proof. Native owning Result arms use Fairy C resource rules;
there is no new guest tagged representation or guest move opcode here. The 128
price is a private template and does not change any existing public Fuel price.
Intrinsic copyability likewise grants no access: source liveness, destination
authority, whole-root loans and alias/selected-place rules still need their
existing independent proof. A property's `copyable` flag is not native authority.

## Verification and remaining work

Run `python -B tools/verify-value-ownership.py --profile development` and the same
command with `--profile release`. The runner verifies the pinned compiler, locked
checkout, exact native identities, captured empty streams and unchanged input
hashes. It does not reuse historical results or override native compiler flags.

The four structural groups cover inactive/nested resource alternatives, depth 4/5,
independent record depth 16, maximum arrays, malformed/unused/reserved nodes,
forbidden scalar/record fields, cycles and all legacy tags. Four native ownership
groups move an allocated root twice and finally drop/refund it, reject stale or
mismatched metadata while retaining the root, block read leases/pending growth/
underaccounting and another root's real pending close, and admit full-table/
maximum-generation/empty-root moves. Budget checks exercise 127/128/129, plus
two successive moves at 256, with exact accounting/table snapshots. The evidence
receipt identifies the actual source inputs and executed profiles.

Guest Buffer locals/parameters/results, independent move/Dead CFG proof,
resource-bearing TAG_BUILD/TAG_UNPACK execution and payload cleanup, wide/nested
tagged source syntax, general reference/Buffer joins, must-use and Engine/Instance
ownership remain open. These helpers do not promote public capabilities, satisfy
full L04/L05/D01-D04, or provide guest admission. Grouped borrows and other pending
language/runtime/delivery work keep their existing scopes.

Windows development and release each passed all eight final native groups on
`ad3475c` (structural prerequisite `1186934`). The current input union matches
checkout and Git raw bytes; see the [Windows receipt](../evidence/value-ownership-windows-20261107.json).
Both final selections run fresh with no native overrides or historical reuse.
Public CLI/full language/native Fuel matrices, LF mirrors, Linux, OOM injection,
general stack/performance and clean-machine delivery were not run for this slice.
Local commits only; no push, release or deployment.

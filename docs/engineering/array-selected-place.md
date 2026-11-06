# Native owned-array selected locations

Date: 2026-11-06. This is the first L04 primitive, not source compound
assignment or the full SELECT_PLACE/PLACE_STORE/END_PLACE contract.

## Implemented boundary

`src/array_places.fy` captures one scalar element of a live, currently writable
owned array. Its native `Place` contains the original owner token/generation,
element type, array length, allocation mark/base/end, evaluated index and
recomputed byte offset. It is bound to one owner table and its unchanged backing
lifetime, exactly as existing owner tokens are. It is not a guest register,
pointer, reference, host grant or serialized capability.

Selection authenticates the complete owner ledger and bounds without reading
payload. An empty array view does not select an element; zero-length owned
arrays remain unsupported. An old noncanonical bool can therefore be replaced
by ordinary assignment, while explicitly reading that old bool still fails.

`read` and `store` re-resolve the captured token instead of looking up a caller's
possibly reassigned descriptor or index variable. They compare the exact shape,
reservation and offset again. Released, cleared, reused, malformed or currently
borrowed roots fail before payload access. Other RHS allocations and completed
loans may change the table cursor or loan epoch without invalidating a still-live
target. A completed loan is not confused with a live outstanding loan.

Compound lowering must retain the scalar returned by `read` **before** evaluating
the RHS. The primitive does not execute the RHS, evaluate an index expression,
perform arithmetic, or remember an old scalar implicitly. A later `read` sees
the then-current payload.

`store` uses the existing scalar codec's validate/stage/publish operation. A
failed revalidation or encoding preserves every backing byte and all metadata.
One operation scans at most 16 allocation-order entries plus 16 owner flags;
element encoding stages at most eight bytes. Snapshot storage is constant-sized,
with no heap allocation, guest owner/site or payload copy. No opcode, public
syntax, capability flag, operation price, CLI default or ceiling changes.

## Deliberately still open

This native snapshot does not pin the owner or enforce single use. Root release
invalidates it; it does not yet reject ROOT_END because an IR place is active.
Native structs are trusted/private metadata, not unforgeable guest values.
Source binding mutability, place identity across joins, active-place overlap,
END_PLACE, nonlocal-exit obligations and independent IR admission remain L04
work. Exclusive slice places, record field places, scalar-local places, grouped
lvalues and compound operator spelling/lowering remain unimplemented.

## Verification

Run `python -B tools/verify-static-execution.py --profile development
--selection array-places`, then repeat with `--profile release`. The selection
includes the new native cases and the existing complete owner, storage and layout
suites. Receipts fingerprint source, compiler and test discovery, verify the
locked LF mirror, and reject input changes or native compiler/stack overrides.

New cases cover descriptor/index changes, RHS allocation, a separately captured
old scalar, all six scalar domains, metadata-only bool selection and atomic
encoding failure, the 4096-element boundary, host-maximum indices, short backing,
stale/reused/cleared roots, outstanding/completed shared and exclusive loans,
malformed snapshots/ledgers and rejection of record tokens.

See [Windows evidence](../evidence/array-selected-place-windows-20261106.json).
No guest source/IR integration or its Fuel behavior is claimed by these tests.

Development and release each passed **24 native groups** (eight new and 16
existing), on 169 identical selected input hashes and 161 LF production modules.
Both locked LF mirrors passed. Executed inputs match the staged Git bytes;
separate discovery-only CRLF/LF differences are recorded in the evidence.
Public CLI/full language/Fuel matrices, Linux, OOM injection, general stack or
performance characterization, isolation and delivery were not rerun.

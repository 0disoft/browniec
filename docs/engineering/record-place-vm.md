# Metered owned-record selected-place storage

This follows the [independent record-place proof](record-place-ir.md). The
private adapter now executes record SELECT/READ/STORE and common END against
caller-owned backing. It does not grant ordinary, image or returned-reference
execution admission. Both VM drivers and source lowering remain separate work.

## Storage and ownership

`record_place_vm::requirement` validates canonical kind/ordinal/reserved bytes
and derives the highest shared place ID plus one, W in 0..16. Array-only and
slice-only programs retain their existing allocation formats and costs. When
any record selection occurs, one invocation-owned Vec has
`2 + 32*(14*W+1)` usize words: 482..7202, or 3856..57616 bytes on amd64.
The two format words are exactly `18432+W` and `2`. Legacy vector extents have
remainder zero/one modulo 32; the new format has remainder two, so neither its
length nor prefix can alias either older layout. There is no instruction-time
allocation, extra owner/reservation or fixed native-stack snapshot table.

All three kinds share fourteen-word rows and per-frame counters. A record row
holds owner slot/generation, nominal record, root byte length/alignment,
reservation mark/base/end, scalar ordinal and byte offset in words0..9.
Words10..12 must be zero. Word13 packs scalar tag in bits0..3, record site in
bits4..7, phase in bits8..9 and record kind in bit11. Slice kind uses bit10;
array kind has neither bit. No live row can be overwritten by another kind.
The common frame check recognizes the new format; END clears fourteen words
and decrements the counter without resolving a potentially stale owner.

The caller supplies its current canonical record token for SELECT. Later
READ/STORE reconstruct the original token, nominal record, scalar ordinal and
reservation, then reauthenticate through `record_places`. Rebinding a caller's
descriptor cannot redirect a saved location. READ captures one exact scalar;
STORE can follow SELECT directly or READ, but cannot run twice. Failed owner,
shape, phase, codec or ordinal checks publish neither payload nor phase.
Plain bool stores can repair a noncanonical old byte; compound READ rejects it.

## Fuel and limits

All operation prices include ordinary dispatch. A future retained driver must
add its existing separate dispatch unit; it must not silently reuse an ordinary
whole-invocation total. No new public syntax, capability flag, opcode, existing
operation price or CLI limit is introduced. Default Fuel remains 256 and the
explicit public ceiling remains 16000000.

| Work | Exact abstract charge |
| --- | ---: |
| No places | 0 |
| Array-only setup | Existing `257+10*32*(9*W+1)` |
| Slice/mixed setup without records | Existing `257+10*(1+32*(14*W+1))` |
| Record-capable setup | `257+10*(2+32*(14*W+1))`, 5077..72277 |
| Record SELECT | 41025 |
| Record READ | 41025+stride |
| Record STORE | 41025+2*stride |
| Common END in record-capable storage | 22 |

`prepare_metered` rejects insufficient Fuel before Vec reservation. Allocation
returns the private vector; its coordinator must debit the plan cost once on
successful publication. `step` returns the remaining balance. Every instruction
checks its full charge before owner-ledger/catalog traversal or snapshot,
register and payload publication. Array/slice operations in the new vector
retain their previous extended instruction costs. Scalar stride is 1/4/8;
payload work is independent of aggregate size and touches at most eight bytes.
All schedule arithmetic uses independently bounded W<=16 and stride<=8.

Record metadata costs `32768 + 4*2048 + 65 = 41025`. SELECT and subsequent
revalidation each authenticate the complete 32-visit owner ledger and call the
iterative catalog planner twice. Catalogs contain at most 32 records and 512
field slots; validation, dependency resolution and layout each visit a field
at most once. Validation headers, root checks and record completions each add
at most 32 visits per plan. Two plans therefore need at most
`2*(3*32+3*512)=3264` logical record/field visits. A depth-first walk
through at most 128 scalar leaves at depth16 takes at most `2*16*128=4096`
descents/ascents. These visits plus ledger/row bookkeeping fit four existing
2048-visit allowances. The existing 32768 transaction envelope separately
covers bounded plan/cursor initialization, copies, staging and failure paths;
65 covers dispatch/snapshot bookkeeping. These conservative abstract charges
are not timings. Changes to these capacities require a new audit.

## Admission and remaining work

Only private native calls can use this adapter. `place_vm` and `slice_place_vm`
still reject record instructions in requirement/cost preflight; recognizing
the new private Vec format grants no Program admission. Both VM coordinators
must resolve current live record tokens from canonical frame/site state, prepay
setup, dispatch kinds, preserve CALL/lexical cleanup and protect returned roots
before executable kind2 is enabled. Image/recipe guards and record source
selection/compound lowering remain next. Scalar-local/grouped places, generic
aggregate overlap and full L04/C05/Instance/host/delivery remain open.

## Verification

The focused `record-place-vm` selection covers native exact/one-short effect
preflight, six scalar tags, field/nominal/snapshot corruption, replacement and
descriptor changes, bool repair, stale/reused owners, mixed IDs/formats and
frame31/ID15. It includes existing array/slice storage, record proof and original
ordinary/retained 32/33 CALL-bound regressions. Public CLI Fuel checks retain
their separate scope. Full language/original full native Fuel matrices, Linux,
OOM injection, general stack/performance, worker isolation and packaging/
clean-machine delivery are not implied by these checks.

Windows development/release each passed **34 native groups** and **57 tool-free
public Fuel CLI cases**; see [the evidence](../evidence/record-place-vm-windows-20261106.json).
The 189-path input union matches checkout and staged Git raw bytes.
Both locked LF mirrors pass with 170 production modules and
292-file discovery. The 40 unselected CRLF/LF-only discovery differences
are recorded separately. No historical result reuse or native compiler/linker/
stack overrides were used. Skipped scopes above remain unverified here.

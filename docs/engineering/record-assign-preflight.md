# Share whole-record assignment preflight

array_owners::assign_record implements whole-record copying at the native owner
boundary used by struct_vm opcode 46. It previously called resolve_record for
each owner, independently validating the same immutable owner table and planning
the same catalog twice, before raw storage assignment built its third plan.
This metadata work repeats on every assignment, including self-assignment.

The wrapper now authenticates the destination token, complete table and record
kind with inspect_record_owner, builds one fresh local plan, and checks the
destination nominal ID, byte length and alignment with record_metadata_prepared.
The existing private record_owner_prepared then checks source token identity,
kind and shape against that plan. This is safe because the entire table has
already passed validation and neither table nor catalog changes in this call.
The exact nominal type comparison still precedes raw storage assignment.

## Authentication and publication

The error order remains destination token, complete table, destination kind,
full catalog/destination shape, source token/kind/shape, nominal equality, then
checked storage extents and source payload. A bad catalog still wins over a
stale source token. An array destination still returns Type before planning.
Same-shaped records with different nominal IDs still fail Type; an absent
owner record or wrong length/alignment still fails Metadata before that match.

One complete table validation covers both identities, including all unrelated
owners, allocation order, retained holes, loans and arena reservations. The
source identity lookup remains mandatory. No unchecked lookup becomes public,
and no external Plan, persistent proof, cache, heap allocation or new API is
introduced. Each invocation independently checks current metadata.

Raw struct_nested_storage::assign retains its independent fresh plan, both
extent checks, copy proof and existing zeroed 128-byte canonical snapshot. It
checks all source bools before publishing. Self-assignment still reads/validates
the source and normalizes padding; no identity shortcut skips these operations.
An invalid old destination bool may be overwritten from a valid source. Failed
copies leave all backing unchanged. Tokens, owner state, reservation, quota and
Fuel prices remain unchanged. See [record owners](m2-struct-owner-copy.md) and the
existing [subrecord planning](subrecord-assign-plan.md) for adjacent boundaries.

## Structural cost

For a successful whole-record assignment, complete layout plans drop from three
to two. Fixed catalog slots fall from 1536 to 1024 (one third removed), and fixed
record rows from 96 to 64, plus one removed dependency/offset planning pass.
For 4096 assignments the field-slot count falls from 6291456 to 4194304,
removing 2097152 inspections and 4096 dependency/offset planning passes.

Complete owner-table validation falls from two calls to one. With D retained
owners, its successful loops visit D+16 entries per validation. At D=16, visits
fall from 64 to 32 per assignment, or 262144 to 131072 over 4096 assignments.
Both token identity lookups remain; raw storage arena checks remain independent.

Asymptotic complexity stays O(T+S+R+F+B), where T is table validation, S=512
fixed catalog slots, R<=32 records, F<=512 active fields and B<=128 staged bytes.
The repeated full-table and full-catalog factors are reduced. Source payload
reads/writes and the 128-byte payload scratch are unchanged. These are source
operation counts, not measured throughput, machine instructions or physical
stack/memory peaks. Other record creation/copy/subrecord APIs are unchanged.

## Focused verification

Run python -B tools/verify-record-assign-preflight.py --profile all.
The selection has six native groups per profile, with byte-identical locked
production mirrors, the pinned compiler and default native stacks.
The frozen 37ba32f assignment algorithm retains two independently authenticated
owners and raw checked storage; resolve_record itself is unchanged.

Two new groups compare 1618 inputs. Each compares successful lengths or exact
error codes and all 256 backing bytes. Every failed copy must preserve the
original backing. They cover:

- 1024 catalog field-slot corruptions, 32 row corruptions and 36 catalog/error
  contexts, plus 192 mutations across all sixteen owner slots.
- Eight invalid/array-token contexts, ten ledger/order/arena corruptions, two
  same-layout nominal mismatches, four structurally valid-table shape faults,
  three competing errors and four backing capacities.
- Eight bool/self-copy cases, replacement of an invalid old destination bool,
  and two noncanonical-padding copy/self-copy cases.
- Three valid maximum-size copies, 256 bad-bool copies covering all 128 leaves
  and self-copy, 32 depth/nominal combinations and a depth-17 rejection.

Four existing groups cover exact nominal rejection, maximum 128-byte payloads,
owner metadata preservation, direct VM prepaid Fuel and one-unit-short failure,
and all sixteen owners with full backing, deferred holes, release and reuse.
Receipts are under build/record-assign-preflight/<profile>.

Full Engine, standalone memory, public CLI and full release gates are outside
this focused change; public admission is unchanged. The prior legacy source
failure recorded in subrecord planning was not rerun or claimed fixed. Final
profile results and tested input/commit identity are in the
[evidence](../evidence/record-assign-preflight-windows-20261115.json).

Development and O2 each passed all six selected native groups. All 376 receipt
inputs match tested working bytes. Against implementation 1326600, 375 match raw
Git bytes; the unchanged tests/m2/struct_vm.fy differs only by CRLF/LF endings.
Its normalized bytes match, and both raw hashes are recorded in the evidence.
The root check passed with 375 sources and 4092 MIR functions; its lock update
is included in the implementation. The guidance body after its heading is
byte-identical to the prior checkpoint.

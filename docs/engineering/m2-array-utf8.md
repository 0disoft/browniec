# Metered UTF-8 predicate for live u8 arrays

Implemented as a private IR/VM operation. Source syntax and version capabilities
are unchanged: this slice does not expose a new guest builtin, Buffer or text
type. It connects existing array ownership/storage to UTF-8 validation before
frontend syntax is introduced.

## Instruction and independent validation

`ir::array_utf8(program, array_id, offset)` emits opcode **51** with a fresh bool
destination, `a=array_id`, `b=0` and all four reserved bytes zero. The builder
rejects non-u8 or out-of-range catalog entries. The independent verifier checks
the same type, catalog/function ownership, live-set membership, bool destination,
single scalar definition, non-slot destination and canonical operand bytes.
The source stays live; the instruction neither moves nor drops it.

Opcode dispatch explicitly routes 51 to the array path rather than the existing
41-and-above record path. Array reads and this predicate both select their source
catalog ID from operand `a` for cost calculation. Other opcode behavior is
unchanged; 52 and higher still fail independent verification.

## Fuel and runtime ownership

The operation costs **33 + 4 * length** Fuel. Existing checked layouts restrict
length to 1..4,096 and stride to one byte, so the charge is 37..16,417 and cannot
overflow. VM execution subtracts the entire charge before forming the array view
or scanning bytes. Insufficient Fuel leaves this operation's destination and
array state untouched. Invalid UTF-8 has the same prepaid cost as valid input,
even when the native validator can stop early.

Runtime uses the current frame's token, validates token identity and the full
owner/arena chain, then requires a u8 owner and the exact catalog length before
slicing its initialized extent. Matching array/result shape does not authorize
a record or bool token. Stale tokens, wrong backing bounds, malformed metadata
or shape mismatch return the existing verification/state error instead of a
UTF-8 result. Defensive execution also rejects malformed operands and frame/
register bounds before changing the result register.

The SDK UTF-8 validator returns a canonical bool cell (1 or 0). ASCII/NUL and
valid multibyte sequences return true; malformed encodings return false. Payload,
owner metadata, frame tokens, live sets and arena usage remain unchanged. There
is no result cache, normalization, text ownership transfer, payload copy or new
allocation in the predicate path. Allocation instrumentation and process-memory
measurements were not performed for this slice.

The scan is synchronous and bounded by the existing maximum array length. It
does not use Buffer scan sessions or provide cooperative interruption inside an
individual scan. Future Buffer/text source integration remains separate.

## Focused verification

Run `python -B tools/verify-m2-array-utf8.py --profile development` and repeat with
`--profile release`. The harness verifies the pinned compiler checksum/revision,
SDK and root lock, hashes source/test/tool inputs and checks native results and
tool-free CLI sentinels. The focused
[Windows receipt](../evidence/m2-array-utf8-windows-20261029.json) records both runs.

Each profile selects 25 native groups: six new UTF-8 groups, five existing array
IR groups, six array VM groups and eight struct VM groups. It also builds the
native CLI and runs eight existing check/run sentinels covering scalar, array,
struct and honest rejection of guest Buffer syntax.

The six new groups cover:

- Valid four-byte scalars, ASCII/NUL, overlong encodings, UTF-16 surrogate
  encodings, values above U+10FFFF, stray continuations and truncated input.
- Exact total Fuel `146+6*N` for the direct-IR test program at N=1, 4 and 4,096;
  one unit short rejects, and a short pre-scan budget reports the operation's
  source offset. Fresh reuse succeeds after a Fuel failure.
- Independent rejection of malformed types, operands, reserved bytes, reused or
  slot destinations, invalid catalog IDs, unknown opcode and dead source owners.
- Frame-local tokens and unchanged complete owner table, initialized bytes,
  arena counters and unrelated scalar registers across valid/invalid scans.
- Missing backing, stale tokens, wrong lengths, malformed arena metadata and
  valid bool owners rejected at the storage boundary.
- Builder type rejection and successful drop after the predicate, proving that
  the operation leaves its source owner live.

Native test images are managed by the Fairy test runner; CLI hashes and all
native test identities/outcomes are recorded. Both verified CLI executables are
retained in the ignored build directory and rehashed at archive time. The archive
rechecks both profiles'
matching input sets and retains their original receipt hashes. Earlier Buffer
lifecycle/Provider receipts remain historical for their exact inputs.

Full native/CLI suites, Buffer lifecycle/Provider probes, M0, Linux, DLL embedding,
isolation, packaging, allocator instrumentation and elapsed-time performance
were not run. Source-level calls to this predicate remain a following slice.

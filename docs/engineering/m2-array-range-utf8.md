# Metered UTF-8 range instruction (opcode 52)

This slice adds a private IR/VM operation that validates UTF-8 over an explicit
byte range of a live `u8` array. It stays below the frontend: guest syntax, type
rules and version capabilities are unchanged. It publishes no text or Buffer
type, returns a plain bool, and is the backend companion to the whole-array
predicate in [m2-array-utf8.md](m2-array-utf8.md).

## Instruction encoding

`ir::array_range_utf8(program, array_id, start, end, offset)` emits opcode **52**
with a fresh bool destination `dst`, `a = array_id`, `b = 0`, and the endpoints
as unsigned 16-bit little-endian values: `start` in bytes 4..5, `end` in bytes
6..7. The builder rejects a non-`u8` entry, an unknown catalog ID (`>= 16`),
`start > end`, `end` past the catalog length and `end > 4096` before emitting
anything; a rejected request leaves program count, registers and code untouched.

## Independent verification

Dispatch sends 51 and 52 to `array_verifier::step` and keeps them off the
41-and-above record path. The catalog ID comes from operand `a`; the entry must
exist, belong to the current function and be `u8`. The source array must be live
in the current function, `b` must be zero, and the destination must be a function
register that is not a slot, holds no prior definition, and is typed bool.
Endpoints are decoded and checked with `start <= end` and
`end <= lengths[array_id]`. Opcode 52 is exempt from the zero
reserved-byte rule applied to other upper opcodes; 53 and above still fail
verification, as do dead or foreign sources, malformed endpoints and a reused
destination.

## Runtime behavior and Fuel

`array_range_vm::step` runs synchronously in the current frame and re-checks
program bounds, the opcode byte, `b = 0`, frame and register bounds, catalog ID,
shape and range before touching state. The 1..4,096 length limit and one-byte
`u8` stride stay in place.

Fuel is prepaid in full before any byte is examined: **65 + 4 * K**, with
`K = end - start`. The charge covers the two bounded owner-chain checks plus up
to four units per selected byte, so it ranges from 65 for an empty range to
16,449 for 4,096 bytes and cannot overflow. Insufficient Fuel returns the
existing Fuel error at this operation's source offset and leaves the destination
and array state unchanged. Invalid UTF-8 costs the same as valid input.

The scan allocates nothing, copies no payload, mints no owner slot, opens no
Buffer scan session and keeps no retained read lease. It reads the selected bytes
and writes a canonical bool (1 or 0); owner table, arena counters, frame tokens,
payload bytes and unrelated registers are unchanged on both outcomes.

`owners::view` validates token identity, generation, liveness and the backing
capacity window; the runtime then requires the resolved element to be `u8` and
the resolved owner length to equal the catalog length exactly. A record or bool
token, stale generation, mismatched length or malformed arena metadata fails at
this boundary before any UTF-8 result exists. `owners::view_utf8` resolves the
view again, re-checking the owner generation and bounds against the current
byte buffer before validating the slice
`bytes[owner.base + view.start .. owner.base + view.end]`. Empty ranges are
valid: `start == end` yields true at the minimum charge.

Only the selected slice is scanned, so segment boundaries are independent of the
whole array: a slice holding valid UTF-8 returns true even when bytes outside it
are malformed, and a slice that cuts a multibyte sequence returns false.

Guest syntax and capabilities are unchanged; the instruction is reachable only
from generated IR. Borrow syntax, borrow lifetimes and origin-to-backing
association for guest programs remain pending. The synchronous instruction
leaves no persistent borrow behind. Pairing the owner table with its backing
buffer is a trusted native caller obligation; the VM always supplies its own
matching pair.

## Focused verification

Run `python -B tools/verify-m2-array-utf8.py --profile development --range-vm`
and repeat with `--profile release`. The harness pins the compiler checksum and
revision plus the SDK and root lock, and hashes source, test and tool inputs.
Each profile selects **41 native groups**: six new range groups, six whole-array
UTF-8 groups, five array IR groups, six array VM groups, eight struct VM groups,
five read-lease groups and five view groups. It also builds the native CLI and
runs **14 sentinel invocations** (seven programs through `check` and `run`),
covering scalar, array and struct programs plus honest rejection of guest Buffer
and guest borrow syntax.

The six new groups cover selected bytes and empty ranges across independent
segment boundaries; prepaid cost at lengths 1, 4, 256 and 4,096 with a one-unit
short fallback and a short pre-scan budget; verifier rejection of bad ranges,
types, destinations, dead or foreign sources and unknown opcodes; defensive
runtime errors that preserve destination and storage; a last-frame read with all
sixteen owner slots occupied and no new owners or session changes; and builder rejection
before publication together with little-endian encoding of `start = 256`,
`end = 4096`.

Development and release each passed all 41 native groups and 14 CLI sentinels.
The implementation is committed at `65af78d`. The [Windows receipt](../evidence/m2-array-range-utf8-windows-20261030.json)
records both runs, matching input hashes, compiler/SDK identities, original
receipt hashes and retained CLI executable hashes. The implementation was
committed after development verification while release verification was running;
its tested source/tool hashes are identical in both profiles. Earlier receipts
remain historical for their exact inputs.

Full native and CLI suites, Linux, M0, DLL embedding, isolation, packaging,
allocation instrumentation and elapsed-time performance were not run for this
slice.

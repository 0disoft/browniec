# Private Buffer instructions and native execution

The retained typed dialect independently admits and executes Buffer operations
99..104. It uses the existing native root/frame store, including authenticated
serials/bindings, checked generations, combined quotas and prepaid cleanup.
Public compiler/CLI/capability gates remain unchanged. General source references,
views, Buffer methods and input/output composition remain implementation work.

## Instruction contract

Every instruction retains the eight-byte format. Bytes4..7 are reserved zero.
Buffer operands name live exact Buffer slots in the current function. Ordinary
scalar operands require independent type, initialized/fresh and nonslot proof.

| Opcode | Operands | Effect |
| --- | --- | --- |
| 99 LEN | usize register dst, Buffer a, b=0 | Inspect length; retain owner. |
| 100 READ | u8 register dst, Buffer a, usize index register b | Read initialized byte; retain owner. |
| 101 WRITE | Buffer dst, usize index register a, u8 register b | Write initialized byte; retain owner/generation. |
| 102 PUSH | fresh Result value dst, Buffer a, u8 register b | Append one byte; retain Buffer. |
| 103 RESERVE | fresh Result value dst, Buffer a, usize register b | Reserve at least b capacity; retain length. |
| 104 APPEND | fresh Result value dst, Buffer a, distinct Buffer b | Append b to a; preserve b and retain both owners. |

The private Result representation is exactly Result<usize,u8>. Success carries
new length for push/append and actual capacity for reserve. Allocator failure
returns error byte 1. Fuel, hard quota and bounds remain execution errors. This
private bridge does not define a public AllocError type or guest API signature.
The Result is copyable; CASE retains it, so normal paths still drop/return it.

The independent value CFG proves exact initialized/Dead state, fresh Result
destinations, nonconsuming reads/writes and distinct live append inputs. The
ordinary CFG separately proves scalar definitions/reads. Ordinary/image/returned
reference executable admissions retain their rejection gates.

## Publication and native ownership

Length/read/write use the existing authenticated frame operations. Growing
instructions prepay Result publication and admit its exact fresh destination
before touching a root. The native Buffer operation changes no frame bytes or
initialization order. Its success or allocator error then publishes canonical
sixteen-byte Result data without allocation, callbacks or further guest Fuel.
Postmutation trusted-invariant failures are fatal, not recoverable rejections.

Append authenticates both roots and rejects self-aliasing before extraction.
Its destination becomes one owning local; the source stays in the root or
scratch vector under an immutable borrow. No input-sized scratch allocation is
needed. Both vector directions restore positions on every recoverable result.
The common append transaction retains the old allocation through preparation,
drops it before refund and publishes one new generation. Source read leases are
allowed; destination leases still reject mutation. Source bytes/generation and
neighboring roots remain unchanged.

## Fuel and verification

Let L be old destination length and S source length. Total native instruction
prices include the frame template and, where needed, prepaid Result publication:

| Instruction | Fuel |
| --- | --- |
| LEN | 2336 |
| READ / WRITE | 2337 |
| PUSH | 6240 + 4(L+1) |
| RESERVE | 6240 + 4L |
| APPEND | 6496 + 4(L+S) |

Append-from pays 512 metadata first, then the remaining payload allowance. Prior
admitted charges survive a later failed admission; rejected work preserves live
data/owners/accounting. Existing opcode prices and public default256/cap16000000
remain unchanged. Resumable work quanta and full Engine/Instance accounting are
separate work.

Run `python -B tools/verify-value-buffer-execution.py --profile development` and
its release counterpart. `--discover` only lists identities. Windows development
and release each passed ten groups on `6107487`: five new instruction/ownership/
publication groups and five tag/root regressions. All 210 inputs match checkout
and Git raw bytes; all 202 production modules are LF. Both runs use fresh,
byte-identical locked mirrors with no native overrides or historical reuse.
See [Windows evidence](../evidence/value-buffer-execution-windows-20261107.json)
and [input manifest](../evidence/value-buffer-execution-inputs-windows-20261107.json).

Actual native CASE extraction caught the initially inverted Result storage tags;
canonical success0/error1 was corrected before both final profile runs. The
existing conditional-depth fixture is byte-identical but was not selected here.
Actual allocator failure injection, full language/CLI/native Fuel matrices,
Linux, general stack/performance and clean-machine delivery were not run. Local
commits only; no push, release or deployment.

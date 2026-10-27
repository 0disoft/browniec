# M2 Private Frame-Local Record VM

- Status: private frame-local record execution verified in development and release.
- Scope: frame-local execution of verified record IR opcodes 41..49 in up to 32
  guest frames, with sixteen static record sites and one shared owner table and
  payload arena.
- Predecessor: [private function-owned record IR](m2-struct-function-ir.md).
- Implementation: [record dispatch](../../src/struct_vm.fy) and
  [VM frame routing](../../src/vm.fy).
- Implementation commit: `80ed712`.
- Tests: [seven new frame-local cases](../../tests/m2/struct_function_vm.fy) and six
  [function-owned IR cases](../../tests/m2/struct_function_ir.fy).
- Aggregate selection:
  `python -B tools/verify-m2-struct-values.py --function-vm`.
- Evidence: [Windows receipt](../evidence/m2-struct-function-vm-windows-20261027.json).

This successor removes the entry-only runtime boundary from the function-owned
record IR foundation. Verified helper IR now executes with frame-local record
tokens. Source helper records, record parameters, record results, and borrows
remain unsupported; this slice adds no frontend or version capability.

## Frame slots

`struct_vm::State` now holds `owners::Token[512]` instead of sixteen tokens.
Each guest frame owns a consecutive sixteen-slot group, so a static site `id`
uses `frame * 16 + id`. The VM already bounds calls to frames 0..31, and record
dispatch rejects `frame >= 32` before indexing the token array.

The layout matches the existing array frame scheme. Recursive invocations can
therefore keep independent record bindings for the same static sites while all
frames continue to share the sixteen owner descriptors and the single payload
arena. Entering a frame allocates no separate owner table or arena. `SINIT` and
`SCOPY` still reserve records in the shared owner table and payload, so they
consume the same quotas as before.

The token array is fixed at 512 slots. This document makes no measured claim
about allocation bytes, stack use, or speed.

## Execution rules

Opcodes 41..49, operand encoding, Fuel charges, and preparation behavior are
unchanged. Every record operation uses the token belonging to the active frame.
`SINIT` and `SCOPY` require a dead destination token; successful execution
reserves an owner and payload extent. `SREAD` and `SDROP` require a live token.
`SWRITE`, `SASSIGN`, `SSUBASSIGN`, `SREPLACE`, and `SSUBREPLACE` require a
live mutable destination. Copy, assignment, and subrecord sources must be live
under the same frame. Generations and nominal identities are checked on access.

The call-depth limit remains 32 frames. Depth checks report error kind 12 before
entering frame 32. The defensive record-dispatch check for a direct call with an
invalid frame reports kind 5 before token access. Insufficient Fuel still reports
kind 8 before any owner, byte, register, or token mutation.

Copy, assignment, and subrecord operations continue to validate source and
destination under the same frame. A generation retained from a released child
frame cannot read a slot reused by a later call. A live parent record remains
accessible while child records are created and dropped, and released child
records return their shared owners and payload extents for deeper calls. A drop
clears the frame token; dead middle extents stay charged until suffix reclamation.
The helper/array-result fixture covers that release before transferring a result
while a caller record remains live.

## Source and version boundary

The source compiler still emits records only in the entry function. Helper-local
record declarations, record parameters and results, record argument capture, and
borrows remain rejected. This is private IR/VM support for verified programs, not
source helper record support.

No opcode, Fuel charge, frontend lowering rule, source profile, or version JSON
field changes. The five predecessor CLI matrices are regression checks in the
aggregate selection.

## Verification

The complete `python -B tools/verify-m2-struct-values.py --function-vm` invocation
passed in development and release without reusing prior results. Each profile
passed 46 native groups: seven frame-local record VM, six function-owned IR,
nine existing IR, eight existing VM, six root replacement VM, six child
replacement VM, and four atomic-assignment groups. The 2,383 CLI cases per
profile comprise 103 child constructor, 97 root constructor, 83 child-path,
131 subrecord-assignment, and 1,969 M1 scalar cases.

The seven new groups exercise all record opcodes in frames 0, 1, and 31; exact
Fuel prepayment; invalid frame 32 and usize-max rejection; foreign dead bindings;
all 512 token slots remaining unchanged on failure; shared array/record quota and
payload limits; stale generations; parent values across recursive helper calls;
repeat calls reusing child frames; and record cleanup before an array result
transfer beside a live caller record.

A depth-15 recursive helper keeps 16 records live and returns 120 in 64 payload
bytes with exactly 1,400,064 Fuel. One less Fuel fails with kind 8, 63 payload
bytes fail with kind 13, and depth 16 exceeds the shared owner limit. Releasing
the local record before each child call instead reaches all 32 VM frames using
four payload bytes; the next call fails with kind 12. Three repeated calls pass
in both modes. The array-result fixture succeeds in 12 bytes and fails in 11.

The [receipt](../evidence/m2-struct-function-vm-windows-20261027.json) records
input hashes, compiler/SDK identities, commands, native/CLI outcomes, and
artifact hashes. All recorded inputs and compiler hashes, the release binary,
and equal native identities across profiles were rechecked before archival.
SDK lock identity is unchanged; the compiler remains `4ce1264273be`.
Implementation commit: `80ed712`.

Earlier receipts remain historical for changed runtime, root-lock, test and
harness inputs. Source helper-local records, record parameters/results and
borrows remain unsupported. Full native suites, other struct/array CLI matrices,
M0, Linux, packaging, DLL, isolation, allocation instrumentation and performance
were not run. No measured stack-size or speed claim is made.

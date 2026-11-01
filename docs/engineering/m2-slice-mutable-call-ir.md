# Private mutable scalar-slice CALL IR proof

Independent IR inspection now admits exact mutable slice arguments and formal
forwarding. This connects the [formal IR](m2-slice-mutable-parameters-ir.md) with
the argument-proof prerequisite of the [native handoff protocol](m2-slice-exclusive-call-handoff.md).
It does not publish runtime handoffs, execute mutable formals or enable guest
mutable parameters. Public owned mutable and readonly behavior remains unchanged.

## Exact arguments and batch uniqueness

`slice_parameters::argument` still requires a declared formal, source encoding
160..175, a live source ticket and the correct owning function. Access modes must
match exactly: exclusive-to-shared and shared-to-exclusive coercions fail. The
owned-root branch compares the root's exact scalar tag with the decoded formal
tag and requires a mutable owned root for an exclusive source. The root itself
must remain live. Rootless forwarding compares exact formal tag/mode bytes and
retains the existing origin/function proof. Mutable derived sites remain invalid
under whole-Program metadata validation.

`slice_builders::argument` encodes one checked source. It cannot prove uniqueness
across multiple arguments. Both scalar-result and aggregate-result CALL inspection
use the shared `array_parameters::arguments` batch proof. Two local bit sets track
exclusive static sites and statically known owned roots. A second occurrence of
either fails at the CALL PC. Shared duplicates remain valid. There is at most one
constant amount of extra bit-set work per argument, bounded by eight arguments;
no pairwise scan, new Program field, heap allocation or payload access is added.

The batch proof continues to check interleaved scalar definitions, immutable
owned array shapes, exact nominal record arguments, readonly slices and unused
argument bytes. Wrong kinds, tags, functions, dead roots/tickets and malformed
metadata remain errors. Eight distinct writer arguments can use the existing
sixteen-site namespace: eight formals plus eight owned caller slice sites.

## Lifetimes and execution boundary

CALL keeps the caller's loan live set unchanged, representing synchronous
transfer followed by successful restoration before the caller resumes. Reads,
length and close after CALL are independently checked against this retained live
set. Recursive and mutually recursive formal forwarding are inspectable; this
is not runtime recursion or mutable-formal write execution evidence.

Public `verify` first performs the complete independent proof, then rejects all
rootless exclusive formals at offset zero, before VM allocation, Fuel or dispatch.
A malformed CALL retains its CALL-PC proof error instead of being hidden by that
gate. Existing native CALL cost and frame adapters also reject mutable signatures
before publishing registers, return metadata, owners, tickets or backing bytes.
The new tests check these unchanged runtime boundaries with empty backing and
sentinel registers/return frames. Guest mutable parameter syntax stays rejected.

No opcode, public capability, profile, instruction price or Program field changes.
The previous native generation handoff implementation is unchanged. Its future
runtime integration must authenticate dynamic roots and exact sessions, stage
handoffs before mixed copies, prepay complete costs, replace caller/callee ticket
bindings and restore authority before resuming the caller. Formal close must
release the formal binding without prematurely ending the caller's write session.
Global abort drain remains distinct from normal return restoration.

## Verification

```text
python -B tools/verify-m2-slice-elements.py --profile development --mutable-call-ir
python -B tools/verify-m2-slice-elements.py --profile release --mutable-call-ir
```

The selection includes six new mutable CALL proof groups, six formal IR groups,
five readonly borrow-flow groups and four parameter groups. CLI regression covers
222 public owned mutable, 192 readonly scalar and 2,007 full M1 cases. These CLI
cases exercise existing public behavior; new mutable CALLs are inspection-only.

The new groups cover all six scalar tags and signed/unsigned extremes in IR,
caller lifetime continuation, recursive and mutual forwarding, eight distinct
writers, duplicate owned/formal sources, duplicate statically known roots, shared
duplicates, exact mode/tag/kind rules, dead and foreign sources, mixed signatures
and public/native execution gates. They do not claim payload writes by mutable
CALLs, new Fuel accounting, runtime rollback or performance measurements.

Development passed all 21 selected native groups and 2,421 CLI cases. Release
verification and the combined evidence record follow in a documentation commit.

Full native, other M2 suites, Linux, M0, isolation, packaging, allocator and timing
checks are outside this selection. Local commits only; no push, publication,
packaged release or deployment. Earlier evidence remains historical at its own
source identities. Next is mixed runtime CALL admission and staged frame
publication, followed by return restoration and mutable formal dispatch.

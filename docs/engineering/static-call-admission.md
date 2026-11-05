# Static CALL analysis with canonical scalar and ownership proof

Date: 2026-11-05. This follows the [CALL recipe proof](static-call-ir.md).
`verifier::verify_static_calls` combines independently reconstructed Static
signatures, image windows, origins and CFG lifetimes with the existing complete
scalar, array, record and runtime-loan verifier. Its copyable `StaticCallProof`
is private analysis metadata; it neither retains an image nor enables execution.

## One complete analysis path

The recipe checker first validates the real image and PARAM 77/CALL 78/RETURN 79
instructions. The canonical verifier then checks every function, including
ordinary register definitions/types, slots, aggregate metadata, CALL arguments,
result destinations, owner lifetimes and loan/reborrow rules. A valid recipe
alone cannot bypass those checks.

Static formals occupy reserved type-zero positions. They enter the written set
but never the scalar-defined set. They cannot supply a scalar return, argument,
index or computation, or receive a scalar instruction result. At a mixed CALL,
only independently classified Static positions bypass the ordinary argument
classifier; scalar, owned array, record and loan positions retain their normal
signature-selected encoding and canonical checks.

CALL 78 uses the callee's proved result class: a fresh Static site, the existing
array/record result checker, or a typed scalar destination. RETURN 79 requires
exactly its selected Static view and no remaining array, record or loan state.
Static image storage cannot hide an ordinary owner leak. Static and ordinary
live states must both agree at CFG joins and loop backedges.

## Possible roots and actual windows

`static_call_sites::prepare` derives image-root sets from the proved recipes.
Each OPEN is a root with its exact admitted image window. PARAM unions its real
actuals across CALLs; BYTES, ALIAS and RANGE propagate their source roots. A
CALL result maps the callee's proved logical input position to that call's
actual, or collects the callee's Static return roots. At most sixteen rounds
over sixteen sites solve these finite reachability sets. No payload is copied.

One formal can therefore receive different image windows at different CALLs.
The sets are bounds for later validation, not replacement runtime spans or
authority to select arbitrary image bytes. `static_views::inspect` checks an
actual packed word against a possible real root: bytes must remain inside one
root window; text must equal one complete validated text window. Byte roots
cannot manufacture validated text. A latent uncalled formal can have no roots;
ordinary native scalar entry cannot manufacture an incoming Static value.

The new tables are bounded proof metadata. Existing limits remain 16 sites,
16 functions, 128 registers, 256 instructions and 32 runtime frames. No runtime
frame table, instruction price, CLI limit or capability flag changes here.
Public Fuel still defaults to 256 with an explicit CLI ceiling of 16000000;
see the [public Fuel contract](public-fuel-limits.md).

## Verification boundary

Run `python -B tools/verify-static-execution.py --profile development --selection
call-proof`, then repeat with `--profile release`. The selection contains eight
new admission groups, nine existing range groups, fourteen Static execution
groups and seven ordinary scalar-entry groups. It covers valid byte/text,
alias/range/conversion and recursive recipes, canonical argument/register
failures, owned-array leaks, distinct actual windows, exact text windows,
ordinary array/record/loan CALLs and the remaining bare/legacy gates.

Windows development and release each passed all 38 native groups on 136 matching
final native inputs and the same 229-file discovery identity. All 128 production
modules are LF and both locked LF mirrors passed. Public Fuel CLI-only checks
also passed all 33 tool-free cases per profile on 140 matching CLI inputs, with
separate artifact hashes and unchanged limits. No compiler/stack overrides or
historical native result reuse were used. Implementation commit: `1dff6a1`.
The earlier 37/38 development run, superseded release run and diagnostic probes
are excluded; the corrected runtime-loan fixture uses required `f(ref r)` syntax.
The original public Fuel native selection was not rerun.

Final results, committed code and exact input identities are recorded in the
[focused evidence](../evidence/static-call-admission-windows-20261105.json).
These checks do not establish full-profile conformance, general stack/RAM,
allocator/OOM/timing, Linux, restricted Windows or C ABI/package behavior.

## Runtime successor and remaining boundary

Bare verification, legacy retained-Program admission and the fixed-frame Static
executor continue to reject the new CALL profile. PARAM 77 is explicitly rejected
by the legacy step helper. Copyable analysis proof never substitutes for an
owning Program/image or runtime authority.

The [canonical transfer successor](static-call-transfer.md) now executes these
recipes through a separately proved native `CallProgram` retaining the exact
image. It preflights full transfer Fuel/destinations, keeps actual words outside
scalar cells, preserves actual spans/kinds, restores ordinary owner/loan state
and drains failures with prepaid abort. A root-window set cannot broaden an
actual transferred view. The analysis result by itself still grants neither
execution nor lifetime authority.

The [shared byte-formal successor](reference-formals.md) now adds separate
mixed-backing signature/CFG analysis and canonical runtime loan validation.
Its native transfer and returned-reference paths are still pending.
Storage-independent reference execution, source signatures/CALL lowering, ordinary public
admission and host-visible returned-image lifetime APIs remain subsequent work.
The complete accepted inventory remains open.

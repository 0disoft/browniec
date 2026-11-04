# Retained native Program images

Date: 2026-11-05. This connects the owning [literal image](static-literal-image.md)
to an immutable native Program. It is a prerequisite for B04 Static origins and
R01 Program reuse. Static executable definitions, guest literal syntax, Engine
handles and Instance pinning remain open. The complete accepted implementation
objective in [the plan](completion-plan.md) remains active.

## Ownership and admission

`program_image::Program` is a move-only resource with private fields: one copyable
`slice_result_ir::Program` snapshot and one owning `static_image::Image`. Retaining
a Program copies the IR once and moves the image; it does not allocate another
literal payload or keep a reference to compiler scratch. Later changes to the
candidate IR cannot alter the admitted snapshot. Both snapshots survive the
compiler function's scope exit.

`retain` independently verifies all existing IR through `slice_result_verifier`,
inspects the actual immutable image including its UTF-8 contents, and checks its
logical charge against an explicit image ceiling. Success publishes both together.
Failure publishes no Program and consumes/drops the supplied image normally;
the borrowed candidate IR remains untouched. Code and literal errors retain
separate provenance. Only the error field selected by `Error.kind` is meaningful.

The image ceiling covers 576 logical metadata bytes plus exact payload capacity.
It is checked against an already-created owning image. This is not a reservation
before that image's earlier allocation or total Program/Engine accounting: IR,
compiler scratch, native stack, allocator buckets and old-plus-new peaks still
need R02 integration. `static_image::freeze` remains responsible for preflighting
its own allocation. Empty catalogs and empty literals both retain zero payload
capacity, with distinct literal metadata.

The IR remains inline in the native owning resource. At this ownership checkpoint,
combining the multi-resource quota fixture with empty-image VM execution produced
Windows stack-overflow status `-1073741571`; separating the fixture was not a fix.
The [native return-stack successor](native-return-stack.md) now removes the large
intermediate return-transaction snapshots and runs the original combined case.
Persistent Program/frame allocation and general stack containment remain R02 work.

## Reuse and execution

`code` and `literals` return shared references tied to the native Program borrow.
There is no mutable accessor. Existing image operations can read checked byte/text
views through `literals`; numeric spans are still image-local offsets, not
authenticated cross-Program handles. Separate Programs retain separate images
even when both use literal index zero.

`run_scalar` borrows the whole Program while entering the existing canonical
returned-view VM. It preserves the VM's independent admission, explicit native
inputs, exact Fuel, resumed generations, first errors and cleanup. The image is
not copied into the per-invocation owner arena. A native host can reuse the same
Program with separate invocation states, including after a prior guest failure.
The focused checks execute an existing returned-input CALL and terminal cleanup
through this retained owner.

The current executor does not read the image from guest instructions. No Static
opcode or origin claim is added or normalized to a fabricated mutable array.
In particular `run_scalar` returns only the existing scalar completion; it does
not issue a returned Static receipt that could outlive the Program borrow.
Explicit cross-call pinning and Program release/destroy policy belong to the
forthcoming Engine/Instance owner, not these plain offset or proof objects.

## Verification

Run the focused verifier for each profile:

```text
python tools/verify-program-image.py --profile development
python tools/verify-program-image.py --profile release
```

The verifier captures all production sources, selected tests, manifest, lock,
toolchain and itself before execution. It fingerprints the complete test-discovery
tree, checks an LF mirror with `--locked`, requires exact native test identities,
empty captured process streams and no native traps, then rechecks input hashes.
The ownership-checkpoint [Windows evidence](../evidence/retained-program-image-windows-20261105.json)
records 20 development and 20 release native groups (seven new and thirteen
affected regressions), on 126 matching final inputs and a 217-file discovery
digest. All 119 production files are LF and both LF mirror checks passed. All
counted selections followed final capture, without native overrides or historical
result reuse. Earlier construction/fixture probes and pre-snapshot passes are
excluded; native stack/RAM/allocator safety is not established by these checks.

Seven new groups cover compiler-scope escape, candidate mutation, separate images,
exact/one-short/hostile image ceilings, empty catalogs, hostile IR/unknown opcode
claims, repeated scalar execution, exact/one-short Fuel, guest arithmetic failure,
immutable payload capacity and existing returned-input CALL cleanup. Image and
native scalar-entry groups were selected at that checkpoint. The current verifier
selects retained-Program and native scalar-entry groups for the
[return-stack successor](native-return-stack.md); the original combined fixture
now executes in one group. Direct image checks remain separate when its storage
implementation changes.

## Next integration

Add actual immutable literal definitions and Static origin reconstruction tied to
this retained image. Prove literal identity, exact read-only byte/text kind, range,
function and definition before admitting any executable Static site. Route VM
reads, CALL/binding/return/close and failure cleanup to the retained image without
copying it into each Instance. Then connect guest source literals and text APIs,
complete Engine/Instance lifetime/accounting and promote public admission only
after source-to-execution evidence. This owner does not complete B04, R01 or D05.

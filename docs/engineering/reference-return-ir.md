# Shared byte returned-reference recipes

Date: 2026-11-05. This B04/B05 increment follows [canonical byte-formal
execution](reference-vm.md). It adds independent return-recipe analysis, not
complete owner/loan lifetime proof or native generic-result execution.
Implementation: `969456a`.

## Signature and origin reconstruction

`static_call_ir::inspect_reference_returns` is a separate analysis entry point.
It accepts existing private result kind 3 for shared bytes backed by an image or
runtime loan. RETURN 79 must select the function's sole live view, of byte or
universal-byte kind. Text cannot become bytes without the existing explicit
conversion; generic bytes cannot masquerade as an image-only result.
All existing bounded signatures, logical positions, parameter preludes, reserved
bytes, view definitions and CFG merge checks remain. No new opcode is introduced.

Return claims are reconstructed from actual PARAM/CALL/ALIAS/RANGE/RETURN edges.
Function origins remain exact input 1..8 or Static image 9. A caller temporary
receiving a result from its own rooted loan gets symbolic local origin 10. This
is not a selectable function result origin: attempting to return it as an input
or Static origin rejects. Rootless ordinary shared byte inputs map back through
their exact formal ancestry and logical parameter position, including scalar
prefixes. Owned value parameters cannot substitute for a borrowed-result input.

The bounded fixed point propagates transitive calls and checks every RETURN
against the same grounded declaration. Aliases, checked-range recipes and empty
ranges preserve origins. Range recipes do not prove runtime endpoint values.
Image-root propagation branches on actual encoding before subtracting 192;
a runtime actual contributes no image root. An empty image-root set conveys
neither an empty runtime window nor owner authority.

The existing Program/Proof/Sites layouts and prices remain unchanged. Origin
reconstruction performs at most sixteen rounds over at most 256 instructions;
each ordinary rootless origin lookup scans at most eight logical formals after
bounded shape validation. These are static-analysis bounds, not a runtime Fuel
schedule, memory benchmark or complete hostile-source budget.

## Authority boundary and next implementation

A recipe proof is copyable metadata. It does not prove ordinary scalar/loan
liveness or continued owner availability across returned-view lifetimes.
`inspect_references`, complete `inspect_reference_calls`, retained
ReferenceProgram/CallProgram and ordinary public admission still reject result
kind 3. Existing shared-byte formal VM execution remains supported. This separate
entry point does not enable source result syntax or host-visible references.

Next combine these recipes with canonical owner/loan lifetime analysis, including
writes/drops while a returned runtime reference remains live. Then connect native
handoff, caller publication, last-alias close, selected owner/parent retention and
prepaid abort. Image results must keep their retained Program borrow; runtime
results must keep full-generation native receipts. Source signatures/actuals/
returns and ordinary public admission follow. The full [inventory](../product/04-remaining-work.md)
and [completion plan](completion-plan.md) remain active.

## Verification

Run `python -B tools/verify-static-execution.py --profile development --selection
reference-return-ir` and repeat for release. Eight new groups cover actual image
and runtime encodings, caller-local versus declared input origins, alias/range/
empty/forwarded returns, all eight actuals and scalar prefixes, rootless shared
input mapping, wrong result kind/origin and all existing admission gates.
Eight existing formal-analysis groups and two actual Static VM regressions cover
the changed shared recipe and image-window paths.

Windows development and release each passed 18 native groups on 139 matching
committed inputs. All 132 production modules are LF, both locked LF mirrors pass,
and discovery covers 237 files. See [focused evidence](../evidence/reference-return-ir-windows-20261105.json).
Final native runs used no compiler/stack overrides or historical-result reuse.
Earlier fixture semantic rejections and a semantic-interpreter probe unsupported
by native UTF-8 primitives are excluded. Public CLI/Fuel selections, full
profiles, general stack/RAM, allocator/OOM/timing, Linux, restricted delivery and
ABI/package checks were not rerun. The next canonical lifetime and native
handoff requirements are not established by these recipe-only tests.

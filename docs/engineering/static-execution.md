# Retained-image Static execution

Date: 2026-11-05. This B04/D05 increment executes independently proved Static
instructions in the existing canonical returned-view coordinator. It follows the
[Static IR proof](static-ir.md); guest text syntax and returned Static views are
still separate work.

## Exact-image admission

`program_image::retain` now uses `slice_result_verifier::inspect_image`. Shared
preparation normalizes only the existing returned-loan recipes. Image-aware
ordinary verification reconstructs Static definitions from the actual immutable
image, complete scalar definitions/types, CFG owner/loan states, executable CALL
shapes and independent Static liveness. Existing return-origin grounding,
CALL-binding identities, capture masks and terminal pairing then run over that
same normalized candidate. The original IR is what the Program retains/executes.

The exact image remains an owned private field of the Program. Each scalar run
independently proves its code/image again and borrows the owning Program for the
whole invocation. `static_image::payload` exposes only a shared read-only view;
proof derives each absolute payload start from a checked image-local span. No
literal bytes are copied into the invocation's array arena. Image-only programs
can execute with zero guest backing. Program image charge still covers image
metadata/capacity only, not complete Program/Engine/process accounting.

The ordinary bare verifier/VM entry points carry no image authority and continue
rejecting 69-75. Image-aware admission is an explicit native API path, not a guest
numeric flag or a public CLI/capability promotion. A copyable Sites value alone
cannot select the admitted payload at the invocation boundary.

CALL_BIND's scalar normalization identity never contains a runtime value.
Static READ's index operand is now included in its prohibited-use scan, alongside
the existing scalar readers. The regression separately demonstrates that the
normalized scalar proof accepts the index while full recipe proof rejects it.

## Shared VM and lifetime

Image-aware entry reuses existing argument admission, owner transfer, frame
push/pop, ordinary scalar/array/record CALLs, returned-loan handoff and first-error
abort. There is no second scalar interpreter. Driver dispatch routes 69-75 to
`static_execution::step` with the exact payload and independently rebuilt sites.

A separate 32-word local table tracks Static live sites per call frame. Its
logical elements total 256 bytes on the current 64-bit targets, excluding native
compiler temporaries. Existing array/record/slice namespaces, all frame capacities
and canonical receipt/ticket generations retain their meanings. Callee entry
clears its word; normal and borrowed returns require it empty. Static CLOSE is
actually executed after loan-result preparation rather than being confused with
prepaid native loan finalizers.

BYTES makes an independent shared byte view of the same immutable backing.
Closing its text source preserves that byte view. All views remain internal to
the running invocation; no Static pointer or receipt escapes a scalar result.
Failure discards the local alias words and uses existing zero-Fuel native abort
for real owners/loans. The retained image remains intact for subsequent runs.
This is not Engine handle pinning or an external returned-Static lifetime API.
The [alias successor](static-alias.md) now copies same-kind immutable descriptors
through opcode 75, preserving exact spans and independent lifetimes.

Initial development probes reproduced Windows stack overflow in both an existing
CALL-binding test and the new retained-image integration. Verifier/driver field
reads now borrow the nested ordinary IR once. Runtime entry/handoff/close/abort
stage individual borrowed authority/pool/owner fields and publish them only after
all fallible work. Array/record/loan adapters likewise avoid intermediate Runtime
copies. Return-map validation runs in a separate private helper, releasing its
large compatibility plans before loan restoration begins. Transaction rollback,
cleanup order, public APIs, guest capacities and existing prices are preserved.

After those runtime reductions, native tracing reached the source-compilation
part of the same integration fixture and exposed another large result temporary.
Internal lowering now fills wrapper-owned scratch by reference and returns only
a scalar count. Both public source compilation and private origin-analysis APIs
continue returning owned snapshots on success and errors without publishing
partial IR. The wrapper's scratch never escapes on failure. Core/function source
regressions are included for this shared compiler path.

The existing failing CALL fixture and the new combined integration retain their
single-function test bodies; tests were not split to obtain a pass. Generated-C
instrumentation is diagnostic only and excluded from final results. Focused
native passes do not prove a general stack bound, total RAM, allocation counts or
a frame-size/timing benchmark.

## Private prices

The driver pays one dispatch unit. All extra charges below are preflighted before
payload reads or register/live-state publication. Definition and span guards
only inspect bounded metadata. READ's actual index bounds run after its complete
price preflight, preserving Fuel as first cause when both fail.

| Operation | Total including dispatch |
| --- | ---: |
| OPEN, BYTES, ALIAS, LEN | 17 |
| CLOSE | 1 |
| READ | 18 |
| EQUAL | 17 + selected left byte length + selected right byte length |

Span lengths are at most 4096; equality charges both entire selected lengths
even on early inequality. These are abstract bounded metadata/payload units,
not timings or a constant-time equality promise. Existing instruction prices,
entry/leave/handoff reserves, default Fuel and CLI cap are unchanged. General
work-budgeted step/cancellation/deadline recipes remain open under R03-R05.

## Verification and remaining work

`python -B tools/verify-static-execution.py --profile development` and `--profile
release` capture pinned compiler/input/discovery identities, check locked LF
mirrors, and run the changed execution/proof and affected retained-Program,
scalar-entry, returned-CALL and core/function source suites. Public Fuel CLI
regressions are run separately with `tools/verify-public-fuel.py --phase cli` for
both profiles, including tool-free execution and the CLI artifact identities.
Windows development and release each passed 59 native groups (eight new Static
execution groups, affected proof/retention/returned-CALL groups, and twelve
core/function regressions) on 133 matching final inputs and the same 219-file
test-discovery identity. All 121 production files are LF and both locked LF
mirrors passed. Public Fuel CLI regressions passed 33 cases per profile with
separate hashed artifacts and an empty runtime tool PATH.

The [Windows evidence](../evidence/static-execution-windows-20261105.json) records
exact selections, compiler/input/report/artifact hashes and outcomes. Counted
runs follow final input capture with no native overrides or historical reuse.
Earlier checker/native probes and generated-C diagnostics, including a diagnostic
16 MiB stack run, are excluded from verification. Full profiles, Linux,
restricted delivery, C ABI/packaging, allocator/OOM, general stack/RAM and timing
checks were not run. The focused passes do not establish those guarantees.

Next lower real byte/text literals, `ref str`, `text::bytes` and `text::equal`
through this image-aware path. Connect Static CALL actuals and returned views to
real Program lifetime/origin receipts before permitting their escape. General
references, ordinary public returned-result admission, Engine/Instance lifecycle,
input/output, Buffer, host exchange, Windows restrictions and the C ABI remain
open in the complete inventory.

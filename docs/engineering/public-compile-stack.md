# Public retained compilation stack containment

## Reproducer and scope

On baseline `8f63c74`, the unchanged
`array_expression_projections::combined_group_index_and_32_deep_captured_call_bounds_stay_original`
native development group fails with Windows stack-overflow status
`-1073741571` (`0xC00000FD`) using the pinned preview.2 compiler and default
stack. A diagnostic-only standalone image localizes the failure to the retained,
leading-grouped-array depth-32 case. The preceding grouped-index and ordinary
CALL cases complete. The diagnostic is supplemental; final acceptance retains
the original combined group without splitting its cases or changing its helpers.

The production `compiler::compile_program` native API is the affected entry.
The CLI uses thinner, separate entry functions. Before this change, its eight
original grouped CALL cases already execute depth 32 to 42 or reject depth 33
with `compile_limit` in development, across both argument positions and source routes. Twelve
additional combined control/CALL inputs also check or reject normally.
These observations do not establish general stack containment.

## Cause and repair

`compile_public_references` originally unpacked `compile_reference_returns`
and constructed `Result<PublicProgram, Error>` in one frame. The generated C
reserves large resource/result temporaries at function entry, even though public
packaging occurs only after recursive source lowering has finished. MSVC
development assembly reserves 172,904 bytes in this waiting adapter.

The adapter now passes the completed owning candidate to a private
`publish_public_references` function. Recursive compilation returns before
public packaging temporaries become live. The helper consumes exactly that
candidate and uses the original success constructor and error translation.
The public signatures, source selection, image ownership, admission order,
diagnostics, Fuel, limits and cleanup remain unchanged. No heap allocation,
cross-call cache, native shim or compiler/stack override is added.

The generated-C/MSVC inspection uses `/std:c11 /TC /MT /Od /c /FAs` with the
same installed compiler and SDK for both snapshots. It measures individual
prologue reservations, not whole-process peak stack or elapsed latency. The
inspection object is never substituted for an acceptance executable.

| Waiting adapter | Before, bytes | After, bytes | Decrease |
| --- | ---: | ---: | ---: |
| `compiler::compile_public_references` | 172,904 | 66,584 | 106,320 (61.49%) |

Both prologues retain the same two saved-register pushes, which are excluded
from these reservation counts. Public packaging still has its own frame after
recursive compilation returns; no whole-invocation peak reduction is claimed.

## Verification boundaries

`tools/verify-public-compile-stack.py` selects the original combined array and
record depth fixtures, public
admission profiles, lifetime rejection and a focused exact-image-quota
admission group. The verifier copies the transitive import closure of the
unchanged production `main` and four selected test modules: 279 of 367 production
modules. Every included source/test byte must match the repository. It refreshes
only the isolated closure's lock, retains the full repository lock, and records
both identities. Both profiles then use byte-identical locked mirrors. Profiles
run serially with unchanged compiler, optimization, stack and timeout settings:

```text
python -B tools/verify-public-compile-stack.py --profile development
python -B tools/verify-public-compile-stack.py --profile release
```

Development passes all five groups, both with all production modules and with
the import closure. The closure checks 287 source files and 2,997 MIR functions;
all 289 recorded input hashes still match. Release compilation of the closure
also exceeds the unchanged one-minute MSVC host timeout before any group runs.
It is incomplete, not a pass. No further identical timeout retry is counted as
validation. The [recorded evidence](../evidence/public-compile-stack-windows-20261118.json)
separates development acceptance from unsuccessful release attempts.

The original `public_program::image_quota_is_exact_and_independent_of_the_public_backing_limit`
combined admission/execution fixture separately overflows in development on the unmodified
baseline and the first adapter patch. It is unchanged and remains an open
failure. The new quota group checks only the affected admission boundary: one
literal requires 577 image units and an empty literal requires 576; each rejects
one fewer unit. It does not claim to repair or replace that execution fixture.

The subsequent [combined-stack follow-up](native-stack-regressions.md#public-image-quota)
repairs and executes that unchanged quota/runtime fixture. It also removes the
extra private owning-result frame from the public lowering path. The earlier
adapter frame measurement above is historical, not a measurement of that later
implementation.

The original `public_program::source_routing_keeps_legacy_profiles_and_admits_the_extended_path`
combined admission/execution fixture also overflows independently in development on baseline
`8f63c74` and with this patch. It remains unchanged and open. A separate
admission-only group verifies scalar, array, literal and returned-reference
profile selection without retaining unrelated programs or entering those
execution frames. Neither pre-existing combined execution failure is counted
as a passing group or a repaired failure in this slice.

The private
`value_signature_depth::four_wrapper_local_annotations_with_32_controls_execute_and_33_reject`
fixture also overflows in development with preview.2 in the current checkout and
on baseline `8f63c74`. The historical
2026-11-12 pass does not establish a current pass. Its direct `value_source`
entry does not use this public compilation adapter, and this failure remains
open rather than being counted toward this slice's five passing groups.

Full-source release verification hit the existing one-minute MSVC host timeout
both during concurrent diagnostics and in a later serial run. Neither is a pass.
The full-source development selection passed all five final groups. The
dependency closure excludes unrelated kernels while preserving the complete
original fixtures, but still times out in release; it does not extend a timeout. Full Engine,
all-source-depth composition, Linux, release packaging and remote delivery are
outside this slice.

# Binding an explicit project to native source snapshots

Date: 2026-11-05. This advances L01/C01 after [metadata admission](../cli/project-format.md).
The project_sources select function borrows an immutable Project and consumes a
sealed source Snapshot. It opens no files and grants no capability.

Every decoded project member path must equal exactly one snapshot identity.
Snapshot order is immaterial; a private 16-slot map records its corresponding
project row. Missing/extra files, unknown identities and case-changed spellings
fail. Snapshot identities are opaque host labels, so case folding is used only
to reject collisions while parsing the manifest, never to guess another identity.
The sealed Snapshot already proves identity uniqueness; equal counts plus exact
matching prove complete coverage of the source map.

The existing module index scans all retained original bytes and proves complete
module/import/declaration binding. Each canonical header must then match the
module named by that exact source-map row. Source/header swaps fail even if the
set of module names is otherwise correct. Canonical header comments/whitespace
remain valid. Visibility, alias targets, duplicate/reserved declarations and
lexical errors retain the index's existing checks.

Only after all files and headers agree does selection accept the explicitly
named public zero-argument i32 entry. The returned owning Entry uses the exact
Index/Snapshot and composes with module_program complete executable admission.
Selection itself does not validate every body, grant declared requirements or
establish filesystem origin. The caller retains its Project and must enforce
its authority before any project execution. A native project Program successor
will retain that metadata with the admitted code.

## Errors and bounds

Selection preserves the existing module diagnostic directly: Limit for compiler
file capacity, Missing for file-count/identity mismatches, Kind for a wrong bound
header, and the original lexical/import/visibility/signature kinds. Each carries
the original snapshot source index and half-open byte span. Header mismatches
point to the actual header path. Global count/capacity failures use an explicit
no-source span; unknown identities identify the actual unmatched snapshot file.
Snapshot indices are not project-row indices when the host reorders inputs.
No synthetic metadata position is substituted for an original source location.

Native Entry error adaptation previously amplified owning return slots enough
to overflow the default Windows stack in the combined 16/17-file case. Selection
now returns the existing Entry/module-error result directly. Entry signature
proof uses a small private Checked result before the final owning constructor.
It authenticates the same Index immediately before publication; no mutable or
caller-supplied proof is accepted. This changes no capacity or stack setting.

The accepted metadata format still admits 32 source mappings. This native
compiler/snapshot increment accepts at most 16 files and 4096 aggregate source
bytes. A larger valid metadata map fails with Limit before selection, without
truncation. Matching needs at most 16*16 exact path comparisons of up to 240
bytes and 16 canonical header comparisons of up to 128; no graph walk or
filesystem probe is added. Input/entry/body limits and public Fuel prices stay.

## Verification

Run tools/verify-static-execution.py with --profile development and --selection
project-sources, then repeat with --profile release. The selection includes new
source-map binding cases and existing metadata, entry and immutable-snapshot
regressions. It checks the locked LF production mirror and exact input/compiler/
discovery identities.

This is explicit native host-snapshot evidence. Anchored filesystem collection,
race containment, project CLI/policy/catalog/run loaders, host authority and
full-profile capacities remain separate remaining work.

Windows development and release each passed 26 native groups (seven new binding,
seven metadata, six entry and six snapshot) on 156 matching verification inputs.
Both locked LF mirrors pass. The unchanged combined 16/17-file case passes
without compiler/linker stack overrides. See the [focused evidence](../evidence/project-sources-windows-20261105.json).
Diagnostic-only probes and the run invalidated by a test identity edit are excluded.

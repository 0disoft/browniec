# Advisory source origins for result binding lowering

Date: 2026-11-04. This is a lowering prerequisite for B04, not admission proof.
The source compiler does not yet invoke this pass or admit a result binding.

`slice_result_source_origins::infer` fills the signature table's new
`return_slice_inputs` column. Each nonzero entry names one input position, 1..8.
It rescans reference-returning function bodies with lexical reference-name scopes,
same-type/access aliases and the current callee hints. Arguments are skipped with
balanced parentheses/brackets/braces, while the outer token walk still observes
returns inside argument value blocks. It handles reordered inputs, reference
aliases and inline ranges without guessing the first matching formal.

A known return branch can ground recursion. Every later pass checks all returns
again, so a newly resolved conflicting path rejects. Ungrounded cycles and
non-input-backed or differently typed returned references reject. Existing hints
are cleared before inference, preventing a cached selector from seeding a cycle.
There are at most seventeen passes across sixteen functions. Names are bounded
by the existing 64-local limit. This is compile-time work, not runtime Fuel.

These are advisory source facts only. Syntax/type/Flow checking and independent
IR proof remain authoritative. In particular, the eventual IR verifier must trace
CALL-defined bindings through callee summaries and alias definitions, rather than
accepting flattened site provenance as evidence that a recursive cycle grounds.

Windows development passed three semantic-interpreter and three native groups.
The final runs include cache-reset rejection; exploratory earlier results are
excluded. All 119 captured compilation inputs match (115 production modules,
the selected test and three manifest/lock/toolchain files). See
[retained evidence](../evidence/m2-slice-source-origins-windows-20261104.json).
Release, standalone CLI regressions, other M1/M2, Linux, isolation, ABI and
performance were not run for this prerequisite. No public capability changes.

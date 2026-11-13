# Assignment destination context preparation

The 2026-11-13 checkpoint bounds private ordinary source-place preparation for
all five destination kinds: array element, exclusive slice element, scalar
record leaf, whole array and nominal record subtree. The compiler still drains
these continuations synchronously before it evaluates the RHS. Final IR proof
continues to establish every destination's identity, type, lifetime and phase.

## Metadata children

`destination_record_work` reuses the existing layout, record metadata and nominal
copy/range cursors. Scalar field destinations preserve the original operand-first
checks, whole-catalog flattening and kind-3 errors at the source offset. Their
internal record representation still supports 128 scalar leaves.

Aggregate record destinations preserve kind-5 errors at the selected offset and
the original layout-only proof: they do not acquire extra validation of unused
binding rows. Owner/function/mutability checks precede full layout planning;
exact nominal destination and source ranges are then walked independently.
The copy/range child performs at most sixteen visits per fresh allowance. A fixed
copy of its small State avoids nested borrow conflicts in the pinned compiler;
the reviewed transport measures 656 bytes per child copy, 1312 bytes for the
read/write pair within the 4096 allowance. No whole plan is cloned.

Scalar SELECT, old-value READ for compound assignments and STORE share the bounded
shape adapter. The original SELECT/READ/STORE builders and scalar shape routine
remain independent raw comparison oracles. Other general metadata builders,
verifier/runtime catalog consumers and aggregate STORE proofs retain their own
protocols; this checkpoint does not globally replace every metadata preparation.

## Selection and publication

`destination_place_work` first validates the pending mask, then examines one of
the sixteen place bits per stage. It selects the lowest free ID. Exhausted or
forged masks fail before metadata preparation or SELECT emission.

Scalar and aggregate record kinds issue an explicit metadata request. Pending
parent advances neither charge nor mutate; resume consumes that request once.
The owning adapter drains the bounded child with its own allowance. It does not
count a full catalog scan as one parent transition. Other kinds use their fixed
builders; exclusive-slice formal authentication examines at most eight formals.

A separate stage emits one SELECT transaction. Another stage publishes the
pending bit and completed result. Thus a failed SELECT cannot publish a pending
place, and RHS evaluation starts only after complete destination construction.
Budget denial and terminal advances preserve IR, names and cursor state. The
original partial code bytes and source diagnostics are retained.

## Verification and limits

The [destination evidence](../evidence/compiler-destination-context-windows-20261113.json)
connects focused snapshots and final owning Engine development/O2 execution to
committed input hashes. Tests compare raw errors, IR bytes and pending masks for
all five kinds, including full/high masks, bad operands, invalid metadata and
IR exhaustion. Direct protocols cover child waiting, duplicate resume, delayed
publication, terminal guards and nominal walks beyond sixteen visits. Scalar
READ/STORE cases check partial IR and register/type changes. Ordinary source
fixtures exercise mixed array/slice/record assignments and returned records with
verifier/VM result 42; the default-stack CALL depth 32/33 regression is retained.

The initial combined six-group development selection passed; its O2 image hit
the pinned compiler's default 60-second MSVC host-build limit. Metadata checks
were isolated and rerun in both profiles. Final ordinary source regressions and
owning Engine integration are recorded separately. No compiler, stack, timeout
or optimization override was used, and the incomplete combined O2 attempt is
not counted as a pass.

Both new States are inline. SDK heap classes, Bank/Pratt fields, scratch slot
caps and the 66,630,144-byte lowering reservation remain unchanged. Fixed setup
and synchronous owning drains remain atomic. This does not establish a public
Pending compiler, measured CPU/time/physical-heap/stack improvement or R02-R05
closure. Full transitive evaluation, typed/value source walks, declaration
headers, catalogs/origins, entry/final metadata and unrelated implicit cleanup
remain outside these named destination bounds. The standalone 28-group memory,
broad public-CLI and full-release gates were not rerun. Broader completion remains
paused; no push, release, deployment or version change.

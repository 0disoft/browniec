# Stable loop snapshot compaction

The private typed/value compiler's `value_source_loops::release` releases
branch-local snapshots while retaining snapshots referenced by escaping loop
transfers. This is a compiler metadata path, not public CLI execution support.

Previously every suffix snapshot scanned all 256 transfer rows to decide
retention, and every retained snapshot scanned them again to rewrite indices.
For suffix size S and retained size R, transfer-row visits were
256*(S+R), plus S compaction iterations. With the admitted 128-row pool and all
rows retained this is 65,536 transfer-row visits.

The replacement first marks referenced suffix indices in a 128-word relocation
map, compacts snapshots in original order while recording new encoded indices,
then rewrites transfer rows once. Nonempty retained suffixes require 512
transfer-row visits, plus S compaction iterations: O(S+P) instead of O(S*P),
where P=256. The worst-case transfer-row count falls by 128x; this is a structural
bound, not a measured wall-clock speedup. The local map contains 1024 logical
bytes on the pinned 64-bit target. There is no added heap allocation or persistent
ledger field; generated compiler temporaries are not included in that number.

Empty suffixes return immediately. Single-row suffixes use the original path.
Suffixes without a retained reference truncate after one transfer scan.
Manually supplied pools over 128 rows keep the original general Vec behavior;
normal snapshot admission remains capped at 128 by `value_source_control::save`.
Invalid marks still fail before mutation. Prefix snapshots, owner-zero/stale
transfer entries, duplicate references, ancestor owners, flags and frame metadata
retain their original values and stable ordering.

`tools/verify-value-loop-compaction.py` selects six native groups: a comparison
against the unchanged original algorithm for all 256 small retention masks,
maximum/prefix/stale/duplicate/oversized/invalid-mark cases, three existing
source loop groups and the existing default-stack conditional 32/33 group.
Comparisons cover every snapshot State field, all 256 transfer rows and all 32
loop Frame rows. Source fixtures verify and execute real loops and cleanup.
Run development and release profiles individually with the pinned toolchain;
receipts are written to `build/value-loop-compaction/<profile>/receipt.json`.

The source module is outside the owning Engine closure. The unchanged complete
Engine closure/input hashes retain prior evidence. No new physical memory peak,
CPU/time improvement, public Pending compiler or R02-R05 completion is claimed.

Development and O2: six native groups each passed. Exact input hashes and
structural-count calculations are recorded in the [evidence](../evidence/compiler-loop-compaction-windows-20261114.json).

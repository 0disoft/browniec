# Native returned-byte receipt bindings

Date: 2026-11-05. This increment follows the [complete returned-byte
analysis](reference-return-lifetimes.md) and prepares canonical generic-result VM
integration. Implementation: `ec27142`. Native helper execution is verified;
generic CALL/RETURN dispatch and retained return-Program admission remain next.

## Compact selectors and disjoint receipt identities

`reference_words` keeps its existing u32 frame word. Image words retain their
low 26-bit span. Formal runtime words keep the prior tag and three logical
argument bits. Returned runtime words use the returned tag and four receipt-site
bits; their decoded selector is 16..31, separate from formal selectors 0..7.
The other formal tag range remains reserved. All byte spans remain checked within
4096, including empty/end spans. Word layout and the 32 x 16 u32 table remain
2048 logical bytes. The decoded Word struct gains no fields.

The full native ticket stays in the existing sparse 47-slot Held table. Ordinary
slice locations remain 0..511, absent remains 512, and returned universal sites
use 1024 + frame*16 + site (1024..1535). No dense ticket table, runtime frame
field or extra physical pool reservation is added. Frame membership and terminal
consumption decode both namespaces. Ticket duplication is rejected across both;
an ordinary and universal site with the same number cannot select each other's
receipt. Returned-byte receipts must be shared u8 and belong to the exact frame.

## Publication, access and last-alias close

`reference_receipts::publish` checks destination liveness, span and sparse-store
constraints before publishing its plain word/live bit. A failed or duplicate
publication preserves existing words and receipts. `source` resolves the exact
returned receipt and relative window; the existing access interface independently
authenticates its full native generation, root and lease before payload access.
Words and helpers remain invocation-private metadata: the eventual VM must also
validate the exact active frame, proved site and logical liveness. A copied raw
word alone is not a host handle or authority.

Aliases and ranges can share one receipt selector without acquiring another
physical read session. `close` scans the current frame's live aliases. An
intermediate close clears only its word/live bit; the last close consumes the
native Held receipt and its selected owner-drop obligation. Native failure leaves
the word, sparse receipt and runtime metadata live and unchanged. Terminal
metadata retirement is allowed only after successful native handoff/abort has
already consumed that frame's receipts; it never substitutes for ordinary close.

The helper prepays 128 metadata units: up to two 47-entry receipt lookups plus a
16-word alias scan, rounded up. One-short fails before native authentication;
exact succeeds with zero remaining. Physical finalization was prepaid by the
native handoff that issued Held. This helper price excludes eventual VM dispatch.
Unpaid selector/publication helpers still require complete VM caller preflight;
this increment does not claim a complete generic CALL/RETURN/access schedule.
Existing operation prices, public default 256 and ceiling 16000000 remain.

## Verification

Run `python -B tools/verify-static-execution.py --profile development --selection
reference-receipts` and repeat for release. Eight new groups exercise all sixteen
returned selectors and extreme/empty spans, actual native returned-byte window
reads, last-alias close and exact/one-short metadata Fuel, namespace collisions,
failed final owner-drop rollback, stale-ticket rejection, publication rollback
and retirement after native cleanup. Four word/window groups, four sparse-binding
groups (including seventeen nested writer receipts sharing one slot), and two
real shared-byte formal VM groups cover affected legacy behavior.

Windows development/release each passed 18 native groups on 142 matching committed
inputs, 134 LF production modules and 239-file discovery. Both locked LF mirrors
pass. Final runs use no compiler/stack overrides or historical-result reuse;
earlier rejected fixtures (reserved helper name and nested-field loans) are
excluded. See [focused evidence](../evidence/reference-receipts-windows-20261105.json).
Public CLI/Fuel selections, full profiles, general stack/RAM, allocator/OOM/timing,
Linux, restricted delivery and ABI/package were not rerun.

## Next integration

The [native result VM successor](reference-return-vm.md) now connects these
receipts and complete proof to retained private admission and canonical
CALL/RETURN dispatch. Selector/access and complete native return costs are
prepaid; exact windows, post-success publication and consumed-frame retirement
are connected. The [source CALL successor](reference-call-source.md) now lowers shared byte
formals and mixed-backing actuals. Source returns/result bindings and ordinary
public admission follow. The complete
[inventory](../product/04-remaining-work.md) and [plan](completion-plan.md) stay open.

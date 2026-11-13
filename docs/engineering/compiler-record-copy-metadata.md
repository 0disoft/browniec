# Record and copy source metadata

The 2026-11-13 checkpoint stages the metadata used by record projection,
constructor traversal and source-level copying. It extends the earlier
[source continuations](compiler-source-stages.md); the compiler still drains
these private continuations synchronously.

## Source discovery and leaf order

`record_leaf_source_work` performs one original depth-first visit per admission,
including pop and failure visits. It preserves the source staging limits of
16 scalar leaves, depth 16 and 4096 visits. This is separate from the internal
128-leaf record representation.

`record_field_source_work` locates the declaration through `record_location_work`
and reconstructs its lexer through `source_state_work`. Neither whole-source
location nor scoped context authentication is hidden in one field stage. Field
rows, token work and spelling comparisons of at most 64 bytes advance separately.

`record_path_source_work` stages preceding sibling counts, nested leaf walks,
selected field hops and scalar-tail lookahead. `path` retains its original
ordinal accumulation; `project` retains its distinct 127 ordinal check and
member-offset diagnostics. A double dot after a scalar leaves the main cursor
at its first dot; errors in that lookahead do not publish the lookahead cursor.

Nominal `named` discovery uses the existing location cursor. Declaration size
checks drain `struct_layout_work`, preserving the original diagnostic mapping
and 128-byte source-owner cap. Raw source loops remain independent oracles.

## Constructor metadata and copy reads

`record_initializer_source_work` updates the caller-owned initializer and lexer
at the original commit points. Child entry, closing token work, parent field
increment, member resolution and shorthand selection advance separately. Its
advance-only mode preserves mutations before failed comma/token consumption.
The raw constructor, next-leaf and advance routines remain comparison oracles.

`record_read_source_work` reuses `output_record_metadata_work`, including its
bounded `struct_layout_work` authentication and flattening. It authenticates the
entire catalog before checking the selected owner and leaf, matching the raw
`struct_meta::prepare` order. Metadata failure remains kind 5 at offset 0 even
when the requested owner is also invalid. Operand checks, SREAD emission and
final tag assignment follow in separate stages. A prepared result is unavailable
until completion.

The parent `aggregate_copy_source_work` emits explicit metadata requests for
source leaf counts (1) and authenticated reads (2). Its owning adapter drains
the matching bounded child and resumes with the scalar result. While a request
is pending, parent advances neither charge nor mutate; a repeated resume fails.
Thus a full read/catalog scan is not counted as a single parent copy transition.
This bounds preparation underneath copy/materialization/staging reads as well
as ordinary `ir::record_read` calls. Each read still revalidates
its pinned catalog; this checkpoint does not introduce a cross-read cache.
Other runtime/verifier callers of `struct_meta::prepare` retain their protocols.

## Accounting and verification

The five new work states use inline scratch and the existing logical allowance
of 4096. Existing Bank/Pratt fields, SDK heap classes, scratch slot caps and the
66,630,144-byte lowering reservation are unchanged. Transport review preserves
36 declarations, 51 reviewed layouts and 523 retained recursive definitions.
The obsolete emitted `struct_source::Location` disappears from the owning Engine;
it remains in source for raw oracles. Five new private State definitions change
the emitted total from 524 to 528, with 116 arrays unchanged. Fixed setup and synchronous
owning drains remain outside transition accounting. No public Pending compiler,
R02-R05 closure or measured CPU/time/physical-heap/stack improvement is claimed.

The [record/copy evidence](../evidence/compiler-record-copy-metadata-windows-20261113.json)
connects focused development/O2 receipts to their implementation commits and
records final owning Engine integration. Source comparisons cover depth/leaf
limits, cycles, nominal/scoped lookup, declaration validation and field/path
results. Final copy/initializer checks cover raw IR and error prefixes,
128-leaf reads, scoped 200-byte field names, path depth 16/17, double-dot and
lookahead errors, partial initializer mutations, budget denial, publication and
terminal guards, plus existing copy and CALL depth 32/33 regressions.

Complete transitive record/group/static evaluation, general destination-context
preparation, typed/value walkers, catalogs/origins, entry/final metadata and
unrelated implicit cleanup remain outside these named bounds. The standalone
28-group memory gate, broad default/public CLI and full release gates were not
rerun; final owning Engine retains its allocator, compilation and retention
fixtures. Broader completion stays paused. No remote delivery or version change.

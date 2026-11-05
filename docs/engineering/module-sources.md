# Immutable source snapshots for module compilation

Date: 2026-11-05. This is the first L01/C03 prerequisite: an explicit native host
snapshot owns source identities and original bytes. Module/import resolution,
visibility, multi-module execution, project loading and CLI flags remain open.

## Ownership and admission

`source_snapshot::Builder` is copyable, caller-mutable scratch. `add` authenticates
its packed ranges before any subtraction or index, validates the candidate's name
and source UTF-8, checks duplicate identities and both remaining capacities, then
copies bytes and publishes metadata. Every rejection precedes all writes.

`freeze` independently rechecks all metadata, UTF-8, identities and duplicates.
It copies the complete value into a private-field, move-only `Snapshot`. Shared
name/source views borrow that exact owner. Mutating or dropping either the input
buffers or the original builder cannot change admitted bytes or metadata. No
mutable getter, partial resource move, heap allocation, file access or capability
exists in this API.

Names are opaque, case-sensitive host identities, not filesystem paths. They must
be nonempty valid UTF-8 without ASCII controls or DEL. Path canonicalization,
Windows case/device/ADS rules, anchored roots and reparse checks belong to C01's
future explicit collector. This API does not certify a name as a safe path or a
source body as valid Brownie syntax. The compiler remains responsible for lexical
and semantic validation, including raw NUL/CR/BOM rules.

## Bounded storage and locations

The native precursor accepts at most 16 sources, 4096 total source bytes and
4096 total identity bytes, with at most 256 bytes per identity. Callers may narrow
both byte limits, including to zero. Empty source bodies are preserved. These are
explicit experimental bounds; they do not adopt the full profile's larger limits
or change the single-source CLI's capacities.

Every source has a stable insertion index within its exact snapshot. `Span`
contains that source index and original half-open byte offsets. `whole`, `view`,
`subspan` and `position` check source/range bounds before arithmetic or access.
A child cannot escape its supplied parent. `no_source` uses index 16 and never
passes source lookup. IDs/spans are snapshot-local metadata, not authenticated
Engine or ABI handles, and must be used with their owning snapshot.

Positions use one-based lines and byte columns. They count original UTF-8 bytes,
including an initial BOM and encoded continuation bytes. LF completes a line
break, so CR in CRLF belongs to the preceding line until LF. EOF and empty spans
are valid. Lookup scans at most 4096 original bytes and never opens a file for a
snippet. Diagnostic message escaping/rendering and persistent line maps remain
C03 work.

`add` scans 16 metadata rows and compares at most 15 existing 256-byte identities,
then validates/copies only the new source/name bytes. `freeze` scans at most 4096
source and 4096 identity bytes plus 120 identity pairs of at most 256 bytes.
`initialized_bytes` counts only initialized source/name prefixes; it is not the
fixed native storage size, Engine accounting or a process memory measurement.

## Verification and next integration

```text
python -B tools/verify-static-execution.py --profile development --selection source-snapshot
python -B tools/verify-static-execution.py --profile release --selection source-snapshot
```

Six native groups cover source/builder mutation isolation; append rollback and
stable IDs; exact source/name/file capacities; independently rejected hostile
metadata, duplicate/control identities and bad UTF-8; forged/overflowing spans
and parent boundaries; and original BOM/UTF-8/CRLF/EOF byte locations. Final input
and report identities are recorded in the
[Windows evidence](../evidence/source-snapshot-windows-20261105.json).
Implementation `f7a67b5`: both Windows profiles passed all six groups on 144
matching committed inputs, 139 LF production modules and the same 244-file test
discovery identity. Both locked LF mirror checks passed. No compiler/stack overrides
or historical-result reuse were used. CLI/full-profile/native VM, Linux, allocator/
RAM/stack/timing, restricted and ABI/package checks were not rerun.

The [module-index successor](module-index.md) now binds canonical module headers,
explicit aliases, declarations and public/private lookup while owning this exact
snapshot. Next connect qualified value/type lowering, source mappings and full
entry signature proof to compilation and public project entry selection. A successful snapshot does not prove a linked or executable module.

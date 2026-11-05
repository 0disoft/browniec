# Explicit project metadata

Date: 2026-11-05. Accepted native metadata format: brownie.project/0.3.
This locally adopts the reviewed project source-map shape from the reference
design, with the checks below. It adopts no other external schema or command.
The [schema](../../schemas/project.schema.json) supports editors; native
project_manifest admission is authoritative for the extra semantic checks.

## Required fields

The root is exactly one JSON object with all five fields:

| Field | Value |
| --- | --- |
| schema | Exact string brownie.project/0.3 |
| name | 1..80 ASCII lowercase letters, digits and hyphens; first is a letter/digit |
| entry | Object with module and function strings |
| sources | 1..32 objects, each with module and path strings |
| requires | 0..256 unique requirement strings |

There are no defaults, optional extension fields or ignored values. Field order
is immaterial. Unknown and duplicate keys fail in every object; comparison uses
decoded strings, so Unicode escapes cannot hide a duplicate. Trailing commas,
comments, multiple roots, wrong scalar/container types, invalid UTF-8/escapes
and missing fields fail. The whole input is at most 65536 original UTF-8 bytes.
Accepted schema nesting is at most three; no recursive parse or unknown-value
walk occurs. A leading BOM fails.

Modules use canonical double-colon-separated existing language identifiers, up
to 128 bytes. Functions use one existing identifier, up to 64. Reserved words
and guest roots std/brownie fail under the existing declaration rules. Source
module identities are unique and the entry module must occur in the source map.
The [native snapshot binding](../engineering/project-sources.md) now proves each
exact member identity/header and selected public i32 entry. Complete executable
admission still follows through the retained module Program.

Member paths are canonical root-relative ASCII source names up to 240 bytes,
ending in lowercase .brc or .fy. The [input primitives](../engineering/project-input.md)
define the complete spelling/device checks. Duplicate paths, including ASCII
case collisions and equivalent JSON-escaped spellings, fail even on a
case-sensitive host. Module identities retain language case sensitivity.

Requirements have at least two dot-separated lowercase alphanumeric segments,
each starting with a letter; total length is at most 128 bytes. Duplicate decoded
requirements fail. These are declarations, not run grants, host registrations
or policy ceilings. Parsing a nonempty list grants nothing.

## Native ownership and limits

The parse function in project_manifest returns an opaque owning Project only
after complete schema, uniqueness and entry-map checks. It copies decoded values;
no input borrow or mutable field escapes. Read-only accessors expose project/
entry names, source module/path pairs and declared requirements. Out-of-range
source/requirement queries fail. Error offsets refer to original JSON bytes;
global entry-map failure uses offset zero.

Decoded semantic strings total at most 44816 bytes:
80 + 128 + 64 + 32*(128+240) + 256*128.
Private pool capacity is bounded by the smaller of that total and input length;
schema text is checked without retention. Fixed metadata uses 32 source pairs
and 256 requirement spans. There is no DOM or retained raw JSON copy.
Requirement uniqueness needs at most 32640 comparisons of up to 128 bytes;
source-map uniqueness needs at most 496 module/path comparisons.

Metadata accepts the complete 32-source format. Current native compiler/snapshot
limits remain 16 files and 4096 aggregate source bytes; consuming this format
must report those separate compile limits rather than silently truncate metadata.
This increment does not promote full-profile source/resource capacities.

## Availability

The [complete example](../../examples/projects/hello/project.json) includes two
source files and an explicit public i32 start entry. Native metadata parsing is
implemented; a filesystem project collector and CLI project flag remain pending.
The source map does not prove anchored root membership, reparse-point safety or
file identity. No file is opened by metadata admission.

Untrusted collection must retain the selected root, enforce membership while
opening every member, reject prohibited reparse/device aliases and duplicate
physical identities, and snapshot exact bounded bytes before compilation.
Checking a spelling or path prefix before an ordinary open is insufficient.
The current Fairy SDK has ordinary file opens and observed directory-entry
reparse metadata; those APIs alone do not establish race-free anchored opens.
An explicit Brownie OS shim or a later suitable SDK primitive is needed; modifying
the Fairy checkout is not part of this implementation.

Policy/catalog/run configuration, input ABI, host authority, restricted delivery
and public project CLI are separate remaining obligations.

## Verification

Windows development and release each passed 20 focused native groups (13 input
primitive/name regressions plus seven metadata groups) on 154 matching verification
inputs. Both locked LF production mirrors passed. Tests cover owned decoding,
decoded duplicates, strict grammar/types, path/namespace failures, independent
32/33-source and 256/257-requirement limits, and all maximum string lengths/counts
simultaneously filling the exact 44816-byte semantic pool.

Run tools/verify-static-execution.py with --profile development and --selection
project-manifest; repeat with --profile release. See the [focused evidence](../evidence/project-manifest-windows-20261105.json).
The example/editor-schema consistency check is static only. No CLI or file-loader
execution, policy grant, isolation, allocator/OOM or Linux claim follows. The
earlier input-only receipt remains scoped to its original checkpoint.

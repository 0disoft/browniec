# Native project input primitives

Date: 2026-11-05. This advances the input-validation part of L01/C01.
It does not introduce a project CLI, file collector, policy loader or grants.

The json_tokens module reads at most 65536 original UTF-8 bytes. Tokens distinguish
strings, JSON numbers, true/false/null, punctuation and EOF. Raw controls, invalid
UTF-8, invalid escapes, unpaired UTF-16 surrogates, malformed numbers and a leading
BOM are rejected. Paired surrogates decode to their exact Unicode scalar; escaped
NUL is legal JSON data and must be rejected by consumers whose values forbid NUL.
Decoded output belongs to caller scratch; insufficient scratch fails explicitly.
No reference into scratch escapes. A failed advance leaves the prior token state.

This is a lexical reader, not a generic document validator. Schema consumers must
check the complete object/array grammar, duplicate decoded keys, required/unknown
fields, scalar types, nesting and EOF after exactly one root. The start function
validates the complete input's UTF-8; native mutable State is only parser scratch.

The project_names module supplies pure spelling checks for project metadata:

- Project names: 1..80 lowercase ASCII letters, digits and hyphens, starting with
  a letter or digit.
- Module names: 1..128 bytes, double-colon-separated existing language identifiers
  and reserved-word rules. Guest roots std and brownie are forbidden.
- Function names: 1..64 bytes under the same identifier/reserved-word rules.
- Requirements: 1..128 bytes, at least two dotted lowercase alphanumeric segments,
  each starting with a letter. A requirement is a declaration, never authority.
- Members: 1..240 ASCII bytes, canonical relative slash components and a lowercase
  .brc or .fy suffix. Empty/dot/parent components, trailing dots, roots, drive
  prefixes, backslashes, ADS colons, controls, non-ASCII, spaces and wildcards
  fail. Every component rejects Windows reserved device stems, case-insensitively,
  including stems before extensions. Device-like ordinary names such as COM10
  remain valid. Path collision checks fold ASCII case on two valid spellings.

These predicates establish no filesystem membership or identity. Symlinks,
reparse points, hard links and collection races require an anchored collector;
joining a validated spelling to a directory is not that proof. Explicit native
host snapshots remain the available source-input path.

Both routines use linear scans and bounded scratch. Tokenization never recurses
or builds a DOM. These bounds do not promote the compiler's current 16-file,
4096-source-byte capacities or the reference profile's other limits.

## Verification

Run tools/verify-static-execution.py with --profile development and --selection
project-names, then repeat with --profile release. This selects JSON and path/
name native tests, checks the locked LF production mirror and records exact
compiler/input/test-discovery identities. No CLI, filesystem anchoring, policy,
host authority or full-profile runtime claim follows from this selection.

Windows development and release each passed 13 native groups on 152 matching
verification inputs; both locked LF mirrors passed. See the [focused evidence](../evidence/project-input-windows-20261105.json).

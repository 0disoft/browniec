# M2 Record Result Signature Foundation

- Status: signature metadata implemented and verified in development and release
- Scope: bounded nominal record-result detection in function signatures
- Runtime: none; source record returns remain unavailable
- Evidence: [Windows receipt](../evidence/m2-struct-result-signatures-windows-20261028.json)

The signature scan recognizes a bare nominal result such as `fn Point make(...)`.
It reuses the same bounded `record_type` lookup as record formals, including names
declared after the function. Unknown names, borrowed or `var` results, record
arrays, generic record forms, and wrapper payloads containing a record remain
unsupported. A bare nominal name may denote a record with nested by-value fields;
its execution is gated like every record result. Existing scalar, wrapper, and
exact scalar-array result syntax is unchanged.

`functions::Table.return_records` is a `u8[16]` field. Zero marks a scalar, array,
or wrapper result. A nominal record stores its declaration ID plus one in the
range 1..32. `return_types` and `return_lengths` are zero for that slot. This keeps
record identity separate from scalar tags and array lengths; the encoded value is
not a VM site.

| Metadata | Record result | Scalar, array, or wrapper result |
| --- | --- | --- |
| `return_records[f]` | nominal ID + 1, 1..32 | 0 |
| `return_types[f]` | 0 | existing type tag |
| `return_lengths[f]` | 0 | 0 or exact array length |

All sixteen slots start at zero, and the table retains the existing 16-function
limit. The field adds 16 bytes of signature metadata. This is a layout count, not
an allocation or performance measurement.

## Entry point and compilation gate

`main` remains a zero-argument scalar `i32` function. A record result on `main` is
rejected during signature scanning because its arguments, type, length, and record
metadata do not match the entry contract.

After `functions::scan` completes, `compiler::compile` checks every
`return_records` entry before creating IR, preparing array or record catalogs, or
lowering any body. A nonzero entry returns the existing type error (`kind` 3) at
the function-name span stored in `signatures.begins`.

The gate therefore rejects record results on unused helpers, functions with
invalid bodies, and programs whose aggregate catalogs would later overflow. This
prevents the zero `return_types` placeholder from reaching IR as a scalar result.
Malformed signatures still fail during the scan; the gate covers declarations
that the signature table accepted.

The increment adds no IR, VM, opcode, Fuel, profile, or version capability.
Existing record parameters and scalar-array results retain their behavior. No
source path returns a record.

## Verification

Executed:

```text
python -B tools/verify-m2-struct-result-signatures.py --phase signatures
```

Development and release each passed 22 native groups and 2,317 CLI cases. The [Windows receipt](../evidence/m2-struct-result-signatures-windows-20261028.json) records the original baseline, executed commands, compiler/SDK and CLI identities, input hashes, and outcomes. The native selection comprises 6 new record-result, 6 record-formal, 6 array-result and 4 scalar-function groups. CLI coverage comprises 72 new record-result, 66 record-formal, 114 source record-parameter, 96 array-result and 1,969 M1 cases per profile. All 209 input hashes, the compiler, SDK and final release CLI were checked before archival. Full native suites, other CLI matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.

The six new native groups verify disjoint result kinds, zero sentinels, nested and
forward nominal names, mutual signatures and source spans, the final function
slot and nominal ID, invalid result shapes and entry points, the pre-IR gate
before invalid bodies or aggregate catalog exhaustion, and supported record
parameters, array results and shallow wrappers. The new CLI matrix covers both
declaration orders, record counts 1/16/32, six scalar field types, exact function
name diagnostics, rejected shapes, and executable controls. A cleared runtime
environment and tool-free PATH do not establish packaging or OS isolation.

Earlier receipts are historical for changed scanner, compiler, root-lock,
signature fixture and harness inputs. No new record-result runtime capability
is advertised. The next step is private result IR and independent verification,
followed by VM owner transfer and source lowering.

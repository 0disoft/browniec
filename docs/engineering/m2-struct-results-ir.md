# M2 Record Result IR and Verifier Foundation

- Status: implemented at `dc1574b`; verified for its original baseline; its VM
  runtime gate and blanket source gate are historical.
- Scope: nominal record-result metadata, `SRET` verification, and record-result CALL destinations
- Runtime: historical kind 11 availability gate, superseded by [record-result VM transfer](m2-struct-result-vm.md)
- Source: historical blanket gate, superseded by [bounded source record results](m2-struct-result-source.md)
- Evidence: matching core and native-only regression receipts, linked below
- Successor: [M2 private record-result VM ownership transfer](m2-struct-result-vm.md)
- Source successor: [M2 bounded source record results](m2-struct-result-source.md)
- Implementation: [struct_results.fy](../../src/struct_results.fy), [ir.fy](../../src/ir.fy), [verifier.fy](../../src/verifier.fy), and [vm.fy](../../src/vm.fy)
- Tests and harness: [struct_results_ir.fy](../../tests/m2/struct_results_ir.fy) and [verify-m2-struct-results-ir.py](../../tools/verify-m2-struct-results-ir.py)

This slice adds private IR and independent verification for functions that return
a nominal record. At this checkpoint it did not lower a source record return or
execute an owner transfer. The existing record-result signature metadata remains
separate: `record_results` names a callee-owned IR site, while `return_records`
names a declaration ID. The [source successor](m2-struct-result-source.md) now
emits this IR for bare exact-nominal returns and typed call initializers.

## Metadata

`Program.record_results` is a `u8[16]` table. Zero marks a scalar, array, or wrapper result. A record result stores its callee-owned record site plus one in 1..16. For every active entry, `struct_results::metadata` requires:

- the owning function to be a non-entry function and the site to be below the catalog count;
- `record_functions[site] == function` and `array_results[function] == 0`;
- `return_types[function] == 0`;
- the encoded site to remain within the catalog; its owner need not be live.

The anchor supplies the exact nominal shape for CALL checks and SRET. It is not required to be live when the result is returned, and a distinct live record of the same nominal type may be the returned owner.

## SRET

`SRET` is opcode 50. Its encoding is `dst=0`, `a=source site`, `b=0`, with bytes 4..7 reserved as zero. The source site names a callee owner; it is not a destination register.

The independent checker requires the owner to belong to the active function and have the same nominal shape as the function's result anchor. Its live set must be exactly `1 << (16 + source)`: one record owner and no array or other record owners. A record-formal owner can be returned, provided it satisfies those conditions. The instruction is terminal, so verification has no successor state.

## CALL destinations

Record-result calls retain opcode 9, the existing dense call-argument schema for scalar registers and array or record sites, and the existing eight-argument limit. The destination is `dst = 144 + site`, identifying a caller-owned record site in 0..15 rather than an array site or scalar register.

For a target with active record-result metadata, `struct_results::call` requires a dead destination owned by the caller and of the exact nominal shape named by the target's anchor. A caller record-formal slot is rejected as a destination even after it has been dropped. Successful checking adds the destination's live bit at `16 + site`; arrays continue to use bits 0..15.

Existing CFG joins and loop backedges compare the full live sets exactly, including bits 16..31. Merging paths with different live sets, or taking a backedge with a live set different from its target, fails verification.

## Builders and bounds

`ir::record_return` emits opcode 50 with the source site and zero destination and `b` operands. `ir::record_call` preflights the 256-instruction (2,048-byte code) ceiling, the 32-call-site ceiling, the eight-argument bound, the 0..15 target and destination bounds, and every argument's one-byte encoding before writing argument bytes or CALL metadata. Its destination bound produces the encoded range 144..159.

Function arity, register windows, record catalogs, record sites, and aggregate quotas remain under their existing limits. The new field adds 16 bytes to the private program layout. This is a layout count, not an allocation, stack, or performance measurement.

## Historical gates and unchanged surface

At `dc1574b`, `vm::run` and `vm::run_with_array_limit` verified first and returned error kind 11 at offset 0 when any `record_results` entry was active, before Fuel accounting, payload reservation, or guest execution. That availability gate is historical and superseded by the [record-result VM successor](m2-struct-result-vm.md); current execution owns `SRET` transfer. Malformed IR still reaches the verifier first and reports the normal kind 5 failure.

This slice added no record-owner transfer, `SRET` dispatch, or source return
lowering. Its compiler gate rejected every scanned record result, so source record
returns were unavailable at that checkpoint. The source successor now lowers a
bounded subset while preserving `return_types[f] == 0` and using the result anchor
described above. The IR increment added no Fuel charge, array or record price,
source profile, or `--version --json` capability change.

## Verification

Executed as two separate phases:

```text
python -B tools/verify-m2-struct-results-ir.py --phase core
python -B tools/verify-m2-struct-results-ir.py --phase regressions
```

Development and release each passed 39 unique native groups and 2,317 CLI cases. The [core receipt](../evidence/m2-struct-results-ir-core-windows-20261028.json) records 21 native groups (8 new record-result, 6 array-result, 7 record-parameter), CLI builds and all 2,317 cases; the [regression receipt](../evidence/m2-struct-results-ir-regressions-windows-20261028.json) records 18 native-only groups (6 array-result VM, 8 record-call VM, 4 scalar-function), with no build or CLI rerun. CLI coverage is 72 record-result signature, 66 record-formal signature, 114 source record-parameter, 96 array-result signature and 1,969 M1 cases per profile. These were two separate phase invocations across implementation commit `dc1574b`, with disjoint native selections and matching 212 input hashes, compiler and SDK identities. All inputs and the final release CLI were rechecked before archival. Full native/CLI suites, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.

The eight new groups cover six scalar leaf tags, nested records, recursive
forwarding, a distinct shape anchor, record-parameter ownership returns, mixed
scalar/array/record arguments, malformed metadata, nominal mismatches, dead and
foreign destinations, reserved operands, extra owners, joins and backedges,
site 15/live bit 31, builder capacity/encoding rejection, and verifier-before-gate
ordering. Earlier receipts are historical for changed IR, verifier, VM, root-lock,
fixture, and harness inputs. This evidence does not execute record-result transfer
or the later source lowering. The [VM successor](m2-struct-result-vm.md) records
transfer for its own original inputs. The [source successor](m2-struct-result-source.md)
is verified in development and release at 14 native groups and 2,438 CLI cases per
profile; its receipt records the aggregate and focused checker repair.

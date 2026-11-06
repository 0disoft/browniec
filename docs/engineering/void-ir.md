# Void call and return IR

Date: 2026-11-06. Native foundation. The [source successor](void-source.md)
now connects declaration, statements and lexical cleanup; the original
foundation-only verification below remains scoped to its checkpoint.

Return tag 13 denotes void only in function metadata. `types.valid` deliberately
continues to exclude it, so no local, scalar register, argument or tagged payload
can contain a void value. This also leaves the frontend's pure-for-header context
zero distinct from void function bodies.

Opcode 82 returns without a value; all seven operand/reserved bytes are zero.
A CALL to a void function has canonical destination zero and defines no scalar
register. The builder returns sentinel 256 to its native caller, not a guest
value. Independently checked return metadata, CFG initialization, exact argument
maps and live owner/loan/image cleanup remain mandatory. Entry still returns i32.

The ordinary and retained drivers restore the existing call frame and loans,
without reading a return register or writing the caller's destination zero.
The new RETURN costs one dispatch unit. Existing CALL, ownership transaction,
cleanup and operation prices are unchanged; default 256 and ceiling 16000000
remain.

Windows development passed three native groups with:

```text
build/toolchain/fairyc.exe test --native --capture-output --json --locked --file tests/m2/void_execution.fy
```

The no-argument call succeeds at exactly four ordinary Fuel units and fails at
three. At 128 occupied value registers the corresponding program succeeds at
131 and fails at 130, without a dummy result register. Retained execution also
preserves the caller's existing cell. Malformed operands/reserved bytes,
destinations, value returns and void register types fail independent admission.
Release, source and CLI checks were not run for this native foundation.

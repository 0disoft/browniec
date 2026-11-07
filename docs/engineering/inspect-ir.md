# Public bounded IR inspection

`browniec inspect SOURCE --ir [--json]` reads one explicitly selected source file
and uses the same public admission as `check`. Legacy scalar/aggregate/slice code
is compiled and independently verified. Literal/shared-byte sources retain the
same immutable, completely admitted reference Program as public check/run.
Inspection never enters the VM or calls a host operation.

The CLI requires one `--ir`. `--json` and `--ir` may appear in either order after
SOURCE; duplicate/unknown options and run-only `--fuel` reject as usage errors.
`--isolated` remains unavailable without fallback. Source selection, the 4096-byte
source limit and zero-argument i32 main remain unchanged. Public Buffer, input,
host calls, Engine lifecycle, restricted execution and embedding stay unavailable.
Version JSON reports `inspect_ir: true` alongside the unchanged execution flags
and public Fuel default 256 / ceiling 16000000.

Text mode emits ASCII diagnostics to stdout; failures use the existing stderr
diagnostic style. JSON mode emits one `browniec.ir/v1` object with command
`inspect` and status `inspected` or `error`. Successful objects contain:

- Selected public profile and `brownie.private-instructions/1` diagnostic format.
- Entry function, instruction/register counts and retained literal byte count.
- Function IDs, PC ranges, register ranges, arities and return tags.
- Scalar register type tags and the signed packed constant cells.
- Every instruction PC, source byte offset and all eight instruction bytes.

The upper usize domain retains its existing packed i64 cell representation in
the constant list. Aggregate/static/reference operands retain their actual
private instruction encoding. Catalog layouts, retained literal contents and
all other complete Program metadata are not serialized. This output is for
diagnosis, not a standalone bytecode format or executable Program. No bytecode
loader, disk code cache, native address or host capability is exposed.

The encoder admits the existing maxima (256 instructions, 128 registers/constants,
16 functions, 32 call maps and 4096 list operands). It stages a complete owned
output Buffer with a 128KiB diagnostic ceiling before one console write. Encoding
or sink failures return process status 7; a partial sink write is not rolled back
and no second JSON object is appended. Error objects contain the fixed diagnostic
kind and offset, with no partial instruction list or unescaped source/path text.
Instruction tags/numbers/offsets are numeric, so guest strings cannot inject
terminal control bytes. Existing check/run output schemas and statuses remain.

`python tools/verify-inspect-cli.py --profile all` builds both native profiles in
locked mirrors using the pinned toolchain and no compiler/linker overrides.
Each profile checks 19 CLI cases plus version/help with an empty tool PATH.
Cases cover exact scalar IR, text output, division by zero and infinite-loop
sources that inspect without execution, arrays, records, retained byte literals,
the combined 32-deep conditional/32-call parser fixture, malformed source/UTF-8,
oversized source, options and ordinary check/run regression. This is Windows
evidence when executed there; Linux and full-profile conformance remain open.

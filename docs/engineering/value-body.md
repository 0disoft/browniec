# Private typed-source body execution

The [predicate successor](value-predicates.md) now adds non-consuming typed
Option/Result inspection through TAG_TEST98, including move-only Buffer wrappers.
The [propagation successor](value-propagation.md) now connects wide/resource `?`
and early cleanup. [Private must-use](value-must-use.md) now tracks Result
obligations; typed value-expression joins, loops and public
integration remain separate work.

`value_source::compile` now lowers actual source bodies to `value_ir::Program`.
The resulting candidate passes through `verifier::inspect_values` and the existing
retained native `vm::run_values` path. No proof, root, frame or native allocation
is supplied by source metadata. Public compiler/CLI routes do not select this
increment and do not retry failed compilation in another dialect.

## Source and ownership

This increment implements immutable annotated/inferred locals, lexical blocks,
explicit discard, scalar expressions, ordinary/void calls, Buffer/wrapper value
arguments and explicit returns. `bytes::empty()` and
`brownie::bytes::empty()` create actual empty native Buffers with instruction95.
Canonical `.some`, `.none`, `.ok` and `.err` constructors compose through the
existing four-level wrapper depth, including wide scalar and Buffer payloads.
`.some` can infer its child; Result constructors and `.none` need exact context.
All six scalar domains retain their ordinary register encoding, including signed
minimum and full unsigned ranges. This does not add a serialized value format.

`value_source_functions::Plan` retains exact canonical signature types before any
body is emitted. Forward calls consult that plan; complete IR parameter positions
and Dead result anchors are installed while each function is lowered. Ordinary
scalar formals keep ordinary register cells; typed positions use the existing
separate value-slot domain. Names and parameter positions stay in source order.

Typed names use whole-type COPY89 or MOVE88. An inactive Buffer alternative still
makes the whole wrapper move-only. Reusing a moved name or repeating a move-only
actual rejects before executable admission. Constructors copy copyable children
and consume move-only children, with explicit cleanup of anonymous copied inputs.
Arguments evaluate once, left to right, into separate captures. CALL93 transfers
move-only captures and copies copyable ones; caller-owned copies are then dropped.
The VM's existing atomic CALL/RETURN transactions perform the actual handoff.

Scope exit emits reverse lexical DROP90. A function return drops all other live
typed values, removes source names and emits RETURN94 for a typed result, ordinary
RETURN8 for a scalar or RETURN82 for void. The independent verifier requires the
same exact initialized/Dead state and sole remaining typed return value.

`value_source_ops` preflights exact operands, scalar register domains, liveness,
instruction capacity and slot capacity before publishing constructors/conversions.
Function metadata and the complete parser discard their entire candidate on any
error; partially lowered candidates must never be resumed or executed. Recursive
expression/block parsing is bounded at32, with the existing private16 typed slots,
128 registers, 256 instructions, 16 functions and eight arguments. Slot allocation
never rewinds between functions or lexical scopes.

## Scope still open

This is a private executable body bridge, not full language completion or public
Buffer admission. The [control successor](value-control.md) now supplies mutable
assignment and statement if/switch joins. Typed value-expression joins, loops,
propagation, must-use diagnostics, aggregate construction/projection, general
references, import/visibility integration and ordinary/retained public source
composition still need implementation. Typed arrays and nominal records can have
signature metadata; this parser does not yet create their source values.

Useful Buffer operations still need source/IR/runtime connection: allocation with
capacity/content, bytes input, read/write/grow, views/text and staged output. Empty
Buffer construction alone does not complete D01-D05. Engine/Instance, host exchange,
restricted workers, embedding and delivery remain separate work. Existing opcode
prices, Fuel default256/cap16000000 and public capabilities are unchanged.

## Verification

Run `python -B tools/verify-value-body.py --profile development` and its release
counterpart. The focused runner shares the existing locked native implementation
and writes separate `build/value-body/{profile}/receipt.json` files. It hashes
both runner files, all production modules and the exact selected test modules,
then checks mirrored/original bytes before and after native execution.

The selection has19 groups: four source-body, five function metadata, three
construction/conversion, five existing lexical ownership and two existing typed
VM regressions. Source tests execute forward mixed calls, active/inactive Buffer
wrappers, nested wide copyable wrappers, void/scalar paths, six scalar domains,
lexical cleanup, moved-name rejection, zero Fuel and failed native quota setup.
The unchanged combined tag regression remains one test without stack overrides.

Windows development/release each passed all 19 native groups on `468394d`, after
helper implementation `9476d25`. All206 recorded inputs match checkout and Git raw
bytes; all 196 production modules are LF. Both runs used final byte-identical
production/selected-test mirrors, without native overrides or historical reuse.
See the [Windows evidence](../evidence/value-body-windows-20261107.json) and
[input manifest](../evidence/value-body-inputs-windows-20261107.json).
No public CLI matrix, full native/language/Fuel matrix, Linux, LF runtime mirror,
OOM injection, general stack/performance or clean-machine delivery pass is implied.

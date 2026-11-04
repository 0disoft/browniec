# Static CALL and returned-origin recipe proof

Date: 2026-11-05. This follows [computed source ranges](static-range-source.md)
and prepares the required image-backed argument/return contract. It checks real
IR recipes, their Static lifetimes and grounded origins. It is not whole-program
scalar/owner/loan proof, executable admission, VM dispatch, source CALL syntax,
an Engine pin or a host-visible returned-view API.

## Private signature and eight-byte instructions

`static_call_ir::Program` owns copyable ordinary IR plus untrusted parameter-kind,
result-kind and result-origin claims. Kind 1 is immutable bytes and kind 2 is
validated text. These are storage-specific private recipes, not new public
language types. Existing logical function arities and CALL maps still contain
at most eight mixed positions; a Static formal has a reserved type-zero position
and never contains a scalar value, array owner or loan ticket.

| Opcode | Operands |
| --- | --- |
| 77 PARAM | `dst=new site`, `a=formal register`, `b=kind`; entry prelude only |
| 78 CALL | `dst=Static result site or ordinary destination`, `a=callee`, `b=CALL map` |
| 79 RETURN | `dst=0`, `a=sole remaining live Static site`, `b=0` |

Bytes 4..7 are zero. PARAM instructions are ordered by actual formal position,
contiguous at function entry and independently matched to the signature. Jumps
cannot reenter their prelude. Static actuals use `192 + site`; their kind comes
from the independently reconstructed site, never the numeric encoding. Ordinary
argument positions retain their existing signature-selected encoding. Opcode 78
is required whenever a callee has a Static formal or result. Ordinary CALL
opcodes cannot bypass this classification. CALL maps remain unique with checked
arity and zero padding. Entry has no Static formal/result and still returns i32.

Parameter, OPEN, BYTES, ALIAS, RANGE and Static CALL result definitions share one
sixteen-site namespace. The checker reconstructs exact function/kind/definition
identities from code. OPEN validates its real retained image kind, window and
UTF-8 boundaries; conversions and ranges retain the source's lineage. The
separate CFG live plane requires matching join/backedge states and forbids use
after close, cross-function actuals, duplicate sites and numeric manufacture of
a view. A Static return consumes the sole remaining live site of its result kind;
other Static aliases must already be closed. Ordinary terminals require no live
Static site. Existing scalar/owner/loan checking remains an additional obligation.

## Grounded origins

Origin claims use 1..8 for an exact logical input position, 9 for Static storage,
and zero for an ordinary result. The selected position counts every argument,
including scalar prefixes; it is not the ordinal among Static parameters.
BYTES, ALIAS and RANGE preserve that origin even when their resulting kind or
selected byte span changes. CALL composes a callee's independently derived input
origin with the actual source site at that call. Literal-based results remain
Static.

The solver revisits at most sixteen functions/256 instructions for at most
sixteen rounds. A reachable direct input/literal return provides a witness for
recursive summaries. A cycle whose only claimed witness is another unresolved
CALL remains unknown and rejects. Every return path must derive the same origin;
a claim cannot hide another input or convert a parameter origin into Static.
Transitive callers remap logical positions through their actual argument maps.

Static means storage owned by this exact retained Program/image; it does not
mean immortal process storage. This proof neither owns/pins that Program nor
validates runtime frame words. Future transfer must authenticate the caller's
actual live view against this same image and preserve its actual span and kind.
Text receipts must preserve validated boundaries; byte ranges cannot become text.

## Verification and integration

Run `python -B tools/verify-static-execution.py --profile development --selection
call-ir`, then repeat with `--profile release`. The selection runs recipe checks
and existing retained-Program regression groups. The final selection has eleven
new recipe groups plus six existing retained-Program groups. Windows development
and release each passed all seventeen native groups on 133 matching final inputs
and the same 228-file discovery identity. All 127 production modules are LF; both
locked LF mirrors pass. No compiler/stack overrides or historical-result reuse
were used. See [focused Windows evidence](../evidence/static-call-ir-windows-20261105.json).
Implementation is committed as `a6a62d5`; evidence records the preceding starting
head and exact final input hashes. Earlier checker/native and fifteen-group
probes are excluded.

The current bare verifier/VM and retained-Program admission still reject 77..79.
The recipe proof cannot substitute for their complete scalar definitions/types,
ordinary argument/aggregate/loan shapes, ownership or metering proof. No guest
price, capability flag, source gate, runtime descriptor table or ABI is promoted.
Focused proof tests cannot establish runtime lifetime retention or full-profile,
stack/RAM/allocator/timing, Linux, restricted Windows or C ABI/package behavior.

Next integrate this recipe contract into complete image-aware admission, then
canonical CALL/return dispatch. Preflight full transfer Fuel and all destinations
before publishing frame words; retain the exact image for the invocation and
copy actual spans without payload allocation. A formal may receive different
image windows at different CALLs; do not bind it permanently to one literal or
replace a transferred span with a maximum window. Preserve validated text
boundaries and forbid scalar reads/writes of type-zero Static formal positions. Preserve ordinary owner/loan entry,
return and zero-Fuel abort. Native external entry must not manufacture Static
arguments from scalar values or expose a returned frame word without a real
Program lifetime API. Then lower source actuals/returned views and verify
end-to-end cases before public admission. The complete accepted goal stays open.

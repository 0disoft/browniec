# Conditional Buffer owners behind shared views

Later [terminal expressions](value-bottom.md) and [loop origin inference](value-view-loop-origins.md)
add selected composition. This predecessor records the conditional-owner checkpoint
`ea8c773`; the current inventory owns remaining work.

Private byte views may now select anonymous Buffer owners created only on the
chosen `if` or exhaustive `Option`/`Result` switch arm. Ownership follows the
actual executed path. The compiler does not create empty owners for unselected
arms, move a pinned owner, rebind a native lease, or copy Buffer payloads.

```c
module main;
fn ref u8[] id(ref u8[] v) { return v; }
fn i32 main() {
    let r = if (true) { id(ref bytes::view(ref bytes::empty())) }
            else { id(ref bytes::view(ref bytes::empty())) };
    if (r.len == 0) { return 42; }
    return 0;
}
```

This remains a private retained-value execution path. Ordinary public source,
CLI capability flags, external bytecode loading and the public ABI are unchanged.

## Independent owner proof

The canonical CFG verifier now keeps two bounded initialized-state planes.
Definitely initialized slots intersect at forward joins; possibly initialized
slots union. Only exact Buffer nodes may become uncertain. Scalar values and
Buffer-containing Option/Result wrappers retain exact ownership requirements.

Every ordinary read, move, borrow, owning CALL argument, tag payload and DROP
requires definite initialization. Publication requires absence from the possible
plane. Successful returns must leave no possible owner except an exact, definite
owning return value. Both planes must match a loop header exactly on backedges;
this does not add general evolving source-loop inference.

`DROP_IF_LIVE` (115) names one exact local Buffer slot, with zero remaining
operands and reserved bytes. It clears both proof planes. Independent view-origin
analysis rejects it while any live descriptor could depend on that slot,
including aliases, narrowed windows and selected-input CALL results.

On 64-bit targets the owner planes occupy 4 KiB rather than 2 KiB. The separate
view-origin fixed-point proof, 16 owning slots, 16 frame-local view IDs and
bounded instruction/frame limits remain. Neither proof trusts compiler snapshots.

## Compiler lifetimes and cleanup

`State.maybe` contains possible-only anonymous Buffer slots and is disjoint from
definite `live`. It cannot overlap ephemeral loans, Result obligations or named
owning bindings. Snapshots, alternative selection, joins and loop transfers keep
the complete state without rewinding static allocation IDs.

Branch normalization retains differing anonymous roots required by surviving
view descriptors. It still normalizes ordinary conditional moves with real
cleanup. Aliases and CALLs retain the complete candidate set. An explicit shared
CALL return may retain a temporary into a lexical view; a direct anonymous view
is limited to its full expression. Arm-local named owners cannot escape.

Last-alias close, rebinding, lexical exit, propagation and loop transfer close
views before retiring their candidate roots. Definite roots use existing DROP90;
possible-only roots use 115. Cleanup capacity is admitted before publication.
View mutators and loan boundaries validate the new state before changing IR or
loan masks. View copying authenticates all possible local candidates while the
native operation reads only its selected concrete root.

## Native execution and Fuel

The new instruction uses the existing authenticated native frame live bit.
Both Live and Dead paths validate activation generation, layout, exact Buffer
type and initialization order. Dead additionally requires canonical zero bytes,
a valid root store and no root associated with that binding. Live retires through
the existing checked owner path and still rejects a native read lease.

Both paths pay the existing eight-byte frame operation price, `2048 + 4*8 = 2080`
Fuel. No new allocation or owner word is published. Existing instruction prices,
no-view setup and public Fuel default 256/ceiling 16000000 are unchanged. Failure
cleanup continues to use prepaid native ledgers after view shutdown, with no
guest cleanup callback or remaining Fuel requirement.

## Verification and remaining work

`tools/verify-value-view-conditional-owners.py` separates `kernel`, `source` and
`regression` batches. Profiles use disjoint locked mirrors and default native
stacks. The source selection includes conditional payloads, nested alternatives,
mixed named/temporary roots, aliases, rebinding, copy, immediate unretained views,
loops/transfers, selected bounds errors and ordinary-public rejection. Existing
Result obligations, conditional moves and admitted32/rejected33 remain regressions.

Implementation `ea8c773` on kernel `cd417e2` passed 72 groups in each Windows
native profile: kernel 25, source 30 and regression 17. The kernel includes
thirteen new independent IR and five native cleanup groups plus seven prior
origin-set groups. Source includes eleven native metadata drivers for thirteen
small helper scopes, eight new source groups with 24 guest programs and eleven
predecessor source groups. Regression includes Result obligations, exact loop
state, conditional moves and the unchanged admitted32/rejected33 helper/test.

The older Result replacement example already rejected at byte56 with must-use
error18 on `b5aff73`, reproduced by a separate development native test. It now
acknowledges the previous value before replacing it; rejection policy is unchanged.

All 232 union inputs match checkout and Git raw bytes; all
216 production modules use LF. Both profiles used default native stacks
and fresh byte-identical production mirrors. See [focused evidence](../evidence/value-view-conditional-owners-windows-20261107.json).

General evolving source-loop origins, bottom expressions, mutable/non-byte and
Buffer-object references, methods, public AllocError/admission, text/I/O,
Engine/Instance/host/cancellation, isolation, embedding and platform/delivery
requirements remain in the [inventory](../product/04-remaining-work.md). This
increment does not establish public CLI, Linux/macOS or restricted execution.

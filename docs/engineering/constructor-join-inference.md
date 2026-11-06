# Constructor inference across value arms

Date: 2026-11-06. Source successor to
[constructor constraints](constructor-join-constraints.md).

```brownie
let absent = if (true) { .none } else { .some(false) }; // Option<bool>
let result = if (true) { .ok(42) } else { .err(true) }; // Result<i32,bool>
```

Complete final constructor atoms in if/switch value arms now contribute
constraints before the result is published. A preceding `.none` can obtain its
Option payload domain from a later `.some` or complete typed value. Ok and err
arms together determine both Result domains. Both branch orders work for all
six existing shallow i32/bool wrappers. Parentheses and mixed nested final
if/switch expressions contribute to the same exact-type join. Named wrapper
values and calls with complete return types can also constrain missing domains.

At least one arm must yield; terminal arms contribute no type constraint. All
continuing arms, including unselected arms, must agree. Missing/conflicting
domains fail type checking. Standalone `.none`, `.ok` and `.err` still require
an annotation/signature/complete expected type; two none arms, only ok arms or
only err arms cannot invent a missing domain. Existing expected wrapper types
keep their exact payload rules. Classic-for restrictions remain.

This is inference over complete final atoms and shared nested tails. Arbitrary
flow-sensitive inference between separately declared unresolved locals is not
added. Constructors within another operator/propagation expression use their
existing expression context. Nested/resource-bearing wrappers, wider scalar
payloads, arrays, records, references, text and Buffer payloads remain L05 work.

## Lowering and authority

Read-only token classification identifies only a complete final constructor,
with existing grouping/depth limits. Actual lowering evaluates/checks each
payload once using the ordinary expression path. The join intersects alternatives
over existing type IDs 3..8 and tracks only its own provisional constructor
registers in two 64-bit words. On a unique result, it sets their final type and
the result slot type before emitting the load. Ambiguous results cannot escape
the private recipe. Payload values/types, evaluation order and instructions are
unchanged; there is no guest replay, runtime union or new type ID.

The final type patch visits at most 128 registers and allocates no heap storage.
Normal independent tagged/CFG admission still checks the resulting complete
Program. A malformed constructor register type fails that admission. Existing
ordered argument captures, early return/propagation, loop transfers, owner/image
cleanup and source-local module diagnostics remain. Earlier guest effects are
not rolled back on failure.

No opcode, operation price, source/storage/frame/register limit or profile is
changed. Default Fuel remains 256 and the CLI ceiling remains 16000000. The
`constructor_join_inference` version flag advertises this source subset.

## Focused verification

```text
python -B tools/verify-static-execution.py --profile development --selection constructor-join-inference
python -B tools/verify-local-inference-cli.py --profile development --constructor-join-inference
python -B tools/verify-static-execution.py --profile release --selection constructor-join-inference
python -B tools/verify-local-inference-cli.py --profile release --constructor-join-inference
```

The selection includes native constraints/source behavior, existing Option/tagged
semantics, scalar/aggregate joins, native qualified modules and original CALL
depth regressions. Forty-eight public source combinations cover all six existing
wrappers, both constructor orders, both selected arms and both control forms.
The original none-first rejection is replaced with an unresolved-both-none
rejection; none-first source execution is now tested positively.

Inferred/annotated Option<bool> Programs have identical instruction bytes,
register types/slots and constants. The none-selected fixture requires exactly
9 ordinary Fuel units (condition, branch, constructor, store, jump, load, case,
constant, return); 8 fails. The public retained image-binding variant requires
`344064 + 18 + 9 = 344091`; public fixtures check exact, one-short and one-more.
Input, compiler, native report and standalone CLI identities are recorded in
[Windows evidence](../evidence/constructor-join-inference-windows-20261106.json).

Development and release each passed **18 native groups and 440 tool-free CLI
cases** at `bdb6d2b`. All 177 input paths match checkout and Git raw bytes.
Both locked LF mirrors pass with 160 LF modules and common 278-file test
discovery. Forty-one unselected legacy fixtures differ only by CRLF/LF; both
hashes are recorded.

CLI builds are serialized; execution has an empty runtime tool PATH. Both native
profiles use locked LF mirrors. Full profile matrices, the full public Fuel suite,
Linux, allocator fault injection, general stack-size bounds and timing/delivery
benchmarks are outside this focused increment. Broader inference, L05, general
reference/Buffer joins, grouped lvalues/borrows, Engine/Instance/host and delivery
remain open.

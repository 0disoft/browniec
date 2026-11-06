# Typed value IR and independent move-state proof

`value_ir::Program` extends the actual eight-byte ordinary Program with a checked
type DAG and sixteen frame-local typed value slots. `verifier::inspect_values`
combines independently reconstructed type properties and initialized/Dead CFG
state with the existing complete scalar, array, record, loan, CALL and selected
place proof. This layer supplies analysis; the
[private execution successor](value-execution.md)
now retains an immutable `value_program::Program` and executes operations 88..97
through native value frames and the ordinary VM. Ordinary, image and returned
reference admissions keep their existing gates. The [source foundation](value-source.md)
now provides canonical type/signature and lexical COPY/MOVE/DROP metadata;
executable Buffer/wider-wrapper body lowering remains next.

## Instructions and type identity

Private operations 88..97 describe MOVE, COPY, DROP, TAG_BUILD, CASE, CALL,
RETURN, EMPTY_BUFFER, SCALAR_READ and SCALAR_VALUE. Each uses the ordinary eight
bytes and original PCs. Only CASE may use byte4, for its forward mismatch PC;
every other reserved byte is zero. Logical variant1 is some/ok and variant0 is
none/err, preserving the existing IR convention. This does not define a new
serialized value tag layout. Analysis of EMPTY_BUFFER proves a constructor
type/lifetime; actual allocation belongs to the admitted private execution path.

The native [whole-type prerequisite](value-ownership.md) recomputes layout, wrapper
depth and copyability. Duplicated equivalent nodes compare by canonical classes;
equal-layout distinct nominal record IDs remain distinct. Classification has
at most 64 nodes and 2016 earlier-node comparisons, without recursive expansion.
Every slot has one exact declared type and owning function. Typed formal positions
reserve existing register indices but have no scalar cell/type. Parameters,
results, inactive metadata and every new instruction are independently checked.

MOVE requires an initialized source and Dead destination, then consumes the
source. COPY additionally requires whole-type copyability and keeps the source.
DROP consumes exactly one initialized slot. Overwrite, double drop, use after
move, resource copy, cross-function access and malformed reserved bytes fail.
An explicitly Dead slot may be initialized again. Frame activations remain
distinct even when recursive calls use the same static slot IDs.

## Tags, calls and CFG

TAG_BUILD copies a copyable payload or consumes a move-only payload into an
otherwise Dead wrapper. A none constructor has no payload operand. CASE preserves
the original wrapper on mismatch. On match, it consumes a move-only **whole
wrapper**, even when the selected payload is scalar or absent. The selected
payload, if any, initializes its exact typed destination. Copyable wrappers and
payloads keep their independent source values.

CALL uses the existing bounded source-ordered argument maps. Opaque value actuals
encode 208+slot, outside the scalar, array, record, runtime-loan and Static
namespaces. Copyable actuals survive and may be repeated. Move-only actuals are
consumed in order, so a repeated move fails. Callee formals start initialized
in that separate activation. Result publication requires a Dead exact-type
destination after argument consumption, permitting a move-return into its
consumed source slot. RETURN transfers the sole remaining resource-domain value;
all ordinary owners, loans and selected places must already be cleaned.

Each forward edge carries an exact sixteen-bit initialized set. Joins require
equal sets, and backedges preserve the already established target invariant.
The pass uses 256 state words and 256 seen flags in a separate bounded frame;
ordinary programs do not acquire this extra CFG scratch. Every function body
must be reachable under the existing canonical rules. Normal exits drain this
domain; internal failure may retain values for native runtime-ledger cleanup.

The canonical verifier independently proves the real scalar definitions used by
SCALAR_VALUE and created by SCALAR_READ, scalar CALL actuals and results, ordinary
aggregate/loan lifetimes and CALLs with suspended reborrow forests. New CASE
edges and RETURN terminals also reach the pending-place graph. Ordinary/image/
returned-reference admission retains its old gates before Fuel/backing work.
An analysis receipt is copyable data, not executable or native token authority.

## Verification and next integration

Run `python -B tools/verify-value-ir.py --profile development` and the same command
with `--profile release`. `--batch core` selects eight new groups and
`--batch regression` selects four existing canonical groups covering recursive
and mixed aggregate copies, reborrow CFG restoration and mixed reference formals.
The runner records exact native identities, profile, compiler, inputs and streams,
checks locked inputs and rejects hash changes or historical/native-override reuse.
The core also checks returned proof fields after native aggregate return, rather
than only its Result discriminator. One full positive boundary uses all 64 type
nodes, sixteen live value slots, 128 scalar registers and RETURN at PC255.

Separately run `python -B tools/verify-public-fuel.py --profile development --phase cli`
and its release counterpart for the existing 105 tool-free CLI boundary cases.
The IR-analysis checkpoint added no public source syntax, capability,
price/default/ceiling or VM execution path. The private execution successor keeps
the existing public gates and prices. Full language/native Fuel matrices, Linux,
LF mirrors, OOM/general
stack/performance and clean-machine delivery remain separate work.

The [canonical byte successor](value-codec.md) now retains immutable layouts,
validates complete value bytes and supplies atomic copy/wrapper primitives.
The [native frame successor](value-frames.md) now supplies actual native value
storage, activation generations, COPY/MOVE, tag construction/extraction, combined
quotas and prepaid cleanup. The [private execution successor](value-execution.md)
now connects retained code/layout, typed dispatch and atomic mixed typed/ordinary
CALL/RETURN handoff to that storage. The [source foundation](value-source.md)
now supplies canonical type/signature and lexical ownership preparation;
executable Buffer/wider-wrapper body lowering remains next.
General reference/Buffer joins,
must-use, Engine/Instance ownership and complete L04/L05/D01-D04 remain open.

Windows development and release each passed 12 native groups (eight final core,
four existing regression, in separate batches) and 105 tool-free public Fuel CLI
cases on implementation `0254278`. At that checkpoint, all 203 recorded inputs
matched checkout and Git raw bytes; 182 production modules were LF. Its static
test inventory was 310
files / 1850 annotations. See the [Windows evidence](../evidence/value-ir-windows-20261107.json)
and its [input manifest](../evidence/value-ir-inputs-windows-20261107.json).
Both final core selections ran fresh, including returned proof fields and full
positive bounds. The regression and CLI manifests record that checkpoint's
production/selected fixture inputs. CLI discovery hashes predated its last core
native test expansion; that inventory was recorded separately. No runtime/CLI-fixture
input changed between those phases, and no native overrides or historical
results were used.
Local commits only; no push, release or deployment.

The private execution successor passed 26 native groups and 105 tool-free public
Fuel CLI cases per Windows development/release profile on `d025c6f`; see its
[evidence](../evidence/value-execution-windows-20261107.json).
The historical IR/CLI checkpoint above retains its separate scope.

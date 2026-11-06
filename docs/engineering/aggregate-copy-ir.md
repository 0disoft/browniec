# Independent aggregate copy IR proof

Date: 2026-11-06. Successor to the
[native byte-window proof](aggregate-copy-windows.md).

## Derived strategy

`copy_ir` derives a small Plan from the actual immutable operands and catalogs.
Neither compiler assertions, reserved bytes nor a caller-supplied strategy grant
authority. The supported value domains are scalar fixed arrays and plain nominal
records. This does not admit resource-bearing or tagged aggregate copies.

| IR operation | Independently derived strategy |
| --- | --- |
| Array COPY 34 | Direct copy into a fresh, separate owner |
| Array ASSIGN 38, distinct sites | Direct copy between independently live owners |
| Array ASSIGN 38, same site and frame | Identity candidate; native tokens must still authenticate NoOp |
| Record COPY 42 | Complete canonical snapshot into a fresh owner |
| Record ASSIGN 46 | Complete canonical snapshot, including self-assignment |
| Subrecord ASSIGN 47 | Exact nominal subtree windows, complete canonical snapshot |
| Owned array/record CALL arguments | Fresh callee activation, Direct/Snapshot respectively |

Array plans independently check exact element tag, nonzero length through 4096,
byte size through 32768, destination mutability where required, and both function
namespaces. Record plans independently replan the layout and resolve both nominal
subtrees against that same plan. Structural lookalikes do not satisfy nominal
identity. Both roots and the selected value must fit the existing 128-byte bound.
Relative offsets are checked inside their roots. Same-owner windows are classified
using checked subtraction; distinct owners and fresh reservations require the
native disjoint-storage invariant. A static ID alone never proves physical bounds.

Record range resolution now has an explicitly internal `offset_prepared` helper.
It consumes an independently planned, unchanged catalog; ordinary `offset`
continues to replan untrusted catalog inputs. The two sides of a copy reuse one
layout plan instead of constructing two plans during path resolution.

## Lifetime composition and admission

Canonical whole-Program validation checks copy metadata after catalog/function
partition validation, including reserved tails and copies in unreachable code.
Its reachable scalar/owner/loan CFG delegates all five copying operations to
`copy_ir::step`. The source must be live in the current function. A fresh
destination must be dead and cannot reconstruct an aggregate formal after drop;
assignment requires an existing writable destination. Array source reads reject
exclusive loans; destination writes reject shared and exclusive loans. Shared
source reads remain legal.

This proof composes with the existing exact owner-set joins/backedges and terminal
cleanup proof. It does not allocate a duplicate CFG, add Program fields or change
scalar definitions. `instruction` alone checks structure and strategy, not CFG
reachability; `step` consumes the canonical current live state. Complete verifier
entry points combine these checks with scalar, parameter, result and loan proof.

By-value CALL arguments use the same domain/shape/window rules, validate immutable
caller sources and exact callee formals, and keep array and record operand ranges
separate. Every callee parameter has fresh activation storage. Recursive calls
with equal static source/destination IDs therefore never become identity NoOps.
Repeated immutable arguments remain independent values. CALL result transfer and
RETURN ownership retain their existing independently checked transactions.

Ordinary, image and returned-reference admission all use this canonical verifier;
both actual VM drivers inherit the check before guest execution. Runtime storage
still derives its own byte-window proof and validates actual tokens, generations,
loans, bools and reservations immediately before publication. No dispatch API
accepts a Plan as authority or skips these native checks.

## Public behavior and verification

There is no new opcode, source feature, capability flag, guest allocation, Fuel
price or limit. Existing self-array and self-record CLI exact budgets remain
65779/409865 and 213577/557663 for ordinary/retained-marker routing respectively.

Run `python -B tools/verify-copy-ir.py --profile development --phase native`
and repeat for release. `--batch core` selects the eight new proof/execution
groups; `--batch regression` selects 22 existing window, array/record IR,
function-ownership and parameter-lifetime groups. Run each profile's `--phase cli`
serially: each rebuilds the shared CLI output and executes 28 tool-free cases.

The generic selected-aggregate destination protocol and its lifetime/overlap
integration remain open. Resource/tag whole-type copy-versus-move rules also
remain open, alongside full L04/C05/Engine/Instance/host/isolation/delivery.
Focused Windows checks do not establish full language/Fuel matrices, Linux, OOM
injection, general stack/performance bounds or clean-machine delivery.

Windows development/release each passed **30 native groups and 28 tool-free CLI
cases**. Development retains the eight new direct native core groups from this
same turn and adds 22 focused regression groups; release runs all 30 together.
No production/core fixture edits occurred after that direct core run began. Both
profiles use the same 183-path input union and implementation `a31aeb8`; 180 paths
match Git raw bytes, and three unchanged legacy tests differ only by CRLF/LF,
with both hashes recorded. All 173 production modules are LF. Discovery has 300
fixture files and 1793 tests. No historical result, compiler/linker/stack override
or wider conformance claim was used. See [Windows evidence](../evidence/aggregate-copy-ir-windows-20261106.json).

The [native aggregate-destination successor](aggregate-selected-place.md) now
captures/revalidates original whole-array and nominal-subtree destinations through
existing atomic owner/value stores. Its metadata pins no root; independent
aggregate-place IR/lifetimes, metered snapshots and both drivers/source remain open.

# Native aggregate copy-window proof

Date: 2026-11-06. Native prerequisite for the remaining generic L04 copy proof.

## Checked strategies

`aggregate_copy::relation` authenticates two equally sized half-open byte
windows against a caller-supplied, already authenticated backing limit. It uses
subtraction after checking each start, so neither a window end nor an end-to-end
comparison can overflow usize. Identical, disjoint (including adjacent) and
partially overlapping windows remain distinct. Empty windows access no bytes.

`prove` permits direct copying only for disjoint windows. An identical nonempty
window needs explicit identity evidence for `NoOp`, or a complete snapshot.
Partial overlap requires snapshot capacity at least equal to the whole value.
Snapshot wins over identity, so record self-assignment still canonicalizes
padding and checks bools. Bounds are checked before either policy exception.

These are byte-window facts, never type, owner, lifetime, loan or allocation
authority. Callers authenticate those independently. No publication API accepts
a caller-supplied Mode; each storage boundary obtains a fresh local result.
Safe Fairy C borrowing keeps the encoded record scratch disjoint from backing.

## Connected storage paths

Fresh array copy, homogeneous argument copy and mixed array/record argument copy
prove each reservation against its original source before any payload or owner
publication. Every destination follows the original published prefix; repeated
arguments cannot name another argument's provisional destination. Existing
complete-batch validation and canonical record staging remain atomic.

Whole-array assignment first authenticates writable/readable tokens, exact
element/length and the complete bool source. Only then can identical token slot,
generation and byte window skip physical copying. Active read/write leases,
stale tokens, malformed/overlapping ledgers and noncanonical bools still fail.
Separate live owners continue to copy independently into the existing extent.

Flat and nested record copy/assignment prove their bounded snapshot strategy
before staging all source fields and padding. Self and both partial-overlap
directions keep their prewrite values, including at full arena capacity. No
additional owner, backing extent or heap allocation is introduced.

Flat record preparation also now fills separate tag/offset arrays and constructs
Shape once at return. A release-only diagnostic reproduced incorrect prepared
field metadata before initialization or copying. Existing flat-copy helpers now
independently check count, scalar tags and aligned offsets before storage use.
The diagnostic probe was removed after localization.

## Cost and public behavior

For a numeric array self-assignment of N bytes, the former N byte reads plus N
byte writes become zero payload accesses after bounded owner authentication.
The 32768-byte maximum skips 65536 byte accesses. Bool sources retain their
complete canonical-value scan before skipping the redundant copy. This is an
operation-count bound, not a measured elapsed-time or throughput claim.

All existing instruction prices and limits remain. Array self-assignment still
pays its conservative existing `81+B+bool_scan`; record self-assignment retains
its existing snapshot price. There is no new opcode or public capability flag.

| Complete CLI fixture | Ordinary exact Fuel | Retained marker exact Fuel |
| --- | ---: | ---: |
| `var a=[42;1];a=a;return a[0];` | 65779 | 409865 |
| `var P p=P{.x=42};p=p;return p.x;`, P has one i32 field | 213577 | 557663 |

The marker is `let ref u8[] marker=b"*";` and selects actual retained public
routing. Tests use zero, one-short, exact and one-more budgets. Both routes also
execute bool self-assignment and a mixed owned-array/record CALL returning 42.

## Verification and frontier

Run `python -B tools/verify-aggregate-copy.py --profile development --phase native`
and repeat for release. The selection has 22 groups: three independent window
proofs, six array assignment/copy groups, six flat/nested record groups, six
homogeneous/mixed argument-copy groups and one record-owner assignment group.
The window oracle enumerates all 4913 start/start/size combinations in 0..16;
separate cases cover usize maximum, scratch shortage and identity forgery.

Run each profile's `--phase cli` serially because builds share their output
artifact. Each executes 20 cases with a cleared tool-free PATH. The runner
fingerprints its source, selected fixtures, toolchain and production modules.

General IR copy-strategy/lifetime proof, aggregate selected places, resource/tag
copy-versus-move rules, full L04/C05 and Engine/Instance/host/isolation/delivery
remain open. Native storage checks do not establish those missing contracts.
Full language/Fuel matrices, Linux, OOM injection, LF mirrors and general
stack/performance or clean-machine delivery are outside this focused selection.

Windows development/release each passed **22 native groups and20 tool-free CLI
cases**, on184 inputs matching checkout and implementation Git raw bytes. All
172 production modules are LF; discovery contains299 fixture files. No compiler,
linker or stack overrides, historical result reuse or full-suite claims were used.
See [focused Windows evidence](../evidence/aggregate-copy-windows-20261106.json).
The broader frontier and skipped scopes above remain unverified.

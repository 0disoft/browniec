# Initialize wrapper bytes once

Private retained-value `Option` and `Result` construction used to clear the
entire destination, write its tag, then copy the active payload over bytes just
cleared. Both the raw `value_codec::wrap_at` and staged native
`value_frames::build_tag` performed this redundant payload initialization.

Both paths now partition the destination into four disjoint regions: the tag
`[0,1)`, header padding `[1,A)`, payload `[A,A+P)`, and tail padding `[A+P,B)`.
The retained layout and checked child type prove `1 <= A <= A+P <= B`, where
`A` is the payload offset, `P` the active payload size (zero for `none`), and
`B` the wrapper width. Only padding is cleared. The tag and the complete
payload are written once by their existing assignments/copy. For `none`, all
inactive payload bytes still belong to the cleared tail. No byte is left stale.

## Preserved boundaries

The original preflight order, destination/source bounds, raw overlap rejection
and canonical source inspection remain. Raw rejection paths precede target
writes. Raw construction still rejects overlap with the entire destination;
this change does not admit additional aliases. Frame staging still performs
its final canonical inspection before handoff and publication, and retains
source consumption, rollback, Fuel, quotas, root accounting and cleanup.
No new public helper, state field, allocation or caller-supplied proof is added.
The retained-value execution path remains private.

## Quantitative scope

Source-level construction writes change from `B + 1 + P` to exactly `B`:
header/tail clearing contributes `B - 1 - P`, followed by one tag byte and
`P` payload bytes. Thus each successful construction eliminates `P + 1` byte
stores. A wrapper containing `i64[4096]` has `B=32776`, `A=8`, `P=32768`:

| Counted writes | Before | After | Eliminated |
| --- | ---: | ---: | ---: |
| Raw destination or native staging buffer | 65545 | 32776 | 32769 |
| Native staging plus unchanged destination publication | 98321 | 65552 | 32769 |

The second row counts a copyable array source, so source erasure does not
apply. Other operations, byte validation reads, allocation setup and cleanup
are excluded. `none` eliminates only the redundant tag zeroing (one byte);
small active alternatives eliminate only their own payload size plus one.
Both versions remain O(B) per construction and O(1) auxiliary space. These
are source operation counts, not measured native throughput or memory peaks;
compiler optimization can change executed stores. Fuel prices are unchanged.

## Focused verification

`tools/verify-value-wrap-writes.py` selects ten native groups:

- Two new groups compare the entire backing buffer, returned sizes and exact
  error variants against a frozen implementation of the original raw wrapper
  construction. Cases include alignments 1/4/8, both Result branches, some/none,
  records and their padding, bool arrays, four nested Buffer wrappers, per-byte
  mutations, invalid type/variant/bounds, overlap rejection and maximum-width
  payloads in both disjoint copy directions. Error paths preserve all bytes.
- One new native frame group dirties the staging buffer before full-array,
  small-Buffer and absent payload construction. It checks insufficient/exact
  Fuel, canonical output/tails, payload preservation, ignored none sources,
  binding handoff, unchanged root charges and zero-charge abort cleanup.
- Four existing codec groups cover tags, padding, copying and overlap; two
  existing frame groups cover inactive/active move-only alternatives and maximum
  arrays with four wrappers. One existing VM group executes repeated predicates
  with plain, nested and active/inactive Buffer wrappers.

Run `build/toolchain/fairyc.exe check`, then
`python -B tools/verify-value-wrap-writes.py --profile all`. Each native profile
uses the pinned compiler, default settings and a byte-identical input mirror.
The initial fixture compilation used an unsupported usize-to-u8 cast; it was
replaced by a bounded u8 counter before the final runs. Failed attempts are
not counted as passing evidence.

See the [Windows evidence](../evidence/value-wrap-writes-windows-20261116.json)
for final results and implementation/input identities. Full Engine transport,
public CLI, standalone memory and full release gates are outside this change.
The known legacy source failure was not retested or claimed fixed.

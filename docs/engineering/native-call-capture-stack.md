# Native stack containment for call argument prefixes

Date: 2026-11-05. Implementation: `51437c1`. This fixes one reproduced R02
compiler stack failure; complete compiler/Engine accounting remains open.

## Reproducer

An owned aggregate formal sends scalar-returning calls through capture lowering.
The former `captured_call` retained a complete 64-entry lexical Table while
recursively lowering every argument, even when no argument created a capture.

The new combined depth-32 success/depth-33 rejection fixture fails on `3160751`
through public retained compilation with native process status `-1073741571`
(`0xC00000FD`), without a valid guest trap. A locked LF baseline mirror contains
the exact Git production bytes and the byte-identical final test fixture. The
same fixture passes with the fix, using the unchanged pinned compiler and native
stack configuration. The boundary group is not split or reduced for final checks.

## Lowering

`captured_call` now evaluates the longest prefix of scalar actuals and bare
immutable array/record owners before entering the separate `captured_tail`
frame. The prefix keeps only its eight argument words and small parser scratch.
The tail owns the full lexical snapshot only when prefix evaluation has finished.
For the 32-deep prefix-only examples, simultaneous capture-table snapshots
decrease from 32 to at most one. This is a structural live-snapshot count, not a
measurement of native frame sizes, total process stack or RAM.

`call_prefix_source::stable` consumes a bare owner only after checking its exact
lexical binding, owning function, immutable catalog entry and exact array shape
or nominal record identity. A lookahead proves the following comma/close. If an
actual needs ordinary capture lowering, it returns sentinel 256 without changing
the active lexer or IR. This is source-shape dispatch before lowering, not retry
after a failed compiler or verifier.

Mutable owners, literals, paths, owned CALL results and borrowed arguments keep
the original tail evaluation, capture publication and reverse cleanup. Once a
real capture is needed, all remaining actuals use that same lexical suffix. Thus
later effects and return/propagation/break/continue still see preceding captures.
The existing special returned-reference finishers receive the complete argument
vector, including the already evaluated prefix.

No guest opcode, IR layout, ownership proof, evaluation order, runtime allocation,
Fuel price, public Fuel default/ceiling, source limit or call-depth limit changes.
Independent admission remains mandatory. There is no new allocator or compiler/
linker stack override.

## Verification

```text
python -B tools/verify-static-execution.py --profile development --selection captured-call-stack
python -B tools/verify-static-execution.py --profile release --selection captured-call-stack
```

The selection contains six new groups and all existing array-literal argument,
record-constructor argument and retained module-program groups. New groups cover
both compiler routes; depth 32 and compile-limit rejection at 33; immutable array
and record arguments in either position; and the original actual-capture catalog
boundary (14 captures succeed, 15 exceed sixteen sites including the formal and
source owner). Existing groups cover mixed values/results, early-exit cleanup,
evaluation counts/order, malformed types/arities, source-local diagnostics,
independent admission, repeated execution and the original combined scalar
depth-32/depth-33 fixture.

Final profile results and exact input identities are recorded in the
[Windows evidence](../evidence/native-call-capture-stack-windows-20261105.json).
Development and release each passed all 28 groups on the same 158 input paths,
150 LF production modules and 255-file discovery identity. Every input matches
the checkout and Git raw bytes at `51437c1`; both locked LF mirrors passed.
Development began on the final unchanged inputs before that implementation
commit; release began afterward. The verifier reads its `startingHead` field
after native execution, so the evidence distinguishes that observation from
launch chronology and identifies executed code by its complete input hashes.
Diagnostic generated-C output, intermediate prefix-only fixes and preliminary
probe runs are excluded from final profile evidence.

This increment does not prove general stack containment, complete R02 accounting,
preallocation/OOM handling, full-profile capacities, benchmarks, Linux, restricted
delivery or ABI/package behavior. Public CLI/Fuel matrices are not rerun here.
The remaining language, general references, Buffer/input, Engine/Instance,
authority/host exchange, filesystem collection and delivery work stays open.

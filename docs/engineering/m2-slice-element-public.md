# Public readonly scalar slice elements

Status: implemented and locally committed at `ec73328`. Development and release
each passed 22 native groups and 2,833 CLI cases. The
[Windows evidence](../evidence/m2-slice-element-public-windows-20261101.json)
records both profiles, 351 identical current input hashes and checked compiler,
retained CLI and matrix receipt identities.

Public `verify` and the CLI `check` and `run` commands now admit readonly
`i32`, `bool`, `i64`, `u8`, `u32` and `usize` slices formed from an existing
lexical array owned by the same function. This extends the existing slice VM
and public CLI beyond the former `u8`-only boundary.

```c
module main;
fn i32 read(ref i32[] p) {
    if (p[0] == 42) { return 42; }
    return 0;
}
fn i32 main() {
    let i32[1] a = [42; 1];
    let ref i32[] p = ref a;
    return read(ref p);
}
```

## Source and lifetime boundary

A root is introduced by an immutable `let ref Tag[] name = ref root` binding.
The root must already have the same element tag, must be an owned lexical array
in the current function, and must be an ordinary array binding. Whole ranges,
ranges with computed endpoints, open ranges, nested subranges and empty ranges
are supported. An alias must use the source slice's exact tag; tags of the same
width are not interchangeable. In particular, `i32` and `u32` are distinct
tags even though both have width four.

CALL arguments explicitly name a visible slice binding, for example
`read(ref p)`. Forwarding, recursion, repeated borrow arguments, mixed scalar,
owned array and record arguments, scalar/fixed-array/record results and `?`
propagation use the existing execution and cleanup machinery. Direct borrowing
of an array in a call such as `read(ref a)` remains unsupported; create and pass
a lexical `ref` binding.

`slice_source::root_argument` is the new owned-array admission path. It is
separate from the unchanged `text_source` argument path, which remains
`u8`-only. Readonly slices for all six scalar tags are supported, while UTF-8
predicates apply only to `u8` arrays and slices.

## Verification and execution

`verifier::inspect` and public `verifier::verify` now run the same complete
metadata, type, borrow-flow, liveness and lifetime proof for all six scalar
tags. Public promotion removes only the former non-`u8` rejection after that
proof. Malformed IR, stale or mismatched roots, invalid aliases, escaped
references, mutable borrows and invalid UTF-8 uses remain rejected.

Readonly views may be forwarded through callees, recursed on, repeated in one
call, and combined with scalar, fixed-array and record arguments and results.
The shared VM retains exact element tags and owner generations, dispatches slice
operations dynamically, and preserves the original result or error when
cleanup succeeds. Source-level exits close lexical bindings in reverse
declaration order. CALL frame leave closes borrowed roots in reverse
static-site order. Invocation abort drains the remaining pool. If cleanup
itself fails, the cleanup error is surfaced and ticket/root metadata remains
retained.

Version JSON adds `"array_slice_scalar_elements": true`; the existing
`"array_slice_parameters": true` remains present. Result schemas, selected
profile names, opcodes, Fuel prices, capacity limits and CLI limits are
unchanged.

## Fuel accounting

The existing array and slice meter is reused. Relevant read prices are:

| Element | Byte stride | Read Fuel |
| --- | ---: | ---: |
| `bool`, `u8` | 1 | 4,131 |
| `i32`, `u32` | 4 | 4,134 |
| `i64`, `usize` | 8 | 4,138 |

Length and close each cost 4,097 Fuel; subslice/open costs 65,537. For `n`
borrowed formals, CALL reserves `65,537 * (n + 1)` for frame cleanup and one
retained borrow per formal. Unborrowed calls add no reserve. The CLI still
defaults to 256 Fuel and permits at most 1,000,000; default backing preparation
alone costs 65,537, so array and slice programs need an explicit budget.

For the uniform helper below, a one-element root, local `ref` and direct
`read(ref p)` CALL cost exactly 274,593 with stride 1, 274,605 with stride 4
and 274,621 with stride 8. One less Fuel fails each case with a `fuel` error.

```c
fn i32 read(ref Tag[] p) {
    if (p[0] == FILL) { return 42; }
    return 0;
}
```

For `bool`, `FILL` is `true`; for the other tags, the fixture compares equal to
42. The existing one-byte `u8` direct-read-plus-widen fixture still costs
274,590 and is unchanged.

## Working example

`examples/slice-elements.brc` sums the two `i64` values 21 and 21 and returns
42. From the repository root:

```text
browniec check examples/slice-elements.brc --json
browniec run examples/slice-elements.brc --fuel 1000000 --json
```

Both commands exercise public admission. `run` alone executes and reports the
result under the existing `browniec.result/v1` schema.

## Unsupported forms and verification state

Mutable slices and non-scalar slice elements remain unsupported. Slice results,
escaping references, temporary roots, direct array call arguments and
UTF-8 calls on non-`u8` arrays or slices remain rejected. The existing limits
stay at eight arguments, sixteen static sites per Program, sixteen live handles
shared across one invocation, 32 frames and 128 registers in each frame's
existing partitions.
The promotion adds no heap allocation path, payload clone, JIT or GC.

Development and release each passed all 22 selected native groups: three public,
five typed-VM, five source, four typed-IR and five borrow-flow groups. The 2,833 CLI cases comprise
192 new public, 252 promoted source, 64 old public `u8`, 74 old source, 120 alias,
124 subslice and 2,007 full M1 cases. Both profiles matched 351 current input
hashes. The pinned compiler, retained CLI hashes, all six CLI matrix receipt
hashes and full M1 receipt hashes were checked against the current files before
writing the evidence record.

```text
python -B tools/verify-m2-slice-elements.py --profile development --public-elements
python -B tools/verify-m2-slice-elements.py --profile release --public-elements
```

The selection covers the new public native groups, the tool-free public CLI
matrix and full M1 CLI on Windows. It is a selected native matrix rather than a
claim that every native suite passed. Other M2 suites, Linux, M0, isolation,
packaging, allocator and timing checks were not rerun. The feature changes
source, tests and tools in local commit `ec73328`; no push, publication, packaged
release or deployment was performed.

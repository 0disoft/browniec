# Private typed readonly slice IR

Implemented at `f9bc9d6`, this private typed foundation for readonly slices makes
the element shape of a borrowed slice explicit in `ir::Program` and carries that
shape through construction, argument checking and the existing dataflow proof.
Public Brownie source and the CLI still expose readonly `ref u8[]` slices only.
Source lowering, dynamic VM adapters and cleanup for other element types remain
future work.

## Element metadata

`ir::Program` has one additional field:

```text
u8[16] slice_elements
```

Each entry is either the exact scalar element tag of a rootless borrowed site or
the zero sentinel. Formal anchors and derived sites require a nonzero scalar tag.
Owned slices keep zero because their shape comes from the rooted array catalog;
unused sites also keep zero. `ir::slice_site` treats all four slice metadata
arrays as occupancy, so a site is reusable only after every entry is zero.

The accepted borrowed element tags are exact type tags, not widths or category
codes:

| Tag | Element type |
| ---: | --- |
| 1 | `i32` |
| 2 | `bool` |
| 9 | `i64` |
| 10 | `u8` |
| 11 | `u32` |
| 12 | `usize` |

Other values, including zero, fail the scalar-tag and metadata checks for a
borrowed site. The field adds sixteen `u8` cells to `Program` metadata. It adds
no heap allocation or payload copy; this contract makes no memory or
performance measurement claim.

## Construction and inheritance

`slice_builders::parameter_typed` declares a formal slice with an exact scalar
tag. It reserves the existing parameter-register position, creates a rootless
formal anchor, and records the site/origin in `slice_parameters` and
`slice_origins`, the owning function in `slice_functions`, and the exact element
tag in `slice_elements` only after its checks pass. The existing
`slice_builders::parameter` is a `u8` wrapper that calls
`parameter_typed` with tag 10.

`slice_builders::derived` creates a rootless derived site in the same function.
It flattens the parent to the formal anchor and requires the parent, anchor and
new site to carry the same tag. The new site inherits the tag rather than
accepting another type from its caller. This prevents a derived site from
changing the element type of its borrow.

Rooted owned sites continue through `ir::slice`. An owned site requires
`slice_elements` to stay zero and takes its element type from
`arrays.elements[root - 1]` when instructions are built or verified.

## Calls and arguments

Slice arguments are still encoded in the existing CALL source range 160 through
175 and checked by `slice_parameters::argument`. The destination formal and the
source must have exactly the same element tag:

- An owned source requires the rooted array element to equal the destination
  formal tag.
- A formal or derived source requires its own tag and its anchor tag to equal
  the destination formal tag.
- The source must be live, belong to the caller and route through the existing
  borrow-site encoding.

There is no tag conversion in argument checking. A mismatch is rejected before
the argument is added to a CALL.

## Slice instructions

The existing instruction numbers and encodings are reused:

- Read (58) returns a fresh register whose type is the site's exact element
  tag. Its index remains a `usize`.
- Length (57) returns a fresh `usize` (tag 12).
- Subslice (59) requires the child and parent to have the same nonzero element
  tag, root/origin/function identity and separate live sites.
- Close (56) accepts any valid typed site and releases that site's slice loan.
- UTF-8 (55) is valid only for tag 10, `u8`. Construction rejects it for other
  element types, and the verifier independently requires byte type.

Open (54) remains an owned-root operation. A formal or derived rootless slice
arrives through CALL; it cannot be opened from an owned array in the callee.

## Admission boundary

`verifier::inspect` and `verifier::verify` both run the complete existing proof:
whole-Program metadata, register partitions, instruction types, dataflow joins
and backedges, borrow liveness and close, CALL use and function exits. Thus
`inspect` can admit a well-formed private program whose borrowed sites use any
of the scalar tags above.

`verifier::verify` then scans every Program site and rejects any site with a
nonzero `slice_origins` entry whose `slice_elements` entry is not 10. This scan
is part of verification, before VM array backing preparation, Fuel checks or
instruction dispatch. It covers the whole Program, including typed helper
signatures that the entry function never calls.

For current `u8` slices, `inspect` and `verify` have the same admission result.
For a non-`u8` borrowed site, `inspect` can prove the private IR while `verify`
rejects execution admission.

## Public boundary

Brownie source and the CLI accept `ref u8[]` slice declarations and arguments.
No typed source syntax is added by this foundation. There is no new version
flag or capability flag, no new opcode and no Fuel or pricing change. Existing
limits remain sixteen static slice sites, eight formal arguments and 32 live
frames.

The next implementation step is source lowering for typed slice declarations.
Dynamic VM adapters and normal/error cleanup for non-`u8` elements must be
completed before any public promotion. Mutable slices, slice-returning
functions, escaping references and arguments whose root is temporary remain
unsupported.

## Verification

Development and release each passed 28 native groups:

- 4 `slice_elements` groups
- 4 `slice_parameters` groups
- 5 `slice_builders` groups
- 4 `slice_borrow_ir` groups
- 5 `slice_borrow_flow` groups
- 6 `slice_lifecycle_vm` groups

Each profile also passed 402 CLI cases: 64 public slice parameter cases,
74 source/limit cases, 120 alias cases, 124 subslice cases and 20 unsupported
non-`u8` boundary cases. Both profiles used 345 identical current input hashes.
Both CLI binaries were retained and identity-checked.

Verification commands:

```text
python -B tools/verify-m2-slice-elements.py --profile development
python -B tools/verify-m2-slice-elements.py --profile release
```

The [Windows evidence](../evidence/m2-slice-elements-windows-20261101.json)
records the completed results. Full native, M1 and other M2 suites, Linux, M0,
isolation, packaging, allocator and timing checks were not rerun.

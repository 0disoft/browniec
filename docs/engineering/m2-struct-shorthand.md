# Record field shorthand

## Scope

This slice implements the L03 record-constructor field shorthand only:

```brownie
struct Point { i32 x; i32 y; }
fn i32 main() {
    var i32 x = 20;
    var i32 y = 22;
    let Point p = Point { .x, .y };
    return p.x + p.y;
}
```

`.field` is shorthand for `.field = field`, where the initializer name is
resolved in the lexical scope at the constructor. Scalar and mixed explicit/
shorthand members use the existing constructor walker:

```text
.FIELD                         // same-name lexical value
.FIELD = SCALAR_EXPR           // existing explicit scalar form
.FIELD = CHILD_TYPE { ... }    // existing inline child constructor
.FIELD = CHILD_BINDING         // existing whole child-record copy
```

All fields remain complete and in declaration order. A trailing comma before
each closing `}` remains optional.

## Lowering

`struct_value_source::next_leaf` recognizes `.FIELD` followed by `,` or `}` and
retains the field token. `compiler::record_constructor_value` restores that token
and uses the ordinary scalar expression path for a scalar field. The resulting
value is written to the field's staging slot before the next member is evaluated.
The usual exact-type check then compares the expression tag with the declared
field tag.

For a plain-record field, the same token is handed to the existing
`struct_value_source::stage_child` path. That path reads each child leaf in
declaration order into the parent's existing scalar staging slots. It allocates
no temporary child record owner. The root is initialized with one `SINIT` after
all fields have been staged and validated.

Consequently, scalar shorthand is snapshotted at its source position. A child
record shorthand snapshots its leaves at its source position before later sibling
expressions run. Mutating the source local or record after construction does not
change the constructed destination. Separate constructors therefore receive
independent record values through the existing record allocation and copy paths.

The shared helper covers declaration initializers, nested constructors, call
arguments, whole-record replacement, and record returns that already route
through `record_constructor_value`.

## Rejections

The implementation continues to reject:

- members out of declaration order, duplicate members, or a missing field;
- shorthand whose lexical local is missing;
- a scalar shorthand value whose type differs from the declared field;
- a record shorthand whose source binding is not the field's exact nominal
  record type;
- dotted or computed shorthand such as `.pair.x`, and any token other than `=`,
  `,`, or `}` after a member name;
- positional shorthand, omitted-value syntax, and rest syntax.

Existing explicit constructors, inline child constructors, and whole child
bindings retain their behavior. Record layouts, field order, IR opcodes, and VM
ownership recipes are unchanged. Existing source limits still apply, including
16 staged scalar leaves, 16 fields per record, and the existing nesting and site
bounds.

## Implementation and tests

- `src/struct_value_source.fy`: shorthand marker/restore support in the
  constructor cursor.
- `src/compiler.fy`: shorthand handling inside `record_constructor_value`.
- `tests/m2/struct_shorthand.fy`: four focused groups cover all scalar field
  types and mixed members, plain-record leaf copying and independence, call/
  assignment/return use, and rejection cases.

The standalone checker `tools/check-struct-shorthand.py` covers 36 check/run
cases, including missing/duplicate/dotted members and later sibling expressions
that mutate the source scalar or child record. The constructed value retains the
snapshot from its own member position. It runs with an empty tool PATH and checks
the public `struct_field_shorthand` version capability.

Validation uses fresh Windows native constructor groups and development/release
standalone CLI artifacts. Other private returned-view/native suites, full M1/M2,
Linux, restricted delivery, DLL/ABI, allocator and performance checks remain
outside this increment. Array element-list construction remains the open part
of L03; record shorthand does not complete the whole language profile.

## Source bytes and the root lock

The Fairy C source digest includes source bytes. The development workspace had
23 CRLF production files even though Git stores and checks them out as LF. A
mirror containing the Git LF source therefore rejected the old root lock as
stale. Production sources are now LF and the root lock is regenerated from those
bytes. A separate LF mirror with the same manifest and lock passed `check
--locked`. This changes source identity, not Brownie syntax or VM prices.

Final validation uses the LF sources and refreshed lock. Earlier exploratory
pre-normalization native/CLI runs are excluded from its totals. Preserve LF when
writing source; do not regenerate this lock from a mixed-line-ending workspace.

Final Windows development passed **21 native groups** (four shorthand, six
constructor return, six root replacement and five child-path groups). Release
passed the four shorthand native groups. Both profiles passed **362 tool-free
CLI cases** (36 shorthand, 144 constructor return, 99 replacement and 83 child
path). All 507 captured inputs match across profiles; all 113 production sources
are LF. No native result reuse or stack/compiler override was used. See the
[retained evidence](../evidence/m2-struct-shorthand-windows-20261104.json).

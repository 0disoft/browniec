# M1 Direct Scalar Functions

- Status: implemented; function/local, branch, and loop receipts are historical; tagged slice verified
- Scope: direct scalar/wrapper functions and VM calls in the experimental scalar profile

## Source contract

A source file starts with `module main;` and declares one or more functions:

```text
fn TYPE NAME(TYPE PARAM, ...) { BODY }
```

Exactly one `main` must exist, take zero arguments, and return i32. Other functions
may return i32, bool, or an admitted shallow Option/Result type and may take those
types as parameters. There are no implicit scalar conversions. Constructors receive
their wrapper type from the parameter or result context. Declarations may precede or
follow their callers. Direct and mutual recursion are admitted; structured branches
can now provide conditional base cases. Every function body is checked, including
functions that are never called.

Arguments evaluate once from left to right and pass independent scalar or wrapper values.
Parameter bindings are immutable; copy a parameter into a var to update a local.
Locals belong to one function and cannot access a caller's bindings. Duplicate
functions/parameters and invalid arity or annotations are rejected. A local may
shadow a function name, but that scalar local cannot be called. Functions are not
first-class values. Indirect calls, variadics, default arguments, and trailing commas
are not admitted. See [bool and branches](m1-branches.md) for branch control,
[loops](m1-loops.md) for loop control and header call restrictions, and
[tagged values](m1-tagged.md) for shallow Option/Result parameters and returns.

## Compiler and private IR

A bounded signature pass gathers names, parameter spans, body spans, and the entry.
A second pass compiles bodies into disjoint instruction and value-register ranges.
The 1024-token ceiling applies to the complete source in the signature pass; each
body is then re-read within the same bounded snapshot. Function lookup is bounded.

Existing opcode meanings stay unchanged. CALL is eight bytes `9,dst,target,site,0,0,0,0`.
The private Program owns function ranges/arities and call-site argument register
lists. Parameters occupy the first registers of each function's range. There is
still no externally supplied bytecode or persistent runtime code cache.

The verifier validates the complete function directory before decoding instructions.
It reconstructs definitions independently for each function, admitting only its
parameters as initialized on entry. Forward CFG joins intersect definite
initialization, and unique values remain separate from typed `var` slot stores. All
reads and writes must remain in that function's register range. A CALL must bind a
valid target and unique call-site, match the callee's arity and scalar types, read
initialized caller registers, and have canonical unused argument bytes. Every
reachable path in every function must return the declared type. All functions are
verified before any guest code executes.

## VM frames, limits, and Fuel

Guest calls use a flat VM-owned register array, saved PCs, and return destinations;
they never recurse through Fairy/native calls. Return copies one canonical i32 or
bool result to the caller. Sibling calls may reuse frame storage because verified
code cannot read an uninitialized register. The Program is read-only and reusable
across fresh runs.

Limits: 16 functions, 8 arguments per function/call, 32 static call-sites, and 32
live frames including the entry. The 128-register ceiling is global across the
Program, not per function, and includes typed `var`, short-circuit, and wrapper slots.
At most 64 bindings may be simultaneously visible in a function, including
parameters. Source bytes, tokens, constants, instructions, structural parser depth,
expression depth, and loop depth keep their existing limits. The VM reserves 4096
scalar slots for its bounded frames; this is not an accounted-memory or process-RAM
measurement.

Every ordinary instruction/return costs one Fuel; CALL costs one plus its argument
count. The same remaining Fuel spans the entire call tree. Fuel preflight happens
before the frame-capacity check. An attempted 33rd frame returns `frame_limit`, a
guest quota outcome with process exit 5. It does not publish a return value.

## Evidence and remaining work

The [function receipt](../evidence/m1-functions-windows-20261023.json) is historical
evidence for forward/nested calls, value and scope isolation, left-to-right failures,
recursion/Fuel/frame boundaries, function/call-site ceilings, and corrupted private
call metadata. It does not cover bool returns, structured branches, slot joins, or
the branch verifier.

The branch receipt records the historical 20-group/248-case branch slice, and the
loop receipt records the historical 26-group/332-case loop slice. The current
[tagged receipt](../evidence/m1-tagged-windows-20261023.json) records 33 native
groups and 423 black-box CLI cases for each development and release
profile, including wrapper parameters and returns, constructors under call context,
and call regressions across scalar and tagged values. Full M1, `?` propagation,
workers, DLL ABI, clean-machine distribution, and performance targets remain
unverified. M0 inputs are unchanged and were not rerun.

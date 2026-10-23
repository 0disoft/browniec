# M1 Direct i32 Functions

- Status: implemented; native validation recorded in the dated function receipt
- Scope: direct functions and VM calls in the experimental scalar profile

## Source contract

A source file starts with `module main;` and declares one or more functions:

```text
fn i32 NAME(i32 PARAM, ...) { STMT* return EXPR; }
```

Exactly one `main` must exist and take zero arguments. All parameters and results
are i32. Declarations may precede or follow their callers. Direct and mutual
recursion are admitted, but this slice has no branches or conditional base cases.
Every function body is checked, including unreachable functions.

Arguments evaluate once from left to right and pass independent scalar values.
Parameter bindings are immutable; copy a parameter into a var to update a local.
Locals belong to one function and cannot access a caller's bindings. Duplicate
functions/parameters and invalid arity or annotations are rejected. A local may
shadow a function name, but that scalar local cannot be called. Functions are not
first-class values. Indirect calls, variadics, default arguments, trailing commas,
branches, and tagged values are not admitted.

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
parameters as initialized on entry. All reads and writes must remain in that
function's register range. A CALL must bind a valid target and unique call-site,
match the callee's arity, read initialized caller registers, and have canonical
unused argument bytes. Every function ends in exactly one return. All functions
are verified before any guest code executes.

## VM frames, limits, and Fuel

Guest calls use a flat VM-owned register array, saved PCs, and return destinations;
they never recurse through Fairy/native calls. Return copies one i32 result to the
caller. Sibling calls may reuse frame storage because verified code cannot read an
uninitialized register. The Program is read-only and reusable across fresh runs.

Limits: 16 functions, 8 arguments per function/call, 32 static call-sites, and 32
live frames including the entry. The 128-register ceiling is global across the
Program, not per function. The existing 64-binding limit includes parameters within
each function. Source bytes, tokens, constants, instructions, and parser depth keep
their existing limits. The VM reserves 4096 scalar slots for its bounded frames;
this is not an accounted-memory or process-RAM measurement.

Every ordinary instruction/return costs one Fuel; CALL costs one plus its argument
count. The same remaining Fuel spans the entire call tree. Fuel preflight happens
before the frame-capacity check. An attempted 33rd frame returns `frame_limit`, a
guest quota outcome with process exit 5. It does not publish a return value.

## Evidence and remaining work

The [function receipt](../evidence/m1-functions-windows-20261023.json) records the
compiler, source, native artifacts, test identities, and black-box corpus digests.
Validation covers forward/nested calls, value and scope isolation, left-to-right
failures, recursion/Fuel/frame boundaries, function/call-site ceilings, and corrupted
private call metadata. M0 inputs are unchanged and were not rerun. No worker, DLL,
full M1 conformance, clean-machine distribution, or performance target is claimed.

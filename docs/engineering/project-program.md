# Retained native project programs

Date: 2026-11-05. This connects admitted project metadata and exact native source
binding to a retained, reusable executable. It advances L01/C03 and preserves
the remaining filesystem, CLI and host-authority obligations.

## Admission and ownership

`project_program::compile` consumes an owning `project_manifest::Project` and an
owning `module_entry::Entry`. It accepts no caller-provided executable proof or
scope hints. An independently selected Entry must pass `project_sources::verify`
again: exact source identities, source count, every canonical module header and
the exact selected named public i32 entry must match the retained metadata.
Matching source order is unnecessary; substituting another path, header or
public function fails before body compilation.

The existing module compiler then reconstructs scope from that exact immutable
Index and performs complete body/type/ownership and independent IR/image
admission. Unused invalid bodies fail too. No project path bypasses that proof
or falls back to a different compiler, execution profile or Fuel schedule.

Successful publication retains the complete original Project, including every
declared requirement, beside its module Program. The private
[typed module owners](native-module-retention.md) keep large source/index/code
payloads out of nested owning return slots. Project accessors expose only shared
metadata/source borrows and the admitted profile. No mutable code, grants,
guest references or native tickets escape.

Binding failures retain the module error domain and original source-local span.
Compilation/runtime failures retain the existing module diagnostic. Global,
allocation and image-quota failures have no fabricated source location. Inputs
are consumed on success and failure; callers needing source identity lookup
after a failed compile must retain their original host input mapping separately.

## Invocation and authority

`run` borrows the entire retained project and uses fresh existing VM state on
each invocation. Fuel exhaustion or arithmetic failure does not mutate the
admitted executable; the same project can run again with another budget.
Original runtime error spans refer to its retained exact source snapshot.

Requirements remain declarations. There is no policy/grant argument or host
registration in this API yet. Consequently a nonempty requirement list returns
the typed `Requirements` failure and existing unavailable diagnostic code 11
before guest execution, backing preparation or Fuel consumption. It grants
nothing and does not discard requirements to make execution succeed. Policy
ceilings and explicit grants remain separate work.

The source map still accepts 32 metadata rows while native compilation retains
its explicit 16-file/4096-source-byte limits. No truncation occurs. Public Fuel
default 256, CLI ceiling 16000000, host-selected native budgets and all operation
prices remain unchanged. No project CLI flag or delivery capability is enabled.

## Verification

```text
python -B tools/verify-static-execution.py --profile development --selection project-program-core
python -B tools/verify-static-execution.py --profile release --selection project-program
```

The core selects seven new project-execution groups and all seven existing
project-source groups. The integrated selection adds six module-index and ten
module-program groups. Tests retain the combined 16/17-file binding case and
both combined legacy/reference depth-32 success and depth-33 rejection cases.
No compiler/linker stack override or reduced capacity is permitted.

New groups check owned metadata and original sources, repeated execution,
requirement denial at zero and sufficient Fuel, independent wrong-entry/path
binding, complete unused-body admission, source-local compile/runtime failures,
retry after Fuel exhaustion and actual literal/shared-byte module results.

Implementation `83370c1` passed 14 focused development groups and all 30
integrated release groups. The final development input set (155 paths) is an
exact subset of the release set (157 paths); all match current checkout and Git
raw bytes. Both use 149 LF production modules and the same 254-file discovery
identity, and both locked LF mirrors passed. The earlier retention foundation's
16 development groups used its own 253-file snapshot; they were not reused as a
final-input development result. All sixteen identities also pass in the final
integrated release run. No compiler/stack overrides or historical-result reuse
were used. See the [focused Windows evidence](../evidence/project-program-windows-20261105.json).

Diagnostic probes and the initial exhaustive-enum fixture failure are excluded.
Public CLI/Fuel/full profiles, Linux, allocator fault injection, general memory/
stack/timing measurements and delivery/ABI/package checks were not rerun.

Anchored filesystem collection, public project loading, policy/grants, guest
Buffer/input, Engine/Instance, restricted worker, ABI/package and complete
profile/platform evidence remain open.

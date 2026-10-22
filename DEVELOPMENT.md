# Development

- Status: workflow designed; no executable toolchain configured
- Current repository content: documentation only

## Current reality

There is no build file, package manifest, source tree, test runner, or installed
browniec command in this repository. Do not invent a toolchain version, dependency
file, build command, or passing test result.

The first implementation work must begin with a small native feasibility probe. M0
must record the actual Fairy compiler, SDK, Windows SDK, and optional C shim versions
that are available. Those observations become a dated build record, not a permanent
version freeze.

## Bootstrap versus runtime

The fairyc toolchain may use Go to build the compiler or stage-0 infrastructure.
That does not make Go part of the produced Brownie VM.

The finished native executable must:

- start on a machine without a Go runtime;
- accept Brownie source directly;
- avoid launching MSVC, clang, gcc, Go, or another compiler while compiling or running;
- load no external bytecode or disk runtime code cache.

Build-machine prerequisites and end-user runtime prerequisites are separate records.
Clean-machine validation belongs to the packaging milestone.

## Working sequence

1. Confirm the smallest actual native signatures and failure returns.
2. Run the M0 probes for arithmetic, codec, storage, quota, and generations.
3. Build one scalar source-to-VM path before broad language support.
4. Add arrays, structs, borrows, Buffer, and text through small end-to-end cases.
5. Add typed host suspension only after the pure path is stable.
6. Add Windows process isolation before exposing the restricted delivery level.
7. Add DLL export and clean-machine packaging before exposing embed delivery.

M0 and M1 are not blocked by the later Windows worker or DLL milestones.

## Command inventory

No project command is currently runnable. The proposed `browniec check`, `run`,
`inspect`, and `worker` commands, with `--project` and `--isolated` options where
applicable, describe intended CLI behavior only.

Documentation review may use repository-neutral tools such as a Markdown link check
or git diff --check when the parent task supplies them. These checks do not execute
the language or prove a runtime contract.

## Build and cache hygiene

The default retained output should be the final binary, the embed DLL when available,
and a small build receipt. Generated C, objects, response files, and link scratch
should be removed after success.

Failure diagnostics may be retained only in a bounded explicit bundle. Caches need a
size limit, eviction, and invocation-specific scratch files. Do not create idle
pollers, garbage-collection cycles, or background cache maintenance.

Developer toolchain installs, fairyc Go build caches, Brownie project outputs, OS page
cache, process memory, and VM ledgers are different measurements and must stay labeled.

## Dependency changes

Prefer existing project-owned or platform capability. Record the need, alternatives,
license, consumer impact, and removal path before adding a dependency.

Use major-version ranges and reproducible locks or build IDs for compatible updates.
Promote a new major only after a narrow compatibility check. Pre-stable Fairy
semantic changes require explicit source corpus review.

## Evidence handoff

Every milestone result should name the artifact, environment, commands, observed
result, skipped checks, and remaining risk. A failed probe stays failed; a missing
compiler is skipped, never passed. See VALIDATION.md and docs/design-baseline.md.

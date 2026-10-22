# Validation

- Status: Draft

## Validation Source of Truth

This document owns stable validation names for this scaffold.

## Standard Validation Names

- format
- lint
- typecheck
- test
- contract
- migration-check
- smoke
- docs
- check

## Required Final Report

Final responses must list executed validations, passed validations, skipped validations, skip reasons, and remaining risk.

## Runner Policy

Task runner files are optional. Runner `none` means no executable task runner is generated.
If a runner is generated, runner command names must match this document.
Unconfigured runner commands must fail, not pass with a fake success.

## Hygiene Validation

Repository hygiene file changes must check line-ending churn, binary diff pollution,
tracked secret files, ignored build/cache artifacts, and generated-output drift.

## Scope

general validation routes must stay stack-neutral unless a runner file explicitly defines a command.

## Repository Shape

cli-tool validation must stay repository-shape focused and must not imply generated application source code.

## Task Validation Guides

Select the relevant guide for affected contracts and failure paths. This list reflects the guides generated for the selected scope, repository type, addons, and density. Stable names and runner routing remain governed by this document. Update the list when the project retires or replaces a guide.

- [Default Validation](.agents/validations/default.md)
- [Ops Change Validation](.agents/validations/ops-change.md)
- [Dependency Upgrade Validation](.agents/validations/dependency-upgrade.md)
- [CLI Tool Validation](.agents/validations/cli-tool.md)

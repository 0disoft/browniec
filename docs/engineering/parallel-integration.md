# Composed native integration checkpoint

Independent language, host catalog and ABI-coordinator changes were reviewed and
applied serially after `git apply --check`. The root source lock was refreshed
after each Fairy source integration. No worker edited root files or the separate
Fairy compiler checkout. Local implementation commits are:

| Slice | Commit | Focused evidence |
| --- | --- | --- |
| Public IR inspection | `2b44bf9` | 19 CLI cases plus version/help per development/release profile |
| Catalog admission and canonical SHA-256 | `41144d7` | 12 native groups per development/release profile |
| Fresh anonymous loop owners | `cbdfdbe` | 11 native groups per development/release profile |
| Real lazy internal registry coordinator | `8a4dae9` | Four actual C-host scenarios per development/optimized profile, three builder rejection controls |

These increments retain their exact native snapshot identities. New root modules
and unrelated CLI version output do not retroactively become worker-tested
inputs. The owning evidence records input differences and checks matching
dependencies; no full-suite pass is inferred from a sum of group counts.

`python tools/verify-parallel-integration.py --profile release --cli-smoke` checks
the actual composed root snapshot. It runs four selected native groups: populated
fresh loop-carried Buffer ranges/continue, pinned native MOVE identity and failure
drain, admitted catalog tags through the actual TLV codec, and the unchanged
combined admitted32/rejected33 depth fixture. It then builds the root release CLI
with the same lock and runs three tool-free cases: scalar IR inspection, retained
byte-literal IR inspection and an ordinary aggregate execution returning 42.

The final receipt hashes every production module, selected test, manifest, lock,
toolchain and integration verifier. CLI smoke requires those inputs to remain
unchanged through build/execution. Native and CLI tests use default stacks and no
compiler/linker overrides. They do not replace the feature-specific cases.

The ABI coordinator uses only its eleven frozen isolated build inputs; it does
not import root VM/CLI/value modules. Integration checks those bytes and compiler
against the actual two-profile C-host receipt rather than rebuilding unrelated
modules or rerunning unchanged generation-exhaustion kernel tests.

No public Buffer/host/Engine/Instance or restricted/embed availability follows.
Conditional fresh-root unions, complete Program catalog binding and host exchange,
actual lifecycle/pins/accounting/steps/cancellation, production registry scale and
the remaining language/platform/delivery inventory are still open. See the
[authoritative inventory](../product/04-remaining-work.md).

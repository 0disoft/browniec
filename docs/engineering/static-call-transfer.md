# Static CALL descriptor transfer

Date: 2026-11-05. This follows [complete Static CALL analysis](static-call-admission.md).
The first increment supplies unpublished argument and return plans plus PARAM
activation checks. Canonical VM integration remains the next increment.

`static_call_execution::arguments` checks each live caller word against its
proved kind and image roots and the corresponding future PARAM destination.
Its sixteen-word plan starts cleared and preserves each actual packed span.
Logical scalar prefixes and repeated shared actuals retain their positions.
It never copies payload or changes caller/frame state. PARAM validates its
already-staged word before the driver may publish the corresponding live bit.

`returned` validates the sole selected live word, the exact caller CALL,
callee/function/kind, fresh result site and recipient image window. Native leave
must still succeed before the driver can publish that plan. These helpers require
complete independent proof and a borrow of the same image; neither plans nor
words pin or authenticate storage on their own.

The first metadata plan charges 16+16*N for at most eight Static actuals;
PARAM and return validation each charge 16. These exclude dispatch and native
entry/leave/copy reserves, which canonical integration must preflight together.
They are abstract bounded-work prices, not timings or machine instruction counts.
No runtime/public capability is enabled by the helper increment.

Run `python -B tools/verify-static-execution.py --profile development --selection
call-transfer-core` and repeat for release. Both Windows profiles passed four
native groups on 134 matching inputs, with 129 LF production modules, locked LF
mirrors and the same 230-file discovery identity. The tests cover real independently
proved byte/text recipes, narrowed spans, exact text windows, full/one-short
budgets, parameter replay, recipient/liveness failures, scalar prefixes and all
eight shared arguments. No compiler/stack overrides or historical reuse.
See [focused evidence](../evidence/static-call-transfer-core-windows-20261105.json).
No VM/CLI/full-profile, general stack/RAM, allocator/timing, Linux, restricted,
ABI or package checks are claimed by this increment. Actual frame/image transfer,
native ownership restoration, source CALL lowering and public promotion remain.

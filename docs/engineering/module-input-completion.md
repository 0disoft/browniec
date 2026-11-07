# Exact input invocation completion

`module_input_program::complete(program, snapshot, fuel)` returns a terminal
`Completion { success, value, remaining, diagnostic }` for the real invocation.
The preserved `run` API delegates to it and retains its former Result interface.
No invocation is replayed to derive consumption or reconstruct an error.

The canonical input coordinator shares a mutable meter through preparation and
dispatch. Each committed debit survives a later Result error: array preparation,
input metadata, list/place setup, root entry, instruction dispatch, staged CALL
arguments and staged RETURN work. An atomic helper publishes its new balance on
success; its unsuccessful uncommitted price is not charged. Earlier independent
debits remain visible. Abort and metadata destruction use prepaid work and do
not consume additional guest Fuel. All successful existing prices are unchanged.

This matters when a guest divides by zero, reads beyond its actual input, builds
an invalid range or exhausts Fuel partway through a CALL/return transaction.
The first original-source diagnostic and the actual committed remainder are
returned together, including preflight failures that preserve the initial budget.
It does not complete full Engine work accounting, resumability or deadlines.

Run `python tools/verify-module-input-completion.py`. The seven new native groups
have independent numeric price oracles for preflight/dispatch/PARAM, exact return,
nested returned input, division/read/range errors and CALL staging. Sixteen
unchanged input/module/reference/depth regressions include the complete combined
32/33 fixture. Both development and O2 passed all 23 isolated groups with default
1MiB/4KiB PE stacks, no compiler environment overrides and the pinned compiler.

The [evidence](../evidence/module-input-completion-windows-20261107.json) explicitly
reuses the executed ignored-mirror results after all 194 code/test/tool inputs
matched checkout bytes. Root `fairyc check` refreshed the lock after integration;
no unchanged broad CLI/language or other-platform suites were rerun. The private
[Engine input path](runtime-engine-inputs.md) consumes this completion directly.

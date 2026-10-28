# Native Buffer close accounting

Implemented and verified in development and release. See the
[Windows receipt](../evidence/m2-buffer-close-windows-20261029.json).

`buffer_close` connects [descriptor retirement](m2-buffer-owners.md) with final
[Buffer usage accounting](m2-buffer-growth.md). It provides an irreversible
begin/finish protocol, not automatic resource destruction or guest VM cleanup.
Source syntax, VM instructions, Fuel prices and capability flags are unchanged.

## Begin, destroy, finish

The trusted caller must serialize these three steps for one owning native root:

1. Call `begin` with its token, native root, table, ledger and an inactive Plan.
   Identity/table validation precedes native metadata access. Length/capacity must
   match the descriptor. Accounting must be consistent, cover capacity plus 64,
   and contain no pending growth or residual transaction fields. Cleanup uses
   representable accounting ceilings, so a reduced policy limit does not itself
   prevent release of an already-admitted allocation.
2. Begin precomputes descriptor release, then invalidates the token and activates
   a Plan containing the entire resulting table snapshot, all nine ledger fields,
   source identity, old capacity and charge. Usage is still fully charged. MAX
   generation becomes zero and retires its slot; other generations advance once.
   There is no fallible operation after invalidation. The original token is
   unusable even while the caller still holds the native root for destruction.
3. Drop the owning root, then call `finish`. It checks exact table/ledger snapshots,
   capacity/charge arithmetic and the expected retired slot before subtracting
   the charge from Instance and Engine usage. Observed peaks and pending fields
   remain unchanged. The Plan becomes inactive. Duplicate finish returns State.

For old capacity 256 containing `keep`, begin holds Instance/Engine usage at
320/352 while invalidating its token. After native destruction, finish yields
0/32, preserving earlier peaks. An empty root holds 64/64 until finish returns
0/0, retaining peaks 64/64. Zero remaining Instance usage does not re-admit a new
empty owner: any later root needs separate admission.

The returned logical owner charge is occupancy accounting, not evidence that the
fixed descriptor table was physically freed. Native payload cleanup occurs in
the caller's scope destruction. The fixed table and Plan still have storage and
must be admitted separately in a future Instance implementation.

## Failure and trust boundary

Before successful begin, errors preserve the root, descriptors and ledger. After
begin, retirement is one-way; there is no cancel or token resurrection. Forgetting
finish retains the charge. A changed table (including another vacant slot's
generation) or any changed ledger field rejects finish without decrementing usage.
This conservatively retains usage if completion cannot be established.

The compiler does not support whole resource replacement through a mutable
reference. Consequently this API cannot drop the caller's native root, prove
that destruction happened, or prevent finish being called too early. The caller
must bind the correct root, preserve exclusive access, avoid slot reuse or other
metadata/accounting mutations between phases, and finish only after destruction.
Root destruction and accounting are not one atomic operation. Multiple overlapping
close Plans are unsupported; close roots sequentially.

Plans and tables are private mutable native data, not sealed guest capabilities.
Consistent forged snapshots, wrong matching roots/tables, copied Plan replay and
cross-Instance identity are outside this boundary. No guest borrow enforcement,
automatic finalization or whole-Instance error cleanup is introduced here.

## Focused verification

The shared Windows probe runs four close scenarios plus nine append/allocator
regressions in each profile through `tools/verify-m2-buffer-failure.py`:

- Successful retirement before native scope exit, final charge release afterward,
  duplicate begin/finish rejection, retained Engine background usage, and an
  additional empty-root close without allocation.
- Invalid identity/backing, malformed table, insufficient accounting and a real
  pending growth reservation rejected before retirement; cancellation of that
  reservation then permits close.
- Native root destruction followed by changed ledger/other-slot rejection,
  malformed capacity/charge rejection without arithmetic traps, fixture repair
  and successful finish without a partial decrement.
- MAX generation retirement to zero without wrapping and final usage release.

Every close process reports one allocation attempt for its initial 256-byte root,
one final free and zero outstanding allocations at the instrumented FY heap seam.
The empty-root subcase adds no allocation. The fixture places finish after the
root's lexical scope; the counters establish tracked cleanup rather than prove
ordering for arbitrary callers or whole-process absence of leaks.

Both profiles passed all 13 scenarios. The archive rechecks 13 selected inputs,
seven generated sources, SDK lock and both retained executables. Profiles ran
from `27a0a7b` with the increment uncommitted; hashes identify the tested sources.
The previous 31 native groups and CLI sentinels, full suites, M0, Linux, isolation,
DLL embedding, packaging, Provider injection and elapsed-time performance were
not run. Earlier receipts remain historical for their original inputs.

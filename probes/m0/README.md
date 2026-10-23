# M0 Native Probes

- Status: implemented and verified on Windows x64; native primitive scope only
- Scope: native primitive feasibility, not `.brc` source execution

M0 checks the smallest Fairy C boundaries needed before Brownie language work. The
separate [M1 slice](../../docs/engineering/m1-scalar-slice.md) now implements a scalar
source CLI/VM. These probes do not establish that pipeline, worker, DLL, or full profile.

## Build and run

From the Brownie C repository root:

```powershell
Push-Location ../fairyc
go build -mod=readonly -trimpath -o ../browniec/build/toolchain/fairyc.exe ./cmd/fairyc
Pop-Location
pwsh -NoProfile -File tools/verify-m0.ps1
```

The harness builds development and release variants, runs both with an empty runtime
`PATH` and cleared environment, and checks the four negative fixtures. It validates
the requested compiler checkout against the compiler build identity; the M0 source
and SDK versions are a dated record, not a permanent pin.

## Observed native contract

The public Buffer operations used by the probe are:

```text
bytes::with_capacity(usize) -> Result<Buffer, BufferError>
bytes::append(ref mut Buffer, ref u8[]) -> Result<usize, BufferError>
bytes::view(ref Buffer) -> ref u8[]
```

Storage uses `plan`, `prepare`, `commit`, and `cancel`. Planning chooses either the
preferred 1.5-times growth rounded up to 64 bytes or the minimum rounded requirement
when that preferred size exceeds an object, Instance, or Engine limit. Preparation
requests exactly the planned capacity with `Buffer.with_capacity`; it must not rely
on provider reserve/doubling behavior. Accounting keeps the old and new capacities
plus both owners' 64-byte logical charges at peak.

Prepare retains the old owner while allocating the replacement. After the caller
replaces its root and drops the old allocation, it calls `commit`. If the prepared
replacement is abandoned, the caller drops it before `cancel`. This lifetime ordering
is trusted; the probe ledger does not enforce it. The ledger counts logical owner and
payload bytes, not process RAM. These quotas and owners are Brownie-owned M0 probe
primitives; they do not change Fairy language semantics.

Arithmetic keeps results in wide registers: signed i32 and i64 use `i64`, while u8,
u32, and usize use `usize`. Width and overflow failures return `Result`; the probe
does not narrow an intermediate and call that checked arithmetic. The i64 codec is
full signed two's complement in exactly eight little-endian bytes. The usize codec is
also exactly eight bytes and covers `usize::MAX`.

The owner table's four slots are a test fixture bound, not a production capacity
policy. Stale, free, reused, and retired-maximum generation tokens are rejected before
payload access. The owner check frees a function-local real Buffer before using a
token from it; a stale read against an empty Buffer returns an error and leaves the
payload read counter unchanged. Scalar array frames copy on assignment and function
pass, while exclusive views update the owning frame.

The allocator probe forces a target allocator to return `NULL` for a 320-byte request with the test-only
`native/allocator_probe.h` header included through `cl`. Header exit checks require no
leaked target heap allocations. This is allocator evidence, not a long-running memory
safety or packaging proof.

## Evidence

The expanded run passed six native executions: development and release normal
baselines, development and release instrumented normal runs, and development and
release instrumented allocator-failure runs plus leak checks. Four negative compiler checks
produced the expected diagnostics:

| Fixture | Diagnostic |
| --- | --- |
| use after move | `E1101` |
| grow with a live shared view | `E2101` |
| escape a local view | `E2102` |
| exclusive alias | `E2101` |

Selected source was Fairy C `4ce1264273be6051ee560173e94690e1b99c9eaf`, SDK
`0.0.0-stage0.86`, and language `fairyc-language/20`, targeting Windows x64 with MSVC
tools `14.51.36231`, `cl` `19.51.36248.0`, Windows SDK `10.0.26100.0`, and Go
`1.27.1`. The compiler was built from a clean fairyc checkout with SHA-256 build
identity
`572395f7f1e425d613c5a69f50b30ed177cda37ca2b1638bd0c11cf79fcbcc77`.

Exact command transcripts and artifact details are in
`build/m0/receipt.json` and the dated
[`docs/evidence/m0-windows-20261023.json`](../../docs/evidence/m0-windows-20261023.json).
An empty runtime `PATH` does not establish clean-machine packaging, Windows isolation,
or a sandbox.

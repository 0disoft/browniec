# Owning runtime Store probe (R01 prerequisite)

Run `python tools/verify-runtime-store-probe.py` from the repository. Windows x64,
MSVC with a complete Windows SDK, Python, Git, and `build/toolchain/fairyc.exe`
matching `toolchain.json` are required. The sibling fairyc Git repository must
contain revision `eb274643bfcfe746617121ddc6f130b018978b53`. An isolated/relocated
mirror can supply `--fairyc-repository <repository>`; the default resolves
`toolchain.json`'s `source.localRepository` relative to this repository.
`--profile development` or `--profile release` selects one native build; both run
by default. Release uses `/O2`; development uses `/Od`. CL, _CL_, and LINK
variables are rejected even when empty. No stack override is accepted.

The fixture's opaque Fairy `Store` owns `Vec<Entry>`, and every `Entry` owns an
actual `std::bytes::Buffer`. Fairy constructs buffers and performs typed Vec
push/pop, element access and generated resource cleanup. A small synchronous C
shim projects actual emitted `Store.items` and `Entry.buffer` fields to call the
reviewed Fairy helpers. No resource value crosses a raw foreign signature, and
no pointer or borrow escapes the public Store operations. Payloads 11/22/33 are
cleanup observations, not object handles or identity substitutes. The retained
helper warm-up exists solely to include the C-called typed functions in emission;
its cleanup trace is reset before the owning Store scenario.

Native assertions check push, buffer append, pop/drop, whole-Store move, survivor
drop, empty pop and a second independent Store. The post-reset cleanup trace must
be exactly `[22,11,33]`. The process also requires zero live SystemHeap allocations
at exit. The allocator observer wraps the pinned runtime's malloc/free macros;
it does not replace the allocator or vector algorithms. Receipt cleanup values
mean these native assertions and the guarded process exit passed; they are not
invented observations parsed from a synthetic stdout trace.

The original proof's Fairy sources, bridge and allocator-observer bodies are
preserved byte for byte. `probes/runtime-store/transport.json` records their hashes,
the compiler/revision, the full emitted transport/runtime hashes and the exact
runtime Git-object source hashes. The builder rejects changed identities before
native compilation. Generated C retains the compiler's size/alignment/offset
assertions. The shim uses its real types and typed field expressions, with no
copied struct layout or manually calculated offset. These private generated names
are not a stable ABI: any source/compiler change requires reviewing the complete
transport and every mapping before intentionally updating the pins.

All generated projects, probe locks, C/runtime snapshots, logs, objects, binaries
and receipts go below `build/runtime-store-probe/<UTC-run>/`. The builder checks
and emits C only in that isolated project. It reads runtime source through
`git show <exact revision>:<path>` and never builds or edits fairyc. Native runs
use an empty tool PATH and the default 1MiB/4KiB PE stack reserve/commit, verified
from the built image. The receipt records actual source, command, runtime,
transport, native object and executable hashes. No generated C, binary or log is
part of this contribution; the repository lock and production sources are untouched.

With the pinned compiler, direct `ref mut Store.items` is rejected with E1008;
moving the resource field out gives E1103. User-authored `storage_borrow_mut` is
unavailable (E0101), nested Vec explicit generic arguments fail E4502, and safe
references in raw foreign signatures fail E5102. The prior bounded investigation
also verified private-field rejection E0103 and moved-owner rejection E1101.
Those negative investigations are historical context, not tests rerun by this
small packaging builder. The packaged builder exercises the working native slice.

This is **R01 prerequisite evidence**, not Engine/Program/Instance lifecycle
completion or a public host ABI. General safe mutable resource-field projection
remains unsupported. The trusted C boundary, arbitrary Program storage, allocation
failure rollback, concurrency, recovery and broader runtime integration need their
own implementation and evidence. No Engine, host coordinator, inventory, checkpoint
or production admission gate is changed by this probe.

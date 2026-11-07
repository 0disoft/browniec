module abi_bootstrap;

// Revision-2 constants and admission are Fairy logic. Native code marshals only.
// These public Fairy helpers are not DLL exports or a generated-C ABI contract.
pub fn u32 info_size() { return 32; }
pub fn u32 revision() { return 2; }
pub fn u32 pointer_bits() { return 64; }
pub fn u32 diagnostic_size() { return 264; }
pub fn u32 event_size() { return 336; }
pub fn u32 entry_info_size() { return 32; }
pub fn u32 source_size() { return 32; }
pub fn u32 slice_size() { return 16; }
pub fn u32 validate(u32 requested_revision, u32 out_capacity, bool has_output) {
    if (requested_revision != revision() || out_capacity < info_size()) { return 9; }
    if (!has_output) { return 1; }
    return 0;
}

module main;
import abi_bootstrap as abi;

// Retain the helper roots in the private compiler transport. Never called by DLL.
fn i32 main() {
    if (abi::validate(abi::revision(), abi::info_size(), true) != 0) { return 1; }
    if (abi::pointer_bits() != 64 || abi::diagnostic_size() != 264 || abi::event_size() != 336 ||
        abi::entry_info_size() != 32 || abi::source_size() != 32 || abi::slice_size() != 16) { return 1; }
    return 0;
}

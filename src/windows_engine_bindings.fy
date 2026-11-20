module windows_engine_bindings;
import std::vec as vec;
import module_entry as ordinary;
import module_input_entry as input;
import runtime_input as snapshots;

// Retain the exact generic descriptor types consumed by the native bridge.
resource Incoming {
    vec::Vec<ordinary::Entry> ordinary;
    vec::Vec<input::InputEntry> input;
    vec::Vec<snapshots::Snapshot> snapshots;
    cleanup {}
}
fn Incoming incoming(){
    return Incoming{.ordinary=vec::empty<ordinary::Entry>(),.input=vec::empty<input::InputEntry>(),
        .snapshots=vec::empty<snapshots::Snapshot>()};
}

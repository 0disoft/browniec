module tests::m2::array_allocation;
import ir as ir;
import vm as vm;
import errors as errors;
import std::process as process;

fn usize built(Result<usize, errors::Error> result) {
    return switch (result) { case .ok(n): { n } case .err(_): { assert(false); 0 } };
}
fn ir::Program program() {
    var ir::Program p = ir::empty();
    let usize id = built(ir::array(ref mut p, 1, 1, true, 0));
    let usize fill = built(ir::literal(ref mut p, 42, 0));
    let usize index = built(ir::integer(ref mut p, 0, 12, 0));
    let usize init = built(ir::array_init(ref mut p, id, fill, 0));
    let usize value = built(ir::array_read(ref mut p, id, index, 0));
    let usize drop = built(ir::array_drop(ref mut p, id, 0));
    let usize returned = built(ir::emit(ref mut p, 8, value, 0, 0));
    let usize end = p.count; let usize registers = p.registers;
    p.function_count = 1; p.ends[0] = end; p.register_ends[0] = registers; p.return_types[0] = 1;
    return p;
}
@test
fn void allocation_failure_is_a_guest_error_and_a_new_run_can_succeed() {
    let ir::Program p = program();
    if (process::arg_count() == 2) {
        // The injected one-shot allocator failure must remain pending through
        // these two rejected preflights, then hit the actual 320-byte arena.
        assert(switch (vm::run_with_array_limit(ref p, 320, 320)) { case .ok(_): { false } case .err(e): { e.kind == 8 } });
        assert(switch (vm::run_with_array_limit(ref p, 1000, 65537)) { case .ok(_): { false } case .err(e): { e.kind == 13 } });
        assert(switch (vm::run_with_array_limit(ref p, 1000, 320)) { case .ok(_): { false } case .err(e): { e.kind == 15 } });
    }
    // This is an explicit new one-shot execution, never an automatic replay.
    assert(switch (vm::run_with_array_limit(ref p, 1000, 320)) { case .ok(n): { n == 42 } case .err(_): { false } });
}

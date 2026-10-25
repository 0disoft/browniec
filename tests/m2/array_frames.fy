module tests::m2::array_frames;

import array_layout as layouts;
import errors as errors;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn usize built(Result<usize, errors::Error> result) {
    return switch (result) { case .ok(n): { n } case .err(_): { assert(false); 0 } };
}
fn void finish(ref mut ir::Program p, usize f) {
    let usize end = p.count;
    let usize registers = p.registers;
    p.ends[f] = end; p.register_ends[f] = registers;
}
fn void result(ref ir::Program p, usize limit, usize fuel) {
    assert(verifier::verify(p).is_ok);
    assert(switch (vm::run_with_array_limit(p, fuel, limit)) {
        case .ok(n): { n == 42 } case .err(_): { false }
    });
}
fn void failed(ref ir::Program p, usize limit, usize fuel, u8 kind) {
    assert(verifier::verify(p).is_ok);
    assert(switch (vm::run_with_array_limit(p, fuel, limit)) {
        case .ok(_): { false } case .err(e): { e.kind == kind }
    });
}
fn usize cell(ref mut ir::Program p, u8 tag, i64 value) {
    if (tag == 2) { return built(ir::boolean(p, value == 1, 0)); }
    return built(ir::integer(p, value, tag, 0));
}

// Private helper locals use all existing array operations while the caller
// retains its own payload. No source grammar or aggregate calling ABI is added.
fn ir::Program sequential(u8 tag, i64 value) {
    var ir::Program p = ir::empty();
    p.function_count = 2; p.entry = 1; p.return_types[0] = 1; p.return_types[1] = 1;
    p.arities[0] = 1; p.types[0] = tag; p.registers = 1;
    let usize a = built(ir::array_in(ref mut p, 0, tag, 2, true, 0));
    let usize b = built(ir::array_in(ref mut p, 0, tag, 2, true, 0));
    let usize index = cell(ref mut p, 12, 0);
    let usize zero = cell(ref mut p, tag, 0);
    let usize init = built(ir::array_init(ref mut p, a, 0, 0));
    let usize copy = built(ir::array_copy(ref mut p, b, a, 0));
    let usize write = built(ir::array_write(ref mut p, a, index, zero, 0));
    let usize assign = built(ir::array_assign(ref mut p, a, b, 0));
    let usize self = built(ir::array_assign(ref mut p, b, b, 0));
    let usize actual = built(ir::array_read(ref mut p, a, index, 0));
    let usize equal = built(ir::emit(ref mut p, 11, actual, 0, 0));
    let usize drop_b = built(ir::array_drop(ref mut p, b, 0));
    let usize drop_a = built(ir::array_drop(ref mut p, a, 0));
    let usize answer = cell(ref mut p, 1, 42);
    let usize failure = cell(ref mut p, 1, 0);
    let usize target = p.count + 2;
    let usize branch = built(ir::raw(ref mut p, 20, 0, equal, target, 0));
    let usize yes = built(ir::emit(ref mut p, 8, answer, 0, 0));
    let usize no = built(ir::emit(ref mut p, 8, failure, 0, 0));
    finish(ref mut p, 0);

    let usize start = p.count; let usize registers = p.registers;
    p.starts[1] = start; p.register_starts[1] = registers;
    let usize parent = built(ir::array(ref mut p, tag, 2, false, 0));
    let usize fill = cell(ref mut p, tag, value);
    let usize parent_index = cell(ref mut p, 12, 0);
    let usize parent_init = built(ir::array_init(ref mut p, parent, fill, 0));
    let usize[1] arguments = [fill];
    var usize last = 0; var usize i = 0;
    while (i < 24) { last = built(ir::call(ref mut p, 0, ref arguments, 0)); i += 1; }
    let usize parent_value = built(ir::array_read(ref mut p, parent, parent_index, 0));
    let usize preserved = built(ir::emit(ref mut p, 11, parent_value, fill, 0));
    let usize parent_drop = built(ir::array_drop(ref mut p, parent, 0));
    let usize parent_failure = cell(ref mut p, 1, 0);
    let usize parent_target = p.count + 2;
    let usize parent_branch = built(ir::raw(ref mut p, 20, 0, preserved, parent_target, 0));
    let usize parent_yes = built(ir::emit(ref mut p, 8, last, 0, 0));
    let usize parent_no = built(ir::emit(ref mut p, 8, parent_failure, 0, 0));
    finish(ref mut p, 1);
    return p;
}

// Each invocation returns n + recurse(n-1), checking both its preserved local
// array and the scalar child result. Late allocation permits the full frame cap.
fn ir::Program recursive(i64 n, bool late, usize prefix) {
    var ir::Program p = ir::empty();
    p.function_count = 2; p.entry = 1; p.return_types[0] = 1; p.return_types[1] = 1;
    p.arities[0] = 1; p.types[0] = 1; p.registers = 1;
    var usize padding = 0;
    while (padding < prefix) {
        let usize unused = built(ir::array(ref mut p, 1, 1, false, 0)); padding += 1;
    }
    let usize id = built(ir::array_in(ref mut p, 0, 1, 1, true, 0));
    let usize zero = cell(ref mut p, 1, 0);
    let usize index = cell(ref mut p, 12, 0);
    let usize child_value = built(ir::slot(ref mut p, 1, 0));
    let usize initial = built(ir::raw(ref mut p, 18, child_value, zero, 0, 0));
    if (!late) { let usize init = built(ir::array_init(ref mut p, id, 0, 0)); }
    let usize condition = built(ir::emit(ref mut p, 15, 0, zero, 0));
    let usize branch = built(ir::raw(ref mut p, 20, 0, condition, 0, 0));
    let usize one = cell(ref mut p, 1, 1);
    let usize smaller = built(ir::emit(ref mut p, 3, 0, one, 0));
    let usize[1] arguments = [smaller];
    let usize child = built(ir::call(ref mut p, 0, ref arguments, 0));
    let usize stored = built(ir::raw(ref mut p, 18, child_value, child, 0, 0));
    let usize target = p.count;
    let usize patched = built(ir::patch(ref mut p, branch, target, 0));
    if (late) { let usize init = built(ir::array_init(ref mut p, id, 0, 0)); }
    let usize own = built(ir::array_read(ref mut p, id, index, 0));
    let usize child_read = built(ir::emit(ref mut p, 17, child_value, 0, 0));
    let usize total = built(ir::emit(ref mut p, 2, own, child_read, 0));
    let usize drop = built(ir::array_drop(ref mut p, id, 0));
    let usize returned = built(ir::emit(ref mut p, 8, total, 0, 0));
    finish(ref mut p, 0);

    let usize start = p.count; let usize registers = p.registers;
    p.starts[1] = start; p.register_starts[1] = registers;
    let usize count = cell(ref mut p, 1, n);
    let usize[1] root_arguments = [count];
    let usize actual = built(ir::call(ref mut p, 0, ref root_arguments, 0));
    let usize correction = cell(ref mut p, 1, 42 - n * (n + 1) / 2);
    let usize answer = built(ir::emit(ref mut p, 2, actual, correction, 0));
    let usize returned_main = built(ir::emit(ref mut p, 8, answer, 0, 0));
    finish(ref mut p, 1);
    return p;
}

@test
fn void helper_operations_preserve_parent_storage_for_all_scalar_types() {
    let u8[6] tags = [1, 2, 9, 10, 11, 12];
    let i64[6] values = [-2147483648, 1, -9223372036854775808, 255, 4294967295, -1];
    var usize i = 0;
    while (i < tags.len) {
        let ir::Program p = sequential(tags[i], values[i]);
        let layouts::Array layout = switch (layouts::scalar(tags[i], 2)) {
            case .ok(a): { a } case .err(_): { assert(false); layouts::Array { .element = 1, .length = 1, .stride = 4, .alignment = 4, .bytes = 4 } }
        };
        result(ref p, 3 * layout.bytes, 1000000);
        failed(ref p, 3 * layout.bytes - 1, 1000000, 13);
        result(ref p, 3 * layout.bytes, 1000000);
        i += 1;
    }
}

@test
fn void recursive_array_tokens_and_scalar_registers_belong_to_each_frame() {
    let ir::Program p = recursive(3, false, 0);
    result(ref p, 16, 686);
    failed(ref p, 16, 685, 8);
    failed(ref p, 15, 1000000, 13);
    result(ref p, 16, 686);
}

@test
fn void recursion_shares_the_sixteen_owner_quota_and_payload_limit() {
    let ir::Program full = recursive(15, false, 0);
    result(ref full, 64, 1000000);
    failed(ref full, 63, 1000000, 13);
    let ir::Program over = recursive(16, false, 0);
    failed(ref over, 68, 1000000, 13);
    result(ref full, 64, 1000000);
}

@test
fn void deepest_frame_and_last_catalog_binding_reuse_storage_on_unwind() {
    let ir::Program p = recursive(30, true, 15);
    result(ref p, 4, 1000000);
    result(ref p, 4, 1000000);
    let ir::Program over = recursive(31, true, 15);
    failed(ref over, 4, 1000000, 12);
    failed(ref over, 4, 5, 8);
    result(ref p, 4, 1000000);
}

@test
fn void helper_returns_cannot_leave_live_arrays() {
    var ir::Program p = recursive(3, false, 0);
    let usize drop = p.ends[0] - 2;
    let usize count = p.count;
    p.count = drop;
    let usize jump = built(ir::raw(ref mut p, 19, 0, drop + 1, 0, 0));
    p.count = count;
    assert(switch (verifier::verify(ref p)) {
        case .ok(_): { false } case .err(e): { e.kind == 5 && e.offset == drop + 1 }
    });
    assert(switch (vm::run_with_array_limit(ref p, 1000000, 16)) {
        case .ok(_): { false } case .err(e): { e.kind == 5 }
    });
}

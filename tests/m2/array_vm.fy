module tests::m2::array_vm;
import ir as ir;
import vm as vm;
import errors as errors;
import render as render;

fn usize built(Result<usize, errors::Error> result) {
    return switch (result) { case .ok(n): { n } case .err(_): { assert(false); 0 } };
}
fn void finish(ref mut ir::Program p) {
    p.function_count = 1; p.entry = 0; p.starts[0] = 0;
    let usize end = p.count; let usize registers = p.registers;
    p.ends[0] = end; p.register_starts[0] = 0; p.register_ends[0] = registers; p.return_types[0] = 1;
}
fn void result(ref ir::Program p, usize limit, usize fuel, i64 expected) {
    assert(switch (vm::run_with_array_limit(p, fuel, limit)) { case .ok(n): { n == expected } case .err(_): { false } });
}
fn void failed(ref ir::Program p, usize limit, usize fuel, u8 kind) {
    assert(switch (vm::run_with_array_limit(p, fuel, limit)) { case .ok(_): { false } case .err(e): { e.kind == kind } });
}
fn ir::Program simple(i64 index_cell, usize length) {
    var ir::Program p = ir::empty();
    let usize id = built(ir::array(ref mut p, 1, length, true, 0));
    let usize fill = built(ir::literal(ref mut p, 42, 0));
    let usize index = built(ir::integer(ref mut p, index_cell, 12, 0));
    let usize init = built(ir::array_init(ref mut p, id, fill, 0));
    let usize value = built(ir::array_read(ref mut p, id, index, 0));
    let usize drop = built(ir::array_drop(ref mut p, id, 0));
    let usize returned = built(ir::emit(ref mut p, 8, value, 0, 0));
    finish(ref mut p); return p;
}
fn ir::Program roundtrip(u8 tag, i64 cell, usize length, bool copy, bool write) {
    var ir::Program p = ir::empty();
    let usize source = built(ir::array(ref mut p, tag, length, true, 0));
    var usize destination = source;
    if (copy) { destination = built(ir::array(ref mut p, tag, length, false, 0)); }
    let usize fill = if (tag == 2) { built(ir::boolean(ref mut p, cell == 1, 0)) }
        else { built(ir::integer(ref mut p, cell, tag, 0)) };
    let usize index = built(ir::integer(ref mut p, 0, 12, 0));
    let usize zero = if (tag == 2) { built(ir::boolean(ref mut p, false, 0)) }
        else { built(ir::integer(ref mut p, 0, tag, 0)) };
    let usize init = built(ir::array_init(ref mut p, source, fill, 0));
    if (copy) { let usize copied = built(ir::array_copy(ref mut p, destination, source, 0)); }
    if (write) { let usize written = built(ir::array_write(ref mut p, source, index, zero, 0)); }
    let usize actual = built(ir::array_read(ref mut p, destination, index, 0));
    let usize equal = built(ir::emit(ref mut p, 11, actual, if (write && !copy) { zero } else { fill }, 0));
    let usize dropped = built(ir::array_drop(ref mut p, source, 0));
    if (copy) { let usize copied_drop = built(ir::array_drop(ref mut p, destination, 0)); }
    let usize answer = built(ir::literal(ref mut p, 42, 0));
    let usize failure = built(ir::literal(ref mut p, 0, 0));
    let usize target = p.count + 2;
    let usize branch = built(ir::raw(ref mut p, 20, 0, equal, target, 0));
    let usize yes = built(ir::emit(ref mut p, 8, answer, 0, 0));
    let usize no = built(ir::emit(ref mut p, 8, failure, 0, 0));
    finish(ref mut p); return p;
}

@test
fn void all_scalar_array_reads_and_writes_run_in_the_native_vm() {
    let u8[6] tags = [1, 2, 9, 10, 11, 12];
    let i64[6] values = [-2147483648, 1, -9223372036854775808, 255, 4294967295, -1];
    var usize i = 0;
    while (i < tags.len) {
        let ir::Program read = roundtrip(tags[i], values[i], 2, false, false);
        let ir::Program write = roundtrip(tags[i], values[i], 2, false, true);
        result(ref read, 16, 10000, 42); result(ref write, 16, 10000, 42);
        i += 1;
    }
}

@test
fn void copied_arrays_keep_original_values_after_source_mutation_and_drop() {
    let u8[6] tags = [1, 2, 9, 10, 11, 12];
    let i64[6] values = [-2147483648, 1, -9223372036854775808, 255, 4294967295, -1];
    var usize i = 0;
    while (i < tags.len) {
        let ir::Program p = roundtrip(tags[i], values[i], 2, true, true);
        result(ref p, 32, 10000, 42); i += 1;
    }
}

@test
fn void exact_fuel_bounds_quota_and_fresh_program_reuse() {
    let ir::Program p = simple(0, 2);
    failed(ref p, 8, 169, 8); result(ref p, 8, 170, 42);
    failed(ref p, 8, 8, 8); result(ref p, 8, 170, 42);
    failed(ref p, 65537, 0, 13);
    let ir::Program quota = simple(0, 3);
    failed(ref quota, 8, 86, 8); failed(ref quota, 8, 87, 13);
    let ir::Program bounds = simple(2, 2);
    failed(ref bounds, 8, 119, 8); failed(ref bounds, 8, 120, 14);
    let ir::Program huge_index = simple(-1, 2);
    failed(ref huge_index, 8, 1000, 14);
    assert(render::exit_code(13) == 5 && render::exit_code(14) == 5 && render::exit_code(15) == 5);
}

@test
fn void metered_loop_recreation_reuses_owners_until_fuel_exhaustion() {
    var ir::Program p = ir::empty();
    let usize id = built(ir::array(ref mut p, 10, 1, true, 0));
    let usize fill = built(ir::integer(ref mut p, 42, 10, 0));
    let usize condition = built(ir::boolean(ref mut p, true, 0));
    let usize answer = built(ir::literal(ref mut p, 42, 0));
    let usize branch = built(ir::raw(ref mut p, 20, 0, condition, 7, 0));
    let usize init = built(ir::array_init(ref mut p, id, fill, 0));
    let usize drop = built(ir::array_drop(ref mut p, id, 0));
    let usize back = built(ir::raw(ref mut p, 22, 0, 3, 0, 0));
    let usize returned = built(ir::emit(ref mut p, 8, answer, 0, 0));
    finish(ref mut p);
    failed(ref p, 1, 100000, 8); failed(ref p, 1, 100000, 8);
}

@test
fn void scalar_callees_and_frame_failure_do_not_access_parent_arrays() {
    var ir::Program p = ir::empty();
    let usize helper = built(ir::literal(ref mut p, 7, 0));
    let usize helper_return = built(ir::emit(ref mut p, 8, helper, 0, 0));
    p.function_count = 2; p.entry = 1; p.ends[0] = 2; p.register_ends[0] = 1; p.return_types[0] = 1;
    p.starts[1] = 2; p.register_starts[1] = 1; p.return_types[1] = 1;
    let usize id = built(ir::array(ref mut p, 1, 1, true, 0));
    let usize fill = built(ir::literal(ref mut p, 42, 0));
    let usize index = built(ir::integer(ref mut p, 0, 12, 0));
    let usize init = built(ir::array_init(ref mut p, id, fill, 0));
    let usize[1] arguments = [0];
    let usize call = built(ir::call(ref mut p, 0, ref arguments[..0], 0));
    let usize value = built(ir::array_read(ref mut p, id, index, 0));
    let usize drop = built(ir::array_drop(ref mut p, id, 0));
    let usize returned = built(ir::emit(ref mut p, 8, value, 0, 0));
    let usize end = p.count; let usize registers = p.registers;
    p.ends[1] = end; p.register_ends[1] = registers;
    result(ref p, 4, 10000, 42);
    p.code[0] = 9; p.code[2] = 0; p.code[3] = 1; p.call_count = 2;
    failed(ref p, 4, 10000, 12);
}

@test
fn void maximum_usize_array_copy_checks_old_plus_new_peak() {
    let ir::Program p = roundtrip(12, -1, 4096, true, true);
    result(ref p, 65536, 1000000, 42);
    failed(ref p, 65535, 1000000, 13);
    result(ref p, 65536, 1000000, 42);
}

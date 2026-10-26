module tests::m2::struct_ir;
import ir as ir;
import verifier as verifier;
import struct_meta as meta;
import vm as vm;
import errors as errors;

fn usize built(Result<usize, errors::Error> value) {
    return switch (value) { case .ok(n): { n } case .err(_): { assert(false); 0 } };
}
fn void finish(ref mut ir::Program p) {
    let usize count = p.count; let usize registers = p.registers;
    p.function_count = 1; p.entry = 0; p.starts[0] = 0; p.ends[0] = count;
    p.register_starts[0] = 0; p.register_ends[0] = registers; p.return_types[0] = 1;
}
fn ir::Program declared() {
    var ir::Program p = ir::empty();
    p.records.layouts.count = 3;
    // Two distinct, physically identical records and a nested bool+i32 root.
    p.records.layouts.fields[0] = 1; p.records.layouts.types[0] = 1;
    p.records.layouts.fields[1] = 1; p.records.layouts.types[16] = 1;
    p.records.layouts.fields[2] = 2; p.records.layouts.types[32] = 2;
    p.records.layouts.kinds[33] = 1; p.records.layouts.types[33] = 0;
    let usize id = built(ir::record(ref mut p, 0, true, 0));
    return p;
}
fn ir::Program basic() {
    var ir::Program p = declared();
    let usize fill = built(ir::literal(ref mut p, 42, 0));
    let usize init = built(ir::record_init(ref mut p, 0, fill, 0));
    let usize value = built(ir::record_read(ref mut p, 0, 0, 0));
    let usize write = built(ir::record_write(ref mut p, 0, 0, fill, 0));
    let usize drop = built(ir::record_drop(ref mut p, 0, 0));
    let usize ret = built(ir::emit(ref mut p, 8, value, 0, 0));
    finish(ref mut p); return p;
}

@test
fn void builders_and_nested_scalar_order_are_verified_and_execution_is_metered() {
    let ir::Program p = basic(); assert(verifier::verify(ref p).is_ok);
    assert(switch (vm::run(ref p, 0)) { case .err(e): { e.kind == 8 } case .ok(_): { false } });
    assert(switch (vm::run(ref p, 1000000)) { case .ok(n): { n == 42 } case .err(_): { false } });
    var ir::Program q = declared(); q.records.records[0] = 2;
    let usize flag = built(ir::boolean(ref mut q, true, 0));
    let usize value = built(ir::literal(ref mut q, 42, 0));
    let usize init = built(ir::record_init(ref mut q, 0, flag, 0));
    let usize read = built(ir::record_read(ref mut q, 0, 1, 0));
    let usize drop = built(ir::record_drop(ref mut q, 0, 0));
    let usize ret = built(ir::emit(ref mut q, 8, read, 0, 0));
    finish(ref mut q); assert(verifier::verify(ref q).is_ok);
    q.code[19] = 1; assert(!verifier::verify(ref q).is_ok);
    assert(!ir::record_read(ref mut q, 16, 0, 0).is_ok);
    assert(!ir::record_read(ref mut q, 0, 2, 0).is_ok);
    assert(!ir::record(ref mut q, 32, false, 0).is_ok);
    q = declared();
    let usize scalar = built(ir::literal(ref mut q, 42, 0));
    let usize returned = built(ir::emit(ref mut q, 8, scalar, 0, 0));
    finish(ref mut q); assert(verifier::verify(ref q).is_ok);
    assert(switch (vm::run_with_array_limit(ref q, 0, 65537)) {
        case .err(e): { e.kind == 13 } case .ok(_): { false }
    });
}

@test
fn void copies_and_assignment_require_exact_live_record_identity() {
    var ir::Program p = declared();
    let usize second = built(ir::record(ref mut p, 0, true, 0));
    let usize value = built(ir::literal(ref mut p, 42, 0));
    let usize init = built(ir::record_init(ref mut p, 0, value, 0));
    let usize copy = built(ir::record_copy(ref mut p, second, 0, 0));
    let usize assign = built(ir::record_assign(ref mut p, second, 0, 0));
    let usize self = built(ir::record_assign(ref mut p, second, second, 0));
    let usize drop = built(ir::record_drop(ref mut p, 0, 0));
    let usize surviving = built(ir::record_read(ref mut p, second, 0, 0));
    let usize last = built(ir::record_drop(ref mut p, second, 0));
    let usize ret = built(ir::emit(ref mut p, 8, value, 0, 0));
    finish(ref mut p); assert(verifier::verify(ref p).is_ok);
    p.records.records[1] = 1; assert(!verifier::verify(ref p).is_ok);
    p.code[16] = 41; assert(!verifier::verify(ref p).is_ok); // Separate valid init, wrong assignment identity.
    p.code[16] = 42;
    p.records.records[1] = 0; p.records.mutable[1] = false;
    assert(!verifier::verify(ref p).is_ok);
    p.records.mutable[1] = true; p.code[26] = 16; assert(!verifier::verify(ref p).is_ok);
    p.code[26] = 0; p.code[18] = 1; assert(!verifier::verify(ref p).is_ok);
}

@test
fn void metadata_is_replanned_even_for_unused_bindings_and_definitions() {
    var ir::Program p = basic();
    p.records.count = 17; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.records.records[1] = 1; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.records.mutable[1] = true; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.records.records[0] = 3; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.records.layouts.types[511] = 1; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.records.layouts.kinds[0] = 1; p.records.layouts.types[0] = 0; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.records.layouts.types[16] = 255; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.records.layouts.count = 33; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.records.layouts.fields[1] = 0; assert(!verifier::verify(ref p).is_ok);
}

@test
fn void scalar_operands_reserved_bytes_and_mutability_are_independent_checks() {
    var ir::Program p = basic();
    p.code[10] = 1; assert(!verifier::verify(ref p).is_ok); // Undefined initializer.
    p = basic(); p.types[0] = 11; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.slots[0] = true; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.code[18] = 16; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.code[19] = 1; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.types[1] = 11; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.code[25] = 16; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.code[26] = 1; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.code[27] = 1; p.code[17] = 0; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.records.mutable[0] = false; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.code[34] = 1; assert(!verifier::verify(ref p).is_ok);
    var usize pc = 1;
    while (pc < 5) {
        var usize byte = 4;
        while (byte < 8) { p = basic(); p.code[pc * 8 + byte] = 1; assert(!verifier::verify(ref p).is_ok); byte += 1; }
        pc += 1;
    }
    p = basic(); p.code[8] = 47; assert(!verifier::verify(ref p).is_ok);
}

@test
fn void initialization_drop_and_return_preserve_record_lifetimes() {
    var ir::Program p = basic();
    p.code[8] = 45; p.code[10] = 0; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.code[24] = 41; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.code[32] = 44; assert(!verifier::verify(ref p).is_ok); // Leaking return.
    p = basic(); p.code[24] = 45; assert(!verifier::verify(ref p).is_ok); // Double drop.
    p = basic(); p.code[16] = 45; p.code[17] = 0; assert(!verifier::verify(ref p).is_ok);
    p = basic(); p.code[24] = 45; p.code[32] = 41; assert(verifier::verify(ref p).is_ok == false);
}

fn ir::Program flow(bool loop) {
    var ir::Program p = declared();
    let usize fill = built(ir::literal(ref mut p, 42, 0));
    let usize condition = built(ir::boolean(ref mut p, true, 0));
    let usize branch = built(ir::raw(ref mut p, 20, 0, condition, 6, 0));
    let usize init = built(ir::record_init(ref mut p, 0, fill, 0));
    let usize drop = built(ir::record_drop(ref mut p, 0, 0));
    let usize jump = built(ir::raw(ref mut p, if (loop) { 22 } else { 19 }, 0, if (loop) { 2 } else { 6 }, 0, 0));
    let usize ret = built(ir::emit(ref mut p, 8, fill, 0, 0));
    finish(ref mut p); return p;
}

@test
fn void forward_joins_require_exact_record_and_array_live_sets() {
    var ir::Program p = flow(false); assert(verifier::verify(ref p).is_ok);
    p.code[32] = 19; p.code[34] = 5; assert(!verifier::verify(ref p).is_ok);
    p = flow(false);
    let usize array = built(ir::array(ref mut p, 1, 1, true, 0));
    p.code[32] = 33; p.code[34] = 0; assert(!verifier::verify(ref p).is_ok);
}

@test
fn void backedges_require_the_first_entry_record_invariant() {
    var ir::Program p = flow(true); assert(verifier::verify(ref p).is_ok);
    p.code[32] = 19; p.code[34] = 5; assert(!verifier::verify(ref p).is_ok);
    p = flow(true); p.code[42] = 4; assert(!verifier::verify(ref p).is_ok);
}

@test
fn void only_entry_accesses_records_and_no_function_can_reenter_it() {
    var ir::Program p = basic();
    let usize value = built(ir::literal(ref mut p, 0, 0));
    let usize ret = built(ir::emit(ref mut p, 8, value, 0, 0));
    p.function_count = 2; p.starts[1] = 6; p.ends[1] = 8;
    p.register_starts[1] = 2; p.register_ends[1] = 3; p.return_types[1] = 1;
    assert(verifier::verify(ref p).is_ok);
    p.entry = 1; assert(!verifier::verify(ref p).is_ok);
    var ir::Program q = declared();
    let usize[1] args = [0];
    let usize called = built(ir::call(ref mut q, 0, ref args[..0], 0));
    let usize returned = built(ir::emit(ref mut q, 8, called, 0, 0));
    q.types[0] = 1; finish(ref mut q); assert(!verifier::verify(ref q).is_ok);
}

@test
fn void deepest_widest_and_full_binding_catalogs_are_bounded() {
    var ir::Program p = ir::empty();
    p.records.layouts.count = 16;
    let u8[16] children = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 1];
    var usize r = 0;
    while (r < 16) {
        p.records.layouts.fields[r] = 1;
        p.records.layouts.kinds[r * 16] = if (r == 15) { 0 } else { 1 };
        p.records.layouts.types[r * 16] = children[r];
        r += 1;
    }
    let usize value = built(ir::literal(ref mut p, 42, 0));
    r = 0;
    while (r < 16) {
        let usize id = built(ir::record(ref mut p, 0, false, 0));
        let usize init = built(ir::record_init(ref mut p, id, value, 0)); r += 1;
    }
    assert(!ir::record(ref mut p, 0, false, 0).is_ok);
    r = 0;
    while (r < 16) { let usize drop = built(ir::record_drop(ref mut p, r, 0)); r += 1; }
    let usize ret = built(ir::emit(ref mut p, 8, value, 0, 0));
    finish(ref mut p); assert(verifier::verify(ref p).is_ok);
    p.records.layouts.count = 17; p.records.layouts.kinds[240] = 1;
    p.records.layouts.types[240] = 16; p.records.layouts.fields[16] = 1;
    p.records.layouts.types[256] = 1; assert(!verifier::verify(ref p).is_ok);
    var meta::Catalog wide = meta::empty(); wide.layouts.count = 2;
    wide.layouts.fields[0] = 8; wide.layouts.fields[1] = 16; wide.count = 1;
    r = 0;
    while (r < 16) {
        wide.layouts.types[16 + r] = 10;
        if (r < 8) { wide.layouts.kinds[r] = 1; wide.layouts.types[r] = 1; }
        r += 1;
    }
    let meta::Prepared shape = switch (meta::prepare(ref wide)) {
        case .ok(n): { n } case .err(_): { assert(false); meta::Prepared { .leaves = [0; 16], .tags = [0; 2048] } }
    };
    assert(shape.leaves[0] == 128 && shape.tags[127] == 10);
    p = ir::empty(); p.records = wide;
    r = 0;
    while (r < 128) { let usize cell = built(ir::integer(ref mut p, 0, 10, 0)); r += 1; }
    let usize init = built(ir::record_init(ref mut p, 0, 0, 0));
    let usize drop = built(ir::record_drop(ref mut p, 0, 0));
    let usize failure = built(ir::raw(ref mut p, 25, 0, 0, 0, 0));
    finish(ref mut p); assert(verifier::verify(ref p).is_ok);
    p.code[1026] = 1; assert(!verifier::verify(ref p).is_ok);
    wide.layouts.fields[0] = 9; wide.layouts.kinds[8] = 1; wide.layouts.types[8] = 1;
    assert(!meta::prepare(ref wide).is_ok);
}

module tests::m2::array_ir;
import ir as ir;
import verifier as verifier;
import vm as vm;
import errors as errors;

fn usize built(Result<usize, errors::Error> result) {
    return switch (result) { case .ok(value): { value } case .err(_): { assert(false); 0 } };
}

fn void finish(ref mut ir::Program p) {
    p.function_count = 1; p.entry = 0; p.starts[0] = 0;
    let usize count = p.count; let usize registers = p.registers;
    p.ends[0] = count; p.register_starts[0] = 0; p.register_ends[0] = registers;
    p.return_types[0] = 1;
}
fn ir::Program basic() {
    var ir::Program p = ir::empty();
    let usize id = built(ir::array(ref mut p, 1, 2, true, 0));
    let usize fill = built(ir::literal(ref mut p, 42, 0));
    let usize index = built(ir::integer(ref mut p, 0, 12, 0));
    let usize init = built(ir::array_init(ref mut p, id, fill, 0));
    let usize value = built(ir::array_read(ref mut p, id, index, 0));
    let usize drop = built(ir::array_drop(ref mut p, id, 0));
    let usize returned = built(ir::emit(ref mut p, 8, value, 0, 0));
    finish(ref mut p);
    return p;
}

@test
fn void private_array_builders_and_scalar_result_are_verified() {
    let ir::Program p = basic();
    assert(verifier::verify(ref p).is_ok);
    assert(p.types[2] == 1 && p.arrays.count == 1 && p.count == 6);
    assert(switch (vm::run(ref p, 100000)) { case .ok(n): { n == 42 } case .err(_): { false } });
    var ir::Program bad = ir::empty();
    assert(!ir::array(ref mut bad, 1, 0, true, 0).is_ok);
    assert(!ir::array_read(ref mut bad, 16, 0, 0).is_ok);
    var ir::Program copied = basic();
    let usize second = built(ir::array(ref mut copied, 1, 2, false, 0));
    copied.count = 4;
    let usize copied_id = built(ir::array_copy(ref mut copied, second, 0, 0));
    let usize drop_first = built(ir::array_drop(ref mut copied, 0, 0));
    let usize drop_second = built(ir::array_drop(ref mut copied, second, 0));
    let usize returned = built(ir::emit(ref mut copied, 8, 2, 0, 0));
    finish(ref mut copied);
    assert(verifier::verify(ref copied).is_ok);
    copied.arrays.lengths[1] = 3; assert(!verifier::verify(ref copied).is_ok);
    copied.arrays.lengths[1] = 2; copied.arrays.elements[1] = 2;
    assert(!verifier::verify(ref copied).is_ok);
}

@test
fn void catalog_reserved_bytes_and_typed_scalar_operands_are_checked() {
    var ir::Program p = basic();
    p.arrays.count = 17; assert(!verifier::verify(ref p).is_ok);
    p.arrays.count = 1; p.arrays.elements[0] = 3; assert(!verifier::verify(ref p).is_ok);
    p.arrays.elements[0] = 1; p.arrays.lengths[0] = 4097; assert(!verifier::verify(ref p).is_ok);
    p.arrays.lengths[0] = 2; p.arrays.elements[1] = 1; assert(!verifier::verify(ref p).is_ok);
    p.arrays.elements[1] = 0; p.code[20] = 1; assert(!verifier::verify(ref p).is_ok);
    p.code[20] = 0; p.types[0] = 9; assert(!verifier::verify(ref p).is_ok);
    p.types[0] = 1; p.types[1] = 1; assert(!verifier::verify(ref p).is_ok);
    p.types[1] = 12; p.code[27] = 2; assert(!verifier::verify(ref p).is_ok);
    p.code[27] = 1; p.slots[2] = true; assert(!verifier::verify(ref p).is_ok);
    p.slots[2] = false; assert(verifier::verify(ref p).is_ok);
    // Replace the read with a write and return the existing scalar fill value.
    p.registers = 2; p.register_ends[0] = 2;
    p.code[24] = 36; p.code[25] = 0; p.code[26] = 1; p.code[27] = 0;
    p.code[42] = 0;
    assert(verifier::verify(ref p).is_ok);
    p.arrays.mutable[0] = false; assert(!verifier::verify(ref p).is_ok);
}

@test
fn void live_sets_must_match_exactly_at_forward_joins() {
    var ir::Program p = ir::empty();
    let usize id = built(ir::array(ref mut p, 1, 1, false, 0));
    let usize fill = built(ir::literal(ref mut p, 42, 0));
    let usize condition = built(ir::boolean(ref mut p, true, 0));
    let usize branch = built(ir::raw(ref mut p, 20, 0, condition, 6, 0));
    let usize init = built(ir::array_init(ref mut p, id, fill, 0));
    let usize drop = built(ir::array_drop(ref mut p, id, 0));
    let usize jump = built(ir::raw(ref mut p, 19, 0, 7, 0, 0));
    let usize other = built(ir::raw(ref mut p, 19, 0, 7, 0, 0));
    let usize returned = built(ir::emit(ref mut p, 8, fill, 0, 0));
    finish(ref mut p);
    assert(verifier::verify(ref p).is_ok);
    p.code[32] = 19; p.code[34] = 5;
    assert(!verifier::verify(ref p).is_ok);
}

@test
fn void backedges_and_returns_cannot_leak_or_revive_arrays() {
    var ir::Program p = ir::empty();
    let usize id = built(ir::array(ref mut p, 1, 1, true, 0));
    let usize fill = built(ir::literal(ref mut p, 42, 0));
    let usize condition = built(ir::boolean(ref mut p, true, 0));
    let usize branch = built(ir::raw(ref mut p, 20, 0, condition, 6, 0));
    let usize init = built(ir::array_init(ref mut p, id, fill, 0));
    let usize drop = built(ir::array_drop(ref mut p, id, 0));
    let usize back = built(ir::raw(ref mut p, 22, 0, 2, 0, 0));
    let usize returned = built(ir::emit(ref mut p, 8, fill, 0, 0));
    finish(ref mut p);
    assert(verifier::verify(ref p).is_ok);
    p.code[32] = 19; p.code[34] = 5;
    assert(!verifier::verify(ref p).is_ok);
    var ir::Program q = basic();
    q.code[32] = 19; q.code[34] = 5;
    assert(!verifier::verify(ref q).is_ok);
    q = basic(); q.code[16] = 37; q.code[18] = 0;
    assert(!verifier::verify(ref q).is_ok);
}

@test
fn void only_entry_arrays_are_admitted_and_entry_cannot_be_called() {
    var ir::Program p = basic();
    let usize value = built(ir::literal(ref mut p, 0, 0));
    let usize returned = built(ir::emit(ref mut p, 8, value, 0, 0));
    p.function_count = 2; p.entry = 1; p.starts[1] = 6; p.ends[1] = 8;
    p.register_starts[1] = 3; p.register_ends[1] = 4; p.return_types[1] = 1;
    assert(!verifier::verify(ref p).is_ok);
    var ir::Program q = ir::empty();
    let usize id = built(ir::array(ref mut q, 1, 1, false, 0));
    let usize[1] arguments = [0];
    let usize called = built(ir::call(ref mut q, 0, ref arguments[..0], 0));
    let usize returned_q = built(ir::emit(ref mut q, 8, called, 0, 0));
    q.types[0] = 1;
    finish(ref mut q);
    assert(!verifier::verify(ref q).is_ok);
}

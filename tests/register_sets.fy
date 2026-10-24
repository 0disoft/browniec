module tests::register_sets;
import ir as ir;
import verifier as verifier;
import vm as vm;
import errors as errors;

fn usize built(Result<usize, errors::Error> value) {
    return switch (value) { case .ok(n): { n } case .err(_): { assert(false); 0 } };
}
fn void finish(ref mut ir::Program p) {
    let usize count = p.count; let usize registers = p.registers;
    p.function_count = 1; p.ends[0] = count; p.register_ends[0] = registers; p.return_types[0] = 1;
}
fn void result(ref ir::Program p) {
    assert(verifier::verify(p).is_ok);
    assert(switch (vm::run(p, 1000)) { case .ok(n): { n == 42 } case .err(_): { false } });
}
fn void rejected(ref ir::Program p, usize pc) {
    assert(switch (verifier::verify(p)) { case .ok(_): { false } case .err(e): { e.kind == 5 && e.offset == pc } });
    assert(switch (vm::run(p, 1000)) { case .ok(_): { false } case .err(e): { e.kind == 5 && e.offset == pc } });
}
@test
fn void all_register_bits_and_nonzero_function_ranges_remain_distinct() {
    var ir::Program p = ir::empty();
    var usize i = 0;
    while (i < 128) { let usize r = built(ir::literal(ref mut p, 42, 0)); i += 1; }
    let usize returned = built(ir::emit(ref mut p, 8, 127, 0, 0)); finish(ref mut p);
    result(ref p);
    var ir::Program bad = p;
    bad.code[127 * 8 + 1] = 63; rejected(ref bad, 127);
    bad = p; bad.code[127 * 8 + 1] = 64; rejected(ref bad, 127);

    p = ir::empty(); i = 0;
    while (i < 128) {
        let usize r = built(ir::literal(ref mut p, 42, 0)); i += 1;
        if (i == 64 || i == 128) { let usize end = built(ir::emit(ref mut p, 8, i - 1, 0, 0)); }
    }
    p.function_count = 2; p.entry = 1;
    p.ends[0] = 65; p.starts[1] = 65; p.ends[1] = 130;
    p.register_ends[0] = 64; p.register_starts[1] = 64; p.register_ends[1] = 128;
    p.return_types[0] = 1; p.return_types[1] = 1;
    result(ref p);
    bad = p; bad.code[129 * 8 + 2] = 63; rejected(ref bad, 129);
}

fn ir::Program joined(usize slot, bool initialized, bool backedge) {
    var ir::Program p = ir::empty();
    // Reserve r0 for the eventual load without defining it on the skipped path.
    let usize hole = built(ir::slot(ref mut p, 1, 0)); p.slots[hole] = false;
    while (p.registers < slot - 1) { let usize r = built(ir::literal(ref mut p, 42, 0)); }
    let usize condition = built(ir::boolean(ref mut p, true, 0));
    let usize binding = built(ir::slot(ref mut p, 1, 0)); assert(binding == slot);
    if (initialized) { let usize store = built(ir::raw(ref mut p, 18, binding, 1, 0, 0)); }
    let usize branch = built(ir::raw(ref mut p, 20, 0, condition, 0, 0));
    let usize store = built(ir::raw(ref mut p, 18, binding, 1, 0, 0));
    let usize header = p.count;
    let usize load = built(ir::raw(ref mut p, 17, hole, binding, 0, 0));
    if (backedge) {
        let usize target = p.count;
        let usize patched = built(ir::patch(ref mut p, branch, target, 0));
        let usize back = built(ir::raw(ref mut p, 22, 0, header, 0, 0));
    } else {
        let usize patched = built(ir::patch(ref mut p, branch, header, 0));
        let usize end = built(ir::emit(ref mut p, 8, hole, 0, 0));
    }
    finish(ref mut p); return p;
}
@test
fn void joins_intersect_both_words_without_leaking_conditional_definitions() {
    let usize[3] boundaries = [63, 64, 127];
    var usize i = 0;
    while (i < 3) {
        let ir::Program good = joined(boundaries[i], true, false); result(ref good);
        let ir::Program bad = joined(boundaries[i], false, false); rejected(ref bad, bad.count - 2);
        i += 1;
    }
}
@test
fn void backedges_preserve_required_bits_in_both_words() {
    let usize[3] boundaries = [63, 64, 127];
    var usize i = 0;
    while (i < 3) {
        let ir::Program bad = joined(boundaries[i], false, true); rejected(ref bad, bad.count - 1);
        i += 1;
    }
}

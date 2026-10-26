module tests::m2::struct_vm;
import ir as ir;
import vm as vm;
import struct_vm as records;
import struct_meta as meta;
import array_vm as arrays;
import array_owners as owners;
import array_layout as layouts;
import errors as errors;
import std::bytes as bytes;

fn usize size(Result<usize, errors::Error> value) {
    return switch (value) { case .ok(n): { n } case .err(_): { assert(false); 0 } };
}
fn usize work(u8 op) { return size(records::cost(op, 0)); }
fn bytes::Buffer payload(usize capacity) {
    return switch (arrays::prepare(capacity)) { case .ok(n): { n } case .err(_): { assert(false); bytes::empty() } };
}
fn meta::Catalog catalog(u8 tag) {
    var meta::Catalog c = meta::empty(); c.count = 2;
    c.layouts.count = 2; c.layouts.fields[0] = 2; c.layouts.kinds[0] = 1; c.layouts.types[0] = 1;
    c.layouts.types[1] = 2; c.layouts.fields[1] = 1; c.layouts.types[16] = tag;
    c.mutable[0] = true; c.mutable[1] = true; return c;
}
fn void step(u8 op, usize dst, usize a, usize b, ref meta::Catalog c,
    ref mut records::State state, ref mut arrays::State shared, ref mut bytes::Buffer data, ref mut i64[] cells) {
    assert(size(records::step(op, dst, a, b, 0, c, state, shared, data, cells, work(op), 123)) == 0);
}
fn bool failure(Result<usize, errors::Error> value, u8 kind) {
    return switch (value) { case .ok(_): { false } case .err(e): { e.kind == kind && e.offset == 123 } };
}
fn void unchanged(ref records::State now, ref records::State before, ref arrays::State shared, ref arrays::State prior) {
    assert(shared.owners.depth == prior.owners.depth && shared.owners.arena.used == prior.owners.arena.used && shared.owners.arena.limit == prior.owners.arena.limit);
    var usize i = 0;
    while (i < 16) {
        assert(now.tokens[i].slot == before.tokens[i].slot && now.tokens[i].generation == before.tokens[i].generation);
        let owners::Owner a = shared.owners.slots[i]; let owners::Owner b = prior.owners.slots[i];
        assert(a.generation == b.generation && a.occupied == b.occupied && a.live == b.live);
        assert(a.mark == b.mark && a.base == b.base && a.end == b.end && a.element == b.element);
        assert(a.length == b.length && a.record == b.record && a.alignment == b.alignment);
        assert(shared.owners.order[i] == prior.owners.order[i]); i += 1;
    }
}

@test
fn void nested_all_six_scalars_copy_assign_and_survive_source_release() {
    let u8[6] tags = [1, 2, 9, 10, 11, 12];
    let i64[6] values = [-2147483648, 1, -9223372036854775808, 255, 4294967295, -1];
    var usize i = 0;
    while (i < 6) {
        let meta::Catalog c = catalog(tags[i]);
        var records::State state = records::empty(); var arrays::State shared = arrays::empty(64);
        var bytes::Buffer data = payload(64);
        var i64[4] cells = [0; 4]; cells[0] = values[i]; cells[1] = 1; cells[2] = if (tags[i] == 2) { 0 } else { 42 };
        step(41, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
        step(42, 1, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
        step(44, 0, 0, 2, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
        step(43, 3, 1, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells); assert(cells[3] == values[i]);
        step(46, 1, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
        step(43, 3, 1, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells); assert(cells[3] == cells[2]);
        step(46, 1, 1, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
        step(45, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
        step(43, 3, 1, 1, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells); assert(cells[3] == 1);
        step(45, 1, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
        assert(shared.owners.depth == 0 && shared.owners.arena.used == 0); i += 1;
    }
}

@test
fn void every_opcode_prepays_before_tokens_bytes_registers_or_metadata_change() {
    let u8[6] ops = [41, 42, 43, 44, 45, 46];
    var usize i = 0;
    while (i < 6) {
        var meta::Catalog c = catalog(1); c.count = 3; c.mutable[2] = true;
        var records::State state = records::empty(); var arrays::State shared = arrays::empty(64);
        var bytes::Buffer data = payload(64); var i64[4] cells = [42, 1, 99, -7];
        step(41, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
        step(41, 1, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
        let records::State before = state; let arrays::State prior = shared;
        var u8[64] saved = [0; 64];
        { let ref u8[] view = bytes::view(ref data); var usize j = 0; while (j < 64) { saved[j] = view[j]; j += 1; } }
        let u8 op = ops[i];
        let usize dst = if (op == 41 || op == 42) { 2 } else if (op == 43) { 3 } else { 0 };
        let usize a = if (op == 46) { 1 } else { 0 }; let usize b = if (op == 44) { 2 } else { 0 };
        assert(failure(records::step(op, dst, a, b, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells, work(op) - 1, 123), 8));
        unchanged(ref state, ref before, ref shared, ref prior);
        assert(cells[0] == 42 && cells[1] == 1 && cells[2] == 99 && cells[3] == -7);
        { let ref u8[] view = bytes::view(ref data); var usize j = 0; while (j < 64) { assert(view[j] == saved[j]); j += 1; } }
        step(op, dst, a, b, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells); i += 1;
    }
    assert(!records::cost(47, 0).is_ok);
}

@test
fn void full_payload_and_shared_array_owner_pressure_preserve_failed_creation() {
    let meta::Catalog c = catalog(1); var i64[4] cells = [42, 1, 0, 0];
    var records::State state = records::empty(); var arrays::State shared = arrays::empty(8); var bytes::Buffer data = payload(8);
    step(41, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
    let records::State before = state; let arrays::State prior = shared;
    assert(failure(records::step(42, 1, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells, work(42), 123), 13));
    unchanged(ref state, ref before, ref shared, ref prior);
    step(46, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells); unchanged(ref state, ref before, ref shared, ref prior);
    state = records::empty(); shared = arrays::empty(64); data = payload(64);
    let layouts::Array layout = switch (layouts::scalar(10, 1)) { case .ok(n): { n } case .err(_): { assert(false); layouts::Array { .element = 10, .length = 1, .stride = 1, .alignment = 1, .bytes = 1 } } };
    var usize i = 0;
    while (i < 16) {
        let owners::Token token = switch (owners::create(ref layout, 0, bytes::view_mut(ref mut data), ref mut shared.owners)) {
            case .ok(n): { n } case .err(_): { assert(false); owners::Token { .slot = 0, .generation = 0 } }
        }; i += 1;
    }
    let arrays::State saturated = shared; let records::State dead = state;
    assert(failure(records::step(41, 0, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells, work(41), 123), 13));
    unchanged(ref state, ref dead, ref shared, ref saturated);
}

@test
fn void corrupt_bools_stale_tokens_and_nominal_substitution_are_rejected_atomically() {
    var meta::Catalog c = catalog(1); var i64[4] cells = [42, 1, 0, -7];
    var records::State state = records::empty(); var arrays::State shared = arrays::empty(32); var bytes::Buffer data = payload(32);
    step(41, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
    { let ref mut u8[] view = bytes::view_mut(ref mut data); view[4] = 2; }
    let records::State before = state; let arrays::State prior = shared;
    assert(failure(records::step(42, 1, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells, work(42), 123), 5));
    unchanged(ref state, ref before, ref shared, ref prior);
    assert(failure(records::step(43, 3, 0, 1, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells, work(43), 123), 5)); assert(cells[3] == -7);
    { let ref mut u8[] view = bytes::view_mut(ref mut data); view[4] = 1; }
    let owners::Token stale = state.tokens[0];
    step(45, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
    step(41, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
    state.tokens[1] = stale;
    assert(failure(records::step(43, 3, 1, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells, work(43), 123), 5));
    // Change only the binding identity to another physically identical definition.
    c.layouts.count = 3; c.layouts.fields[2] = 2; c.layouts.kinds[32] = 1; c.layouts.types[32] = 1; c.layouts.types[33] = 2;
    c.records[0] = 2;
    assert(failure(records::step(45, 0, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells, work(45), 123), 5));
    assert(shared.owners.depth == 1 && cells[3] == -7);
}

fn void finish(ref mut ir::Program p) {
    let usize count = p.count; let usize registers = p.registers;
    p.function_count = 1; p.return_types[0] = 1; p.ends[0] = count; p.register_ends[0] = registers;
}
fn ir::Program program() {
    var ir::Program p = ir::empty(); p.records = catalog(1);
    let usize value = size(ir::literal(ref mut p, 42, 0)); let usize flag = size(ir::boolean(ref mut p, true, 0));
    let usize init = size(ir::record_init(ref mut p, 0, value, 0)); let usize copy = size(ir::record_copy(ref mut p, 1, 0, 0));
    let usize replacement = size(ir::literal(ref mut p, 99, 0)); let usize write = size(ir::record_write(ref mut p, 0, 0, replacement, 0));
    let usize assign = size(ir::record_assign(ref mut p, 1, 0, 0)); let usize read = size(ir::record_read(ref mut p, 1, 0, 0));
    let usize drop = size(ir::record_drop(ref mut p, 0, 0)); let usize last = size(ir::record_drop(ref mut p, 1, 0));
    let usize ret = size(ir::emit(ref mut p, 8, read, 0, 0)); finish(ref mut p); return p;
}
fn void returned(Result<i64, errors::Error> result, i64 expected) {
    assert(switch (result) { case .ok(n): { n == expected } case .err(_): { false } });
}
fn bool trapped(Result<i64, errors::Error> result, u8 kind) {
    return switch (result) { case .err(e): { e.kind == kind } case .ok(_): { false } };
}

@test
fn void actual_dispatch_uses_exact_fuel_and_quota_failures_do_not_poison_later_runs() {
    let ir::Program p = program();
    let usize fuel = 231452;
    assert(fuel == 17 + 4 + work(41) + work(42) + work(43) + work(44) + work(46) + 2 * work(45));
    returned(vm::run_with_array_limit(ref p, fuel, 16), 99);
    assert(trapped(vm::run_with_array_limit(ref p, fuel - 1, 16), 8));
    assert(trapped(vm::run_with_array_limit(ref p, 1000000, 15), 13));
    assert(trapped(vm::run_with_array_limit(ref p, 0, 16), 8));
    assert(trapped(vm::run_with_array_limit(ref p, 1000000, 65537), 13));
    returned(vm::run_with_array_limit(ref p, fuel, 16), 99);
}

@test
fn void entry_records_survive_scalar_callees_that_use_the_same_array_arena() {
    var ir::Program p = ir::empty(); p.records = catalog(1); p.function_count = 2; p.return_types[0] = 1; p.return_types[1] = 1;
    let usize array = size(ir::array_in(ref mut p, 1, 1, 1, false, 0));
    let usize value = size(ir::literal(ref mut p, 42, 0)); let usize flag = size(ir::boolean(ref mut p, true, 0));
    let usize init = size(ir::record_init(ref mut p, 0, value, 0));
    let usize[1] args = [0]; let usize call = size(ir::call(ref mut p, 1, ref args[..0], 0));
    let usize write = size(ir::record_write(ref mut p, 0, 0, call, 0)); let usize read = size(ir::record_read(ref mut p, 0, 0, 0));
    let usize drop = size(ir::record_drop(ref mut p, 0, 0)); let usize ret = size(ir::emit(ref mut p, 8, read, 0, 0));
    let usize entry_end = p.count; let usize entry_registers = p.registers;
    p.ends[0] = entry_end; p.register_ends[0] = entry_registers; p.starts[1] = entry_end; p.register_starts[1] = entry_registers;
    let usize fill = size(ir::literal(ref mut p, 77, 0)); let usize create = size(ir::array_init(ref mut p, array, fill, 0));
    let usize index = size(ir::integer(ref mut p, 0, 12, 0)); let usize result = size(ir::array_read(ref mut p, array, index, 0));
    let usize release = size(ir::array_drop(ref mut p, array, 0)); let usize returned_array = size(ir::emit(ref mut p, 8, result, 0, 0));
    let usize end = p.count; let usize registers = p.registers; p.ends[1] = end; p.register_ends[1] = registers;
    returned(vm::run_with_array_limit(ref p, 1000000, 12), 77);
    assert(trapped(vm::run_with_array_limit(ref p, 1000000, 11), 13));
}

@test
fn void iterative_leaf_paths_cover_depth_sixteen_and_all_128_leaves() {
    var meta::Catalog c = meta::empty(); c.count = 1; c.mutable[0] = true; c.layouts.count = 16;
    let u8[16] children = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 10];
    var usize i = 0;
    while (i < 16) { c.layouts.fields[i] = 1; c.layouts.types[i * 16] = children[i]; c.layouts.kinds[i * 16] = if (i == 15) { 0 } else { 1 }; i += 1; }
    var records::State state = records::empty(); var arrays::State shared = arrays::empty(128); var bytes::Buffer data = payload(128);
    var i64[128] cells = [0; 128]; cells[0] = 255; cells[1] = 42;
    step(41, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
    step(44, 0, 0, 1, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
    step(43, 2, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells); assert(cells[2] == 42);
    step(45, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
    c = meta::empty(); c.count = 1; c.layouts.count = 2; c.layouts.fields[0] = 8; c.layouts.fields[1] = 16;
    i = 0;
    while (i < 16) { c.layouts.types[16 + i] = 10; if (i < 8) { c.layouts.kinds[i] = 1; c.layouts.types[i] = 1; } i += 1; }
    cells = [0; 128]; cells[127] = 255;
    step(41, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
    step(43, 0, 0, 127, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells); assert(cells[0] == 255);
    assert(shared.owners.arena.used == 128);
}

@test
fn void full_record_table_assignment_and_deferred_holes_preserve_shared_limits() {
    var meta::Catalog c = catalog(1); c.count = 16;
    var records::State state = records::empty(); var arrays::State shared = arrays::empty(128); var bytes::Buffer data = payload(128);
    var i64[3] cells = [42, 1, 0]; var usize i = 0;
    while (i < 16) { c.mutable[i] = true; step(41, i, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells); i += 1; }
    step(46, 15, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
    assert(shared.owners.depth == 16 && shared.owners.arena.used == 128);
    step(45, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
    assert(failure(records::step(41, 0, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells, work(41), 123), 13));
    i = 16;
    while (i > 1) { i -= 1; step(45, i, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells); }
    assert(shared.owners.depth == 0 && shared.owners.arena.used == 0);
    step(41, 0, 0, 0, ref c, ref mut state, ref mut shared, ref mut data, ref mut cells);
    assert(state.tokens[0].generation == 2);
}

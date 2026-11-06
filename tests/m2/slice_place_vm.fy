module tests::m2::slice_place_vm;

import slice_place_vm as execution;
import place_vm as legacy;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import slice_handoff as handoff;
import slice_reborrow as reborrow;
import slice_builders as builders;
import ir as ir;
import errors as errors;
import std::vec as vec;

fn usize built(Result<usize,errors::Error> r) {
    return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } };
}
fn owners::Token token(Result<owners::Token,owners::Error> r) {
    return switch(r) { case .ok(v): { v }
        case .err(_): { assert(false); owners::Token { .slot = 16, .generation = 0 } } };
}
fn slices::Ticket opened(Result<slices::Ticket,owners::Error> r) {
    return switch(r) { case .ok(v): { v }
        case .err(_): { assert(false); slices::Ticket { .slot = 16, .generation = 0 } } };
}
fn slices::Arguments returned(Result<slices::Arguments,owners::Error> r) {
    return switch(r) { case .ok(v): { v } case .err(_): { assert(false); slices::empty_arguments() } };
}
fn handoff::Batch batch(Result<handoff::Batch,owners::Error> r) {
    return switch(r) { case .ok(v): { v } case .err(_): { assert(false); handoff::empty() } };
}
fn reborrow::Loan loan(Result<reborrow::Loan,owners::Error> r) {
    return switch(r) { case .ok(v): { v } case .err(_): { assert(false); reborrow::empty() } };
}
fn usize size(Result<usize,owners::Error> r) {
    return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } };
}
fn i64 cell(Result<i64,owners::Error> r) {
    return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } };
}
fn execution::Requirement required(ref ir::Program p) {
    return switch(execution::requirement(p)) {
        case .ok(v): { v }
        case .err(_): { assert(false); execution::Requirement { .width = 0, .slices = false, .cost = 0 } }
    };
}
fn vec::Vec<usize> prepared_plan(ref execution::Requirement plan) {
    return switch(execution::prepare(plan)) {
        case .ok(v): { v } case .err(_): { assert(false); vec::empty<usize>() }
    };
}
fn vec::Vec<usize> prepared(ref ir::Program p) {
    var execution::Requirement plan = required(p);
    return prepared_plan(ref plan);
}
fn vec::Vec<usize> legacy_prepared(ref legacy::Requirement plan) {
    return switch(legacy::prepare(plan)) {
        case .ok(v): { v } case .err(_): { assert(false); vec::empty<usize>() }
    };
}
fn void failed(Result<usize,errors::Error> r,u8 kind,usize offset) {
    assert(switch(r) { case .ok(_): { false } case .err(e): { e.kind == kind && e.offset == offset } });
}
fn void refused(Result<usize,errors::Error> r) { assert(!r.is_ok); }
fn void rejected(Result<execution::Requirement,errors::Error> r) { assert(!r.is_ok); }
fn void finish(ref mut ir::Program p,usize function) {
    let usize end = p.count; let usize regs = p.registers;
    p.ends[function] = end; p.register_ends[function] = regs;
}
fn usize tagged(ref mut ir::Program p,u8 op,usize dst,usize a,usize b) {
    let usize pc = built(ir::raw(p,op,dst,a,b,77));
    p.code[pc*8+4] = 1;
    return pc;
}
fn ir::Program unit(u8 tag) {
    var ir::Program p = ir::empty(); p.function_count = 1; p.entry = 0;
    let usize root = built(ir::array(ref mut p,tag,2,true,77));
    let usize site = built(ir::exclusive_slice(ref mut p,root,77));
    let usize selected = tagged(ref mut p,83,0,site,0);
    let usize read = tagged(ref mut p,84,1,0,site);
    let usize stored = tagged(ref mut p,85,0,site,2);
    let usize ended = built(ir::raw(ref mut p,86,0,0,0,77));
    finish(ref mut p,0); return p;
}
fn ir::Program array_unit(u8 tag) {
    var ir::Program p = ir::empty(); p.function_count = 1; p.entry = 0;
    let usize root = built(ir::array(ref mut p,tag,2,true,77));
    let usize selected = built(ir::raw(ref mut p,83,0,root,0,77));
    let usize read = built(ir::raw(ref mut p,84,1,0,root,77));
    let usize stored = built(ir::raw(ref mut p,85,0,root,2,77));
    let usize ended = built(ir::raw(ref mut p,86,0,0,0,77));
    finish(ref mut p,0); return p;
}
fn owners::Token created(ref mut owners::Table table,u8 tag,usize length,i64 fill,
    ref mut u8[] data) {
    let layouts::Array shape = switch(layouts::scalar(tag,length)) {
        case .ok(v): { v } case .err(_): { assert(false);
            layouts::Array { .element = 10, .length = 1, .stride = 1, .alignment = 1, .bytes = 1 } }
    };
    return token(owners::create(ref shape,fill,data,table));
}
fn i64 value(ref owners::Table table,owners::Token root,usize index,ref u8[] data) {
    return cell(owners::read(table,root,index,data));
}
fn i64 sliced(ref slices::Pool pool,slices::Ticket ticket,ref owners::Table table,
    usize index,ref u8[] data) {
    return cell(slices::read(pool,ticket,table,index,data));
}
fn void copy_bytes(ref u8[] data,ref mut u8[] saved) {
    let usize count = if(data.len < saved.len) { data.len } else { saved.len };
    var usize i = 0; while(i < count) { saved[i] = data[i]; i += 1; }
}
fn void same_bytes(ref u8[] a,ref u8[] b) {
    let usize count = if(a.len < b.len) { a.len } else { b.len };
    var usize i = 0; while(i < count) { assert(a[i] == b[i]); i += 1; }
}

@test
fn void six_scalar_slices_publish_bound_phases_at_independently_priced_exact_fuel() {
    let u8[6] tags = [1,2,9,10,11,12];
    let usize[6] reads = [4166,4163,4170,4163,4166,4170];
    let usize[6] writes = [4170,4164,4178,4164,4170,4178];
    var usize i = 0;
    while(i < 6) {
        let ir::Program p = unit(tags[i]);
        var execution::Requirement plan = required(ref p);
        assert(plan.width == 1 && plan.slices && plan.cost == 5067);
        var vec::Vec<usize> state = prepared(ref p);
        assert(vec::len<usize>(ref state) == 481);
        assert(vec::view_usize(ref state)[0] == 14337);
        assert(built(execution::cost(ref p,0,true)) == 4129);
        var u8[32] data = [85;32]; var owners::Table table = owners::empty(32);
        let i64 initial = if(tags[i] == 2) { 0 } else { 20 };
        let i64 result = if(tags[i] == 2) { 1 } else { 42 };
        let owners::Token root = created(ref mut table,tags[i],2,initial,ref mut data);
        var owners::Token[512] tokens = [owners::Token { .slot = 16, .generation = 0 };512];
        tokens[0] = root;
        var slices::Pool pool = slices::empty();
        let slices::Ticket ticket = opened(slices::open_exclusive(
            ref mut pool,ref mut table,root,0,2,32));
        var i64[3] registers = [0,777,result];
        failed(execution::step(ref p,0,0,0,ref mut state,ref table,ref tokens,
            ref pool,ticket,ref mut data,ref mut registers,4128),8,77);
        assert(vec::view_usize(ref state)[1] == 0);
        assert(built(execution::step(ref p,0,0,0,ref mut state,ref table,ref tokens,
            ref pool,ticket,ref mut data,ref mut registers,4129)) == 0);
        {
            let ref usize[] words = vec::view_usize(ref state);
            assert(words[1] == 1 && words[2+13] == (tags[i] as usize)+256+1024);
            assert(words[2+2] == 2 && words[2+6] == ticket.slot && words[2+7] == ticket.generation);
        }
        failed(execution::step(ref p,1,0,0,ref mut state,ref table,ref tokens,
            ref pool,ticket,ref mut data,ref mut registers,reads[i]-1),8,77);
        assert(registers[1] == 777 && ((vec::view_usize(ref state)[2+13]>>8)&3) == 1);
        assert(built(execution::step(ref p,1,0,0,ref mut state,ref table,ref tokens,
            ref pool,ticket,ref mut data,ref mut registers,reads[i])) == 0);
        assert(registers[1] == initial && ((vec::view_usize(ref state)[2+13]>>8)&3) == 2);
        failed(execution::step(ref p,2,0,0,ref mut state,ref table,ref tokens,
            ref pool,ticket,ref mut data,ref mut registers,writes[i]-1),8,77);
        assert(sliced(ref pool,ticket,ref table,0,ref data) == initial);
        assert(((vec::view_usize(ref state)[2+13]>>8)&3) == 2);
        assert(built(execution::step(ref p,2,0,0,ref mut state,ref table,ref tokens,
            ref pool,ticket,ref mut data,ref mut registers,writes[i])) == 0);
        assert(((vec::view_usize(ref state)[2+13]>>8)&3) == 3);
        failed(execution::step(ref p,3,0,0,ref mut state,ref table,ref tokens,
            ref pool,ticket,ref mut data,ref mut registers,21),8,77);
        assert(((vec::view_usize(ref state)[2+13]>>8)&3) == 3);
        assert(built(execution::step(ref p,3,0,0,ref mut state,ref table,ref tokens,
            ref pool,ticket,ref mut data,ref mut registers,22)) == 0);
        {
            let ref usize[] words = vec::view_usize(ref state);
            assert(words[1] == 0);
            var usize row = 0; while(row < 14) { assert(words[2+row] == 0); row += 1; }
        }
        assert(sliced(ref pool,ticket,ref table,0,ref data) == result);
        assert(sliced(ref pool,ticket,ref table,1,ref data) == initial);
        let usize closed = size(slices::close(ref mut pool,ticket,ref mut table,32));
        i += 1;
    }
}

@test
fn void completed_call_and_lexical_restoration_keep_the_original_place_target() {
    let ir::Program p = unit(10);
    var vec::Vec<usize> state = prepared(ref p);
    var u8[16] data = [20;16]; var owners::Table table = owners::empty(16);
    let owners::Token root = created(ref mut table,10,2,20,ref mut data);
    var owners::Token[512] tokens = [owners::Token { .slot = 16, .generation = 0 };512];
    tokens[0] = root;
    var slices::Pool pool = slices::empty();
    let slices::Ticket original = opened(slices::open_exclusive(
        ref mut pool,ref mut table,root,0,2,16));
    var i64[3] registers = [1,777,42];
    let usize selected = built(execution::step(ref p,0,0,0,ref mut state,ref table,ref tokens,
        ref pool,original,ref mut data,ref mut registers,4129));
    let usize old = built(execution::step(ref p,1,0,0,ref mut state,ref table,ref tokens,
        ref pool,original,ref mut data,ref mut registers,4163));
    assert(registers[1] == 20);
    let slices::Ticket[1] sources = [original];
    var handoff::Batch receipt = batch(handoff::begin(
        ref mut pool,ref sources,ref table,16,0));
    let slices::Ticket child = receipt.tickets[0];
    let slices::Ticket[1] children = [child];
    var slices::Arguments call_back = returned(handoff::restore(
        ref mut pool,ref mut receipt,ref children,ref table,16));
    let slices::Ticket call_resumed = call_back.tickets[0];
    let usize stored = built(execution::step(ref p,2,0,0,ref mut state,ref table,ref tokens,
        ref pool,call_resumed,ref mut data,ref mut registers,4164));
    let usize ended_call = built(execution::step(ref p,3,0,0,ref mut state,ref table,ref tokens,
        ref pool,call_resumed,ref mut data,ref mut registers,22));
    let usize selected_again = built(execution::step(ref p,0,0,0,ref mut state,ref table,ref tokens,
        ref pool,call_resumed,ref mut data,ref mut registers,4129));
    var reborrow::Loan lexical = loan(reborrow::begin(
        ref mut pool,call_resumed,ref table,1,2,16,0));
    let slices::Ticket narrowed = lexical.issued;
    let slices::Ticket lexical_resumed = opened(reborrow::restore(
        ref mut pool,ref mut lexical,narrowed,ref table,16));
    let usize old_again = built(execution::step(ref p,1,0,0,ref mut state,ref table,ref tokens,
        ref pool,lexical_resumed,ref mut data,ref mut registers,4163));
    assert(registers[1] == 42);
    let usize ended_lexical = built(execution::step(ref p,3,0,0,ref mut state,ref table,ref tokens,
        ref pool,lexical_resumed,ref mut data,ref mut registers,22));
    assert(sliced(ref pool,lexical_resumed,ref table,0,ref data) == 20);
    assert(sliced(ref pool,lexical_resumed,ref table,1,ref data) == 42);
    let usize closed = size(slices::close(ref mut pool,lexical_resumed,ref mut table,16));
}

@test
fn void stale_reopened_borrowed_session_shape_and_encoding_failures_are_atomic() {
    var ir::Program p = unit(10);
    var vec::Vec<usize> state = prepared(ref p);
    var u8[32] data = [0;32]; var owners::Table table = owners::empty(32);
    let owners::Token root = created(ref mut table,10,2,20,ref mut data);
    let owners::Token other = created(ref mut table,10,2,90,ref mut data);
    var owners::Token[512] tokens = [owners::Token { .slot = 16, .generation = 0 };512];
    tokens[0] = root; tokens[1] = other;
    var slices::Pool pool = slices::empty();
    let slices::Ticket ticket = opened(slices::open_exclusive(
        ref mut pool,ref mut table,root,0,2,32));
    var i64[3] registers = [1,777,42];
    registers[0] = 2;
    refused(execution::step(ref p,0,0,0,ref mut state,ref table,ref tokens,
        ref pool,ticket,ref mut data,ref mut registers,4129));
    assert(vec::view_usize(ref state)[1] == 0);
    registers[0] = 1;
    let usize selected = built(execution::step(ref p,0,0,0,ref mut state,ref table,ref tokens,
        ref pool,ticket,ref mut data,ref mut registers,4129));
    let slices::Ticket[1] sources = [ticket];
    var handoff::Batch receipt = batch(handoff::begin(
        ref mut pool,ref sources,ref table,32,0));
    let slices::Ticket child = receipt.tickets[0];
    var u8[32] saved = [0;32]; copy_bytes(ref data,ref mut saved);
    refused(execution::step(ref p,2,0,0,ref mut state,ref table,ref tokens,
        ref pool,ticket,ref mut data,ref mut registers,4164));
    assert(((vec::view_usize(ref state)[2+13]>>8)&3) == 1);
    same_bytes(ref data,ref saved);
    let slices::Ticket[1] children = [child];
    var slices::Arguments call_back = returned(handoff::restore(
        ref mut pool,ref mut receipt,ref children,ref table,32));
    let slices::Ticket resumed = call_back.tickets[0];
    let slices::Ticket ignored = slices::Ticket { .slot = 16, .generation = 0 };
    let usize abandoned = built(execution::step(ref p,3,0,0,ref mut state,ref table,ref tokens,
        ref pool,ignored,ref mut data,ref mut registers,22));
    let usize reselected = built(execution::step(ref p,0,0,0,ref mut state,ref table,ref tokens,
        ref pool,resumed,ref mut data,ref mut registers,4129));
    let usize closed_old = size(slices::close(ref mut pool,resumed,ref mut table,32));
    let slices::Ticket fresh = opened(slices::open_exclusive(
        ref mut pool,ref mut table,root,0,2,32));
    refused(execution::step(ref p,2,0,0,ref mut state,ref table,ref tokens,
        ref pool,fresh,ref mut data,ref mut registers,4164));
    assert(((vec::view_usize(ref state)[2+13]>>8)&3) == 1);
    assert(sliced(ref pool,fresh,ref table,0,ref data) == 20);
    let usize clean = built(execution::step(ref p,3,0,0,ref mut state,ref table,ref tokens,
        ref pool,ignored,ref mut data,ref mut registers,22));
    registers[0] = 2;
    refused(execution::step(ref p,0,0,0,ref mut state,ref table,ref tokens,
        ref pool,fresh,ref mut data,ref mut registers,4129));
    registers[0] = 1;
    var ir::Program short = p; short.arrays.lengths[0] = 1;
    refused(execution::step(ref short,0,0,0,ref mut state,ref table,ref tokens,
        ref pool,fresh,ref mut data,ref mut registers,4129));
    var ir::Program wrong_type = p; wrong_type.arrays.elements[0] = 1;
    refused(execution::step(ref wrong_type,0,0,0,ref mut state,ref table,ref tokens,
        ref pool,fresh,ref mut data,ref mut registers,4129));
    let usize reselected_fresh = built(execution::step(ref p,0,0,0,ref mut state,ref table,ref tokens,
        ref pool,fresh,ref mut data,ref mut registers,4129));
    let slices::Ticket future = slices::Ticket {
        .slot = fresh.slot, .generation = fresh.generation+1 };
    refused(execution::step(ref p,2,0,0,ref mut state,ref table,ref tokens,
        ref pool,future,ref mut data,ref mut registers,4164));
    let slices::Ticket outsider = opened(slices::open_exclusive(
        ref mut pool,ref mut table,other,0,2,32));
    refused(execution::step(ref p,2,0,0,ref mut state,ref table,ref tokens,
        ref pool,outsider,ref mut data,ref mut registers,4164));
    registers[2] = 2147483648;
    refused(execution::step(ref p,2,0,0,ref mut state,ref table,ref tokens,
        ref pool,fresh,ref mut data,ref mut registers,4164));
    assert(((vec::view_usize(ref state)[2+13]>>8)&3) == 1);
    assert(sliced(ref pool,fresh,ref table,1,ref data) == 20);
    let usize closed_other = size(slices::close(ref mut pool,outsider,ref mut table,32));
    let usize closed_fresh = size(slices::close(ref mut pool,fresh,ref mut table,32));
}

@test
fn void explicit_prefix_layout_bounds_and_frame31_slot15_reuse_stay_exact() {
    var ir::Program p = ir::empty(); p.function_count = 1; p.entry = 0;
    p.arrays.count = 16; var usize i = 0;
    while(i < 16) {
        p.arrays.elements[i] = 10; p.arrays.lengths[i] = 2;
        p.arrays.mutable[i] = true; p.array_functions[i] = 0; i += 1;
    }
    p.slice_roots[0] = 16; p.slice_elements[0] = 128;
    let usize selected = tagged(ref mut p,83,15,0,0);
    let usize read = tagged(ref mut p,84,1,15,0);
    let usize stored = tagged(ref mut p,85,15,0,2);
    let usize ended = built(ir::raw(ref mut p,86,15,0,0,77));
    finish(ref mut p,0);
    var execution::Requirement plan = required(ref p);
    assert(plan.width == 16 && plan.slices && plan.cost == 72267);
    var vec::Vec<usize> state = prepared(ref p);
    assert(vec::len<usize>(ref state) == 7201);
    assert(vec::view_usize(ref state)[0] == 14352);
    let usize header = 1+31*(14*16+1); let usize base = header+1+14*15;
    assert(header == 6976 && base == 7187 && base+13 == 7200);
    assert(built(legacy::empty_frame(ref state,31,77)) == 31);
    assert(!legacy::empty_frame(ref state,32,77).is_ok);
    var u8[32] data = [0;32]; var owners::Table table = owners::empty(32);
    let owners::Token root = created(ref mut table,10,2,20,ref mut data);
    var owners::Token[512] tokens = [owners::Token { .slot = 16, .generation = 0 };512];
    tokens[511] = root;
    var slices::Pool pool = slices::empty();
    let slices::Ticket ticket = opened(slices::open_exclusive(
        ref mut pool,ref mut table,root,0,2,32));
    var i64[3] registers = [0,777,42];
    i = 0;
    while(i < 3) {
        failed(execution::step(ref p,selected,0,31,ref mut state,ref table,ref tokens,
            ref pool,ticket,ref mut data,ref mut registers,4128),8,77);
        let usize one = built(execution::step(ref p,selected,0,31,ref mut state,ref table,ref tokens,
            ref pool,ticket,ref mut data,ref mut registers,4129));
        assert(vec::view_usize(ref state)[header] == 1);
        failed(execution::step(ref p,ended,0,31,ref mut state,ref table,ref tokens,
            ref pool,slices::Ticket { .slot = 16, .generation = 0 },
            ref mut data,ref mut registers,21),8,77);
        let usize zero = built(execution::step(ref p,ended,0,31,ref mut state,ref table,ref tokens,
            ref pool,slices::Ticket { .slot = 16, .generation = 0 },
            ref mut data,ref mut registers,22));
        assert(vec::view_usize(ref state)[header] == 0);
        assert(vec::view_usize(ref state)[base] == 0 && vec::view_usize(ref state)[base+13] == 0);
        i += 1;
    }
    assert(built(execution::cost(ref p,selected,true)) == 4129);
    assert(built(execution::cost(ref p,ended,true)) == 22);
    {
        let ref mut usize[] words = vec::view_mut_usize(ref mut state);
        words[0] = 14351;
    }
    assert(!legacy::empty_frame(ref state,31,77).is_ok);
}

@test
fn void mixed_same_ordinal_collisions_wrong_kinds_and_common_end_are_distinct() {
    var ir::Program p = ir::empty(); p.function_count = 1; p.entry = 0;
    p.arrays.count = 2;
    p.arrays.elements[0] = 10; p.arrays.lengths[0] = 2; p.arrays.mutable[0] = true;
    p.arrays.elements[1] = 10; p.arrays.lengths[1] = 2; p.arrays.mutable[1] = true;
    p.array_functions[0] = 0; p.array_functions[1] = 0;
    p.slice_roots[0] = 2; p.slice_elements[0] = 128;
    let usize array_select = built(ir::raw(ref mut p,83,0,0,0,77));
    let usize array_end = built(ir::raw(ref mut p,86,0,0,0,77));
    let usize slice_select = tagged(ref mut p,83,0,0,0);
    let usize slice_read = tagged(ref mut p,84,1,0,0);
    let usize slice_store = tagged(ref mut p,85,0,0,2);
    let usize slice_end = built(ir::raw(ref mut p,86,0,0,0,77));
    finish(ref mut p,0);
    var vec::Vec<usize> state = prepared(ref p);
    var u8[8] data = [0;8]; var owners::Table table = owners::empty(8);
    let owners::Token first = created(ref mut table,10,2,10,ref mut data);
    let owners::Token second = created(ref mut table,10,2,80,ref mut data);
    var owners::Token[512] tokens = [owners::Token { .slot = 16, .generation = 0 };512];
    tokens[0] = first; tokens[1] = second;
    var slices::Pool pool = slices::empty();
    let slices::Ticket ticket = opened(slices::open_exclusive(
        ref mut pool,ref mut table,second,0,2,8));
    let slices::Ticket ignored = slices::Ticket { .slot = 16, .generation = 0 };
    var i64[3] registers = [0,777,42];
    let usize first_select = built(execution::step(ref p,array_select,0,0,ref mut state,
        ref table,ref tokens,ref pool,ignored,ref mut data,ref mut registers,65));
    assert(vec::view_usize(ref state)[2+13] == 266);
    refused(execution::step(ref p,slice_select,0,0,ref mut state,ref table,ref tokens,
        ref pool,ticket,ref mut data,ref mut registers,4129));
    let usize first_end = built(execution::step(ref p,array_end,0,0,ref mut state,ref table,ref tokens,
        ref pool,ignored,ref mut data,ref mut registers,22));
    assert(vec::view_usize(ref state)[1] == 0);
    let usize reused = built(execution::step(ref p,slice_select,0,0,ref mut state,ref table,ref tokens,
        ref pool,ticket,ref mut data,ref mut registers,4129));
    assert(vec::view_usize(ref state)[2+13] == 1290);
    var ir::Program bad_read = p; bad_read.code[slice_read*8+4] = 0;
    refused(execution::step(ref bad_read,slice_read,0,0,ref mut state,ref table,ref tokens,
        ref pool,ticket,ref mut data,ref mut registers,65));
    assert(((vec::view_usize(ref state)[2+13]>>8)&3) == 1);
    var ir::Program bad_store = p; bad_store.code[slice_store*8+4] = 0;
    refused(execution::step(ref bad_store,slice_store,0,0,ref mut state,ref table,ref tokens,
        ref pool,ticket,ref mut data,ref mut registers,67));
    assert(sliced(ref pool,ticket,ref table,0,ref data) == 80);
    let usize read = built(execution::step(ref p,slice_read,0,0,ref mut state,ref table,ref tokens,
        ref pool,ticket,ref mut data,ref mut registers,4163));
    assert(registers[1] == 80);
    let usize store = built(execution::step(ref p,slice_store,0,0,ref mut state,ref table,ref tokens,
        ref pool,ticket,ref mut data,ref mut registers,4164));
    assert(sliced(ref pool,ticket,ref table,0,ref data) == 42);
    let usize last_end = built(execution::step(ref p,slice_end,0,0,ref mut state,ref table,ref tokens,
        ref pool,ignored,ref mut data,ref mut registers,22));
    assert(vec::view_usize(ref state)[1] == 0 && value(ref table,first,0,ref data) == 10);
    let usize closed = size(slices::close(ref mut pool,ticket,ref mut table,8));
}

@test
fn void preparation_rejects_invalid_plans_and_keeps_pure_array_prices() {
    var ir::Program empty = ir::empty();
    var execution::Requirement zero = required(ref empty);
    assert(zero.width == 0 && !zero.slices && zero.cost == 0);
    var vec::Vec<usize> nothing = prepared_plan(ref zero);
    assert(vec::len<usize>(ref nothing) == 0);
    assert(legacy::empty_frame(ref nothing,31,0).is_ok &&
        !legacy::empty_frame(ref nothing,32,0).is_ok);
    var execution::Requirement bad_zero = execution::Requirement {
        .width = 0, .slices = true, .cost = 0 };
    assert(!execution::prepare(ref bad_zero).is_ok);
    var execution::Requirement too_wide = execution::Requirement {
        .width = 17, .slices = false, .cost = 0 };
    assert(!execution::prepare(ref too_wide).is_ok);
    var execution::Requirement old_cost = execution::Requirement {
        .width = 1, .slices = true, .cost = 3457 };
    assert(!execution::prepare(ref old_cost).is_ok);
    var execution::Requirement new_cost = execution::Requirement {
        .width = 1, .slices = false, .cost = 5067 };
    assert(!execution::prepare(ref new_cost).is_ok);
    var execution::Requirement plain = execution::Requirement {
        .width = 1, .slices = false, .cost = 3457 };
    var vec::Vec<usize> plain_state = prepared_plan(ref plain);
    assert(vec::len<usize>(ref plain_state) == 320 && vec::view_usize(ref plain_state)[0] == 0);
    var execution::Requirement mixed = execution::Requirement {
        .width = 1, .slices = true, .cost = 5067 };
    var vec::Vec<usize> mixed_state = prepared_plan(ref mixed);
    assert(vec::len<usize>(ref mixed_state) == 481 &&
        vec::view_usize(ref mixed_state)[0] == 14337);
    let ir::Program arrays = array_unit(10);
    var execution::Requirement array_plan = required(ref arrays);
    assert(array_plan.width == 1 && !array_plan.slices && array_plan.cost == 3457);
    assert(built(execution::cost(ref arrays,0,false)) == 65);
    assert(built(execution::cost(ref arrays,0,true)) == 65);
    assert(built(execution::cost(ref arrays,1,false)) == 66);
    assert(built(execution::cost(ref arrays,1,true)) == 66);
    assert(built(execution::cost(ref arrays,2,false)) == 67);
    assert(built(execution::cost(ref arrays,2,true)) == 67);
    assert(built(execution::cost(ref arrays,3,false)) == 17);
    assert(built(execution::cost(ref arrays,3,true)) == 22);
    let usize legacy_width = switch(legacy::requirement(ref arrays)) {
        case .ok(v): { v.width } case .err(_): { assert(false); 0 } };
    assert(legacy_width == 1);
    let ir::Program slices_p = unit(10);
    assert(!legacy::requirement(ref slices_p).is_ok);
    assert(!legacy::cost(ref slices_p,0).is_ok);
    var execution::Requirement slice_plan = required(ref slices_p);
    assert(slice_plan.width == 1 && slice_plan.slices && slice_plan.cost == 5067);
}

@test
fn void rootless_formal_selects_arbitrary_compatible_length_without_tokens() {
    var ir::Program p = ir::empty(); p.function_count = 2; p.entry = 1;
    p.arities[0] = 1; p.return_types[0] = 1; p.return_types[1] = 1;
    let usize site = built(builders::parameter_exclusive(ref mut p,0,1,77));
    let usize selected = tagged(ref mut p,83,0,site,1);
    let usize read = tagged(ref mut p,84,2,0,site);
    let usize stored = tagged(ref mut p,85,0,site,3);
    let usize ended = built(ir::raw(ref mut p,86,0,0,0,77));
    finish(ref mut p,0);
    assert(site == 0 && p.slice_roots[0] == 0 && p.slice_functions[0] == 1);
    assert(p.slice_elements[0] == 129);
    var vec::Vec<usize> state = prepared(ref p);
    var u8[16] data = [10;16]; var owners::Table table = owners::empty(16);
    let owners::Token root = created(ref mut table,1,4,10,ref mut data);
    var slices::Pool pool = slices::empty();
    let slices::Ticket ticket = opened(slices::open_exclusive(
        ref mut pool,ref mut table,root,0,4,16));
    var owners::Token[1] hidden = [owners::Token { .slot = 16, .generation = 0 }];
    var i64[4] registers = [777,2,0,42];
    let usize select = built(execution::step(ref p,selected,0,0,ref mut state,ref table,
        ref hidden[..0],ref pool,ticket,ref mut data,ref mut registers,4129));
    {
        let ref usize[] words = vec::view_usize(ref state);
        assert(words[2+2] == 4 && words[2+11] == 2 && words[2+13] == 1281);
    }
    let usize old = built(execution::step(ref p,read,0,0,ref mut state,ref table,
        ref hidden[..0],ref pool,ticket,ref mut data,ref mut registers,4166));
    assert(registers[2] == 10);
    let usize write = built(execution::step(ref p,stored,0,0,ref mut state,ref table,
        ref hidden[..0],ref pool,ticket,ref mut data,ref mut registers,4170));
    assert(sliced(ref pool,ticket,ref table,2,ref data) == 42);
    let usize abandon = built(execution::step(ref p,ended,0,0,ref mut state,ref table,
        ref hidden[..0],ref pool,ticket,ref mut data,ref mut registers,22));
    var vec::Vec<usize> wrong_state = prepared(ref p);
    var u8[16] wrong_data = [1;16]; var owners::Table wrong_table = owners::empty(16);
    let owners::Token wrong = created(ref mut wrong_table,2,4,1,ref mut wrong_data);
    var slices::Pool wrong_pool = slices::empty();
    let slices::Ticket wrong_ticket = opened(slices::open_exclusive(
        ref mut wrong_pool,ref mut wrong_table,wrong,0,4,16));
    var i64[4] wrong_registers = [777,2,0,42];
    refused(execution::step(ref p,selected,0,0,ref mut wrong_state,ref wrong_table,
        ref hidden[..0],ref wrong_pool,wrong_ticket,ref mut wrong_data,
        ref mut wrong_registers,4129));
    let usize closed = size(slices::close(ref mut pool,ticket,ref mut table,16));
}

@test
fn void malformed_vectors_rows_and_program_tags_fail_without_publication() {
    var ir::Program p = unit(10);
    var vec::Vec<usize> state = prepared(ref p);
    var owners::Table table = owners::empty(32);
    var owners::Token[1] hidden = [owners::Token { .slot = 16, .generation = 0 }];
    var slices::Pool pool = slices::empty();
    var u8[1] data = [0]; var i64[1] registers = [0];
    let slices::Ticket ignored = slices::Ticket { .slot = 16, .generation = 0 };
    assert(legacy::empty_frame(ref state,31,77).is_ok);
    {
        let ref mut usize[] words = vec::view_mut_usize(ref mut state);
        words[0] = 14338;
    }
    refused(execution::step(ref p,0,0,0,ref mut state,ref table,
        ref hidden[..0],ref pool,ignored,ref mut data,ref mut registers,4129));
    assert(!legacy::empty_frame(ref state,0,77).is_ok);
    {
        let ref mut usize[] words = vec::view_mut_usize(ref mut state);
        words[0] = 14337; words[1] = 1;
    }
    assert(!legacy::empty_frame(ref state,0,77).is_ok);
    {
        let ref mut usize[] words = vec::view_mut_usize(ref mut state);
        words[1] = 0; words[2+8] = 1;
    }
    refused(execution::step(ref p,0,0,0,ref mut state,ref table,
        ref hidden[..0],ref pool,ignored,ref mut data,ref mut registers,4129));
    {
        let ref mut usize[] words = vec::view_mut_usize(ref mut state);
        words[2+8] = 0;
    }
    var legacy::Requirement old = legacy::Requirement { .width = 1, .cost = 3457 };
    var vec::Vec<usize> plain = legacy_prepared(ref old);
    assert(vec::len<usize>(ref plain) == 320);
    refused(execution::step(ref p,0,0,0,ref mut plain,ref table,
        ref hidden[..0],ref pool,ignored,ref mut data,ref mut registers,4129));
    var ir::Program bad_kind = unit(10); bad_kind.code[4] = 2;
    rejected(execution::requirement(ref bad_kind));
    assert(!execution::cost(ref bad_kind,0,true).is_ok);
    var ir::Program bad_end = unit(10); bad_end.code[3*8+4] = 1;
    rejected(execution::requirement(ref bad_end));
    var ir::Program bad_tail = unit(10); bad_tail.code[1*8+5] = 1;
    rejected(execution::requirement(ref bad_tail));
    var ir::Program bad_id = unit(10); bad_id.code[1] = 16;
    rejected(execution::requirement(ref bad_id));
    var ir::Program short_range = unit(10); short_range.ends[0] = 3;
    refused(execution::step(ref short_range,0,0,0,ref mut state,ref table,
        ref hidden[..0],ref pool,ignored,ref mut data,ref mut registers,4129));
    let Option<usize> removed = vec::pop<usize>(ref mut state);
    discard removed;
    assert(!legacy::empty_frame(ref state,31,77).is_ok);
}

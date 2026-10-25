module tests::m2::array_signatures;

import functions as functions;
import compiler as compiler;
import lexer as lexer;

fn functions::Table scanned(ref u8[] source) {
    return switch (functions::scan(source)) {
        case .ok(t): { t } case .err(_): { assert(false); functions::empty() }
    };
}
fn void rejected(ref u8[] source) { assert(!functions::scan(source).is_ok); }

@test
fn void exact_shapes_cover_all_six_elements_and_mixed_parameters() {
    let functions::Table t = scanned(b"module main; fn i32 f(bool[1] a,u8[4096] b,i32[2] c,i64[3] d,u32[4] e,usize[5] f,Option<i32> g,Result<bool,bool> h){return 0;} fn i32 main(){return 42;}");
    assert(t.count == 2 && t.entry == 1 && t.arities[0] == 8);
    assert(t.param_types[0] == 2 && t.param_lengths[0] == 1);
    assert(t.param_types[1] == 10 && t.param_lengths[1] == 4096);
    assert(t.param_types[2] == 1 && t.param_lengths[2] == 2);
    assert(t.param_types[3] == 9 && t.param_lengths[3] == 3);
    assert(t.param_types[4] == 11 && t.param_lengths[4] == 4);
    assert(t.param_types[5] == 12 && t.param_lengths[5] == 5);
    assert(t.param_types[6] == 3 && t.param_lengths[6] == 0);
    assert(t.param_types[7] == 8 && t.param_lengths[7] == 0);
    var usize i = 8;
    while (i < 128) { assert(t.param_lengths[i] == 0); i += 1; }
}

@test
fn void shapes_keep_function_slots_names_and_body_boundaries() {
    let ref u8[] source = b"module main; fn i32 main(){return 42;} fn i32 f(i32 x,bool [ 2 ] flags){return x;} fn i32 g(u8[3] flags){return 0;}";
    let functions::Table t = scanned(source);
    assert(t.entry == 0 && t.arities[1] == 2 && t.arities[2] == 1);
    assert(t.param_lengths[8] == 0 && t.param_types[8] == 1);
    assert(t.param_lengths[9] == 2 && t.param_types[9] == 2);
    assert(t.param_lengths[16] == 3 && t.param_types[16] == 10);
    assert(lexer::equal(source[t.param_begins[9]..t.param_ends[9]], b"flags"));
    assert(lexer::equal(source[t.param_begins[16]..t.param_ends[16]], b"flags"));
    assert(source[t.bodies[1]] == 114 && source[t.body_ends[1]] == 125);
    let functions::Table empty = functions::empty();
    var usize i = 0;
    while (i < 128) { assert(empty.param_lengths[i] == 0); i += 1; }
}

@test
fn void last_function_and_parameter_use_the_final_metadata_slot() {
    let functions::Table t = scanned(b"module main; fn i32 main(){return 0;} fn i32 a(){return 0;} fn i32 b(){return 0;} fn i32 c(){return 0;} fn i32 d(){return 0;} fn i32 e(){return 0;} fn i32 f(){return 0;} fn i32 g(){return 0;} fn i32 h(){return 0;} fn i32 i(){return 0;} fn i32 j(){return 0;} fn i32 k(){return 0;} fn i32 l(){return 0;} fn i32 m(){return 0;} fn i32 n(){return 0;} fn i32 last(i32 a,i32 b,i32 c,i32 d,i32 e,i32 f,i32 g,usize[4096] h){return 0;}");
    assert(t.count == 16 && t.arities[15] == 8);
    assert(t.param_lengths[126] == 0 && t.param_lengths[127] == 4096 && t.param_types[127] == 12);
}

@test
fn void malformed_unsupported_and_out_of_range_shapes_are_rejected() {
    rejected(b"module main; fn i32 f(i32[0] a){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(i32[4097] a){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(i32[-1] a){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(i32[18446744073709551615] a){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(i32[9223372036854775808] a){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(i32[] a){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(i32[1+1] a){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(i32[2 a){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(i32[2][2] a){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(Option<i32>[2] a){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(Result<bool,bool>[2] a){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(ref i32[2] a){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32[2] f(){return 0;} fn i32 main(){return 0;}");
}

@test
fn void parameter_limits_and_name_rules_still_apply() {
    rejected(b"module main; fn i32 main(i32[1] a){return 0;}");
    rejected(b"module main; fn i32 f(i32[1] a,i32 a){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(i32[1] return){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(i32[1] a,){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(i32[1]){return 0;} fn i32 main(){return 0;}");
    rejected(b"module main; fn i32 f(i32[1] a,i32 b,i32 c,i32 d,i32 e,i32 f,i32 g,i32 h,i32 i){return 0;} fn i32 main(){return 0;}");
}

@test
fn void compilation_blocks_array_signatures_before_any_body_lowering() {
    let ref u8[] source = b"module main; fn i32 main(){return f(42);} fn i32 f(i32[1] a){return 0;}";
    let functions::Table t = scanned(source);
    assert(switch (compiler::compile(source)) {
        case .ok(_): { false } case .err(e): { e.kind == 3 && e.offset == t.param_begins[8] }
    });
    assert(!compiler::compile(b"module main; fn i32 f(i32[1] a){return 0;} fn i32 main(){return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main(){let i32[1] a=[42;1]; return f(a);} fn i32 f(i32[1] a){return 0;}").is_ok);
    assert(compiler::compile(b"module main; fn i32 f(i32 a){return a;} fn i32 main(){return f(42);}").is_ok);
}

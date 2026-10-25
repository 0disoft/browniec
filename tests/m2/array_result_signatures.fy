module tests::m2::array_result_signatures;

import functions as functions;
import compiler as compiler;
import lexer as lexer;

fn functions::Table scanned(ref u8[] source) {
    return switch(functions::scan(source)) {
        case .ok(t): {t} case .err(_): {assert(false); functions::empty()}
    };
}
fn void rejected_body(ref u8[] source, usize f) {
    let functions::Table t=scanned(source);
    assert(t.return_lengths[f]!=0);
    switch(compiler::compile(source)) {
        case .ok(_): {assert(false);}
        case .err(e): {assert(e.kind==3 || e.kind==4);}
    };
}

@test
fn void exact_result_shapes_cover_all_six_elements_and_scalar_wrapper_sentinels() {
    let functions::Table t=scanned(b"module main; fn bool[1] a(){return 0;} fn u8[4096] b(){return 0;} fn i32[2] c(){return 0;} fn i64[3] d(){return 0;} fn u32[4] e(){return 0;} fn usize[5] f(){return 0;} fn Option<i32> g(){return .none;} fn Result<bool,bool> h(){return .ok(true);} fn i32 main(){return 42;}");
    assert(t.count==9 && t.entry==8);
    assert(t.return_types[0]==2 && t.return_lengths[0]==1);
    assert(t.return_types[1]==10 && t.return_lengths[1]==4096);
    assert(t.return_types[2]==1 && t.return_lengths[2]==2);
    assert(t.return_types[3]==9 && t.return_lengths[3]==3);
    assert(t.return_types[4]==11 && t.return_lengths[4]==4);
    assert(t.return_types[5]==12 && t.return_lengths[5]==5);
    assert(t.return_types[6]==3 && t.return_lengths[6]==0);
    assert(t.return_types[7]==8 && t.return_lengths[7]==0);
    let functions::Table empty=functions::empty();
    var usize i=0;
    while(i<16) {
        assert(empty.return_lengths[i]==0);
        if(i>=8) {assert(t.return_lengths[i]==0);}
        i+=1;
    }
}

@test
fn void names_parameters_and_body_spans_keep_their_original_slots() {
    let ref u8[] source=b"module main; fn i32 main(){return 42;} fn i64 [ 4096 ] make(u8[2] a,i32 x){return x;}";
    let functions::Table t=scanned(source);
    assert(t.entry==0 && t.arities[1]==2 && t.return_types[1]==9 && t.return_lengths[1]==4096);
    assert(t.param_types[8]==10 && t.param_lengths[8]==2);
    assert(t.param_types[9]==1 && t.param_lengths[9]==0);
    assert(lexer::equal(source[t.begins[1]..t.ends[1]],b"make"));
    assert(source[t.bodies[1]]==114 && source[t.body_ends[1]]==125);
}

@test
fn void last_result_slot_and_function_limit_stay_bounded() {
    let functions::Table t=scanned(b"module main; fn i32 main(){return 0;} fn i32 a(){return 0;} fn i32 b(){return 0;} fn i32 c(){return 0;} fn i32 d(){return 0;} fn i32 e(){return 0;} fn i32 f(){return 0;} fn i32 g(){return 0;} fn i32 h(){return 0;} fn i32 i(){return 0;} fn i32 j(){return 0;} fn i32 k(){return 0;} fn i32 l(){return 0;} fn i32 m(){return 0;} fn i32 n(){return 0;} fn usize[4096] last(){return 0;}");
    assert(t.count==16 && t.return_types[15]==12 && t.return_lengths[15]==4096);
    var usize i=0;
    while(i<15) {assert(t.return_lengths[i]==0);i+=1;}
    assert(!functions::scan(b"module main; fn i32 main(){return 0;} fn i32 a(){return 0;} fn i32 b(){return 0;} fn i32 c(){return 0;} fn i32 d(){return 0;} fn i32 e(){return 0;} fn i32 f(){return 0;} fn i32 g(){return 0;} fn i32 h(){return 0;} fn i32 i(){return 0;} fn i32 j(){return 0;} fn i32 k(){return 0;} fn i32 l(){return 0;} fn i32 m(){return 0;} fn i32 n(){return 0;} fn i32[1] last(){return 0;} fn i32 extra(){return 0;}").is_ok);
}

@test
fn void malformed_lengths_and_unsupported_aggregate_results_are_rejected() {
    assert(!functions::scan(b"module main; fn i32[0] f(){return 0;} fn i32 main(){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn i32[4097] f(){return 0;} fn i32 main(){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn i32[-1] f(){return 0;} fn i32 main(){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn i32[9223372036854775808] f(){return 0;} fn i32 main(){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn i32[18446744073709551615] f(){return 0;} fn i32 main(){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn i32[18446744073709551616] f(){return 0;} fn i32 main(){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn i32[] f(){return 0;} fn i32 main(){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn i32[1+1] f(){return 0;} fn i32 main(){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn i32[2 f(){return 0;} fn i32 main(){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn i32[2][2] f(){return 0;} fn i32 main(){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn Option<i32>[2] f(){return 0;} fn i32 main(){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn Result<bool,bool>[2] f(){return 0;} fn i32 main(){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn ref i32[2] f(){return 0;} fn i32 main(){return 0;}").is_ok);
}

@test
fn void main_still_requires_a_scalar_zero_argument_i32_result() {
    assert(!functions::scan(b"module main; fn i32[1] main(){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn bool[1] main(){return false;}").is_ok);
    assert(!functions::scan(b"module main; fn i32 main(i32[1] a){return 0;}").is_ok);
    assert(!functions::scan(b"module main; fn i64 main(){return 0;}").is_ok);
    assert(functions::scan(b"module main; fn i32 main(){return 42;}").is_ok);
}

@test
fn void invalid_bodies_scalar_uses_and_catalog_overflow_are_rejected() {
    rejected_body(b"module main; fn i32[1] f(){return 42;} fn i32 main(){return 42;}",0);
    rejected_body(b"module main; fn i32 main(){return missing;} fn i32[2] f(i32[2] a){return a;}",1);
    rejected_body(b"module main; fn i32 main(){return f();} fn i32[1] f(){return 42;}",1);
    rejected_body(b"module main; fn bool[1] f(){return true;} fn i32 main(){return 42;}",0);
    rejected_body(b"module main; fn u8[4096] f(){return 0;} fn i32 main(){return 42;}",0);
    rejected_body(b"module main; fn i64[1] f(){return 0;} fn i32 main(){return 42;}",0);
    rejected_body(b"module main; fn u32[1] f(){return 0;} fn i32 main(){return 42;}",0);
    rejected_body(b"module main; fn usize[4096] f(){return 0;} fn i32 main(){return 42;}",0);
    rejected_body(b"module main; fn i32 a(i32[1] a,i32[1] b,i32[1] c,i32[1] d,i32[1] e,i32[1] f,i32[1] g,i32[1] h){return 0;} fn i32 b(i32[1] a,i32[1] b,i32[1] c,i32[1] d,i32[1] e,i32[1] f,i32[1] g,i32[1] h){return 0;} fn i32[1] c(i32[1] a){return 0;} fn i32 main(){return 42;}",2);
}

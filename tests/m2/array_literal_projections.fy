module tests::m2::array_literal_projections;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
import errors as errors;
import program_image as programs;
import static_image as images;
import static_call_ir as calls;
import array_local_source as literals;
import lexer as lexer;
import std::bytes as bytes;
fn void result(Result<i64,errors::Error> r,i64 n){switch(r){case .ok(v):{assert(v==n);}case .err(_):{assert(false);}};}
fn void value(ref u8[] source,i64 n){switch(compiler::compile_program(source,65536)){
    case .ok(p):{var usize i=0;while(i<2){result(programs::run_public(ref p,16000000),n);i+=1;}}
    case .err(_):{assert(false);}
};}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
};}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
@test fn void list_and_repeated_projections_preserve_six_scalar_domains_and_grouping(){
    value(b"module main;fn i32 main(){let n=[20,42,][1];var m=(([20,40]))[1];m=m+2;return n+m-42;}",42);
    value(b"module main;fn i32 main(){if([true,false][0] && ![false;2][1] && [20,22][0]==20){return 42;}return 0;}",42);
    value(b"module main;fn i64 big(){return [-9223372036854775808,0][0];}fn i32 main(){if(big()==-9223372036854775808){return 42;}return 0;}",42);
    value(b"module main;fn u8 byte(){return [255,42][1];}fn u32 word(){return [4294967295;2][0];}fn usize size(){return [18446744073709551615,0][0];}fn i32 main(){if(word()==4294967295 && size()==18446744073709551615){return byte() as i32;}return 0;}",42);
    value(b"module main;fn i32 main(){let n=([true,false]).len;let m=([20;2]).len;if(n==2 && m==2){return -[20,22][0]+62;}return 0;}",42);
}
@test fn void cells_fillers_lengths_and_indices_preserve_once_only_order_and_short_circuiting(){
    value(b"module main;fn i32 bump(ref mut i32[] c){c[0]=c[0]+1;return 22;}fn usize pick(ref mut i32[] c){c[0]=c[0]+1;return 0;}fn i32 main(){var c=[20];let n=[c[0],bump(ref mut c)][pick(ref mut c)];return n+c[0];}",42);
    value(b"module main;fn i32 bump(ref mut i32[] c){c[0]=c[0]+1;return c[0];}fn i32 main(){var c=[0];let n=[bump(ref mut c),bump(ref mut c)].len;let m=[bump(ref mut c);2].len;if(n==2 && m==2){return c[0]*14;}return 0;}",42);
    value(b"module main;fn i32 bump(ref mut i32[] c){c[0]=c[0]+1;return 1;}fn i32 main(){var c=[0];if(false && [bump(ref mut c)==1][0]){return 0;}if(true || [bump(ref mut c)==1][0]){return 42-c[0];}return 0;}",42);
}
@test fn void completed_temporaries_join_return_propagation_and_loop_exit_cleanup(){
    value(b"module main;fn i32 main(){let prior=[7];let Option<i32> o=.none;return [20,22][switch(o){case .some(v):{0}case .none:{return 42;}}];}",42);
    value(b"module main;fn usize pick(i32 n){return 0;}fn Option<i32> work(Option<i32> o){return .some([42][pick(o?)]);}fn i32 main(){switch(work(.none)){case .some(_):{return 0;}case .none:{}}switch(work(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",42);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;var n=0;while(n<42){let prior=[7];let v=[20,22][switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}];}while(true){let v=[42;1][switch(o){case .some(v):{0}case .none:{break;}}];}return n;}",42);
    value(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let Option<i32> o=.none;return [42][same(ref [0])[switch(o){case .some(v):{0}case .none:{return 42;}}] as usize];}",42);
}
@test fn void nested_scalar_projections_compose_with_calls_records_tags_and_replacement(){
    value(b"module main;fn i32 main(){return [[20,22][0],[20,22][1]][0]+22;}",42);
    value(b"module main;struct P{i32 n;usize count;}fn i32 take(i32 n){return n;}fn i32 main(){let P p=P{.n=take([20,22][1]),.count=[true,false].len};if(p.count==2){return p.n+20;}return 0;}",42);
    value(b"module main;fn i32[2] make(){return [20,22];}fn i32 main(){var a=[0;2];a=[[20,22][0],make()[1]];let o=.some(a[0]+a[1]);switch(o){case .some(v):{return v;}case .none:{return 0;}}}",42);
    value(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let marker=same(ref b\"*\");let n=([20,22])[1];var sum=0;var i=0;while(i<42){sum=sum+[1][0];i=i+1;}return n+sum-22;}",42);
    value(b"module main;fn i32[1] make(){return [42];}fn i32 main(){let Option<i32> o=.none;return make()[switch(o){case .some(v):{0}case .none:{return 42;}}];}",42);
}
@test fn void utf8_element_lists_keep_exact_u8_ranges_effects_and_endpoint_cleanup(){
    value(b"module main;fn i32 main(){if(text::valid_utf8([195,169]) && !text::valid_utf8([195]) && text::valid_utf8([255][1..])){return 42;}return 0;}",42);
    value(b"module main;fn usize end(){return 2;}fn i32 main(){if(text::valid_utf8([255,195,169][1+0..end()+1])){return 42;}return 0;}",42);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;if(text::valid_utf8([65,switch(o){case .some(v):{65}case .none:{return 42;}}])){return 0;}return 0;}",42);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;var n=0;while(n<42){let valid=text::valid_utf8([65,66][0..switch(o){case .some(v):{1}case .none:{n=n+1;continue;}}]);}return n;}",42);
}
fn void runtime_error(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(p):{switch(programs::run_public(ref p,16000000)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}};}
    case .err(_):{assert(false);}
};}
@test fn void bounds_and_malformed_or_non_scalar_operands_fail_honestly(){
    runtime_error(b"module main;fn i32 main(){return [20,22][2];}",14);
    runtime_error(b"module main;fn i32 main(){let ref u8[] marker=b\"*\";return [42;2][2];}",14);
    runtime_error(b"module main;fn i32 main(){return [42][1/0];}",7);
    rejected(b"module main;fn i32 main(){return [1,true][0];}",3);
    rejected(b"module main;fn i32 main(){return [1,2][true];}",3);
    rejected(b"module main;fn i32 main(){return [1,2][-1];}",3);
    rejected(b"module main;fn i32 main(){return [1,2].missing;}",3);
    rejected(b"module main;fn i32 main(){return [1,2];}",3);
    rejected(b"module main;fn i32 main(){return [][0];}",3);
    rejected(b"module main;fn i32 main(){return [42;0][0];}",3);
    rejected(b"module main;fn i32 main(){return [1,,2][0];}",2);
    rejected(b"module main;fn i32 main(){if(text::valid_utf8([256])){return 42;}return 0;}",3);
}
fn void classify(ref u8[] source,usize groups,u8 kind){var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    let lexer::State prior=lexer::snapshot(ref s);switch(literals::projection(source,ref s)){
        case .ok(v):{assert(v.groups==groups && v.kind==kind);}case .err(_):{assert(false);}
    };assert(s.cursor==prior.cursor && s.begin==prior.begin && s.end==prior.end && s.tokens==prior.tokens && s.kind==prior.kind);
}
fn void append(ref mut bytes::Buffer b,ref u8[] s){assert(bytes::append(b,s).is_ok);}
fn void groups(usize n,bool pass){var bytes::Buffer b=bytes::empty();append(ref mut b,b"module main;fn i32 main(){return ");var usize i=0;
    while(i<n){append(ref mut b,b"(");i+=1;}append(ref mut b,b"[42]");i=0;while(i<n){append(ref mut b,b")");i+=1;}
    append(ref mut b,b"[0];}");if(pass){value(bytes::view(ref b),42);}else{rejected(bytes::view(ref b),4);}
}
fn void sites(usize n,bool nested,bool pass){var bytes::Buffer b=bytes::empty();append(ref mut b,b"module main;fn i32 main(){return [42][");var usize i=1;
    while(i<n){append(ref mut b,if(nested){b"[0]["}else{b"0]+[0]["});i+=1;}append(ref mut b,b"0");i=0;
    while(i<if(nested){n}else{1}){append(ref mut b,b"]");i+=1;}append(ref mut b,b";}");
    if(pass){let ir::Program p=compiled(bytes::view(ref b));assert(p.arrays.count==n);result(vm::run_with_array_limit(ref p,16000000,if(nested){128}else{4}),42);}
    else{rejected(bytes::view(ref b),4);}
}
@test fn void advisory_lookahead_groups_and_sixteen_site_limits_preserve_original_bounds(){
    classify(b"([20,22])[0]",1,91);classify(b"(([20,22])).len",2,46);classify(b"([20,22][0])",0,0);
    classify(b"[f(20,22);2].len",0,46);classify(b"[b\";],\"[0] as i32,22][0]",0,91);classify(b"[20/* ] , ; */ ,22];",0,0);
    groups(31,true);groups(33,false);sites(16,false,true);sites(17,false,false);sites(16,true,true);sites(17,true,false);
}
fn images::Image image(){var images::Builder b=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    return switch(images::freeze(ref b,images::metadata_charge())){case .ok(v):{v}case .err(_):{assert(false);image()}};}
fn void exact(ref ir::Program p,usize fuel){result(vm::run_with_array_limit(p,fuel,8),42);result(vm::run_with_array_limit(p,fuel+1,8),42);
    switch(vm::run_with_array_limit(p,fuel-1,8)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
}
@test fn void immediate_projection_costs_match_independent_ordinary_and_retained_oracles(){
    let ir::Program list=compiled(b"module main;fn i32 main(){return [20,42][1];}");
    assert(verifier::verify(ref list).is_ok && list.arrays.count==1 && list.list_used==2 && list.count==7 && list.code[5*8]==37);exact(ref list,450);
    let ir::Program repeat=compiled(b"module main;fn i32 main(){return [42;2][1];}");assert(repeat.list_used==0 && repeat.count==6);exact(ref repeat,170);
    let calls::Program code=calls::Program{.body=list,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    let programs::ReferenceReturnProgram retained=switch(programs::retain_reference_returns(ref code,image(),images::metadata_charge())){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    result(programs::run_public_references(ref retained,410045),42);result(programs::run_public_references(ref retained,410046),42);
    switch(programs::run_public_references(ref retained,410044)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
}

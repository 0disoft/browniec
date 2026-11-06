module tests::m2::place_assignment;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
import lexer as lexer;
import program_image as programs;
import std::bytes as bytes;

fn void ordinary(ref u8[] source){switch(compiler::compile(source)){
    case .ok(p):{assert(verifier::verify(ref p).is_ok);assert(switch(vm::run(ref p,16000000)){case .ok(n):{n==42}case .err(_):{false}});}
    case .err(_):{assert(false);}
};}
fn void retained(ref u8[] source){switch(compiler::compile_reference_returns(source,65536)){
    case .ok(p):{assert(switch(programs::run_public_references(ref p,16000000)){case .ok(n):{n==42}case .err(_):{false}});}
    case .err(_):{assert(false);}
};}
fn void both(ref u8[] source){ordinary(source);retained(source);}
fn void public_value(ref u8[] source){switch(compiler::compile_program(source,65536)){
    case .ok(p):{assert(switch(programs::run_public(ref p,16000000)){case .ok(n):{n==42}case .err(_):{false}});}
    case .err(_):{assert(false);}
};}
fn void append(ref mut bytes::Buffer b,ref u8[] s){assert(bytes::append(b,s).is_ok);}
fn void compound(ref u8[] tag,ref u8[] left,ref u8[] op,ref u8[] right){
    var bytes::Buffer b=bytes::empty();append(ref mut b,b"module main;fn i32 main(){var ");append(ref mut b,tag);
    append(ref mut b,b"[1] a=[");append(ref mut b,left);append(ref mut b,b";1];a[0]");append(ref mut b,op);
    append(ref mut b,right);append(ref mut b,b";if(a[0]==42){return 42;}return 0;}");both(bytes::view(ref b));
}
@test fn void compound_tokens_use_maximal_munch_and_keep_existing_operator_tokens(){
    let ref u8[] source=b"+= -= *= /= %= <<= >>= &= ^= |= << >> <= >= == != && ||";
    let u8[18] kinds=[136,137,138,139,140,141,142,143,144,145,134,135,130,131,128,129,132,133];
    var lexer::State s=lexer::empty();var usize i=0;
    while(i<18){assert(lexer::next(source,ref mut s).is_ok && s.kind==kinds[i]);
        assert(s.end-s.begin==if(i==5 || i==6){3}else{2});i+=1;}
    assert(lexer::next(source,ref mut s).is_ok && s.kind==0);
}
@test fn void ten_checked_compounds_execute_in_all_five_integer_domains(){
    var usize tag=0;while(tag<5){let ref u8[] name=if(tag==0){b"i32"}else if(tag==1){b"i64"}else if(tag==2){b"u8"}else if(tag==3){b"u32"}else{b"usize"};
        compound(name,b"20",b"+=",b"22");compound(name,b"64",b"-=",b"22");compound(name,b"6",b"*=",b"7");
        compound(name,b"84",b"/=",b"2");compound(name,b"127",b"%=",b"85");compound(name,b"21",b"<<=",b"1");
        compound(name,b"84",b">>=",b"1");compound(name,b"63",b"&=",b"42");compound(name,b"0",b"^=",b"42");compound(name,b"40",b"|=",b"2");tag+=1;
    }
    both(b"module main;fn i32 main(){var a=[false];a[0]=true;if(a[0]){return 42;}return 0;}");
}
@test fn void index_and_old_scalar_are_captured_once_before_rhs_mutations_and_calls(){
    both(b"module main;fn i32 main(){var a=[20;2];var usize i=0;var hits=0;a[if(true){hits=hits+1;i}else{0}]+=if(true){i=1;a=[100,100];hits=hits+1;22}else{0};if(hits==2 && a[1]==100){return a[0];}return 0;}");
    both(b"module main;fn i32 main(){var a=[20;2];a[0]+=if(true){a[1]=22;a[0]=100;22}else{0};if(a[1]==22){return a[0];}return 0;}");
    both(b"module main;fn i32 rhs(ref mut i32[] a){a[0]=100;return 22;}fn i32 main(){var a=[20];a[0]+=rhs(ref mut a);return a[0];}");
    both(b"module main;fn i32 rhs(){var a=[20];a[0]+=22;return a[0];}fn i32 main(){var a=[0];a[0]=rhs();return a[0];}");
}
@test fn void return_and_loop_transfers_end_only_exited_pending_places(){
    both(b"module main;fn i32 main(){var a=[0];a[0]=if(true){return 42;}else{0};return 0;}");
    both(b"module main;fn i32 main(){var a=[20];a[0]+=if(true){while(true){break;}22}else{0};return a[0];}");
    both(b"module main;fn i32 main(){var a=[0];while(true){a[0]+=if(true){break;}else{0};}return 42;}");
    both(b"module main;fn i32 main(){var a=[0];var n=0;while(n<3){n=n+1;a[0]+=if(true){continue;}else{0};}return n+39;}");
    both(b"module main;fn i32 main(){var a=[20;2];a[0]+=if(true){while(true){a[1]+=if(true){break;}else{0};}22}else{0};return a[0];}");
    both(b"module main;fn i32 main(){var a=[0];var n=0;for(;n<3;n=n+1){a[0]=if(true){continue;}else{0};}return n+39;}");
}
@test fn void propagation_and_all_return_kinds_close_pending_places_before_handoff(){
    both(b"module main;fn Option<i32> work(Option<i32> o){var a=[20];a[0]+=o?;return .some(a[0]);}fn i32 main(){switch(work(.none)){case .some(_):{return 0;}case .none:{}}switch(work(.some(22))){case .some(v):{return v;}case .none:{return 0;}}}");
    both(b"module main;fn i32[1] make(){var a=[20];a[0]=if(true){return a;}else{0};return a;}fn i32 main(){let a=make();return a[0]+22;}");
    both(b"module main;struct P{i32 x;}fn P make(){var a=[0];a[0]=if(true){return P{.x=42};}else{0};return P{.x=0};}fn i32 main(){let p=make();return p.x;}");
    both(b"module main;fn void work(){var a=[0];a[0]=if(true){return;}else{0};}fn i32 main(){work();return 42;}");
    public_value(b"module main;fn ref u8[] pick(ref u8[] b){var a=[0];a[0]=if(true){return b;}else{0};return b;}fn i32 main(){let ref u8[] b=pick(ref b\"*\");return b[0] as i32;}");
}
fn void failure(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(p):{assert(switch(programs::run_public(ref p,16000000)){case .ok(_):{false}case .err(e):{e.kind==kind}});}
    case .err(_):{assert(false);}
};switch(compiler::compile_reference_returns(source,65536)){
    case .ok(p):{assert(switch(programs::run_public_references(ref p,16000000)){case .ok(_):{false}case .err(e):{e.kind==kind}});}
    case .err(_):{assert(false);}
};}
@test fn void bounds_precede_rhs_returns_and_faults_and_compounds_keep_checked_errors(){
    failure(b"module main;fn i32 main(){var a=[0];a[999]=1/0;return 0;}",14);
    failure(b"module main;fn i32 main(){var a=[0];a[999]+=if(true){return 42;}else{0};return 0;}",14);
    failure(b"module main;fn i32 main(){var a=[0];a[0]/=0;return 0;}",7);
    failure(b"module main;fn i32 main(){var u8[1] a=[255;1];a[0]+=1;return 0;}",6);
    failure(b"module main;fn i32 main(){var a=[1];a[0]<<=32;return 0;}",6);
    assert(!compiler::compile(b"module main;fn i32 main(){let a=[0];a[0]+=42;return 0;}").is_ok);
    assert(!compiler::compile(b"module main;fn i32 main(){var a=[false];a[0]^=true;return 0;}").is_ok);
    assert(!compiler::compile(b"module main;fn i32 main(){var a=[0];a[0]+=true;return 0;}").is_ok);
    assert(!compiler::compile(b"module main;fn i32 main(){var a=[0];for(;false;a[0]+=1){}return 0;}").is_ok);
}
fn void exact(ref u8[] source,usize low,usize public,usize reference){
    switch(compiler::compile(source)){case .ok(p):{
        assert(switch(vm::run_with_array_limit(ref p,low-1,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
        assert(switch(vm::run_with_array_limit(ref p,low,4)){case .ok(n):{n==42}case .err(_):{false}});
        assert(switch(vm::run(ref p,public-1)){case .ok(_):{false}case .err(e):{e.kind==8}});
        assert(switch(vm::run(ref p,public)){case .ok(n):{n==42}case .err(_):{false}});
    }case .err(_):{assert(false);}};
    switch(compiler::compile_reference_returns(source,65536)){case .ok(p):{
        assert(switch(programs::run_public_references(ref p,reference-1)){case .ok(_):{false}case .err(e):{e.kind==8}});
        assert(switch(programs::run_public_references(ref p,reference)){case .ok(n):{n==42}case .err(_):{false}});
    }case .err(_):{assert(false);}};
}
@test fn void plain_and_compound_source_have_independent_exact_fuel_boundaries(){
    exact(b"module main;fn i32 main(){var a=[0;1];a[0]=42;return a[0];}",3776,69308,413378);
    exact(b"module main;fn i32 main(){var a=[20;1];a[0]+=22;return a[0];}",3846,69378,413449);
}
@test fn void source_places_preserve_sixty_four_bindings_and_reuse_ids_across_thirty_statements(){
    var bytes::Buffer source=bytes::empty();append(ref mut source,b"module main;fn i32 main(){var a=[0;1];");
    var usize i=0;while(i<63){append(ref mut source,b"let x");assert(bytes::append_usize(ref mut source,i).is_ok);
        append(ref mut source,b"=0;");i+=1;}
    append(ref mut source,b"a[0]+=42;return a[0];}");both(bytes::view(ref source));
    var bytes::Buffer repeated=bytes::empty();append(ref mut repeated,b"module main;fn i32 main(){var a=[12;1];");
    i=0;while(i<30){append(ref mut repeated,b"a[0]+=1;");i+=1;}
    append(ref mut repeated,b"return a[0];}");both(bytes::view(ref repeated));
}

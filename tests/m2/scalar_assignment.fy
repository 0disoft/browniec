module tests::m2::scalar_assignment;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
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
fn void append(ref mut bytes::Buffer b,ref u8[] source){assert(bytes::append(b,source).is_ok);}
fn void rejected(ref u8[] source,u8 kind){assert(switch(compiler::compile(source)){case .ok(_):{false}case .err(e):{e.kind==kind}});}
fn void failure(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(p):{assert(switch(programs::run_public(ref p,16000000)){case .ok(_):{false}case .err(e):{e.kind==kind}});}
    case .err(_):{assert(false);}
};switch(compiler::compile_reference_returns(source,65536)){
    case .ok(p):{assert(switch(programs::run_public_references(ref p,16000000)){case .ok(_):{false}case .err(e):{e.kind==kind}});}
    case .err(_):{assert(false);}
};}
fn void compound(ref u8[] tag,ref u8[] left,ref u8[] op,ref u8[] right){
    var bytes::Buffer b=bytes::empty();append(ref mut b,b"module main;fn i32 main(){var ");append(ref mut b,tag);
    append(ref mut b,b" x=");append(ref mut b,left);append(ref mut b,b";x");append(ref mut b,op);append(ref mut b,right);
    append(ref mut b,b";if(x==42){return 42;}return 0;}");both(bytes::view(ref b));
}
@test fn void ten_compounds_execute_in_all_five_integer_domains_and_plain_tagged_stores_remain(){
    var usize tag=0;while(tag<5){let ref u8[] name=if(tag==0){b"i32"}else if(tag==1){b"i64"}else if(tag==2){b"u8"}else if(tag==3){b"u32"}else{b"usize"};
        compound(name,b"20",b"+=",b"22");compound(name,b"64",b"-=",b"22");compound(name,b"6",b"*=",b"7");
        compound(name,b"84",b"/=",b"2");compound(name,b"127",b"%=",b"85");compound(name,b"21",b"<<=",b"1");
        compound(name,b"84",b">>=",b"1");compound(name,b"63",b"&=",b"42");compound(name,b"0",b"^=",b"42");compound(name,b"40",b"|=",b"2");tag+=1;
    }
    both(b"module main;fn i32 main(){var bool flag=false;flag=true;if(flag){return 42;}return 0;}");
    both(b"module main;fn i32 main(){var Option<i32> x=.none;x=.some(42);return switch(x){case .some(v):{v}case .none:{0}};}");
}
@test fn void old_scalar_is_captured_before_nested_mutation_calls_and_mixed_place_rhs(){
    both(b"module main;fn i32 main(){var x=20;var hits=0;x+=if(true){hits+=1;x=100;22}else{0};if(hits==1){return x;}return 0;}");
    both(b"module main;fn i32 main(){var x=20;x+=if(true){x+=100;22}else{0};return x;}");
    both(b"module main;fn i32 delta(){var x=0;x+=22;return x;}fn i32 main(){var x=20;x+=delta();return x;}");
    both(b"module main;fn i32 main(){var x=20;let Option<i32> o=.some(22);return switch(o){case .some(v):{x+=v;x}case .none:{0}};}");
    both(b"module main;struct P{i32 x;}fn i32 main(){var x=20;var P p=P{.x=20};var a=[20];var b=[20];let ref mut i32[] s=ref mut b;x+=if(true){p.x+=if(true){a[0]+=if(true){s[0]+=22;22}else{0};22}else{0};22}else{0};if(p.x==42 && a[0]==42 && s[0]==42){return x;}return 0;}");
}
@test fn void pure_for_headers_continue_and_skipped_posts_keep_existing_order(){
    both(b"module main;fn i32 main(){var sum=0;for(var i=0;i<3;i+=1){sum+=14;continue;}return sum;}");
    both(b"module main;fn i32 main(){var sum=0;var i=0;for(i+=1;i<3;i+=1){sum+=14;}return sum+14;}");
    both(b"module main;fn i32 main(){var x=2147483647;for(;;x+=1){break;}return 42;}");
    both(b"module main;fn i32 main(){var x=0;for(;false;x/=0){return 0;}return 42;}");
    both(b"module main;fn i32 main(){var x=0;var n=0;while(n<3){n+=1;x+=if(true){continue;}else{0};}return n+39;}");
    rejected(b"module main;fn i32 f(){return 1;}fn i32 main(){var x=0;for(;false;x+=f()){}return 42;}",3);
    rejected(b"module main;fn i32 main(){var x=0;for(;false;x+=true){}return 42;}",3);
}
@test fn void every_return_kind_and_propagation_can_abandon_scalar_compounds(){
    both(b"module main;fn i32 main(){var x=2147483647;x+=if(true){return 42;}else{1};return x;}");
    both(b"module main;fn Option<i32> work(Option<i32> o){var x=20;x+=o?;return .some(x);}fn i32 main(){switch(work(.none)){case .some(_):{return 0;}case .none:{}}return switch(work(.some(22))){case .some(v):{v}case .none:{0}};}");
    both(b"module main;fn i32[1] make(){var x=0;x+=if(true){return [42];}else{0};return [0];}fn i32 main(){let a=make();return a[0];}");
    both(b"module main;struct P{i32 x;}fn P make(){var x=0;x+=if(true){return P{.x=42};}else{0};return P{.x=0};}fn i32 main(){let p=make();return p.x;}");
    both(b"module main;fn void work(){var x=0;x+=if(true){return;}else{0};}fn i32 main(){work();return 42;}");
    public_value(b"module main;fn ref u8[] pick(ref u8[] b){var x=0;x+=if(true){return b;}else{0};return b;}fn i32 main(){return pick(ref b\"*\")[0] as i32;}");
    both(b"module main;fn i32 main(){var x=0;while(true){x+=if(true){break;}else{0};}return 42;}");
}
@test fn void scalar_compounds_preserve_checked_errors_exact_types_and_statement_only_syntax(){
    failure(b"module main;fn i32 main(){var x=0;x/=0;return 0;}",7);
    failure(b"module main;fn i32 main(){var u8 x=255;x+=1;return 0;}",6);
    failure(b"module main;fn i32 main(){var x=-2147483648;x/=-1;return 0;}",6);
    failure(b"module main;fn i32 main(){var x=1;x<<=32;return 0;}",6);
    rejected(b"module main;fn i32 main(){let x=0;x+=42;return 0;}",3);
    rejected(b"module main;fn i32 main(){var bool x=false;x^=true;return 0;}",3);
    rejected(b"module main;fn i32 main(){var Option<i32> x=.some(0);x+=.some(42);return 0;}",3);
    rejected(b"module main;fn i32 main(){var x=0;x+=true;return 0;}",3);
    rejected(b"module main;fn i32 main(){var u8 x=0;let u32 y=42;x+=y;return 0;}",3);
    rejected(b"module main;fn i32 main(){var x=0;return (x+=42);}",2);
}
fn void exact(ref u8[] source,usize ordinary,usize retained){
    switch(compiler::compile(source)){case .ok(p):{
        assert(switch(vm::run(ref p,ordinary-1)){case .ok(_):{false}case .err(e):{e.kind==8}});
        assert(switch(vm::run(ref p,ordinary)){case .ok(n):{n==42}case .err(_):{false}});
    }case .err(_):{assert(false);}};
    switch(compiler::compile_reference_returns(source,65536)){case .ok(p):{
        assert(switch(programs::run_public_references(ref p,retained-1)){case .ok(_):{false}case .err(e):{e.kind==8}});
        assert(switch(programs::run_public_references(ref p,retained)){case .ok(n):{n==42}case .err(_):{false}});
    }case .err(_):{assert(false);}};
}
fn void same_ir(){switch(compiler::compile(b"module main;fn i32 main(){var x=20;x+=22;return x;}")){
    case .ok(p):{switch(compiler::compile(b"module main;fn i32 main(){var x=20;x=x+22;return x;}")){
        case .ok(q):{assert(p.count==8 && p.count==q.count && p.registers==q.registers);
            var usize i=0;while(i<p.count*8){assert(p.code[i]==q.code[i]);assert(p.code[i-i%8]<83);i+=1;}}
        case .err(_):{assert(false);}
    };}case .err(_):{assert(false);}
};}
fn void limits(){
    var bytes::Buffer source=bytes::empty();append(ref mut source,b"module main;fn i32 main(){var x=0;");
    var usize i=0;while(i<63){append(ref mut source,b"let v");assert(bytes::append_usize(ref mut source,i).is_ok);append(ref mut source,b"=0;");i+=1;}
    append(ref mut source,b"x+=42;return x;}");both(bytes::view(ref source));
    var bytes::Buffer repeated=bytes::empty();append(ref mut repeated,b"module main;fn i32 main(){var x=12;");
    i=0;while(i<30){append(ref mut repeated,b"x+=1;");i+=1;}
    append(ref mut repeated,b"return x;}");both(bytes::view(ref repeated));
}
@test fn void plain_and_compound_ir_exact_fuel_and_original_binding_limits_are_preserved(){
    same_ir();limits();
    exact(b"module main;fn i32 main(){var x=20;x=42;return x;}",6,344070);
    exact(b"module main;fn i32 main(){var x=20;x+=22;return x;}",8,344072);
}

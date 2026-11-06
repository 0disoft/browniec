module tests::m2::grouped_assignment;
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
fn void compound(usize kind,ref u8[] tag,ref u8[] left,ref u8[] op,ref u8[] right){
    var bytes::Buffer b=bytes::empty();append(ref mut b,b"module main;");
    if(kind==3){append(ref mut b,b"struct P{");append(ref mut b,tag);append(ref mut b,b" x;}");}
    append(ref mut b,b"fn i32 main(){var ");
    if(kind==3){append(ref mut b,b"P p=P{.x=");}else{append(ref mut b,tag);append(ref mut b,if(kind==0){b" x="}else{b"[1] a=["});}
    append(ref mut b,left);
    if(kind==3){append(ref mut b,b"};((p).x)");}
    else if(kind==0){append(ref mut b,b";((x))");}
    else{append(ref mut b,b"];");if(kind==2){append(ref mut b,b"let ref mut ");append(ref mut b,tag);append(ref mut b,b"[] s=ref mut a;(((s))[0])");}
        else{append(ref mut b,b"((a)[0])");}}
    append(ref mut b,op);append(ref mut b,right);append(ref mut b,b";if(");
    append(ref mut b,if(kind==0){b"x"}else if(kind==1){b"a[0]"}else if(kind==2){b"s[0]"}else{b"p.x"});
    append(ref mut b,b"==42){return 42;}return 0;}");both(bytes::view(ref b));
}
@test fn void all_four_place_kinds_accept_ten_compounds_in_every_integer_domain(){
    var usize kind=0;while(kind<4){var usize tag=0;while(tag<5){let ref u8[] name=if(tag==0){b"i32"}else if(tag==1){b"i64"}else if(tag==2){b"u8"}else if(tag==3){b"u32"}else{b"usize"};
        compound(kind,name,b"20",b"+=",b"22");compound(kind,name,b"64",b"-=",b"22");compound(kind,name,b"6",b"*=",b"7");
        compound(kind,name,b"84",b"/=",b"2");compound(kind,name,b"127",b"%=",b"85");compound(kind,name,b"21",b"<<=",b"1");
        compound(kind,name,b"84",b">>=",b"1");compound(kind,name,b"63",b"&=",b"42");compound(kind,name,b"0",b"^=",b"42");compound(kind,name,b"40",b"|=",b"2");tag+=1;}
        kind+=1;}
    both(b"module main;fn i32 main(){var x=false;((x))=true;if(x){return 42;}return 0;}");
    both(b"module main;fn i32 main(){var a=[false];((a[0]))=true;if(a[0]){return 42;}return 0;}");
    both(b"module main;fn i32 main(){var a=[false];let ref mut bool[] s=ref mut a;(s)[0]=true;if(s[0]){return 42;}return 0;}");
    both(b"module main;struct P{bool x;}fn i32 main(){var P p=P{.x=false};(p).x=true;if(p.x){return 42;}return 0;}");
    both(b"module main;fn i32 main(){var Option<i32> o=.none;((o))=.some(42);return switch(o){case .some(v):{v}case .none:{0}};}");
}
fn void same(ref u8[] original,ref u8[] grouped){switch(compiler::compile(original)){
    case .ok(p):{switch(compiler::compile(grouped)){
        case .ok(q):{assert(p.count==q.count && p.registers==q.registers && p.arrays.count==q.arrays.count && p.records.count==q.records.count);
            var usize i=0;while(i<p.count*8){assert(p.code[i]==q.code[i]);i+=1;}}
        case .err(_):{assert(false);}
    };}case .err(_):{assert(false);}
};both(grouped);}
@test fn void grouping_preserves_instruction_bytes_and_whole_array_record_child_transactions(){
    same(b"module main;fn i32 main(){var x=20;x+=22;return x;}",b"module main;fn i32 main(){var x=20;((x))+=22;return x;}");
    same(b"module main;fn i32 main(){var a=[20;1];a[0]+=22;return a[0];}",b"module main;fn i32 main(){var a=[20;1];((a)[0])+=22;return a[0];}");
    same(b"module main;fn i32 main(){var a=[20;1];let ref mut i32[] s=ref mut a;s[0]+=22;return s[0];}",b"module main;fn i32 main(){var a=[20;1];let ref mut i32[] s=ref mut a;(((s))[0])+=22;return s[0];}");
    same(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=20};p.x+=22;return p.x;}",b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=20};((p).x)+=22;return p.x;}");
    same(b"module main;fn i32 main(){var a=[0;1];a=[42];return a[0];}",b"module main;fn i32 main(){var a=[0;1];((a))=[42];return a[0];}");
    same(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p=P{.x=42};return p.x;}",b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};((p))=P{.x=42};return p.x;}");
    same(b"module main;struct I{i32 x;}struct P{I i;}fn i32 main(){var P p=P{.i=I{.x=0}};p.i=I{.x=42};return p.i.x;}",b"module main;struct I{i32 x;}struct P{I i;}fn i32 main(){var P p=P{.i=I{.x=0}};((p).i)=I{.x=42};return p.i.x;}");
    both(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};let P q=P{.x=42};(p)=q;return p.x;}");
    both(b"module main;fn i32 main(){var sum=0;for(var i=0;i<3;((i))+=1){(sum)+=14;}return sum;}");
}
@test fn void indices_and_old_values_are_captured_once_before_rhs_and_restored_calls(){
    both(b"module main;fn i32 main(){var a=[20;2];var usize i=0;var hits=0;((a[if(true){hits+=1;i}else{0}]))+=if(true){i=1;a[0]=100;a[1]=99;22}else{0};if(hits==1 && a[1]==99){return a[0];}return 0;}");
    both(b"module main;fn i32 rhs(ref mut i32[] p){((p)[0])=100;return 22;}fn i32 main(){var a=[20];let ref mut i32[] p=ref mut a;((p)[0])+=rhs(ref mut p);return p[0];}");
    both(b"module main;fn i32 main(){var a=[20];let ref mut i32[] p=ref mut a;((p)[0])+=if(true){{let ref mut i32[] q=ref mut p;(q)[0]=100;}22}else{0};return p[0];}");
    both(b"module main;struct I{i32 x;i32 y;}struct P{I i;}fn i32 main(){var P p=P{.i=I{.x=20,.y=0}};((p).i).x+=if(true){(p.i)=I{.x=100,.y=99};22}else{0};if(p.i.y==99){return p.i.x;}return 0;}");
    both(b"module main;struct P{i32 x;}fn i32 main(){var x=20;var P p=P{.x=20};var a=[20];var b=[20];let ref mut i32[] s=ref mut b;(x)+=if(true){(p.x)+=if(true){(a[0])+=if(true){(s[0])+=22;22}else{0};22}else{0};22}else{0};if(p.x==42 && a[0]==42 && s[0]==42){return x;}return 0;}");
    both(b"module main;fn i32 main(){var a=[0];(a[if(true){return 42;}else{0}])=0;return 0;}");
    failure(b"module main;fn i32 main(){var a=[0];(a[999])=1/0;return 0;}",14);
    failure(b"module main;fn i32 main(){var a=[0];let ref mut i32[] s=ref mut a;(s[999])+=if(true){return 42;}else{0};return 0;}",14);
}
@test fn void grouped_places_close_before_every_return_kind_propagation_and_loop_transfer(){
    both(b"module main;fn Option<i32> f(Option<i32> o){var a=[20];(a[0])+=o?;return .some(a[0]);}fn i32 main(){switch(f(.none)){case .some(_):{return 0;}case .none:{}}return switch(f(.some(22))){case .some(v):{v}case .none:{0}};}");
    both(b"module main;fn i32[1] f(){var a=[42];(a[0])+=if(true){return a;}else{0};return a;}fn i32 main(){let a=f();return a[0];}");
    both(b"module main;struct P{i32 x;}fn P f(){var P p=P{.x=42};(p.x)+=if(true){return p;}else{0};return p;}fn i32 main(){let p=f();return p.x;}");
    both(b"module main;fn void f(){var a=[0];(a[0])+=if(true){return;}else{0};}fn i32 main(){f();return 42;}");
    public_value(b"module main;fn ref u8[] f(ref u8[] b){var a=[0];(a[0])=if(true){return b;}else{0};return b;}fn i32 main(){return f(ref b\"*\")[0] as i32;}");
    both(b"module main;fn i32 main(){var a=[0];var n=0;while(n<3){n+=1;(a[0])+=if(true){continue;}else{0};}return n+39;}");
    both(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=20};(p.x)+=if(true){while(true){break;}22}else{0};return p.x;}");
    both(b"module main;fn i32 main(){var a=[0];while(true){(a[0])+=if(true){break;}else{0};}return 42;}");
}
@test fn void immutable_borrowed_wrong_typed_and_nonlocation_targets_are_rejected(){
    failure(b"module main;fn i32 main(){var u8 x=255;(x)+=1;return 0;}",6);
    failure(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};(p.x)/=0;return 0;}",7);
    rejected(b"module main;fn i32 main(){let x=0;(x)=42;return x;}",3);
    rejected(b"module main;fn i32 main(){var a=[0];let ref i32[] s=ref a;(a[0])=42;return s[0];}",3);
    rejected(b"module main;fn i32 main(){var a=[0];let ref i32[] s=ref a;(s[0])=42;return 0;}",3);
    rejected(b"module main;fn i32 main(){var a=[0];for(;false;(a[0])+=1){}return 42;}",3);
    rejected(b"module main;fn i32 main(){var a=[false];(a[0])^=true;return 0;}",3);
    rejected(b"module main;fn i32 main(){var a=[0];(a)+=[42];return 0;}",3);
    rejected(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};(p)+=P{.x=42};return 0;}",3);
    rejected(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};(p.missing)=42;return 0;}",3);
    rejected(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};((p.x).y)=42;return 0;}",3);
    rejected(b"module main;fn i32 main(){var x=0;(x+1)=42;return 0;}",2);
    rejected(b"module main;fn i32 main(){var x=0;return ((x)=42);}",2);
}
fn void limits(usize kind){
    var bytes::Buffer b=bytes::empty();append(ref mut b,b"module main;");
    if(kind==3){append(ref mut b,b"struct P{i32 x;}");}append(ref mut b,b"fn i32 main(){");
    append(ref mut b,if(kind==0){b"var x=0;"}else if(kind==1){b"var a=[0];"}else if(kind==2){b"var a=[0];let ref mut i32[] s=ref mut a;"}else{b"var P p=P{.x=0};"});
    var usize i=0;let usize count=if(kind==2){62}else{63};while(i<count){append(ref mut b,b"let v");assert(bytes::append_usize(ref mut b,i).is_ok);append(ref mut b,b"=0;");i+=1;}
    append(ref mut b,if(kind==0){b"(x)+=42;return x;}"}else if(kind==1){b"(a[0])+=42;return a[0];}"}else if(kind==2){b"(s[0])+=42;return s[0];}"}else{b"(p.x)+=42;return p.x;}"});both(bytes::view(ref b));
}
@test fn void grouped_targets_keep_all_bindings_reuse_ids_and_reject_the_thirty_third_group(){
    var usize kind=0;while(kind<4){limits(kind);kind+=1;}
    var bytes::Buffer source=bytes::empty();append(ref mut source,b"module main;fn i32 main(){var x=0;");var usize i=0;
    while(i<32){append(ref mut source,b"(");i+=1;}append(ref mut source,b"x");i=0;while(i<32){append(ref mut source,b")");i+=1;}
    append(ref mut source,b"+=42;return x;}");both(bytes::view(ref source));
    var bytes::Buffer bad=bytes::empty();append(ref mut bad,b"module main;fn i32 main(){var x=0;");i=0;while(i<33){append(ref mut bad,b"(");i+=1;}
    append(ref mut bad,b"x");i=0;while(i<33){append(ref mut bad,b")");i+=1;}append(ref mut bad,b"+=42;return x;}");rejected(bytes::view(ref bad),4);
    var bytes::Buffer repeated=bytes::empty();append(ref mut repeated,b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=12};");
    i=0;while(i<30){append(ref mut repeated,b"((p).x)+=1;");i+=1;}append(ref mut repeated,b"return p.x;}");both(bytes::view(ref repeated));
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
@test fn void grouped_plain_and_compound_costs_match_all_four_independent_fuel_oracles(){
    exact(b"module main;fn i32 main(){var x=20;((x))=42;return x;}",6,344070);
    exact(b"module main;fn i32 main(){var x=20;((x))+=22;return x;}",8,344072);
    exact(b"module main;fn i32 main(){var a=[0;1];((a)[0])=42;return a[0];}",69308,413378);
    exact(b"module main;fn i32 main(){var a=[20;1];((a)[0])+=22;return a[0];}",69378,413449);
    exact(b"module main;fn i32 main(){var a=[0;1];let ref mut i32[] s=ref mut a;(((s))[0])=42;return s[0];}",152817,496889);
    exact(b"module main;fn i32 main(){var a=[20;1];let ref mut i32[] s=ref mut a;(((s))[0])+=22;return s[0];}",156984,501057);
    exact(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};((p).x)=42;return p.x;}",240190,584260);
    exact(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=20};((p).x)+=22;return p.x;}",281220,625291);
}

module tests::m2::record_place_assignment;
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
// One compiler result per helper frame; do not accumulate large IR temporaries
// in the native test caller while checking independent rejection cases.
fn void rejected(ref u8[] source){assert(!compiler::compile(source).is_ok);}
fn void public_value(ref u8[] source){switch(compiler::compile_program(source,65536)){
    case .ok(p):{assert(switch(programs::run_public(ref p,16000000)){case .ok(n):{n==42}case .err(_):{false}});}
    case .err(_):{assert(false);}
};}
fn void append(ref mut bytes::Buffer b,ref u8[] s){assert(bytes::append(b,s).is_ok);}
fn void compound(ref u8[] tag,ref u8[] left,ref u8[] op,ref u8[] right){
    var bytes::Buffer b=bytes::empty();append(ref mut b,b"module main;struct P{");append(ref mut b,tag);
    append(ref mut b,b" x;}fn i32 main(){var P p=P{.x=");append(ref mut b,left);
    append(ref mut b,b"};p.x");append(ref mut b,op);append(ref mut b,right);
    append(ref mut b,b";if(p.x==42){return 42;}return 0;}");both(bytes::view(ref b));
}
@test fn void ten_checked_compounds_execute_in_all_five_integer_domains(){
    var usize tag=0;while(tag<5){let ref u8[] name=if(tag==0){b"i32"}else if(tag==1){b"i64"}else if(tag==2){b"u8"}else if(tag==3){b"u32"}else{b"usize"};
        compound(name,b"20",b"+=",b"22");compound(name,b"64",b"-=",b"22");compound(name,b"6",b"*=",b"7");
        compound(name,b"84",b"/=",b"2");compound(name,b"127",b"%=",b"85");compound(name,b"21",b"<<=",b"1");
        compound(name,b"84",b">>=",b"1");compound(name,b"63",b"&=",b"42");compound(name,b"0",b"^=",b"42");compound(name,b"40",b"|=",b"2");tag+=1;
    }
    both(b"module main;struct P{bool x;}fn i32 main(){var P p=P{.x=false};p.x=true;if(p.x){return 42;}return 0;}");
}
fn void failure(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(p):{assert(switch(programs::run_public(ref p,16000000)){case .ok(_):{false}case .err(e):{e.kind==kind}});}
    case .err(_):{assert(false);}
};switch(compiler::compile_reference_returns(source,65536)){
    case .ok(p):{assert(switch(programs::run_public_references(ref p,16000000)){case .ok(_):{false}case .err(e):{e.kind==kind}});}
    case .err(_):{assert(false);}
};}
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
@test fn void nested_paths_capture_old_fields_before_replacement_nested_writes_and_calls(){
    both(b"module main;struct I{i32 x;i32 y;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=20,.y=7}};var hits=0;p.i.x+=if(true){hits=hits+1;p.i=I{.x=100,.y=99};22}else{0};if(hits==1 && p.i.y==99){return p.i.x;}return 0;}");
    both(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=20,.y=0};p.x+=if(true){p.y+=22;p.x=100;22}else{0};if(p.y==22){return p.x;}return 0;}");
    both(b"module main;struct P{i32 x;}fn i32 rhs(){var P p=P{.x=0};p.x+=22;return p.x;}fn i32 main(){var P p=P{.x=20};p.x+=rhs();return p.x;}");
    both(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=20};var a=[20];var b=[20];let ref mut i32[] s=ref mut b;p.x+=if(true){a[0]+=if(true){s[0]+=22;22}else{0};22}else{0};if(a[0]==42 && s[0]==42){return p.x;}return 0;}");
    both(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};let Option<i32> o=.some(1);return switch(o){case .some(_):{p.x+=42;p.x}case .none:{0}};}");
}
@test fn void record_return_and_loop_transfers_end_only_exited_pending_places(){
    both(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p.x=if(true){return 42;}else{0};return 0;}");
    both(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=20};p.x+=if(true){while(true){break;}22}else{0};return p.x;}");
    both(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};while(true){p.x+=if(true){break;}else{0};}return 42;}");
    both(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};var n=0;while(n<3){n=n+1;p.x+=if(true){continue;}else{0};}return n+39;}");
    both(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=20,.y=0};p.x+=if(true){while(true){p.y+=if(true){break;}else{0};}22}else{0};return p.x;}");
    both(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};var n=0;for(;n<3;n=n+1){p.x=if(true){continue;}else{0};}return n+39;}");
}
@test fn void propagation_and_scalar_array_record_void_and_reference_returns_release_selections(){
    both(b"module main;struct P{i32 x;}fn Option<i32> work(Option<i32> o){var P p=P{.x=20};p.x+=o?;return .some(p.x);}fn i32 main(){switch(work(.none)){case .some(_):{return 0;}case .none:{}}switch(work(.some(22))){case .some(v):{return v;}case .none:{return 0;}}}");
    both(b"module main;struct P{i32 x;}fn i32[1] make(){var P p=P{.x=0};p.x=if(true){return [42];}else{0};return [0];}fn i32 main(){let a=make();return a[0];}");
    both(b"module main;struct P{i32 x;}fn P make(){var P p=P{.x=42};p.x=if(true){return p;}else{0};return p;}fn i32 main(){let p=make();return p.x;}");
    both(b"module main;struct P{i32 x;}fn void work(){var P p=P{.x=0};p.x=if(true){return;}else{0};}fn i32 main(){work();return 42;}");
    public_value(b"module main;struct P{i32 x;}fn ref u8[] pick(ref u8[] b){var P p=P{.x=0};p.x=if(true){return b;}else{0};return b;}fn i32 main(){let ref u8[] b=pick(ref b\"*\");return b[0] as i32;}");
}
@test fn void compounds_preserve_checked_errors_exact_types_and_statement_only_syntax(){
    failure(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p.x/=0;return 0;}",7);
    failure(b"module main;struct P{u8 x;}fn i32 main(){var P p=P{.x=255};p.x+=1;return 0;}",6);
    failure(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=1};p.x<<=32;return 0;}",6);
    rejected(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=0};p.x+=42;return 0;}");
    rejected(b"module main;struct P{bool x;}fn i32 main(){var P p=P{.x=false};p.x^=true;return 0;}");
    rejected(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p.x+=true;return 0;}");
    rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 main(){var R r=R{.p=P{.x=0}};r.p+=P{.x=42};return 0;}");
    rejected(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};for(;false;p.x+=1){}return 0;}");
}
@test fn void selected_source_ir_and_independent_plain_compound_fuel_are_exact(){
    let ref u8[] source=b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p.x=42;return p.x;}";
    switch(compiler::compile(source)){case .ok(p):{assert(p.records.count==1 && p.arrays.count==0);
        var usize selected=0;var usize store=0;var usize end=0;var usize pc=0;
        while(pc<p.count){let u8 op=p.code[pc*8];assert(op!=44);
            if(op==83){assert(p.code[pc*8+4]==2 && p.code[pc*8+5]==0);selected+=1;}
            if(op==85){store+=1;}if(op==86){end+=1;}pc+=1;}
        assert(selected==1 && store==1 && end==1);
    }case .err(_):{assert(false);}};
    exact(source,174658,240190,584260);
    exact(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=20};p.x+=22;return p.x;}",215688,281220,625291);
}
@test fn void record_selections_keep_all_bindings_and_reuse_ids_across_thirty_compounds(){
    var bytes::Buffer source=bytes::empty();append(ref mut source,b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};");
    var usize i=0;while(i<63){append(ref mut source,b"let x");assert(bytes::append_usize(ref mut source,i).is_ok);
        append(ref mut source,b"=0;");i+=1;}
    append(ref mut source,b"p.x+=42;return p.x;}");both(bytes::view(ref source));
    var bytes::Buffer repeated=bytes::empty();append(ref mut repeated,b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=12};");
    i=0;while(i<30){append(ref mut repeated,b"p.x+=1;");i+=1;}
    append(ref mut repeated,b"return p.x;}");both(bytes::view(ref repeated));
}

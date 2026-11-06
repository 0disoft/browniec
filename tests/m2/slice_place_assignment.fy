module tests::m2::slice_place_assignment;
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
fn void append(ref mut bytes::Buffer b,ref u8[] s){assert(bytes::append(b,s).is_ok);}
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

fn void compound(ref u8[] tag,ref u8[] left,ref u8[] op,ref u8[] right){
    var bytes::Buffer b=bytes::empty();append(ref mut b,b"module main;fn i32 main(){var ");append(ref mut b,tag);
    append(ref mut b,b"[1] a=[");append(ref mut b,left);append(ref mut b,b";1];let ref mut ");append(ref mut b,tag);
    append(ref mut b,b"[] p=ref mut a;p[0]");append(ref mut b,op);append(ref mut b,right);
    append(ref mut b,b";if(p[0]==42){return 42;}return 0;}");both(bytes::view(ref b));
}
@test fn void ten_slice_compounds_execute_in_every_integer_domain_and_bool_plain_store(){
    var usize i=0;while(i<5){let ref u8[] tag=if(i==0){b"i32"}else if(i==1){b"i64"}else if(i==2){b"u8"}else if(i==3){b"u32"}else{b"usize"};
        compound(tag,b"20",b"+=",b"22");compound(tag,b"64",b"-=",b"22");compound(tag,b"6",b"*=",b"7");
        compound(tag,b"84",b"/=",b"2");compound(tag,b"127",b"%=",b"85");compound(tag,b"21",b"<<=",b"1");
        compound(tag,b"84",b">>=",b"1");compound(tag,b"63",b"&=",b"42");compound(tag,b"0",b"^=",b"42");compound(tag,b"40",b"|=",b"2");i+=1;
    }
    both(b"module main;fn i32 main(){var a=[false];let ref mut bool[] p=ref mut a;p[0]=true;if(p[0]){return 42;}return 0;}");
}
@test fn void slice_index_and_old_scalar_survive_rhs_mutations_mixed_places_and_rotated_tickets(){
    both(b"module main;fn i32 main(){var a=[20;2];let ref mut i32[] p=ref mut a;var usize i=0;var hits=0;p[if(true){hits=hits+1;i}else{0}]+=if(true){i=1;p[0]=100;p[1]=99;hits=hits+1;22}else{0};if(hits==2 && p[1]==99){return p[0];}return 0;}");
    both(b"module main;fn i32 main(){var a=[20;2];var b=[0];let ref mut i32[] p=ref mut a;p[0]+=if(true){b[0]=22;p[0]=100;b[0]}else{0};return p[0];}");
    both(b"module main;fn i32 rhs(ref mut i32[] p){p[0]=100;return 22;}fn i32 main(){var a=[20];let ref mut i32[] p=ref mut a;p[0]+=rhs(ref mut p);return p[0];}");
    both(b"module main;fn i32 main(){var a=[20];let ref mut i32[] p=ref mut a;p[0]+=if(true){{let ref mut i32[] q=ref mut p;q[0]=100;}22}else{0};return p[0];}");
    both(b"module main;fn i32 f(ref mut i32[] p){p[0]+=22;return p[0];}fn i32 main(){var a=[20;3];let ref mut i32[] p=ref mut a;{let ref mut i32[] q=ref mut p[1..2];let result=f(ref mut q);}return p[1];}");
}
@test fn void slice_places_end_before_returns_propagation_and_loop_transfers(){
    both(b"module main;fn i32 main(){var a=[0];let ref mut i32[] p=ref mut a;p[0]=if(true){return 42;}else{0};return 0;}");
    both(b"module main;fn Option<i32> f(Option<i32> o){var a=[20];let ref mut i32[] p=ref mut a;p[0]+=o?;return .some(p[0]);}fn i32 main(){switch(f(.none)){case .some(_):{return 0;}case .none:{}}switch(f(.some(22))){case .some(v):{return v;}case .none:{return 0;}}}");
    both(b"module main;fn i32 main(){var a=[20];let ref mut i32[] p=ref mut a;p[0]+=if(true){while(true){break;}22}else{0};return p[0];}");
    both(b"module main;fn i32 main(){var a=[0];let ref mut i32[] p=ref mut a;while(true){p[0]+=if(true){break;}else{0};}return 42;}");
    both(b"module main;fn i32 main(){var a=[0];let ref mut i32[] p=ref mut a;var n=0;while(n<3){n=n+1;p[0]+=if(true){continue;}else{0};}return n+39;}");
    both(b"module main;fn i32[1] f(){var a=[0];let ref mut i32[] p=ref mut a;p[0]=if(true){return [42];}else{0};return [0];}fn i32 main(){let a=f();return a[0];}");
    both(b"module main;struct P{i32 x;}fn P f(){var a=[0];let ref mut i32[] p=ref mut a;p[0]=if(true){return P{.x=42};}else{0};return P{.x=0};}fn i32 main(){let p=f();return p.x;}");
    both(b"module main;fn void f(){var a=[0];let ref mut i32[] p=ref mut a;p[0]+=if(true){return;}else{0};}fn i32 main(){f();return 42;}");
    public_value(b"module main;fn ref u8[] f(ref u8[] b){var a=[0];let ref mut i32[] p=ref mut a;p[0]=if(true){return b;}else{0};return b;}fn i32 main(){let ref u8[] b=f(ref b\"*\");return b[0] as i32;}");
}
@test fn void slice_bounds_precede_rhs_returns_and_faults_and_checked_errors_remain(){
    failure(b"module main;fn i32 main(){var a=[0];let ref mut i32[] p=ref mut a;p[999]=1/0;return 0;}",14);
    failure(b"module main;fn i32 main(){var a=[0];let ref mut i32[] p=ref mut a;p[999]+=if(true){return 42;}else{0};return 0;}",14);
    failure(b"module main;fn i32 main(){var a=[0];let ref mut i32[] p=ref mut a[1..];p[0]=if(true){return 42;}else{0};return 0;}",14);
    failure(b"module main;fn i32 main(){var a=[0];let ref mut i32[] p=ref mut a;p[0]/=0;return 0;}",7);
    failure(b"module main;fn i32 main(){var u8[1] a=[255];let ref mut u8[] p=ref mut a;p[0]+=1;return 0;}",6);
    failure(b"module main;fn i32 main(){var a=[1];let ref mut i32[] p=ref mut a;p[0]<<=32;return 0;}",6);
    assert(!compiler::compile(b"module main;fn i32 main(){let a=[0];let ref i32[] p=ref a;p[0]+=42;return 0;}").is_ok);
    assert(!compiler::compile(b"module main;fn i32 main(){var a=[false];let ref mut bool[] p=ref mut a;p[0]^=true;return 0;}").is_ok);
    assert(!compiler::compile(b"module main;fn i32 main(){var a=[0];let ref mut i32[] p=ref mut a;p[0]+=true;return 0;}").is_ok);
    assert(!compiler::compile(b"module main;fn i32 main(){var a=[0];let ref mut i32[] p=ref mut a;for(;false;p[0]+=1){}return 0;}").is_ok);
}
@test fn void slice_source_ir_and_independent_exact_fuel_cover_plain_and_compound(){
    exact(b"module main;fn i32 main(){var a=[0;1];let ref mut i32[] p=ref mut a;p[0]=42;return p[0];}",87285,152817,496889);
    exact(b"module main;fn i32 main(){var a=[20;1];let ref mut i32[] p=ref mut a;p[0]+=22;return p[0];}",91452,156984,501057);
    switch(compiler::compile(b"module main;fn i32 main(){var a=[20];let ref mut i32[] p=ref mut a;p[0]+=22;return p[0];}")){
        case .ok(p):{var usize pc=0;var usize reads=0;var usize selects=0;var usize stores=0;var usize ends=0;
            while(pc<p.count){let u8 op=p.code[pc*8];if(op>=83 && op<=85){assert(p.code[pc*8+4]==1);}
                if(op==83){selects+=1;}if(op==84){reads+=1;}if(op==85){stores+=1;}if(op==86){ends+=1;}assert(op!=60);pc+=1;}
            assert(p.arrays.count==1 && selects==1 && reads==1 && stores==1 && ends==1);}
        case .err(_):{assert(false);}
    };
}
@test fn void slice_selections_keep_sixty_four_bindings_and_reuse_ids_for_thirty_compounds(){
    var bytes::Buffer source=bytes::empty();append(ref mut source,b"module main;fn i32 main(){var a=[0];let ref mut i32[] p=ref mut a;");
    var usize i=0;while(i<62){append(ref mut source,b"let x");assert(bytes::append_usize(ref mut source,i).is_ok);append(ref mut source,b"=0;");i+=1;}
    append(ref mut source,b"p[0]+=42;return p[0];}");both(bytes::view(ref source));
    var bytes::Buffer repeated=bytes::empty();append(ref mut repeated,b"module main;fn i32 main(){var a=[12];let ref mut i32[] p=ref mut a;");
    i=0;while(i<30){append(ref mut repeated,b"p[0]+=1;");i+=1;}
    append(ref mut repeated,b"return p[0];}");both(bytes::view(ref repeated));
}

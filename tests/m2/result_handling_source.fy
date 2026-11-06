module tests::m2::result_handling_source;
import compiler as compiler;
import program_image as programs;
import ir as ir;
import vm as vm;
import verifier as verifier;

fn void value(ref u8[] source){switch(compiler::compile_program(source,65536)){
    case .ok(p):{switch(programs::run_public(ref p,16000000)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};}
    case .err(_):{assert(false);}
};}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind && e.offset<source.len);}
};}
fn void exact(ref u8[] source,usize fuel,usize count){
    let ir::Program p=switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
    assert(p.count==count && verifier::verify(ref p).is_ok);
    var usize i=0;while(i<p.count){
        if(p.code[i*8]==24){
            let usize at=p.offsets[i];assert(source[at]==46 && source[at+1]==105);
            // Every instruction of this inspection keeps the original dot span.
            var usize j=i;while(j<i+7){assert(p.offsets[j]==at);j+=1;}
        }i+=1;
    }
    assert(switch(vm::run(ref p,fuel)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run(ref p,fuel-1)){case .ok(_):{false}case .err(e):{e.kind==8}});
}

@test fn void result_inspection_composes_with_calls_groups_boolean_contexts_and_existing_propagation(){
    value(b"module main;fn i32 main(){let Result<i32,i32> r=.ok(0);if(r.is_ok){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var Result<bool,bool> r=.err(true);if(!r.is_ok){r=.ok(false);}if((r).is_ok==true){return 42;}return 0;}");
    value(b"module main;fn Result<i32,bool> f(){return .ok(0);}fn i32 main(){let bool b=f().is_ok;if(b){return 42;}return 0;}");
    value(b"module main;fn Result<bool,i32> f(){return .err(0);}fn i32 main(){if(!((f())).is_ok){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let bool b=(if(true){.ok(1)}else{.err(false)}).is_ok;if(b){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let Result<i32,bool> r=.ok(42);if(!(r).is_ok){return 0;}switch(r){case .ok(n):{return n;}case .err(_):{return 0;}}}");
    value(b"module main;fn i32 main(){if((switch(.some(1)){case .some(_):{.err(0)}case .none:{.ok(true)}}).is_ok){return 0;}return 42;}");
    value(b"module main;fn Result<i32,i32> f(){return .ok(21);}fn Result<bool,i32> g(){let n=f()?;let Result<bool,i32> r=.ok(n==21);return .ok(r.is_ok);}fn i32 main(){if(g().is_ok){return 42;}return 0;}");
    value(b"module main;fn Result<i32,i32> f(){return .ok(42);}fn i32 main(){let Result<i32,i32> r=.ok(1);let n=if(r.is_ok){_ = f();42}else{0};return n;}");
}

@test fn void explicit_discard_evaluates_once_and_retains_capture_and_nonlocal_cleanup(){
    value(b"module main;fn Result<i32,bool> f(ref mut i32[] c){c[0]=c[0]+1;return .err(false);}fn i32 main(){var a=[40];_ = f(ref mut a);if(f(ref mut a).is_ok){return 0;}return a[0];}");
    value(b"module main;fn Result<i32,bool> f(ref mut i32[] c){c[0]=0;return .ok(1);}fn i32 main(){var a=[42];if(false && f(ref mut a).is_ok){return 0;}if(true || f(ref mut a).is_ok){return a[0];}return 0;}");
    value(b"module main;fn Result<i32,i32> take(i32[1] a){return .ok(a[0]);}fn i32 main(){let r=take([42]);_ = r;_ = (take([0]));_ = 1+2;return 42;}");
    value(b"module main;fn Result<i32,i32> take(i32[1] a,i32 n){return .ok(a[0]+n);}fn Result<i32,i32> work(){let Result<i32,i32> e=.err(42);_ = take([0],e?);return .ok(0);}fn i32 main(){switch(work()){case .ok(_):{return 0;}case .err(n):{return n;}}}");
    value(b"module main;fn Result<i32,i32> take(i32[1] a,i32 n){return .ok(n);}fn i32 main(){var n=40;while(n<42){_ = take([0],if(true){n=n+1;continue;}else{0});}while(true){_ = take([0],if(true){break;}else{0});}return n;}");
    value(b"module main;fn Result<i32,i32> f(){return .err(0);}fn i32 main(){let n=switch(.some(0)){case .some(_):{_ = f();42}case .none:{0}};return n;}");
    value(b"module main;fn void work(){let Result<i32,i32> r=.err(0);_ = r;}fn i32 main(){work();return 42;}");
    // No unused-binding rule is introduced by this source increment.
    value(b"module main;fn i32 main(){let Result<i32,i32> unused=.err(0);return 42;}");
}

@test fn void exact_existing_instruction_prices_spans_and_type_errors_are_preserved(){
    // Seven emitted inspection instructions: CASE, true/STORE/JUMP,
    // false/STORE, LOAD. Success executes five units, failure four.
    exact(b"module main;fn i32 main(){let Result<i32,i32> r=.ok(0);_ = r.is_ok;return 42;}",9,11);
    exact(b"module main;fn i32 main(){let Result<i32,i32> r=.err(0);_ = r.is_ok;return 42;}",8,11);
    exact(b"module main;fn i32 main(){let Result<i32,i32> r=.ok(0);_ = r;return 42;}",4,4);
    exact(b"module main;fn i32 main(){_ = 0;return 42;}",3,3);
    rejected(b"module main;fn i32 main(){let o=.some(1);_ = o.is_ok;return 0;}",3);
    rejected(b"module main;fn i32 main(){_ = (42).is_ok;return 0;}",3);
    rejected(b"module main;fn i32 main(){_ = true.is_ok;return 0;}",3);
    rejected(b"module main;fn i32 main(){let Result<i32,i32> r=.ok(0);_ = r.other;return 0;}",3);
    rejected(b"module main;fn i32 main(){let Result<i32,i32> r=.ok(0);_ = r.is_ok();return 0;}",2);
    rejected(b"module main;fn i32 main(){let Result<i32,i32> r=.ok(0);return r.is_ok;}",3);
    rejected(b"module main;fn i32 main(){let Result<i32,i32> r=.ok(0);_ = r.is_ok.is_ok;return 0;}",3);
    rejected(b"module main;fn i32 main(){let Result<i32,i32> r=.ok(0);_ = r.is_ok+1;return 0;}",3);
    rejected(b"module main;fn Result<i32,i32> f(){return .ok(0);}fn i32 main(){f();return 0;}",3);
    rejected(b"module main;fn i32 f(){return 0;}fn i32 main(){f();return 0;}",3);
    rejected(b"module main;fn void f(){}fn i32 main(){_ = f();return 0;}",3);
    rejected(b"module main;fn i32 main(){_ = .ok(0);return 0;}",3);
    rejected(b"module main;fn i32 main(){_ = (.err(false)).is_ok;return 0;}",3);
    rejected(b"module main;fn i32 main(){for(_ = 0;false;){}return 0;}",3);
    rejected(b"module main;fn i32 main(){_ += 1;return 0;}",2);
    rejected(b"module main;fn i32 main(){_ = 1 return 0;}",2);
}

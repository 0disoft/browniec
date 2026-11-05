module tests::m2::option_constructor_inference;
import compiler as compiler;
import program_image as programs;
import ir as ir;
import vm as vm;
import verifier as verifier;

fn void value(ref u8[] source,i64 expected){
    let programs::PublicProgram p=switch(compiler::compile_program(source,65536)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    switch(programs::run_public(ref p,16000000)){case .ok(n):{assert(n==expected);}case .err(_):{assert(false);}};
}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){
    case .ok(p):{p}case .err(_):{assert(false);ir::empty()}
};}
fn void rejected(ref u8[] source){assert(!compiler::compile_program(source,65536).is_ok);}
@test fn void some_infers_exact_supported_payload_once_and_keeps_annotated_ir_and_fuel(){
    let ir::Program a=compiled(b"module main;fn i32 main(){let Option<i32> o=.some(42);switch(o){case .some(v):{return v;}case .none:{return 0;}}}");
    let ir::Program b=compiled(b"module main;fn i32 main(){let o=.some(42);switch(o){case .some(v):{return v;}case .none:{return 0;}}}");
    assert(verifier::verify(ref a).is_ok && verifier::verify(ref b).is_ok);
    assert(a.count==b.count && a.registers==b.registers && a.constant_count==b.constant_count);
    var usize i=0;while(i<a.count*8){assert(a.code[i]==b.code[i]);i+=1;}
    i=0;while(i<a.registers){assert(a.types[i]==b.types[i] && a.slots[i]==b.slots[i]);i+=1;}
    i=0;while(i<a.constant_count){assert(a.constants[i]==b.constants[i]);i+=1;}
    // One constant, one constructor, one selected case and one return.
    switch(vm::run(ref b,4)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
    switch(vm::run(ref b,3)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    value(b"module main;fn i32 main(){var o=.some(42);let old=o;o=.none;switch(old){case .some(v):{return v;}case .none:{return 0;}}}",42);
    value(b"module main;fn i32 main(){let o=(.some(false));switch(o){case .some(v):{if(v){return 0;}return 42;}case .none:{return 0;}}}",42);
    value(b"module main;fn i32 main(){let o=.some(-2147483648);switch(o){case .some(v):{if(v==-2147483648){return 42;}return 0;}case .none:{return 0;}}}",42);
    value(b"module main;fn i32 bump(ref mut i32[] p){p[0]=p[0]+1;return 32;}fn i32 main(){var a=[0;1];let o=.some(bump(ref mut a));switch(o){case .some(v):{return a[0]*10+v;}case .none:{return 0;}}}",42);
    value(b"module main;fn i32 read(i32[1] a){return a[0];}fn i32 main(){let o=.some(read([42;1]));switch(o){case .some(v):{return v;}case .none:{return 0;}}}",42);
    value(b"module main;fn Option<i32> f(Option<i32> o){let p=.some(o?+2);return p;}fn i32 main(){switch(f(.none)){case .some(_):{return 0;}case .none:{}}switch(f(.some(40))){case .some(v):{return v;}case .none:{return 0;}}}",42);
    value(b"module main;fn i32 main(){let o=.some(switch(.some(true)){case .some(v):{42}case .none:{return 0;}});switch(o){case .some(v):{return v;}case .none:{return 0;}}}",42);
    value(b"module main;fn i32 main(){let o=switch(.some(true)){case .some(v):{.some(42)}case .none:{.none}};switch(o){case .some(v):{return v;}case .none:{return 0;}}}",42);
    value(b"module main;fn ref u8[] id(ref u8[] p){let o=.some(p.len==1);return ref p;}fn i32 main(){let o=.some(id(ref [42;1])[0] as i32);switch(o){case .some(v):{return v;}case .none:{return 0;}}}",42);
}
@test fn void missing_context_unsupported_payloads_type_changes_and_pure_headers_still_reject(){
    rejected(b"module main;fn i32 main(){let o=.none;return 0;}");
    rejected(b"module main;fn i32 main(){let o=.ok(42);return 0;}");
    rejected(b"module main;fn i32 main(){let o=.err(true);return 0;}");
    rejected(b"module main;fn i32 main(){let o=.some(2147483648);return 0;}");
    rejected(b"module main;fn i32 main(){let o=.some(42 as i64);return 0;}");
    rejected(b"module main;fn u8 byte(){return 42;}fn i32 main(){let o=.some(byte());return 0;}");
    rejected(b"module main;fn i32 main(){let o=.some(b\"*\"[0]);return 0;}");
    rejected(b"module main;fn i32 main(){let o=.some(.some(42));return 0;}");
    rejected(b"module main;fn i32 main(){let o=.some(.none);return 0;}");
    rejected(b"module main;fn i32 main(){let o=.some();return 0;}");
    rejected(b"module main;fn i32 main(){let o=.some(1);o=.none;return 0;}");
    rejected(b"module main;fn i32 main(){var o=.some(1);o=.some(true);return 0;}");
    rejected(b"module main;fn i32 main(){for(var o=.some(1);false;){}return 0;}");
    rejected(b"module main;fn i32 main(){let o=switch(.some(true)){case .none:{.none}case .some(v):{.some(42)}};return 0;}");
}

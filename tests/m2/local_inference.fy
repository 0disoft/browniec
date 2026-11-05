module tests::m2::local_inference;
import compiler as compiler;
import program_image as programs;
import ir as ir;
import vm as vm;
import verifier as verifier;
import std::bytes as bytes;

fn void value(ref u8[] source,i64 expected){
    let programs::PublicProgram p=switch(compiler::compile_program(source,65536)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    var usize i=0;while(i<2){
        switch(programs::run_public(ref p,16000000)){case .ok(n):{assert(n==expected);}case .err(_):{assert(false);}};
        i+=1;
    }
}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
};}
@test fn void initializer_types_default_to_i32_and_preserve_all_existing_scalar_domains(){
    value(b"module main;fn i32 main(){let x=20;var y=22;y=y+x;return y;}",42);
    value(b"module main;fn i32 main(){var b=true;let old=b;b=false;if(old && !b){return 42;}return 0;}",42);
    value(b"module main;fn i64 big(){return -9223372036854775808;}fn i32 main(){let n=big();if(n==-9223372036854775808){return 42;}return 0;}",42);
    value(b"module main;fn u8 byte(){return 255;}fn u32 word(){return 4294967295;}fn usize size(){return 18446744073709551615;}fn i32 main(){var a=byte();let b=word();let c=size();a=42;if(b==4294967295 && c==18446744073709551615){return a as i32;}return 0;}",42);
    value(b"module main;fn i32 main(){let n=-2147483648;let wide=42 as i64;if(n==-2147483648 && wide==42){return 42;}return 0;}",42);
}
@test fn void inferred_bindings_keep_initialization_order_value_copies_and_lexical_scopes(){
    value(b"module main;fn i32 bump(ref mut i32[] p){p[0]=p[0]+1;return 32;}fn i32 main(){var i32[1] n=[0;1];let x=bump(ref mut n);return n[0]*10+x;}",42);
    value(b"module main;fn i32 main(){var x=20;let old=x;x=0;{let y=22;x=old+y;}return x;}",42);
    value(b"module main;fn i32 main(){var sum=0;for(var i=0;i<4;i=i+1){let n=i;sum=sum+n;}return sum+36;}",42);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;let n=switch(o){case .some(v):{v}case .none:{let x=20;var y=21;y=y+1;x+y}};return n;}",42);
}
@test fn void complete_tagged_expression_types_survive_inference_and_reassignment(){
    value(b"module main;fn Option<i32> make(){return .some(42);}fn i32 main(){let o=make();let copy=o;switch(copy){case .some(n):{return n;}case .none:{return 0;}}}",42);
    value(b"module main;fn Result<i32,bool> make(){return .ok(1);}fn i32 main(){var r=make();r=.ok(42);switch(r){case .ok(n):{return n;}case .err(e):{return 0;}}}",42);
    rejected(b"module main;fn i32 main(){let x=.none;return 0;}",3);
    rejected(b"module main;fn i32 main(){let x=.ok(42);return 0;}",3);
}
@test fn void invalid_names_uninitialized_uses_and_type_changes_are_rejected(){
    rejected(b"module main;fn i32 main(){let x=x;return 0;}",3);
    rejected(b"module main;fn i32 main(){let x=y;let y=1;return x;}",3);
    rejected(b"module main;fn i32 main(){let x=1;let x=2;return x;}",3);
    rejected(b"module main;fn i32 main(){{let x=1;}return x;}",3);
    rejected(b"module main;fn i32 main(){let x=1;x=2;return x;}",3);
    rejected(b"module main;fn i32 main(){var x=1;x=true;return x;}",3);
    rejected(b"module main;fn i32 main(){let x=2147483648;return 0;}",3);
    rejected(b"module main;fn i32 main(){let x;return 0;}",3);
    rejected(b"module main;fn i32 main(){for(var i=0;i<1;let n=1){}return 0;}",2);
    rejected(b"module main;fn i32 id(){return 0;}fn i32 main(){for(var i=id();i<1;i=i+1){}return 0;}",3);
}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){
    case .ok(p):{p}case .err(_):{assert(false);ir::empty()}
};}
@test fn void inference_keeps_scalar_ir_and_exact_fuel_identical_to_annotations(){
    let ir::Program a=compiled(b"module main;fn i32 main(){var i32 n=40;let i32 extra=2;n=n+extra;return n;}");
    let ir::Program b=compiled(b"module main;fn i32 main(){var n=40;let extra=2;n=n+extra;return n;}");
    assert(verifier::verify(ref a).is_ok && verifier::verify(ref b).is_ok);
    assert(a.count==b.count && a.registers==b.registers && a.constant_count==b.constant_count);
    var usize i=0;while(i<a.count*8){assert(a.code[i]==b.code[i]);i+=1;}
    i=0;while(i<a.registers){assert(a.types[i]==b.types[i] && a.slots[i]==b.slots[i]);i+=1;}
    i=0;while(i<a.constant_count){assert(a.constants[i]==b.constants[i]);i+=1;}
    switch(vm::run(ref b,b.count)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
    switch(vm::run(ref b,b.count-1)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
}
@test fn void retained_byte_reads_and_scalar_locals_in_returned_borrow_bodies_keep_admission(){
    value(b"module main;fn i32 main(){let n=b\"*\"[0];return n as i32;}",42);
    value(b"module main;fn ref u8[] same(ref u8[] p){let count=p.len;return ref p;}fn i32 main(){let ref u8[] p=same(ref b\"*\");let n=p[0];return n as i32;}",42);
}
fn void append(ref mut bytes::Buffer b,ref u8[] s){assert(bytes::append(b,s).is_ok);}
fn void locals_limit(usize count,bool pass){
    var bytes::Buffer b=bytes::empty();append(ref mut b,b"module main;fn i32 main(){");
    let ref u8[] letters=b"abcdefghijklmnopqrstuvwxyz";var usize i=0;
    while(i<count){append(ref mut b,b"let n");let usize a=i/26;let usize c=i%26;
        append(ref mut b,letters[a..a+1]);append(ref mut b,letters[c..c+1]);append(ref mut b,b"=1;");i+=1;}
    append(ref mut b,b"return 42;}");
    if(pass){value(bytes::view(ref b),42);}else{rejected(bytes::view(ref b),4);}
}
@test fn void inferred_locals_preserve_the_original_64_binding_limit(){
    locals_limit(64,true);locals_limit(65,false);
}
fn void nested_initializer(usize count,bool image,bool pass){
    var bytes::Buffer b=bytes::empty();
    append(ref mut b,b"module main;fn i32 id(i32 x,i32[1] a){return x;}fn i32 main(){let i32[1] a=[0;1];");
    if(image){append(ref mut b,b"let ref u8[] marker=b\"*\";");}append(ref mut b,b"let n=");
    var usize i=0;while(i<count){append(ref mut b,b"id(");i+=1;}append(ref mut b,b"42");
    i=0;while(i<count){append(ref mut b,b",a)");i+=1;}append(ref mut b,b";return n;}");
    if(pass){value(bytes::view(ref b),42);}else{rejected(bytes::view(ref b),4);}
}
@test fn void inferred_initializers_keep_32_deep_captured_calls_without_native_stack_overrides(){
    nested_initializer(32,false,true);nested_initializer(33,false,false);
    nested_initializer(32,true,true);nested_initializer(33,true,false);
}

module tests::m2::reference_inference_shadow;
import compiler as compiler;
import program_image as programs;
import ir as ir;

fn void same(ref u8[] inferred,ref u8[] annotated){
    let programs::PublicProgram a=switch(compiler::compile_program(inferred,65536)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    let programs::PublicProgram b=switch(compiler::compile_program(annotated,65536)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    let ref ir::Program left=programs::public_body(ref a);let ref ir::Program right=programs::public_body(ref b);
    assert(left.count==right.count && left.registers==right.registers && left.constant_count==right.constant_count);
    var usize i=0;while(i<left.count*8){assert(left.code[i]==right.code[i]);i+=1;}
    switch(programs::run_public(ref a,16000000)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
    switch(programs::run_public(ref b,16000000)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
}
@test fn void scalar_aliases_shadow_reference_functions_without_becoming_calls(){
    same(b"module main;fn ref u8[] owner(){return b\"!\";}fn ref u8[] take(ref u8[] input){let i32 owner=0;let x=owner;if(x==0){return ref input;}return ref input;}fn i32 main(){return take(ref b\"*\")[0] as i32;}",
         b"module main;fn ref u8[] owner(){return b\"!\";}fn ref u8[] take(ref u8[] input){let i32 owner=0;let i32 x=owner;if(x==0){return ref input;}return ref input;}fn i32 main(){return take(ref b\"*\")[0] as i32;}");
    same(b"module main;fn ref u8[] owner(){return b\"!\";}fn ref u8[] take(ref u8[] input){let owner=0;let x=((owner));let alias=input;if(x==0){return ref alias;}return ref input;}fn i32 main(){return take(ref b\"*\")[0] as i32;}",
         b"module main;fn ref u8[] owner(){return b\"!\";}fn ref u8[] take(ref u8[] input){let i32 owner=0;let i32 x=((owner));let ref u8[] alias=input;if(x==0){return ref alias;}return ref input;}fn i32 main(){return take(ref b\"*\")[0] as i32;}");
    assert(!compiler::compile_program(b"module main;fn ref u8[] owner(){return b\"!\";}fn i32 main(){let p=owner;return 0;}",65536).is_ok);
}

module tests::m2::evaluation_entry;
import compiler as compiler;
import errors as errors;
import ir as ir;
import verifier as verifier;
import vm as vm;
import std::bytes as bytes;
fn bytes::Buffer heads(usize depth){
    var bytes::Buffer source=bytes::empty();assert(bytes::append(ref mut source,b"module main;fn i32 main(){return if(").is_ok);
    var usize i=0;while(i<depth){assert(bytes::append(ref mut source,b"if(").is_ok);i+=1;}assert(bytes::append(ref mut source,b"true").is_ok);
    i=0;while(i<depth){assert(bytes::append(ref mut source,b"){true}else{false}").is_ok);i+=1;}
    assert(bytes::append(ref mut source,b"){42}else{0};}").is_ok);return source;
}
fn void check(ref u8[] source,bool admitted){
    let Result<ir::Program,errors::Error> result=compiler::compile(source);
    switch(result){case .ok(program):{assert(admitted && verifier::verify(ref program).is_ok);
        assert(switch(vm::run_with_array_limit(ref program,10000000,65536)){case .ok(n):{n==42}case .err(_):{false}});}
        case .err(e):{assert(!admitted && e.kind==4 && e.offset==126);}};
}
@test fn void full_compile_keeps_conditional_head_depth_on_default_stack(){
    let bytes::Buffer good=heads(30);check(bytes::view(ref good),true);
    let bytes::Buffer bad=heads(31);check(bytes::view(ref bad),false);
}

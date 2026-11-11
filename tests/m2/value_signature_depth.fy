module tests::m2::value_signature_depth;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;
import std::bytes as bytes;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn values::Program compiled(ref u8[] text){return switch(source::compile(text)){
    case .ok(v):{v}case .err(_):{assert(false);compiled(text)}
};}
fn void value(ref u8[] text){
    let values::Program p=compiled(text);assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void rejected(ref u8[] text,u8 kind){
    assert(switch(source::compile(text)){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset<=text.len}});
}

fn bytes::Buffer nested(usize count){var bytes::Buffer text=bytes::empty();
    assert(bytes::append(ref mut text,b"module main;fn Option<Result<Option<Result<Buffer,u8>>,i64>> probe(){").is_ok);var usize i=0;
    while(i<count){assert(bytes::append(ref mut text,b"if(true){").is_ok);i+=1;}
    assert(bytes::append(ref mut text,b"_ = 1;").is_ok);
    i=0;while(i<count){assert(bytes::append(ref mut text,b"}else{}").is_ok);i+=1;}
    assert(bytes::append(ref mut text,b"return .none;}fn i32 main(){let result=probe();_ = result;return 42;}").is_ok);return text;
}
@test fn void four_wrapper_signatures_with_32_controls_execute_and_33_reject(){
    let bytes::Buffer good=nested(32);value(bytes::view(ref good));let bytes::Buffer bad=nested(33);rejected(bytes::view(ref bad),4);
}

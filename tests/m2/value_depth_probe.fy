module tests::m2::value_depth_probe;
import value_source as source;
import value_ir as values;
import value_properties as properties;
import std::bytes as bytes;
import ir as ir;
fn void probe(bool staged){var usize depth=32;while(depth<=33){var bytes::Buffer input=bytes::empty();assert(bytes::append(ref mut input,b"module main;fn i32 id(i32 x){return x;}fn i32 main(){return ").is_ok);
    var usize i=0;while(i<depth){assert(bytes::append(ref mut input,b"id(").is_ok);i+=1;}assert(bytes::append(ref mut input,b"42").is_ok);i=0;while(i<depth){assert(bytes::append(ref mut input,b")").is_ok);i+=1;}assert(bytes::append(ref mut input,b";}").is_ok);
    var values::Program p=values::Program{.body=ir::empty(),.catalog=properties::empty(),.types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    switch(source::lower_candidate(bytes::view(ref input),ref mut p,staged)){case .ok(_):{assert(depth==32);}case .err(e):{assert(depth==33 && e.kind==4);}};depth+=1;}}
@test fn void raw_nested_calls_keep_default_stack(){probe(false);}
@test fn void staged_nested_calls_keep_default_stack(){probe(true);}

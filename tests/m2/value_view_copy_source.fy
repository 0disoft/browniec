module tests::m2::value_view_copy_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(v):{v}case .err(_):{assert(false);compiled(input)}
};}
fn void value(ref u8[] input){
    let values::Program p=compiled(input);assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void rejected(ref u8[] input,u8 kind){
    assert(switch(source::compile(input)){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset<=input.len}});
}
fn void failure(ref u8[] input,u8 kind){
    let values::Program p=compiled(input);assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){case .ok(_):{false}case .err(e):{e.kind==kind}});
}

@test fn void selected_nested_empty_and_temporary_views_copy_to_independent_owners(){
    // A nonzero range copies only its initialized window; writing the independent
    // copy must neither change nor release the original named view.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);_ = bytes::push(ref mut b,11);let ref u8[] v=bytes::view(ref b);switch(bytes::copy(ref v[1..2])){case .ok(owner):{var copy=owner;bytes::write(ref mut copy,0,9);if(bytes::len(ref copy)==1 && bytes::read(ref copy,0)==9 && v[1]==42 && bytes::read(ref b,0)==7){return 42;}return 0;}case .err(_):{return 0;}}}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b)[1..];let ref u8[] alias=v;switch(brownie::bytes::copy(ref alias[..][0..1])){case .ok(owner):{if(bytes::len(ref owner)==1 && bytes::read(ref owner,0)==42 && alias[0]==42){return 42;}return 0;}case .err(_):{return 0;}}}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);let ref u8[] v=bytes::view(ref b);switch(bytes::copy(ref v[1..1])){case .ok(owner):{var copy=owner;_ = bytes::push(ref mut copy,42);if(bytes::len(ref copy)==1 && bytes::read(ref copy,0)==42 && v[0]==7){return 42;}return 0;}case .err(_):{return 0;}}}");
    // An owning copy may escape an anonymous input without extending its view.
    value(b"module main;fn i32 main(){switch(bytes::copy(ref bytes::view(ref bytes::empty()))){case .ok(owner):{var copy=owner;_ = bytes::push(ref mut copy,42);if(bytes::read(ref copy,0)==42){return 42;}return 0;}case .err(_):{return 0;}}}");
    // Dropping the anonymous nonempty source compacts backing before the copy
    // is unwrapped; its independent payload must survive that compaction.
    value(b"module main;fn Buffer make(){var b=bytes::empty();_ = bytes::push(ref mut b,42);return b;}fn i32 main(){switch(bytes::copy(ref bytes::view(ref make()))){case .ok(owner):{if(bytes::len(ref owner)==1 && bytes::read(ref owner,0)==42){return 42;}return 0;}case .err(_):{return 0;}}}");
    var values::Program p=compiled(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);_ = bytes::copy(ref v);return 42;}");
    var bool found=false;var usize pc=0;while(pc<p.body.count){if(p.body.code[pc*8]==112){
        found=true;assert(p.body.code[pc*8+1]<16 && p.body.code[pc*8+2]<16 && p.body.code[pc*8+3]<16);
        var usize i=4;while(i<8){assert(p.body.code[pc*8+i]==0);i+=1;}
    }pc+=1;}assert(found);assert(verifier::inspect_values(ref p).is_ok);
}

@test fn void copied_results_compose_with_return_propagation_loops_and_early_endpoints(){
    value(b"module main;fn Result<Buffer,u8> copied(){let b=bytes::empty();let ref u8[] v=bytes::view(ref b);return bytes::copy(ref v);}fn i32 main(){switch(copied()){case .ok(owner):{if(bytes::len(ref owner)==0){return 42;}return 0;}case .err(_):{return 0;}}}");
    value(b"module main;fn Result<usize,u8> size(){let b=bytes::empty();let v=bytes::view(ref b);let owner=bytes::copy(ref v)?;return .ok(bytes::len(ref owner));}fn i32 main(){switch(size()){case .ok(n):{if(n==0){return 42;}return 0;}case .err(_):{return 0;}}}");
    // Every iteration closes only the anonymous copy receiver and drops its new
    // result, preserving the original view's native pin and actual bytes.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);{let v=bytes::view(ref b);for(var n=0;n<3;n+=1){_ = bytes::copy(ref v[..]);if(v[0]!=42){return 0;}}}bytes::write(ref mut b,0,7);return 42;}");
    value(b"module main;fn i32 main(){while(true){let b=bytes::empty();let v=bytes::view(ref b);_ = bytes::copy(ref v[0..if(true){break;}else{0}]);}return 42;}");
    value(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);_ = bytes::copy(ref v[0..if(true){return 42;}else{0}]);return 0;}");
}

@test fn void view_copy_keeps_reference_types_obligations_and_runtime_bounds(){
    rejected(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);bytes::copy(ref v);return 42;}",18);
    rejected(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let result=bytes::copy(ref v);return 42;}",18);
    rejected(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);_ = bytes::copy(v);return 42;}",3);
    rejected(b"module main;fn i32 main(){let b=bytes::empty();var v=bytes::view(ref b);_ = bytes::copy(ref mut v);return 42;}",3);
    rejected(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let Result<Buffer,bool> result=bytes::copy(ref v);_ = result;return 42;}",3);
    rejected(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let Result<usize,u8> result=bytes::copy(ref v);_ = result;return 42;}",3);
    rejected(b"module main;fn i32 main(){_ = bytes::copy(ref 0);return 42;}",3);
    // Closing the intrinsic's capture must not close the original lexical view.
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let v=bytes::view(ref b);_ = bytes::copy(ref v);bytes::write(ref mut b,0,7);return 42;}",3);
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,switch(bytes::copy(ref bytes::view(ref b))){case .ok(_):{42}case .err(_):{0}});return 42;}",3);
    failure(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);_ = bytes::copy(ref v[0..1]);return 42;}",14);
    failure(b"module main;fn i32 main(){let b=bytes::empty();_ = bytes::copy(ref bytes::view(ref b)[1..0]);return 42;}",14);
    // A later invocation is independent of the failed range/copy attempt.
    value(b"module main;fn i32 main(){_ = bytes::copy(ref bytes::view(ref bytes::empty()));return 42;}");
}

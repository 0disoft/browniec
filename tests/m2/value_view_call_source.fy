module tests::m2::value_view_call_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(v):{v}case .err(_):{assert(false);compiled(input)}
};}
fn void value(ref u8[] input){let values::Program p=compiled(input);
    assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void rejected(ref u8[] input){assert(switch(source::compile(input)){
    case .ok(p):{!verifier::inspect_values(ref p).is_ok}case .err(e):{e.kind==3 && e.offset<=input.len}
});}
fn void failure(ref u8[] input,u8 expected){let values::Program p=compiled(input);
    assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){case .ok(_):{false}case .err(e):{e.kind==expected && e.offset<=input.len}});
    value(b"module main;fn usize count(ref u8[] v){return v.len;}fn i32 main(){let b=bytes::empty();if(count(ref bytes::view(ref b))==0){return 42;}return 0;}");
}

@test fn void shared_formals_mix_with_owned_and_scalar_actuals_and_release_after_calls(){
    value(b"module main;fn usize count(ref u8[] v){return v.len;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);{let v=bytes::view(ref b);if(count(ref v)!=1){return 0;}}bytes::write(ref mut b,0,7);return 42;}");
    value(b"module main;fn usize mixed(ref u8[] v,Buffer b,usize n){return v.len+bytes::len(ref b)+n;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let c=bytes::empty();if(mixed(ref bytes::view(ref b),c,6)!=7){return 0;}bytes::write(ref mut b,0,7);return 42;}");
    value(b"module main;fn usize twice(ref u8[] a,ref u8[] b){return a.len+b.len;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);{let v=bytes::view(ref b);if(twice(ref v,ref v)!=2){return 0;}}bytes::write(ref mut b,0,7);return 42;}");
}

@test fn void returned_selected_ranges_forward_multiple_inputs_and_survive_caller_capture_cleanup(){
    value(b"module main;fn ref u8[] tail(ref u8[] v){return v[1..];}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);{let r=tail(ref bytes::view(ref b));if(r.len!=1 || r[0]!=42){return 0;}}bytes::write(ref mut b,0,9);return 42;}");
    value(b"module main;fn ref u8[] second(ref u8[] a,ref u8[] b){return b;}fn ref u8[] forward(ref u8[] a,ref u8[] b){let r=second(ref a,ref b);return r[0..1];}fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);{let r=forward(ref bytes::view(ref a),ref bytes::view(ref b));bytes::write(ref mut a,0,9);if(r[0]!=42){return 0;}}bytes::write(ref mut b,0,9);return 42;}");
    value(b"module main;fn ref u8[] identity(ref u8[] v){return v;}fn i32 main(){{let r=identity(ref bytes::view(ref bytes::empty()));if(r.len!=0){return 0;}}return 42;}");
}

@test fn void wrong_origin_mutable_local_escape_and_overlapping_owning_actuals_reject(){
    rejected(b"module main;fn ref u8[] wrong(ref u8[] a,ref u8[] b,bool choose){if(choose){return a;}return b;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] local(ref u8[] v){let b=bytes::empty();return bytes::view(ref b);}fn i32 main(){return 42;}");
    rejected(b"module main;fn usize count(ref mut u8[] v){return v.len;}fn i32 main(){return 42;}");
    rejected(b"module main;fn usize mixed(ref u8[] v,Buffer b){return v.len;}fn i32 main(){let b=bytes::empty();_ = mixed(ref bytes::view(ref b),b);return 42;}");
    rejected(b"module main;fn i32 main(){let r=bytes::view(ref bytes::empty());return 42;}");
}

@test fn void runtime_bounds_and_recursive_registry_limits_drain_before_fresh_invocation(){
    failure(b"module main;fn ref u8[] tail(ref u8[] v,usize i){return v[i..];}fn i32 main(){let b=bytes::empty();let r=tail(ref bytes::view(ref b),1);return 42;}",14);
    failure(b"module main;fn usize deep(ref u8[] v,usize n){if(n==0){return v.len;}return deep(ref v,n-1);}fn i32 main(){let b=bytes::empty();_ = deep(ref bytes::view(ref b),20);return 42;}",13);
}

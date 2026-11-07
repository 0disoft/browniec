module tests::m2::value_fresh_loop_owners_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import render as render;
import std::io as io;
import buffer_growth as growth;

@effects(console)
fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(v):{v}case .err(e):{let i32 printed=render::outcome(true,false,true,0,e);assert(false);compiled(input)}
};}
@effects(console)
fn void value(ref u8[] input){
    let values::Program p=compiled(input);
    switch(verifier::inspect_values(ref p)){case .ok(_):{}case .err(e):{
        let i32 printed=render::outcome(true,false,true,0,e);
        assert(false);}};
    assert(switch(vm::run_values(ref p,10000000,0,
        growth::Limits{.object=4096,.instance=1048576,.engine=1048576})){
        case .ok(v):{if(v!=42){let bool printed=io::write_stderr_i64(v).is_ok;}v==42}case .err(e):{let i32 printed=render::outcome(true,true,true,0,e);false}
    });
}
// These are source errors, not executable IR accepted pending a later rejection.
fn void rejected(ref u8[] input){assert(switch(source::compile(input)){
    case .ok(_):{false}case .err(e):{e.kind==3 && e.offset<=input.len}
});}

@effects(console)
@test fn void fresh_empty_carrier_repeats(){
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();var ref u8[] r=bytes::view(ref b);var n=0;while(n<3){r=id(ref bytes::view(ref bytes::empty()));n+=1;}if(n==3 && r.len==0){return 42;}return 0;}");
}

@effects(console)
@test fn void fresh_payload_ranges_and_classic_continue_keep_concrete_bytes(){
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let b=make(9);var ref u8[] r=bytes::view(ref b);var n=0;for(;n<3;n+=1){if(n!=0){if(r.len!=1 || r[0]!=42){return 0;}}r=id(ref bytes::view(ref make(42))[1..]);continue;}if(n==3 && r.len==1 && r[0]==42){return 42;}return 0;}");
    // A selected CALL may return a narrower range unknown to the caller.
    value(b"module main;fn ref u8[] tail(ref u8[] v){return v[1..];}fn Buffer make(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);return b;}fn i32 main(){let b=make();var ref u8[] r=bytes::view(ref b);var n=0;while(n<3){r=tail(ref bytes::view(ref make()));n+=1;}if(r.len==1 && r[0]==42){return 42;}return 0;}");
}

@effects(console)
@test fn void zero_trip_break_and_nested_fresh_assignment_execute(){
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(){var b=bytes::empty();_ = bytes::push(ref mut b,42);return b;}fn i32 main(){let b=make();var ref u8[] r=bytes::view(ref b);while(false){r=id(ref bytes::view(ref bytes::empty()));}if(r[0]==42){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(){var b=bytes::empty();_ = bytes::push(ref mut b,42);return b;}fn i32 main(){let b=bytes::empty();var ref u8[] r=bytes::view(ref b);var n=0;while(n<3){r=id(ref bytes::view(ref make()));if(n==1){break;}n+=1;}if(n==1 && r[0]==42){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();var ref u8[] r=bytes::view(ref b);var n=0;while(n<2){var j=0;while(j<2){r=id(ref bytes::view(ref bytes::empty()));j+=1;}n+=1;}if(n==2 && r.len==0){return 42;}return 0;}");
    // These terminal paths actually execute after a fresh owner crosses a backedge.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(){var b=bytes::empty();_ = bytes::push(ref mut b,42);return b;}fn u8 work(){let b=bytes::empty();var ref u8[] r=bytes::view(ref b);var n=0;while(n<3){if(n==1){return r[0];}r=id(ref bytes::view(ref make()));n+=1;}return 0;}fn i32 main(){if(work()==42){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Option<i32> work(){let b=bytes::empty();var ref u8[] r=bytes::view(ref b);var n=0;while(n<2){if(n==1){let Option<i32> o=.none;let x=o?;return .some(x);}r=id(ref bytes::view(ref bytes::empty()));n+=1;}return .some(0);}fn i32 main(){switch(work()){case .none:{return 42;}case .some(_):{return 0;}}}");

}

@effects(console)
@test fn void fresh_aliases_keep_old_contents_until_explicit_rebind(){
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let b=make(7);var ref u8[] r=bytes::view(ref b);var ref u8[] s=r;var n=0;while(n<3){r=id(ref bytes::view(ref make(42)));if(n==0){if(s[0]!=7){return 0;}}else{if(s[0]!=42){return 0;}}s=r;n+=1;}if(r[0]==42 && s[0]==42){return 42;}return 0;}");
}

@effects(console)
fn void failure(ref u8[] input,u8 kind){
    let values::Program p=compiled(input);assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,
        growth::Limits{.object=4096,.instance=1048576,.engine=1048576})){
        case .ok(_):{false}case .err(e):{e.kind==kind}
    });
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();var ref u8[] r=bytes::view(ref b);var n=0;while(n<3){r=id(ref bytes::view(ref bytes::empty()));n+=1;}return 42;}");
}
@effects(console)
@test fn void fresh_failures_after_backedge_and_source_pins_remain_honest(){
    failure(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();var ref u8[] r=bytes::view(ref b);var n=0;while(n<3){if(n==1){_ = r[0];}r=id(ref bytes::view(ref bytes::empty()));n+=1;}return 42;}",14);
    failure(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();var ref u8[] r=bytes::view(ref b);var u8 x=255;var n=0;while(n<3){r=id(ref bytes::view(ref bytes::empty()));if(n==1){x+=1;}n+=1;}return 42;}",6);
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();let owner=bytes::empty();var ref u8[] r=bytes::view(ref b);while(true){r=id(ref bytes::view(ref bytes::empty()));_ = owner;continue;}return 42;}");
    rejected(b"module main;fn i32 main(){let b=bytes::empty();var ref u8[] r=bytes::view(ref b);_ = b;if(r.len==0){return 42;}return 0;}");
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var b=bytes::empty();var ref u8[] r=bytes::view(ref b);var n=0;while(n<2){bytes::write(ref mut b,0,7);r=id(ref bytes::view(ref bytes::empty()));n+=1;}return 42;}");
}

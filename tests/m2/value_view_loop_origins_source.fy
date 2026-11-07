module tests::m2::value_view_loop_origins_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;

fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(v):{v}case .err(_):{assert(false);compiled(input)}
};}
fn void value(ref u8[] input){
    let values::Program p=compiled(input);
    assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,
        growth::Limits{.object=4096,.instance=1048576,.engine=1048576})){
        case .ok(v):{v==42}case .err(_):{false}
    });
}
// These are source errors, not executable IR accepted pending a later rejection.
fn void rejected(ref u8[] input){assert(switch(source::compile(input)){
    case .ok(_):{false}case .err(e):{e.kind==3 && e.offset<=input.len}
});}

fn void named_reassignment_and_repeated_ranges(){
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);{var ref u8[] r=bytes::view(ref a);var n=0;while(n<3){r=bytes::view(ref b);n+=1;}if(n!=3 || r[0]!=42){return 0;}}bytes::write(ref mut a,0,8);bytes::write(ref mut b,0,9);return 42;}");
    value(b"module main;fn i32 main(){var a=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut a,9);_ = bytes::push(ref mut a,42);{var ref u8[] r=bytes::view(ref a);var n=0;while(n<2){r=r[1..];n+=1;}if(r.len!=1 || r[0]!=42){return 0;}}bytes::write(ref mut a,0,8);return 42;}");
}
fn void condition_continue_and_nested_loops(){
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);var ref u8[] r=bytes::view(ref a);var n=0;while(if(n<2){r=bytes::view(ref b);true}else{false}){n+=1;continue;}if(n==2 && r[0]==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);var ref u8[] r=bytes::view(ref a);var i=0;while(i<2){var j=0;while(j<2){r=bytes::view(ref b);j+=1;continue;}i+=1;}if(r[0]==42){return 42;}return 0;}");
}
@test fn void while_ranges_conditions_continue_and_nested_origin_changes_execute(){
    named_reassignment_and_repeated_ranges();condition_continue_and_nested_loops();
}

fn void classic_post_break_and_multi_round_origin_chain(){
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);var ref u8[] r=bytes::view(ref a);var n=0;for(;n<3;n+=1){r=bytes::view(ref b);if(n==0){continue;}break;}if(n==1 && r[0]==42){return 42;}return 0;}");
    // r gains c only after information crosses multiple loop backedges. A
    // single union of the first body exit with the header is insufficient.
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();var c=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,9);_ = bytes::push(ref mut c,42);var ref u8[] r=bytes::view(ref a);var ref u8[] s=bytes::view(ref a);var ref u8[] t=bytes::view(ref b);for(var n=0;n<3;n+=1){r=s[..];s=t;t=bytes::view(ref c);}if(r[0]==42 && s[0]==42 && t[0]==42){return 42;}return 0;}");
}
fn void formal_origins_and_selected_shared_calls(){
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn u8 choose(ref u8[] a,ref u8[] b){var ref u8[] r=a;for(var n=0;n<2;n+=1){r=id(ref b[..]);continue;}return r[0];}fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);if(choose(ref bytes::view(ref a),ref bytes::view(ref b))==42){return 42;}return 0;}");
}
@test fn void for_post_break_multi_round_widening_and_formal_roots_execute(){
    classic_post_break_and_multi_round_origin_chain();formal_origins_and_selected_shared_calls();
}

fn void zero_trip_and_distinct_break_exit(){
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,42);_ = bytes::push(ref mut b,7);{var ref u8[] r=bytes::view(ref a);while(false){r=bytes::view(ref b);}if(r[0]!=42){return 0;}}bytes::write(ref mut a,0,9);bytes::write(ref mut b,0,8);return 42;}");
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);{var ref u8[] r=bytes::view(ref a);var n=0;while(n<3){if(n==1){r=bytes::view(ref b);break;}n+=1;continue;}if(n!=1 || r[0]!=42){return 0;}}bytes::write(ref mut a,0,8);bytes::write(ref mut b,0,9);return 42;}");
}
fn void retained_seed_outlives_inner_scope(){
    // The named edge is unretained; the anonymous seed edge retains its own
    // origin. Closing seed must not drop a candidate still needed by r.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var a=bytes::empty();_ = bytes::push(ref mut a,42);{var ref u8[] r=bytes::view(ref a);{let seed=id(ref bytes::view(ref bytes::empty()));var n=0;while(n<2){r=seed;n+=1;}}let child=id(ref r);if(child.len!=0 || r.len!=0){return 0;}}bytes::write(ref mut a,0,9);return 42;}");
    // Possible-only owners at the header stay exact through repetition, then
    // last-alias cleanup emits DROP_IF_LIVE115 for both anonymous candidates.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var a=bytes::empty();_ = bytes::push(ref mut a,42);{let seed=if(false){id(ref bytes::view(ref bytes::empty()))}else{id(ref bytes::view(ref bytes::empty()))};var ref u8[] r=bytes::view(ref a);for(var n=0;n<2;n+=1){r=seed;continue;}if(r.len!=0 || seed.len!=0){return 0;}}bytes::write(ref mut a,0,9);return 42;}");
}
@test fn void zero_trip_break_retained_and_conditional_seed_cleanup_execute(){
    zero_trip_and_distinct_break_exit();retained_seed_outlives_inner_scope();
}

fn void early_mutations_are_rechecked_after_widening(){
    rejected(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut b,7);var ref u8[] r=bytes::view(ref a);var n=0;while(n<2){bytes::write(ref mut b,0,9);r=bytes::view(ref b);n+=1;}return 42;}");
    rejected(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();var ref u8[] r=bytes::view(ref a);for(var n=0;n<2;n+=1){_ = bytes::push(ref mut b,9);r=bytes::view(ref b);}return 42;}");
    rejected(b"module main;fn void take(Buffer b){}fn i32 main(){var a=bytes::empty();var b=bytes::empty();var ref u8[] r=bytes::view(ref a);var n=0;while(n<2){take(b);b=bytes::empty();r=bytes::view(ref b);n+=1;}return 42;}");
    rejected(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut b,7);var ref u8[] r=bytes::view(ref a);var ref u8[] s=bytes::view(ref a);var n=0;while(n<3){bytes::write(ref mut b,0,9);r=s;s=bytes::view(ref b);n+=1;}return 42;}");
}
fn void exits_pin_every_inferred_candidate(){
    rejected(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut b,7);var ref u8[] r=bytes::view(ref a);var n=0;while(n<2){r=bytes::view(ref b);n+=1;}bytes::write(ref mut b,0,9);return 42;}");
    rejected(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);var ref u8[] r=bytes::view(ref a);while(false){r=bytes::view(ref b);}bytes::write(ref mut a,0,9);return 42;}");
}
@test fn void widened_backedges_and_exits_reject_earlier_writes_growth_and_owner_calls(){
    early_mutations_are_rechecked_after_widening();exits_pin_every_inferred_candidate();
}

fn void owner_shape_and_retained_seed_retirement_stay_exact(){
    // Last-alias retirement defers the actual pre-loop owner until safe cleanup.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();var ref u8[] r=id(ref bytes::view(ref bytes::empty()));var n=0;while(n<2){r=bytes::view(ref b);n+=1;}return 42;}");
    rejected(b"module main;fn i32 main(){let a=bytes::empty();var ref u8[] r=bytes::view(ref a);while(true){let local=bytes::empty();r=bytes::view(ref local);break;}return 42;}");
    rejected(b"module main;fn i32 main(){let a=bytes::empty();var ref u8[] r=bytes::view(ref a);while(true){let local=bytes::empty();r=bytes::view(ref local);continue;}return 42;}");
    // A break may retire a seed: zero-trip still owns it, the break does not.
    // The exit union preserves possible ownership until the view closes.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();{var ref u8[] r=id(ref bytes::view(ref bytes::empty()));while(true){r=bytes::view(ref b);break;}if(r.len!=0){return 0;}}return 42;}");
}
@test fn void exact_owner_headers_local_escape_and_last_seed_retirement_are_checked(){
    owner_shape_and_retained_seed_retirement_stay_exact();
}

@test fn void terminal_value_arms_preserve_widened_continue_and_break_origins(){
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);{var ref u8[] r=bytes::view(ref a);var n=0;while(n<2){_ = if(n==0){r=bytes::view(ref b);n+=1;continue;}else{break;};}if(r[0]!=42){return 0;}}bytes::write(ref mut a,0,8);bytes::write(ref mut b,0,9);return 42;}");
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);{var ref u8[] r=bytes::view(ref a);for(var n=0;n<2;n+=1){let dead=if(n==0){r=bytes::view(ref b);continue;}else{break;};}if(r[0]!=42){return 0;}}bytes::write(ref mut a,0,8);bytes::write(ref mut b,0,9);return 42;}");
}

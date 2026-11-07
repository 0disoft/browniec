module tests::m2::value_view_join_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;
import ir as ir;
import compiler as public_compiler;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(v):{v}case .err(_):{assert(false);compiled(input)}
};}
fn void executes(ref values::Program p){
    let ref ir::Program body=ref p.body;
    assert(body.count<=256 && body.registers<=128);
    assert(verifier::inspect_values(p).is_ok);
    assert(switch(vm::run_values(p,10000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void value(ref u8[] input){let values::Program p=compiled(input);executes(ref p);}
fn void rejected(ref u8[] input){assert(switch(source::compile(input)){
    case .ok(p):{!verifier::inspect_values(ref p).is_ok}
    case .err(e):{e.kind==3 && e.offset<=input.len}
});}
fn void failure(ref u8[] input,u8 expected){
    let values::Program p=compiled(input);assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){
        case .ok(_):{false}case .err(e):{e.kind==expected && e.offset<=input.len}
    });
    // Match the view-call source suite: fresh invocations must still admit views.
    // This is recovery coverage, not observation of a failed instance's registry.
    value(b"module main;fn usize count(ref u8[] v){return v.len;}fn i32 main(){let b=bytes::empty();if(count(ref bytes::view(ref b))==0){return 42;}return 0;}");
}

// Each independent guest fits the existing sixteen owning slots, 256 instructions
// and 128 registers. Small native groups avoid a single giant development frame.
// Windows may differ. Different already-live roots now join conservatively;
// branch-only anonymous owners and multi-formal returns remain rejected.
fn void true_and_false_if_join_choose_different_windows_of_one_root(){
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);{let v=bytes::view(ref b);let r=if(true){v[1..2]}else{v[0..1]};if(r.len!=1 || r[0]!=42 || v[0]!=7){return 0;}}bytes::write(ref mut b,0,9);return 42;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);{let v=bytes::view(ref b);let ref u8[] r=if(false){v[0..0]}else{v[1..]};if(r.len!=1 || r[0]!=42){return 0;}}bytes::write(ref mut b,0,9);return 42;}");
    // The unselected arm is valid source but would fail its bounds at runtime.
    value(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let r=if(true){v[..]}else{v[0..1]};if(r.len==0){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let r=if(false){v[0..1]}else{v[..]};if(r.len==0){return 42;}return 0;}");
}

fn void else_if_each_edge_and_nested_joins_select_same_origin_aliases(){
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let v=bytes::view(ref b);let alias=v;let r=if(true){alias}else if(false){v[0..0]}else{v[..]};if(r.len==1 && r[0]==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);let v=bytes::view(ref b);let r=if(false){v[0..0]}else if(true){v[1..]}else{v[..1]};if(r.len==1 && r[0]==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let v=bytes::view(ref b);let r=if(false){v[0..0]}else if(false){v[0..0]}else{if(false){v[0..0]}else{v[..]}};if(r.len==1 && r[0]==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);let v=bytes::view(ref b);let r=if(true){if(false){v[..1]}else{v[1..2]}}else{if(true){v[..]}else{v[0..0]}};if(r.len==1 && r[0]==42){return 42;}return 0;}");
}

fn void option_switch_both_variants_yield_views_of_the_same_root(){
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);{let v=bytes::view(ref b);let Option<usize> o=.some(1);let r=switch(o){case .some(n):{v[n..]}case .none:{v[..1]}};if(r.len!=1 || r[0]!=42){return 0;}}bytes::write(ref mut b,0,9);return 42;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);let v=bytes::view(ref b);let Option<usize> o=.none;let ref u8[] r=switch(o){case .some(n):{v[..n]}case .none:{let alias=v;alias[1..2]}};if(r.len==1 && r[0]==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let r=switch(.some(1)){case .some(_):{if(false){v[0..1]}else{v[..]}}case .none:{v[0..1]}};if(r.len==0){return 42;}return 0;}");
}

fn void result_switch_both_variants_and_nested_switch_joins_execute(){
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);let v=bytes::view(ref b);let Result<usize,u8> o=.ok(1);let r=switch(o){case .ok(n):{v[n..]}case .err(_):{v[..1]}};if(r.len==1 && r[0]==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);{let v=bytes::view(ref b);let Result<usize,u8> o=.err(7);let r=switch(o){case .ok(n):{v[..n]}case .err(e):{if(e!=7){return 0;}v[1..]}};if(r[0]!=42){return 0;}}bytes::write(ref mut b,0,9);return 42;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let v=bytes::view(ref b);let r=if(true){switch(.some(1)){case .some(_):{v[..]}case .none:{v[0..0]}}}else{v};if(r.len==1 && r[0]==42){return 42;}return 0;}");
}

fn void terminal_return_arms_do_not_contribute_a_join_origin(){
    value(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let r=if(true){let scratch=bytes::empty();return 42;}else{v};_ = r;return 0;}");
    value(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let r=if(false){return 0;}else{v};if(r.len==0){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let Option<i32> o=.none;let r=switch(o){case .some(_):{return 0;}case .none:{v}};if(r.len==0){return 42;}return 0;}");
}

fn void fully_terminal_value_joins_remain_rejected_without_bottom_expression_support(){
    // Existing limitation: no arm yields a descriptor. Bottom expressions are
    // outside this increment; one terminal plus one yielding arm is covered above.
    rejected(b"module main;fn ref u8[] pick(ref u8[] v,bool c){return if(c){return v;}else{return v[..];};}fn i32 main(){let b=bytes::empty();let r=pick(ref bytes::view(ref b),true);if(r.len==0){return 42;}return 0;}");
}

fn void break_in_a_view_join_cleans_inner_aliases_and_preserves_outer_roots(){
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);while(true){let v=bytes::view(ref b);let r=if(true){let alias=v;break;}else{v};_ = r;}bytes::write(ref mut b,0,42);if(bytes::read(ref b,0)==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);while(true){let v=bytes::view(ref b);let r=if(false){break;}else{v};if(r[0]!=42){return 0;}break;}bytes::write(ref mut b,0,7);return 42;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);for(;;){let v=bytes::view(ref b);let r=switch(.some(1)){case .some(_):{let alias=v;break;}case .none:{v}};_ = r;}bytes::write(ref mut b,0,42);return 42;}");
}

fn void continue_in_a_view_join_releases_views_before_the_next_root_write(){
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);var n=0;while(n<2){bytes::write(ref mut b,0,42);let v=bytes::view(ref b);let r=if(n==0){let alias=v;n+=1;continue;}else{v};if(r[0]!=42){return 0;}n+=1;}bytes::write(ref mut b,0,7);return 42;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);for(var n=0;n<2;n+=1){bytes::write(ref mut b,0,42);let v=bytes::view(ref b);let r=switch(.some(n)){case .some(_):{let alias=v;continue;}case .none:{v}};_ = r;}bytes::write(ref mut b,0,7);return 42;}");
}

fn void named_join_aliases_keep_the_root_pinned_until_the_last_scope_closes(){
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);{let v=bytes::view(ref b);let r=if(false){v[0..0]}else{v};{let child=r;_ = r;if(child[0]!=42){return 0;}}if(r[0]!=42 || v[0]!=42){return 0;}}bytes::write(ref mut b,0,7);let moved=b;if(bytes::read(ref moved,0)==7){return 42;}return 0;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let r=if(true){bytes::view(ref b)}else{bytes::view(ref b)};_ = r;_ = bytes::reserve(ref mut b,0);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let v=bytes::view(ref b);let r=if(true){v}else{v[..]};{let child=r;_ = child;}_ = r;let moved=b;return 42;}");
}

fn void mutable_shared_binding_returns_infer_the_same_formal_after_rebinding(){
    value(b"module main;fn ref u8[] tail(ref u8[] v){var ref u8[] r=v;r=v[1..];return r;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);{let r=tail(ref bytes::view(ref b));if(r.len!=1 || r[0]!=42){return 0;}}bytes::write(ref mut b,0,9);return 42;}");
    value(b"module main;fn ref u8[] pick(ref u8[] v,bool c){var ref u8[] r=v;if(c){r=v[1..];}else{r=v[..1];}return r;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);let r=pick(ref bytes::view(ref b),true);if(r.len==1 && r[0]==42){return 42;}return 0;}");
    value(b"module main;fn ref u8[] pick(ref u8[] v,bool c){var r=v;r=if(c){v[0..0]}else{v[1..]};return r;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);let r=pick(ref bytes::view(ref b),false);if(r.len==1 && r[0]==42){return 42;}return 0;}");
}

fn void same_root_rebinding_combines_direct_aliases_calls_and_returned_views(){
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn ref u8[] pick(ref u8[] v,bool c){var ref u8[] r=id(ref v);r=if(c){v[1..]}else{id(ref v[1..])};return r;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);let r=pick(ref bytes::view(ref b),false);if(r.len==1 && r[0]==42){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);{var ref u8[] r=id(ref bytes::view(ref b));let old=r;r=if(true){bytes::view(ref b)[1..]}else{id(ref old[1..])};if(r[0]!=42 || old.len!=2 || old[0]!=7){return 0;}}bytes::write(ref mut b,0,9);return 42;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);{var ref u8[] r=bytes::view(ref b);r=if(false){r[..1]}else{id(ref r[1..])};if(r.len!=1 || r[0]!=42){return 0;}}bytes::write(ref mut b,0,9);return 42;}");
}

fn void yielded_inner_aliases_of_outer_roots_survive_arm_scope_cleanup(){
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);{let r=if(true){let inner=bytes::view(ref b);let alias=inner;alias[1..]}else{let inner=bytes::view(ref b);inner[..1]};if(r.len!=1 || r[0]!=42){return 0;}}bytes::write(ref mut b,0,9);return 42;}");
    value(b"module main;fn ref u8[] pick(ref u8[] v){return switch(.some(1)){case .some(_):{let inner=v;let child=inner[1..];child}case .none:{let other=v;other[..1]}};}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);let r=pick(ref bytes::view(ref b));if(r.len==1 && r[0]==42){return 42;}return 0;}");
    value(b"module main;fn ref u8[] pick(ref u8[] v){var r=v;{let inner=v;r=if(false){inner[0..0]}else{let alias=inner;alias};}return r;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let r=pick(ref bytes::view(ref b));if(r[0]==42){return 42;}return 0;}");
}

fn void local_owner_escape_rejects_but_distinct_live_named_roots_join(){
    rejected(b"module main;fn i32 main(){let b=bytes::empty();let r=if(true){let local=bytes::empty();bytes::view(ref local)}else{bytes::view(ref b)};return 42;}");
    rejected(b"module main;fn ref u8[] wrong(ref u8[] v){return if(true){let local=bytes::empty();bytes::view(ref local)}else{v};}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] wrong(ref u8[] v){var r=v;{let local=bytes::empty();r=bytes::view(ref local);}return r;}fn i32 main(){return 42;}");
    value(b"module main;fn i32 main(){let a=bytes::empty();let b=bytes::empty();let r=if(false){bytes::view(ref a)}else{bytes::view(ref b)};if(r.len==0){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let a=bytes::empty();let b=bytes::empty();let r=switch(.some(1)){case .some(_):{bytes::view(ref a)}case .none:{bytes::view(ref b)}};if(r.len==0){return 42;}return 0;}");
}

fn void different_formal_joins_and_rebound_return_origins_remain_rejections(){
    rejected(b"module main;fn ref u8[] wrong(ref u8[] a,ref u8[] b,bool c){return if(c){a}else{b};}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] wrong(ref u8[] a,ref u8[] b){return switch(.some(1)){case .some(_):{a}case .none:{b}};}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] wrong(ref u8[] a,ref u8[] b,bool c){var r=a;if(c){r=a[..];}else{r=b[..];}return r;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn ref u8[] wrong(ref u8[] a,ref u8[] b,bool c){var r=a;r=if(c){id(ref a)}else{id(ref b)};return r;}fn i32 main(){return 42;}");
}

fn void joins_retain_one_anonymous_call_root_without_unifying_distinct_temporary_slots(){
    // Both edges select a single already-retained anonymous Buffer origin.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){{let seed=id(ref bytes::view(ref bytes::empty()));let r=if(true){seed}else{id(ref seed)};if(r.len!=0 || seed.len!=0){return 0;}}return 42;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){{let seed=id(ref bytes::view(ref bytes::empty()));let Option<i32> o=.none;let r=switch(o){case .some(_):{id(ref seed)}case .none:{let alias=seed;alias[..]}};if(r.len!=0){return 0;}}return 42;}");
    // Branch-only owners have no merged owning state, even when both are empty.
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let r=if(true){id(ref bytes::view(ref bytes::empty()))}else{id(ref bytes::view(ref bytes::empty()))};return 42;}");
}

fn void selected_join_bounds_fail_and_cleanup_preserves_the_first_error(){
    failure(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let r=if(true){v[0..1]}else{v};return 42;}",14);
    failure(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let r=if(false){v}else{v[1..]};return 42;}",14);
    failure(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let r=switch(.some(1)){case .some(_):{v}case .none:{v[..]}};_ = r[0];return 42;}",14);
}

fn void endpoint_arithmetic_precedes_join_bounds_and_cleanup_errors(){
    failure(b"module main;fn usize bad(){var usize n=18446744073709551615;n+=1;return n;}fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let r=if(true){v[2..bad()]}else{v};return 42;}",6);
    failure(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn usize bad(){var usize n=18446744073709551615;n+=1;return n;}fn i32 main(){let b=bytes::empty();let v=id(ref bytes::view(ref b));let r=switch(.some(1)){case .some(_):{v[2..bad()]}case .none:{v}};return 42;}",6);
}

fn void shared_join_source_and_body_stay_rejected_by_ordinary_public_routes(){
    let values::Program p=compiled(b"module main;fn ref u8[] pick(ref u8[] v,bool c){return if(c){v}else{v[..]};}fn i32 main(){let b=bytes::empty();let r=pick(ref bytes::view(ref b),false);if(r.len==0){return 42;}return 0;}");
    executes(ref p);
    assert(!verifier::inspect(ref p.body).is_ok && !verifier::verify(ref p.body).is_ok);
    assert(!vm::run(ref p.body,10000000).is_ok);
    assert(!public_compiler::compile(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let r=if(true){v}else{v[..]};return 42;}").is_ok);
}

// Reuse small helper scopes while compiling six native test images instead of
// eighteen. Every guest still compiles/verifies/runs with fresh invocation state.
@test fn void conditional_windows_nested_aliases_and_last_scope_cleanup(){
    true_and_false_if_join_choose_different_windows_of_one_root();
    else_if_each_edge_and_nested_joins_select_same_origin_aliases();
    named_join_aliases_keep_the_root_pinned_until_the_last_scope_closes();
}
@test fn void switch_variants_nested_values_and_inner_alias_lifetimes(){
    option_switch_both_variants_yield_views_of_the_same_root();
    result_switch_both_variants_and_nested_switch_joins_execute();
    yielded_inner_aliases_of_outer_roots_survive_arm_scope_cleanup();
}
@test fn void terminal_arms_and_loop_transfers_clean_views_before_roots(){
    terminal_return_arms_do_not_contribute_a_join_origin();
    break_in_a_view_join_cleans_inner_aliases_and_preserves_outer_roots();
    continue_in_a_view_join_releases_views_before_the_next_root_write();
}
@test fn void mutable_return_origins_calls_and_anonymous_owner_retention(){
    mutable_shared_binding_returns_infer_the_same_formal_after_rebinding();
    same_root_rebinding_combines_direct_aliases_calls_and_returned_views();
    joins_retain_one_anonymous_call_root_without_unifying_distinct_temporary_slots();
}
@test fn void bottom_local_escape_reject_and_live_named_origin_joins_execute(){
    fully_terminal_value_joins_remain_rejected_without_bottom_expression_support();
    local_owner_escape_rejects_but_distinct_live_named_roots_join();
    different_formal_joins_and_rebound_return_origins_remain_rejections();
}
@test fn void bounds_arithmetic_first_errors_and_public_admission_gates(){
    selected_join_bounds_fail_and_cleanup_preserves_the_first_error();
    endpoint_arithmetic_precedes_join_bounds_and_cleanup_errors();
    shared_join_source_and_body_stay_rejected_by_ordinary_public_routes();
}

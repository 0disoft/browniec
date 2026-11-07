module tests::m2::value_view_origin_sets_source;
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
    let values::Program p=compiled(input);
    assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){
        case .ok(v):{v==42}case .err(_):{false}
    });
}
fn void rejected(ref u8[] input){assert(switch(source::compile(input)){
    case .ok(p):{!verifier::inspect_values(ref p).is_ok}
    case .err(e):{e.kind==3 && e.offset<=input.len}
});}
fn void failure(ref u8[] input){
    let values::Program p=compiled(input);
    assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){
        case .ok(_):{false}case .err(e):{e.kind==14 && e.offset<=input.len}
    });
}

// Origin sets are compile-time low-24-bit metadata. Each runtime descriptor must
// still select one concrete native view; different payloads expose wrong choice.
// Five native wrappers delegate to small helpers: never aggregate Program locals.
fn void named_if_edges_choose_concrete_payloads_and_leave_both_owners_live(){
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,42);_ = bytes::push(ref mut b,7);{let r=if(true){bytes::view(ref a)}else{bytes::view(ref b)};if(r.len!=1 || r[0]!=42){return 0;}}bytes::write(ref mut a,0,9);bytes::write(ref mut b,0,8);if(bytes::read(ref a,0)==9 && bytes::read(ref b,0)==8){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);{let av=bytes::view(ref a);let bv=bytes::view(ref b);let r=if(false){av}else{bv};if(r[0]!=42 || av[0]!=7 || bv[0]!=42){return 0;}}let moved_a=a;let moved_b=b;if(bytes::read(ref moved_a,0)==7 && bytes::read(ref moved_b,0)==42){return 42;}return 0;}");
}
fn void option_switch_edges_select_distinct_roots_and_ranges(){
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut a,42);_ = bytes::push(ref mut b,9);let Option<usize> o=.some(1);let r=switch(o){case .some(n):{bytes::view(ref a)[n..]}case .none:{bytes::view(ref b)[..1]}};if(r.len==1 && r[0]==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);let Option<usize> o=.none;let r=switch(o){case .some(n):{bytes::view(ref a)[..n]}case .none:{let inner=bytes::view(ref b);let alias=inner;alias[0..1]}};if(r.len==1 && r[0]==42){return 42;}return 0;}");
}
fn void result_switch_and_nested_three_root_join_execute(){
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);let Result<usize,u8> o=.err(9);let r=switch(o){case .ok(n):{bytes::view(ref a)[n..]}case .err(e):{if(e!=9){return 0;}bytes::view(ref b)[..]}};if(r.len==1 && r[0]==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();var c=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,9);_ = bytes::push(ref mut c,42);let r=if(false){bytes::view(ref a)}else{if(false){bytes::view(ref b)}else{bytes::view(ref c)}};let alias=r[..1];if(alias[0]==42 && r.len==1){return 42;}return 0;}");
}

fn void scalar_calls_may_select_formal_alternatives_without_returning_a_reference(){
    value(b"module main;fn u8 choose(ref u8[] a,ref u8[] b,bool c){let r=if(c){a}else{b};return r[0];}fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);if(choose(ref bytes::view(ref a),ref bytes::view(ref b),true)!=7){return 0;}if(choose(ref bytes::view(ref a),ref bytes::view(ref b),false)==42){return 42;}return 0;}");
    value(b"module main;fn usize choose(ref u8[] a,ref u8[] b,bool c){let Option<usize> o=if(c){.some(1)}else{.none};let r=switch(o){case .some(n):{a[n..]}case .none:{b[..]}};return r.len;}fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut a,9);if(choose(ref bytes::view(ref a),ref bytes::view(ref b),true)!=1){return 0;}if(choose(ref bytes::view(ref a),ref bytes::view(ref b),false)==0){return 42;}return 0;}");
}
fn void union_actuals_survive_scalar_and_exact_selected_shared_return_calls(){
    value(b"module main;fn usize count(ref u8[] a,ref u8[] b){return a.len+b.len;}fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);{let r=if(false){bytes::view(ref a)}else{bytes::view(ref b)};let alias=r[..];if(count(ref r,ref alias)!=2 || alias[0]!=42){return 0;}}bytes::write(ref mut a,0,9);bytes::write(ref mut b,0,8);return 42;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,9);_ = bytes::push(ref mut b,42);{let r=if(false){bytes::view(ref a)}else{bytes::view(ref b)};let child=id(ref r[1..]);if(child.len!=1 || child[0]!=42 || r[0]!=9){return 0;}}bytes::write(ref mut a,0,8);bytes::write(ref mut b,0,8);return 42;}");
    value(b"module main;fn ref u8[] second(ref u8[] a,ref u8[] b){return b;}fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);{let r=if(true){bytes::view(ref a)}else{bytes::view(ref b)};let s=if(false){bytes::view(ref a)}else{bytes::view(ref b)};let selected=second(ref r,ref s);if(selected[0]!=42 || r[0]!=7){return 0;}}bytes::write(ref mut a,0,9);bytes::write(ref mut b,0,8);return 42;}");
}
fn void already_live_retained_anonymous_roots_can_union_without_owner_state_merge(){
    // Both anonymous owners exist before either join. Their descriptors remain
    // live until this scope closes; no arm creates an owning alternative.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn usize count(ref u8[] v){return v.len;}fn i32 main(){{let a=id(ref bytes::view(ref bytes::empty()));let b=id(ref bytes::view(ref bytes::empty()));var ref u8[] r=if(true){a}else{b};let child=id(ref r);r=if(false){a}else{b};if(count(ref child)!=0 || r.len!=0 || a.len!=0 || b.len!=0){return 0;}}return 42;}");
}
fn void named_and_retained_anonymous_roots_preserve_independent_retention_bits(){
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var a=bytes::empty();_ = bytes::push(ref mut a,42);{let seed=id(ref bytes::view(ref bytes::empty()));let r=if(true){bytes::view(ref a)}else{seed};let child=id(ref r);if(child.len!=1 || child[0]!=42 || seed.len!=0){return 0;}}bytes::write(ref mut a,0,7);return 42;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var a=bytes::empty();_ = bytes::push(ref mut a,42);{let seed=id(ref bytes::view(ref bytes::empty()));let r=if(false){bytes::view(ref a)}else{seed};let child=id(ref r);if(child.len!=0 || r.len!=0 || bytes::read(ref a,0)!=42){return 0;}}bytes::write(ref mut a,0,7);return 42;}");
}
fn void mixed_union_alias_outlives_the_inner_seed_scope_on_either_edge(){
    // The named-root edge supplies no CALL retention. It must not revoke the
    // anonymous root's independent retention when the inner seed is closed.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var a=bytes::empty();_ = bytes::push(ref mut a,42);{var ref u8[] r=bytes::view(ref a);{let seed=id(ref bytes::view(ref bytes::empty()));r=if(true){bytes::view(ref a)}else{seed};}let child=id(ref r);if(child.len!=1 || child[0]!=42 || r[0]!=42){return 0;}}bytes::write(ref mut a,0,7);return 42;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var a=bytes::empty();_ = bytes::push(ref mut a,42);{var ref u8[] r=bytes::view(ref a);{let seed=id(ref bytes::view(ref bytes::empty()));r=if(false){bytes::view(ref a)}else{seed};}let child=id(ref r);r=bytes::view(ref a);if(child.len!=0 || r[0]!=42){return 0;}}bytes::write(ref mut a,0,7);let moved=a;if(bytes::read(ref moved,0)==7){return 42;}return 0;}");
}
fn void copy_from_named_and_formal_origin_unions_returns_independent_bytes(){
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);let r=if(false){bytes::view(ref a)}else{bytes::view(ref b)};switch(bytes::copy(ref r[..1])){case .ok(owner):{var copy=owner;bytes::write(ref mut copy,0,9);if(bytes::len(ref copy)==1 && bytes::read(ref copy,0)==9 && r[0]==42 && bytes::read(ref a,0)==7 && bytes::read(ref b,0)==42){return 42;}return 0;}case .err(_):{return 0;}}}");
    // Separate guest programs keep both selected edges inside the fixed compile
    // budget; each independently checks payload selection and copy isolation.
    value(b"module main;fn Result<Buffer,u8> copied(ref u8[] a,ref u8[] b,bool c){let r=if(c){a[..]}else{b[..]};return bytes::copy(ref r);}fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);switch(copied(ref bytes::view(ref a),ref bytes::view(ref b),true)){case .ok(owner):{var copy=owner;if(bytes::read(ref copy,0)!=7){return 0;}bytes::write(ref mut copy,0,9);if(bytes::read(ref copy,0)==9 && bytes::read(ref a,0)==7 && bytes::read(ref b,0)==42){return 42;}return 0;}case .err(_):{return 0;}}}");
    value(b"module main;fn Result<Buffer,u8> copied(ref u8[] a,ref u8[] b,bool c){let r=if(c){a[..]}else{b[..]};return bytes::copy(ref r);}fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);switch(copied(ref bytes::view(ref a),ref bytes::view(ref b),false)){case .ok(owner):{var copy=owner;if(bytes::read(ref copy,0)!=42){return 0;}bytes::write(ref mut copy,0,9);if(bytes::read(ref copy,0)==9 && bytes::read(ref a,0)==7 && bytes::read(ref b,0)==42){return 42;}return 0;}case .err(_):{return 0;}}}");
}

fn void rebinding_releases_all_old_possibilities_after_the_last_alias(){
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);{var ref u8[] r=if(false){bytes::view(ref a)}else{bytes::view(ref b)};{let old=r;r=bytes::view(ref a);if(old[0]!=42 || r[0]!=7){return 0;}}bytes::write(ref mut b,0,9);if(bytes::read(ref b,0)!=9 || r[0]!=7){return 0;}}bytes::write(ref mut a,0,8);let moved_a=a;let moved_b=b;if(bytes::read(ref moved_a,0)==8 && bytes::read(ref moved_b,0)==9){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);{var ref u8[] r=bytes::view(ref a);r=if(false){r[..]}else{bytes::view(ref b)};let alias=r;{let child=alias[..];if(child[0]!=42){return 0;}}if(alias[0]!=42 || r[0]!=42){return 0;}}bytes::write(ref mut a,0,9);bytes::write(ref mut b,0,8);return 42;}");
    value(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,42);_ = bytes::push(ref mut b,7);{var ref u8[] r=if(false){bytes::view(ref a)}else{bytes::view(ref b)};r=if(true){bytes::view(ref a)[..1]}else{r[..]};if(r[0]!=42){return 0;}}_ = a;_ = b;return 42;}");
}
fn void selected_bounds_fail_but_unselected_invalid_windows_do_not_execute(){
    value(b"module main;fn i32 main(){var a=bytes::empty();let b=bytes::empty();_ = bytes::push(ref mut a,42);let r=if(true){bytes::view(ref a)[..1]}else{bytes::view(ref b)[0..1]};if(r[0]==42){return 42;}return 0;}");
    failure(b"module main;fn i32 main(){let a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut b,42);let r=if(true){bytes::view(ref a)[..1]}else{bytes::view(ref b)};return 42;}");
    failure(b"module main;fn i32 main(){var a=bytes::empty();let b=bytes::empty();_ = bytes::push(ref mut a,42);let Option<i32> o=.none;let r=switch(o){case .some(_):{bytes::view(ref a)}case .none:{bytes::view(ref b)[1..]}};return 42;}");
}

fn void every_possible_named_root_rejects_write_and_move_while_union_is_live(){
    // Constant selectors intentionally do not grant path-sensitive ownership.
    rejected(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,7);_ = bytes::push(ref mut b,42);let r=if(false){bytes::view(ref a)}else{bytes::view(ref b)};bytes::write(ref mut a,0,9);if(r[0]==42){return 42;}return 0;}");
    rejected(b"module main;fn i32 main(){var a=bytes::empty();var b=bytes::empty();_ = bytes::push(ref mut a,42);_ = bytes::push(ref mut b,7);let r=if(true){bytes::view(ref a)}else{bytes::view(ref b)};bytes::write(ref mut b,0,9);if(r[0]==42){return 42;}return 0;}");
    rejected(b"module main;fn i32 main(){let a=bytes::empty();let b=bytes::empty();let r=if(false){bytes::view(ref a)}else{bytes::view(ref b)};let moved=a;_ = r;return 42;}");
}
fn void aliases_and_shared_return_calls_preserve_all_possible_root_pins(){
    rejected(b"module main;fn void take(Buffer v){}fn i32 main(){let a=bytes::empty();let b=bytes::empty();let r=if(true){bytes::view(ref a)}else{bytes::view(ref b)};let alias=r;take(b);_ = alias;return 42;}");
    rejected(b"module main;fn i32 main(){let a=bytes::empty();let b=bytes::empty();let r=if(false){bytes::view(ref a)}else{bytes::view(ref b)};_ = a;_ = r;return 42;}");
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let a=bytes::empty();let b=bytes::empty();var ref u8[] r=if(true){bytes::view(ref a)}else{bytes::view(ref b)};let child=id(ref r);r=bytes::view(ref a);_ = b;_ = child;return 42;}");
}

fn void arm_local_named_roots_cannot_escape_but_anonymous_call_owners_can_join(){
    rejected(b"module main;fn i32 main(){let outer=bytes::empty();let r=if(true){let local=bytes::empty();bytes::view(ref local)}else{bytes::view(ref outer)};if(r.len==0){return 42;}return 0;}");
    rejected(b"module main;fn i32 main(){let outer=bytes::empty();let r=if(false){bytes::view(ref outer)}else{let local=bytes::empty();let alias=bytes::view(ref local);alias[..]};if(r.len==0){return 42;}return 0;}");
    rejected(b"module main;fn i32 main(){let outer=bytes::empty();let r=switch(.some(1)){case .some(_):{bytes::view(ref outer)}case .none:{let local=bytes::empty();let alias=bytes::view(ref local);alias[..]}};if(r.len==0){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let r=if(true){id(ref bytes::view(ref bytes::empty()))}else{id(ref bytes::view(ref bytes::empty()))};if(r.len==0){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let r=switch(.some(1)){case .some(_):{id(ref bytes::view(ref bytes::empty()))}case .none:{id(ref bytes::view(ref bytes::empty()))}};if(r.len==0){return 42;}return 0;}");
}
fn void shared_returns_still_require_one_exact_selected_formal(){
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn ref u8[] wrong(ref u8[] a,ref u8[] b,bool c){let r=if(c){a[..]}else{b[..]};return id(ref r);}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] wrong(ref u8[] a,ref u8[] b,bool c){var ref u8[] r=a;r=switch(.some(c)){case .some(n):{if(n){a}else{b}}case .none:{a}};return r;}fn i32 main(){return 42;}");
}

@test fn void named_live_root_if_switch_ranges_and_nested_aliases_execute(){
    named_if_edges_choose_concrete_payloads_and_leave_both_owners_live();
    option_switch_edges_select_distinct_roots_and_ranges();
    result_switch_and_nested_three_root_join_execute();
}
@test fn void formal_alternatives_union_actual_calls_and_retained_roots_execute(){
    scalar_calls_may_select_formal_alternatives_without_returning_a_reference();
    union_actuals_survive_scalar_and_exact_selected_shared_return_calls();
    already_live_retained_anonymous_roots_can_union_without_owner_state_merge();
    copy_from_named_and_formal_origin_unions_returns_independent_bytes();
}
@test fn void rebind_last_close_and_selected_window_errors_preserve_concrete_views(){
    rebinding_releases_all_old_possibilities_after_the_last_alias();
    selected_bounds_fail_but_unselected_invalid_windows_do_not_execute();
    named_and_retained_anonymous_roots_preserve_independent_retention_bits();
    mixed_union_alias_outlives_the_inner_seed_scope_on_either_edge();
}
@test fn void all_possible_roots_remain_pinned_against_writes_moves_and_drops(){
    every_possible_named_root_rejects_write_and_move_while_union_is_live();
    aliases_and_shared_return_calls_preserve_all_possible_root_pins();
}
@test fn void local_named_escape_and_multi_formal_returns_reject_while_anonymous_roots_join(){
    arm_local_named_roots_cannot_escape_but_anonymous_call_owners_can_join();
    shared_returns_still_require_one_exact_selected_formal();
}

module tests::m2::value_view_conditional_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import compiler as ordinary;
import buffer_growth as growth;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(v):{v}case .err(_):{assert(false);compiled(input)}
};}
fn void conditional_cleanup(ref values::Program p){
    var usize found=0;var usize pc=0;while(pc<p.body.count){if(p.body.code[pc*8]==115){found+=1;}pc+=1;}
    assert(found!=0);
}
fn void value(ref u8[] input){
    let values::Program p=compiled(input);conditional_cleanup(ref p);
    assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){
        case .ok(v):{v==42}case .err(_):{false}
    });
}
fn void rejected(ref u8[] input){assert(switch(source::compile(input)){
    case .ok(p):{!verifier::inspect_values(ref p).is_ok}
    case .err(e):{e.kind==3 && e.offset<=input.len}
});}
fn void bounds(ref u8[] input){
    let values::Program p=compiled(input);conditional_cleanup(ref p);
    assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){
        case .ok(_):{false}case .err(e):{e.kind==14 && e.offset<=input.len}
    });
}

// Each invocation is fresh. Keep Program locals inside helpers, not wrappers.
@test fn void if_switch_and_nested_joins_keep_only_the_executed_branch_owner(){
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let r=if(true){id(ref bytes::view(ref make(42)))}else{id(ref bytes::view(ref make(7)))};if(r[0]==42){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let r=if(false){id(ref bytes::view(ref make(7)))}else{id(ref bytes::view(ref make(42)))};if(r[0]==42){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let Option<i32> o=.some(1);let r=switch(o){case .some(n):{id(ref bytes::view(ref make(42)))}case .none:{id(ref bytes::view(ref make(7)))}};if(r.len==1 && r[0]==42){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let Result<i32,u8> o=.err(7);let r=switch(o){case .ok(n):{id(ref bytes::view(ref make(7)))}case .err(e):{id(ref bytes::view(ref make(42)))}};if(r[0]==42){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let r=if(false){id(ref bytes::view(ref make(7)))}else{if(false){id(ref bytes::view(ref make(9)))}else{id(ref bytes::view(ref make(42)))}};let child=r[..1];if(child[0]==42){return 42;}return 0;}");
}

@test fn void named_and_conditionally_created_roots_share_a_view_without_moving_the_name(){
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){var b=make(42);{let r=if(true){bytes::view(ref b)}else{id(ref bytes::view(ref make(7)))};let child=id(ref r);if(child[0]!=42){return 0;}}bytes::write(ref mut b,0,9);if(bytes::read(ref b,0)==9){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){var b=make(7);{let r=if(false){bytes::view(ref b)}else{id(ref bytes::view(ref make(42)))};let child=id(ref r);if(child[0]!=42){return 0;}}bytes::write(ref mut b,0,9);if(bytes::read(ref b,0)==9){return 42;}return 0;}");
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){var b=make(7);let r=if(false){bytes::view(ref b)}else{id(ref bytes::view(ref make(42)))};bytes::write(ref mut b,0,9);return 42;}");
}

@test fn void rebind_outer_scope_and_last_alias_close_release_conditional_roots(){
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){var b=make(7);{var ref u8[] r=bytes::view(ref b);{r=if(false){id(ref bytes::view(ref make(7)))}else{id(ref bytes::view(ref make(42)))};}let child=id(ref r[..]);if(child[0]!=42 || r[0]!=42){return 0;}}bytes::write(ref mut b,0,9);return 42;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){{var ref u8[] r=if(false){id(ref bytes::view(ref make(7)))}else{id(ref bytes::view(ref make(42)))};{let old=r;r=id(ref bytes::view(ref make(9)));if(old[0]!=42 || r[0]!=9){return 0;}}if(r[0]!=9){return 0;}}return 42;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let r=id(ref if(true){id(ref bytes::view(ref make(42)))}else{id(ref bytes::view(ref make(7)))});let alias=r[..];if(alias[0]==42 && r[0]==42){return 42;}return 0;}");
}

@test fn void immediate_unretained_views_and_copy_use_the_actual_present_root(){
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn usize count(ref u8[] v){return v.len;}fn i32 main(){if(count(ref if(true){bytes::view(ref make(42))}else{bytes::view(ref make(7))})==1){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn usize count(ref u8[] v){return v.len;}fn i32 main(){if(count(ref if(false){bytes::view(ref make(7))}else{bytes::view(ref make(42))})==1){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let r=if(false){id(ref bytes::view(ref make(7)))}else{id(ref bytes::view(ref make(42)))};switch(bytes::copy(ref r)){case .ok(owner):{var copy=owner;bytes::write(ref mut copy,0,9);if(bytes::read(ref copy,0)==9 && r[0]==42){return 42;}return 0;}case .err(_):{return 0;}}}");
}

@test fn void loop_iterations_and_transfers_close_views_before_optional_owners(){
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){var i32 i=0;while(i<3){{let r=if(i==1){id(ref bytes::view(ref make(42)))}else{id(ref bytes::view(ref make(7)))};if(i==1){if(r[0]!=42){return 0;}}else{if(r[0]!=7){return 0;}}}i+=1;}return 42;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){var i32 i=0;while(i<3){let r=if(i==0){id(ref bytes::view(ref make(7)))}else{id(ref bytes::view(ref make(42)))};i+=1;if(i<3){continue;}if(r[0]!=42){return 0;}break;}return 42;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let r=if(false){id(ref bytes::view(ref make(7)))}else{id(ref bytes::view(ref make(42)))};var i32 i=0;while(i<3){let child=id(ref r);if(child[0]!=42){return 0;}i+=1;}return 42;}");
}

@test fn void unselected_effects_do_not_run_and_selected_window_failures_clean_up(){
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn Buffer fail(){var b=bytes::empty();_ = bytes::read(ref b,0);return b;}fn i32 main(){let r=if(true){id(ref bytes::view(ref make(42)))}else{id(ref bytes::view(ref fail()))};if(r[0]==42){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let r=if(true){id(ref bytes::view(ref make(42)))}else{id(ref bytes::view(ref make(7)))[..2]};if(r[0]==42){return 42;}return 0;}");
    bounds(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let r=if(true){id(ref bytes::view(ref make(42)))[..2]}else{id(ref bytes::view(ref make(7)))};return 42;}");
}

@test fn void unretained_lexical_escape_named_arm_escape_and_multi_formal_returns_reject(){
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let r=if(true){bytes::view(ref make(42))}else{bytes::view(ref make(7))};return 42;}");
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let outer=make(7);let r=if(true){let local=make(42);id(ref bytes::view(ref local))}else{bytes::view(ref outer)};return 42;}");
    rejected(b"module main;fn ref u8[] choose(ref u8[] a,ref u8[] b,bool c){return if(c){a}else{b};}fn i32 main(){return 42;}");
}

@test fn void conditional_owner_source_keeps_ordinary_public_admission_closed(){
    let ref u8[] input=b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let r=if(true){id(ref bytes::view(ref bytes::empty()))}else{id(ref bytes::view(ref bytes::empty()))};if(r.len==0){return 42;}return 0;}";
    value(input);assert(!ordinary::compile(input).is_ok);
}

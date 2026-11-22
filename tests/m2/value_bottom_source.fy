module tests::m2::value_bottom_source;
import value_source as source;
import value_source_context as context;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;
import ir as ir;
import compiler as public_compiler;

fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(p):{p}case .err(_):{assert(false);compiled(input)}
};}
fn void value(ref u8[] input){
    let values::Program p=compiled(input);
    assert(verifier::inspect_values(ref p).is_ok);
    let growth::Limits limits=growth::Limits{.object=4096,.instance=1048576,.engine=1048576};
    assert(switch(vm::run_values(ref p,10000000,0,limits)){case .ok(v):{v==42}case .err(_):{false}});
}
fn void rejected(ref u8[] input){assert(switch(source::compile(input)){
    case .ok(_):{false}case .err(e):{e.offset<=input.len}
});}
fn usize count(ref values::Program p,u8 op){let ref ir::Program body=ref p.body;
    var usize i=0;var usize n=0;while(i<body.count){if(body.code[i*8]==op){n+=1;}i+=1;}return n;
}

@test fn void bottom_is_distinct_from_void_and_accepts_any_expected_domain(){
    let context::Value b=context::bottom();let context::Value v=context::nothing();
    assert(b.bottom && !b.nothing && !b.typed && b.binding==64 && b.value==256);
    assert(v.nothing && !v.bottom);
    assert(context::expected(b,0,0).is_ok && context::expected(b,65,0).is_ok);
    assert(!context::expected(v,0,0).is_ok && !context::expected(v,65,0).is_ok);
}
@test fn void both_return_if_and_switch_need_no_destination_or_outer_return(){
    let values::Program p=compiled(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;};}");
    assert(verifier::inspect_values(ref p).is_ok);
    assert(count(ref p,8)==2 && count(ref p,18)==0 && count(ref p,17)==0);
    value(b"module main;fn i32 main(){return if(false){return 0;}else{return 42;};}");
    value(b"module main;fn i32 main(){return switch(.some(1)){case .some(n):{return n+41;}case .none:{return 0;}};}");
    value(b"module main;fn i32 main(){let Option<i32> o=.none;return switch(o){case .some(_):{return 0;}case .none:{return 42;}};}");
}
@test fn void nested_bottom_tails_and_else_if_suffixes_compose(){
    value(b"module main;fn i32 main(){return if(true){if(false){return 0;}else{return 42;}}else{0};}");
    value(b"module main;fn i32 main(){return if(false){0}else if(false){return 0;}else{return 42;};}");
    value(b"module main;fn i32 main(){return if(false){if(true){return 0;}else{return 0;}}else{42};}");
    value(b"module main;fn i32 main(){return switch(.some(1)){case .some(_):{if(true){return 42;}else{return 0;}}case .none:{0}};}");
    value(b"module main;fn i32 main(){return if(true){switch(.some(1)){case .some(_):{return 42;}case .none:{return 0;}}}else{0};}");
}
@test fn void declarations_discard_and_assignments_do_not_capture_dead_results(){
    value(b"module main;fn i32 main(){let i32 dead=if(true){return 42;}else{return 0;};}");
    value(b"module main;fn i32 main(){let dead=switch(.some(1)){case .some(_):{return 42;}case .none:{return 0;}};}");
    value(b"module main;fn i32 main(){_ = if(false){return 0;}else{return 42;};}");
    value(b"module main;fn i32 main(){var n=0;n=if(true){return 42;}else{return 0;};}");
    value(b"module main;fn i32 main(){var b=bytes::empty();b=if(true){return 42;}else{return 0;};}");
    value(b"module main;fn i32 main(){let b=bytes::empty();var v=bytes::view(ref b);v=if(true){return 42;}else{return 0;};}");
}
@test fn void owned_and_view_return_contexts_preserve_real_terminal_cleanup(){
    value(b"module main;fn Buffer make(bool c){let scratch=bytes::empty();return if(c){return bytes::empty();}else{return bytes::empty();};}fn i32 main(){let b=make(true);if(bytes::len(ref b)==0){return 42;}return 0;}");
    value(b"module main;fn Option<Buffer> make(){return .some(if(true){return .none;}else{return .some(bytes::empty());});}fn i32 main(){switch(make()){case .some(_):{return 0;}case .none:{return 42;}}}");
    // Regression: fully terminal shared returns used to require a join value.
    value(b"module main;fn ref u8[] pick(ref u8[] v,bool c){return if(c){return v;}else{return v[..];};}fn i32 main(){let b=bytes::empty();let r=pick(ref bytes::view(ref b),true);if(r.len==0){return 42;}return 0;}");
    value(b"module main;fn ref u8[] pick(ref u8[] v,bool c){return if(c){return v;}else{return v[..];};}fn i32 main(){let b=bytes::empty();let r=pick(ref bytes::view(ref b),false);if(r.len==0){return 42;}return 0;}");
    value(b"module main;fn ref u8[] pick(ref u8[] v){return switch(.some(1)){case .some(_):{return v;}case .none:{return v[..];}};}fn i32 main(){let b=bytes::empty();let r=pick(ref bytes::view(ref b));if(r.len==0){return 42;}return 0;}");
}
@test fn void operand_and_last_call_argument_bottom_skip_enclosing_work(){
    value(b"module main;fn i32 main(){return 1+(if(true){return 42;}else{return 0;});}");
    value(b"module main;fn i32 main(){return -(if(false){return 0;}else{return 42;});}");
    value(b"module main;fn i32 never(Buffer b,i32 n){return 0;}fn i32 main(){return never(bytes::empty(),if(true){return 42;}else{return 0;});}");
    value(b"module main;fn i32 never(ref u8[] v,i32 n){return 0;}fn i32 main(){return never(ref bytes::view(ref bytes::empty()),if(true){return 42;}else{return 0;});}");
}
fn void terminal_property(ref u8[] input,bool raw,usize expected_drops){
    let values::Program p=switch(if(raw){source::compile_raw(input)}else{source::compile(input)}){
        case .ok(v):{v}case .err(_):{assert(false);compiled(input)}
    };
    assert(count(ref p,98)==0 && count(ref p,110)==0 && count(ref p,8)==2);
    assert(count(ref p,90)==expected_drops);
    assert(verifier::inspect_values(ref p).is_ok);
    let growth::Limits limits=growth::Limits{.object=4096,.instance=1048576,.engine=1048576};
    assert(switch(vm::run_values(ref p,10000000,0,limits)){case .ok(v):{v==42}case .err(_):{false}});
}

@test fn void final_properties_of_terminal_receivers_validate_without_reading_values(){
    var usize i=0;
    while(i<2){
        terminal_property(b"module main;fn i32 main(){let b=bytes::empty();let dead=(if(true){return 42;}else{return 0;}).len;}",i==0,2);
        terminal_property(b"module main;fn i32 main(){let dead=(if(false){return 0;}else{return 42;}).is_ok;}",i==0,0);
        terminal_property(b"module main;fn i32 main(){let dead=(if(true){return 42;}else{return 0;}).is_err;}",i==0,0);
        terminal_property(b"module main;fn i32 main(){let dead=(if(true){return 42;}else{return 0;}).is_some;}",i==0,0);
        terminal_property(b"module main;fn i32 main(){let dead=(if(false){return 0;}else{return 42;}).is_none;}",i==0,0);
        i+=1;
    }
    rejected(b"module main;fn i32 main(){let dead=(if(true){return 42;}else{return 0;}).oops;}");
    rejected(b"module main;fn i32 main(){let dead=(if(true){return 42;}else{return 0;}).;}");
    rejected(b"module main;fn i32 main(){let dead=(if(true){return 42;}else{return 0;}).is_ok();}");
    rejected(b"module main;fn i32 main(){let dead=(if(true){return 42;}else{return 0;}).len.is_some;}");
    rejected(b"module main;fn i32 main(){let dead=(if(true){return 42;}else{return 0;})[0];}");
    rejected(b"module main;fn i32 main(){let dead=(if(true){return 42;}else{return 0;})?;}");
    rejected(b"module main;fn void run(){}fn i32 main(){let dead=run().len;return 42;}");
}

@test fn void short_circuit_bottom_keeps_skip_edge_and_never_replays_effects(){
    value(b"module main;fn i32 main(){var n=0;let c=false && if(true){n+=1;return 0;}else{return 0;};if(!c && n==0){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var n=0;let c=true || if(true){n+=1;return 0;}else{return 0;};if(c && n==0){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let c=true && if(true){return 42;}else{return 0;};return 0;}");
    value(b"module main;fn i32 main(){let c=false || if(false){return 0;}else{return 42;};return 0;}");
}
@test fn void all_terminal_loop_value_arms_retain_break_continue_and_outer_mutations(){
    value(b"module main;fn i32 main(){var n=0;while(n<2){let dead=if(n==0){n+=1;continue;}else{n+=41;break;};}return n;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);var n=0;while(n<2){let v=bytes::view(ref b);let dead=if(n==0){n+=1;continue;}else{break;};}bytes::write(ref mut b,0,42);if(bytes::read(ref b,0)==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var n=0;for(var i=0;i<2;i+=1){let dead=switch(.some(i)){case .some(k):{n+=21;continue;}case .none:{break;}};}return n;}");
}
@test fn void void_and_malformed_or_unreachable_trailing_source_stay_errors(){
    rejected(b"module main;fn void noop(){}fn i32 main(){let i32 n=noop();return 42;}");
    rejected(b"module main;fn void noop(){}fn i32 main(){return if(true){noop();}else{noop();};}");
    rejected(b"module main;fn i32 main(){return if(true){return 42;}else{return false;};}");
    rejected(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;} + ;}");
    rejected(b"module main;fn i32 main(){let n=if(true){return 42;}else{return 0;};let i32 bad=false;}");
    rejected(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;};garbage( ;}");
    rejected(b"module main;fn i32 main(){return switch(.some(1)){case .some(_):{return 42;}case .some(_):{return 0;}};}");
    rejected(b"module main;fn i32 main(){return if(true){return 42;};}");
    rejected(b"module main;fn i32 main(){let Result<i32,u8> pending=.ok(1);return if(true){return 42;}else{return 0;};}");
}
@test fn void independent_cfg_proof_still_rejects_tampered_returns(){
    var values::Program p=compiled(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;};}");
    assert(verifier::inspect_values(ref p).is_ok);
    var usize i=0;var bool changed=false;while(i<p.body.count){
        if(p.body.code[i*8]==8){p.body.code[i*8+2]=127;changed=true;break;}i+=1;
    }assert(changed && !verifier::inspect_values(ref p).is_ok);
    assert(!public_compiler::compile(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;};}").is_ok);
}

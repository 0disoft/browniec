module tests::m2::value_source_loops_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;
import ir as ir;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(v):{v}case .err(_):{assert(false);compiled(input)}
};}
fn void executes(ref values::Program p){
    let ref ir::Program body=ref p.body;assert(body.count<=256);
    assert(verifier::inspect_values(p).is_ok);
    assert(switch(vm::run_values(p,10000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void value(ref u8[] input){let values::Program p=compiled(input);executes(ref p);}
fn void rejected(ref u8[] input,u8 kind){
    assert(switch(source::compile(input)){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset<=input.len}});
}
fn void recovery(ref u8[] input){
    let values::Program p=compiled(input);
    assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,1,0,limits())){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_values(ref p,10000000,0,growth::Limits{.object=0,.instance=0,.engine=0})){
        case .ok(_):{false}case .err(e):{e.kind==13 || e.kind==4}
    });
    executes(ref p);
}

// 47 independent guests in three focused groups. Typed allocation is monotonic
// across source sites, not runtime iterations: each guest fits sixteen slots and
// 256 instructions. Positive guests run the actual verifier and typed VM.
@test fn void while_conditions_calls_control_values_and_repeated_nested_owner_cleanup_execute(){
    // W01: body declarations initialize again on 42 visits; nested wrappers drop.
    value(b"module main;fn i32 main(){var n=0;while(n<42){let b=bytes::empty();{let Option<Buffer> o=.some(bytes::empty());}n+=1;}return n;}");
    // W02: a call in a while condition is ordinary executable source.
    value(b"module main;fn bool more(i32 n){return n<42;}fn i32 main(){var n=0;while(more(n)){n+=1;}return n;}");
    // W03/W04: condition-local owners die before either condition edge repeats.
    value(b"module main;fn i32 main(){var n=0;while(if(n<2){let b=bytes::empty();true}else{false}){n+=1;}return n+40;}");
    value(b"module main;fn i32 main(){var n=0;while(switch(.some(bytes::empty())){case .some(b):{_ = b;n<2}case .none:{false}}){n+=1;}return n+40;}");
    // W05/W06: the nearest while owns condition-arm continue and break.
    value(b"module main;fn i32 main(){var n=0;while(if(n<2){let b=bytes::empty();n+=1;continue;}else{n<3}){n+=1;}return n+39;}");
    value(b"module main;fn i32 main(){while(switch(.some(1)){case .some(_):{let b=bytes::empty();break;}case .none:{true}}){return 0;}return 42;}");
    // W07: inner break cleans its owner; outer continue cleans the outer owner.
    recovery(b"module main;fn i32 main(){var n=0;while(n<42){let a=bytes::empty();while(true){let b=bytes::empty();break;}n+=1;continue;}return n;}");
    // W08: explicit header-owner move is legal after restoration on a backedge.
    value(b"module main;fn i32 main(){var b=bytes::empty();var n=0;while(n<2){_ = b;b=bytes::empty();n+=1;continue;}_ = b;return 42;}");
    // W09: break-only moves normalize exit liveness, including zero-trip state.
    value(b"module main;fn i32 main(){let b=bytes::empty();while(true){_ = b;break;}return 42;}");
    // W10: early condition propagation drains outer owners and skips the body.
    value(b"module main;fn Option<bool> missing(){return .none;}fn Option<i32> f(){let b=bytes::empty();while(missing()?){return .some(0);}return .some(0);}fn i32 main(){switch(f()){case .some(_):{return 0;}case .none:{return 42;}}}");
    // W11: a terminal condition value arm returns with all current owners.
    value(b"module main;fn i32 main(){let a=bytes::empty();while(if(true){let b=bytes::empty();return 42;}else{false}){return 0;}return 0;}");
}

@test fn void classic_for_headers_post_transfers_nested_loops_and_terminal_value_arms_execute(){
    // F01: continue reaches post; the header declaration disappears afterward.
    value(b"module main;fn i32 main(){var n=0;for(var i=0;i<42;i+=1){let b=bytes::empty();n+=1;continue;}let i=42;return n+i-42;}");
    // F02: assignment init includes the already-supported compound operators.
    value(b"module main;fn i32 main(){var n=0;for(n+=1;n<43;n+=1){}return n-1;}");
    // F03/F04: all clauses may be absent; init/post may both be absent.
    value(b"module main;fn i32 main(){for(;;){let b=bytes::empty();break;}return 42;}");
    value(b"module main;fn i32 main(){var n=0;for(;n<42;){n+=1;}return n;}");
    // F05/F06: break and return skip a post that would overflow at runtime.
    value(b"module main;fn i32 main(){var u8 n=255;for(;true;n+=1){break;}return 42;}");
    value(b"module main;fn i32 main(){var u8 n=255;for(;true;n+=1){let b=bytes::empty();return 42;}return 0;}");
    // F07: inner continues execute only the inner post and preserve outer locals.
    value(b"module main;fn i32 main(){var n=0;for(var i=0;i<6;i+=1){for(var j=0;j<7;j+=1){let b=bytes::empty();n+=1;continue;}}return n;}");
    // F08/F09: lexical transfers inside expression arms target the enclosing for.
    value(b"module main;fn i32 main(){for(;;){let n=if(true){let b=bytes::empty();break;}else{0};_ = n;}return 42;}");
    value(b"module main;fn i32 main(){var n=0;for(var i=0;i<2;i+=1){let x=switch(.some(1)){case .some(_):{let b=bytes::empty();n+=21;continue;}case .none:{0}};n+=x;}return n;}");
    // F10: switch-expression propagation in a body drains arm-local owners.
    value(b"module main;fn Option<i32> f(){for(;;){let n=switch(.some(1)){case .some(_):{let b=bytes::empty();let Option<i32> o=.none;o?}case .none:{0}};return .some(n);}return .some(0);}fn i32 main(){switch(f()){case .some(_):{return 0;}case .none:{return 42;}}}");
    // F11: a captured first argument survives loop-expression snapshots. A later
    // argument propagates before CALL, so cleanup must still see that Buffer.
    recovery(b"module main;fn void take(Buffer b,i32 n){}fn Option<i32> f(){take(bytes::empty(),if(true){while(false){}let Option<i32> o=.none;o?}else{0});return .some(0);}fn i32 main(){switch(f()){case .some(_):{return 0;}case .none:{return 42;}}}");
    // F12/F13: multiple escaping exits must survive sibling branch-pool releases.
    value(b"module main;fn i32 main(){for(var i=0;i<3;i+=1){let x=switch(.some(i)){case .some(n):{if(n==1){let b=bytes::empty();break;}0}case .none:{let b=bytes::empty();break;}};_ = x;}return 42;}");
    value(b"module main;fn i32 main(){var n=0;for(var i=0;i<2;i+=1){if(i==0){let b=bytes::empty();n+=21;continue;}else{let b=bytes::empty();n+=21;continue;}}return n;}");

}

@test fn void loop_header_invariants_pure_for_syntax_and_result_pending_fixedpoints_are_enforced(){
    // P01/P02: replacement in the body becomes pending, then the NEXT condition
    // acknowledges it. First-entry handling must not reject this cyclic proof.
    value(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(1);_ = r.is_ok;var n=0;while(r.is_ok){r=.err(false);n+=1;}return n+41;}");
    value(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(1);_ = r.is_ok;while(r.is_ok){r=.err(false);continue;}return 42;}");
    // P03: a body acknowledgment permits each replacement, and exit cleanup
    // acknowledges the pending value from the last iteration.
    value(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(1);_ = r.is_ok;var n=0;while(n<2){_ = r;r=.err(false);n+=1;}_ = r;return 42;}");
    // P04: break replacement is pending at the zero-trip/break exit union.
    value(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(1);_ = r.is_ok;while(true){r=.err(false);break;}_ = r;return 42;}");

    // N01: first iteration overwrites a handled value, second discards pending.
    rejected(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(1);_ = r.is_ok;var n=0;while(n<2){r=.err(false);n+=1;}_ = r;return 42;}",18);
    // N02: even true has an abstract false edge; body-only handling is incomplete.
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(1);while(true){_ = r;break;}return 42;}",18);
    // N03/N04: break cannot defer acknowledgment to a condition it skips, and
    // continue cannot bypass the next iteration's pending overwrite check.
    rejected(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(1);_ = r.is_ok;while(r.is_ok){r=.err(false);break;}return 42;}",18);
    rejected(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(1);_ = r.is_ok;var n=0;while(n<2){r=.err(false);n+=1;continue;}_ = r;return 42;}",18);
    // N05: terminal return must check obligations created inside the loop.
    rejected(b"module main;fn i32 main(){while(true){let Result<i64,bool> r=.ok(1);return 42;}return 42;}",18);
    // N06: loop snapshots cannot erase anonymous pending CALL arguments. The
    // later propagation must reject their implicit discard before CALL executes.
    rejected(b"module main;fn void take(Result<i64,bool> r,i32 n){_ = r;}fn Option<i32> f(){let Result<i64,bool> r=.ok(1);take(r,if(true){while(false){}let Option<i32> o=.none;o?}else{0});return .some(0);}fn i32 main(){return 42;}",18);
    // N07/N08: transfers require a lexical loop.
    rejected(b"module main;fn i32 main(){break;return 42;}",2);
    rejected(b"module main;fn i32 main(){continue;return 42;}",2);
    // N09/N10: explicit conditions require bool.
    rejected(b"module main;fn i32 main(){while(1){break;}return 42;}",3);
    rejected(b"module main;fn i32 main(){for(;1;){break;}return 42;}",3);
    // N11..N13: calls are forbidden in each for header position, even when a
    // constant-false condition makes the runtime body/post unreachable.
    rejected(b"module main;fn i32 n(){return 0;}fn i32 main(){for(var i=n();false;i+=1){}return 42;}",3);
    rejected(b"module main;fn bool yes(){return false;}fn i32 main(){for(;yes();){break;}return 42;}",3);
    rejected(b"module main;fn i32 n(){return 1;}fn i32 main(){var i=0;for(;false;i=n()){}return 42;}",3);
    // N14..N16: propagation and if/switch values are also impure header forms.
    rejected(b"module main;fn Option<i32> f(Option<bool> o){for(;o?;){break;}return .some(42);}fn i32 main(){return 42;}",3);
    rejected(b"module main;fn i32 main(){for(var i=if(true){0}else{1};false;i+=1){}return 42;}",3);
    rejected(b"module main;fn i32 main(){var i=0;for(;false;i=switch(.some(1)){case .some(n):{n}case .none:{0}}){}return 42;}",3);
    // N17: post is validated outside the body's lexical scope.
    rejected(b"module main;fn i32 main(){var i=0;for(;false;i=n){let n=1;}return 42;}",3);
    // N18: a move on a continue edge fails the live header invariant.
    rejected(b"module main;fn i32 main(){let b=bytes::empty();while(true){_ = b;continue;}return 42;}",3);
    // N19: return completeness includes the abstract zero-trip edge.
    rejected(b"module main;fn i32 main(){while(true){return 42;}}",2);
}

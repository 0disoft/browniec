module tests::m2::value_source_must_use_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;
import render as render;
import lexer as lexer;
import std::text as text;

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

// Independent sources keep the global monotonic typed-slot ledger below sixteen.
// A predicate acknowledges a Result without consuming its Buffer owner. An owned
// copy transfers the current obligation; another owned read can create a new one.
@test fn void result_transfers_copyable_rereads_predicate_acknowledgment_and_cases_execute(){
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);_ = r;_ = r;_ = (r);return 42;}");
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.err(false);let s=r;_ = s;return 42;}");
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);let s=r;let t=r;_ = s;_ = t;return 42;}");
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);let s=r;_ = s;_ = r.is_ok;_ = r.is_err;return 42;}");
    value(b"module main;fn void take(Result<i64,bool> r){_ = r;}fn i32 main(){let Result<i64,bool> r=.ok(42);take(r);take(r);return 42;}");
    value(b"module main;fn Result<i64,bool> pass(Result<i64,bool> r){return r;}fn i32 main(){let Result<i64,bool> r=.ok(42);let s=pass(r);switch(s){case .ok(n):{if(n==42){return 42;}return 0;}case .err(_):{return 0;}}}");
    value(b"module main;fn i32 main(){let Result<Buffer,bool> r=.ok(bytes::empty());_ = ((r)).is_ok;_ = r.is_err;let s=r;_ = s;return 42;}");
    value(b"module main;fn i32 main(){let Result<i64,Buffer> r=.err(bytes::empty());_ = r.is_err;_ = r.is_ok;switch(r){case .ok(_):{return 0;}case .err(b):{_ = b;return 42;}}}");
    value(b"module main;fn i32 main(){let Result<i64,Buffer> r=.ok(42);_ = r.is_ok;let s=r;switch(s){case .ok(n):{if(n==42){return 42;}return 0;}case .err(_):{return 0;}}}");
    value(b"module main;fn Result<i64,Buffer> made(){return .err(bytes::empty());}fn i32 main(){if(((made())).is_err){return 42;}return 0;}");
    value(b"module main;fn void take(Result<Buffer,bool> r){_ = r.is_ok;}fn i32 main(){take(.ok(bytes::empty()));return 42;}");
    value(b"module main;fn void take(Result<i64,bool> r){_ = r.is_err;_ = r.is_ok;}fn i32 main(){take(.err(false));return 42;}");
    // Nested Result children transfer into their enclosing constructor. Only a
    // direct Result has an obligation; an unused outer Option is permitted.
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);let Option<Result<i64,bool>> o=.some(r);return 42;}");
    value(b"module main;fn i32 main(){let Result<Buffer,bool> r=.ok(bytes::empty());let Option<Result<Buffer,bool>> o=.some(r);return 42;}");
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);let Result<Result<i64,bool>,bool> s=.ok(r);_ = s;return 42;}");
    value(b"module main;fn i32 main(){let Option<Result<i64,bool>> o=.some(.ok(42));switch(o){case .some(r):{_ = r;}case .none:{}}return 42;}");
    value(b"module main;fn i32 main(){let Result<Result<Buffer,bool>,bool> r=.ok(.ok(bytes::empty()));switch(r){case .ok(_):{}case .err(_):{}}return 42;}");
    value(b"module main;fn i32 main(){let Option<Result<Buffer,bool>> o=.some(.ok(bytes::empty()));switch(o){case .some(_):{}case .none:{}}return 42;}");
    // Replacing a handled destination is legal, but the replacement is pending.
    value(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(1);_ = r;r=.err(false);_ = r;return 42;}");
    value(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(42);_ = r.is_ok;r=r;_ = r;return 42;}");
    value(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(42);r=r;_ = r;return 42;}");
    value(b"module main;fn i32 main(){var Result<i64,Buffer> r=.ok(1);_ = r.is_ok;r=.err(bytes::empty());_ = r;return 42;}");
    value(b"module main;fn i32 main(){{let Result<i64,bool> r=.ok(42);_ = r;}return 42;}");
    value(b"module main;fn i32 main(){let Option<i64> o=.some(1);let b=bytes::empty();return 42;}");
}

@test fn void unused_results_parameters_overwrites_scope_exits_and_error_names_are_distinct(){
    assert(lexer::equal(text::as_bytes(render::kind(18)),b"must_use_result"));
    assert(render::exit_code(18)==3 && render::exit_code(3)==3);
    assert(lexer::equal(text::as_bytes(render::kind(3)),b"type"));
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);return 42;}",18);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.err(false);return 42;}",18);
    rejected(b"module main;fn i32 main(){let Result<Buffer,bool> r=.ok(bytes::empty());return 42;}",18);
    rejected(b"module main;fn i32 main(){let Result<i64,Buffer> r=.ok(42);return 42;}",18);
    rejected(b"module main;fn Result<i64,bool> made(){return .ok(42);}fn i32 main(){let r=made();return 42;}",18);
    rejected(b"module main;fn Result<i64,bool> made(){return .ok(42);}fn i32 main(){made();return 42;}",18);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);r;return 42;}",18);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);_ = r;(r);return 42;}",18);
    // Even an unreachable helper's formal is pending on entry.
    rejected(b"module main;fn void unused(Result<i64,bool> r){}fn i32 main(){return 42;}",18);
    rejected(b"module main;fn void unused(Result<i64,Buffer> r){return;}fn i32 main(){return 42;}",18);
    rejected(b"module main;fn i32 unused(Result<i64,bool> r){return 42;}fn i32 main(){return 42;}",18);
    rejected(b"module main;fn void unused(){let Result<i64,bool> r=.ok(42);}fn i32 main(){return 42;}",18);
    rejected(b"module main;fn i32 main(){{let Result<i64,bool> r=.ok(42);}return 42;}",18);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);{let s=r;}_ = r;return 42;}",18);
    // Handling the original cannot acknowledge the separate copied destination.
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);let s=r;_ = r;return 42;}",18);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);let s=r;_ = s;let t=r;return 42;}",18);
    rejected(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(1);r=.err(false);_ = r;return 42;}",18);
    rejected(b"module main;fn i32 main(){var Result<i64,Buffer> r=.ok(1);r=.err(bytes::empty());_ = r;return 42;}",18);
    rejected(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(1);_ = r;r=.ok(42);return 42;}",18);
    rejected(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(42);_ = r;r=r;return 42;}",18);
    rejected(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(42);r=r;return 42;}",18);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);let Result<Result<i64,bool>,bool> s=.ok(r);return 42;}",18);
    rejected(b"module main;fn i32 main(){let Option<Result<i64,bool>> o=.some(.ok(42));switch(o){case .some(r):{}case .none:{}}return 42;}",18);
    rejected(b"module main;fn i32 main(){let Result<Result<i64,bool>,bool> r=.ok(.ok(42));switch(r){case .ok(s):{}case .err(_):{}}return 42;}",18);
    // Scalar/wrapper mismatches and consumed owners retain type error 3.
    rejected(b"module main;fn i32 main(){42;return 42;}",3);
    rejected(b"module main;fn Option<i64> made(){return .some(42);}fn i32 main(){made();return 42;}",3);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=42;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Option<i64> o=.some(42);_ = o.is_ok;return 42;}",3);
    rejected(b"module main;fn Result<i64,bool> f(Option<i64> o){return .ok(o?);}fn i32 main(){return 42;}",3);
    rejected(b"module main;fn Result<i64,i64> f(Result<i64,u32> r){return .ok(r?);}fn i32 main(){return 42;}",3);
    rejected(b"module main;fn i32 main(){let Result<Buffer,bool> r=.ok(bytes::empty());_ = r;_ = r.is_ok;return 42;}",3);
}

@test fn void continuing_branch_or_early_propagation_and_unpublished_call_captures_track_obligations(){
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);if(true){_ = r;}else{_ = r;}return 42;}");
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);if(true){_ = r.is_ok;}else{_ = r.is_err;}return 42;}");
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);if(false){_ = r;return 0;}_ = r;return 42;}");
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);if(true){_ = r;}_ = r;return 42;}");
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);switch(.some(1)){case .some(_):{_ = r;}case .none:{_ = r;return 0;}}return 42;}");
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);if(true){_ = r;}return 42;}",18);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);if(false){}else{_ = r;}return 42;}",18);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);switch(.some(1)){case .some(_):{_ = r;}case .none:{}}return 42;}",18);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);if(false){return 0;}_ = r;return 42;}",18);
    rejected(b"module main;fn i32 main(){var Result<i64,bool> r=.ok(42);_ = r;if(false){r=.err(false);}return 42;}",18);
    // A terminal path with a pending Result is itself invalid; valid terminal
    // paths above are excluded when the remaining continuing states merge.
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);switch(.some(1)){case .some(_):{return 0;}case .none:{_ = r;}}return 42;}",18);
    value(b"module main;fn Result<i64,bool> f(Result<i64,bool> r){return .ok(r?);}fn i32 main(){switch(f(.err(false))){case .ok(_):{return 0;}case .err(_):{return 42;}}}");
    value(b"module main;fn Result<i64,bool> f(Result<i64,bool> r){return .ok(r?);}fn i32 main(){switch(f(.ok(42))){case .ok(n):{if(n==42){return 42;}return 0;}case .err(_):{return 0;}}}");
    rejected(b"module main;fn Result<i64,bool> f(Result<i64,bool> r){let Result<i64,bool> other=.ok(1);let n=r?;_ = other;return .ok(n);}fn i32 main(){return 42;}",18);
    rejected(b"module main;fn Option<i64> f(Option<i64> o){let Result<i64,bool> other=.ok(1);let n=o?;_ = other;return .some(n);}fn i32 main(){return 42;}",18);
    value(b"module main;fn Result<i64,bool> f(Result<i64,bool> r){let Result<i64,bool> other=.ok(1);_ = other;return .ok(r?);}fn i32 main(){switch(f(.err(false))){case .ok(_):{return 0;}case .err(_):{return 42;}}}");
    // The first argument has been captured, but its callee has not executed
    // when a later argument propagates failure. It is still pending then.
    rejected(b"module main;fn void take(Result<i64,bool> a,i64 n){_ = a;}fn Option<i64> f(Option<i64> o){let Result<i64,bool> r=.ok(1);take(r,o?);return .some(42);}fn i32 main(){return 42;}",18);
    rejected(b"module main;fn void take(Result<i64,bool> a,i64 n){_ = a;}fn Option<i64> f(Option<i64> o){let Result<i64,bool> r=.ok(1);_ = r;take(r,o?);return .some(42);}fn i32 main(){return 42;}",18);
    rejected(b"module main;fn Result<i64,bool> made(){return .ok(1);}fn void take(Result<i64,bool> a,i64 n){_ = a;}fn Option<i64> f(Option<i64> o){take(made(),o?);return .some(42);}fn i32 main(){return 42;}",18);
    rejected(b"module main;fn void take(Result<Buffer,bool> a,i64 n){_ = a;}fn Result<i64,bool> f(Result<i64,bool> e){let Result<Buffer,bool> r=.ok(bytes::empty());take(r,e?);return .ok(42);}fn i32 main(){return 42;}",18);
    value(b"module main;fn void take(Result<i64,bool> a,i64 n){_ = a;}fn i32 main(){let Result<i64,bool> r=.ok(1);take(r,42);return 42;}");
    value(b"module main;fn void take(Buffer a,i64 n){}fn Option<i64> f(Option<i64> o){take(bytes::empty(),o?);return .some(0);}fn i32 main(){switch(f(.none)){case .some(_):{return 0;}case .none:{return 42;}}}");
    value(b"module main;fn void take(Buffer a,i64 n){}fn Result<i64,Buffer> f(Result<i64,Buffer> e){let b=bytes::empty();take(b,e?);return .ok(0);}fn i32 main(){switch(f(.err(bytes::empty()))){case .ok(_):{return 0;}case .err(_):{return 42;}}}");
    value(b"module main;fn void take(bool a,i64 n){}fn Option<i64> f(Option<i64> o){let Result<i64,bool> r=.ok(1);take(r.is_ok,o?);return .some(0);}fn i32 main(){switch(f(.none)){case .some(_):{return 0;}case .none:{return 42;}}}");
    value(b"module main;fn void take(i64 n,Result<i64,bool> a){_ = a;}fn Option<i64> f(Option<i64> o){take(o?,.ok(1));return .some(0);}fn i32 main(){switch(f(.none)){case .some(_):{return 0;}case .none:{return 42;}}}");
}

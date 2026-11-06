module tests::m2::value_source_propagation_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn values::Program compiled(ref u8[] text){return switch(source::compile(text)){
    case .ok(v):{v}case .err(_):{assert(false);compiled(text)}
};}
fn void executes(ref values::Program p){
    assert(verifier::inspect_values(p).is_ok);
    assert(switch(vm::run_values(p,10000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void value(ref u8[] text){let values::Program p=compiled(text);executes(ref p);}
fn void rejected(ref u8[] text){
    assert(switch(source::compile(text)){case .ok(_):{false}case .err(e):{e.kind==3 && e.offset<=text.len}});
}
fn void recovery(ref u8[] text){
    let values::Program p=compiled(text);assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,1,0,limits())){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_values(ref p,10000000,0,growth::Limits{.object=0,.instance=0,.engine=0})){
        case .ok(_):{false}case .err(e):{e.kind==13 || e.kind==4}
    });
    executes(ref p);
}

// Short independent sources stay within the sixteen-slot global typed ledger.
// Helper functions here group fixtures without creating another native test.
fn void scalar_positions(){
    value(b"module main;fn Option<i32> f(Option<i32> a){var n=(a)?;n=n+1;return .some(-a?+n+41);}fn i32 main(){switch(f(.some(1))){case .some(n):{return n;}case .none:{return 0;}}}");
    value(b"module main;fn Option<i32> f(Option<i32> a){var n=0;n=a?+1;return .some(n);}fn i32 main(){switch(f(.some(41))){case .some(n):{return n;}case .none:{return 0;}}}");
    value(b"module main;fn Option<bool> yes(){return .some(true);}fn Option<i32> f(){if(!((yes()))?){return .none;}return .some(42);}fn i32 main(){switch(f()){case .some(n):{return n;}case .none:{return 0;}}}");
    value(b"module main;fn i32 add(i32 a,i32 b){return a+b;}fn Option<i32> f(){return .some(add(.some(40)?,2));}fn i32 main(){switch(f()){case .some(n):{return n;}case .none:{return 0;}}}");
    value(b"module main;fn Option<i32> made(){return .some(42);}fn Option<i32> f(){return .some((made())?);}fn i32 main(){switch(f()){case .some(n):{return n;}case .none:{return 0;}}}");
}
fn void switch_and_failure(){
    value(b"module main;fn Option<Option<i32>> made(){return .some(.some(42));}fn Option<i32> f(){switch((made())?){case .some(n):{return .some(n);}case .none:{return .none;}}}fn i32 main(){switch(f()){case .some(n):{return n;}case .none:{return 0;}}}");
    value(b"module main;fn Option<i64> missing(){return .none;}fn i32 bad(){var u8 x=255;x+=1;return 0;}fn Option<bool> f(){let i64 n=missing()?;_ = bad();return .some(n==0);}fn i32 main(){switch(f()){case .some(_):{return 0;}case .none:{return 42;}}}");
}
@test fn void postfix_precedence_contexts_and_option_failure_skip_later_work(){
    scalar_positions();switch_and_failure();
}

fn void result_domains(){
    value(b"module main;fn Result<bool,u32> f(Result<i64,u32> a){let i64 n=((a))?;if(!a.is_ok){return .err(0);}return .ok(n==9000000000);}fn i32 main(){switch(f(.ok(9000000000))){case .ok(b):{if(b){return 42;}return 0;}case .err(_):{return 0;}}}");
    value(b"module main;fn Result<i64,u32> missing(){return .err(4294967295);}fn Result<bool,u32> f(){return .ok((missing())?==0);}fn i32 main(){switch(f()){case .ok(_):{return 0;}case .err(n):{if(n==4294967295){return 42;}return 0;}}}");
    value(b"module main;fn Result<Result<i64,bool>,bool> made(){return .ok(.ok(9000000000));}fn Result<i64,bool> f(){return (made())?;}fn i32 main(){switch(f()){case .ok(n):{if(n==9000000000){return 42;}return 0;}case .err(_):{return 0;}}}");
}
fn void nested_wrappers(){
    value(b"module main;fn Option<i64> f(){let Option<Option<i64>> a=.some(.some(9000000000));return .some(a??);}fn i32 main(){switch(f()){case .some(n):{if(n==9000000000){return 42;}return 0;}case .none:{return 0;}}}");
    value(b"module main;fn Option<i64> f(){let Option<Option<i64>> a=.some(.none);return .some(a??);}fn i32 main(){switch(f()){case .some(_):{return 0;}case .none:{return 42;}}}");
    value(b"module main;fn Result<bool,u32> f(){let Result<Result<i64,u32>,u32> a=.ok(.ok(9000000000));return .ok(a??==9000000000);}fn i32 main(){switch(f()){case .ok(b):{if(b){return 42;}return 0;}case .err(_):{return 0;}}}");
    value(b"module main;fn Result<i64,u32> f(){let Result<Result<i64,u32>,u32> a=.ok(.err(4294967295));return .ok(a??);}fn i32 main(){switch(f()){case .ok(_):{return 0;}case .err(n):{if(n==4294967295){return 42;}return 0;}}}");
}
@test fn void exact_wide_result_errors_copyable_names_and_chained_wrappers_roundtrip(){
    result_domains();nested_wrappers();
}

fn void buffer_payloads(){
    value(b"module main;fn Option<i32> f(Option<Buffer> a){let b=(a)?;_ = b;return .some(42);}fn i32 main(){switch(f(.some(bytes::empty()))){case .some(n):{return n;}case .none:{return 0;}}}");
    value(b"module main;fn Option<Buffer> made(){return .some(bytes::empty());}fn Option<Buffer> f(){return .some(((made()))?);}fn i32 main(){switch(f()){case .some(b):{_ = b;return 42;}case .none:{return 0;}}}");
    value(b"module main;fn Result<bool,Buffer> f(Result<i64,Buffer> a){return .ok(a?==1);}fn i32 main(){switch(f(.err(bytes::empty()))){case .ok(_):{return 0;}case .err(b):{_ = b;return 42;}}}");
    value(b"module main;fn Result<i64,Buffer> f(){let Result<i64,Buffer> a=.ok(9000000000);return .ok(a?);}fn i32 main(){switch(f()){case .ok(n):{if(n==9000000000){return 42;}return 0;}case .err(b):{_ = b;return 0;}}}");
    value(b"module main;fn Option<Buffer> f(){let Option<Option<Buffer>> a=.some(.some(bytes::empty()));return .some(a??);}fn i32 main(){switch(f()){case .some(b):{_ = b;return 42;}case .none:{return 0;}}}");
}
fn void captured_arguments(){
    value(b"module main;fn Option<i32> missing(){return .none;}fn i32 bad(){var u8 x=255;x+=1;return 0;}fn i32 take(Buffer a,i32 n,i32 last){return n+last;}fn Option<i32> f(){let a=bytes::empty();return .some(take(a,missing()?,bad()));}fn i32 main(){switch(f()){case .some(_):{return 0;}case .none:{return 42;}}}");
    recovery(b"module main;fn Option<i32> missing(){return .none;}fn i32 bad(){var u8 x=255;x+=1;return 0;}fn i32 take(Buffer a,i32 n,i32 last){return n+last;}fn Option<i32> f(){return .some(take(bytes::empty(),missing()?,bad()));}fn i32 main(){switch(f()){case .some(_):{return 0;}case .none:{return 42;}}}");
    value(b"module main;fn void take(Buffer a,i32 n){}fn Result<bool,Buffer> f(){let a=bytes::empty();let Result<i32,Buffer> r=.err(bytes::empty());take(a,r?);return .ok(true);}fn i32 main(){switch(f()){case .ok(_):{return 0;}case .err(b):{_ = b;return 42;}}}");
}
@test fn void buffer_moves_pending_arguments_and_failed_invocations_cleanup_before_retry(){
    buffer_payloads();captured_arguments();
}

fn void wrong_contexts(){
    rejected(b"module main;fn Result<i32,bool> f(Option<i32> a){return .ok(a?);}fn i32 main(){return 42;}");
    rejected(b"module main;fn Option<i32> f(Result<i32,bool> a){return .some(a?);}fn i32 main(){return 42;}");
    rejected(b"module main;fn Result<i32,i64> f(Result<i32,u32> a){return .ok(a?);}fn i32 main(){return 42;}");
    rejected(b"module main;fn Option<bool> f(Option<i64> a){return .some(a?);}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 main(){let Option<i32> a=.some(42);return a?;}");
    rejected(b"module main;fn i64 f(Option<i64> a){return a?;}fn i32 main(){return 42;}");
    rejected(b"module main;fn bool f(Option<bool> a){return a?;}fn i32 main(){return 42;}");
    rejected(b"module main;fn void f(Option<i32> a){_ = a?;}fn i32 main(){return 42;}");
    rejected(b"module main;fn Option<i32> f(){return .some(42?);}fn i32 main(){return 42;}");
    rejected(b"module main;fn void nothing(){}fn Option<i32> f(){return .some(nothing()?);}fn i32 main(){return 42;}");
    rejected(b"module main;fn Result<i32,bool> f(){return .ok(.ok(42)?);}fn i32 main(){return 42;}");
    rejected(b"module main;fn Option<i32> f(){return .some(.none?);}fn i32 main(){return 42;}");
    rejected(b"module main;fn Option<i32> f(Option<i32> a){return .some(a??);}fn i32 main(){return 42;}");
}
fn void consumed_names(){
    rejected(b"module main;fn Option<i32> f(Option<Buffer> a){let b=a?;_ = a;_ = b;return .some(42);}fn i32 main(){return 42;}");
    // Inactive Buffer alternatives still make the whole Result move-only.
    rejected(b"module main;fn Result<i64,Buffer> f(){let Result<i64,Buffer> a=.ok(42);let n=a?;_ = a;return .ok(n);}fn i32 main(){return 42;}");
    rejected(b"module main;fn Option<i32> f(){let Option<Buffer> a=.none;let b=a;_ = a?;_ = b;return .some(42);}fn i32 main(){return 42;}");
    rejected(b"module main;fn Option<i32> f(){let a=bytes::empty();_ = a?;return .some(42);}fn i32 main(){return 42;}");
}
@test fn void invalid_wrappers_error_domains_inference_and_consumed_owners_reject_as_types(){
    wrong_contexts();consumed_names();
}

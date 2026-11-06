module tests::m2::value_source_joins_source;
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
fn void value(ref u8[] input){
    let values::Program p=compiled(input);assert(verifier::inspect_values(ref p).is_ok);
    let ref ir::Program body=ref p.body;
    assert(body.count<=256);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void rejected(ref u8[] input,u8 kind){
    assert(switch(source::compile(input)){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset<=input.len}});
}

// Independent guests keep the total monotonic typed-slot ledger within sixteen,
// including helper signatures and both exclusive arms. No generated matrices.
@test fn void if_values_exact_types_inference_else_if_nested_values_and_terminal_arms_execute(){
    value(b"module main;fn i32 main(){let n=if(false){0}else if(true){let a=40;a+2}else{0};return n;}");
    value(b"module main;fn i32 bad(){var u8 x=255;x+=1;return 0;}fn i32 main(){return if(false){bad()}else{42};}");
    value(b"module main;fn i32 main(){let n=if(true){40}else{0}+2*1;return n;}");
    value(b"module main;fn i32 main(){if(!if(false){true}else{false}){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let i64 n=if(false){0}else{9000000000};if(n==9000000000){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u32 a=4294967295;let n=if(false){a}else{4294967295};if(n==4294967295){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let b=if(false){bytes::empty()}else{let c=bytes::empty();c};_ = b;return 42;}");
    value(b"module main;fn i32 main(){let Option<i64> a=.some(42);let o=if(true){a}else{.none};switch(o){case .some(n):{if(n==42){return 42;}return 0;}case .none:{return 0;}}}");
    value(b"module main;fn i32 main(){let Option<Result<i64,bool>> o=if(false){.none}else{.some(.ok(42))};switch(o){case .some(r):{switch(r){case .ok(n):{if(n==42){return 42;}return 0;}case .err(_):{return 0;}}}case .none:{return 0;}}}");
    value(b"module main;fn i32 main(){let Result<i64,bool> r=if(true){.ok(9000000000)}else{.err(false)};if(r.is_ok){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let n=if(true){let b=bytes::empty();return 42;}else{0};return n;}");
    value(b"module main;fn i32 main(){let n=if(false){0}else{return 42;};return n;}");
    value(b"module main;fn Option<i32> f(Option<i32> a){let n=if(true){let b=bytes::empty();a?}else{0};return .some(n);}fn i32 main(){switch(f(.some(42))){case .some(n):{return n;}case .none:{return 0;}}}");
    value(b"module main;fn Result<i32,Buffer> f(Result<i32,Buffer> r){let n=if(true){let b=bytes::empty();r?}else{_ = r;0};return .ok(n);}fn i32 main(){switch(f(.err(bytes::empty()))){case .ok(_):{return 0;}case .err(b):{_ = b;return 42;}}}");
    value(b"module main;fn i32 main(){return if(true){switch(.some(40)){case .some(n):{n+2}case .none:{0}}}else{if(false){0}else{0}};}");
    value(b"module main;fn void work(){}fn i32 main(){return if(true){work();42}else{0};}");
    value(b"module main;fn void work(){}fn Buffer make(){return if(true){work();bytes::empty()}else{bytes::empty()};}fn i32 main(){let b=make();_ = b;return 42;}");
    value(b"module main;fn i32 main(){return if(false){42}else if(true){return 42;}else{return 0;};}");
    value(b"module main;fn i32 main(){return if(true){if(false){return 0;}let n=40;n+2}else{0};}");

}

@test fn void switch_values_exact_variants_owned_payloads_postfix_nested_values_and_terminal_arms_execute(){
    value(b"module main;fn i32 main(){let n=switch(.some(40)){case .some(p):{let a=2;p+a}case .none:{0}};return n;}");
    value(b"module main;fn i32 bad(){var u8 x=255;x+=1;return 0;}fn i32 main(){let Option<i32> o=.none;return switch(o){case .none:{42}case .some(_):{bad()}};}");
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(9000000000);let b=switch(r){case .ok(n):{n==9000000000}case .err(_):{false}};if(b){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let Result<i64,Buffer> r=.err(bytes::empty());let b=switch(r){case .ok(_):{bytes::empty()}case .err(e):{let scratch=bytes::empty();e}};_ = b;return 42;}");
    value(b"module main;fn i32 main(){let Option<Buffer> o=switch(.some(1)){case .some(_):{let b=bytes::empty();.some(b)}case .none:{.none}};switch(o){case .some(b):{_ = b;return 42;}case .none:{return 0;}}}");
    value(b"module main;fn i32 main(){let Result<Buffer,bool> r=switch(.some(1)){case .some(_):{.ok(bytes::empty())}case .none:{.err(false)}};if(r.is_ok){_ = r;return 42;}_ = r;return 0;}");
    value(b"module main;fn i32 main(){let Option<Result<i64,bool>> o=switch(.some(1)){case .some(_):{.some(.ok(42))}case .none:{.none}};switch(o){case .some(r):{switch(r){case .ok(n):{if(n==42){return 42;}return 0;}case .err(_):{return 0;}}}case .none:{return 0;}}}");
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);_ = r.is_ok;let q=switch(.some(1)){case .some(_):{r}case .none:{.err(false)}};_ = q;return 42;}");
    value(b"module main;fn i32 main(){let n=switch(.some(1)){case .some(_):{return 42;}case .none:{0}};return n;}");
    value(b"module main;fn i32 main(){let Option<i32> o=.none;let n=switch(o){case .some(_):{0}case .none:{return 42;}};return n;}");
    value(b"module main;fn i32 main(){let a=.some(42);if((switch(.some(1)){case .some(_):{a}case .none:{.none}}).is_some){return 42;}return 0;}");
    value(b"module main;fn Option<i32> f(){let Option<i32> a=.some(40);return .some((switch(.some(1)){case .some(_):{a}case .none:{.none}})?+2);}fn i32 main(){switch(f()){case .some(n):{return n;}case .none:{return 0;}}}");
    value(b"module main;fn i32 main(){return switch(.some(40)){case .some(n):{if(true){n}else{0}}case .none:{0}}+2;}");
}

@test fn void invalid_yields_exact_types_variants_pending_results_and_moved_names_reject_with_real_cleanup(){
    rejected(b"module main;fn Result<i32,Buffer> f(Result<i32,Buffer> r){let n=if(true){let b=bytes::empty();r?}else{0};return .ok(n);}fn i32 main(){return 42;}",18);
    rejected(b"module main;fn i32 main(){let n=if(true){42};return n;}",2);
    rejected(b"module main;fn i32 main(){let n=if(true){}else{42};return n;}",3);
    rejected(b"module main;fn i32 main(){let n=if(true){42;}else{42};return n;}",3);
    rejected(b"module main;fn i32 main(){return if(1){42}else{0};}",3);
    rejected(b"module main;fn i32 main(){let i64 a=42;let u32 b=42;let n=if(true){a}else{b};return 42;}",3);
    rejected(b"module main;fn i32 main(){let Option<i64> a=.some(42);let Option<u32> b=.some(42);let o=switch(.some(1)){case .some(_):{a}case .none:{b}};return 42;}",3);
    rejected(b"module main;fn i32 main(){let n=switch(.some(42)){case .some(p):{p}};return n;}",2);
    rejected(b"module main;fn i32 main(){let n=switch(.some(42)){case .some(p):{p}case .some(q):{q}};return n;}",3);
    rejected(b"module main;fn i32 main(){let n=switch(.some(42)){case .ok(p):{p}case .none:{0}};return n;}",3);
    rejected(b"module main;fn i32 main(){let a=bytes::empty();let b=if(true){a}else{bytes::empty()};_ = a;_ = b;return 42;}",3);
    rejected(b"module main;fn i32 main(){let a=bytes::empty();let b=switch(.some(1)){case .some(_):{a}case .none:{bytes::empty()}};_ = a;_ = b;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=if(true){.ok(42)}else{.err(false)};return 42;}",18);
    rejected(b"module main;fn i32 main(){let Option<Result<i64,bool>> o=.some(.ok(42));let n=switch(o){case .some(r):{42}case .none:{42}};return n;}",18);
    rejected(b"module main;fn i32 main(){let n=if(true){let Result<i64,bool> r=.ok(1);42}else{42};return n;}",18);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(1);let n=if(true){_ = r.is_ok;42}else{42};return n;}",18);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(1);let n=if(false){return 0;}else{_ = r;42};return n;}",18);
    rejected(b"module main;fn Option<i32> f(Option<i32> o){let Result<i64,bool> r=if(true){.ok(1)}else{.err(false)};let n=o?;_ = r;return .some(n);}fn i32 main(){return 42;}",18);
    rejected(b"module main;fn i32 main(){let r=if(true){.ok(42)}else{.err(false)};_ = r;return 42;}",3);
    // pending is OR over continuing exits, then explicit handling acknowledges it.
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(1);let n=if(true){_ = r.is_ok;42}else{42};_ = r;return n;}");
    // A common source can move once on each exclusive path, never twice at runtime.
    value(b"module main;fn i32 main(){let a=bytes::empty();let b=if(false){a}else{a};_ = b;return 42;}");
    // The surviving path drops a maybe-moved owner; mutable reinitialization is fresh.
    value(b"module main;fn i32 main(){let a=bytes::empty();let n=if(false){_ = a;0}else{let scratch=bytes::empty();42};return n;}");
    value(b"module main;fn i32 main(){var a=bytes::empty();let n=switch(.some(1)){case .some(_):{_ = a;42}case .none:{0}};a=bytes::empty();_ = a;return n;}");
}

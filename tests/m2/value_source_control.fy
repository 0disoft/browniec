module tests::m2::value_source_control;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;
import std::bytes as bytes;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn values::Program compiled(ref u8[] text){return switch(source::compile(text)){
    case .ok(v):{v}case .err(_):{assert(false);compiled(text)}
};}
fn void value(ref u8[] text){
    let values::Program p=compiled(text);assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void rejected(ref u8[] text,u8 kind){
    assert(switch(source::compile(text)){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset<=text.len}});
}

@test fn void mutable_buffers_wrappers_and_scalar_slots_replace_reinitialize_and_snapshot_rhs_values(){
    value(b"module main;fn Buffer id(Buffer a){return a;}fn i32 main(){var Buffer a=bytes::empty();a=id(a);_ = a;a=bytes::empty();a=a;return 42;}");
    value(b"module main;fn i32 main(){var Option<Buffer> a=.some(bytes::empty());a=.none;a=.some(bytes::empty());_ = a;return 42;}");
    value(b"module main;fn i32 main(){var Result<i64,bool> a=.ok(1);_ = a.is_ok;a=.err(false);a=a;_ = a;return 42;}");
    value(b"module main;fn i32 main(){var n=20;n+=1;n*=2;var bool b=true;b=false;if(b){return 0;}return n;}");
    value(b"module main;fn i32 main(){var u8 n=1;n<<=3;n|=2;n^=1;n&=15;n>>=1;n-=1;n%=3;n/=2;_ = n;return 42;}");
}

@test fn void conditional_moves_emit_real_cleanup_on_the_other_path_without_owner_revival(){
    value(b"module main;fn i32 main(){var a=bytes::empty();if(false){_ = a;}a=bytes::empty();_ = a;return 42;}");
    value(b"module main;fn i32 main(){var a=bytes::empty();if(true){_ = a;}else{}a=bytes::empty();return 42;}");
    value(b"module main;fn i32 main(){let a=bytes::empty();if(false){_ = a;}return 42;}");
    value(b"module main;fn i32 main(){let a=bytes::empty();if(true){return 42;}else{_ = a;return 0;}}");
    value(b"module main;fn i32 main(){let a=bytes::empty();if(false){return 0;}else if(false){_ = a;return 0;}else{_ = a;}return 42;}");
    value(b"module main;fn i32 main(){var a=bytes::empty();if(true){_ = a;}else{a=a;}a=bytes::empty();return 42;}");
}

@test fn void exhaustive_switches_extract_nested_wide_and_buffer_payloads_and_merge_surviving_paths(){
    value(b"module main;fn i32 main(){let Result<Option<i64>,Buffer> r=.ok(.some(42));switch(r){case .ok(o):{switch(o){case .some(n):{if(n==42){return 42;}return 0;}case .none:{return 0;}}}case .err(b):{_ = b;return 0;}}}");
    value(b"module main;fn i32 main(){let Result<i64,Buffer> r=.err(bytes::empty());switch(r){case .err(b):{_ = b;return 42;}case .ok(n):{_ = n;return 0;}}}");
    value(b"module main;fn i32 main(){var a=bytes::empty();let o=.some(1);switch(o){case .some(_):{_ = a;}case .none:{}}a=bytes::empty();return 42;}");
    value(b"module main;fn i32 main(){var n=0;let Option<Buffer> o=.none;switch(o){case .none:{n=42;}case .some(b):{_ = b;n=0;}}return n;}");
    value(b"module main;fn i32 main(){let Option<Buffer> o=.none;switch(o){case .some(_):{return 0;}case .none:{}}return 42;}");
}

@test fn void unselected_if_and_switch_arms_do_not_execute_failing_calls(){
    value(b"module main;fn i32 bad(){var u8 x=255;x+=1;return 0;}fn i32 main(){if(false){_ = bad();}return 42;}");
    value(b"module main;fn i32 bad(){var u8 x=255;x+=1;return 0;}fn i32 main(){switch(.some(bytes::empty())){case .some(_):{return 42;}case .none:{_ = bad();return 0;}}}");
    let values::Program p=compiled(b"module main;fn i32 bad(){var u8 x=255;x+=1;return 0;}fn i32 main(){if(true){_ = bad();}return 42;}");
    assert(switch(vm::run_values(ref p,10000000,0,limits())){case .ok(_):{false}case .err(e):{e.kind==6}});
}

@test fn void maybe_moved_values_immutable_writes_and_nonexhaustive_or_duplicate_cases_reject(){
    rejected(b"module main;fn i32 main(){let a=bytes::empty();if(false){_ = a;}_ = a;return 42;}",3);
    rejected(b"module main;fn i32 main(){let a=bytes::empty();a=bytes::empty();return 42;}",3);
    rejected(b"module main;fn i32 main(){var Option<Buffer> a=.none;a=.some(42);return 42;}",3);
    rejected(b"module main;fn i32 main(){var a=bytes::empty();a+=a;return 42;}",3);
    rejected(b"module main;fn i32 main(){if(1){return 42;}return 0;}",3);
    rejected(b"module main;fn i32 main(){let Option<Buffer> o=.none;switch(o){case .none:{}case .none:{}}return 42;}",3);
    rejected(b"module main;fn i32 main(){let o=.some(1);switch(o){case .some(n):{_ = n;}}return 42;}",2);
    rejected(b"module main;fn i32 main(){let o=.some(1);switch(o){case .some(n):{}case .none:{}}_ = n;return 42;}",3);
}

fn bytes::Buffer nested(usize count){
    var bytes::Buffer text=bytes::empty();
    let usize start=switch(bytes::append(ref mut text,b"module main;fn i32 main(){")){case .ok(n):{n}case .err(_):{assert(false);0}};
    var usize i=0;while(i<count){let usize n=switch(bytes::append(ref mut text,b"if(true){")){case .ok(n):{n}case .err(_):{assert(false);0}};i+=1;}
    let usize value=switch(bytes::append(ref mut text,b"return 42;")){case .ok(n):{n}case .err(_):{assert(false);0}};
    i=0;while(i<count){let usize n=switch(bytes::append(ref mut text,b"}else{return 42;}")){case .ok(n):{n}case .err(_):{assert(false);0}};i+=1;}
    let usize end=switch(bytes::append(ref mut text,b"}")){case .ok(n):{n}case .err(_):{assert(false);0}};
    return text;
}
@test fn void admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override(){
    let bytes::Buffer admitted=nested(32);value(bytes::view(ref admitted));
    let bytes::Buffer refused=nested(33);rejected(bytes::view(ref refused),4);
}

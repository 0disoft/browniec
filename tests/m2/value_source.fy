module tests::m2::value_source;
import value_source as source;
import value_ir as values;
import value_properties as properties;
import verifier as verifier;
import vm as vm;
import errors as errors;
import buffer_growth as growth;

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

@test fn void empty_buffer_and_nested_tags_run_through_forward_mixed_calls_and_real_cleanup(){
    value(b"module main;fn i32 main(){let Buffer a=bytes::empty();let b=forward(a,40);_ = b;return 42;}fn Result<Option<Buffer>,i64> forward(Buffer a,i32 n){let Option<Buffer> b=.some(a);return .ok(b);}");
    value(b"module main;fn Option<Buffer> pass(Option<Buffer> p){return p;}fn i32 main(){let Option<Buffer> a=.none;let b=pass(a);_ = b;return 42;}");
    value(b"module main;fn Result<i64,Buffer> pass(Result<i64,Buffer> p){return p;}fn i32 main(){let Result<i64,Buffer> a=.ok(-9223372036854775808);let b=pass(a);_ = b;return 42;}");
    value(b"module main;fn i32 main(){let Result<Option<i64>,u32> a=.ok(.some(9000000000));let b=copy(a);_ = a;_ = b;return 42;}fn Result<Option<i64>,u32> copy(Result<Option<i64>,u32> a){return a;}");
    value(b"module main;fn Buffer made(){return brownie::bytes::empty();}fn i32 main(){{let a=made();_ = a;}return 42;}");
}

@test fn void scalar_domains_void_calls_and_lexical_scopes_preserve_ordinary_register_values(){
    value(b"module main;fn i32 add(i32 a,i32 b){return a+b;}fn void use(Buffer b){}fn i32 main(){use(bytes::empty());let i64 wide=-9223372036854775808;let u8 small=255;let u32 big=4294967295;let usize max=18446744073709551615;let bool yes=41<42;_ = wide;_ = small;_ = big;_ = max;_ = yes;return add(40,2);}");
    value(b"module main;fn i32 main(){let a=.some(bytes::empty());_ = a;{let i32 n=42;_ = n;}return 40+2;}");
    value(b"module main;fn void use(Buffer b){return;}fn i32 main(){let Buffer a=bytes::empty();use(a);return 42;}");
}

@test fn void whole_type_move_rules_and_unsupported_source_forms_fail_before_vm_admission(){
    rejected(b"module main;fn i32 main(){let Buffer a=bytes::empty();let b=a;_ = a;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Option<Buffer> a=.none;let b=a;_ = a;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Result<i64,Buffer> a=.ok(1);let b=a;_ = a;return 42;}",3);
    rejected(b"module main;fn void take(Buffer a,Buffer b){}fn i32 main(){let a=bytes::empty();take(a,a);return 42;}",3);
    rejected(b"module main;fn i32 main(){let Buffer a=bytes::empty();{let a=bytes::empty();}return 42;}",3);
    rejected(b"module main;fn Buffer f(){let a=bytes::empty();}fn i32 main(){return 42;}",2);
    rejected(b"module main;fn i32 main(){bytes::empty();return 42;}",3);
    rejected(b"module main;fn i32 main(){_ = .ok(1);return 42;}",3);
    rejected(b"module main;fn i32 main(){let Buffer a=42;return 42;}",3);
    rejected(b"module main;fn i32 main(){let u8 a=-1;return 42;}",3);
}

@test fn void failed_native_setup_and_instruction_budgets_leave_reusable_source_and_exact_errors(){
    let values::Program p=compiled(b"module main;fn i32 main(){let Buffer a=bytes::empty();let Option<Buffer> b=.some(a);_ = b;return 42;}");
    assert(switch(vm::run_values(ref p,0,0,limits())){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_values(ref p,10000000,0,growth::Limits{.object=0,.instance=0,.engine=0})){
        case .ok(_):{false}case .err(e):{e.kind==13 || e.kind==4}
    });
    assert(switch(vm::run_values(ref p,10000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}

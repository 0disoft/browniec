module tests::m2::body_lowering;
import compiler as compiler;
import functions as functions;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import std::bytes as bytes;

fn void same(ref ir::Program a,ref ir::Program b){
    {var usize i=0;while(i<2048){assert(a.code[i]==b.code[i]);i+=1;}}
    {var usize i=0;while(i<128){assert(a.constants[i]==b.constants[i]);i+=1;}}
    {var usize i=0;while(i<256){assert(a.offsets[i]==b.offsets[i]);i+=1;}}
    assert(a.count==b.count);
    assert(a.registers==b.registers);
    assert(a.constant_count==b.constant_count);
    {var usize i=0;while(i<16){assert(a.starts[i]==b.starts[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.ends[i]==b.ends[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.register_starts[i]==b.register_starts[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.register_ends[i]==b.register_ends[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.arities[i]==b.arities[i]);i+=1;}}
    {var usize i=0;while(i<256){assert(a.call_args[i]==b.call_args[i]);i+=1;}}
    {var usize i=0;while(i<32){assert(a.call_arities[i]==b.call_arities[i]);i+=1;}}
    assert(a.function_count==b.function_count);
    assert(a.entry==b.entry);
    assert(a.call_count==b.call_count);
    {var usize i=0;while(i<128){assert(a.types[i]==b.types[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.return_types[i]==b.return_types[i]);i+=1;}}
    {var usize i=0;while(i<128){assert(a.slots[i]==b.slots[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.array_functions[i]==b.array_functions[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.record_functions[i]==b.record_functions[i]);i+=1;}}
    {var usize i=0;while(i<128){assert(a.array_parameters[i]==b.array_parameters[i]);i+=1;}}
    {var usize i=0;while(i<128){assert(a.record_parameters[i]==b.record_parameters[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.array_results[i]==b.array_results[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.record_results[i]==b.record_results[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.slice_roots[i]==b.slice_roots[i]);i+=1;}}
    {var usize i=0;while(i<128){assert(a.slice_parameters[i]==b.slice_parameters[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.slice_origins[i]==b.slice_origins[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.slice_functions[i]==b.slice_functions[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.slice_elements[i]==b.slice_elements[i]);i+=1;}}
    {var usize i=0;while(i<4096){assert(a.list_operands[i]==b.list_operands[i]);i+=1;}}
    assert(a.list_used==b.list_used);
    assert(a.arrays.count==b.arrays.count && a.records.count==b.records.count && a.records.layouts.count==b.records.layouts.count);
    var usize i=0;while(i<16){assert(a.arrays.elements[i]==b.arrays.elements[i] && a.arrays.lengths[i]==b.arrays.lengths[i] && a.arrays.mutable[i]==b.arrays.mutable[i]);assert(a.records.records[i]==b.records.records[i] && a.records.mutable[i]==b.records.mutable[i]);i+=1;}
    i=0;while(i<32){assert(a.records.layouts.fields[i]==b.records.layouts.fields[i]);i+=1;}
    i=0;while(i<512){assert(a.records.layouts.kinds[i]==b.records.layouts.kinds[i] && a.records.layouts.types[i]==b.records.layouts.types[i]);i+=1;}
}
fn void compare(ref u8[] source,bool success){compare_candidate(source,success,false);}
fn void captured(ref u8[] source,bool success){compare_candidate(source,success,true);}
fn void compare_candidate(ref u8[] source,bool success,bool aggregates){
    var functions::Table t=switch(functions::scan(source)){case .ok(v):{v}case .err(e):{
        assert(!success);switch(compiler::compile(source)){case .ok(_):{assert(false);}case .err(z):{assert(e.kind==z.kind && e.offset==z.offset);}};return;
    }};
    var ir::Program a=ir::empty();a.function_count=t.count;a.entry=t.entry;a.return_types=t.return_types;
    var ir::Program b=ir::empty();b.function_count=t.count;b.entry=t.entry;b.return_types=t.return_types;
    if(aggregates){assert(compiler::prepare_aggregates(source,ref mut t,ref mut a).is_ok);assert(compiler::prepare_aggregates(source,ref mut t,ref mut b).is_ok);same(ref a,ref b);}
    var usize f=0;while(f<t.count){
        let Result<usize,errors::Error> raw=compiler::lower_body(source,ref t,f,ref mut a,false);
        let Result<usize,errors::Error> staged=compiler::lower_body(source,ref t,f,ref mut b,true);same(ref a,ref b);
        switch(raw){case .ok(x):{assert(staged.is_ok);switch(staged){case .ok(y):{assert(x==y);}case .err(_):{assert(false);}};}
            case .err(e):{assert(!success);switch(staged){case .ok(_):{assert(false);}case .err(z):{assert(e.kind==z.kind && e.offset==z.offset);}};return;}};
        f+=1;
    }
    assert(success && verifier::verify(ref b).is_ok);
    assert(switch(vm::run_with_array_limit(ref b,10000000,65536)){case .ok(n):{n==42}case .err(_):{false}});
}
@test fn void control_continuations_match_all_raw_ir_fields_and_execute(){
    compare(b"module main;fn i32 main(){if(false){return 0;}else if(true){{return 42;}}else{return 1;}}",true);
    compare(b"module main;fn i32 main(){var i32 i=0;while(i<3){i=i+1;if(i==2){continue;}}return 42;}",true);
    compare(b"module main;fn i32 main(){for(var i32 i=0;i<3;i=i+1){if(i==1){continue;}if(i==2){break;}}return 42;}",true);
    compare(b"module main;fn i32 main(){for(;;){break;}return 42;}",true);
    compare(b"module main;fn i32 main(){for(;;){let i32[1] a=[7;1];break;}return 42;}",true);
    compare(b"module main;fn i32 main(){var i32 i=0;while(i<2){let i32[1] a=[7;1];i=i+1;continue;}return 42;}",true);
    compare(b"module main;fn i32 main(){let Option<i32> o=.some(42);switch(o){case .some(n):{return n;}case .none:{return 0;}}}",true);
    compare(b"module main;fn i32 main(){let Result<i32,bool> o=.ok(42);switch(o){case .ok(n):{return n;}case .err(_):{return 0;}}}",true);
    compare(b"module main;fn i32 main(){if(true){let i32[2] a=[20,22];}else{}return 42;}",true);
    compare(b"module main;fn void probe(){{let i32[2] a=[20,22];}}fn i32 main(){probe();return 42;}",true);
}
@test fn void invalid_control_headers_and_terminal_errors_keep_exact_offsets(){
    compare(b"module main;fn i32 main(){if(1){return 42;}else{return 0;}}",false);
    compare(b"module main;fn i32 main(){if(true)return 42;return 0;}",false);
    compare(b"module main;fn i32 main(){{return 42;return 0;}}",false);
    compare(b"module main;fn i32 main(){break;return 42;}",false);
    compare(b"module main;fn i32 main(){continue return 42;}",false);
    compare(b"module main;fn i32 main(){let Option<i32> o=.none;switch(o){case .some(return):{return 0;}case .none:{return 42;}}}",false);
    compare(b"module main;fn i32 main(){let Option<i32> o=.none;switch(o){case .ok(n):{return n;}case .none:{return 42;}}}",false);
    compare(b"module main;fn i32 main(){for(;;){return 42;}}",false);
    compare(b"module main;fn i32 main(){let Option<i32> o=.none;switch(o){case .none:{return 0;}case .none:{return 42;}}}",false);
}
fn bytes::Buffer nested(usize count){var bytes::Buffer s=bytes::empty();assert(bytes::append(ref mut s,b"module main;fn i32 main(){").is_ok);
    var usize i=0;while(i<count){assert(bytes::append(ref mut s,b"if(true){").is_ok);i+=1;}assert(bytes::append(ref mut s,b"return 42;").is_ok);
    i=0;while(i<count){assert(bytes::append(ref mut s,b"}else{return 42;}").is_ok);i+=1;}assert(bytes::append(ref mut s,b"}").is_ok);return s;}
@test fn void admitted_32_controls_and_33_error_match_without_stack_overrides(){
    let bytes::Buffer good=nested(32);compare(bytes::view(ref good),true);
    let bytes::Buffer bad=nested(33);compare(bytes::view(ref bad),false);
    // Else-if chains reach the semantic depth guard without first failing the
    // independent signature scan's 33-brace lexical limit.
    var bytes::Buffer chain=bytes::empty();assert(bytes::append(ref mut chain,b"module main;fn i32 main(){").is_ok);
    var usize i=0;while(i<32){assert(bytes::append(ref mut chain,b"if(false){return 0;}else ").is_ok);i+=1;}
    assert(bytes::append(ref mut chain,b"{return 42;}}").is_ok);compare(bytes::view(ref chain),true);
    var bytes::Buffer deeper=bytes::empty();assert(bytes::append(ref mut deeper,b"module main;fn i32 main(){").is_ok);
    i=0;while(i<33){assert(bytes::append(ref mut deeper,b"if(false){return 0;}else ").is_ok);i+=1;}
    assert(bytes::append(ref mut deeper,b"{return 42;}}").is_ok);compare(bytes::view(ref deeper),false);
}

@test fn void pratt_condition_continuations_match_raw_ir_and_short_circuit(){
    compare(b"module main;fn i32 main(){if(20+11*2==42){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 main(){if((20+1)*2==42){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 main(){if(50-12/3*2==42){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 main(){if(false && 40/0==0){return 0;}else{return 42;}}",true);
    compare(b"module main;fn i32 main(){if(true || 40/0==0){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 main(){if(1<2 && 3>=3 || false){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 main(){if(true==false || 42!=0){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 main(){if((1<<4 | 2^3 & 7)==17){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 main(){if((20 as i64)+22==42){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 main(){if(1+true==42){return 42;}else{return 0;}}",false);
    compare(b"module main;fn i32 main(){if(true+false){return 42;}else{return 0;}}",false);
    compare(b"module main;fn i32 main(){if(1 && true){return 42;}else{return 0;}}",false);
    compare(b"module main;fn i32 main(){if(true || 1){return 42;}else{return 0;}}",false);
    compare(b"module main;fn i32 main(){if(1+){return 42;}else{return 0;}}",false);
}

@test fn void annotated_semantics_keep_raw_ir_publication_and_diagnostics(){
    compare(b"module main;fn i32 main(){let i32 x=20+11*2;return x;}",true);
    compare(b"module main;fn i32 main(){var i32 x=42;return x;}",true);
    compare(b"module main;fn i32 main(){let bool b=1<2 && true;if(b){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 main(){let i64 x=20+22;let u8 y=42;let u32 z=42;let usize n=42;return y as i32;}",true);
    compare(b"module main;fn i32 main(){let i32 x=x;return 42;}",false);
    compare(b"module main;fn i32 main(){let i32 x=1;let i32 x=42;return x;}",false);
    compare(b"module main;fn i32 main(){let i32 true=42;return 42;}",false);
    compare(b"module main;fn i32 main(){let i32 x=true;return 42;}",false);
    compare(b"module main;fn i32 main(){let i32 x 42;return 42;}",false);
    compare(b"module main;fn i32 main(){let i32 x=42 return x;}",false);
    compare(b"module main;fn i32 main(){let Option<i64> x=.none;return 42;}",false);
    // Inference and aggregate annotations retain their original semantic child.
    compare(b"module main;fn i32 main(){let x=42;return x;}",true);
}

@test fn void scalar_and_void_returns_preserve_raw_exit_ir_and_special_fallback(){
    compare(b"module main;fn i32 main(){return 20+11*2;}",true);
    compare(b"module main;fn bool yes(){return false && 40/0==0;}fn i32 main(){if(yes()){return 0;}else{return 42;}}",true);
    compare(b"module main;fn void probe(){let i32[2] a=[20,22];return;}fn i32 main(){probe();return 42;}",true);
    compare(b"module main;fn i32 main(){let i32[1] a=[20;1];let i32[1] b=[22;1];return a[0]+b[0];}",true);
    compare(b"module main;fn Result<i32,bool> answer(){return .ok(42);}fn i32 main(){let Result<i32,bool> r=answer();switch(r){case .ok(n):{return n;}case .err(_):{return 0;}}}",true);
    compare(b"module main;fn i32 main(){return true;}",false);
    compare(b"module main;fn i32 main(){return 42 return 1;}",false);
    compare(b"module main;fn i32 main(){return 20+;}",false);
    compare(b"module main;fn void probe(){return 42;}fn i32 main(){probe();return 42;}",false);
}

fn bytes::Buffer declarations(usize count){var bytes::Buffer s=bytes::empty();assert(bytes::append(ref mut s,b"module main;fn i32 main(){").is_ok);
    var usize i=0;while(i<count){assert(bytes::append(ref mut s,b"let i32 ").is_ok);var usize j=0;
        while(j<=i){assert(bytes::append(ref mut s,b"x").is_ok);j+=1;}assert(bytes::append(ref mut s,b"=0;").is_ok);i+=1;}
    assert(bytes::append(ref mut s,b"return 42;}").is_ok);return s;}
@test fn void local_binding_capacity_preserves_raw_error_order(){
    let bytes::Buffer full=declarations(64);compare(bytes::view(ref full),true);
    let bytes::Buffer over=declarations(65);compare(bytes::view(ref over),false);
}

@test fn void grouped_operands_match_raw_ir_and_preserve_postfix_cast_context(){
    compare(b"module main;fn i32 main(){return ((20+1)*2);}",true);
    compare(b"module main;fn i32 main(){let i32 x=((20+11*2));return x;}",true);
    compare(b"module main;fn i32 main(){if((false && 40/0==0) || (20+22==42)){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 main(){let i64 x=(20+22) as i64;return 42;}",true);
    compare(b"module main;fn i32 main(){let Result<i32,bool> r=.ok(1);if((r).is_ok){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 main(){let i32[2] a=[20,22];return (a)[0]+(a)[1];}",true);
    compare(b"module main;fn i32 main(){return ();}",false);
    compare(b"module main;fn i32 main(){return (20+22;}",false);
    compare(b"module main;fn i32 main(){return (true+false);}",false);
    compare(b"module main;fn i32 main(){return (42).nope;}",false);
}

@test fn void scalar_call_operands_preserve_raw_arguments_suffixes_and_errors(){
    compare(b"module main;fn i32 add(i32 a,i32 b){return a+b;}fn i32 main(){return add(add(10,10),(11+11));}",true);
    compare(b"module main;fn i32 zero(){return 42;}fn i32 main(){return ((zero()));}",true);
    compare(b"module main;fn bool yes(){return true;}fn i32 main(){if(false && yes() || yes()){return 42;}else{return 0;}}",true);
    compare(b"module main;fn Result<i32,bool> answer(){return .ok(42);}fn i32 main(){if((answer()).is_ok){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 answer(){return 42;}fn i32 main(){let i64 x=answer() as i64;return 42;}",true);
    compare(b"module main;fn i32 f(i32 n){return n;}fn i32 main(){return f();}",false);
    compare(b"module main;fn i32 f(){return 0;}fn i32 main(){return f(42);}",false);
    compare(b"module main;fn i32 f(i32 n){return n;}fn i32 main(){return f(true);}",false);
    compare(b"module main;fn i32 f(i32 n){return n;}fn i32 main(){return f(42,);}",false);
    compare(b"module main;fn i32 f(i32 n){return n;}fn i32 main(){return f(20 22);}",false);
    compare(b"module main;fn i32 f(i32 n){return n;}fn i32 main(){let i32 f=0;return f(42);}",false);
    compare(b"module main;fn i32 main(){return missing(42);}",false);
}

@test fn void captured_scalar_results_keep_prefix_order_and_lexical_cleanup(){
    captured(b"module main;fn i32 take(i32[1] before,i32 stamp,i32[1] after){return before[0]*10+stamp+after[0];}fn i32 main(){var i32[1] a=[2;1];let Option<i32> o=.none;return take(a,switch(o){case .some(v):{v}case .none:{a[0]=4;18}},a);}",true);
    captured(b"module main;fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){let Option<i32> o=.none;return take([1;1],switch(o){case .some(v):{v}case .none:{return 42;}});}",true);
    captured(b"module main;fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){let i32[1] a=[20;1];return take((a),(11+11));}",true);
    captured(b"module main;fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){var i32[1] a=[20;1];return take(a,take(a,2));}",true);
    captured(b"module main;fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){return take([20;1],(22));}",true);
    captured(b"module main;struct P{i32 x;}fn i32 take(P p,i32 n){return p.x+n;}fn i32 main(){var P p=P{.x=20};return take(p,take(p,2));}",true);
    captured(b"module main;fn i32 take(ref i32[] a,i32 n){return a[0]+n;}fn i32 main(){let i32[1] a=[20;1];return take(ref a[..],22);}",true);
    captured(b"module main;fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){var i32[1] a=[20;1];return take(a,true);}",false);
    captured(b"module main;fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){return take([20;1],);}",false);
    captured(b"module main;fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){let i32[1] a=[20;1];return take(a,22,0);}",false);
}
fn bytes::Buffer nested_calls(usize depth,bool captures){var bytes::Buffer s=bytes::empty();
    if(captures){assert(bytes::append(ref mut s,b"module main;fn i32 id(i32[1] a,i32 n){return n;}fn i32 main(){let i32[1] a=[0;1];return ").is_ok);}
    else{assert(bytes::append(ref mut s,b"module main;fn i32 id(i32 n){return n;}fn i32 main(){return ").is_ok);}
    var usize i=0;while(i<depth){assert(bytes::append(ref mut s,if(captures){b"id(a,"}else{b"id("}).is_ok);i+=1;}
    assert(bytes::append(ref mut s,b"42").is_ok);i=0;while(i<depth){assert(bytes::append(ref mut s,b")").is_ok);i+=1;}
    assert(bytes::append(ref mut s,b";}").is_ok);return s;
}
fn bytes::Buffer mixed_calls(usize count){var bytes::Buffer s=bytes::empty();assert(bytes::append(ref mut s,b"module main;fn i32 id(i32 n){return n;}fn i32 main(){return ").is_ok);
    var usize i=0;while(i<count){assert(bytes::append(ref mut s,b"(id(").is_ok);i+=1;}assert(bytes::append(ref mut s,b"42").is_ok);
    i=0;while(i<count){assert(bytes::append(ref mut s,b"))").is_ok);i+=1;}assert(bytes::append(ref mut s,b";}").is_ok);return s;}
@test fn void nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics(){
    let bytes::Buffer mixed=mixed_calls(16);compare(bytes::view(ref mixed),true);
    let bytes::Buffer deeper=mixed_calls(17);compare(bytes::view(ref deeper),false);
    let bytes::Buffer plain=nested_calls(32,false);compare(bytes::view(ref plain),true);
    let bytes::Buffer deep=nested_calls(33,false);compare(bytes::view(ref deep),false);
    let bytes::Buffer capture=nested_calls(32,true);captured(bytes::view(ref capture),true);
    let bytes::Buffer over=nested_calls(33,true);captured(bytes::view(ref over),false);
}

@test fn void call_arity_and_site_capacity_keep_original_error_order(){
    compare(b"module main;fn i32 f(i32 a,i32 b,i32 c,i32 d,i32 e,i32 f,i32 g,i32 h){return a+b+c+d+e+f+g+h;}fn i32 main(){return f(1,2,3,4,5,6,7,14);}",true);
    compare(b"module main;fn i32 f(i32 a,i32 b,i32 c,i32 d,i32 e,i32 f,i32 g,i32 h){return a;}fn i32 main(){return f(1,2,3,4,5,6,7,8,9);}",false);
    var bytes::Buffer s=bytes::empty();assert(bytes::append(ref mut s,b"module main;fn i32 z(){return 0;}fn i32 main(){return ").is_ok);
    var usize i=0;while(i<32){assert(bytes::append(ref mut s,b"z()+").is_ok);i+=1;}assert(bytes::append(ref mut s,b"42;}").is_ok);compare(bytes::view(ref s),true);
    var bytes::Buffer over=bytes::empty();assert(bytes::append(ref mut over,b"module main;fn i32 z(){return 0;}fn i32 main(){return ").is_ok);
    i=0;while(i<33){assert(bytes::append(ref mut over,b"z()+").is_ok);i+=1;}assert(bytes::append(ref mut over,b"42;}").is_ok);compare(bytes::view(ref over),false);
}

@test fn void unary_operands_keep_raw_precedence_context_minima_and_errors(){
    compare(b"module main;fn i32 main(){return -20+62;}",true);
    compare(b"module main;fn i32 main(){return ~(-43);}",true);
    compare(b"module main;fn i32 main(){if(!!!false && !!true){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 id(i32 n){return n;}fn i32 main(){return -id(-42);}",true);
    compare(b"module main;fn i32 main(){let i64 x=-42 as i64;if(x== -42){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 main(){let u8 x=~0;if(x==255){return 42;}else{return 0;}}",true);
    compare(b"module main;fn i32 main(){let i32 x=-2147483648;let i64 y=-9223372036854775808;return 42;}",true);
    compare(b"module main;fn i32 main(){let i64 x=-2147483648;return 42;}",true);
    compare(b"module main;fn i32 main(){let i32 x= - -42;return x;}",true);
    compare(b"module main;fn i32 main(){let Result<i32,bool> r=.ok(1);if(!r.is_ok){return 0;}else{return 42;}}",true);
    compare(b"module main;fn i32 main(){return -true;}",false);
    compare(b"module main;fn i32 main(){return !42;}",false);
    compare(b"module main;fn i32 main(){return ~true;}",false);
    compare(b"module main;fn i32 main(){let u8 x=-1;return 42;}",false);
    compare(b"module main;fn i32 main(){return -9223372036854775808;}",false);
    compare(b"module main;fn i32 main(){return -;}",false);
    compare(b"module main;fn i32 main(){return -42.nope;}",false);
    compare(b"module main;fn i32 main(){let u8 x=1;let i64 y=-x as i64;return 42;}",false);
    compare(b"module main;fn i32 main(){let i64 x=-9223372036854775808 as i64;return 42;}",false);
    compare(b"module main;fn i32 main(){return -2147483648.nope;}",false);
}

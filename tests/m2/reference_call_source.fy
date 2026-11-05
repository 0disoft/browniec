module tests::m2::reference_call_source;
import compiler as compiler;
import program_image as programs;
import static_image as images;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_owners as owners;
import array_slices as slices;
import errors as errors;

// These cases target the private source -> retained ReferenceProgram -> scalar
// VM path. They assume compile_references keeps program_image::Error: lowering
// errors are .Code and literal-image failures are .Literal. Fuel boundaries are
// measured from one wide invocation rather than copied from an independent
// implementation oracle. Guest backing and source snippets stay deliberately
// small, and unsupported generic-result text/equality operations are not used.
fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0);
    assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
fn Result<execution::Scalar,errors::Error> run(ref programs::ReferenceProgram program,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let usize entry=programs::reference_code(program).body.entry;
    return programs::run_reference_scalar(program,entry,ref captures[..0],ref values[..0],
        ref inputs[..0],state,data,fuel);
}
// Every attempt owns a fresh native state and guest arena. The state is fully
// drained before the scalar result or error is returned to a test.
fn Result<execution::Scalar,errors::Error> attempt(ref programs::ReferenceProgram program,usize fuel){
    var runtime::State state=runtime::empty(64);var u8[64] data=[99;64];
    let Result<execution::Scalar,errors::Error> result=run(program,ref mut state,ref mut data,fuel);
    drained(ref state);return result;
}
fn void exercise(ref u8[] source,i64 expected){
    let programs::ReferenceProgram program=switch(compiler::compile_references(source,8192)){
        case .ok(value):{value}
        case .err(_):{assert(false);return;}
    };
    let usize allowance=16000000;var usize required=0;
    switch(attempt(ref program,allowance)){
        case .ok(value):{assert(value.value==expected);required=allowance-value.remaining;}
        case .err(_):{assert(false);return;}
    };
    switch(attempt(ref program,required-1)){
        case .ok(_):{assert(false);}case .err(error):{assert(error.kind==8);}
    };
    switch(attempt(ref program,required)){
        case .ok(value):{assert(value.value==expected && value.remaining==0);}
        case .err(_):{assert(false);}
    };
    switch(attempt(ref program,required+1)){
        case .ok(value):{assert(value.value==expected && value.remaining==1);}
        case .err(_):{assert(false);}
    };
}

@test fn void image_and_runtime_values_keep_distinct_backings(){
    exercise(b"module main;fn i32 read(ref u8[] p){return p[0] as i32;}fn i32 main(){let u8[1] a=[24;1];let i32 image=read(ref b\"\\x2a\");let i32 runtime=read(ref a);if(image==42 && runtime==24){return 42;}return 0;}",42);
}

@test fn void named_narrowed_forwarded_empty_and_text_bytes_values(){
    exercise(b"module main;fn i32 first(ref u8[] p){return p[0] as i32;}fn usize length(ref u8[] p){return p.len;}fn i32 forward(ref u8[] p){return first(ref p);}fn i32 main(){let u8[3] a=[20;3];let ref u8[] named=ref a;let i32 narrow=forward(ref named[1..3]);let i32 text=first(ref text::bytes(\"*\"));let usize empty=length(ref b\"\");if(narrow==20 && text==42 && empty==0){return 42;}return 0;}",42);
}

@test fn void scalar_prefixes_and_eight_actual_reference_calls(){
    exercise(b"module main;fn i32 all(ref u8[] a,ref u8[] b,ref u8[] c,ref u8[] d,ref u8[] e,ref u8[] f,ref u8[] g,ref u8[] h){return (a[0] as i32)+(b[0] as i32)+(c[0] as i32)+(d[0] as i32)+(e[0] as i32)+(f[0] as i32)+(g[0] as i32)+(h[0] as i32);}fn i32 main(){return all(ref b\"\\x01\",ref b\"\\x02\",ref b\"\\x03\",ref b\"\\x04\",ref b\"\\x05\",ref b\"\\x06\",ref b\"\\x07\",ref b\"\\x0e\");}",42);
    exercise(b"module main;fn i32 prefixed(i32 marker,ref u8[] a,ref u8[] b,ref u8[] c,ref u8[] d,ref u8[] e,ref u8[] f,ref u8[] g){if(marker!=14){return 0;}return marker+(a[0] as i32)+(b[0] as i32)+(c[0] as i32)+(d[0] as i32)+(e[0] as i32)+(f[0] as i32)+(g[0] as i32);}fn i32 main(){return prefixed(14,ref b\"\\x01\",ref b\"\\x02\",ref b\"\\x03\",ref b\"\\x04\",ref b\"\\x05\",ref b\"\\x06\",ref b\"\\x07\");}",42);
}

@test fn void shared_formals_coexist_with_mutable_owned_and_record_arguments(){
    exercise(b"module main;struct P{i32 x;}fn i32 mix(ref u8[] p,ref mut u8[] q,ref i32[] nums,P r,i32[1] a){q[0]=20;return (p[0] as i32)+(q[0] as i32)+nums[0]+r.x+a[0];}fn i32 main(){var u8[1] q=[1;1];let i32[1] nums=[6;1];let P r=P{.x=2};let i32[1] a=[10;1];if(mix(ref b\"\\x04\",ref mut q,ref nums,r,a)==42){return 42;}return 0;}",42);
}

@test fn void arguments_and_endpoints_evaluate_left_to_right_with_early_exit_cleanup(){
    exercise(b"module main;fn i32 choose(i32 a,i32 b,ref u8[] p){return a*10+b+(p[0] as i32);}fn i32 main(){var i32 n=0;let Option<i32> o=.none;var u8[3] a=[10;3];a[1]=20;a[2]=30;let ref u8[] part=ref a[switch(o){case .some(v):{0}case .none:{n=n*10+1;0}}..switch(o){case .some(v):{2}case .none:{n=n*10+2;2}}];let i32 x=choose(switch(o){case .some(v):{0}case .none:{n=n*10+3;1}},switch(o){case .some(v):{0}case .none:{n=n*10+4;2}},ref part);if(n==1234 && part.len==2 && part[0]==10 && part[1]==20 && x==22){return 42;}return 0;}",42);
    // The shared range is acquired before the later scalar endpoint returns.
    exercise(b"module main;fn i32 use(i32 marker,ref u8[] p,usize stop){return p[0] as i32;}fn i32 main(){let u8[3] a=[42;3];let Option<i32> o=.none;return use(0,ref a[0..2],switch(o){case .some(v):{1}case .none:{return 42;}});}",42);
}

@test fn void measured_fuel_distinguishes_one_short_exact_and_one_more(){
    // exercise derives the exact whole-invocation cost from a wide first run,
    // then checks short/exact/surplus runs with fresh and fully drained states.
    exercise(b"module main;fn i32 read(ref u8[] p){return p[0] as i32;}fn i32 main(){let u8[1] a=[24;1];return read(ref b\"\\x2a\")+read(ref a)-24;}",42);
}

fn void rejected(ref u8[] source){
    switch(compiler::compile_references(source,8192)){
        case .ok(_):{assert(false);}
        case .err(error):{switch(error.kind){
            case .Code:{assert(error.code.kind==3);}case .Literal:{assert(false);}
        }}
    };
}
@test fn void type_access_arity_origin_and_generic_result_mismatches_reject(){
    rejected(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){return f(ref \"*\");}");
    rejected(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){return f(ref b\"*\"[0]);}");
    rejected(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){var u8[1] a=[1;1];return f(ref mut a);}");
    rejected(b"module main;fn i32 f(ref u8[] p,ref u8[] q){return 42;}fn i32 main(){return f(ref b\"*\");}");
    rejected(b"module main;fn i32 f(ref mut u8[] p){p[0]=0;return 42;}fn i32 main(){return f(ref mut b\"*\");}");
    rejected(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){return 42;}");
}

fn usize charge(ref programs::ReferenceProgram program){
    return switch(images::charge(programs::reference_literals(program))){
        case .ok(value):{value}case .err(_):{assert(false);0}
    };
}
fn bool quota(images::Error error){return switch(error){
    case .Quota:{true}case .State:{false}case .Limit:{false}case .Literals:{false}
    case .Utf8:{false}case .Kind:{false}case .Bounds:{false}case .Allocation:{false}case .Provider:{false}
};}
fn void closed(ref u8[] source){
    switch(compiler::compile(source)){
        case .ok(_):{assert(false);}case .err(error):{assert(error.kind==3);}
    };
    switch(compiler::compile_image(source,8192)){
        case .ok(_):{assert(false);}
        case .err(error):{switch(error.kind){
            case .Code:{assert(error.code.kind==3);}case .Literal:{assert(false);}
        }}
    };
}
@test fn void retained_state_quota_fuel_bounds_and_legacy_gates(){
    let ref u8[] source=b"module main;fn i32 read(ref u8[] p){return p[0] as i32;}fn i32 main(){return read(ref b\"*\");}";
    var u8[128] copy=[0;128];assert(source.len<=128);var usize i=0;
    while(i<source.len){copy[i]=source[i];i+=1;}
    let programs::ReferenceProgram retained=switch(compiler::compile_references(ref copy[..source.len],8192)){
        case .ok(value):{value}case .err(_):{assert(false);return;}
    };
    copy[0]=0;copy[source.len-1]=0;
    switch(attempt(ref retained,16000000)){
        case .ok(value):{assert(value.value==42);}case .err(_):{assert(false);}
    };
    let usize required=charge(ref retained);
    switch(compiler::compile_references(source,required-1)){
        case .ok(_):{assert(false);}
        case .err(error):{switch(error.kind){
            case .Code:{assert(false);}case .Literal:{assert(quota(error.literal));}
        }}
    };
    switch(compiler::compile_references(source,required)){
        case .ok(_):{}case .err(_):{assert(false);}
    };
    switch(compiler::compile_references(source,required+1)){
        case .ok(_):{}case .err(_):{assert(false);}
    };
    let programs::ReferenceProgram bounds=switch(compiler::compile_references(
        b"module main;fn i32 read(ref u8[] p){return p[0] as i32;}fn i32 main(){return read(ref b\"\");}",8192)){
        case .ok(value):{value}case .err(_):{assert(false);return;}
    };
    switch(attempt(ref bounds,16000000)){
        case .ok(_):{assert(false);}case .err(error):{assert(error.kind==14);}
    };
    exercise(source,42);
    closed(source);
    closed(b"module main;fn i32 read(ref u8[] p){return p[0] as i32;}fn i32 main(){return read(ref text::bytes(\"*\"));}");
}

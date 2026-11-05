module tests::m2::reference_return_source;
import compiler as compiler;
import program_image as programs;
import static_image as images;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_owners as owners;
import array_slices as slices;
import errors as errors;

// These cases drive source through compile_reference_returns and the retained
// ReferenceReturnProgram native VM. Every execution starts with fresh native
// state. Guest backing is deliberately small, and successful sources are
// measured from a wide run before fresh short/exact/surplus executions.
fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0);
    assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}

fn Result<execution::Scalar,errors::Error> run(ref programs::ReferenceReturnProgram program,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let usize entry=programs::reference_return_code(program).body.entry;
    return programs::run_reference_returns_scalar(program,entry,ref captures[..0],ref values[..0],
        ref inputs[..0],state,data,fuel);
}

// Each attempt owns a fresh native state and guest arena and drains both before
// exposing the scalar result or error to the test.
fn Result<execution::Scalar,errors::Error> attempt(ref programs::ReferenceReturnProgram program,usize fuel){
    var runtime::State state=runtime::empty(64);var u8[64] data=[99;64];
    let Result<execution::Scalar,errors::Error> result=run(program,ref mut state,ref mut data,fuel);
    drained(ref state);return result;
}

fn void verify(ref programs::ReferenceReturnProgram program,i64 expected){
    let usize allowance=16000000;var usize required=0;
    switch(attempt(program,allowance)){
        case .ok(value):{assert(value.value==expected);required=allowance-value.remaining;}
        case .err(_):{assert(false);return;}
    };
    switch(attempt(program,required-1)){
        case .ok(_):{assert(false);}case .err(error):{assert(error.kind==8);}
    };
    switch(attempt(program,required)){
        case .ok(value):{assert(value.value==expected && value.remaining==0);}
        case .err(_):{assert(false);}
    };
    switch(attempt(program,required+1)){
        case .ok(value):{assert(value.value==expected && value.remaining==1);}
        case .err(_):{assert(false);}
    };
}

fn void exercise(ref u8[] source,i64 expected){
    let programs::ReferenceReturnProgram program=switch(compiler::compile_reference_returns(source,8192)){
        case .ok(value):{value}case .err(_):{assert(false);return;}
    };
    verify(ref program,expected);
}

fn bool quota(images::Error error){return switch(error){
    case .Quota:{true}case .State:{false}case .Limit:{false}case .Literals:{false}
    case .Utf8:{false}case .Kind:{false}case .Bounds:{false}case .Allocation:{false}case .Provider:{false}
};}

fn usize charge(ref programs::ReferenceReturnProgram program){
    return switch(images::charge(programs::reference_return_literals(program))){
        case .ok(value):{value}case .err(_):{assert(false);0}
    };
}

fn void image_quota(ref u8[] source){
    let programs::ReferenceReturnProgram program=switch(compiler::compile_reference_returns(source,8192)){
        case .ok(value):{value}case .err(_):{assert(false);return;}
    };
    let usize required=charge(ref program);
    switch(compiler::compile_reference_returns(source,required-1)){
        case .ok(_):{assert(false);}
        case .err(error):{let bool literal=switch(error.kind){
            case .Literal:{quota(error.literal)}case .Code:{false}
        };assert(literal);}
    };
    switch(compiler::compile_reference_returns(source,required)){
        case .ok(_):{}case .err(_):{assert(false);}
    };
    switch(compiler::compile_reference_returns(source,required+1)){
        case .ok(_):{}case .err(_):{assert(false);}
    };
    verify(ref program,42);
}

fn void failed(ref programs::ReferenceReturnProgram program,u8 kind){
    switch(attempt(program,16000000)){
        case .ok(_):{assert(false);}case .err(error):{assert(error.kind==kind);}
    };
}

fn void rejected(ref u8[] source){
    switch(compiler::compile_reference_returns(source,8192)){
        case .ok(_):{assert(false);}case .err(_):{}
    };
}

fn void closed(ref u8[] source){
    assert(!compiler::compile(source).is_ok);
    assert(!compiler::compile_image(source,8192).is_ok);
    assert(!compiler::compile_references(source,8192).is_ok);
}

@test fn void image_and_owned_runtime_arrays_use_the_same_returned_signature(){
    exercise(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn ref u8[] literal(){return b\"*\";}fn i32 main(){var u8[1] a=[0;1];a[0]=24;let ref u8[] image=same(ref b\"*\");let ref u8[] runtime=same(ref a);let ref u8[] bare=literal();if(image[0]==42 && runtime[0]==24 && bare[0]==42 && literal().len==1){return 42;}return 0;}",42);
}

@test fn void returned_aliases_narrowed_and_empty_windows_support_read_and_length(){
    exercise(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[4] a=[0;4];a[0]=20;a[1]=20;a[2]=22;let ref u8[] p=same(ref a[1..3]);let ref u8[] q=ref p;let ref u8[] empty=same(ref a[4..]);if(q.len==2 && q[0]==20 && q[1]==22 && empty.len==0 && same(ref a[0..1])[0]==20 && same(ref a[4..]).len==0){return 42;}return 0;}",42);
}

@test fn void selected_temporary_owner_survives_an_unselected_mutable_argument_mutation(){
    exercise(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn ref u8[] pick(ref u8[] a,ref u8[] b){return ref a;}fn i32 main(){let ref u8[] p=same(ref [42;3]);let ref u8[] alias=ref p;var u8[2] selected=[0;2];selected[0]=42;var u8[2] unused=[0;2];let ref u8[] kept=pick(ref selected,ref unused);unused[0]=7;if(alias[1]==42 && alias.len==3 && kept[0]==42 && unused[0]==7){return 42;}return 0;}",42);
}

@test fn void nested_returned_actuals_ranges_and_temporary_lexical_cleanup(){
    exercise(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn ref u8[] pick(ref u8[] a,ref u8[] b){return ref b;}fn ref u8[] nested(ref u8[] a,ref u8[] b){return pick(ref a,ref pick(ref b,ref a));}fn i32 main(){let ref u8[] p=nested(ref [42;3],ref b\"*\");var i32 value=0;{let ref u8[] q=pick(ref b\"!\",ref id(ref p[1..3]));value=(q[0] as i32)+(q[1] as i32);}let i32 immediate=nested(ref [42;2],ref b\"!\")[1] as i32;if(p[0]==42 && p[2]==42 && value==84 && immediate==42){return 42;}return 0;}",42);
}

@test fn void agreeing_branches_forwarding_and_grounded_recursion_reject_conflicts_and_cycles(){
    exercise(b"module main;fn ref u8[] branch(ref u8[] p,bool b){if(b){return ref p[1..];}return ref p[..];}fn i32 main(){let ref u8[] a=branch(ref [42;3],true);if(a.len==2){return a[0] as i32;}return 0;}",42);
    exercise(b"module main;fn ref u8[] pick(ref u8[] a,ref u8[] b){return ref b;}fn ref u8[] forward(ref u8[] a,ref u8[] b){return pick(ref a,ref pick(ref b,ref a));}fn i32 main(){return forward(ref [42;2],ref b\"!\")[0] as i32;}",42);
    exercise(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn ref u8[] rec(ref u8[] p,i32 n){if(n==0){return ref p;}return rec(ref id(ref p),n-1);}fn i32 main(){return rec(ref [42;2],3)[1] as i32;}",42);
    rejected(b"module main;fn ref u8[] f(ref u8[] p,ref u8[] q,bool b){if(b){return ref p;}return ref q;}fn i32 main(){return 0;}");
    rejected(b"module main;fn ref u8[] f(ref u8[] p,bool b){if(b){return ref p;}return b\"*\";}fn i32 main(){return 0;}");
    rejected(b"module main;fn ref u8[] f(ref u8[] p){return f(ref p);}fn i32 main(){return 0;}");
}

@test fn void selected_temporaries_cleanup_across_return_propagation_break_continue_and_later_arguments(){
    exercise(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let Option<i32> o=.none;let ref u8[] p=same(ref [42;3])[0..switch(o){case .some(v):{1}case .none:{return 42;}}];return 0;}",42);
    exercise(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn Option<i32> make(Option<i32> o){let ref u8[] p=same(ref [42;2])[0..switch(o){case .some(v):{1}case .none:{let i32 n=o?;1}}];return .some(p[0] as i32);}fn i32 main(){switch(make(.none)){case .some(_):{return 0;}case .none:{}}switch(make(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",42);
    exercise(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let Option<i32> o=.none;var i32 n=0;while(n<2){let ref u8[] q=same(ref [33;2])[0..switch(o){case .some(v):{1}case .none:{n=n+1;continue;}}];}while(true){let ref u8[] q=same(ref [33;2])[switch(o){case .some(v):{0}case .none:{break;}}..];}return 42;}",42);
    exercise(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 use(i32 marker,ref u8[] p,usize stop){return marker+(p[0] as i32);}fn i32 main(){let Option<i32> o=.none;let ref u8[] p=same(ref [42;3])[0..2];return use(0,ref p,switch(o){case .some(v):{1}case .none:{return 42;}});}",42);
}

@test fn void fuel_image_quota_and_bounds_boundaries_drain_fresh_runtime_state(){
    exercise(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let ref u8[] p=same(ref b\"*\");return p[0] as i32;}",42);
    image_quota(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let ref u8[] p=same(ref b\"*\");return p[0] as i32;}");
    let programs::ReferenceReturnProgram bounds=switch(compiler::compile_reference_returns(
        b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let ref u8[] p=same(ref b\"\");return p[0] as i32;}",8192)){
        case .ok(value):{value}case .err(_):{assert(false);return;}
    };
    failed(ref bounds,14);
}

@test fn void old_entries_reject_returned_declarations_and_retained_source_is_immutable(){
    let ref u8[] source=b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let ref u8[] p=same(ref [42;3]);return p[0] as i32;}";
    closed(source);
    rejected(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){return 0;}");
    rejected(b"module main;fn ref mut u8[] f(ref mut u8[] p){return ref mut p;}fn i32 main(){return 0;}");
    rejected(b"module main;fn ref u8[] f(){let u8[1] a=[42;1];return ref a;}fn i32 main(){return 0;}");
    var u8[160] copy=[0;160];assert(source.len<=160);var usize i=0;
    while(i<source.len){copy[i]=source[i];i+=1;}
    let programs::ReferenceReturnProgram retained=switch(compiler::compile_reference_returns(ref copy[..source.len],8192)){
        case .ok(value):{value}case .err(_):{assert(false);return;}
    };
    copy[0]=0;copy[source.len-1]=0;
    verify(ref retained,42);
}

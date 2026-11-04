module tests::m2::slice_result_call_execution;
import compiler as compiler;
import slice_result_ir as ir;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_owners as owners;
import array_slices as slices;
import vm as vm;
import errors as errors;
import ir as ordinary;
import array_layout as layout;
import render as render;

fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
@effects(console)
fn Result<usize,errors::Error> completed(ref ir::Program unit,i64 expected,usize fuel){
    var runtime::State state=runtime::empty(256);var u8[256] data=[0;256];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let execution::Scalar result=switch(vm::run_slice_scalar(unit,unit.body.entry,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,fuel)){
        case .ok(v):{v}case .err(e):{let i32 printed=render::outcome(true,true,true,0,e);return .err(e);}
    };
    assert(result.value==expected);drained(ref state);return .ok(result.remaining);
}
@effects(console)
fn Result<usize,errors::Error> run(ref u8[] source,i64 expected,usize fuel){
    let ir::Program unit=compiler::inspect_slice_result_ir(source)?;
    assert(!compiler::compile(source).is_ok);return completed(ref unit,expected,fuel);
}
@effects(console)
@test
fn void shared_and_exclusive_results_execute_all_six_scalar_types(){
    assert(run(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){let i32[2] a=[42;2];let ref i32[] r=f(ref a);if(r[0]==42){return 42;}return 0;}",42,1000000).is_ok);
    assert(run(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] r=f(ref mut a);r[0]=42;if(r[0]==42){return 42;}return 0;}",42,1000000).is_ok);
    assert(run(b"module main;fn ref bool[] f(ref bool[] p){return ref p;}fn i32 main(){let bool[2] a=[true;2];let ref bool[] r=f(ref a);if(r[0]==true){return 42;}return 0;}",42,1000000).is_ok);
    assert(run(b"module main;fn ref mut bool[] f(ref mut bool[] p){return ref mut p;}fn i32 main(){var bool[2] a=[false;2];let ref mut bool[] r=f(ref mut a);r[0]=true;if(r[0]==true){return 42;}return 0;}",42,1000000).is_ok);
    assert(run(b"module main;fn ref i64[] f(ref i64[] p){return ref p;}fn i32 main(){let i64[2] a=[42;2];let ref i64[] r=f(ref a);if(r[0]==42){return 42;}return 0;}",42,1000000).is_ok);
    assert(run(b"module main;fn ref mut i64[] f(ref mut i64[] p){return ref mut p;}fn i32 main(){var i64[2] a=[0;2];let ref mut i64[] r=f(ref mut a);r[0]=42;if(r[0]==42){return 42;}return 0;}",42,1000000).is_ok);
    assert(run(b"module main;fn ref u8[] f(ref u8[] p){return ref p;}fn i32 main(){let u8[2] a=[42;2];let ref u8[] r=f(ref a);if(r[0]==42){return 42;}return 0;}",42,1000000).is_ok);
    assert(run(b"module main;fn ref mut u8[] f(ref mut u8[] p){return ref mut p;}fn i32 main(){var u8[2] a=[0;2];let ref mut u8[] r=f(ref mut a);r[0]=42;if(r[0]==42){return 42;}return 0;}",42,1000000).is_ok);
    assert(run(b"module main;fn ref u32[] f(ref u32[] p){return ref p;}fn i32 main(){let u32[2] a=[42;2];let ref u32[] r=f(ref a);if(r[0]==42){return 42;}return 0;}",42,1000000).is_ok);
    assert(run(b"module main;fn ref mut u32[] f(ref mut u32[] p){return ref mut p;}fn i32 main(){var u32[2] a=[0;2];let ref mut u32[] r=f(ref mut a);r[0]=42;if(r[0]==42){return 42;}return 0;}",42,1000000).is_ok);
    assert(run(b"module main;fn ref usize[] f(ref usize[] p){return ref p;}fn i32 main(){let usize[2] a=[42;2];let ref usize[] r=f(ref a);if(r[0]==42){return 42;}return 0;}",42,1000000).is_ok);
    assert(run(b"module main;fn ref mut usize[] f(ref mut usize[] p){return ref mut p;}fn i32 main(){var usize[2] a=[0;2];let ref mut usize[] r=f(ref mut a);r[0]=42;if(r[0]==42){return 42;}return 0;}",42,1000000).is_ok);
}
@effects(console)
@test
fn void ended_anonymous_captures_restore_both_parents_and_actual_ranges(){
    assert(run(b"module main;fn ref mut i32[] f(i32 n,ref mut i32[] a,ref mut i32[] b){return ref mut b[1..];}fn i32 main(){var i32[3] a=[1;3];var i32[3] b=[0;3];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut b;{let ref mut i32[] r=f(0,ref mut p[..],ref mut q[..]);r[0]=41;let i32 n=p[0];}return p[0]+q[1];}",42,10000000).is_ok);
    assert(run(b"module main;fn ref i32[] f(ref i32[] p){return ref p[1..];}fn i32 main(){let i32[4] a=[42;4];let ref i32[] p=ref a;{let ref i32[] r=f(ref p[1..]);if(r.len!=2){return 1;}}return p[0];}",42,10000000).is_ok);
}
@effects(console)
@test
fn void selected_temporary_owners_and_unselected_copies_clean_up_exactly_once(){
    assert(run(b"module main;fn ref i32[] f(ref i32[] a,ref i32[] b){return ref b;}fn i32 main(){let ref i32[] r=f(ref [1;2],ref [42;2]);return r[0];}",42,1000000).is_ok);
    assert(run(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){let ref mut i32[] r=f(ref mut [0;2]);r[0]=42;return r[0];}",42,1000000).is_ok);
    assert(run(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32[3] make(){return [42;3];}fn i32 main(){let ref i32[] r=f(ref make()[1..]);return r[0];}",42,10000000).is_ok);
    assert(run(b"module main;struct P{i32 x;}fn ref i32[] f(P p,i32[2] a,ref i32[] b){return ref b;}fn i32 main(){let ref i32[] r=f(P{.x=1},[2;2],ref [42;2]);return r[0];}",42,10000000).is_ok);
}
@effects(console)
@test
fn void nested_results_aliases_and_recursive_forwarding_preserve_generations(){
    assert(run(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){var i32[3] a=[0;3];let ref mut i32[] p=ref mut a;{let ref mut i32[] r=f(ref mut p);{let ref mut i32[] s=ref mut r[1..];let ref mut i32[] w=f(ref mut s);w[0]=42;}}return p[1];}",42,10000000).is_ok);
    assert(run(b"module main;fn ref mut i32[] f(ref mut i32[] p,i32 n){if(n==0){return ref mut p;}let ref mut i32[] r=f(ref mut p,n-1);return ref mut r;}fn i32 main(){var i32[2] a=[0;2];{let ref mut i32[] r=f(ref mut a,3);r[0]=42;}return a[0];}",42,10000000).is_ok);
    assert(run(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q){let ref i32[] r=g(ref q,ref p);let ref i32[] s=ref r;return ref s;}fn ref i32[] g(ref i32[] a,ref i32[] b){return ref b;}fn i32 main(){let ref i32[] r=f(ref [42;2],ref [1;2]);return r[0];}",42,10000000).is_ok);
}
fn void fuel_trap(ref ir::Program unit,usize fuel,bool wrote){
    var runtime::State state=runtime::empty(256);var u8[256] data=[0;256];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    switch(vm::run_slice_scalar(unit,unit.body.entry,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,fuel)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}
    };drained(ref state);assert(data[0]==if(wrote){42}else{0});
}
@effects(console)
@test
fn void exact_fuel_succeeds_one_short_drains_and_initial_short_preserves_bytes(){
    let ir::Program unit=switch(compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){p[0]=42;return ref mut p;}fn i32 main(){let ref mut i32[] r=f(ref mut [0;2]);return r[0];}")){
        case .ok(v):{v}case .err(_):{assert(false);ir::Program{.body=ordinary::empty(),.elements=[0;16],.parameters=[0;16]}}
    };
    let usize remaining=switch(completed(ref unit,42,1000000)){case .ok(v):{v}case .err(_):{assert(false);0}};
    let usize used=1000000-remaining;assert(used>0 && used<1000000);
    switch(completed(ref unit,42,used)){case .ok(v):{assert(v==0);}case .err(_):{assert(false);}};
    fuel_trap(ref unit,used-1,true);fuel_trap(ref unit,0,false);
}
fn void execution_trap(ref ir::Program unit){
    var runtime::State state=runtime::empty(256);var u8[256] data=[0;256];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    switch(vm::run_slice_scalar(unit,unit.body.entry,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,1000000)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==14);}
    };drained(ref state);assert(data[0]==42);
}
@test
fn void failure_after_borrowed_result_retains_prior_writes_and_drains_hidden_owners(){
    let ir::Program unit=switch(compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){p[0]=42;return ref mut p;}fn i32 main(){let ref mut i32[] r=f(ref mut [0;2]);return r[2];}")){
        case .ok(v):{v}case .err(_):{assert(false);ir::Program{.body=ordinary::empty(),.elements=[0;16],.parameters=[0;16]}}
    };execution_trap(ref unit);
}

struct Inputs { slices::Ticket parent; owners::Token value; }
fn Inputs opened_inputs(ref mut runtime::State state,ref mut u8[] data){
    let layout::Array shape=switch(layout::scalar(1,2)){case .ok(v):{v}case .err(_):{assert(false);layout::Array{.element=1,.length=2,.stride=4,.alignment=4,.bytes=8}}};
    let owners::Token parent=switch(owners::create(ref shape,0,data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    let owners::Token value=switch(owners::create(ref shape,42,data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket ticket=switch(slices::open_exclusive(ref mut pool,ref mut table,parent,0,2,data.len)){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};
    state.runtime.pool=pool;state.runtime.owners=table;return Inputs{.parent=ticket,.value=value};
}
fn Result<usize,errors::Error> returned_owned(ref ir::Program unit){
    var runtime::State state=runtime::empty(64);var u8[64] data=[0;64];let Inputs input=opened_inputs(ref mut state,ref mut data);
    let runtime::Capture[2] captures=[runtime::capture(input.parent,true,true),runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[2] values=[0,0];let owners::Token[2] inputs=[owners::Token{.slot=0,.generation=0},input.value];
    var runtime::Returned result=vm::run_slice_result_owned(unit,0,ref captures,ref values,ref inputs,ref mut state,ref mut data,10000000)?;
    let slices::Ticket current=result.held.issued;
    switch(slices::length(ref state.runtime.pool,current,ref state.runtime.owners,data.len)){case .ok(n):{assert(n==1);}case .err(_):{assert(false);}};
    assert(data[4]==42 && data[8]==42 && !slices::length(ref state.runtime.pool,input.parent,ref state.runtime.owners,data.len).is_ok);
    let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,data.len,0)?;assert(closed.remaining==0);
    assert(owners::view(ref state.runtime.owners,input.value,0,2,data.len).is_ok);
    let usize cleared=runtime::abort(ref mut state,data.len,0)?;drained(ref state);return .ok(0);
}
@test
fn void native_owned_entry_can_return_bound_subviews_and_close_at_zero_fuel(){
    let ir::Program unit=switch(compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p,i32[2] x){let ref mut i32[] r=g(ref mut p[1..]);r[0]=x[0];return ref mut r;}fn ref mut i32[] g(ref mut i32[] p){return ref mut p;}fn i32 main(){return 0;}")){
        case .ok(v):{v}case .err(_):{assert(false);ir::Program{.body=ordinary::empty(),.elements=[0;16],.parameters=[0;16]}}
    };assert(returned_owned(ref unit).is_ok);
}

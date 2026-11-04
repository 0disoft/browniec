module tests::m2::slice_result_projections;
import compiler as compiler;
import slice_result_ir as ir;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_owners as owners;
import array_slices as slices;
import vm as vm;
import errors as errors;
import render as render;

fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
@effects(console)
fn Result<usize,errors::Error> execute(ref ir::Program unit,usize fuel,u8 error,bool wrote){
    var runtime::State state=runtime::empty(256);var u8[256] data=[0;256];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let usize remaining=switch(vm::run_slice_scalar(unit,unit.body.entry,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,fuel)){
        case .ok(v):{assert(error==0 && v.value==42);v.remaining}
        case .err(e):{if(error!=e.kind){let i32 printed=render::outcome(true,true,true,0,e);}assert(e.kind==error);0}
    };
    drained(ref state);if(wrote){assert(data[0]==42);}return .ok(remaining);
}
@effects(console)
fn Result<usize,errors::Error> run(ref u8[] source){
    let ir::Program unit=compiler::inspect_slice_result_ir(source)?;
    assert(!compiler::compile(source).is_ok);return execute(ref unit,16000000,0,false);
}
@effects(console)
@test fn void shared_and_exclusive_calls_project_all_six_scalar_types(){
    assert(run(b"module main;fn ref i32[] view(ref i32[] p){return ref p;}fn i32 main(){let i32[2] a=[42;2];if(view(ref a)[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut i32[] view(ref mut i32[] p){p[0]=42;return ref mut p;}fn i32 main(){var i32[2] a=[0;2];if(view(ref mut a)[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref bool[] view(ref bool[] p){return ref p;}fn i32 main(){let bool[2] a=[true;2];if(view(ref a)[0]==true){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut bool[] view(ref mut bool[] p){p[0]=true;return ref mut p;}fn i32 main(){var bool[2] a=[false;2];if(view(ref mut a)[0]==true){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref i64[] view(ref i64[] p){return ref p;}fn i32 main(){let i64[2] a=[42;2];if(view(ref a)[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut i64[] view(ref mut i64[] p){p[0]=42;return ref mut p;}fn i32 main(){var i64[2] a=[0;2];if(view(ref mut a)[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref u8[] view(ref u8[] p){return ref p;}fn i32 main(){let u8[2] a=[42;2];if(view(ref a)[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut u8[] view(ref mut u8[] p){p[0]=42;return ref mut p;}fn i32 main(){var u8[2] a=[0;2];if(view(ref mut a)[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref u32[] view(ref u32[] p){return ref p;}fn i32 main(){let u32[2] a=[42;2];if(view(ref a)[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut u32[] view(ref mut u32[] p){p[0]=42;return ref mut p;}fn i32 main(){var u32[2] a=[0;2];if(view(ref mut a)[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref usize[] view(ref usize[] p){return ref p;}fn i32 main(){let usize[2] a=[42;2];if(view(ref a)[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut usize[] view(ref mut usize[] p){p[0]=42;return ref mut p;}fn i32 main(){var usize[2] a=[0;2];if(view(ref mut a)[0]==42){return 42;}return 0;}").is_ok);
}
@effects(console)
@test fn void length_and_utf8_projections_use_the_actual_returned_range(){
    assert(run(b"module main;fn ref i32[] view(ref i32[] p){return ref p[1..];}fn i32 main(){let i32[3] a=[0;3];if(view(ref a).len==2){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref u8[] view(ref u8[] p){return ref p[1..];}fn i32 main(){let u8[3] a=[65;3];if(text::valid_utf8(view(ref a))){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut u8[] view(ref mut u8[] p){return ref mut p;}fn i32 main(){var u8[2] a=[195;2];if(!text::valid_utf8(view(ref mut a))){return 42;}return 0;}").is_ok);
}
@effects(console)
@test fn void call_and_index_execute_once_and_restore_the_mutable_parent(){
    assert(run(b"module main;fn ref mut i32[] view(ref mut i32[] p){p[0]=p[0]+1;return ref mut p;}fn i32 main(){var i32[1] a=[20;1];let Option<i32> o=.none;var i32 n=0;let i32 x=view(ref mut a)[switch(o){case .some(v):{0}case .none:{n=n+1;0}}];return x+a[0]+n-1;}").is_ok);
    assert(run(b"module main;fn ref i32[] view(ref i32[] p){return ref p;}fn i32 main(){let Option<i32> o=.none;return view(ref [0;1])[switch(o){case .some(v):{0}case .none:{return 42;}}];}").is_ok);
    assert(run(b"module main;fn ref i32[] view(ref i32[] p){return ref p;}fn Option<i32> outer(Option<i32> o){return .some(view(ref [42;1])[switch(o){case .some(v):{0}case .none:{let i32 n=o?;0}}]);}fn i32 main(){switch(outer(.none)){case .some(v):{return 0;}case .none:{}}switch(outer(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}").is_ok);
    assert(run(b"module main;fn ref i32[] view(ref i32[] p){return ref p;}fn i32 main(){let Option<i32> o=.none;var i32 n=0;while(n<2){let i32 x=view(ref [0;1])[switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}];}return n+40;}").is_ok);
    assert(run(b"module main;fn ref i32[] view(ref i32[] p){return ref p;}fn i32 main(){let Option<i32> o=.none;while(true){let i32 x=view(ref [0;1])[switch(o){case .some(v):{0}case .none:{break;}}];}return 42;}").is_ok);
}
@test fn void invalid_projection_types_ranges_and_live_root_conflicts_reject(){
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] view(ref i32[] p){return ref p;}fn i32 main(){return view(ref [42;1]);}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] view(ref i32[] p){return ref p;}fn i32 main(){return view(ref [42;1])[true];}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] view(ref i32[] p){return ref p;}fn i32 main(){if(text::valid_utf8(view(ref [42;1]))){return 42;}return 0;}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] view(ref i32[] p){return ref p;}fn i32 main(){var i32[1] a=[42;1];let Option<i32> o=.none;return view(ref a)[switch(o){case .some(v):{0}case .none:{a[0]=0;0}}];}").is_ok);
}
@effects(console)
fn Result<usize,errors::Error> boundaries(){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] view(ref mut i32[] p){p[0]=42;return ref mut p;}fn i32 main(){return view(ref mut [0;2])[0];}")?;
    let usize remaining=execute(ref unit,16000000,0,true)?;let usize used=16000000-remaining;
    assert(execute(ref unit,used,0,true)?==0);let usize short=execute(ref unit,used-1,8,true)?;
    let ir::Program bad=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] view(ref mut i32[] p){p[0]=42;return ref mut p;}fn i32 main(){return view(ref mut [0;2])[2];}")?;
    let usize bounds=execute(ref bad,16000000,14,true)?;return .ok(0);
}
@effects(console)
@test fn void fuel_bounds_and_prior_writes_keep_canonical_failure_cleanup(){assert(boundaries().is_ok);}

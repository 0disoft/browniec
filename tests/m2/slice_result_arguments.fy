module tests::m2::slice_result_arguments;
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
@test fn void nested_returned_actuals_preserve_shared_and_exclusive_temporary_backing(){
    assert(run(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn i32 main(){let ref i32[] t=id(ref id(ref id(ref [42;2])));return t[0];}").is_ok);
    assert(run(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn i32 main(){let ref mut i32[] t=id(ref mut id(ref mut id(ref mut [0;2])));t[0]=42;return t[0];}").is_ok);
    assert(run(b"module main;fn i32[2] make(){return [42;2];}fn ref i32[] id(ref i32[] p){return ref p;}fn i32 main(){return id(ref id(ref make()))[0];}").is_ok);
    assert(run(b"module main;fn i32[2] make(){return [0;2];}fn ref mut i32[] id(ref mut i32[] p){p[0]=42;return ref mut p;}fn i32 main(){return id(ref mut id(ref mut make()))[0];}").is_ok);
}
@effects(console)
@test fn void unselected_returned_chains_release_before_using_the_selected_result(){
    assert(run(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn ref mut i32[] select(ref mut i32[] a,ref mut i32[] b){return ref mut a;}fn i32 use(ref mut i32[] p,ref mut i32[] q){{let ref mut i32[] t=select(ref mut id(ref mut id(ref mut p)),ref mut id(ref mut id(ref mut q)));q[0]=10;t[0]=32;}return p[0]+q[0];}fn i32 main(){var i32[1] a=[0;1];var i32[1] b=[0;1];return use(ref mut a,ref mut b);}").is_ok);
    assert(run(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn ref mut i32[] select(ref mut i32[] a,ref mut i32[] b){return ref mut b;}fn i32 use(ref mut i32[] p,ref mut i32[] q){{let ref mut i32[] t=select(ref mut id(ref mut p),ref mut id(ref mut q));p[0]=10;t[0]=32;}return p[0]+q[0];}fn i32 main(){var i32[1] a=[0;1];var i32[1] b=[0;1];return use(ref mut a,ref mut b);}").is_ok);
    assert(run(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn ref i32[] select(ref i32[] a,ref i32[] b){return ref b;}fn i32 main(){let ref i32[] t=select(ref id(ref [0;2]),ref id(ref [42;2]));return t[0];}").is_ok);
}
@effects(console)
@test fn void ordinary_scalar_array_and_record_calls_cleanup_returned_actuals(){
    assert(run(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn i32 read(ref mut i32[] p){p[0]=21;return p[0];}fn i32 main(){var i32[1] a=[0;1];let i32 x=read(ref mut id(ref mut id(ref mut a)));return x+a[0];}").is_ok);
    assert(run(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn i32[1] make(ref i32[] p){return [p[0];1];}fn i32 main(){return make(ref id(ref [42;1]))[0];}").is_ok);
    assert(run(b"module main;struct R{i32 x;}fn ref i32[] id(ref i32[] p){return ref p;}fn R make(ref i32[] p){return R{.x=p[0]};}fn i32 main(){return make(ref id(ref [42;1])).x;}").is_ok);
}
@effects(console)
@test fn void selected_nested_origins_reorder_forward_and_recurse(){
    assert(run(b"module main;fn ref i32[] select(ref i32[] a,ref i32[] b){return ref b;}fn ref i32[] forward(ref i32[] a,ref i32[] b){return select(ref a,ref select(ref b,ref a));}fn i32 main(){return forward(ref [42;1],ref [0;1])[0];}").is_ok);
    assert(run(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn ref mut i32[] rec(ref mut i32[] p,i32 n){if(n==0){return ref mut p;}return rec(ref mut id(ref mut p),n-1);}fn i32 main(){return rec(ref mut [42;1],3)[0];}").is_ok);
}
@effects(console)
@test fn void later_arguments_keep_hidden_backing_visible_to_all_lexical_exits(){
    assert(run(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn i32 read(ref i32[] p,i32 n){return p[0]+n;}fn i32 main(){let Option<i32> o=.none;return read(ref id(ref id(ref [0;1])),switch(o){case .some(v):{v}case .none:{return 42;}});}").is_ok);
    assert(run(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn Option<i32> read(ref mut i32[] p,i32 n){return .some(p[0]+n);}fn Option<i32> outer(Option<i32> o){return read(ref mut id(ref mut [42;1]),o?);}fn i32 main(){switch(outer(.none)){case .some(v):{return 0;}case .none:{}}switch(outer(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}").is_ok);
    assert(run(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn i32 read(ref i32[] p,i32 n){return p[0]+n;}fn i32 main(){let Option<i32> o=.none;var i32 n=0;while(n<2){let i32 x=read(ref id(ref [0;1]),switch(o){case .some(v):{v}case .none:{n=n+1;continue;}});}while(true){let i32 x=read(ref id(ref [0;1]),switch(o){case .some(v):{v}case .none:{break;}});}return 40+n;}").is_ok);
}
@test fn void conflicting_aliases_wrong_access_and_owned_escape_reject(){
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn i32 read(ref mut i32[] p,i32 n){return p[0]+n;}fn i32 main(){var i32[1] a=[0;1];return read(ref mut id(ref mut a),a[0]);}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn i32 read(ref mut i32[] p){return p[0];}fn i32 main(){return read(ref mut id(ref [42;1]));}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn ref i32[] bad(ref i32[] p){return id(ref id(ref [42;1]));}fn i32 main(){return 0;}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn ref i32[] bad(ref i32[] p){return bad(ref id(ref p));}fn i32 main(){return 0;}").is_ok);
}
@effects(console)
fn Result<usize,errors::Error> boundaries(){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] id(ref mut i32[] p){p[0]=42;return ref mut p;}fn i32 read(ref mut i32[] p){return p[0];}fn i32 main(){return read(ref mut id(ref mut id(ref mut [0;2])));}")?;
    let usize left=execute(ref unit,16000000,0,true)?;let usize used=16000000-left;
    assert(execute(ref unit,used,0,true)?==0);let usize short=execute(ref unit,used-1,8,true)?;
    let ir::Program bad=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] id(ref mut i32[] p){p[0]=42;return ref mut p;}fn i32 read(ref mut i32[] p){return p[2];}fn i32 main(){return read(ref mut id(ref mut [0;2]));}")?;
    let usize bounds=execute(ref bad,16000000,14,true)?;return .ok(0);
}
@effects(console)
@test fn void exact_fuel_bounds_and_prior_writes_drain_all_nested_receipts(){assert(boundaries().is_ok);}

@effects(console)
@test fn void returned_argument_ranges_preserve_actual_bounds_and_endpoint_lifetimes(){
    assert(run(b"module main;fn ref mut i32[] tail(ref mut i32[] p){return ref mut p[1..];}fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn i32 use(ref mut i32[] p){{let ref mut i32[] t=id(ref mut tail(ref mut p)[..1]);t[0]=42;}return p[1];}fn i32 main(){var i32[3] a=[0;3];return use(ref mut a);}").is_ok);
    assert(run(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn ref i32[] select(ref i32[] a,ref i32[] b){return ref a;}fn i32 main(){let ref i32[] t=select(ref id(ref [42;3])[1..],ref id(ref [0;2]));if(t.len==2){return t[0];}return 0;}").is_ok);
    assert(run(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn i32 read(ref i32[] p){return p[0];}fn i32 main(){let Option<i32> o=.none;return read(ref id(ref [0;2])[switch(o){case .some(v):{0}case .none:{return 42;}}..]);}").is_ok);
    assert(run(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn i32 read(ref mut i32[] p){return p[0];}fn i32 main(){let Option<i32> o=.none;return read(ref mut id(ref mut [0;2])[0..switch(o){case .some(v):{1}case .none:{return 42;}}]);}").is_ok);
}
@effects(console)
@test fn void direct_returned_actuals_match_all_six_scalar_modes(){
    assert(run(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn i32 read(ref i32[] p){return p[0];}fn i32 main(){if(read(ref id(ref [42;1]))==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn i32 read(ref mut i32[] p){return p[0];}fn i32 main(){if(read(ref mut id(ref mut [42;1]))==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref bool[] id(ref bool[] p){return ref p;}fn bool read(ref bool[] p){return p[0];}fn i32 main(){if(read(ref id(ref [true;1]))==true){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut bool[] id(ref mut bool[] p){return ref mut p;}fn bool read(ref mut bool[] p){return p[0];}fn i32 main(){if(read(ref mut id(ref mut [true;1]))==true){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref i64[] id(ref i64[] p){return ref p;}fn i64 read(ref i64[] p){return p[0];}fn i32 main(){if(read(ref id(ref [42;1]))==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut i64[] id(ref mut i64[] p){return ref mut p;}fn i64 read(ref mut i64[] p){return p[0];}fn i32 main(){if(read(ref mut id(ref mut [42;1]))==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn u8 read(ref u8[] p){return p[0];}fn i32 main(){if(read(ref id(ref [42;1]))==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut u8[] id(ref mut u8[] p){return ref mut p;}fn u8 read(ref mut u8[] p){return p[0];}fn i32 main(){if(read(ref mut id(ref mut [42;1]))==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref u32[] id(ref u32[] p){return ref p;}fn u32 read(ref u32[] p){return p[0];}fn i32 main(){if(read(ref id(ref [42;1]))==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut u32[] id(ref mut u32[] p){return ref mut p;}fn u32 read(ref mut u32[] p){return p[0];}fn i32 main(){if(read(ref mut id(ref mut [42;1]))==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref usize[] id(ref usize[] p){return ref p;}fn usize read(ref usize[] p){return p[0];}fn i32 main(){if(read(ref id(ref [42;1]))==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut usize[] id(ref mut usize[] p){return ref mut p;}fn usize read(ref mut usize[] p){return p[0];}fn i32 main(){if(read(ref mut id(ref mut [42;1]))==42){return 42;}return 0;}").is_ok);
}

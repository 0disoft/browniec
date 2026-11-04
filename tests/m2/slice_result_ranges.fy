module tests::m2::slice_result_ranges;
import compiler as compiler;
import slice_result_ir as ir;
import slice_result_verifier as proof;
import slice_result_runtime as runtime;
import array_layout as layouts;
import array_owners as owners;
import array_slices as slices;
import errors as errors;
import vm as vm;

fn owners::Token create(ref mut runtime::State state,ref mut u8[] data,u8 tag){
    let layouts::Array shape=switch(layouts::scalar(tag,4)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=1,.length=4,.stride=4,.alignment=4,.bytes=16}}};
    return switch(owners::create(ref shape,1,data,ref mut state.runtime.owners)){
        case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}
    };
}
fn slices::Ticket opened(ref mut runtime::State state,owners::Token root,bool writer,usize capacity){
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket ticket=switch(if(writer){slices::open_exclusive(ref mut pool,ref mut table,root,0,4,capacity)}else{slices::open(ref mut pool,ref mut table,root,0,4,capacity)}){
        case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}
    };state.runtime.pool=pool;state.runtime.owners=table;return ticket;
}
fn void drained(ref runtime::State state){
    assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0 && state.runtime.authority.depth==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
fn Result<usize,errors::Error> run(ref u8[] source,u8 tag,bool writer,i64 lo,i64 hi,usize start,usize end,u8 error,i64 payload){
    let ir::Program unit=compiler::inspect_slice_result_ir(source)?;
    assert(proof::inspect(ref unit).is_ok && unit.parameters[0]==1);
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);
    let owners::Token root=create(ref mut state,ref mut data,tag);
    if(payload!=0){assert(owners::write(ref mut state.runtime.owners,root,0,0,ref mut data).is_ok);}
    let slices::Ticket parent=opened(ref mut state,root,writer,64);
    let runtime::Capture empty=runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false);
    let runtime::Capture[3] captures=[runtime::capture(parent,true,true),empty,empty];let i64[3] values=[0,lo,hi];
    let usize arity=unit.body.arities[0];
    switch(vm::run_slice_result(ref unit,0,ref captures[..arity],ref values[..arity],ref mut state,ref mut data,10000000)){
        case .ok(v):{
            assert(error==0 && v.held.view.start==start && v.held.view.end==end && v.held.exclusive==writer);
            var runtime::Held held=v.held;let slices::Ticket current=held.issued;
            if(start!=end){switch(slices::read(ref state.runtime.pool,current,ref state.runtime.owners,0,ref data)){case .ok(n):{assert(n==1);}case .err(_):{assert(false);}};}
            if(payload!=0){assert(data[0]==12);}
            let runtime::Closed closed=runtime::close(ref mut state,ref mut held,current,64,0)?;assert(closed.remaining==0);
        }
        case .err(e):{assert(error!=0 && e.kind==error);if(payload!=0){assert(data[0]==12);}}
    };drained(ref state);return .ok(0);
}
@test fn void ranges_preserve_all_six_exact_scalar_and_access_modes(){
    assert(run(b"module main;fn ref i32[] f(ref i32[] p){return ref p[1..3];}fn i32 main(){return 0;}",1,false,0,0,1,3,0,0).is_ok);
    assert(run(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p[1..3];}fn i32 main(){return 0;}",1,true,0,0,1,3,0,0).is_ok);
    assert(run(b"module main;fn ref bool[] f(ref bool[] p){return ref p[1..3];}fn i32 main(){return 0;}",2,false,0,0,1,3,0,0).is_ok);
    assert(run(b"module main;fn ref mut bool[] f(ref mut bool[] p){return ref mut p[1..3];}fn i32 main(){return 0;}",2,true,0,0,1,3,0,0).is_ok);
    assert(run(b"module main;fn ref u8[] f(ref u8[] p){return ref p[1..3];}fn i32 main(){return 0;}",10,false,0,0,1,3,0,0).is_ok);
    assert(run(b"module main;fn ref mut u8[] f(ref mut u8[] p){return ref mut p[1..3];}fn i32 main(){return 0;}",10,true,0,0,1,3,0,0).is_ok);
    assert(run(b"module main;fn ref i64[] f(ref i64[] p){return ref p[1..3];}fn i32 main(){return 0;}",9,false,0,0,1,3,0,0).is_ok);
    assert(run(b"module main;fn ref mut i64[] f(ref mut i64[] p){return ref mut p[1..3];}fn i32 main(){return 0;}",9,true,0,0,1,3,0,0).is_ok);
    assert(run(b"module main;fn ref u32[] f(ref u32[] p){return ref p[1..3];}fn i32 main(){return 0;}",11,false,0,0,1,3,0,0).is_ok);
    assert(run(b"module main;fn ref mut u32[] f(ref mut u32[] p){return ref mut p[1..3];}fn i32 main(){return 0;}",11,true,0,0,1,3,0,0).is_ok);
    assert(run(b"module main;fn ref usize[] f(ref usize[] p){return ref p[1..3];}fn i32 main(){return 0;}",12,false,0,0,1,3,0,0).is_ok);
    assert(run(b"module main;fn ref mut usize[] f(ref mut usize[] p){return ref mut p[1..3];}fn i32 main(){return 0;}",12,true,0,0,1,3,0,0).is_ok);
}
@test fn void open_empty_dynamic_and_relative_ranges_retain_the_original_input(){
    assert(run(b"module main;fn ref i32[] f(ref i32[] p){return ref p[..];}fn i32 main(){return 0;}",1,false,0,0,0,4,0,0).is_ok);
    assert(run(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p[..2];}fn i32 main(){return 0;}",1,true,0,0,0,2,0,0).is_ok);
    assert(run(b"module main;fn ref i32[] f(ref i32[] p){return ref p[1..];}fn i32 main(){return 0;}",1,false,0,0,1,4,0,0).is_ok);
    assert(run(b"module main;fn ref mut i32[] f(ref mut i32[] p,usize lo,usize hi){return ref mut p[lo..hi];}fn i32 main(){return 0;}",1,true,2,2,2,2,0,0).is_ok);
    assert(run(b"module main;fn ref i32[] f(ref i32[] p){let ref i32[] q=ref p[1..4];return ref q[1..2];}fn i32 main(){return 0;}",1,false,0,0,2,3,0,0).is_ok);
    assert(run(b"module main;fn ref mut i32[] f(ref mut i32[] p){let ref mut i32[] q=ref mut p[1..4];return ref mut q[1..2];}fn i32 main(){return 0;}",1,true,0,0,2,3,0,0).is_ok);
    assert(run(b"module main;fn ref mut i32[] f(ref mut i32[] p){return g(ref mut p);}fn ref mut i32[] g(ref mut i32[] q){return ref mut q[1..3];}fn i32 main(){return 0;}",1,true,0,0,1,3,0,0).is_ok);
}
@test fn void endpoints_complete_once_in_order_before_acquisition_and_failure_keeps_writes(){
    assert(run(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p[first(ref mut p)..last(ref mut p)];}fn usize first(ref mut i32[] q){q[0]=q[0]*10+1;return 1;}fn usize last(ref mut i32[] q){q[0]=q[0]*10+2;return 3;}fn i32 main(){return 0;}",1,true,0,0,1,3,0,12).is_ok);
    assert(run(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p[first(ref mut p)..last(ref mut p)];}fn usize first(ref mut i32[] q){q[0]=q[0]*10+1;return 1;}fn usize last(ref mut i32[] q){q[0]=q[0]*10+2;return 1/0;}fn i32 main(){return 0;}",1,true,0,0,0,0,7,12).is_ok);
    assert(run(b"module main;fn ref i32[] f(ref i32[] p,usize lo,usize hi){return ref p[lo..hi];}fn i32 main(){return 0;}",1,false,3,1,0,0,14,0).is_ok);
    assert(run(b"module main;fn ref mut i32[] f(ref mut i32[] p,usize lo,usize hi){return ref mut p[lo..hi];}fn i32 main(){return 0;}",1,true,0,5,0,0,14,0).is_ok);
}
@test fn void source_and_independent_proof_reject_wrong_types_origins_and_cleanup(){
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] f(ref i32[] p){return ref p[true..2];}fn i32 main(){return 0;}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] f(ref i32[] p){return ref p[0..false];}fn i32 main(){return 0;}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref p[0..2];}fn i32 main(){return 0;}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] f(ref i32[] p){let i32[4] a=[1;4];let ref i32[] q=ref a;return ref q[0..2];}fn i32 main(){return 0;}").is_ok);
    let Result<ir::Program,errors::Error> result=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p[1..3];}fn i32 main(){return 0;}");
    switch(result){case .ok(v):{
        var ir::Program unit=v;var usize pc=unit.body.starts[0];while(pc<unit.body.ends[0] && unit.body.code[pc*8]!=62){pc+=1;}assert(pc<unit.body.ends[0]);
        unit.body.code[pc*8+2]=15;assert(!proof::inspect(ref unit).is_ok);
    }case .err(_):{assert(false);}};
    assert(!compiler::compile(b"module main;fn ref i32[] f(ref i32[] p){return ref p[1..3];}fn i32 main(){return 0;}").is_ok);
}

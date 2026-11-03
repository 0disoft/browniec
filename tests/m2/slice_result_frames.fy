module tests::m2::slice_result_frames;
import slice_result_frames as frames;
import slice_result_runtime as runtime;
import slice_result_ir as ir;
import compiler as compiler;
import errors as errors;
import array_slices as slices;
import array_owners as owners;
import array_layout as layout;

fn slices::Ticket opened(ref mut runtime::State state,ref mut u8[] data,bool exclusive){
    let layout::Array shape=switch(layout::scalar(1,4)){case .ok(v):{v}case .err(_):{assert(false);layout::Array{.element=1,.length=4,.stride=4,.alignment=4,.bytes=16}}};
    let owners::Token root=switch(owners::create(ref shape,0,data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket result=switch(if(exclusive){slices::open_exclusive(ref mut pool,ref mut table,root,0,4,data.len)}else{slices::open(ref mut pool,ref mut table,root,0,4,data.len)}){case .ok(v):{v}case .err(_):{assert(false);frames::none()}};
    state.runtime.pool=pool;state.runtime.owners=table;return result;
}
fn Result<usize,errors::Error> forwarding(ref u8[] source,bool exclusive){
    var u8[16] data=[0;16];var runtime::State state=runtime::empty(16);
    let slices::Ticket parent=opened(ref mut state,ref mut data,exclusive);
    let ir::Program unit=compiler::inspect_slice_result_ir(source)?;
    var frames::Frames stack=frames::empty(ref state);
    let runtime::Contract outer=runtime::contract(ref unit,1)?;
    let runtime::Capture[1] args=[runtime::capture(parent,true,true)];
    let runtime::Call first=runtime::enter(ref mut state,outer,ref args,16,runtime::cost())?;
    assert(frames::push(ref unit.body,ref mut stack,first,1,128,32,0).is_ok);
    let usize parameter=unit.body.slice_parameters[unit.body.register_starts[1]] as usize-1;
    let slices::Ticket actual=stack.sites[16+parameter];
    let runtime::Capture[1] inner_args=[runtime::capture(actual,false,false)];
    let runtime::Call inner=runtime::enter(ref mut state,runtime::contract(ref unit,0)?,ref inner_args,16,runtime::cost())?;
    var usize pc=unit.body.starts[1];while(unit.body.code[pc*8]!=64){pc+=1;}
    let usize destination=unit.body.code[pc*8+1] as usize;let usize map=unit.body.code[pc*8+3] as usize;
    assert(frames::push(ref unit.body,ref mut stack,inner,0,destination,map,pc+1).is_ok);
    let usize site=unit.body.slice_parameters[unit.body.register_starts[0]] as usize-1;
    let slices::Ticket selected=stack.sites[32+site];
    assert(frames::prepare(ref mut stack,7,selected).is_ok);
    assert(!frames::selected(ref stack,8).is_ok && frames::selected(ref stack,7)?==2);
    var runtime::Call call=frames::current(ref stack);
    let runtime::Returned result=runtime::handoff(ref mut state,ref mut call,selected,16,runtime::handoff_cost())?;
    assert(frames::pop(ref unit.body,ref mut stack,result)?==pc+1);
    assert(stack.frame==1 && stack.prepared[1] && stack.identities[1]==destination);
    assert(!stack.prepared[2] && !stack.active[2] && stack.results[2].slot==16);
    assert(frames::selected(ref stack,destination)?==1);
    call=frames::current(ref stack);let slices::Ticket forwarded=stack.results[1];
    var runtime::Returned final=runtime::handoff(ref mut state,ref mut call,forwarded,16,runtime::handoff_cost())?;
    assert(frames::pop(ref unit.body,ref mut stack,final)?==0 && stack.frame==0);
    assert(!frames::selected(ref stack,destination).is_ok);
    let slices::Ticket current=final.held.issued;
    assert(runtime::close(ref mut state,ref mut final.held,current,16,0).is_ok);
    assert(state.runtime.owners.depth==0 && state.runtime.authority.depth==0);return .ok(0);
}
@test fn void readonly_destination_and_frame(){assert(forwarding(b"module main;fn ref i32[] g(ref i32[] p){return ref p;}fn ref i32[] f(ref i32[] p){return g(ref p);}fn i32 main(){return 0;}",false).is_ok);}
@test fn void mutable_destination_and_frame(){assert(forwarding(b"module main;fn ref mut i32[] g(ref mut i32[] p){return ref mut p;}fn ref mut i32[] f(ref mut i32[] p){return g(ref mut p);}fn i32 main(){return 0;}",true).is_ok);}

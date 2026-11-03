module tests::m2::slice_result_owned_runtime;
import slice_result_runtime as runtime;
import slice_result_ir as ir;
import compiler as compiler;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import slice_authority as authority;
import errors as errors;
import ir as base;
fn usize size(Result<usize,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 cell(Result<i64,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn runtime::Contract binding(ref u8[] source,usize function){
    let ir::Program unit=switch(compiler::inspect_slice_result_ir(source)){case .ok(v):{v}case .err(_):{assert(false);ir::Program{.body=compiler_program(),.elements=[0;16],.parameters=[0;16]}}};
    return switch(runtime::contract(ref unit,function)){case .ok(v):{v}case .err(_):{assert(false);runtime::Contract{.tags=[0;8],.arity=0,.selected=0}}};
}
fn base::Program compiler_program(){return base::empty();}
fn runtime::Call entered(ref mut runtime::State state,runtime::Contract c,ref runtime::Capture[] captures,usize capacity){return switch(runtime::enter(state,c,captures,capacity,runtime::cost())){case .ok(v):{assert(v.remaining==0);v}case .err(_):{assert(false);runtime::Call{.captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false);8],.views=[state.runtime.pool.slots[0].view;8],.issued=[slices::Ticket{.slot=16,.generation=0};8],.before=[slices::Ticket{.slot=16,.generation=0};16],.contract=c,.depth=0,.frame=0,.remaining=0,.active=false}}};}
fn runtime::Returned returned(ref mut runtime::State state,ref mut runtime::Call call,slices::Ticket selected,usize capacity){return switch(runtime::handoff(state,call,selected,capacity,runtime::cost())){case .ok(v):{assert(v.remaining==0);v}case .err(_):{assert(false);runtime::Returned{.held=runtime::Held{.issued=selected,.view=call.views[0],.exclusive=false,.close_parent=false,.drop=false,.depth=0,.frame=0,.active=false},.resumed=[slices::Ticket{.slot=16,.generation=0};8],.remaining=0}}};}
fn slices::Ticket ended(ref mut runtime::State state,ref mut runtime::Held held,slices::Ticket current,usize capacity){return switch(runtime::close(state,held,current,capacity,runtime::cost())){case .ok(v):{assert(v.remaining==0);v.parent}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn owners::Token create(ref mut runtime::State state,u8 tag,ref mut u8[] data){
    let layouts::Array shape=switch(layouts::scalar(tag,4)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};
    return switch(owners::create(ref shape,0,data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn slices::Ticket open(ref mut runtime::State state,owners::Token root,bool exclusive,usize capacity){
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket result=ticket(if(exclusive){slices::open_exclusive(ref mut pool,ref mut table,root,0,4,capacity)}else{slices::open(ref mut pool,ref mut table,root,0,4,capacity)});
    state.runtime.pool=pool;state.runtime.owners=table;return result;
}
fn void close_ticket(ref mut runtime::State state,slices::Ticket current,usize capacity){
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let usize done=size(slices::close(ref mut pool,current,ref mut table,capacity));state.runtime.pool=pool;state.runtime.owners=table;
}
fn slices::Ticket child(ref mut runtime::State state,slices::Ticket parent,usize lo,usize hi,usize capacity){
    var authority::State stack=state.runtime.authority;var slices::Pool pool=state.runtime.pool;
    let usize frame=stack.frame;
    let slices::Ticket result=ticket(authority::enter_child(ref mut stack,ref mut pool,parent,ref state.runtime.owners,lo,hi,capacity,frame));
    state.runtime.authority=stack;state.runtime.pool=pool;return result;
}
fn slices::Ticket restore(ref mut runtime::State state,slices::Ticket current,usize capacity){
    var authority::State stack=state.runtime.authority;var slices::Pool pool=state.runtime.pool;let usize frame=stack.frame;
    let slices::Ticket result=ticket(authority::leave_child(ref mut stack,ref mut pool,current,ref state.runtime.owners,capacity,frame));
    state.runtime.authority=stack;state.runtime.pool=pool;return result;
}
fn slices::Ticket sub(ref mut runtime::State state,slices::Ticket parent,usize lo,usize hi,usize capacity){
    var slices::Pool pool=state.runtime.pool;let slices::Ticket result=ticket(slices::subslice(ref mut pool,parent,ref state.runtime.owners,lo,hi,capacity));state.runtime.pool=pool;return result;
}

fn Result<usize,errors::Error> zero(){
    var runtime::State state=runtime::empty(64);let runtime::Capture[1] empty=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let runtime::Contract c=runtime::Contract{.tags=[0;8],.arity=0,.selected=0};
    var runtime::Call call=runtime::enter_call(ref mut state,c,ref empty[..0],64,runtime::cost())?;
    assert(!runtime::leave_call(ref mut state,ref mut call,64,0).is_ok && call.active && state.runtime.authority.frame==1);
    let runtime::Resumed result=runtime::leave_call(ref mut state,ref mut call,64,runtime::cost())?;
    assert(!call.active && result.remaining==0 && state.runtime.authority.depth==0);return .ok(0);
}
@test fn void zero_argument_call_and_fuel_rollback(){assert(zero().is_ok);}
fn Result<usize,errors::Error> ordinary(){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);let owners::Token root=create(ref mut state,1,ref mut data);
    let slices::Ticket parent=open(ref mut state,root,true,64);let runtime::Capture[1] args=[runtime::capture(parent,false,false)];
    var runtime::Contract c=runtime::Contract{.tags=[0;8],.arity=1,.selected=0};c.tags[0]=129;
    var runtime::Call call=runtime::enter_call(ref mut state,c,ref args,64,runtime::cost())?;
    let slices::Ticket derived=child(ref mut state,call.issued[0],1,3,64);
    assert(slices::write(ref state.runtime.pool,derived,ref state.runtime.owners,0,42,ref mut data).is_ok);
    let runtime::Resumed result=runtime::leave_call(ref mut state,ref mut call,64,runtime::cost())?;
    assert(cell(slices::read(ref state.runtime.pool,result.tickets[0],ref state.runtime.owners,1,ref data))==42);
    assert(!slices::length(ref state.runtime.pool,parent,ref state.runtime.owners,64).is_ok);
    let usize ended=runtime::abort(ref mut state,64,0)?;return .ok(0);
}
@test fn void ordinary_return_restores_writers_and_descendants(){assert(ordinary().is_ok);}
fn Result<usize,errors::Error> locals(){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);let owners::Token root=create(ref mut state,1,ref mut data);
    let slices::Ticket parent=open(ref mut state,root,true,64);let runtime::Capture[1] args=[runtime::capture(parent,true,true)];
    var runtime::Call call=entered(ref mut state,binding(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){return 0;}",0),ref args,64);
    let owners::Token local=create(ref mut state,1,ref mut data);let slices::Ticket loan=open(ref mut state,local,true,64);
    let slices::Ticket selected=call.issued[0];let owners::Token[1] bad=[root];
    assert(!runtime::handoff_roots(ref mut state,ref mut call,selected,ref bad,64,runtime::cost()).is_ok && call.active);
    assert(slices::length(ref state.runtime.pool,loan,ref state.runtime.owners,64).is_ok && state.runtime.owners.slots[local.slot].live);
    let owners::Token[1] roots=[local];var runtime::Returned result=runtime::handoff_roots(ref mut state,ref mut call,selected,ref roots,64,runtime::cost())?;
    assert(!state.runtime.owners.slots[local.slot].live);let slices::Ticket current=result.held.issued;
    let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,64,runtime::cost())?;
    assert(state.runtime.owners.depth==0 && state.runtime.authority.depth==0);return .ok(0);
}
@test fn void callee_owned_root_cleanup_is_atomic(){assert(locals().is_ok);}

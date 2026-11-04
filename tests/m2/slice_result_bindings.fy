module tests::m2::slice_result_bindings;
import slice_result_frames as frames;
import slice_result_bindings as bindings;
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

fn runtime::Contract contract(bool writer){
    var runtime::Contract result=runtime::Contract{.tags=[0;8],.arity=1,.selected=1};
    result.tags[0]=if(writer){129}else{1};return result;
}
fn Result<runtime::Returned,errors::Error> returned(ref mut runtime::State state,slices::Ticket parent,bool writer,bool drop,usize capacity){
    let runtime::Capture[1] captures=[runtime::capture(parent,drop,drop)];
    var runtime::Call call=runtime::enter(state,contract(writer),ref captures,capacity,runtime::cost())?;
    let slices::Ticket selected=call.issued[0];
    return runtime::handoff(state,ref mut call,selected,capacity,runtime::handoff_cost());
}
fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 && state.runtime.owners.depth==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
fn Result<usize,errors::Error> live_frames(bool writer,bool forward){
    let ir::Program unit=compiler::inspect_slice_result_ir(if(writer){b"module main;fn ref mut i32[] g(ref mut i32[] p){return ref mut p;}fn ref mut i32[] f(ref mut i32[] p){return g(ref mut p);}fn i32 main(){return 0;}"}else{b"module main;fn ref i32[] g(ref i32[] p){return ref p;}fn ref i32[] f(ref i32[] p){return g(ref p);}fn i32 main(){return 0;}"})?;
    var u8[16] data=[0;16];var runtime::State state=runtime::empty(16);
    let slices::Ticket parent=opened(ref mut state,ref mut data,writer);
    var frames::Frames stack=frames::empty(ref state);
    let runtime::Capture[1] initial=[runtime::capture(parent,true,true)];
    let runtime::Call first=runtime::enter(ref mut state,contract(writer),ref initial,16,runtime::cost())?;
    let usize outer=frames::push(ref unit.body,ref mut stack,first,1,128,32,0)?;
    let usize source=unit.body.slice_parameters[unit.body.register_starts[1]] as usize-1;
    let slices::Ticket actual=stack.sites[16+source];
    let runtime::Capture[1] args=[runtime::capture(actual,false,false)];
    let runtime::Call child=runtime::enter(ref mut state,contract(writer),ref args,16,runtime::cost())?;
    var usize pc=unit.body.starts[1];while(unit.body.code[pc*8]!=64){pc+=1;}
    let usize map=unit.body.code[pc*8+3] as usize;
    let usize pushed=frames::push(ref unit.body,ref mut stack,child,0,170,map,pc+1)?;
    let usize formal=unit.body.slice_parameters[unit.body.register_starts[0]] as usize-1;
    let slices::Ticket selected=stack.sites[32+formal];let usize prepared=frames::prepare(ref mut stack,7,selected)?;
    var runtime::Call call=frames::current(ref stack);
    let runtime::Returned result=runtime::handoff(ref mut state,ref mut call,selected,16,runtime::handoff_cost())?;
    assert(frames::pop(ref unit.body,ref mut stack,result)?==pc+1 && stack.frame==1 && !stack.prepared[1]);
    assert(frames::result_bound(ref stack,10));
    let slices::Ticket live=stack.sites[26];assert(slices::length(ref state.runtime.pool,live,ref state.runtime.owners,16).is_ok);
    if(writer){
        assert(stack.sites[16+source].slot==16 && !slices::length(ref state.runtime.pool,actual,ref state.runtime.owners,16).is_ok);
        assert(slices::write(ref state.runtime.pool,live,ref state.runtime.owners,0,42,ref mut data).is_ok);
    }
    if(forward){let usize marked=frames::prepare(ref mut stack,8,live)?;}
    else{
        let runtime::Resumed invalid=runtime::Resumed{.tickets=[frames::none();8],.remaining=0};
        assert(!frames::pop_call(ref unit.body,ref mut stack,invalid).is_ok);
        assert(frames::close_result(ref mut stack,ref mut state,10,16,0)?==0);
        assert(!frames::result_bound(ref stack,10) && stack.sites[26].slot==16);
        assert(!frames::close_result(ref mut stack,ref mut state,10,16,0).is_ok);
        let slices::Ticket fresh=stack.sites[16+source];assert(slices::length(ref state.runtime.pool,fresh,ref state.runtime.owners,16).is_ok);
        if(writer){assert(fresh.generation>actual.generation && data[0]==42);}
        let usize marked=frames::prepare(ref mut stack,8,fresh)?;
    }
    call=frames::current(ref stack);let slices::Ticket final=stack.results[1];
    var runtime::Returned escaped=runtime::handoff(ref mut state,ref mut call,final,16,runtime::handoff_cost())?;
    let usize popped=frames::pop(ref unit.body,ref mut stack,escaped)?;
    assert(stack.frame==0 && !bindings::in_frame(ref stack.loans,1));
    let slices::Ticket issued=escaped.held.issued;
    assert(runtime::close(ref mut state,ref mut escaped.held,issued,16,0).is_ok);drained(ref state);return .ok(0);
}
@test fn void caller_continues_with_a_shared_result_and_closes_it(){assert(live_frames(false,false).is_ok);}
@test fn void mutable_result_close_publishes_the_fresh_parent_binding(){assert(live_frames(true,false).is_ok);}
@test fn void terminal_forward_consumes_held_bindings_after_canonical_handoff(){assert(live_frames(false,true).is_ok && live_frames(true,true).is_ok);}

// Seventeen simultaneously live returned results share ONE physical writer
// slot. The second caller frame makes the static 16-site partitions explicit.
fn Result<usize,errors::Error> nested(){
    var runtime::State state=runtime::empty(16);var u8[16] data=[0;16];
    var bindings::State held=bindings::empty();var slices::Ticket current=opened(ref mut state,ref mut data,true);
    let usize slot=current.slot;var usize i=1;
    while(i<=15){let runtime::Returned result=returned(ref mut state,current,true,false,16)?;
        assert(result.held.issued.slot==slot);let usize saved=bindings::retain(ref mut held,i,i-1,result.held)?;
        current=result.held.issued;i+=1;}
    var runtime::Contract ordinary=contract(true);ordinary.selected=0;
    let runtime::Capture[1] args=[runtime::capture(current,false,false)];
    var runtime::Call call=runtime::enter_call(ref mut state,ordinary,ref args,16,runtime::cost())?;
    current=call.issued[0];i=17;
    while(i<=18){let runtime::Returned result=returned(ref mut state,current,true,false,16)?;
        assert(result.held.issued.slot==slot);let usize saved=bindings::retain(ref mut held,i,i-1,result.held)?;
        current=result.held.issued;i+=1;}
    assert(bindings::in_frame(ref held,0) && bindings::in_frame(ref held,1) && state.runtime.authority.depth==18);
    assert(!bindings::close(ref mut held,ref mut state,1,current,16,0).is_ok && bindings::find(ref held,1)!=47);
    i=19;while(i>17){i-=1;let bindings::Closed closed=bindings::close(ref mut held,ref mut state,i,current,16,0)?;
        assert(closed.location==i-1 && closed.remaining==0);current=closed.parent;}
    let runtime::Resumed resumed=runtime::leave_call(ref mut state,ref mut call,16,runtime::leave_cost())?;current=resumed.tickets[0];
    i=16;while(i>1){i-=1;let bindings::Closed closed=bindings::close(ref mut held,ref mut state,i,current,16,0)?;
        assert(closed.location==i-1);current=closed.parent;}
    assert(!bindings::in_frame(ref held,0) && !bindings::in_frame(ref held,1));
    assert(slices::length(ref state.runtime.pool,current,ref state.runtime.owners,16).is_ok);
    let usize aborted=runtime::abort(ref mut state,16,0)?;drained(ref state);return .ok(0);
}
@test fn void seventeen_nested_receipts_share_one_slot_without_losing_outer_generations(){assert(nested().is_ok);}
fn Result<usize,errors::Error> rollback(){
    var runtime::State state=runtime::empty(16);var u8[16] data=[0;16];let slices::Ticket parent=opened(ref mut state,ref mut data,false);
    let slices::Ticket alias=opened_alias(ref mut state,parent);
    var bindings::State held=bindings::empty();let runtime::Returned result=returned(ref mut state,parent,false,true,16)?;
    let usize retained=bindings::retain(ref mut held,1,0,result.held)?;let slices::Ticket current=result.held.issued;
    assert(!bindings::retain(ref mut held,1,0,result.held).is_ok && !bindings::retain(ref mut held,2,0,result.held).is_ok);
    let slices::Ticket stale=slices::Ticket{.slot=current.slot,.generation=current.generation+1};
    assert(!bindings::close(ref mut held,ref mut state,1,stale,16,0).is_ok);
    assert(!bindings::close(ref mut held,ref mut state,1,current,16,0).is_ok);
    assert(bindings::find(ref held,1)!=47 && slices::length(ref state.runtime.pool,current,ref state.runtime.owners,16).is_ok);
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    assert(slices::close(ref mut pool,alias,ref mut table,16).is_ok);state.runtime.pool=pool;state.runtime.owners=table;
    let bindings::Closed closed=bindings::close(ref mut held,ref mut state,1,current,16,0)?;
    assert(closed.location==512 && closed.parent.slot==16 && bindings::find(ref held,1)==47);
    assert(!bindings::close(ref mut held,ref mut state,1,current,16,0).is_ok);drained(ref state);return .ok(0);
}
fn slices::Ticket opened_alias(ref mut runtime::State state,slices::Ticket parent){
    var slices::Pool pool=state.runtime.pool;
    let slices::Ticket alias=switch(slices::subslice(ref mut pool,parent,ref state.runtime.owners,0,4,16)){case .ok(v):{v}case .err(_):{assert(false);frames::none()}};
    state.runtime.pool=pool;return alias;
}
@test fn void failed_final_root_drop_preserves_the_live_binding_and_runtime(){assert(rollback().is_ok);}

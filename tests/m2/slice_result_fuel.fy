module tests::m2::slice_result_fuel;
import fuel as meter;
import vm as vm;
import compiler as compiler;
import slice_result_ir as ir;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import slice_result_loan_execution as loans;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import errors as errors;
import slice_authority as authority;
import struct_call_vm as copies;

fn slices::Ticket opened(ref mut runtime::State state,ref mut u8[] data,u8 tag,bool exclusive){
    let layouts::Array shape=switch(layouts::scalar(tag,4)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=1,.length=4,.stride=4,.alignment=4,.bytes=16}}};
    let owners::Token root=switch(owners::create(ref shape,0,data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket opened=switch(if(exclusive){slices::open_exclusive(ref mut pool,ref mut table,root,0,4,data.len)}else{slices::open(ref mut pool,ref mut table,root,0,4,data.len)}){
        case .ok(v):{v}case .err(_):{assert(false);frames::none()}
    };state.runtime.pool=pool;state.runtime.owners=table;return opened;
}
fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
fn Result<usize,errors::Error> exact(bool short,bool initial){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){p[0]=42;return ref mut p;}fn i32 main(){return 0;}")?;
    var u8[16] data=[0;16];var runtime::State state=runtime::empty(16);let slices::Ticket parent=opened(ref mut state,ref mut data,1,true);
    let runtime::Capture[1] captures=[runtime::capture(parent,true,true)];let i64[1] values=[0];
    // Independent straight-line oracle: one dispatch per emitted instruction,
    // one formal transfer, one i32 store (4130+2*4), entry and handoff.
    let usize required=147456+294912+1+(unit.body.ends[0]-unit.body.starts[0])+4138;
    let usize budget=if(initial){147456}else{required-if(short){1}else{0}};
    assert(required<meter::cli_limit());
    switch(vm::run_slice_result(ref unit,0,ref captures,ref values,ref mut state,ref mut data,budget)){
        case .ok(v):{
            assert(!short && !initial && v.remaining==0 && data[0]==42);
            var runtime::Held held=v.held;let slices::Ticket current=held.issued;
            let runtime::Closed closed=runtime::close(ref mut state,ref mut held,current,16,0)?;
            assert(closed.remaining==0 && !held.active);drained(ref state);
            assert(!runtime::close(ref mut state,ref mut held,current,16,0).is_ok);drained(ref state);
        }
        case .err(e):{
            assert(e.kind==8 && (short || initial));
            if(initial){assert(data[0]==0 && state.runtime.owners.depth==1 && state.runtime.authority.depth==0);assert(slices::length(ref state.runtime.pool,parent,ref state.runtime.owners,16).is_ok);}
            else{assert(data[0]==42);drained(ref state);}
        }
    };return .ok(required);
}
@test fn void exact_whole_invocation_budget_and_one_short_have_distinct_state_contracts(){
    assert(exact(false,false).is_ok && exact(true,false).is_ok && exact(false,true).is_ok);
}

fn Result<usize,errors::Error> transaction(){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){return 0;}")?;
    var u8[16] data=[0;16];var runtime::State state=runtime::empty(16);let slices::Ticket parent=opened(ref mut state,ref mut data,1,true);
    let runtime::Capture[1] captures=[runtime::capture(parent,true,true)];let runtime::Contract c=runtime::contract(ref unit,0)?;
    assert(!runtime::enter(ref mut state,c,ref captures,16,147455).is_ok);
    assert(state.runtime.authority.depth==0 && state.runtime.pool.slots[parent.slot].generation==parent.generation && data[0]==0);
    var runtime::Call call=runtime::enter(ref mut state,c,ref captures,16,147456)?;
    assert(call.remaining==0);let slices::Ticket selected=call.issued[0];
    switch(runtime::handoff(ref mut state,ref mut call,selected,16,294911)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    assert(call.active && state.runtime.authority.frame==1 && state.runtime.pool.slots[selected.slot].generation==selected.generation);
    var runtime::Returned result=runtime::handoff(ref mut state,ref mut call,selected,16,294912)?;assert(result.remaining==0 && !call.active);
    let slices::Ticket current=result.held.issued;let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,16,0)?;
    assert(closed.remaining==0);drained(ref state);return .ok(0);
}
@test fn void transaction_boundaries_precede_mutation_and_finalization_is_prepaid(){assert(transaction().is_ok);}

fn Result<usize,errors::Error> forward(ref u8[] source,bool exclusive){
    let ir::Program unit=compiler::inspect_slice_result_ir(source)?;
    var u8[16] data=[0;16];var runtime::State state=runtime::empty(16);let slices::Ticket parent=opened(ref mut state,ref mut data,1,exclusive);
    let runtime::Capture[1] captures=[runtime::capture(parent,true,true)];let i64[1] values=[0];
    var runtime::Returned result=vm::run_slice_result(ref unit,0,ref captures,ref values,ref mut state,ref mut data,meter::cli_limit())?;
    assert(result.remaining>0 && result.remaining<meter::cli_limit());
    let usize remaining=result.remaining;let usize used=meter::cli_limit()-remaining;let slices::Ticket current=result.held.issued;
    let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,16,remaining)?;
    assert(closed.remaining==result.remaining);drained(ref state);return .ok(used);
}
@test fn void shared_mutable_and_ordinary_nested_calls_fit_the_cli_limit(){
    assert(forward(b"module main;fn ref i32[] f(ref i32[] p){return g(ref p);}fn ref i32[] g(ref i32[] q){return ref q;}fn i32 main(){return 0;}",false).is_ok);
    assert(forward(b"module main;fn ref mut i32[] f(ref mut i32[] p){return g(ref mut p);}fn ref mut i32[] g(ref mut i32[] q){q[0]=42;return ref mut q;}fn i32 main(){return 0;}",true).is_ok);
    assert(forward(b"module main;fn ref mut i32[] f(ref mut i32[] p){p[0]=g();return ref mut p;}fn i32 g(){return 42;}fn i32 main(){return 0;}",true).is_ok);
}

fn Result<usize,errors::Error> operation(ref u8[] source,u8 tag,bool exclusive,u8 op,usize price){
    let ir::Program unit=compiler::inspect_slice_result_ir(source)?;
    var u8[32] data=[0;32];var runtime::State state=runtime::empty(32);let slices::Ticket parent=opened(ref mut state,ref mut data,tag,exclusive);
    let runtime::Capture[1] captures=[runtime::capture(parent,true,true)];
    let runtime::Call call=runtime::enter(ref mut state,runtime::contract(ref unit,0)?,ref captures,32,runtime::cost())?;
    var frames::Frames bindings=frames::empty(ref state);let usize pushed=frames::push(ref unit.body,ref mut bindings,call,0,128,32,0)?;
    var usize pc=unit.body.starts[0];while(pc<unit.body.ends[0] && unit.body.code[pc*8]!=op){pc+=1;}assert(pc<unit.body.ends[0]);
    var i64[128] registers=[0;128];let usize dst=unit.body.code[pc*8+1] as usize;
    if(op!=60){registers[dst]=99;}
    switch(loans::step(ref unit.body,pc,ref mut bindings,ref mut state,ref mut registers,ref mut data,price-1)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8 && e.offset==unit.body.offsets[pc]);}
    };
    assert(data[0]==0);if(op!=60){assert(registers[dst]==99);}
    assert(loans::step(ref unit.body,pc,ref mut bindings,ref mut state,ref mut registers,ref mut data,price)?==0);
    let usize cleared=runtime::abort(ref mut state,32,0)?;drained(ref state);return .ok(0);
}
@test fn void slice_reads_writes_and_utf8_use_the_existing_public_prices(){
    assert(operation(b"module main;fn ref i32[] f(ref i32[] p){if(p[0]==0){return ref p;}return ref p;}fn i32 main(){return 0;}",1,false,58,4134).is_ok);
    assert(operation(b"module main;fn ref mut i64[] f(ref mut i64[] p){p[0]=0;return ref mut p;}fn i32 main(){return 0;}",9,true,60,4146).is_ok);
    assert(operation(b"module main;fn ref u8[] f(ref u8[] p){if(text::valid_utf8(p)){return ref p;}return ref p;}fn i32 main(){return 0;}",10,false,55,4113).is_ok);
}

fn Result<usize,errors::Error> saturated(bool fail){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){return 0;}")?;
    var u8[256] data=[0;256];var runtime::State state=runtime::empty(256);
    let slices::Ticket parent=opened(ref mut state,ref mut data,1,true);
    var usize i=1;while(i<16){let slices::Ticket extra=opened(ref mut state,ref mut data,1,false);i+=1;}
    let runtime::Capture[1] captures=[runtime::capture(parent,true,true)];
    var runtime::Call call=runtime::enter(ref mut state,runtime::contract(ref unit,0)?,ref captures,256,147456)?;
    var slices::Ticket selected=call.issued[0];var authority::State stack=state.runtime.authority;
    var slices::Pool pool=state.runtime.pool;i=0;
    while(i<30){selected=switch(authority::enter_child(ref mut stack,ref mut pool,selected,ref state.runtime.owners,0,4,256,1)){
        case .ok(v):{v}case .err(_):{assert(false);frames::none()}
    };i+=1;}
    state.runtime.authority=stack;state.runtime.pool=pool;
    assert(state.runtime.authority.depth==31 && state.runtime.owners.depth==16);
    if(!fail){
        var runtime::Returned result=runtime::handoff(ref mut state,ref mut call,selected,256,294912)?;
        assert(result.remaining==0);let slices::Ticket current=result.held.issued;
        let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,256,0)?;
        assert(closed.remaining==0);
    }
    let usize cleared=runtime::abort(ref mut state,256,0)?;drained(ref state);return .ok(0);
}
@test fn void full_owner_pool_and_authority_limits_handoff_or_abort_without_extra_fuel(){assert(saturated(false).is_ok && saturated(true).is_ok);}

fn Result<usize,errors::Error> owned(bool short){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p,i32[4] a){return ref mut p;}fn i32 main(){return 0;}")?;
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);let slices::Ticket parent=opened(ref mut state,ref mut data,1,true);
    let layouts::Array shape=switch(layouts::scalar(1,4)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=1,.length=4,.stride=4,.alignment=4,.bytes=16}}};
    let owners::Token input=switch(owners::create(ref shape,7,ref mut data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    let runtime::Capture[2] captures=[runtime::capture(parent,true,true),runtime::capture(frames::none(),false,false)];
    let i64[2] values=[0,0];let owners::Token[2] inputs=[owners::Token{.slot=0,.generation=0},input];
    let usize work=copies::cost(ref unit.body,0,0)?;assert(work==279);
    let usize required=147456+294912+2+work+(unit.body.ends[0]-unit.body.starts[0]);assert(required<meter::cli_limit());
    if(short){
        switch(vm::run_slice_result_owned(ref unit,0,ref captures,ref values,ref inputs,ref mut state,ref mut data,147456+2+work-1)){
            case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}
        };assert(state.runtime.authority.depth==0 && state.runtime.owners.depth==2 && state.runtime.owners.arena.used==32 && data[16]==7);
        assert(slices::length(ref state.runtime.pool,parent,ref state.runtime.owners,64).is_ok);
    }else{
        var runtime::Returned result=vm::run_slice_result_owned(ref unit,0,ref captures,ref values,ref inputs,ref mut state,ref mut data,required)?;
        assert(result.remaining==0 && data[16]==7);let slices::Ticket current=result.held.issued;
        let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,64,0)?;
        assert(closed.remaining==0 && owners::read(ref state.runtime.owners,input,0,ref data).is_ok);
    }
    let usize cleared=runtime::abort(ref mut state,64,0)?;drained(ref state);return .ok(0);
}
@test fn void owned_entry_copy_work_is_prepaid_once_and_fits_the_cli_limit(){assert(owned(true).is_ok && owned(false).is_ok);}

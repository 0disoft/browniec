module tests::m2::slice_scalar_entry;
import compiler as compiler;
import slice_result_ir as ir;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_owners as owners;
import array_slices as slices;
import array_layout as layouts;
import slice_authority as authority;
import errors as errors;
import vm as vm;

fn runtime::Capture empty(){return runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false);}
fn owners::Token root(ref mut runtime::State state,ref mut u8[] data){
    let layouts::Array shape=switch(layouts::scalar(1,4)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=1,.length=4,.stride=4,.alignment=4,.bytes=16}}};
    return switch(owners::create(ref shape,7,data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn slices::Ticket open(ref mut runtime::State state,owners::Token token,bool writer,usize capacity){
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket ticket=switch(if(writer){slices::open_exclusive(ref mut pool,ref mut table,token,0,4,capacity)}else{slices::open(ref mut pool,ref mut table,token,0,4,capacity)}){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};
    state.runtime.pool=pool;state.runtime.owners=table;return ticket;
}
fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
fn Result<usize,errors::Error> scalar(ref u8[] source,i64 expected){
    let ir::Program unit=compiler::inspect_slice_result_ir(source)?;
    var runtime::State state=runtime::empty(256);var u8[256] data=[0;256];
    let runtime::Capture[1] captures=[empty()];let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let execution::Scalar result=vm::run_slice_scalar(ref unit,0,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,10000000)?;
    assert(result.value==expected && result.remaining>0);drained(ref state);return .ok(0);
}
@test fn void ordinary_entries_execute_nested_scalar_array_and_record_calls(){
    assert(scalar(b"module main;fn i32 main(){return add(20,22);}fn i32 add(i32 a,i32 b){return a+b;}",42).is_ok);
    assert(scalar(b"module main;struct P{i32 x;i32 y;}fn i32 main(){let i32[4] a=make();let P p=point();return a[0]+p.x+p.y;}fn i32[4] make(){return [20;4];}fn P point(){return P{.x=21,.y=1};}",42).is_ok);
    assert(scalar(b"module main;fn i64 f(){return -9223372036854775808;}fn i32 main(){return 0;}",-9223372036854775807-1).is_ok);
    assert(scalar(b"module main;fn usize f(){return 18446744073709551615;}fn i32 main(){return 0;}",-1).is_ok);
    assert(scalar(b"module main;fn bool f(){return true;}fn i32 main(){return 0;}",1).is_ok);
}
fn Result<usize,errors::Error> borrowed(bool writer,bool close,bool drop){
    let ir::Program unit=compiler::inspect_slice_result_ir(if(writer){b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[0];}fn i32 main(){return 0;}"}else{b"module main;fn i32 f(ref i32[] p){return p[0]+35;}fn i32 main(){return 0;}"})?;
    var u8[32] data=[0;32];var runtime::State state=runtime::empty(32);let owners::Token token=root(ref mut state,ref mut data);let slices::Ticket parent=open(ref mut state,token,writer,32);
    let runtime::Capture[1] captures=[runtime::capture(parent,close,drop)];let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let execution::Scalar result=vm::run_slice_scalar(ref unit,0,ref captures,ref values,ref inputs[..0],ref mut state,ref mut data,1000000)?;
    assert(result.value==42 && state.runtime.authority.depth==0);
    if(!close){
        assert(slices::length(ref state.runtime.pool,result.resumed[0],ref state.runtime.owners,32).is_ok);
        if(writer){assert(result.resumed[0].generation>parent.generation && !slices::length(ref state.runtime.pool,parent,ref state.runtime.owners,32).is_ok);}
    }else{assert(result.resumed[0].slot==16 && !slices::length(ref state.runtime.pool,parent,ref state.runtime.owners,32).is_ok);}
    if(drop){drained(ref state);}else{assert(state.runtime.owners.slots[token.slot].live);let usize ended=runtime::abort(ref mut state,32,0)?;drained(ref state);}
    return .ok(0);
}
@test fn void successful_scalar_return_restores_retained_inputs_or_closes_and_drops(){
    assert(borrowed(false,false,false).is_ok && borrowed(true,false,false).is_ok);
    assert(borrowed(false,true,false).is_ok && borrowed(true,true,false).is_ok);
    assert(borrowed(false,true,true).is_ok && borrowed(true,true,true).is_ok);
}
fn Result<usize,errors::Error> boundary(bool short){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn i32 main(){return 42;}")?;
    var runtime::State state=runtime::empty(1);var u8[1] data=[0];let runtime::Capture[1] captures=[empty()];let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let usize budget=147456+196608+(unit.body.ends[0]-unit.body.starts[0]);assert(budget<1000000);
    switch(vm::run_slice_scalar(ref unit,0,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,budget-if(short){1}else{0})){
        case .ok(v):{assert(!short && v.value==42 && v.remaining==0);}
        case .err(e):{assert(short && e.kind==8 && e.offset==unit.body.offsets[unit.body.ends[0]-1]);}
    };drained(ref state);return .ok(0);
}
fn Result<usize,errors::Error> failed(bool fuel){
    let ir::Program unit=compiler::inspect_slice_result_ir(if(fuel){b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[0];}fn i32 main(){return 0;}"}else{b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return 1/0;}fn i32 main(){return 0;}"})?;
    var runtime::State state=runtime::empty(32);var u8[32] data=[0;32];let owners::Token token=root(ref mut state,ref mut data);let slices::Ticket parent=open(ref mut state,token,true,32);
    let runtime::Capture[1] captures=[runtime::capture(parent,false,false)];let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    switch(vm::run_slice_scalar(ref unit,0,ref captures,ref values,ref inputs[..0],ref mut state,ref mut data,if(fuel){147457+100000}else{1000000})){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==if(fuel){8}else{7});}
    };assert(data[0]==42);drained(ref state);return .ok(0);
}
@test fn void exact_terminal_budget_and_failures_preserve_first_errors_and_prior_writes(){assert(boundary(false).is_ok && boundary(true).is_ok && failed(false).is_ok && failed(true).is_ok);}
fn Result<usize,errors::Error> owned(){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn i32 f(i32[4] a){return a[0]+35;}fn i32 main(){return 0;}")?;
    var runtime::State state=runtime::empty(64);var u8[64] data=[0;64];let owners::Token token=root(ref mut state,ref mut data);
    let runtime::Capture[1] captures=[empty()];let i64[1] values=[0];let owners::Token[1] inputs=[token];
    let execution::Scalar result=vm::run_slice_scalar(ref unit,0,ref captures,ref values,ref inputs,ref mut state,ref mut data,1000000)?;
    assert(result.value==42 && state.runtime.owners.depth==1 && state.runtime.owners.arena.used==16);
    switch(owners::read(ref state.runtime.owners,token,0,ref data)){case .ok(v):{assert(v==7);}case .err(_):{assert(false);}};
    assert(owners::release(ref mut state.runtime.owners,token,64).is_ok);drained(ref state);return .ok(0);
}
@test fn void owned_entry_parameters_are_value_copies_and_originals_survive_success(){assert(owned().is_ok);}
fn Result<usize,errors::Error> anonymous(){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return 42;}fn i32 main(){return 0;}")?;
    var runtime::State state=runtime::empty(32);var u8[32] data=[0;32];let owners::Token token=root(ref mut state,ref mut data);let slices::Ticket parent=open(ref mut state,token,true,32);
    var authority::State stack=state.runtime.authority;var slices::Pool pool=state.runtime.pool;
    let slices::Ticket child=switch(authority::enter_child(ref mut stack,ref mut pool,parent,ref state.runtime.owners,1,3,32,0)){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};
    state.runtime.authority=stack;state.runtime.pool=pool;
    let runtime::Capture[1] captures=[runtime::capture(child,true,false)];let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let execution::Scalar result=vm::run_slice_scalar(ref unit,0,ref captures,ref values,ref inputs[..0],ref mut state,ref mut data,1000000)?;
    assert(result.value==42 && data[4]==42 && state.runtime.authority.depth==0);
    assert(slices::length(ref state.runtime.pool,result.resumed[0],ref state.runtime.owners,32).is_ok);
    assert(state.runtime.pool.slots[result.resumed[0].slot].view.start==0 && state.runtime.pool.slots[result.resumed[0].slot].view.end==4);
    let usize ended=runtime::abort(ref mut state,32,0)?;drained(ref state);return .ok(0);
}
@test fn void terminal_capture_cleanup_restores_anonymous_caller_parent(){assert(anonymous().is_ok);}
fn Result<usize,errors::Error> rejected(){
    let ir::Program ordinary=compiler::inspect_slice_result_ir(b"module main;fn bool f(bool b){return b;}fn i32 main(){return 0;}")?;
    let ir::Program borrowed=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){return 0;}")?;
    let ir::Program aggregate=compiler::inspect_slice_result_ir(b"module main;fn i32[4] f(){return [7;4];}fn i32 main(){return 0;}")?;
    var runtime::State state=runtime::empty(32);var u8[32] data=[0;32];let owners::Token token=root(ref mut state,ref mut data);let slices::Ticket parent=open(ref mut state,token,true,32);
    let runtime::Capture[1] none=[empty()];let runtime::Capture[1] capture=[runtime::capture(parent,true,true)];
    let i64[1] bad=[2];let i64[1] zero=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    assert(!vm::run_slice_scalar(ref ordinary,0,ref none,ref bad,ref inputs[..0],ref mut state,ref mut data,1000000).is_ok);
    assert(!vm::run_slice_scalar(ref borrowed,0,ref capture,ref zero,ref inputs[..0],ref mut state,ref mut data,1000000).is_ok);
    assert(!vm::run_slice_scalar(ref aggregate,0,ref none[..0],ref zero[..0],ref inputs[..0],ref mut state,ref mut data,1000000).is_ok);
    assert(!vm::run_slice_scalar(ref ordinary,1,ref none[..0],ref zero[..0],ref inputs[..0],ref mut state,ref mut data,147455).is_ok);
    assert(!vm::run_slice_result(ref ordinary,0,ref none,ref zero,ref mut state,ref mut data,1000000).is_ok);
    assert(state.runtime.authority.depth==0 && state.runtime.owners.depth==1 && data[0]==7);
    assert(slices::length(ref state.runtime.pool,parent,ref state.runtime.owners,32).is_ok);
    let usize ended=runtime::abort(ref mut state,32,0)?;drained(ref state);return .ok(0);
}
@test fn void wrong_entry_kinds_values_and_short_admission_preserve_native_inputs(){assert(rejected().is_ok);}
fn Result<usize,errors::Error> rollback(){
    var runtime::State state=runtime::empty(32);var u8[32] data=[0;32];let owners::Token token=root(ref mut state,ref mut data);
    let slices::Ticket input=open(ref mut state,token,false,32);let slices::Ticket alias=open(ref mut state,token,false,32);
    var runtime::Contract contract=runtime::Contract{.tags=[0;8],.arity=1,.selected=0};contract.tags[0]=1;
    let runtime::Capture[1] captures=[runtime::capture(input,true,true)];
    var runtime::Call call=runtime::enter_call(ref mut state,contract,ref captures,32,runtime::cost())?;
    assert(!runtime::leave_call(ref mut state,ref mut call,32,runtime::leave_cost()).is_ok && call.active);
    assert(state.runtime.authority.frame==1 && state.runtime.owners.slots[token.slot].live && data[0]==7);
    assert(slices::length(ref state.runtime.pool,input,ref state.runtime.owners,32).is_ok);
    assert(slices::length(ref state.runtime.pool,call.issued[0],ref state.runtime.owners,32).is_ok);
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    assert(slices::close(ref mut pool,alias,ref mut table,32).is_ok);state.runtime.pool=pool;state.runtime.owners=table;
    let runtime::Resumed result=runtime::leave_call(ref mut state,ref mut call,32,runtime::leave_cost())?;
    assert(result.remaining==0 && result.tickets[0].slot==16 && !call.active);drained(ref state);return .ok(0);
}
@test fn void late_native_capture_drop_failure_rolls_back_the_entire_return(){assert(rollback().is_ok);}

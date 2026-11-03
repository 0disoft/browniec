module tests::m2::slice_result_execution;
import vm as vm;
import compiler as compiler;
import slice_result_ir as ir;
import slice_result_runtime as runtime;
import slice_authority as authority;
import array_slices as slices;
import array_owners as owners;
import array_layout as layout;
import errors as errors;

fn owners::Token create(ref mut runtime::State state,u8 tag,ref mut u8[] data){
    let layout::Array shape=switch(layout::scalar(tag,4)){case .ok(v):{v}case .err(_):{assert(false);layout::Array{.element=1,.length=4,.stride=4,.alignment=4,.bytes=16}}};
    return switch(owners::create(ref shape,0,data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn slices::Ticket open(ref mut runtime::State state,owners::Token root,bool exclusive,usize capacity){
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket t=switch(if(exclusive){slices::open_exclusive(ref mut pool,ref mut table,root,0,4,capacity)}else{slices::open(ref mut pool,ref mut table,root,0,4,capacity)}){
        case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}
    };state.runtime.pool=pool;state.runtime.owners=table;return t;
}
fn i64 read(ref runtime::State state,slices::Ticket t,usize index,ref u8[] data){return switch(slices::read(ref state.runtime.pool,t,ref state.runtime.owners,index,data)){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
fn Result<usize,errors::Error> roundtrip(ref u8[] source,u8 tag,bool exclusive,i64 value){
    let ir::Program unit=compiler::inspect_slice_result_ir(source)?;
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);
    let owners::Token root=create(ref mut state,tag,ref mut data);
    assert(owners::write(ref mut state.runtime.owners,root,1,value,ref mut data).is_ok);
    let slices::Ticket parent=open(ref mut state,root,exclusive,64);
    let runtime::Capture[1] args=[runtime::capture(parent,true,true)];let i64[1] values=[0];
    var runtime::Returned result=vm::run_slice_result(ref unit,0,ref args,ref values,ref mut state,ref mut data,1000000000)?;
    let slices::Ticket current=result.held.issued;
    assert(result.held.exclusive==exclusive && read(ref state,current,1,ref data)==value);
    assert(!slices::length(ref state.runtime.pool,parent,ref state.runtime.owners,64).is_ok);
    if(exclusive){assert(slices::write(ref state.runtime.pool,current,ref state.runtime.owners,0,value,ref mut data).is_ok);}
    let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,64,runtime::cost())?;
    assert(closed.parent.slot==16);drained(ref state);return .ok(0);
}
@test fn void six_scalar_readonly_and_mutable_ir_roundtrips(){
    assert(roundtrip(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){return 0;}",1,false,-42).is_ok);
    assert(roundtrip(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){return 0;}",1,true,-42).is_ok);
    assert(roundtrip(b"module main;fn ref bool[] f(ref bool[] p){return ref p;}fn i32 main(){return 0;}",2,false,1).is_ok);
    assert(roundtrip(b"module main;fn ref mut bool[] f(ref mut bool[] p){return ref mut p;}fn i32 main(){return 0;}",2,true,1).is_ok);
    assert(roundtrip(b"module main;fn ref i64[] f(ref i64[] p){return ref p;}fn i32 main(){return 0;}",9,false,-9223372036854775807-1).is_ok);
    assert(roundtrip(b"module main;fn ref mut i64[] f(ref mut i64[] p){return ref mut p;}fn i32 main(){return 0;}",9,true,-9223372036854775807-1).is_ok);
    assert(roundtrip(b"module main;fn ref u8[] f(ref u8[] p){return ref p;}fn i32 main(){return 0;}",10,false,255).is_ok);
    assert(roundtrip(b"module main;fn ref mut u8[] f(ref mut u8[] p){return ref mut p;}fn i32 main(){return 0;}",10,true,255).is_ok);
    assert(roundtrip(b"module main;fn ref u32[] f(ref u32[] p){return ref p;}fn i32 main(){return 0;}",11,false,4294967295).is_ok);
    assert(roundtrip(b"module main;fn ref mut u32[] f(ref mut u32[] p){return ref mut p;}fn i32 main(){return 0;}",11,true,4294967295).is_ok);
    assert(roundtrip(b"module main;fn ref usize[] f(ref usize[] p){return ref p;}fn i32 main(){return 0;}",12,false,-1).is_ok);
    assert(roundtrip(b"module main;fn ref mut usize[] f(ref mut usize[] p){return ref mut p;}fn i32 main(){return 0;}",12,true,-1).is_ok);
}
fn Result<usize,errors::Error> subview(bool branch,bool exclusive){
    let ir::Program unit=compiler::inspect_slice_result_ir(if(exclusive){b"module main;fn ref mut i32[] f(ref mut i32[] p,bool b){var i32 i=0;while(i<2){p[0]=p[0]+1;i=i+1;}if(b){return ref mut p;}let ref mut i32[] q=ref mut p[1..3];q[0]=42;return ref mut q;}fn i32 main(){return 0;}"}else{b"module main;fn ref i32[] f(ref i32[] p,bool b){if(b){return ref p;}let ref i32[] q=ref p[1..3];return ref q;}fn i32 main(){return 0;}"})?;
    var u8[16] data=[0;16];var runtime::State state=runtime::empty(16);let owners::Token root=create(ref mut state,1,ref mut data);
    let slices::Ticket parent=open(ref mut state,root,exclusive,16);
    let runtime::Capture[2] args=[runtime::capture(parent,false,false),runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[2] values=[0,if(branch){1}else{0}];
    var runtime::Returned result=vm::run_slice_result(ref unit,0,ref args,ref values,ref mut state,ref mut data,1000000000)?;
    let usize length=if(branch){4}else{2};assert(result.held.view.end-result.held.view.start==length);
    if(exclusive){assert(read(ref state,result.held.issued,0,ref data)==if(branch){2}else{42});}
    let slices::Ticket current=result.held.issued;
    let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,16,runtime::cost())?;
    if(exclusive){assert(closed.parent.slot<16 && read(ref state,closed.parent,0,ref data)==2);}
    let usize cleared=runtime::abort(ref mut state,16,0)?;drained(ref state);return .ok(0);
}
@test fn void branches_loops_and_lexical_subviews_execute(){assert(subview(false,false).is_ok && subview(true,false).is_ok && subview(false,true).is_ok && subview(true,true).is_ok);}
fn Result<usize,errors::Error> forwarded(bool exclusive){
    let ir::Program unit=compiler::inspect_slice_result_ir(if(exclusive){b"module main;fn ref mut i32[] f(ref mut i32[] p,ref mut i32[] q){return g(ref mut q,ref mut p);}fn ref mut i32[] g(ref mut i32[] a,ref mut i32[] b){b[1]=42;return ref mut b;}fn i32 main(){return 0;}"}else{b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q){return g(ref q,ref p);}fn ref i32[] g(ref i32[] a,ref i32[] b){let ref i32[] r=ref b[1..3];return ref r;}fn i32 main(){return 0;}"})?;
    var u8[32] data=[0;32];var runtime::State state=runtime::empty(32);let owners::Token first=create(ref mut state,1,ref mut data);let owners::Token second=create(ref mut state,1,ref mut data);
    let slices::Ticket a=open(ref mut state,first,exclusive,32);let slices::Ticket b=open(ref mut state,second,exclusive,32);
    let runtime::Capture[2] args=[runtime::capture(a,true,true),runtime::capture(b,true,true)];let i64[2] values=[0,0];
    var runtime::Returned result=vm::run_slice_result(ref unit,0,ref args,ref values,ref mut state,ref mut data,1000000000)?;
    assert(result.held.view.root.slot==first.slot && !state.runtime.owners.slots[second.slot].live);
    if(exclusive){assert(read(ref state,result.held.issued,1,ref data)==42);}
    let slices::Ticket current=result.held.issued;let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,32,runtime::cost())?;
    drained(ref state);return .ok(0);
}
@test fn void forwarding_remaps_destinations_and_drops_unselected_captures(){assert(forwarded(false).is_ok && forwarded(true).is_ok);}
fn Result<usize,errors::Error> recursive(i64 n,bool expected){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p,i32 n){if(n==0){let ref mut i32[] r=ref mut p[1..3];return ref mut r;}return f(ref mut p,n-1);}fn i32 main(){return 0;}")?;
    var u8[16] data=[0;16];var runtime::State state=runtime::empty(16);let owners::Token root=create(ref mut state,1,ref mut data);let slices::Ticket parent=open(ref mut state,root,true,16);
    let runtime::Capture[2] args=[runtime::capture(parent,true,true),runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];let i64[2] values=[0,n];
    switch(vm::run_slice_result(ref unit,0,ref args,ref values,ref mut state,ref mut data,1000000000)){
        case .ok(r):{assert(expected);var runtime::Held held=r.held;assert(held.view.start==1 && held.view.end==3);let slices::Ticket current=held.issued;let runtime::Closed closed=runtime::close(ref mut state,ref mut held,current,16,runtime::cost())?;}
        case .err(e):{assert(!expected && e.kind==12);}
    };drained(ref state);return .ok(0);
}
@test fn void recursive_frames_restore_and_depth_failure_drains(){assert(recursive(5,true).is_ok && recursive(40,false).is_ok);}
fn Result<usize,errors::Error> fuel_failure(){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){p[0]=42;return ref mut p;}fn i32 main(){return 0;}")?;
    var u8[16] data=[0;16];var runtime::State state=runtime::empty(16);let owners::Token root=create(ref mut state,1,ref mut data);let slices::Ticket parent=open(ref mut state,root,true,16);
    let runtime::Capture[1] args=[runtime::capture(parent,true,true)];let i64[1] values=[0];
    switch(vm::run_slice_result(ref unit,0,ref args,ref values,ref mut state,ref mut data,runtime::cost()+100000)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);var usize pc=unit.body.starts[0];while(unit.body.code[pc*8]!=65){pc+=1;}assert(e.offset==unit.body.offsets[pc]);}
    };assert(data[0]==42);drained(ref state);return .ok(0);
}
@test fn void return_fuel_failure_preserves_writes_and_first_error(){assert(fuel_failure().is_ok);}
fn Result<usize,errors::Error> rejected_before_entry(){
    var ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){p[0]=42;return ref mut p;}fn i32 main(){return 0;}")?;
    var u8[16] data=[0;16];var runtime::State state=runtime::empty(16);let owners::Token root=create(ref mut state,1,ref mut data);let slices::Ticket parent=open(ref mut state,root,true,16);
    let runtime::Capture[1] args=[runtime::capture(parent,true,true)];let i64[1] values=[0];
    var usize pc=0;while(unit.body.code[pc*8]!=65){pc+=1;}unit.body.code[pc*8+2]=127;
    switch(vm::run_slice_result(ref unit,0,ref args,ref values,ref mut state,ref mut data,1000000000)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
    assert(data[0]==0 && state.runtime.authority.depth==0 && state.runtime.owners.depth==1 && read(ref state,parent,0,ref data)==0);
    let usize cleared=runtime::abort(ref mut state,16,0)?;return .ok(0);
}
@test fn void invalid_result_identity_rejects_before_any_write(){assert(rejected_before_entry().is_ok);}

fn Result<usize,errors::Error> descendants(){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){return 0;}")?;
    var u8[16] data=[0;16];var runtime::State state=runtime::empty(16);let owners::Token root=create(ref mut state,1,ref mut data);let slices::Ticket parent=open(ref mut state,root,true,16);
    let runtime::Capture[1] args=[runtime::capture(parent,false,false)];let i64[1] values=[0];
    var runtime::Returned result=vm::run_slice_result(ref unit,0,ref args,ref values,ref mut state,ref mut data,1000000000)?;
    var authority::State stack=state.runtime.authority;var slices::Pool pool=state.runtime.pool;
    let slices::Ticket child=switch(authority::enter_child(ref mut stack,ref mut pool,result.held.issued,ref state.runtime.owners,1,3,16,0)){case .ok(v):{v}case .err(_):{assert(false);parent}};
    state.runtime.authority=stack;state.runtime.pool=pool;let slices::Ticket old=result.held.issued;
    assert(!runtime::close(ref mut state,ref mut result.held,old,16,runtime::cost()).is_ok && result.held.active);
    assert(!slices::length(ref state.runtime.pool,old,ref state.runtime.owners,16).is_ok);
    assert(slices::write(ref state.runtime.pool,child,ref state.runtime.owners,0,42,ref mut data).is_ok);
    stack=state.runtime.authority;pool=state.runtime.pool;
    let slices::Ticket current=switch(authority::leave_child(ref mut stack,ref mut pool,child,ref state.runtime.owners,16,0)){case .ok(v):{v}case .err(_):{assert(false);parent}};
    state.runtime.authority=stack;state.runtime.pool=pool;
    let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,16,runtime::cost())?;
    assert(read(ref state,closed.parent,1,ref data)==42);
    let usize cleared=runtime::abort(ref mut state,16,0)?;drained(ref state);return .ok(0);
}
@test fn void returned_descendants_suspend_parent_until_last_close(){assert(descendants().is_ok);}
fn Result<usize,errors::Error> private_gates(){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p,bool b){if(b){p[0]=42;}return ref mut p;}fn i32 main(){return 0;}")?;
    var u8[16] data=[0;16];var runtime::State state=runtime::empty(16);let owners::Token root=create(ref mut state,1,ref mut data);let slices::Ticket parent=open(ref mut state,root,true,16);
    let slices::Ticket none=slices::Ticket{.slot=16,.generation=0};
    let runtime::Capture[2] args=[runtime::capture(parent,true,true),runtime::capture(none,false,false)];let i64[2] bad=[0,2];let i64[2] good=[0,1];
    assert(!vm::run_slice_result(ref unit,0,ref args,ref bad,ref mut state,ref mut data,1000000000).is_ok);
    assert(!vm::run_slice_result(ref unit,0,ref args,ref good,ref mut state,ref mut data,runtime::cost()-1).is_ok);
    let runtime::Capture[2] stale=[runtime::capture(slices::Ticket{.slot=parent.slot,.generation=parent.generation+1},true,true),runtime::capture(none,false,false)];
    assert(!vm::run_slice_result(ref unit,0,ref stale,ref good,ref mut state,ref mut data,1000000000).is_ok);
    let ir::Program owned=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){let i32[1] a=[42;1];return ref mut p;}fn i32 main(){return 0;}")?;
    let ir::Program ordinary=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){let i32 n=g();return ref mut p;}fn i32 g(){return 1;}fn i32 main(){return 0;}")?;
    let runtime::Capture[1] single=[runtime::capture(parent,true,true)];let i64[1] value=[0];
    assert(!vm::run_slice_result(ref owned,0,ref single,ref value,ref mut state,ref mut data,1000000000).is_ok);
    assert(!vm::run_slice_result(ref ordinary,0,ref single,ref value,ref mut state,ref mut data,1000000000).is_ok);
    assert(read(ref state,parent,0,ref data)==0 && state.runtime.authority.depth==0 && state.runtime.owners.depth==1);
    let usize cleared=runtime::abort(ref mut state,16,0)?;drained(ref state);return .ok(0);
}
@test fn void unsupported_effects_values_and_stale_inputs_reject_before_entry(){assert(private_gates().is_ok);}
fn Result<usize,errors::Error> alias_empty(bool invalid){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref u8[] f(ref u8[] p){{let ref u8[] q=ref p[0..2];if(q.len==2 && !text::valid_utf8(q)){return ref q;}}let ref u8[] empty=ref p[p.len..];return ref empty;}fn i32 main(){return 0;}")?;
    var u8[16] data=[0;16];var runtime::State state=runtime::empty(16);let owners::Token root=create(ref mut state,10,ref mut data);
    if(invalid){assert(owners::write(ref mut state.runtime.owners,root,0,255,ref mut data).is_ok);}
    let slices::Ticket parent=open(ref mut state,root,false,16);let runtime::Capture[1] args=[runtime::capture(parent,true,true)];let i64[1] values=[0];
    var runtime::Returned result=vm::run_slice_result(ref unit,0,ref args,ref values,ref mut state,ref mut data,1000000000)?;
    assert(result.held.view.end-result.held.view.start==if(invalid){2}else{0});
    let slices::Ticket current=result.held.issued;let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,16,runtime::cost())?;
    drained(ref state);return .ok(0);
}
@test fn void scoped_alias_cleanup_utf8_and_empty_results(){assert(alias_empty(false).is_ok && alias_empty(true).is_ok);}


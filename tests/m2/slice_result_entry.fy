module tests::m2::slice_result_entry;
import vm as vm;
import compiler as compiler;
import slice_result_ir as ir;
import slice_result_runtime as runtime;
import slice_authority as authority;
import array_slices as slices;
import array_owners as owners;
import array_layout as layout;
import errors as errors;
import struct_call_vm as calls;
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

fn void same(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live);
        assert(x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element);
        assert(x.length==y.length && x.record==y.record && x.alignment==y.alignment);i+=1;
    }
}

fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};}
fn Result<usize,errors::Error> array_case(ref u8[] source,u8 tag,i64 fill,i64 expected){
    let ir::Program unit=compiler::inspect_slice_result_ir(source)?;
    var u8[512] data=[0;512];var runtime::State state=runtime::empty(512);
    let owners::Token root=create(ref mut state,1,ref mut data);let slices::Ticket parent=open(ref mut state,root,true,512);
    let layout::Array shape=switch(layout::scalar(tag,4)){case .ok(v):{v}case .err(_):{assert(false);layout::Array{.element=1,.length=4,.stride=4,.alignment=4,.bytes=16}}};
    let owners::Token input=token(owners::create(ref shape,fill,ref mut data,ref mut state.runtime.owners));
    let usize arity=unit.body.arities[0];let runtime::Capture[3] captures=[runtime::capture(parent,true,true),runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false),runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let owners::Token[3] inputs=[owners::Token{.slot=0,.generation=0},input,input];let i64[3] values=[0;3];
    var runtime::Returned result=vm::run_slice_result_owned(ref unit,0,ref captures[..arity],ref values[..arity],ref inputs[..arity],ref mut state,ref mut data,1000000000)?;
    assert(read(ref state,result.held.issued,0,ref data)==expected);
    let i64 original=switch(owners::read(ref state.runtime.owners,input,0,ref data)){case .ok(v):{v}case .err(_):{assert(false);0}};assert(original==fill);
    var usize live=0;var usize i=0;while(i<16){if(state.runtime.owners.slots[i].live){live+=1;}i+=1;}assert(live==2);
    let slices::Ticket current=result.held.issued;let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,512,runtime::cost())?;
    assert(owners::release(ref mut state.runtime.owners,input,512).is_ok);drained(ref state);return .ok(0);
}
@test fn void six_native_array_element_types_copy_independently(){
    assert(array_case(b"module main;fn ref mut i32[] f(ref mut i32[] p,i32[4] a){var i32[4] b=a;b[0]=42;p[0]=b[0];return ref mut p;}fn i32 main(){return 0;}",1,20,42).is_ok);
    assert(array_case(b"module main;fn ref mut i32[] f(ref mut i32[] p,i64[4] a){var i64[4] b=a;b[0]=-9223372036854775808;if(b[0]==-9223372036854775808 && a[0]==9223372036854775807){p[0]=42;}return ref mut p;}fn i32 main(){return 0;}",9,9223372036854775807,42).is_ok);
    assert(array_case(b"module main;fn ref mut i32[] f(ref mut i32[] p,u8[4] a){var u8[4] b=a;b[0]=255;if(b[0]==255 && a[0]==0){p[0]=42;}return ref mut p;}fn i32 main(){return 0;}",10,0,42).is_ok);
    assert(array_case(b"module main;fn ref mut i32[] f(ref mut i32[] p,u32[4] a){var u32[4] b=a;b[0]=0;if(b[0]==0 && a[0]==4294967295){p[0]=42;}return ref mut p;}fn i32 main(){return 0;}",11,4294967295,42).is_ok);
    assert(array_case(b"module main;fn ref mut i32[] f(ref mut i32[] p,usize[4] a){var usize[4] b=a;b[0]=0;if(b[0]==0 && a[0]==18446744073709551615){p[0]=42;}return ref mut p;}fn i32 main(){return 0;}",12,-1,42).is_ok);
    assert(array_case(b"module main;fn ref mut i32[] f(ref mut i32[] p,bool[4] a){var bool[4] b=a;b[0]=false;if(!b[0] && a[0]){p[0]=42;}return ref mut p;}fn i32 main(){return 0;}",2,1,42).is_ok);
}
fn Result<usize,errors::Error> mixed(ref u8[] source,ref i64[] cells,i64 expected){
    let ir::Program unit=compiler::inspect_slice_result_ir(source)?;
    var u8[512] data=[0;512];var runtime::State state=runtime::empty(512);
    let owners::Token root=create(ref mut state,1,ref mut data);let slices::Ticket parent=open(ref mut state,root,true,512);
    let owners::Token array=create(ref mut state,1,ref mut data);
    assert(owners::write(ref mut state.runtime.owners,array,0,3,ref mut data).is_ok);
    let usize site=unit.body.record_parameters[unit.body.register_starts[0]+2] as usize-1;
    let usize nominal=unit.body.records.records[site] as usize;
    let owners::Token record=token(owners::create_record(ref unit.body.records.layouts,nominal,cells,ref mut data,ref mut state.runtime.owners));
    let u8[512] saved=data;let usize used=state.runtime.owners.arena.used;
    let runtime::Capture empty=runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false);
    let runtime::Capture[4] captures=[runtime::capture(parent,true,true),empty,empty,empty];
    let owners::Token[4] inputs=[owners::Token{.slot=0,.generation=0},array,record,owners::Token{.slot=0,.generation=0}];let i64[4] values=[0,0,0,2];
    var runtime::Returned result=vm::run_slice_result_owned(ref unit,0,ref captures,ref values,ref inputs,ref mut state,ref mut data,1000000000)?;
    assert(read(ref state,result.held.issued,0,ref data)==expected);
    var usize i=16;while(i<used){assert(data[i]==saved[i]);i+=1;}
    var usize live=0;i=0;while(i<16){if(state.runtime.owners.slots[i].live){live+=1;}i+=1;}assert(live==3);
    let slices::Ticket current=result.held.issued;let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,512,runtime::cost())?;
    assert(owners::release(ref mut state.runtime.owners,record,512).is_ok && owners::release(ref mut state.runtime.owners,array,512).is_ok);drained(ref state);return .ok(0);
}
@test fn void mixed_native_record_array_scalar_inputs_forward_through_ordinary_calls(){
    let i64[2] nested=[20,1];
    assert(mixed(b"module main;struct P{i32 x;}struct R{P p;bool ok;}fn ref mut i32[] f(ref mut i32[] p,i32[4] a,R r,i32 n){let R q=bump(r);let i32[4] b=take(a);if(q.ok){p[0]=q.p.x+b[0]+n;}return pass(ref mut p);}fn R bump(R r){var R q=r;q.p.x=30;return q;}fn i32[4] take(i32[4] a){var i32[4] b=a;b[0]=10;return b;}fn ref mut i32[] pass(ref mut i32[] p){return ref mut p;}fn i32 main(){return 0;}",ref nested,42).is_ok);
    let i64[6] edges=[1,255,-2147483648,-9223372036854775808,4294967295,-1];
    assert(mixed(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn ref mut i32[] run(ref mut i32[] p,i32[4] a,P r,i32 n){if(r.a && r.b==255 && r.c==-2147483648 && r.d==-9223372036854775808 && r.e==4294967295 && r.f==18446744073709551615){p[0]=37+a[0]+n;}return ref mut p;}fn i32 main(){return 0;}",ref edges,42).is_ok);
}
fn Result<usize,errors::Error> shared(){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref i32[] f(ref i32[] p,i32[4] a){let i32 n=a[0];return ref p;}fn i32 main(){return 0;}")?;
    var u8[128] data=[0;128];var runtime::State state=runtime::empty(128);let owners::Token root=create(ref mut state,1,ref mut data);
    assert(owners::write(ref mut state.runtime.owners,root,0,42,ref mut data).is_ok);let slices::Ticket parent=open(ref mut state,root,false,128);
    let runtime::Capture[2] captures=[runtime::capture(parent,false,false),runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let owners::Token[2] inputs=[owners::Token{.slot=0,.generation=0},root];let i64[2] values=[0,0];
    var runtime::Returned result=vm::run_slice_result_owned(ref unit,0,ref captures,ref values,ref inputs,ref mut state,ref mut data,1000000000)?;
    assert(read(ref state,result.held.issued,0,ref data)==42 && read(ref state,parent,0,ref data)==42);
    let slices::Ticket current=result.held.issued;let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,128,runtime::cost())?;
    assert(read(ref state,parent,0,ref data)==42);let usize cleared=runtime::abort(ref mut state,128,0)?;drained(ref state);return .ok(0);
}
@test fn void duplicate_value_inputs_copy_separately_and_shared_source_can_also_copy(){
    assert(array_case(b"module main;fn ref mut i32[] f(ref mut i32[] p,i32[4] a,i32[4] b){var i32[4] c=a;c[0]=20;p[0]=c[0]+b[0];return ref mut p;}fn i32 main(){return 0;}",1,22,42).is_ok);
    assert(shared().is_ok);
}
fn Result<usize,errors::Error> rejected(usize mode){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;struct P{i32 x;bool ok;}struct Q{i32 x;bool ok;}fn ref mut i32[] f(ref mut i32[] p,i32[4] a,P r){let Q q=Q{.x=1,.ok=true};p[0]=a[0]+r.x+q.x;return ref mut p;}fn i32 main(){return 0;}")?;
    let usize capacity=if(mode==0){56}else{256};var u8[256] data=[0;256];var runtime::State state=runtime::empty(capacity);
    let owners::Token root=create(ref mut state,1,ref mut data[..capacity]);let slices::Ticket parent=open(ref mut state,root,true,capacity);
    let u8 tag=if(mode==2){10}else{1};let usize length=if(mode==3){3}else{4};
    let layout::Array shape=switch(layout::scalar(tag,length)){case .ok(v):{v}case .err(_):{assert(false);layout::Array{.element=1,.length=4,.stride=4,.alignment=4,.bytes=16}}};
    let owners::Token array=token(owners::create(ref shape,3,ref mut data[..capacity],ref mut state.runtime.owners));
    let usize site=unit.body.record_parameters[unit.body.register_starts[0]+2] as usize-1;
    let usize nominal=unit.body.records.records[site] as usize;
    let usize actual=if(mode==4){if(nominal==0){1}else{0}}else{nominal};let i64[2] cells=[20,1];
    let owners::Token record=token(owners::create_record(ref unit.body.records.layouts,actual,ref cells,ref mut data[..capacity],ref mut state.runtime.owners));
    if(mode==5){data[state.runtime.owners.slots[record.slot].base+4]=2;}
    if(mode==12){let layout::Array extra=layout::Array{.element=1,.length=1,.stride=4,.alignment=4,.bytes=4};var usize i=0;while(i<12){let owners::Token t=token(owners::create(ref extra,0,ref mut data[..capacity],ref mut state.runtime.owners));i+=1;}}
    let u8[256] saved=data;let owners::Table before=state.runtime.owners;let slices::Pool old=state.runtime.pool;
    let runtime::Capture empty=runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false);
    var runtime::Capture[3] captures=[runtime::capture(parent,false,false),empty,empty];
    var owners::Token[3] inputs=[owners::Token{.slot=0,.generation=0},array,record];var i64[3] values=[0;3];
    if(mode==1){inputs[1]=owners::Token{.slot=array.slot,.generation=array.generation+1};}
    if(mode==7){inputs[0]=array;}if(mode==8){values[1]=1;}if(mode==9){captures[1]=captures[0];}if(mode==13){inputs[1]=root;}
    let usize length_inputs=if(mode==6){2}else{3};let usize fuel=if(mode==11){runtime::cost()+calls::cost(ref unit.body,0,0)?-1}else{1000000000};
    let Result<runtime::Returned,errors::Error> result=if(mode==10){vm::run_slice_result(ref unit,0,ref captures,ref values,ref mut state,ref mut data[..capacity],fuel)}else{vm::run_slice_result_owned(ref unit,0,ref captures,ref values,ref inputs[..length_inputs],ref mut state,ref mut data[..capacity],fuel)};
    switch(result){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==if(mode==0 || mode==12){13}else if(mode==11){8}else{5});}};
    same(ref state.runtime.owners,ref before);assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0);
    var usize i=0;while(i<256){assert(data[i]==saved[i]);i+=1;}
    i=0;while(i<16){let slices::Slot a=state.runtime.pool.slots[i];let slices::Slot b=old.slots[i];
        assert(a.generation==b.generation && a.live==b.live && a.exclusive==b.exclusive);
        assert(a.view.root.slot==b.view.root.slot && a.view.root.generation==b.view.root.generation && a.view.element==b.view.element && a.view.length==b.view.length && a.view.start==b.view.start && a.view.end==b.view.end);
        assert(a.lease.generation==b.lease.generation && a.lease.root.slot==b.lease.root.slot && a.lease.root.generation==b.lease.root.generation);i+=1;
    }
    assert(read(ref state,parent,0,ref data)==0);let usize cleared=runtime::abort(ref mut state,capacity,0)?;return .ok(0);
}
@test fn void malformed_native_argument_vectors_and_legacy_entry_preserve_inputs(){var usize i=6;while(i<=10){assert(rejected(i).is_ok);i+=1;}}
@test fn void stale_type_length_nominal_bool_and_exclusive_sources_reject_atomically(){var usize i=1;while(i<=5){assert(rejected(i).is_ok);i+=1;}assert(rejected(13).is_ok);}
@test fn void late_quota_owner_and_prepaid_fuel_failure_preserve_all_native_metadata(){assert(rejected(0).is_ok && rejected(11).is_ok && rejected(12).is_ok);}
fn Result<usize,errors::Error> failed(bool fuel){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;struct P{i32 x;}fn ref mut i32[] f(ref mut i32[] p,i32[4] a,P r){p[0]=42;let i32 n=bad();return ref mut p;}fn i32 bad(){return 1/0;}fn i32 main(){return 0;}")?;
    var u8[256] data=[0;256];var runtime::State state=runtime::empty(256);let owners::Token root=create(ref mut state,1,ref mut data);let slices::Ticket parent=open(ref mut state,root,true,256);
    let owners::Token array=create(ref mut state,1,ref mut data);let i64[1] cells=[20];let usize site=unit.body.record_parameters[2] as usize-1;
    let owners::Token record=token(owners::create_record(ref unit.body.records.layouts,unit.body.records.records[site] as usize,ref cells,ref mut data,ref mut state.runtime.owners));
    let runtime::Capture empty=runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false);let runtime::Capture[3] captures=[runtime::capture(parent,true,true),empty,empty];
    let i64[3] values=[0;3];let owners::Token[3] inputs=[owners::Token{.slot=0,.generation=0},array,record];
    let usize budget=if(fuel){runtime::cost()+calls::cost(ref unit.body,0,0)?+100000}else{1000000000};
    switch(vm::run_slice_result_owned(ref unit,0,ref captures,ref values,ref inputs,ref mut state,ref mut data,budget)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==if(fuel){8}else{7});}};
    assert(data[0]==42);drained(ref state);assert(!owners::read(ref state.runtime.owners,array,0,ref data).is_ok);return .ok(0);
}
@test fn void execution_failure_drains_native_originals_and_guest_copies_but_keeps_writes(){assert(failed(false).is_ok && failed(true).is_ok);}

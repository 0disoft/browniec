module tests::m2::slice_result_runtime;
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
fn runtime::Returned returned(ref mut runtime::State state,ref mut runtime::Call call,slices::Ticket selected,usize capacity){return switch(runtime::handoff(state,call,selected,capacity,runtime::handoff_cost())){case .ok(v):{assert(v.remaining==0);v}case .err(_):{assert(false);runtime::Returned{.held=runtime::Held{.issued=selected,.view=call.views[0],.exclusive=false,.close_parent=false,.drop=false,.depth=0,.frame=0,.active=false},.resumed=[slices::Ticket{.slot=16,.generation=0};8],.remaining=0}}};}
fn slices::Ticket ended(ref mut runtime::State state,ref mut runtime::Held held,slices::Ticket current,usize capacity){return switch(runtime::close(state,held,current,capacity,0)){case .ok(v):{assert(v.remaining==0);v.parent}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
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
fn void scalar_roundtrip(ref u8[] source,u8 tag,i64 value){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);let owners::Token root=create(ref mut state,tag,ref mut data);
    let usize written=size(owners::write(ref mut state.runtime.owners,root,1,value,ref mut data));
    let runtime::Contract c=binding(source,0);let bool exclusive=(c.tags[0]&128)!=0;
    let slices::Ticket parent=open(ref mut state,root,exclusive,64);let runtime::Capture[1] args=[runtime::capture(parent,true,true)];
    var runtime::Call call=entered(ref mut state,c,ref args,64);let slices::Ticket selected=call.issued[0];var runtime::Returned result=returned(ref mut state,ref mut call,selected,64);
    let slices::Ticket current=result.held.issued;assert(cell(slices::read(ref state.runtime.pool,current,ref state.runtime.owners,1,ref data))==value);
    assert(!owners::release(ref mut state.runtime.owners,root,64).is_ok);
    if(exclusive){let usize wrote=size(slices::write(ref state.runtime.pool,current,ref state.runtime.owners,0,value,ref mut data));}
    let slices::Ticket absent=ended(ref mut state,ref mut result.held,current,64);assert(absent.slot==16 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
}
fn void same_view(owners::View a,owners::View b){assert(a.root.slot==b.root.slot && a.root.generation==b.root.generation && a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end);}
fn void same_ticket(slices::Ticket a,slices::Ticket b){assert(a.slot==b.slot && a.generation==b.generation);}
fn void unchanged(ref runtime::State a,ref runtime::State b){
    assert(a.runtime.owners.depth==b.runtime.owners.depth && a.runtime.owners.arena.used==b.runtime.owners.arena.used && a.runtime.owners.arena.limit==b.runtime.owners.arena.limit);
    assert(a.runtime.authority.depth==b.runtime.authority.depth && a.runtime.authority.frame==b.runtime.authority.frame);
    var usize i=0;while(i<16){
        let slices::Slot x=a.runtime.pool.slots[i];let slices::Slot y=b.runtime.pool.slots[i];same_view(x.view,y.view);
        assert(x.generation==y.generation && x.live==y.live && x.exclusive==y.exclusive && x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation);
        let owners::Owner u=a.runtime.owners.slots[i];let owners::Owner v=b.runtime.owners.slots[i];
        assert(u.generation==v.generation && u.occupied==v.occupied && u.live==v.live && u.reading==v.reading && u.writing==v.writing && u.read_generation==v.read_generation && u.mark==v.mark && u.base==v.base && u.end==v.end && u.element==v.element && u.length==v.length && u.record==v.record && u.alignment==v.alignment && a.runtime.owners.order[i]==b.runtime.owners.order[i]);i+=1;
    }
    i=0;while(i<31){
        assert(a.runtime.authority.counts[i]==b.runtime.authority.counts[i] && a.runtime.authority.reserves[i]==b.runtime.authority.reserves[i] && a.runtime.authority.kinds[i]==b.runtime.authority.kinds[i] && a.runtime.authority.frames[i]==b.runtime.authority.frames[i]);
        let x=a.runtime.authority.children[i];let y=b.runtime.authority.children[i];same_view(x.parent.view,y.parent.view);same_view(x.selected,y.selected);same_ticket(x.issued,y.issued);assert(x.parent.generation==y.parent.generation && x.depth==y.depth && x.active==y.active);i+=1;
    }
    i=0;while(i<248){same_ticket(a.runtime.authority.tickets[i],b.runtime.authority.tickets[i]);same_view(a.runtime.authority.leases[i].view,b.runtime.authority.leases[i].view);assert(a.runtime.authority.leases[i].generation==b.runtime.authority.leases[i].generation);i+=1;}
}

@test
fn void shared_return_transfers_ticket_and_pins_owner_after_callee_cleanup(){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);let owners::Token root=create(ref mut state,1,ref mut data);
    let usize written=size(owners::write(ref mut state.runtime.owners,root,1,42,ref mut data));
    let slices::Ticket parent=open(ref mut state,root,false,64);
    let runtime::Capture[1] args=[runtime::capture(parent,false,false)];
    var runtime::Call call=entered(ref mut state,binding(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){return 42;}",0),ref args,64);
    let slices::Ticket selected=call.issued[0];var runtime::Returned result=returned(ref mut state,ref mut call,selected,64);
    assert(!call.active && !slices::length(ref state.runtime.pool,selected,ref state.runtime.owners,64).is_ok);
    assert(cell(slices::read(ref state.runtime.pool,result.held.issued,ref state.runtime.owners,1,ref data))==42);
    close_ticket(ref mut state,parent,64);
    assert(!owners::release(ref mut state.runtime.owners,root,64).is_ok);
    let slices::Ticket current=result.held.issued;let slices::Ticket resumed=ended(ref mut state,ref mut result.held,current,64);
    assert(resumed.slot==16 && !result.held.active && owners::release(ref mut state.runtime.owners,root,64).is_ok);
    assert(!runtime::handoff(ref mut state,ref mut call,current,64,runtime::handoff_cost()).is_ok);
}

@test
fn void exclusive_descendant_result_keeps_parent_suspended_until_last_child_ends(){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);let owners::Token root=create(ref mut state,1,ref mut data);
    let slices::Ticket parent=open(ref mut state,root,true,64);let runtime::Capture[1] args=[runtime::capture(parent,false,false)];
    var runtime::Call call=entered(ref mut state,binding(b"module main;fn ref mut i32[] f(ref mut i32[] p){let ref mut i32[] q=ref mut p[1..3];return ref mut q;}fn i32 main(){return 42;}",0),ref args,64);
    let slices::Ticket source=call.issued[0];let slices::Ticket leaf=child(ref mut state,source,1,3,64);
    var runtime::Returned result=returned(ref mut state,ref mut call,leaf,64);let slices::Ticket returned_view=result.held.issued;
    assert(state.runtime.authority.frame==0 && state.runtime.authority.depth==1);
    assert(!slices::read(ref state.runtime.pool,parent,ref state.runtime.owners,0,ref data).is_ok && !owners::release(ref mut state.runtime.owners,root,64).is_ok);
    let usize written=size(slices::write(ref state.runtime.pool,returned_view,ref state.runtime.owners,0,42,ref mut data));
    let slices::Ticket grandchild=child(ref mut state,returned_view,0,2,64);let runtime::State before=state;
    assert(!runtime::close(ref mut state,ref mut result.held,grandchild,64,0).is_ok);unchanged(ref state,ref before);
    let slices::Ticket current=restore(ref mut state,grandchild,64);let slices::Ticket resumed=ended(ref mut state,ref mut result.held,current,64);
    assert(cell(slices::read(ref state.runtime.pool,resumed,ref state.runtime.owners,1,ref data))==42 && size(slices::length(ref state.runtime.pool,resumed,ref state.runtime.owners,64))==4);
    assert(!slices::length(ref state.runtime.pool,returned_view,ref state.runtime.owners,64).is_ok);
    close_ticket(ref mut state,resumed,64);assert(owners::release(ref mut state.runtime.owners,root,64).is_ok);
}

@test
fn void only_selected_temporary_owner_survives_and_other_modes_clean_up(){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);
    let owners::Token other=create(ref mut state,1,ref mut data);let owners::Token selected=create(ref mut state,10,ref mut data);
    let slices::Ticket writer=open(ref mut state,other,true,64);let slices::Ticket reader=open(ref mut state,selected,false,64);
    let runtime::Capture[3] args=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false),runtime::capture(writer,true,true),runtime::capture(reader,true,true)];
    var runtime::Call call=entered(ref mut state,binding(b"module main;fn ref u8[] f(i32 n,ref mut i32[] p,ref u8[] q){return ref q;}fn i32 main(){return 42;}",0),ref args,64);
    let slices::Ticket current=call.issued[2];var runtime::Returned result=returned(ref mut state,ref mut call,current,64);
    assert(!owners::view(ref state.runtime.owners,other,0,0,64).is_ok && !owners::release(ref mut state.runtime.owners,selected,64).is_ok);
    assert(result.held.drop && !slices::length(ref state.runtime.pool,reader,ref state.runtime.owners,64).is_ok);
    let slices::Ticket view=result.held.issued;let slices::Ticket unused=ended(ref mut state,ref mut result.held,view,64);
    assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0 && state.runtime.authority.depth==0);
}

@test
fn void nested_forwarding_consumes_inner_result_without_resuming_original_parent(){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);let owners::Token root=create(ref mut state,1,ref mut data);
    let slices::Ticket parent=open(ref mut state,root,true,64);let runtime::Contract c=binding(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){return 42;}",0);
    let runtime::Capture[1] first=[runtime::capture(parent,false,false)];var runtime::Call outer=entered(ref mut state,c,ref first,64);
    let slices::Ticket source=outer.issued[0];let runtime::Capture[1] second=[runtime::capture(source,false,false)];var runtime::Call inner=entered(ref mut state,c,ref second,64);
    let slices::Ticket selected=inner.issued[0];var runtime::Returned a=returned(ref mut state,ref mut inner,selected,64);let slices::Ticket forwarded=a.held.issued;
    var runtime::Returned b=returned(ref mut state,ref mut outer,forwarded,64);let runtime::State before=state;
    assert(!runtime::close(ref mut state,ref mut a.held,forwarded,64,0).is_ok);unchanged(ref state,ref before);
    let slices::Ticket current=b.held.issued;let slices::Ticket resumed=ended(ref mut state,ref mut b.held,current,64);
    close_ticket(ref mut state,resumed,64);assert(owners::release(ref mut state.runtime.owners,root,64).is_ok);
}

@test
fn void late_capture_drop_failure_rolls_back_handoff_and_preserves_prior_writes(){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);let owners::Token first=create(ref mut state,1,ref mut data);let owners::Token second=create(ref mut state,1,ref mut data);
    let slices::Ticket writer=open(ref mut state,first,true,64);let slices::Ticket reader=open(ref mut state,second,false,64);let slices::Ticket alias=open(ref mut state,second,false,64);
    let runtime::Capture[2] args=[runtime::capture(writer,false,false),runtime::capture(reader,true,true)];
    var runtime::Call call=entered(ref mut state,binding(b"module main;fn ref mut i32[] f(ref mut i32[] p,ref i32[] q){return ref mut p;}fn i32 main(){return 42;}",0),ref args,64);
    let slices::Ticket selected=call.issued[0];let usize written=size(slices::write(ref state.runtime.pool,selected,ref state.runtime.owners,0,42,ref mut data));
    let runtime::State before=state;
    assert(!runtime::handoff(ref mut state,ref mut call,selected,64,runtime::handoff_cost()).is_ok && call.active);unchanged(ref state,ref before);
    assert(cell(slices::read(ref state.runtime.pool,selected,ref state.runtime.owners,0,ref data))==42);
    assert(!runtime::handoff(ref mut state,ref mut call,selected,64,runtime::handoff_cost()-1).is_ok);unchanged(ref state,ref before);
    let slices::Ticket wrong=call.issued[1];assert(!runtime::handoff(ref mut state,ref mut call,wrong,64,runtime::handoff_cost()).is_ok);unchanged(ref state,ref before);
    close_ticket(ref mut state,alias,64);var runtime::Returned result=returned(ref mut state,ref mut call,selected,64);
    let slices::Ticket current=result.held.issued;let slices::Ticket resumed=ended(ref mut state,ref mut result.held,current,64);
    close_ticket(ref mut state,resumed,64);assert(owners::release(ref mut state.runtime.owners,first,64).is_ok && state.runtime.owners.depth==0);
}

@test
fn void full_shared_pool_transfers_in_place_and_abort_needs_no_execution_fuel(){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);let owners::Token root=create(ref mut state,1,ref mut data);
    let slices::Ticket parent=open(ref mut state,root,false,64);var usize i=0;while(i<14){let slices::Ticket extra=open(ref mut state,root,false,64);i+=1;}
    let runtime::Capture[1] args=[runtime::capture(parent,false,false)];var runtime::Call call=entered(ref mut state,binding(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){return 42;}",0),ref args,64);
    let slices::Ticket selected=call.issued[0];var runtime::Returned result=returned(ref mut state,ref mut call,selected,64);assert(result.held.issued.slot==selected.slot);
    switch(runtime::abort(ref mut state,64,0)){case .ok(v):{assert(v==0);}case .err(_):{assert(false);}};
    assert(state.runtime.owners.depth==0 && state.runtime.authority.depth==0);
    let slices::Ticket current=result.held.issued;assert(!runtime::close(ref mut state,ref mut result.held,current,64,0).is_ok);
}

@test
fn void all_six_scalar_modes_retain_and_drop_selected_temporary_roots(){
    scalar_roundtrip(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){return 42;}",1,-42);
    scalar_roundtrip(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){return 42;}",1,-42);
    scalar_roundtrip(b"module main;fn ref bool[] f(ref bool[] p){return ref p;}fn i32 main(){return 42;}",2,1);
    scalar_roundtrip(b"module main;fn ref mut bool[] f(ref mut bool[] p){return ref mut p;}fn i32 main(){return 42;}",2,1);
    scalar_roundtrip(b"module main;fn ref i64[] f(ref i64[] p){return ref p;}fn i32 main(){return 42;}",9,-9223372036854775807-1);
    scalar_roundtrip(b"module main;fn ref mut i64[] f(ref mut i64[] p){return ref mut p;}fn i32 main(){return 42;}",9,-9223372036854775807-1);
    scalar_roundtrip(b"module main;fn ref u8[] f(ref u8[] p){return ref p;}fn i32 main(){return 42;}",10,255);
    scalar_roundtrip(b"module main;fn ref mut u8[] f(ref mut u8[] p){return ref mut p;}fn i32 main(){return 42;}",10,255);
    scalar_roundtrip(b"module main;fn ref u32[] f(ref u32[] p){return ref p;}fn i32 main(){return 42;}",11,4294967295);
    scalar_roundtrip(b"module main;fn ref mut u32[] f(ref mut u32[] p){return ref mut p;}fn i32 main(){return 42;}",11,4294967295);
    scalar_roundtrip(b"module main;fn ref usize[] f(ref usize[] p){return ref p;}fn i32 main(){return 42;}",12,-1);
    scalar_roundtrip(b"module main;fn ref mut usize[] f(ref mut usize[] p){return ref mut p;}fn i32 main(){return 42;}",12,-1);
}

@test
fn void aliased_shared_arguments_keep_the_selected_subrange_and_drop_once(){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);let owners::Token root=create(ref mut state,1,ref mut data);
    let usize written=size(owners::write(ref mut state.runtime.owners,root,1,42,ref mut data));let slices::Ticket parent=open(ref mut state,root,false,64);
    let runtime::Capture[2] args=[runtime::capture(parent,true,true);2];
    var runtime::Call call=entered(ref mut state,binding(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q){let ref i32[] r=ref q[1..3];return ref r;}fn i32 main(){return 42;}",0),ref args,64);
    let slices::Ticket input=call.issued[1];let slices::Ticket selected=sub(ref mut state,input,1,3,64);var runtime::Returned result=returned(ref mut state,ref mut call,selected,64);
    let slices::Ticket current=result.held.issued;
    assert(size(slices::length(ref state.runtime.pool,current,ref state.runtime.owners,64))==2 && cell(slices::read(ref state.runtime.pool,current,ref state.runtime.owners,0,ref data))==42);
    assert(!slices::read(ref state.runtime.pool,current,ref state.runtime.owners,2,ref data).is_ok && !slices::length(ref state.runtime.pool,parent,ref state.runtime.owners,64).is_ok);
    let slices::Ticket absent=ended(ref mut state,ref mut result.held,current,64);assert(state.runtime.owners.depth==0);
}

@test
fn void entry_pool_exhaustion_and_fuel_failure_publish_no_receipt_or_owner_change(){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);let owners::Token root=create(ref mut state,1,ref mut data);
    let slices::Ticket parent=open(ref mut state,root,false,64);var usize i=0;while(i<15){let slices::Ticket extra=open(ref mut state,root,false,64);i+=1;}
    let runtime::State before=state;let runtime::Capture[1] args=[runtime::capture(parent,false,false)];let runtime::Contract c=binding(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){return 42;}",0);
    assert(!runtime::enter(ref mut state,c,ref args,64,runtime::cost()-1).is_ok);unchanged(ref state,ref before);
    assert(!runtime::enter(ref mut state,c,ref args,64,runtime::cost()).is_ok);unchanged(ref state,ref before);
    assert(runtime::abort(ref mut state,64,0).is_ok && state.runtime.owners.depth==0);
}

@test
fn void generation_exhaustion_and_corrupt_frame_fail_before_publication(){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);let owners::Token root=create(ref mut state,1,ref mut data);
    let slices::Ticket parent=open(ref mut state,root,true,64);let runtime::Capture[1] args=[runtime::capture(parent,false,false)];
    var runtime::Call call=entered(ref mut state,binding(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){return 42;}",0),ref args,64);
    let usize slot=call.issued[0].slot;state.runtime.pool.slots[slot].generation=18446744073709551613;
    let slices::Ticket selected=slices::Ticket{.slot=slot,.generation=18446744073709551613};let runtime::State before=state;
    assert(!runtime::handoff(ref mut state,ref mut call,selected,64,runtime::handoff_cost()).is_ok && call.active);unchanged(ref state,ref before);
    call.frame=18446744073709551615;assert(!runtime::handoff(ref mut state,ref mut call,selected,64,runtime::handoff_cost()).is_ok);unchanged(ref state,ref before);
    assert(runtime::abort(ref mut state,64,0).is_ok && state.runtime.authority.depth==0 && state.runtime.owners.depth==0);
}

fn void anonymous_ranges(bool second){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);let owners::Token a=create(ref mut state,1,ref mut data);let owners::Token b=create(ref mut state,1,ref mut data);
    let slices::Ticket pa=open(ref mut state,a,true,64);let slices::Ticket pb=open(ref mut state,b,true,64);
    let slices::Ticket ca=child(ref mut state,pa,1,3,64);let slices::Ticket cb=child(ref mut state,pb,1,4,64);
    let runtime::Capture[2] args=[runtime::capture(ca,true,false),runtime::capture(cb,true,false)];
    let runtime::Contract c=if(second){binding(b"module main;fn ref mut i32[] f(ref mut i32[] p,ref mut i32[] q){return ref mut q;}fn i32 main(){return 42;}",0)}else{binding(b"module main;fn ref mut i32[] f(ref mut i32[] p,ref mut i32[] q){return ref mut p;}fn i32 main(){return 42;}",0)};
    var runtime::Call call=entered(ref mut state,c,ref args,64);let usize index=if(second){1}else{0};let slices::Ticket selected=call.issued[index];
    var runtime::Returned result=returned(ref mut state,ref mut call,selected,64);
    assert(state.runtime.authority.depth==1 && !result.held.close_parent && result.held.depth==0);
    let slices::Ticket current=result.held.issued;let usize written=size(slices::write(ref state.runtime.pool,current,ref state.runtime.owners,0,42,ref mut data));
    let slices::Ticket other=result.resumed[1-index];assert(other.slot<16 && size(slices::length(ref state.runtime.pool,other,ref state.runtime.owners,64))==4);
    assert(!slices::length(ref state.runtime.pool,pa,ref state.runtime.owners,64).is_ok && !slices::length(ref state.runtime.pool,pb,ref state.runtime.owners,64).is_ok);
    let slices::Ticket resumed=ended(ref mut state,ref mut result.held,current,64);
    assert(size(slices::length(ref state.runtime.pool,resumed,ref state.runtime.owners,64))==4 && cell(slices::read(ref state.runtime.pool,resumed,ref state.runtime.owners,1,ref data))==42);
    close_ticket(ref mut state,resumed,64);close_ticket(ref mut state,other,64);
    assert(owners::release(ref mut state.runtime.owners,a,64).is_ok && owners::release(ref mut state.runtime.owners,b,64).is_ok && state.runtime.owners.depth==0);
}
@test
fn void anonymous_mutable_arguments_restore_named_parents_in_both_selection_orders(){anonymous_ranges(false);anonymous_ranges(true);}

@test
fn void late_failure_rolls_back_anonymous_parent_restoration_and_result_installation(){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(64);
    let owners::Token a=create(ref mut state,1,ref mut data);let owners::Token b=create(ref mut state,1,ref mut data);let owners::Token c=create(ref mut state,1,ref mut data);
    let slices::Ticket pa=open(ref mut state,a,true,64);let slices::Ticket pb=open(ref mut state,b,true,64);let slices::Ticket pc=open(ref mut state,c,false,64);let slices::Ticket peer=open(ref mut state,c,false,64);
    let slices::Ticket ca=child(ref mut state,pa,1,3,64);let slices::Ticket cb=child(ref mut state,pb,0,2,64);
    let runtime::Capture[3] args=[runtime::capture(ca,true,false),runtime::capture(cb,true,false),runtime::capture(pc,true,true)];
    var runtime::Call call=entered(ref mut state,binding(b"module main;fn ref mut i32[] f(ref mut i32[] p,ref mut i32[] q,ref i32[] r){return ref mut p;}fn i32 main(){return 42;}",0),ref args,64);
    let slices::Ticket selected=call.issued[0];let runtime::State before=state;
    assert(!runtime::handoff(ref mut state,ref mut call,selected,64,runtime::handoff_cost()).is_ok && call.active);unchanged(ref state,ref before);
    close_ticket(ref mut state,peer,64);var runtime::Returned result=returned(ref mut state,ref mut call,selected,64);
    let slices::Ticket current=result.held.issued;let slices::Ticket other=result.resumed[1];let slices::Ticket resumed=ended(ref mut state,ref mut result.held,current,64);
    close_ticket(ref mut state,other,64);close_ticket(ref mut state,resumed,64);
    assert(owners::release(ref mut state.runtime.owners,a,64).is_ok && owners::release(ref mut state.runtime.owners,b,64).is_ok && state.runtime.owners.depth==0);
}

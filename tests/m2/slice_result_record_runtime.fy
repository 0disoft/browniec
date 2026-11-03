module tests::m2::slice_result_record_runtime;
import slice_result_runtime as runtime;
import array_owners as owners;
import array_layout as arrays;
import array_slices as slices;
import struct_layout as records;
import errors as errors;
fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};}
fn void same(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live);
        assert(x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element);
        assert(x.length==y.length && x.record==y.record && x.alignment==y.alignment);i+=1;
    }
}
fn Result<usize,errors::Error> batch(bool corrupt,usize capacity,bool fail){
    var u8[64] data=[0;64];var runtime::State state=runtime::empty(capacity);
    let arrays::Array shape=arrays::Array{.element=1,.length=4,.stride=4,.alignment=4,.bytes=16};
    let owners::Token root=token(owners::create(ref shape,0,ref mut data[..capacity],ref mut state.runtime.owners));
    var records::Catalog catalog=records::empty();catalog.count=1;catalog.fields[0]=2;catalog.types[0]=1;catalog.types[1]=2;
    let i64[2] cells=[20,1];let owners::Token record=token(owners::create_record(ref catalog,0,ref cells,ref mut data[..capacity],ref mut state.runtime.owners));
    let arrays::Array one=arrays::Array{.element=1,.length=1,.stride=4,.alignment=4,.bytes=4};
    let owners::Token array=token(owners::create(ref one,22,ref mut data[..capacity],ref mut state.runtime.owners));
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket parent=switch(slices::open_exclusive(ref mut pool,ref mut table,root,0,4,capacity)){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};
    state.runtime.pool=pool;state.runtime.owners=table;
    if(corrupt){data[state.runtime.owners.slots[record.slot].base+4]=2;}
    let u8[64] saved=data;let owners::Table before=state.runtime.owners;
    let runtime::Capture[3] captures=[runtime::capture(parent,false,false),runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false),runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    var runtime::Contract c=runtime::Contract{.tags=[0;8],.arity=3,.selected=0};c.tags[0]=129;
    let owners::CallArgument[2] arguments=[owners::CallArgument{.source=record,.element=0,.length=0,.record=0},owners::CallArgument{.source=array,.element=1,.length=1,.record=0}];
    let Result<runtime::Entered,errors::Error> result=runtime::enter_records(ref mut state,c,ref captures,ref catalog,ref arguments,ref mut data[..capacity],runtime::cost());
    if(fail){
        assert(!result.is_ok);same(ref state.runtime.owners,ref before);
        assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0);
        assert(slices::length(ref state.runtime.pool,parent,ref state.runtime.owners,capacity).is_ok);
        var usize i=0;while(i<64){assert(data[i]==saved[i]);i+=1;}
    }else{
        var runtime::Entered entered=switch(result){case .ok(v):{v}case .err(e):{return .err(e);}};
        assert(entered.copies.count==2 && entered.copies.tokens[0].slot!=record.slot && entered.copies.tokens[1].slot!=array.slot);
        let usize[1] path=[0];let owners::Token copied=entered.copies.tokens[0];
        assert(owners::write_record(ref catalog,ref state.runtime.owners,copied,ref path,42,ref mut data[..capacity]).is_ok);
        let i64 original=switch(owners::read_record(ref catalog,ref state.runtime.owners,record,ref path,ref data[..capacity])){case .ok(v):{v}case .err(_):{assert(false);0}};assert(original==20);
        let runtime::Resumed resumed=runtime::leave_call(ref mut state,ref mut entered.call,capacity,runtime::leave_cost())?;
        assert(slices::length(ref state.runtime.pool,resumed.tickets[0],ref state.runtime.owners,capacity).is_ok);
        assert(!slices::length(ref state.runtime.pool,parent,ref state.runtime.owners,capacity).is_ok);
    }
    let usize cleared=runtime::abort(ref mut state,capacity,0)?;assert(state.runtime.owners.depth==0);return .ok(0);
}
@test fn void mixed_batch_quota_or_corrupt_bool_preserves_original_authority_and_bytes(){
    assert(batch(false,36,true).is_ok);assert(batch(true,64,true).is_ok);
}
@test fn void mixed_batch_success_copies_records_and_restores_borrowed_writer(){assert(batch(false,64,false).is_ok);}

fn Result<usize,errors::Error> handoff(){
    var u8[32] data=[0;32];var runtime::State state=runtime::empty(32);
    let arrays::Array shape=arrays::Array{.element=1,.length=4,.stride=4,.alignment=4,.bytes=16};
    let owners::Token root=token(owners::create(ref shape,0,ref mut data,ref mut state.runtime.owners));
    var records::Catalog catalog=records::empty();catalog.count=1;catalog.fields[0]=1;catalog.types[0]=1;
    let i64[1] values=[42];let owners::Token record=token(owners::create_record(ref catalog,0,ref values,ref mut data,ref mut state.runtime.owners));
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket parent=switch(slices::open_exclusive(ref mut pool,ref mut table,root,0,4,32)){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};
    state.runtime.pool=pool;state.runtime.owners=table;
    var runtime::Contract c=runtime::Contract{.tags=[0;8],.arity=1,.selected=1};c.tags[0]=129;
    let runtime::Capture[1] captures=[runtime::capture(parent,true,true)];
    var runtime::Call call=runtime::enter(ref mut state,c,ref captures,32,runtime::cost())?;
    let owners::Table before=state.runtime.owners;let slices::Ticket selected=call.issued[0];
    let owners::Token[2] duplicate=[record,record];
    assert(!runtime::handoff_roots(ref mut state,ref mut call,selected,ref duplicate,32,runtime::handoff_cost()).is_ok);
    same(ref state.runtime.owners,ref before);assert(call.active && state.runtime.authority.frame==1);
    assert(slices::length(ref state.runtime.pool,selected,ref state.runtime.owners,32).is_ok);
    var runtime::Returned result=runtime::handoff_roots(ref mut state,ref mut call,selected,ref duplicate[..1],32,runtime::handoff_cost())?;
    assert(!state.runtime.owners.slots[record.slot].live);
    let slices::Ticket current=result.held.issued;let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,32,0)?;
    assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0 && state.runtime.authority.depth==0);return .ok(0);
}
@test fn void record_cleanup_failure_rolls_back_handoff_and_success_releases_local(){assert(handoff().is_ok);}

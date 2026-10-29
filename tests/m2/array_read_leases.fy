module tests::m2::array_read_leases;
import array_owners as owners;
import array_layout as layouts;
import struct_layout as records;
import array_vm as arrays;
import array_result_vm as results;
import ir as ir;
import std::bytes as bytes;

fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};}
fn owners::ReadLease lease(Result<owners::ReadLease,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::ReadLease{.root=owners::Token{.slot=16,.generation=0},.generation=0}}};}
fn owners::View span(Result<owners::View,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::View{.root=owners::Token{.slot=16,.generation=0},.element=0,.length=0,.start=0,.end=0}}};}
fn i64 value(Result<i64,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn bool utf8(Result<bool,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);false}};}
fn layouts::Array shape(usize n){return switch(layouts::scalar(10,n)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};}
fn owners::Token create(ref mut owners::Table table,usize n,i64 fill,ref mut u8[] data){let layouts::Array a=shape(n);return token(owners::create(ref a,fill,data,table));}
fn void same(ref owners::Table a,ref owners::Table b,ref u8[] data,ref u8[] saved){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.live==y.live && x.occupied==y.occupied);
        assert(x.reading==y.reading && x.read_generation==y.read_generation);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length);
        assert(x.record==y.record && x.alignment==y.alignment);i+=1;}
    assert(data.len==saved.len);i=0;while(i<data.len){assert(data[i]==saved[i]);i+=1;}
}

@test
fn void active_session_blocks_writes_replacement_transfer_and_cleanup_atomically(){
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);
    let owners::Token root=create(ref mut table,2,65,ref mut data);let owners::Token other=create(ref mut table,2,66,ref mut data);
    let owners::View v=span(owners::view(ref table,root,0,2,8));
    let owners::ReadLease r=lease(owners::begin_read(ref mut table,root,8));
    let owners::Table before=table;let u8[8] saved=data;
    assert(!owners::write(ref table,root,0,255,ref mut data).is_ok);
    assert(!owners::fill(ref table,root,0,ref mut data).is_ok);
    assert(!owners::assign(root,other,ref mut data,ref table).is_ok && !owners::assign(root,root,ref mut data,ref table).is_ok);
    assert(!owners::validate_result(ref table,root,10,2,ref data).is_ok);
    assert(!owners::release(ref mut table,root,8).is_ok && !owners::clear(ref mut table,8).is_ok);
    assert(!owners::begin_read(ref mut table,root,8).is_ok);
    assert(value(owners::leased_read(ref table,r,ref v,1,ref data))==65 && utf8(owners::leased_utf8(ref table,r,ref v,ref data)));
    same(ref table,ref before,ref data,ref saved);
    assert(owners::end_read(ref mut table,r,8).is_ok && !table.slots[root.slot].reading);
    assert(owners::write(ref table,root,0,255,ref mut data).is_ok && owners::fill(ref table,root,0,ref mut data).is_ok);
    assert(owners::assign(root,other,ref mut data,ref table).is_ok && owners::validate_result(ref table,root,10,2,ref data).is_ok);
    assert(owners::release(ref mut table,root,8).is_ok && owners::clear(ref mut table,8).is_ok);
}

@test
fn void old_or_copied_tickets_cannot_access_or_end_a_new_session(){
    var u8[4] data=[0;4];var owners::Table table=owners::empty(4);
    let owners::Token root=create(ref mut table,2,65,ref mut data);let owners::Token other=create(ref mut table,1,66,ref mut data);
    let owners::View v=span(owners::view(ref table,root,0,2,4));let owners::View child=span(owners::subview(ref table,ref v,1,2,4));
    let owners::View foreign=span(owners::view(ref table,other,0,1,4));
    let owners::ReadLease old=lease(owners::begin_read(ref mut table,root,4));let owners::ReadLease copied=old;
    assert(value(owners::leased_read(ref table,old,ref child,0,ref data))==65);
    assert(!owners::leased_read(ref table,old,ref foreign,0,ref data).is_ok && !owners::leased_utf8(ref table,old,ref foreign,ref data).is_ok);
    assert(owners::end_read(ref mut table,copied,4).is_ok && !owners::end_read(ref mut table,old,4).is_ok);
    assert(!owners::leased_read(ref table,old,ref v,0,ref data).is_ok);
    let owners::ReadLease fresh=lease(owners::begin_read(ref mut table,root,4));assert(fresh.generation!=old.generation);
    let owners::Table before=table;let u8[4] saved=data;
    assert(!owners::end_read(ref mut table,old,4).is_ok && !owners::leased_utf8(ref table,old,ref v,ref data).is_ok);
    same(ref table,ref before,ref data,ref saved);
    assert(owners::end_read(ref mut table,fresh,4).is_ok && owners::clear(ref mut table,4).is_ok);
    let owners::Token replacement=create(ref mut table,2,0,ref mut data);assert(replacement.generation!=root.generation);
    assert(!owners::end_read(ref mut table,fresh,4).is_ok);
}

@test
fn void shared_sources_can_be_copied_while_new_owners_stay_unleased(){
    var u8[32] data=[0;32];var owners::Table table=owners::empty(32);
    let owners::Token root=create(ref mut table,2,65,ref mut data);
    let owners::ReadLease r=lease(owners::begin_read(ref mut table,root,32));
    let owners::Token copied=token(owners::copy(root,ref mut data,ref mut table));
    assert(!table.slots[copied.slot].reading && table.slots[root.slot].reading);
    assert(owners::assign(copied,root,ref mut data,ref table).is_ok && owners::write(ref table,copied,0,255,ref mut data).is_ok);
    let owners::Token[2] sources=[root,root];let layouts::Array[2] shapes=[shape(2);2];
    let owners::Copies batch=switch(owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table)){case .ok(v):{v}case .err(_):{assert(false);owners::Copies{.tokens=[root;8],.count=0}}};
    assert(batch.count==2 && !table.slots[batch.tokens[0].slot].reading && !table.slots[batch.tokens[1].slot].reading);
    var records::Catalog catalog=records::empty();catalog.count=1;catalog.fields[0]=1;catalog.types[0]=10;let i64[1] fields=[42];
    let owners::Token record=token(owners::create_record(ref catalog,0,ref fields,ref mut data,ref mut table));
    let owners::CallArgument[2] args=[owners::CallArgument{.source=root,.element=10,.length=2,.record=0},owners::CallArgument{.source=record,.element=0,.length=0,.record=0}];
    let owners::Copies mixed=switch(owners::copy_call_arguments(ref catalog,ref args,ref mut data,ref mut table)){case .ok(v):{v}case .err(_):{assert(false);owners::Copies{.tokens=[root;8],.count=0}}};
    assert(mixed.count==2 && !table.slots[mixed.tokens[0].slot].reading && !table.slots[mixed.tokens[1].slot].reading);
    assert(!owners::begin_read(ref mut table,record,32).is_ok && table.slots[root.slot].reading && table.slots[root.slot].read_generation==r.generation);
    assert(value(owners::read(ref table,root,0,ref data))==65 && owners::release(ref mut table,copied,32).is_ok);
    assert(owners::end_read(ref mut table,r,32).is_ok && owners::clear(ref mut table,32).is_ok);
}

@test
fn void failed_end_is_retryable_and_epoch_exhaustion_never_wraps(){
    var u8[16] data=[0;16];var owners::Table table=owners::empty(16);var owners::ReadLease[16] active=[owners::ReadLease{.root=owners::Token{.slot=16,.generation=0},.generation=0};16];
    var usize i=0;while(i<16){let owners::Token root=create(ref mut table,1,65,ref mut data);active[i]=lease(owners::begin_read(ref mut table,root,16));i+=1;}
    let owners::Table before=table;let u8[16] saved=data;
    assert(!owners::end_read(ref mut table,active[0],0).is_ok && !owners::clear(ref mut table,16).is_ok);same(ref table,ref before,ref data,ref saved);
    i=16;while(i>0){i-=1;assert(owners::end_read(ref mut table,active[i],16).is_ok);}
    assert(owners::clear(ref mut table,16).is_ok);
    let owners::Token root=create(ref mut table,1,65,ref mut data);
    table.slots[root.slot].read_generation=18446744073709551615;
    let owners::ReadLease last=lease(owners::begin_read(ref mut table,root,16));
    assert(owners::end_read(ref mut table,last,16).is_ok && table.slots[root.slot].read_generation==0);
    assert(!owners::begin_read(ref mut table,root,16).is_ok && owners::write(ref table,root,0,0,ref mut data).is_ok);
    assert(owners::release(ref mut table,root,16).is_ok);let owners::Token reused=create(ref mut table,1,65,ref mut data);
    let owners::ReadLease next=lease(owners::begin_read(ref mut table,reused,16));assert(!owners::end_read(ref mut table,last,16).is_ok);
    table.slots[reused.slot].read_generation=0;assert(!owners::end_read(ref mut table,next,16).is_ok);
    table.slots[reused.slot].read_generation=next.generation;
    assert(owners::end_read(ref mut table,next,16).is_ok && owners::clear(ref mut table,16).is_ok);
    table.slots[15].reading=true;let layouts::Array one=shape(1);assert(!owners::create(ref one,0,ref mut data,ref mut table).is_ok);
}

@test
fn void array_return_transfer_checks_the_read_session_before_token_writes(){
    var ir::Program p=ir::empty();p.function_count=2;
    let usize source=switch(ir::array_in(ref mut p,0,10,1,false,0)){case .ok(v):{v}case .err(_):{assert(false);0}};
    let usize destination=switch(ir::array_in(ref mut p,1,10,1,false,0)){case .ok(v):{v}case .err(_):{assert(false);0}};p.array_results[0]=1;
    var arrays::State state=arrays::empty(1);var bytes::Buffer payload=switch(arrays::prepare(1)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    let owners::Token root=create(ref mut state.owners,1,65,bytes::view_mut(ref mut payload));state.tokens[16+source]=root;
    let owners::ReadLease r=lease(owners::begin_read(ref mut state.owners,root,1));
    assert(!results::leave(ref p,0,source,destination,1,ref mut state,ref payload,91).is_ok);
    assert(state.tokens[16+source].generation==root.generation && state.tokens[destination].generation==0 && state.owners.slots[root.slot].reading);
    assert(owners::end_read(ref mut state.owners,r,1).is_ok);
    assert(results::leave(ref p,0,source,destination,1,ref mut state,ref payload,91).is_ok);
    assert(state.tokens[16+source].generation==0 && state.tokens[destination].generation==root.generation);
}

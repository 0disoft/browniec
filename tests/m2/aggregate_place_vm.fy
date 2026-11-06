module tests::m2::aggregate_place_vm;
import aggregate_place_vm as execution;
import aggregate_place_ir as places;
import place_vm as legacy;
import record_place_vm as old_records;
import array_list_vm as lists;
import array_vm as backing;
import array_layout as arrays;
import array_owners as owners;
import struct_meta as records;
import ir as ir;
import verifier as verifier;
import errors as errors;
import fuel as meter;
import std::vec as vec;
import std::bytes as bytes;

fn usize ok(Result<usize,errors::Error> r){return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};}
fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};}
fn void finish(ref mut ir::Program p){let usize n=p.count;let usize r=p.registers;p.ends[0]=n;p.register_ends[0]=r;}
fn records::Prepared shapes(ref ir::Program p){return switch(records::prepare(ref p.records)){
    case .ok(v):{v}case .err(_):{assert(false);records::Prepared{.leaves=[0;16],.tags=[0;2048]}}
};}
fn execution::Requirement required(ref ir::Program p){return switch(execution::requirement(p)){
    case .ok(v):{v}case .err(_):{assert(false);execution::Requirement{.width=0,.cost=0}}
};}
fn vec::Vec<usize> prepare(ref ir::Program p){let execution::Requirement plan=required(p);
    return switch(execution::prepare_metered(ref plan,plan.cost)){
        case .ok(v):{v}case .err(_):{assert(false);vec::empty<usize>()}
    };
}
fn lists::Requirement list_plan(ref ir::Program p){return switch(lists::requirement(p)){
    case .ok(v):{v}case .err(_):{assert(false);lists::Requirement{.length=0,.bytes=0,.cost=0}}
};}
fn vec::Vec<i64> cells(ref lists::Requirement plan){return switch(lists::prepare_values(plan)){
    case .ok(v):{v}case .err(_):{assert(false);vec::empty<i64>()}
};}
fn bytes::Buffer scratch(ref lists::Requirement plan){return switch(lists::prepare_encoded(plan)){
    case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
};}
fn void failed(Result<usize,errors::Error> r,u8 kind){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==77}});}
fn void same(ref u8[] a,ref u8[] b){assert(a.len==b.len);var usize i=0;while(i<a.len){assert(a[i]==b[i]);i+=1;}}
fn usize digest(ref vec::Vec<usize> state){var usize n=0;let ref usize[] words=execution::inspect(state);
    var usize i=0;while(i<words.len){n+=words[i];i+=1;}return n;
}
fn ir::Program array(u8 tag,u8 mode,usize length){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize a=ok(ir::array(ref mut p,tag,length,true,0));let usize b=ok(ir::array(ref mut p,tag,length,false,0));
    let usize v=if(tag==2){ok(ir::boolean(ref mut p,true,0))}else{ok(ir::integer(ref mut p,42,tag,0))};
    let usize init=ok(ir::array_init(ref mut p,a,v,0));let usize init_b=ok(ir::array_init(ref mut p,b,v,0));
    let usize select=ok(places::select_array(ref mut p,0,a,77));
    if(mode<2){let usize store=ok(places::store_array(ref mut p,0,a,if(mode==0){b}else{a},77));}
    else if(mode==2){let usize store=ok(places::fill_array(ref mut p,0,a,v,77));}
    else{let usize[4096] values=[0;4096];let usize store=ok(places::replace_array(ref mut p,0,a,ref values[..length],77));}
    let usize end=ok(ir::place_end(ref mut p,0,77));let usize db=ok(ir::array_drop(ref mut p,b,0));
    let usize da=ok(ir::array_drop(ref mut p,a,0));let usize result=ok(ir::literal(ref mut p,42,0));
    let usize ret=ok(ir::emit(ref mut p,8,result,0,0));finish(ref mut p);assert(verifier::inspect_aggregate_places(ref p).is_ok);return p;
}
fn ir::Program record(bool constructor){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    p.records.layouts.count=2;p.records.layouts.fields[0]=2;
    p.records.layouts.kinds[0]=1;p.records.layouts.kinds[1]=1;p.records.layouts.types[0]=1;p.records.layouts.types[1]=1;
    p.records.layouts.fields[1]=2;p.records.layouts.types[16]=1;p.records.layouts.types[17]=2;
    let usize a=ok(ir::record(ref mut p,0,true,0));let usize b=ok(ir::record(ref mut p,0,false,0));
    let usize x=ok(ir::literal(ref mut p,42,0));let usize y=ok(ir::boolean(ref mut p,true,0));
    let usize z=ok(ir::literal(ref mut p,42,0));let usize w=ok(ir::boolean(ref mut p,true,0));
    let usize ia=ok(ir::record_init(ref mut p,a,x,0));let usize ib=ok(ir::record_init(ref mut p,b,x,0));
    let usize select=ok(places::select_record(ref mut p,0,a,1,2,77));
    if(constructor){let usize store=ok(places::replace_record(ref mut p,0,a,1,2,x,77));}
    else{let usize store=ok(places::store_record(ref mut p,0,a,b,1,2,0,77));}
    let usize end=ok(ir::place_end(ref mut p,0,77));let usize db=ok(ir::record_drop(ref mut p,b,0));
    let usize da=ok(ir::record_drop(ref mut p,a,0));let usize answer=ok(ir::literal(ref mut p,42,0));
    let usize ret=ok(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p);assert(verifier::inspect_aggregate_places(ref p).is_ok);return p;
}
fn usize run(ref ir::Program p,ref records::Prepared catalog,usize pc,usize frame,ref mut vec::Vec<usize> state,
    ref owners::Table table,owners::Token root,owners::Token source,ref mut u8[] data,ref i64[] regs,
    ref mut vec::Vec<i64> values,ref mut bytes::Buffer encoded,usize fuel){
    return ok(execution::step(p,catalog,pc,0,frame,state,table,root,source,data,regs,values,encoded,fuel));
}

@test fn void six_array_domains_copy_self_fill_and_lists_preflight_exact_fuel_and_publish_once(){
    let u8[6] tags=[1,2,9,10,11,12];let usize[6] strides=[4,1,8,1,4,8];var usize t=0;
    while(t<6){var u8 mode=0;while(mode<4){let ir::Program p=array(tags[t],mode,2);let records::Prepared c=shapes(ref p);
        var vec::Vec<usize> state=prepare(ref p);let lists::Requirement lp=list_plan(ref p);
        var vec::Vec<i64> values=cells(ref lp);var bytes::Buffer encoded=scratch(ref lp);
        let arrays::Array shape=switch(arrays::scalar(tags[t],2)){case .ok(v):{v}case .err(_):{assert(false);arrays::Array{.element=1,.length=2,.stride=4,.alignment=4,.bytes=8}}};
        var u8[32] data=[85;32];var owners::Table table=owners::empty(32);
        let i64 initial=if(tags[t]==2){0}else{20};let i64 value=if(tags[t]==2){1}else{42};let i64[1] regs=[value];
        let owners::Token root=token(owners::create(ref shape,initial,ref mut data,ref mut table));
        let owners::Token source=token(owners::create(ref shape,value,ref mut data,ref mut table));
        let usize size=2*strides[t];let usize price=if(mode<2){178+size+if(tags[t]==2){2}else{0}}
            else if(mode==2){146+2*strides[t]+size}else{148+3*size};
        assert(ok(execution::cost(ref p,3,0))==97 && ok(execution::cost(ref p,4,0))==price);
        let usize old=digest(ref state);let u8[32] before=data;
        failed(execution::step(ref p,ref c,3,0,0,ref mut state,ref table,root,source,ref mut data,ref regs,ref mut values,ref mut encoded,96),8);
        assert(digest(ref state)==old);same(ref data,ref before);
        assert(run(ref p,ref c,3,0,ref mut state,ref table,root,source,ref mut data,ref regs,ref mut values,ref mut encoded,97)==0);
        let usize selected=digest(ref state);let owners::Token actual=if(mode==1){root}else{source};
        failed(execution::step(ref p,ref c,4,0,0,ref mut state,ref table,source,actual,ref mut data,ref regs,ref mut values,ref mut encoded,price-1),8);
        assert(digest(ref state)==selected);same(ref data,ref before);
        assert(run(ref p,ref c,4,0,ref mut state,ref table,source,actual,ref mut data,ref regs,ref mut values,ref mut encoded,price+1)==1);
        assert(switch(owners::read(ref table,root,1,ref data)){case .ok(v):{v==if(mode==1){initial}else{value}}case .err(_):{false}});
        failed(execution::step(ref p,ref c,4,0,0,ref mut state,ref table,root,actual,ref mut data,ref regs,ref mut values,ref mut encoded,price),5);
        assert(run(ref p,ref c,5,0,ref mut state,ref table,root,actual,ref mut data,ref regs,ref mut values,ref mut encoded,26)==0);
        assert(execution::empty_frame(ref state,0,77).is_ok && table.depth==2 && table.arena.used==2*size);
        mode+=1;
    }t+=1;}
}
@test fn void record_copy_and_constructor_keep_original_subtree_and_fixed_envelopes(){
    var usize mode=0;while(mode<2){let ir::Program p=record(mode==1);let records::Prepared c=shapes(ref p);
        var vec::Vec<usize> state=prepare(ref p);var vec::Vec<i64> values=vec::empty<i64>();var bytes::Buffer encoded=bytes::empty();
        var u8[64] data=[85;64];var owners::Table table=owners::empty(64);let i64[4] fields=[20,0,22,1];let i64[4] regs=[42,1,0,0];
        let owners::Token root=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
        let owners::Token source=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
        let usize price=if(mode==0){172129}else{128162};assert(ok(execution::cost(ref p,6,0))==41057 && ok(execution::cost(ref p,7,0))==price);
        let usize select=run(ref p,ref c,6,0,ref mut state,ref table,root,source,ref mut data,ref regs,ref mut values,ref mut encoded,41057);
        let u8[64] before=data;let usize selected=digest(ref state);
        failed(execution::step(ref p,ref c,7,0,0,ref mut state,ref table,source,source,ref mut data,ref regs,ref mut values,ref mut encoded,price-1),8);
        assert(digest(ref state)==selected);same(ref data,ref before);
        let usize store=run(ref p,ref c,7,0,ref mut state,ref table,source,source,ref mut data,ref regs,ref mut values,ref mut encoded,price);
        assert(data[0]==20 && data[8]==if(mode==0){20}else{42} && data[12]==if(mode==0){0}else{1});
        let usize end=run(ref p,ref c,8,0,ref mut state,ref table,root,source,ref mut data,ref regs,ref mut values,ref mut encoded,26);
        assert(execution::empty_frame(ref state,0,77).is_ok && table.depth==2 && table.arena.used==32);mode+=1;
    }
}
@test fn void setup_is_prepaid_bounded_and_disjoint_from_all_legacy_formats(){
    var ir::Program p=array(1,0,2);let execution::Requirement one=required(ref p);assert(one.width==1 && one.cost==6367);
    assert(!execution::prepare_metered(ref one,6366).is_ok);let vec::Vec<usize> state=prepare(ref p);
    assert(vec::len<usize>(ref state)==611 && !legacy::format(ref state,77).is_ok);
    assert(!old_records::requirement(ref p).is_ok);
    p.code[25]=15;p.code[33]=15;p.code[41]=15;let execution::Requirement max=required(ref p);
    assert(max.width==16 && max.cost==92767 && max.cost<meter::cli_limit());
    let vec::Vec<usize> full=prepare(ref p);assert(vec::len<usize>(ref full)==9251 && !legacy::format(ref full,77).is_ok);
    var execution::Requirement bad=max;bad.width=17;assert(!execution::prepare_metered(ref bad,0).is_ok);
    bad=max;bad.cost-=1;assert(!execution::prepare_metered(ref bad,16000000).is_ok);
    let ir::Program empty=ir::empty();let execution::Requirement zero=required(ref empty);
    let vec::Vec<usize> none=prepare(ref empty);assert(zero.width==0 && zero.cost==0 && vec::len<usize>(ref none)==0);
    assert(meter::cli_default()==256 && meter::cli_limit()==16000000);
}
@test fn void failed_source_bools_and_late_list_values_leave_destination_and_phase_unchanged(){
    var u8 mode=0;while(mode<2){let ir::Program p=array(2,if(mode==0){0}else{3},2);let records::Prepared c=shapes(ref p);
        var vec::Vec<usize> state=prepare(ref p);let lists::Requirement lp=list_plan(ref p);var vec::Vec<i64> values=cells(ref lp);var bytes::Buffer encoded=scratch(ref lp);
        let arrays::Array shape=arrays::Array{.element=2,.length=2,.stride=1,.alignment=1,.bytes=2};var u8[8] data=[85;8];
        var owners::Table table=owners::empty(8);let owners::Token root=token(owners::create(ref shape,0,ref mut data,ref mut table));
        let owners::Token source=token(owners::create(ref shape,1,ref mut data,ref mut table));var i64[1] regs=[2];
        let usize select=run(ref p,ref c,3,0,ref mut state,ref table,root,source,ref mut data,ref regs,ref mut values,ref mut encoded,97);
        data[3]=7;let u8[8] before=data;let usize selected=digest(ref state);let usize price=ok(execution::cost(ref p,4,0));
        failed(execution::step(ref p,ref c,4,0,0,ref mut state,ref table,root,source,ref mut data,ref regs,ref mut values,ref mut encoded,price),5);
        same(ref data,ref before);assert(digest(ref state)==selected);
        regs[0]=1;data[3]=1;let usize retry=run(ref p,ref c,4,0,ref mut state,ref table,root,source,ref mut data,ref regs,ref mut values,ref mut encoded,price);
        assert(data[0]==1 && data[1]==1);execution::abort(ref mut state);assert(execution::empty_frame(ref state,0,77).is_ok);mode+=1;
    }
}
@test fn void active_loan_and_released_generation_never_publish_and_abort_needs_no_fuel(){
    let ir::Program p=array(1,2,2);let records::Prepared c=shapes(ref p);var vec::Vec<usize> state=prepare(ref p);
    var vec::Vec<i64> values=vec::empty<i64>();var bytes::Buffer encoded=bytes::empty();let i64[1] regs=[42];
    let arrays::Array shape=arrays::Array{.element=1,.length=2,.stride=4,.alignment=4,.bytes=8};var u8[16] data=[85;16];var owners::Table table=owners::empty(16);
    let owners::Token root=token(owners::create(ref shape,20,ref mut data,ref mut table));let usize price=ok(execution::cost(ref p,4,0));
    let usize select=run(ref p,ref c,3,0,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,97);
    let owners::ReadLease lease=switch(owners::begin_read(ref mut table,root,16)){case .ok(v):{v}case .err(_):{assert(false);owners::ReadLease{.root=root,.generation=0}}};
    let u8[16] before=data;failed(execution::step(ref p,ref c,4,0,0,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,price),5);same(ref data,ref before);
    assert(owners::end_read(ref mut table,lease,16).is_ok);assert(owners::release(ref mut table,root,16).is_ok);
    let owners::Token reused=token(owners::create(ref shape,20,ref mut data,ref mut table));
    failed(execution::step(ref p,ref c,4,0,0,ref mut state,ref table,reused,reused,ref mut data,ref regs,ref mut values,ref mut encoded,price),5);
    let usize serial=execution::inspect(ref state)[2];execution::abort(ref mut state);
    assert(execution::empty_frame(ref state,0,77).is_ok && execution::inspect(ref state)[2]==serial);
    let usize again=run(ref p,ref c,3,0,ref mut state,ref table,reused,reused,ref mut data,ref regs,ref mut values,ref mut encoded,97);
    assert(execution::inspect(ref state)[20]==serial && execution::inspect(ref state)[2]==serial+1);
}
@test fn void full_pool_scratch_and_maximum_array_keep_exact_prices_without_new_owners(){
    let ir::Program p=array(9,3,4096);let records::Prepared c=shapes(ref p);var vec::Vec<usize> state=prepare(ref p);
    let lists::Requirement lp=list_plan(ref p);assert(lp.length==4096 && lp.bytes==32768 && lp.cost==41217);
    var vec::Vec<i64> values=cells(ref lp);var bytes::Buffer encoded=scratch(ref lp);
    var bytes::Buffer payload=switch(backing::prepare(65536)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    let ref mut u8[] data=bytes::view_mut(ref mut payload);var owners::Table table=owners::empty(65536);let i64[1] regs=[42];
    let arrays::Array shape=arrays::Array{.element=9,.length=4096,.stride=8,.alignment=8,.bytes=32768};
    let owners::Token root=token(owners::create(ref shape,20,data,ref mut table));let owners::Token source=token(owners::create(ref shape,22,data,ref mut table));
    assert(table.arena.used==65536 && ok(execution::cost(ref p,4,0))==102546);
    let usize select=run(ref p,ref c,3,0,ref mut state,ref table,root,source,data,ref regs,ref mut values,ref mut encoded,97);
    let usize store=run(ref p,ref c,4,0,ref mut state,ref table,root,source,data,ref regs,ref mut values,ref mut encoded,102546);
    assert(switch(owners::read(ref table,root,4095,data)){case .ok(v):{v==42}case .err(_):{false}});
    assert(table.depth==2 && table.arena.used==65536 && bytes::len(ref encoded)==32768);
}
@test fn void frame_reuse_and_512_pending_locations_have_distinct_tickets_and_prepaid_abort(){
    var ir::Program p=array(1,2,2);p.count=3;p.registers=1;p.types[1]=0;p.constant_count=1;p.constants[1]=0;
    var usize i=24;while(i<2048){p.code[i]=0;i+=1;}
    i=0;while(i<16){let usize s=ok(places::select_array(ref mut p,i,0,77));i+=1;}
    i=0;while(i<16){let usize e=ok(ir::place_end(ref mut p,i,77));i+=1;}
    let usize db=ok(ir::array_drop(ref mut p,1,0));let usize da=ok(ir::array_drop(ref mut p,0,0));
    let usize ret=ok(ir::emit(ref mut p,8,0,0,0));finish(ref mut p);assert(verifier::inspect_aggregate_places(ref p).is_ok);
    let records::Prepared c=shapes(ref p);var vec::Vec<usize> state=prepare(ref p);var vec::Vec<i64> values=vec::empty<i64>();var bytes::Buffer encoded=bytes::empty();
    var u8[8] data=[85;8];var owners::Table table=owners::empty(8);let i64[1] regs=[42];
    let arrays::Array shape=arrays::Array{.element=1,.length=2,.stride=4,.alignment=4,.bytes=8};let owners::Token root=token(owners::create(ref shape,20,ref mut data,ref mut table));
    var usize frame=0;while(frame<32){i=0;while(i<16){let usize s=run(ref p,ref c,3+i,frame,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,97);i+=1;}
        assert(!execution::empty_frame(ref state,frame,77).is_ok);frame+=1;}
    assert(execution::inspect(ref state)[2]==513 && vec::len<usize>(ref state)==9251);
    execution::abort(ref mut state);frame=0;while(frame<32){assert(execution::empty_frame(ref state,frame,77).is_ok);frame+=1;}
    let usize again=run(ref p,ref c,3,31,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,97);
    assert(execution::inspect(ref state)[2]==514);let usize end=run(ref p,ref c,19,31,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,26);
    assert(execution::empty_frame(ref state,31,77).is_ok);
}
@test fn void native_snapshot_tampering_short_scratch_and_late_record_values_fail_atomically(){
    let ir::Program p=record(true);let records::Prepared c=shapes(ref p);var vec::Vec<usize> state=prepare(ref p);
    var vec::Vec<i64> values=vec::empty<i64>();var bytes::Buffer encoded=bytes::empty();var i64[4] regs=[42,2,0,0];
    var u8[32] data=[85;32];var owners::Table table=owners::empty(32);let i64[4] fields=[20,0,22,1];
    let owners::Token root=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
    let usize s=run(ref p,ref c,6,0,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,41057);
    let u8[32] before=data;let usize selected=digest(ref state);
    failed(execution::step(ref p,ref c,7,0,0,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,128162),5);
    same(ref data,ref before);assert(digest(ref state)==selected);regs[1]=1;
    let usize[6] positions=[9,10,15,16,19,21];let usize[6] invalid_values=[0,0,1,1,0,2];var usize i=0;
    while(i<6){let usize index=positions[i];let usize saved=execution::inspect(ref state)[index];
        {let ref mut usize[] words=vec::view_mut_usize(ref mut state);words[index]=invalid_values[i];}
        failed(execution::step(ref p,ref c,7,0,0,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,128162),5);
        same(ref data,ref before);{let ref mut usize[] words=vec::view_mut_usize(ref mut state);words[index]=saved;}i+=1;
    }
    let usize w=run(ref p,ref c,7,0,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,128162);
    assert(data[8]==42 && data[12]==1);
    short_scratch();
}
fn void short_scratch(){
    let ir::Program p=array(9,3,2);let records::Prepared c=shapes(ref p);var vec::Vec<usize> state=prepare(ref p);
    let lists::Requirement lp=list_plan(ref p);var vec::Vec<i64> values=cells(ref lp);var bytes::Buffer encoded=bytes::empty();
    var u8[32] data=[85;32];var owners::Table table=owners::empty(32);let i64[1] regs=[42];
    let arrays::Array shape=arrays::Array{.element=9,.length=2,.stride=8,.alignment=8,.bytes=16};
    let owners::Token root=token(owners::create(ref shape,20,ref mut data,ref mut table));
    let usize s=run(ref p,ref c,3,0,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,97);
    let u8[32] before=data;let usize selected=digest(ref state);
    failed(execution::step(ref p,ref c,4,0,0,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,196),5);
    same(ref data,ref before);assert(digest(ref state)==selected);
}
@test fn void maximum_record_depth_128_registers_and_full_owner_capacity_preserve_prices(){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;p.records.layouts.count=16;
    var usize i=0;var u8 child=1;while(i<15){p.records.layouts.fields[i]=if(i<7){2}else{1};
        p.records.layouts.kinds[i*16]=1;p.records.layouts.types[i*16]=child;
        if(i<7){p.records.layouts.kinds[i*16+1]=1;p.records.layouts.types[i*16+1]=child;}child+=1;i+=1;}
    p.records.layouts.fields[15]=1;p.records.layouts.types[240]=2;let usize root_site=ok(ir::record(ref mut p,0,true,0));
    i=0;while(i<128){let usize v=ok(ir::boolean(ref mut p,true,0));i+=1;}
    let usize init=ok(ir::record_init(ref mut p,root_site,0,0));let usize select=ok(places::select_record(ref mut p,0,root_site,0,0,77));
    let usize store=ok(places::replace_record(ref mut p,0,root_site,0,0,0,77));let usize end=ok(ir::place_end(ref mut p,0,77));
    let usize drop=ok(ir::record_drop(ref mut p,root_site,0));let usize trap=ok(ir::raw(ref mut p,25,0,0,0,0));finish(ref mut p);
    assert(verifier::inspect_aggregate_places(ref p).is_ok);let records::Prepared c=shapes(ref p);assert(c.leaves[0]==128);
    var vec::Vec<usize> state=prepare(ref p);var vec::Vec<i64> values=vec::empty<i64>();var bytes::Buffer encoded=bytes::empty();
    var u8[143] data=[85;143];var owners::Table table=owners::empty(143);let i64[128] fields=[0;128];let i64[128] regs=[1;128];
    let owners::Token root=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
    let arrays::Array byte=arrays::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1};i=0;
    while(i<15){let owners::Token extra=token(owners::create(ref byte,7,ref mut data,ref mut table));i+=1;}
    let usize s=run(ref p,ref c,select,31,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,41057);
    let usize w=run(ref p,ref c,store,31,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,128162);
    let usize e=run(ref p,ref c,end,31,ref mut state,ref table,root,root,ref mut data,ref regs,ref mut values,ref mut encoded,26);
    assert(data[0]==1 && data[127]==1 && data[142]==7 && table.depth==16 && table.arena.used==143);
    assert(execution::empty_frame(ref state,31,77).is_ok);
}

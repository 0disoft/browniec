module tests::m2::record_place_vm;
import record_place_vm as execution;
import place_vm as arrays;
import slice_place_vm as mixed;
import struct_meta as records;
import array_owners as owners;
import array_layout as layouts;
import array_slices as slices;
import ir as ir;
import errors as errors;
import std::vec as vec;

fn usize ok(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};}
fn execution::Requirement required(ref ir::Program p){return switch(execution::requirement(p)){
    case .ok(v):{v}case .err(_):{assert(false);execution::Requirement{.width=0,.slices=false,.records=false,.cost=0}}
};}
fn records::Prepared catalog(ref ir::Program p){return switch(records::prepare(ref p.records)){
    case .ok(v):{v}case .err(_):{assert(false);records::Prepared{.leaves=[0;16],.tags=[0;2048]}}
};}
fn vec::Vec<usize> prepared(ref execution::Requirement plan){return switch(execution::prepare_metered(plan,plan.cost)){
    case .ok(v):{v}case .err(_):{assert(false);vec::empty<usize>()}
};}
fn void failed(Result<usize,errors::Error> r,u8 kind){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==77}});}
fn void same(ref u8[] a,ref u8[] b){assert(a.len==b.len);var usize i=0;while(i<a.len){assert(a[i]==b[i]);i+=1;}}
fn void words_same(ref vec::Vec<usize> state,ref usize[] before){let ref usize[] now=vec::view_usize(state);
    assert(now.len==before.len);var usize i=0;while(i<now.len){assert(now[i]==before[i]);i+=1;}}
fn void change(ref mut vec::Vec<usize> state,usize index,usize value){let ref mut usize[] words=vec::view_mut_usize(state);words[index]=value;}
fn ir::Program unit(u8 tag){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.records.count=1;p.records.mutable[0]=true;
    p.records.layouts.count=2;p.records.layouts.fields[0]=1;p.records.layouts.kinds[0]=1;p.records.layouts.types[0]=1;
    p.records.layouts.fields[1]=2;p.records.layouts.types[16]=tag;p.records.layouts.types[17]=tag;
    p.registers=3;p.types[0]=tag;p.types[1]=tag;p.types[2]=tag;
    let usize s=ok(ir::raw(ref mut p,83,0,0,0,77));let usize r=ok(ir::raw(ref mut p,84,1,0,0,77));
    let usize w=ok(ir::raw(ref mut p,85,0,0,2,77));let usize e=ok(ir::raw(ref mut p,86,0,0,0,77));
    p.code[4]=2;p.code[12]=2;p.code[20]=2;let usize end=p.count;let usize regs=p.registers;
    p.ends[0]=end;p.register_ends[0]=regs;return p;
}
fn usize run(ref ir::Program p,ref records::Prepared shapes,usize pc,usize frame,ref mut vec::Vec<usize> state,
    ref owners::Table table,owners::Token root,ref mut u8[] data,ref mut i64[] regs,usize fuel){
    return ok(execution::step(p,shapes,pc,0,frame,state,table,root,data,regs,fuel));
}

@test fn void six_scalar_domains_prepay_each_effect_at_independent_exact_prices(){
    let u8[6] tags=[1,2,9,10,11,12];let usize[6] strides=[4,1,8,1,4,8];var usize i=0;
    while(i<6){let ir::Program p=unit(tags[i]);let records::Prepared shapes=catalog(ref p);
        let execution::Requirement plan=required(ref p);assert(plan.width==1 && plan.records && !plan.slices && plan.cost==5077);
        assert(!execution::prepare_metered(ref plan,5076).is_ok);var vec::Vec<usize> state=prepared(ref plan);
        assert(vec::len<usize>(ref state)==482);let usize[482] empty=[0;482];
        var u8[32] data=[85;32];var owners::Table table=owners::empty(32);let i64[2] fields=[20,20];
        let i64[2] bools=[0,1];let owners::Token root=token(owners::create_record(ref p.records.layouts,0,
            if(tags[i]==2){ref bools}else{ref fields},ref mut data,ref mut table));
        var i64[3] regs=[999,888,if(tags[i]==2){1}else{42}];
        let usize[4] prices=[41025,41025+strides[i],41025+2*strides[i],22];var usize pc=0;
        while(pc<4){assert(ok(execution::cost(ref p,ref shapes,pc,0,ref state))==prices[pc]);
            let u8[32] saved=data;let i64[3] old=regs;var usize[482] before=[0;482];var usize n=0;
            while(n<482){before[n]=vec::view_usize(ref state)[n];n+=1;}
            failed(execution::step(ref p,ref shapes,pc,0,0,ref mut state,ref table,root,ref mut data,ref mut regs,prices[pc]-1),8);
            same(ref data,ref saved);words_same(ref state,ref before);assert(regs[0]==old[0] && regs[1]==old[1] && regs[2]==old[2]);
            assert(run(ref p,ref shapes,pc,0,ref mut state,ref table,root,ref mut data,ref mut regs,prices[pc])==0);pc+=1;
        }
        assert(regs[1]==if(tags[i]==2){0}else{20});assert(arrays::empty_frame(ref state,0,77).is_ok);
        assert(table.depth==1 && table.arena.used==2*strides[i]);i+=1;
    }
}

@test fn void original_nominal_leaf_and_old_scalar_survive_rhs_descriptor_and_payload_changes(){
    let ir::Program p=unit(9);let records::Prepared shapes=catalog(ref p);let execution::Requirement plan=required(ref p);
    var vec::Vec<usize> state=prepared(ref plan);var u8[64] data=[85;64];var owners::Table table=owners::empty(64);
    let i64[2] fields=[20,99];let owners::Token root=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
    var owners::Token current=root;var i64[3] regs=[0;3];
    let usize selected=run(ref p,ref shapes,0,0,ref mut state,ref table,current,ref mut data,ref mut regs,41025);
    let usize read=run(ref p,ref shapes,1,0,ref mut state,ref table,current,ref mut data,ref mut regs,41033);
    current=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
    let i64[2] replacement=[100,200];assert(owners::replace_record(ref p.records.layouts,root,0,ref replacement,ref mut data,ref table).is_ok);
    regs[2]=regs[1]+22;let usize stored=run(ref p,ref shapes,2,0,ref mut state,ref table,current,ref mut data,ref mut regs,41041);
    let usize[2] path=[0,0];let usize[2] other=[0,1];
    assert(switch(owners::read_record(ref p.records.layouts,ref table,root,ref path,ref data)){case .ok(v):{v==42}case .err(_):{false}});
    assert(switch(owners::read_record(ref p.records.layouts,ref table,root,ref other,ref data)){case .ok(v):{v==200}case .err(_):{false}});
    assert(switch(owners::read_record(ref p.records.layouts,ref table,current,ref path,ref data)){case .ok(v):{v==20}case .err(_):{false}});
    let usize end=run(ref p,ref shapes,3,0,ref mut state,ref table,current,ref mut data,ref mut regs,22);
}

@test fn void field_substitution_nominal_changes_bad_phases_and_snapshot_corruption_are_atomic(){
    var ir::Program p=unit(9);let records::Prepared shapes=catalog(ref p);let execution::Requirement plan=required(ref p);
    var vec::Vec<usize> state=prepared(ref plan);var u8[32] data=[85;32];var owners::Table table=owners::empty(32);
    let i64[2] fields=[20,99];let owners::Token root=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
    var i64[3] regs=[0,88,42];let usize selected=run(ref p,ref shapes,0,0,ref mut state,ref table,root,ref mut data,ref mut regs,41025);
    let u8[32] saved=data;let usize[10] at=[3,4,5,6,7,8,9,10,11,13];var usize n=0;
    while(n<10){let usize index=at[n];let usize old=vec::view_usize(ref state)[index];change(ref mut state,index,old+1);
        assert(!execution::step(ref p,ref shapes,2,0,0,ref mut state,ref table,root,ref mut data,ref mut regs,41041).is_ok);
        same(ref data,ref saved);change(ref mut state,index,old);n+=1;}
    p.code[21]=1;failed(execution::step(ref p,ref shapes,2,0,0,ref mut state,ref table,root,ref mut data,ref mut regs,41041),5);p.code[21]=0;
    let usize read=run(ref p,ref shapes,1,0,ref mut state,ref table,root,ref mut data,ref mut regs,41033);
    failed(execution::step(ref p,ref shapes,1,0,0,ref mut state,ref table,root,ref mut data,ref mut regs,41033),5);
    let usize stored=run(ref p,ref shapes,2,0,ref mut state,ref table,root,ref mut data,ref mut regs,41041);
    failed(execution::step(ref p,ref shapes,2,0,0,ref mut state,ref table,root,ref mut data,ref mut regs,41041),5);
    let usize ended=run(ref p,ref shapes,3,0,ref mut state,ref table,root,ref mut data,ref mut regs,22);
    failed(execution::step(ref p,ref shapes,3,0,0,ref mut state,ref table,root,ref mut data,ref mut regs,22),5);
}

@test fn void invalid_bool_payload_can_be_repaired_but_failed_read_and_encoding_do_not_publish(){
    let ir::Program p=unit(2);let records::Prepared shapes=catalog(ref p);let execution::Requirement plan=required(ref p);
    var vec::Vec<usize> state=prepared(ref plan);var u8[16] data=[85;16];var owners::Table table=owners::empty(16);
    let i64[2] fields=[0,1];let owners::Token root=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
    data[0]=7;var i64[3] regs=[0,88,2];let usize s=run(ref p,ref shapes,0,0,ref mut state,ref table,root,ref mut data,ref mut regs,41025);
    assert(!execution::step(ref p,ref shapes,1,0,0,ref mut state,ref table,root,ref mut data,ref mut regs,41026).is_ok);
    assert(!execution::step(ref p,ref shapes,2,0,0,ref mut state,ref table,root,ref mut data,ref mut regs,41027).is_ok);
    assert(data[0]==7 && regs[1]==88 && vec::view_usize(ref state)[16]==(2048|256|2));
    regs[2]=1;let usize w=run(ref p,ref shapes,2,0,ref mut state,ref table,root,ref mut data,ref mut regs,41027);
    assert(data[0]==1 && data[1]==1);let usize e=run(ref p,ref shapes,3,0,ref mut state,ref table,root,ref mut data,ref mut regs,22);
}

@test fn void stale_owner_reuse_and_wrong_current_nominal_cannot_rebind_selected_locations(){
    let ir::Program p=unit(9);let records::Prepared shapes=catalog(ref p);let execution::Requirement plan=required(ref p);
    var vec::Vec<usize> state=prepared(ref plan);var u8[32] data=[85;32];var owners::Table table=owners::empty(32);
    let i64[2] fields=[20,99];let owners::Token root=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
    var i64[3] regs=[0,88,42];let usize s=run(ref p,ref shapes,0,0,ref mut state,ref table,root,ref mut data,ref mut regs,41025);
    assert(owners::release(ref mut table,root,data.len).is_ok);
    let owners::Token reused=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
    let u8[32] saved=data;assert(reused.slot==root.slot && reused.generation!=root.generation);
    assert(!execution::step(ref p,ref shapes,1,0,0,ref mut state,ref table,reused,ref mut data,ref mut regs,41033).is_ok);
    assert(!execution::step(ref p,ref shapes,2,0,0,ref mut state,ref table,reused,ref mut data,ref mut regs,41041).is_ok);
    same(ref data,ref saved);assert(regs[1]==88);
    let usize e=run(ref p,ref shapes,3,0,ref mut state,ref table,reused,ref mut data,ref mut regs,22);
    let i64[2] child=[1,2];let owners::Token wrong=token(owners::create_record(ref p.records.layouts,1,ref child,ref mut data,ref mut table));
    failed(execution::step(ref p,ref shapes,0,0,0,ref mut state,ref table,wrong,ref mut data,ref mut regs,41025),5);
    assert(arrays::empty_frame(ref state,0,77).is_ok);
}

@test fn void last_frame_sixteenth_id_and_disjoint_mixed_prefixes_keep_existing_prices(){
    var ir::Program p=unit(10);p.code[1]=15;p.code[10]=15;p.code[17]=15;p.code[25]=15;
    let records::Prepared shapes=catalog(ref p);let execution::Requirement plan=required(ref p);
    assert(plan.width==16 && plan.cost==72277);var vec::Vec<usize> state=prepared(ref plan);assert(vec::len<usize>(ref state)==7202);
    var u8[16] data=[85;16];var owners::Table table=owners::empty(16);let i64[2] fields=[20,99];
    let owners::Token root=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));var i64[3] regs=[0,0,42];
    let usize s=run(ref p,ref shapes,0,31,ref mut state,ref table,root,ref mut data,ref mut regs,41025);
    assert(!arrays::empty_frame(ref state,31,77).is_ok && arrays::empty_frame(ref state,30,77).is_ok);
    let usize w=run(ref p,ref shapes,2,31,ref mut state,ref table,root,ref mut data,ref mut regs,41027);
    let usize e=run(ref p,ref shapes,3,31,ref mut state,ref table,root,ref mut data,ref mut regs,22);
    assert(arrays::empty_frame(ref state,31,77).is_ok && data[0]==42);
    let usize again=run(ref p,ref shapes,0,31,ref mut state,ref table,root,ref mut data,ref mut regs,41025);
    change(ref mut state,0,14352);assert(!arrays::format(ref state,77).is_ok);change(ref mut state,0,18448);
    change(ref mut state,1,1);assert(!arrays::format(ref state,77).is_ok);change(ref mut state,1,2);
    failed(execution::step(ref p,ref shapes,3,0,32,ref mut state,ref table,root,ref mut data,ref mut regs,22),5);
    let usize end=run(ref p,ref shapes,3,31,ref mut state,ref table,root,ref mut data,ref mut regs,22);
}

@test fn void record_array_and_slice_rows_share_ids_without_cross_kind_overwrites(){
    var ir::Program p=unit(10);let usize rootid=ok(ir::array(ref mut p,10,2,true,77));
    let usize site=ok(ir::exclusive_slice(ref mut p,rootid,77));let records::Prepared shapes=catalog(ref p);
    let execution::Requirement plan=required(ref p);var vec::Vec<usize> state=prepared(ref plan);
    var u8[16] data=[85;16];var owners::Table table=owners::empty(16);let i64[2] fields=[20,99];
    let owners::Token record=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
    let layouts::Array shape=layouts::Array{.element=10,.length=2,.stride=1,.alignment=1,.bytes=2};
    let owners::Token root=token(owners::create(ref shape,7,ref mut data,ref mut table));
    var owners::Token[512] tokens=[owners::Token{.slot=16,.generation=0};512];tokens[0]=root;var i64[3] regs=[0,0,42];
    let usize s=run(ref p,ref shapes,0,0,ref mut state,ref table,record,ref mut data,ref mut regs,41025);
    p.code[4]=0;assert(!arrays::step(ref p,0,0,ref mut state,ref table,ref tokens,ref mut data,ref mut regs,65).is_ok);
    p.code[4]=1;var slices::Pool pool=slices::empty();
    let slices::Ticket ticket=switch(slices::open_exclusive(ref mut pool,ref mut table,root,0,2,data.len)){
        case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}
    };
    assert(!mixed::step(ref p,0,0,0,ref mut state,ref table,ref tokens,ref pool,ticket,ref mut data,ref mut regs,4129).is_ok);
    p.code[4]=2;let usize end=run(ref p,ref shapes,3,0,ref mut state,ref table,record,ref mut data,ref mut regs,22);
    p.code[4]=1;let usize ss=ok(mixed::step(ref p,0,0,0,ref mut state,ref table,ref tokens,ref pool,ticket,ref mut data,ref mut regs,4129));
    p.code[4]=2;failed(execution::step(ref p,ref shapes,0,0,0,ref mut state,ref table,record,ref mut data,ref mut regs,41025),5);
    let usize se=run(ref p,ref shapes,3,0,ref mut state,ref table,record,ref mut data,ref mut regs,22);
    assert(slices::close(ref mut pool,ticket,ref mut table,data.len).is_ok);
    p.code[4]=0;let usize asel=ok(arrays::step(ref p,0,0,ref mut state,ref table,ref tokens,ref mut data,ref mut regs,65));
    let usize ae=run(ref p,ref shapes,3,0,ref mut state,ref table,record,ref mut data,ref mut regs,22);
    assert(arrays::empty_frame(ref state,0,77).is_ok);
}

@test fn void malformed_encoding_preparation_and_legacy_adapters_keep_execution_gated(){
    var ir::Program p=unit(9);let records::Prepared shapes=catalog(ref p);
    assert(!arrays::requirement(ref p).is_ok && !mixed::requirement(ref p).is_ok);
    p.code[5]=128;assert(!execution::requirement(ref p).is_ok);p.code[5]=0;
    p.code[3]=1;assert(!execution::requirement(ref p).is_ok);p.code[3]=0;
    p.code[6]=1;assert(!execution::requirement(ref p).is_ok);p.code[6]=0;
    p.code[28]=2;assert(!execution::requirement(ref p).is_ok);p.code[28]=0;
    var execution::Requirement plan=required(ref p);plan.width=17;assert(!execution::prepare(ref plan).is_ok);
    plan.width=1;plan.cost=5076;assert(!execution::prepare(ref plan).is_ok);
    plan.width=0;plan.cost=0;assert(!execution::prepare(ref plan).is_ok);
    let ir::Program empty=ir::empty();let execution::Requirement zero=required(ref empty);assert(zero.cost==0 && zero.width==0);
    let vec::Vec<usize> none=prepared(ref zero);assert(vec::len<usize>(ref none)==0);
    p.code[4]=0;p.code[12]=0;p.code[20]=0;let execution::Requirement ordinary=required(ref p);
    assert(ordinary.cost==3457 && !ordinary.records && !ordinary.slices);
    p.code[4]=1;let execution::Requirement slice=required(ref p);assert(slice.cost==5067 && slice.slices && !slice.records);
    p.code[12]=2;let execution::Requirement both=required(ref p);assert(both.cost==5077 && both.slices && both.records);
}

@test fn void maximum_depth_leaves_and_full_owner_backing_capacity_keep_constant_prices(){
    var ir::Program p=unit(10);p.records=records::empty();p.records.count=1;p.records.mutable[0]=true;
    p.records.layouts.count=16;var usize i=0;var u8 child=1;
    while(i<15){p.records.layouts.fields[i]=if(i<7){2}else{1};
        p.records.layouts.kinds[i*16]=1;p.records.layouts.types[i*16]=child;
        if(i<7){p.records.layouts.kinds[i*16+1]=1;p.records.layouts.types[i*16+1]=child;}
        child+=1;i+=1;
    }
    p.records.layouts.fields[15]=1;p.records.layouts.types[240]=10;
    p.code[5]=127;p.code[13]=127;p.code[21]=127;
    let records::Prepared shapes=catalog(ref p);assert(shapes.leaves[0]==128);
    let execution::Requirement plan=required(ref p);var vec::Vec<usize> state=prepared(ref plan);
    var u8[143] data=[85;143];var owners::Table table=owners::empty(143);let i64[128] fields=[20;128];
    let owners::Token root=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
    let layouts::Array byte=layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1};
    i=0;while(i<15){let owners::Token extra=token(owners::create(ref byte,7,ref mut data,ref mut table));i+=1;}
    var i64[3] regs=[0,0,42];let usize s=run(ref p,ref shapes,0,0,ref mut state,ref table,root,ref mut data,ref mut regs,41025);
    let usize r=run(ref p,ref shapes,1,0,ref mut state,ref table,root,ref mut data,ref mut regs,41026);assert(regs[1]==20);
    let usize w=run(ref p,ref shapes,2,0,ref mut state,ref table,root,ref mut data,ref mut regs,41027);
    let usize e=run(ref p,ref shapes,3,0,ref mut state,ref table,root,ref mut data,ref mut regs,22);
    assert(table.depth==16 && table.arena.used==143 && data[126]==20 && data[127]==42 && data[142]==7);
    assert(vec::len<usize>(ref state)==482 && arrays::empty_frame(ref state,0,77).is_ok);
}

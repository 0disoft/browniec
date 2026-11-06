module tests::m2::place_vm;
import place_vm as execution;
import array_owners as owners;
import array_layout as layouts;
import ir as ir;
import errors as errors;
import std::vec as vec;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};}
fn ir::Program unit(u8 tag){
    var ir::Program p=ir::empty();let usize root=built(ir::array(ref mut p,tag,2,true,0));
    let usize selected=built(ir::raw(ref mut p,83,0,root,0,0));
    let usize read=built(ir::raw(ref mut p,84,1,0,root,0));
    let usize stored=built(ir::raw(ref mut p,85,0,root,2,0));
    let usize ended=built(ir::raw(ref mut p,86,0,0,0,0));return p;
}
fn vec::Vec<usize> prepared(ref ir::Program p){
    let execution::Requirement plan=switch(execution::requirement(p)){case .ok(n):{n}case .err(_):{assert(false);return vec::empty<usize>();}};
    return switch(execution::prepare(ref plan)){case .ok(v):{v}case .err(_):{assert(false);vec::empty<usize>()}};
}
fn owners::Token created(u8 tag,i64 cell,ref mut u8[] data,ref mut owners::Table table){
    let layouts::Array a=switch(layouts::scalar(tag,2)){case .ok(v):{v}case .err(_):{assert(false);return created(1,0,data,table);}};
    return switch(owners::create(ref a,cell,data,table)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}};
}
fn i64 value(ref owners::Table table,owners::Token root,usize index,ref u8[] data){
    return switch(owners::read(table,root,index,data)){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn void failed(Result<usize,errors::Error> r,u8 kind){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind}});}

@test fn void six_scalar_domains_match_independent_prices_and_preflight_each_effect(){
    let u8[6] tags=[1,2,9,10,11,12];let usize[6] reads=[69,66,73,66,69,73];
    let usize[6] writes=[73,67,81,67,73,81];var usize i=0;
    while(i<6){let ir::Program p=unit(tags[i]);var vec::Vec<usize> state=prepared(ref p);
        assert(vec::len<usize>(ref state)==320);
        var u8[32] data=[85;32];var owners::Table table=owners::empty(32);
        let i64 initial=if(tags[i]==2){0}else{20};let i64 result=if(tags[i]==2){1}else{42};
        let owners::Token root=created(tags[i],initial,ref mut data,ref mut table);
        var owners::Token[512] tokens=[owners::Token{.slot=0,.generation=0};512];tokens[0]=root;
        var i64[3] registers=[0,777,result];
        failed(execution::step(ref p,0,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,64),8);
        assert(execution::empty_frame(ref state,0,0).is_ok && registers[1]==777);
        assert(built(execution::step(ref p,0,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,65))==0);
        failed(execution::step(ref p,1,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,reads[i]-1),8);
        assert(registers[1]==777);
        assert(built(execution::step(ref p,1,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,reads[i]))==0);
        assert(registers[1]==initial);
        failed(execution::step(ref p,2,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,writes[i]-1),8);
        assert(value(ref table,root,0,ref data)==initial);
        assert(built(execution::step(ref p,2,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,writes[i]))==0);
        failed(execution::step(ref p,3,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,16),8);
        assert(!execution::empty_frame(ref state,0,0).is_ok);
        assert(built(execution::step(ref p,3,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,17))==0);
        assert(execution::empty_frame(ref state,0,0).is_ok);
        assert(value(ref table,root,0,ref data)==result && value(ref table,root,1,ref data)==initial);
        i+=1;
    }
}

@test fn void original_descriptor_index_and_old_scalar_survive_rhs_changes(){
    let ir::Program p=unit(1);var vec::Vec<usize> state=prepared(ref p);
    var u8[32] data=[85;32];var owners::Table table=owners::empty(32);
    let owners::Token first=created(1,20,ref mut data,ref mut table);
    var owners::Token[512] tokens=[owners::Token{.slot=0,.generation=0};512];tokens[0]=first;
    var i64[3] registers=[0,0,0];
    let usize selected=built(execution::step(ref p,0,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,65));
    let usize read=built(execution::step(ref p,1,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,69));
    let owners::Token next=created(1,99,ref mut data,ref mut table);tokens[0]=next;registers[0]=1;
    assert(owners::write(ref table,first,0,100,ref mut data).is_ok);registers[2]=registers[1]+22;
    let usize stored=built(execution::step(ref p,2,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,73));
    let usize ended=built(execution::step(ref p,3,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,17));
    assert(value(ref table,first,0,ref data)==42 && value(ref table,first,1,ref data)==20);
    assert(value(ref table,next,0,ref data)==99 && table.depth==2 && table.arena.used==16);
}

@test fn void stale_owners_and_outstanding_loans_cannot_publish_store_phases(){
    let ir::Program p=unit(1);var vec::Vec<usize> state=prepared(ref p);
    var u8[16] data=[85;16];var owners::Table table=owners::empty(16);
    let owners::Token first=created(1,20,ref mut data,ref mut table);
    var owners::Token[512] tokens=[owners::Token{.slot=0,.generation=0};512];tokens[0]=first;
    var i64[3] registers=[0,777,42];
    let usize selected=built(execution::step(ref p,0,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,65));
    assert(owners::release(ref mut table,first,data.len).is_ok);
    let owners::Token next=created(1,99,ref mut data,ref mut table);tokens[0]=next;
    failed(execution::step(ref p,2,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,73),5);
    assert((vec::view_usize(ref state)[9]>>8)==1 && value(ref table,next,0,ref data)==99);
    let usize abandoned=built(execution::step(ref p,3,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,17));
    let usize selected_again=built(execution::step(ref p,0,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,65));
    let owners::ReadLease lease=switch(owners::begin_read(ref mut table,next,data.len)){
        case .ok(v):{v}case .err(_):{assert(false);owners::ReadLease{.root=next,.generation=0}}
    };
    failed(execution::step(ref p,2,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,73),5);
    assert((vec::view_usize(ref state)[9]>>8)==1);
    assert(owners::end_read(ref mut table,lease,data.len).is_ok);
    let usize stored=built(execution::step(ref p,2,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,73));
    let usize ended=built(execution::step(ref p,3,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,17));
    assert(value(ref table,next,0,ref data)==42);
}

@test fn void corrupt_snapshot_phase_shape_and_vector_extent_fail_before_payload(){
    var ir::Program p=unit(1);var vec::Vec<usize> state=prepared(ref p);
    var u8[16] data=[85;16];var owners::Table table=owners::empty(16);
    let owners::Token root=created(1,20,ref mut data,ref mut table);
    var owners::Token[512] tokens=[owners::Token{.slot=0,.generation=0};512];tokens[0]=root;
    var i64[3] registers=[0,777,42];
    let usize selected=built(execution::step(ref p,0,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,65));
    {let ref mut usize[] words=vec::view_mut_usize(ref mut state);words[8]=4;}
    failed(execution::step(ref p,1,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,69),5);
    assert(registers[1]==777 && value(ref table,root,0,ref data)==20);
    {let ref mut usize[] words=vec::view_mut_usize(ref mut state);words[8]=0;words[9]|=16;}
    failed(execution::step(ref p,2,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,73),5);
    {let ref mut usize[] words=vec::view_mut_usize(ref mut state);words[9]=257;}
    p.arrays.lengths[0]=1;
    failed(execution::step(ref p,2,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,73),5);
    p.arrays.lengths[0]=2;
    let Option<usize> removed=vec::pop<usize>(ref mut state);discard removed;
    failed(execution::step(ref p,2,0,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,73),5);
    assert(value(ref table,root,0,ref data)==20 && registers[1]==777);
}

@test fn void last_frame_sixteenth_slot_abandonment_and_reuse_stay_bounded(){
    var ir::Program p=unit(1);p.code[1]=15;p.code[8+2]=15;p.code[16+1]=15;p.code[24+1]=15;
    let execution::Requirement plan=switch(execution::requirement(ref p)){case .ok(v):{v}case .err(_):{assert(false);execution::Requirement{.width=0,.cost=0}}};
    assert(plan.width==16 && plan.cost==46657);
    var vec::Vec<usize> state=prepared(ref p);assert(vec::len<usize>(ref state)==4640);
    var u8[16] data=[85;16];var owners::Table table=owners::empty(16);
    let owners::Token root=created(1,20,ref mut data,ref mut table);
    var owners::Token[512] tokens=[owners::Token{.slot=0,.generation=0};512];tokens[496]=root;
    var i64[3] registers=[0,0,42];var usize i=0;
    while(i<40){let usize selected=built(execution::step(ref p,0,31,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,65));
        assert(!execution::empty_frame(ref state,31,0).is_ok && execution::empty_frame(ref state,0,0).is_ok);
        let usize ended=built(execution::step(ref p,3,31,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,17));i+=1;
    }
    failed(execution::step(ref p,0,32,ref mut state,ref table,ref tokens,ref mut data,ref mut registers,65),5);
    assert(execution::empty_frame(ref state,31,0).is_ok && table.depth==1 && table.arena.used==8);
    assert(vec::len<usize>(ref state)==4640 && value(ref table,root,0,ref data)==20);
}

@test fn void empty_program_and_invalid_preparation_plans_preserve_zero_setup(){
    var ir::Program p=ir::empty();let execution::Requirement plan=switch(execution::requirement(ref p)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Requirement{.width=0,.cost=1}}
    };
    assert(plan.width==0 && plan.cost==0);let vec::Vec<usize> state=prepared(ref p);
    assert(vec::len<usize>(ref state)==0 && execution::empty_frame(ref state,31,0).is_ok);
    assert(!execution::empty_frame(ref state,32,0).is_ok);
    let execution::Requirement too_wide=execution::Requirement{.width=17,.cost=0};
    let execution::Requirement wrong_cost=execution::Requirement{.width=1,.cost=0};
    assert(!execution::prepare(ref too_wide).is_ok);
    assert(!execution::prepare(ref wrong_cost).is_ok);
    p=unit(1);let execution::Requirement one=switch(execution::requirement(ref p)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Requirement{.width=0,.cost=0}}
    };assert(one.width==1 && one.cost==3457);
}

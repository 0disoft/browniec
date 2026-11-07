module tests::m2::value_fresh_loop_owners_runtime;
import value_ir as values;
import value_properties as properties;
import verifier as verifier;
import vm as vm;
import ir as ir;
import errors as errors;
import buffer_growth as growth;
import value_program as programs;
import value_runtime as runtime;
import value_view_runtime as view_runtime;
import value_buffer_views as views;
import value_frames as frames;
import value_roots as roots;
import std::bytes as bytes;
import std::vec as vec;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn usize ok(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn properties::Node node(u8 k,u8 a,u8 b){return properties::Node{.kind=k,.first=a,.second=b,.extent=0};}
fn usize emit(ref mut values::Program u,u8 op,usize dst,usize a,usize b){return ok(ir::raw(ref mut u.body,op,dst,a,b,71));}
fn values::Program fixture(){
    var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[1,0,4,1,0,0,0,0,0,0,0,0,0,0,0,0],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    u.catalog.count=4;u.catalog.nodes[0]=node(4,0,0);u.catalog.nodes[1]=node(1,12,0);
    u.catalog.nodes[2]=node(1,10,0);u.catalog.nodes[3]=node(6,1,2);
    let usize answer=ok(ir::literal(ref mut u.body,42,71));
    let usize zero=ok(ir::integer(ref mut u.body,0,12,71));
    let usize one=ok(ir::integer(ref mut u.body,1,12,71));
    let usize byte=ok(ir::integer(ref mut u.body,42,10,71));
    let usize empty=emit(ref mut u,95,0,0,0);let usize push=emit(ref mut u,102,2,0,3);
    let usize handled=emit(ref mut u,90,2,0,0);
    let usize begin=emit(ref mut u,105,0,0,1);u.body.code[begin*8+4]=2;
    let usize alias=emit(ref mut u,107,1,0,0);
    let usize moved=emit(ref mut u,88,3,0,0);
    let usize read=u.body.registers;u.body.registers+=1;u.body.types[read]=10;
    let usize reading=emit(ref mut u,111,read,1,1);
    let usize a=emit(ref mut u,109,0,0,0);let usize b=emit(ref mut u,109,1,0,0);
    let usize drop=emit(ref mut u,90,3,0,0);let usize end=emit(ref mut u,8,0,0,0);
    let usize count=u.body.count;let usize registers=u.body.registers;
    u.body.function_count=1;u.body.ends[0]=count;u.body.register_ends[0]=registers;u.body.return_types[0]=1;
    return u;
}
fn programs::Program retained(ref values::Program u){return switch(programs::retain(u)){
    case .ok(v):{v}case .err(_):{assert(false);retained(u)}
};}
fn usize find(ref values::Program u,u8 op){var usize pc=0;while(pc<u.body.count){if(u.body.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 256;}

fn bool is_quota(Result<usize,frames::Error> result){return switch(result){
    case .ok(_):{false}case .err(e):{switch(e){case .Quota:{true}case .Fuel:{false}
        case .State:{false}case .Type:{false}case .Bounds:{false}case .Allocation:{false}case .Value:{false}case .Owner:{false}}}
};}

@test fn void pinned_move_keeps_serial_token_range_aliases_price_and_failure_drain(){
    let values::Program u=fixture();assert(verifier::inspect_values(ref u).is_ok);
    assert(switch(vm::run_values(ref u,4000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
    let programs::Program p=retained(ref u);
    let runtime::Budget budget=switch(runtime::budget(ref p,0,limits(),4000000)){
        case .ok(v):{v}case .err(_):{assert(false);runtime::Budget{.values=limits(),.initial=0}}
    };
    var vec::Vec<frames::State> states=vec::empty<frames::State>();var vec::Vec<roots::State> stores=vec::empty<roots::State>();
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> backing=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> rs=vec::empty<bytes::Buffer>();
    var vec::Vec<views::Pool> pools=vec::empty<views::Pool>();
    var usize fuel=ok(runtime::setup(ref p,ref mut states,ref mut stores,ref mut data,ref mut scratch,
        ref mut backing,ref mut rs,budget.values,4000000));
    assert(view_runtime::setup(ref u.body,ref mut pools,ref states,ref mut stores,ref backing,ref rs,budget.values,ref mut fuel).is_ok);
    var i64[128] registers=[0;128];registers[0]=42;registers[2]=1;registers[3]=42;
    var usize pc=find(ref u,95);let usize move=find(ref u,88);
    while(pc<move){let runtime::Step step=switch(runtime::instruction_views(ref p,pc,0,ref mut states,ref mut stores,
        ref mut data,ref mut scratch,ref mut backing,ref mut rs,ref mut pools,ref mut registers,budget.values,fuel)){
        case .ok(v):{v}case .err(_):{assert(false);runtime::Step{.pc=pc+1,.remaining=0}}
    };fuel=step.remaining;pc=step.pc;}
    let roots::Row before=vec::at<roots::State>(ref stores,0).rows[0];
    let usize next=vec::at<roots::State>(ref stores,0).next;
    let usize used=vec::at<roots::State>(ref stores,0).ledger.used;
    let usize peak=vec::at<roots::State>(ref stores,0).ledger.peak;
    let views::Pool held=views::Pool{.rows=vec::at<views::Pool>(ref pools,0).rows,.closed=false};
    let frames::Token token=switch(runtime::token(ref states,0,71)){
        case .ok(v):{v}case .err(_):{assert(false);frames::Token{.frame=0,.generation=0}}
    };
    let usize sequence=vec::at<frames::State>(ref states,0).frames[0].next;
    let usize source_order=vec::at<frames::State>(ref states,0).order[0];
    // One short: no owner/descriptor/lease publication, then the same instruction
    // succeeds at the unchanged 2048+4*8 price, without setup/lease surcharges.
    fuel=2079;
    assert(!runtime::instruction_views(ref p,pc,0,ref mut states,ref mut stores,
        ref mut data,ref mut scratch,ref mut backing,ref mut rs,ref mut pools,ref mut registers,budget.values,fuel).is_ok);
    assert(vec::at<roots::State>(ref stores,0).rows[0].binding==0 &&
        vec::at<roots::State>(ref stores,0).table.slots[0].reading);
    assert(vec::at<views::Pool>(ref pools,0).rows[0].owner_binding==0);
    // Occupied destination and stale activation reject before suspending a lease.
    var usize rejected_fuel=2080;
    assert(!view_runtime::transfer(programs::layout(ref p),vec::at_mut<frames::State>(ref mut states,0),ref mut data,ref mut scratch,
        frames::Address{.frame=0,.generation=token.generation,.slot=0},frames::Address{.frame=0,.generation=token.generation,.slot=0},
        vec::at_mut<roots::State>(ref mut stores,0),ref mut backing,ref mut rs,ref mut pools,ref mut rejected_fuel).is_ok);
    assert(!view_runtime::transfer(programs::layout(ref p),vec::at_mut<frames::State>(ref mut states,0),ref mut data,ref mut scratch,
        frames::Address{.frame=0,.generation=token.generation+1,.slot=0},frames::Address{.frame=0,.generation=token.generation,.slot=3},
        vec::at_mut<roots::State>(ref mut stores,0),ref mut backing,ref mut rs,ref mut pools,ref mut rejected_fuel).is_ok);
    // Trusted native fault injection, restored only after each rejected call.
    // No production owner/descriptor is ever restored from a saved snapshot.
    var usize mode=0;while(mode<6){
        if(mode<3){let ref mut views::Pool changed=vec::at_mut<views::Pool>(ref mut pools,0);
            if(mode==0){changed.rows[0].binding=16;}
            else if(mode==1){changed.rows[0].owner_binding=3;}
            else{changed.rows[0].serial=before.serial+1;}
        }else{let ref mut roots::State changed=vec::at_mut<roots::State>(ref mut stores,0);
            if(mode==3){changed.rows[0].generation=before.generation+1;}
            else if(mode==4){changed.ledger.pending=1;}
            else{changed.closed=true;}
        }
        rejected_fuel=2080;
        assert(!view_runtime::transfer(programs::layout(ref p),vec::at_mut<frames::State>(ref mut states,0),ref mut data,ref mut scratch,
            frames::Address{.frame=0,.generation=token.generation,.slot=0},frames::Address{.frame=0,.generation=token.generation,.slot=3},
            vec::at_mut<roots::State>(ref mut stores,0),ref mut backing,ref mut rs,ref mut pools,ref mut rejected_fuel).is_ok);
        assert(vec::at<roots::State>(ref stores,0).rows[0].binding==0 &&
            vec::at<roots::State>(ref stores,0).rows[0].serial==before.serial &&
            vec::at<roots::State>(ref stores,0).rows[0].slot==before.slot &&
            vec::at<roots::State>(ref stores,0).rows[0].generation==if(mode==3){before.generation+1}else{before.generation});
        assert(vec::len<bytes::Buffer>(ref backing)==1 && vec::at<roots::State>(ref stores,0).table.slots[0].reading &&
            vec::at<frames::State>(ref states,0).frames[0].live==1);
        assert(vec::at<views::Pool>(ref pools,0).rows[0].owner_binding==if(mode==1){3}else{0});
        assert(vec::at<views::Pool>(ref pools,0).rows[0].binding==if(mode==0){16}else{0});
        assert(vec::at<views::Pool>(ref pools,0).rows[0].serial==if(mode==2){before.serial+1}else{before.serial});
        {let ref mut views::Pool restored=vec::at_mut<views::Pool>(ref mut pools,0);restored.rows[0]=held.rows[0];}
        {let ref mut roots::State restored=vec::at_mut<roots::State>(ref mut stores,0);
            restored.rows[0]=before;restored.ledger.pending=0;restored.closed=false;}
        assert(vec::at<roots::State>(ref stores,0).next==next && vec::at<roots::State>(ref stores,0).ledger.used==used &&
            vec::at<roots::State>(ref stores,0).table.slots[0].reading && vec::at<frames::State>(ref states,0).frames[0].live==1);
        assert(vec::at<views::Pool>(ref pools,0).rows[1].owner_binding==0 &&
            vec::at<frames::State>(ref states,0).frames[0].next==sequence &&
            vec::at<frames::State>(ref states,0).order[0]==source_order && vec::at<frames::State>(ref states,0).order[3]==0);
        mode+=1;
    }
    // Failed allocation at zero quota leaves the already-held source intact.
    rejected_fuel=100000;
    assert(is_quota(frames::buffer_value(programs::layout(ref p),vec::at_mut<frames::State>(ref mut states,0),ref mut data,
        frames::Address{.frame=0,.generation=token.generation,.slot=3},b"x",vec::at_mut<roots::State>(ref mut stores,0),
        ref mut backing,ref mut rs,growth::Limits{.object=0,.instance=0,.engine=0},ref mut rejected_fuel)));
    assert(vec::at<roots::State>(ref stores,0).ledger.used==used && vec::at<roots::State>(ref stores,0).table.slots[0].reading &&
        vec::at<frames::State>(ref states,0).frames[0].live==1);
    fuel=2080;
    let runtime::Step moved=switch(runtime::instruction_views(ref p,pc,0,ref mut states,ref mut stores,
        ref mut data,ref mut scratch,ref mut backing,ref mut rs,ref mut pools,ref mut registers,budget.values,fuel)){
        case .ok(v):{v}case .err(_):{assert(false);runtime::Step{.pc=pc+1,.remaining=1}}
    };assert(moved.remaining==0);
    {let ref roots::State after=vec::at<roots::State>(ref stores,0);
        assert(after.next==next && after.rows[0].serial==before.serial && after.rows[0].binding==3 &&
            after.rows[0].slot==before.slot && after.rows[0].generation==before.generation);
        assert(after.ledger.used==used && after.ledger.peak==peak && after.table.slots[0].reading);
        assert(!roots::describe(after,ref backing,ref rs,before.serial,0).is_ok);
        let ref views::Pool actual=vec::at<views::Pool>(ref pools,0);var usize i=0;
        while(i<2){assert(actual.rows[i].generation==held.rows[i].generation && actual.rows[i].binding==held.rows[i].binding &&
            actual.rows[i].serial==held.rows[i].serial && actual.rows[i].owner_binding==3 && actual.rows[i].owner_slot==held.rows[i].owner_slot &&
            actual.rows[i].owner_generation==held.rows[i].owner_generation && actual.rows[i].start==held.rows[i].start && actual.rows[i].length==1);i+=1;}
    }
    fuel=513;assert(view_runtime::instruction(111,4,1,1,0,token,programs::layout(ref p),vec::at<frames::State>(ref states,0),
        ref data,ref mut pools,vec::at_mut<roots::State>(ref mut stores,0),ref backing,ref rs,ref mut registers,ref mut fuel).is_ok);
    assert(registers[4]==42 && fuel==0);
    assert(switch(runtime::finish_views(ref mut states,ref mut stores,ref mut data,ref mut scratch,ref mut backing,
        ref mut rs,ref mut pools,.err(errors::make(8,71)))){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==71}});
    let ref roots::State drained=vec::at<roots::State>(ref stores,0);
    assert(drained.closed && drained.external==0 && drained.ledger.used==0 && drained.ledger.engine_used==0);
    assert(vec::at<frames::State>(ref states,0).closed && vec::at<frames::State>(ref states,0).depth==0);
    assert(vec::len<bytes::Buffer>(ref data)==0 && vec::len<bytes::Buffer>(ref scratch)==0 &&
        vec::len<bytes::Buffer>(ref backing)==0 && vec::len<bytes::Buffer>(ref rs)==0);
}

@test fn void occupied_recreation_drop_and_stale_sources_reject_independently(){
    var values::Program occupied=fixture();let usize move=find(ref occupied,88);occupied.body.code[move*8+1]=0;
    assert(!verifier::inspect_values(ref occupied).is_ok);
    var values::Program dropped=fixture();let usize pc=find(ref dropped,88);
    dropped.body.code[pc*8]=90;dropped.body.code[pc*8+1]=0;dropped.body.code[pc*8+2]=0;
    assert(!verifier::inspect_values(ref dropped).is_ok);
    var values::Program impossible=fixture();let usize opened=find(ref impossible,105);impossible.body.code[opened*8+2]=3;
    assert(!verifier::inspect_values(ref impossible).is_ok);
    var values::Program stale=fixture();let usize target=find(ref stale,88);stale.body.code[target*8+2]=3;
    assert(!verifier::inspect_values(ref stale).is_ok);
}

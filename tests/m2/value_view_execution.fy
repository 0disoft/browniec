module tests::m2::value_view_execution;
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

// Independent bytecode fixtures: do not derive opcodes or expected bytes from
// the production view verifier/VM. Scalar registers and view IDs are separate.
fn usize ok(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn properties::Node node(u8 k,u8 a,u8 b){return properties::Node{.kind=k,.first=a,.second=b,.extent=0};}
fn u8 byte(usize v){assert(v<256);var usize i=0;var u8 b=0;while(i<v){i+=1;b+=1;}return b;}
fn usize emit(ref mut values::Program u,u8 op,usize d,usize a,usize b){return ok(ir::raw(ref mut u.body,op,d,a,b,71));}
fn usize scalar(ref mut values::Program u,u8 op,u8 tag,usize a,usize b){
    let usize d=u.body.registers;u.body.registers+=1;u.body.types[d]=tag;
    let usize pc=emit(u,op,d,a,b);return d;
}
fn usize window(ref mut values::Program u,u8 op,usize d,usize a,usize lo,usize hi){
    let usize pc=emit(u,op,d,a,lo);u.body.code[pc*8+4]=byte(hi);return pc;
}
fn void patch(ref mut values::Program u,usize pc,usize target){let usize p=ok(ir::patch(ref mut u.body,pc,target,71));}
fn void drop(ref mut values::Program u,usize id){let usize pc=emit(u,90,id,0,0);}
fn void close(ref mut values::Program u,usize id){let usize pc=emit(u,109,id,0,0);}
fn void check(ref mut values::Program u,usize actual,usize expected){
    let usize equal=ok(ir::emit(ref mut u.body,11,actual,expected,71));
    let usize target=u.body.count+2;let usize branch=emit(u,21,0,equal,target);let usize failed=emit(u,25,0,0,0);
}
fn void finish(ref mut values::Program u){
    let usize end=u.body.count;let usize registers=u.body.registers;
    u.body.function_count=1;u.body.ends[0]=end;
    u.body.register_ends[0]=registers;u.body.return_types[0]=1;
}
fn void done(ref mut values::Program u){drop(u,0);drop(u,1);let usize pc=emit(u,8,0,0,0);finish(u);}
fn void runs(ref values::Program u){
    assert(verifier::inspect_values(u).is_ok);
    assert(switch(vm::run_values(u,4000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void rejected(ref values::Program u){assert(!verifier::inspect_values(u).is_ok);}
fn values::Program base(){
    var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[1,1,4,1,0,5,0,0,0,0,0,0,0,0,0,0],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    u.catalog.count=5;u.catalog.nodes[0]=node(4,0,0);u.catalog.nodes[1]=node(1,12,0);
    u.catalog.nodes[2]=node(1,10,0);u.catalog.nodes[3]=node(6,1,2);u.catalog.nodes[4]=node(5,0,0);
    // r0=answer, r1..5=usize 0..4, r6=41u8, r7=42u8, r8=false.
    let usize answer=ok(ir::literal(ref mut u.body,42,71));
    let usize zero=ok(ir::integer(ref mut u.body,0,12,71));let usize one=ok(ir::integer(ref mut u.body,1,12,71));
    let usize two=ok(ir::integer(ref mut u.body,2,12,71));let usize three=ok(ir::integer(ref mut u.body,3,12,71));
    let usize four=ok(ir::integer(ref mut u.body,4,12,71));
    let usize a=ok(ir::integer(ref mut u.body,41,10,71));let usize b=ok(ir::integer(ref mut u.body,42,10,71));
    let usize condition=ok(ir::boolean(ref mut u.body,false,71));assert(u.body.registers==9);
    let usize root=emit(ref mut u,95,0,0,0);let usize other=emit(ref mut u,95,1,0,0);
    let usize p=emit(ref mut u,102,2,0,6);drop(ref mut u,2);
    let usize q=emit(ref mut u,102,2,0,7);drop(ref mut u,2);
    let usize r=emit(ref mut u,102,2,0,6);drop(ref mut u,2);return u;
}
fn values::Program complete(){
    var values::Program u=base();let usize begin=window(ref mut u,105,0,0,2,4); // [42,41]
    let usize child=window(ref mut u,106,1,0,1,2); // [42]
    let usize alias=emit(ref mut u,107,2,1,0);let usize moved=emit(ref mut u,108,15,2,0);
    close(ref mut u,0);close(ref mut u,1);
    let usize length=scalar(ref mut u,110,12,15,0);check(ref mut u,length,2);
    let usize read=scalar(ref mut u,111,10,15,1);check(ref mut u,read,7);
    let usize empty=window(ref mut u,106,0,15,2,2);let usize empty_len=scalar(ref mut u,110,12,0,0);
    check(ref mut u,empty_len,1);close(ref mut u,15);close(ref mut u,0);
    // Last close releases the pin; a real mutation and read must work again.
    let usize write=emit(ref mut u,101,0,2,6);let usize changed=scalar(ref mut u,100,10,0,2);
    check(ref mut u,changed,6);done(ref mut u);return u;
}
@test fn void real_bytes_nested_ranges_aliases_move_and_empty_windows_outlive_parent_close(){
    let values::Program u=complete();runs(ref u);
}

fn values::Program pinned(u8 op){
    var values::Program u=base();let usize begin=window(ref mut u,105,0,0,1,4);
    let usize alias=emit(ref mut u,107,1,0,0);close(ref mut u,0);
    if(op==88){let usize p=emit(ref mut u,88,3,0,0);drop(ref mut u,3);}
    else if(op==90){drop(ref mut u,0);}
    else if(op==91){let usize p=emit(ref mut u,91,5,0,1);drop(ref mut u,5);}
    else if(op==101){let usize p=emit(ref mut u,101,0,1,7);}
    else{let usize p=emit(ref mut u,op,2,0,if(op==102){7}else if(op==103){5}else{1});drop(ref mut u,2);}
    close(ref mut u,1);
    if(op==88 || op==90 || op==91){drop(ref mut u,1);let usize ret=emit(ref mut u,8,0,0,0);finish(ref mut u);}
    else{done(ref mut u);}return u;
}
@test fn void aliases_keep_root_pinned_against_mutation_move_drop_and_tag_consumption(){
    var u8 op=101;while(op<=104){let values::Program u=pinned(op);rejected(ref u);op+=1;}
    let values::Program moved=pinned(88);rejected(ref moved);let values::Program dropped=pinned(90);rejected(ref dropped);
    let values::Program tagged=pinned(91);rejected(ref tagged);
    var values::Program safe=base();let usize begin=window(ref mut safe,105,0,0,1,4);
    let usize read=scalar(ref mut safe,100,10,0,2);check(ref mut safe,read,7);
    // The pinned root can be an append source; a different root can mutate.
    let usize appended=emit(ref mut safe,104,2,1,0);drop(ref mut safe,2);
    let usize write=emit(ref mut safe,101,1,1,7);
    let usize still=scalar(ref mut safe,111,10,0,1);check(ref mut safe,still,6);
    let usize copied=scalar(ref mut safe,100,10,1,2);check(ref mut safe,copied,7);
    close(ref mut safe,0);done(ref mut safe);runs(ref safe);
}

fn values::Program called(bool pin_actual){
    var values::Program u=base();u.types[4]=1;u.functions[4]=1;
    let usize begin=window(ref mut u,105,0,0,1,4);
    let usize call=emit(ref mut u,93,if(pin_actual){0}else{1},1,0);
    let usize length=scalar(ref mut u,110,12,0,0);check(ref mut u,length,4);close(ref mut u,0);done(ref mut u);
    let usize start=u.body.count;let usize reg=u.body.registers;u.body.registers+=1;
    let usize zero=ok(ir::integer(ref mut u.body,0,12,71));
    // Caller view0 remains live while callee view0 selects its own empty root.
    let usize local=window(ref mut u,105,0,4,zero,zero);close(ref mut u,0);
    let usize returned=emit(ref mut u,94,0,4,0);u.body.function_count=2;
    let usize end=u.body.count;let usize registers=u.body.registers;
    u.body.starts[1]=start;u.body.ends[1]=end;u.body.register_starts[1]=reg;u.body.register_ends[1]=registers;
    u.body.arities[1]=1;u.parameters[reg]=5;u.results[1]=5;
    u.body.call_count=1;u.body.call_arities[0]=1;u.body.call_args[0]=if(pin_actual){208}else{209};return u;
}
@test fn void owning_call_rejects_pinned_actual_but_preserves_unrelated_caller_view(){
    let values::Program bad=called(true);rejected(ref bad);let values::Program good=called(false);runs(ref good);
}

fn usize find(ref values::Program u,u8 op){
    var usize pc=0;while(pc<u.body.count){if(u.body.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;
}
fn void corrupt(ref mut values::Program u,u8 op,usize field,u8 value){
    let usize pc=find(u,op);u.body.code[pc*8+field]=value;
}
@test fn void malformed_operands_undefined_scalars_and_stale_or_overwritten_views_are_rejected(){
    var values::Program u=complete();corrupt(ref mut u,105,1,16);rejected(ref u);
    u=complete();corrupt(ref mut u,106,2,16);rejected(ref u);
    u=complete();corrupt(ref mut u,107,3,1);rejected(ref u);
    u=complete();corrupt(ref mut u,108,1,0);rejected(ref u); // occupied view destination
    u=complete();corrupt(ref mut u,109,2,1);rejected(ref u);
    u=complete();corrupt(ref mut u,110,3,1);rejected(ref u);
    u=complete();let usize read=find(ref u,111);let usize output=u.body.code[read*8+1] as usize;
    u.body.types[output]=12;rejected(ref u);
    u=complete();corrupt(ref mut u,105,5,1);rejected(ref u);
    u=complete();corrupt(ref mut u,105,4,7);rejected(ref u); // u8 high bound
    u=complete();corrupt(ref mut u,111,2,2);rejected(ref u); // moved source
    u=complete();corrupt(ref mut u,109,1,2);rejected(ref u); // close moved source
    u=complete();corrupt(ref mut u,106,1,0);rejected(ref u); // overwrite parent
    u=complete();let usize missing=u.body.registers;u.body.registers+=1;u.body.register_ends[0]+=1;u.body.types[missing]=12;
    corrupt(ref mut u,111,3,byte(missing));rejected(ref u);
    u=complete();let usize absent=u.body.registers;u.body.registers+=1;u.body.register_ends[0]+=1;u.body.types[absent]=12;
    corrupt(ref mut u,105,3,byte(absent));rejected(ref u);
    // A normal return cannot rely on invocation cleanup to close its views.
    u=base();let usize begin=window(ref mut u,105,0,0,1,4);let usize ret=emit(ref mut u,8,0,0,0);finish(ref mut u);rejected(ref u);
    u=base();let usize open=window(ref mut u,105,0,0,1,4);close(ref mut u,0);
    let usize stale=scalar(ref mut u,110,12,0,0);done(ref mut u);rejected(ref u);
}

fn values::Program joined(bool mismatch,bool condition){
    var values::Program u=base();let usize cond=ok(ir::boolean(ref mut u.body,condition,71));
    let usize fork=emit(ref mut u,20,0,cond,0);let usize left=window(ref mut u,105,0,0,1,4);
    let usize jump=emit(ref mut u,19,0,0,0);let usize right=u.body.count;patch(ref mut u,fork,right);
    // Same live view IDs but distinct roots must fail; distinct windows on the
    // same root are allowed. Both branch windows have length one or three.
    let usize other=window(ref mut u,105,0,if(mismatch){1}else{0},1,if(mismatch){1}else{2});
    let usize join=u.body.count;patch(ref mut u,jump,join);
    let usize length=scalar(ref mut u,110,12,0,0);check(ref mut u,length,if(condition){4}else{2});
    close(ref mut u,0);done(ref mut u);return u;
}
fn values::Program looped(bool mismatch){
    var values::Program u=base();let usize counter=ok(ir::slot(ref mut u.body,12,71));
    let usize init=emit(ref mut u,18,counter,1,0);let usize begin=window(ref mut u,105,0,0,1,4);
    let usize head=u.body.count;let usize count=scalar(ref mut u,17,12,counter,0);
    let usize again=ok(ir::emit(ref mut u.body,13,count,4,71));let usize exit=emit(ref mut u,20,0,again,0);
    close(ref mut u,0);let usize reopened=window(ref mut u,105,0,if(mismatch){1}else{0},1,if(mismatch){1}else{4});
    let usize next=ok(ir::emit(ref mut u.body,2,count,2,71));let usize store=emit(ref mut u,18,counter,next,0);
    let usize back=emit(ref mut u,22,0,head,0);let usize end=u.body.count;patch(ref mut u,exit,end);
    let usize read=scalar(ref mut u,111,10,0,2);check(ref mut u,read,7);close(ref mut u,0);done(ref mut u);return u;
}
@test fn void cfg_joins_and_loop_backedges_require_root_origins_but_allow_same_root_windows(){
    let values::Program left=joined(false,true);runs(ref left);let values::Program right=joined(false,false);runs(ref right);
    let values::Program wrong_join=joined(true,false);rejected(ref wrong_join);
    let values::Program loop=looped(false);runs(ref loop);let values::Program wrong_loop=looped(true);rejected(ref wrong_loop);
}

fn void fails(ref values::Program u,usize fuel,u8 kind){
    assert(verifier::inspect_values(u).is_ok);
    assert(switch(vm::run_values(u,fuel,0,limits())){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==71}});
}
fn values::Program bounds(u8 mode){
    var values::Program u=base();let usize begin=window(ref mut u,105,0,0,if(mode==0){4}else{1},if(mode==0){3}else if(mode==1){5}else{4});
    if(mode==2 || mode==3){let usize child=window(ref mut u,106,1,0,if(mode==2){3}else{1},if(mode==2){2}else{5});close(ref mut u,1);}
    else if(mode==4){let usize read=scalar(ref mut u,111,10,0,4);}
    else if(mode==5){let usize empty=window(ref mut u,106,1,0,4,4);let usize read=scalar(ref mut u,111,10,1,1);close(ref mut u,1);}
    close(ref mut u,0);done(ref mut u);return u;
}
@test fn void runtime_bounds_and_fuel_failures_with_live_views_allow_fresh_success(){
    var u8 mode=0;while(mode<6){let values::Program bad=bounds(mode);fails(ref bad,4000000,14);mode+=1;}
    let values::Program good=complete();var usize low=0;var usize high=4000000;
    while(low+1<high){let usize middle=low+(high-low)/2;
        if(vm::run_values(ref good,middle,0,limits()).is_ok){high=middle;}else{low=middle;}}
    fails(ref good,high-1,8);runs(ref good);
    // Exhaust at VIEW_READ while aliases are still live. A terminal
    // failure (25) is also allowed to leave them for prepaid cleanup.
    var values::Program trapped=base();let usize begin=window(ref mut trapped,105,0,0,1,4);
    let usize alias=emit(ref mut trapped,107,1,0,0);let usize trap=emit(ref mut trapped,25,0,0,0);finish(ref mut trapped);
    fails(ref trapped,4000000,5);runs(ref good);
    var values::Program reading=base();let usize opened=window(ref mut reading,105,0,0,1,4);
    let usize copied=emit(ref mut reading,107,1,0,0);let usize read_pc=reading.body.count;
    let usize read=scalar(ref mut reading,111,10,1,1);close(ref mut reading,0);close(ref mut reading,1);done(ref mut reading);
    // Use a matched prefix ending in trap25 to locate the live-view boundary,
    // without consulting the production Fuel schedule.
    var values::Program prefix=reading;prefix.body.count=read_pc+1;prefix.body.ends[0]=read_pc+1;
    // The truncated READ no longer defines its final scalar destination.
    // Keep the prefix's declared register range exact, just like emitted IR.
    prefix.body.registers=read;prefix.body.register_ends[0]=read;prefix.body.types[read]=0;
    prefix.body.code[read_pc*8]=25;prefix.body.code[read_pc*8+1]=0;prefix.body.code[read_pc*8+2]=0;prefix.body.code[read_pc*8+3]=0;
    assert(verifier::inspect_values(ref prefix).is_ok);
    low=0;high=4000000;while(low+1<high){let usize middle=low+(high-low)/2;
        let bool reached=switch(vm::run_values(ref prefix,middle,0,limits())){case .ok(_):{false}case .err(e):{e.kind==5}};
        if(reached){high=middle;}else{low=middle;}}
    fails(ref reading,high-1,8);runs(ref reading);runs(ref good);
}

fn programs::Program retained(ref values::Program u){
    return switch(programs::retain(u)){case .ok(v):{v}case .err(_):{assert(false);retained(u)}};
}
@test fn void zero_fuel_driver_cleanup_releases_live_read_leases_metadata_and_all_backing(){
    let values::Program u=complete();let programs::Program p=retained(ref u);
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
    var i64[128] registers=[0;128];registers[4]=3;registers[6]=41;registers[7]=42;
    // Execute the actual Buffer construction/push/drop prefix through the
    // coordinator, then open a view and alias through the view adapter.
    var usize pc=find(ref u,95);let usize until=find(ref u,105);
    while(pc<until){
        let runtime::Step step=switch(runtime::instruction_views(ref p,pc,0,ref mut states,ref mut stores,
            ref mut data,ref mut scratch,ref mut backing,ref mut rs,ref mut pools,ref mut registers,budget.values,fuel)){
            case .ok(v):{v}case .err(_):{assert(false);runtime::Step{.pc=pc+1,.remaining=0}}
        };fuel=step.remaining;pc=step.pc;
    }
    let frames::Token token=switch(runtime::token(ref states,0,71)){
        case .ok(v):{v}case .err(_):{assert(false);frames::Token{.frame=0,.generation=0}}
    };
    assert(view_runtime::instruction(105,0,0,1,4,token,programs::layout(ref p),vec::at<frames::State>(ref states,0),
        ref data,ref mut pools,vec::at_mut<roots::State>(ref mut stores,0),ref backing,ref rs,ref mut registers,ref mut fuel).is_ok);
    assert(view_runtime::instruction(107,1,0,0,0,token,programs::layout(ref p),vec::at<frames::State>(ref states,0),
        ref data,ref mut pools,vec::at_mut<roots::State>(ref mut stores,0),ref backing,ref rs,ref mut registers,ref mut fuel).is_ok);
    let views::Snapshot held=views::snapshot(vec::at<views::Pool>(ref pools,0));
    assert(held.live==2 && held.roots==1 && !held.closed);
    assert(vec::at<roots::State>(ref stores,0).external==4096 && vec::at<roots::State>(ref stores,0).table.slots[0].reading);
    fuel=0;
    assert(switch(view_runtime::instruction(111,9,1,1,0,token,programs::layout(ref p),vec::at<frames::State>(ref states,0),
        ref data,ref mut pools,vec::at_mut<roots::State>(ref mut stores,0),ref backing,ref rs,ref mut registers,ref mut fuel)){
        case .ok(_):{false}case .err(e):{switch(e){case .Fuel:{true}case .State:{false}case .Type:{false}case .Bounds:{false}
            case .Quota:{false}case .Allocation:{false}case .Value:{false}case .Owner:{false}}}
    });assert(fuel==0);
    // This is the same cleanup boundary called by the actual driver. No guest
    // CLOSE/DROP, additional Fuel or independent shutdown substitutes for it.
    assert(switch(runtime::finish_views(ref mut states,ref mut stores,ref mut data,ref mut scratch,ref mut backing,
        ref mut rs,ref mut pools,.err(errors::make(8,71)))){
        case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==71}
    });
    let ref roots::State store=vec::at<roots::State>(ref stores,0);
    let views::Snapshot cleared=views::snapshot(vec::at<views::Pool>(ref pools,0));
    assert(fuel==0 && cleared.closed && cleared.live==0 && cleared.roots==0);
    assert(store.closed && store.external==0 && store.ledger.used==0 && store.ledger.engine_used==0);
    var usize i=0;while(i<16){assert(!store.table.slots[i].reading);i+=1;}
    assert(vec::at<frames::State>(ref states,0).closed && vec::at<frames::State>(ref states,0).depth==0);
    assert(vec::len<bytes::Buffer>(ref data)==0 && vec::len<bytes::Buffer>(ref scratch)==0 &&
        vec::len<bytes::Buffer>(ref backing)==0 && vec::len<bytes::Buffer>(ref rs)==0);
}

@test fn void legacy_admission_independently_rejects_every_private_view_opcode(){
    var u8 op=105;while(op<=111){
        var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
            .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
        let usize answer=ok(ir::literal(ref mut u.body,42,71));let usize pc=emit(ref mut u,op,0,0,0);
        let usize ret=emit(ref mut u,8,0,0,0);finish(ref mut u);
        assert(!verifier::inspect(ref u.body).is_ok);
        assert(switch(vm::run(ref u.body,4000000)){case .ok(_):{false}case .err(e):{e.kind==5}});op+=1;
    }
}

module tests::m2::value_tag_destination;
import value_source_ops as ops;
import value_source_bindings as bindings;
import value_ir as values;
import value_properties as properties;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;

fn usize ok(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize bit(usize id){let usize one=1;return one<<id;}
fn properties::Node node(u8 k,u8 a,u8 b){return properties::Node{.kind=k,.first=a,.second=b,.extent=0};}
fn values::Program base(){
    var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    u.body.function_count=1;u.catalog.count=9;
    u.catalog.nodes[0]=node(4,0,0);u.catalog.nodes[1]=node(1,10,0);
    u.catalog.nodes[2]=node(6,0,1);u.catalog.nodes[3]=node(5,0,0);
    u.catalog.nodes[4]=node(6,1,1);u.catalog.nodes[5]=node(6,4,1);
    u.catalog.nodes[6]=node(6,2,1);
    // Equal shapes are still different exact source types.
    u.catalog.nodes[7]=node(1,10,0);u.catalog.nodes[8]=node(4,0,0);
    let usize answer=ok(ir::literal(ref mut u.body,42,0));
    let usize byte=ok(ir::integer(ref mut u.body,42,10,1));return u;
}
fn usize allocated(ref mut values::Program u,ref mut bindings::State s,usize exact_type){
    return ok(bindings::allocate(u,s,exact_type,2));
}
fn void mark(ref mut values::Program u){
    var usize i=u.body.count*8;while(i<2048){u.body.code[i]=199;i+=1;}
    i=u.body.count;while(i<256){u.body.offsets[i]=999;i+=1;}
}
fn void canonical(ref values::Program u,usize pc,usize dst,usize payload,u8 variant,usize at){
    assert(u.body.code[pc*8]==91 && u.body.code[pc*8+1] as usize==dst);
    assert(u.body.code[pc*8+2] as usize==payload && u.body.code[pc*8+3]==variant);
    assert(u.body.offsets[pc]==at);var usize i=4;
    while(i<8){assert(u.body.code[pc*8+i]==0);i+=1;}
}
fn usize checked_variant(ref mut values::Program u,ref mut bindings::State s,usize slot,u8 variant){
    let usize test=ok(ops::tag_test(u,s,slot,variant,30));
    return ok(ir::raw(ref mut u.body,20,0,test,0,31));
}

// Separate minimal programs use the same destination ID for Buffer.ok and u8.err.
fn void executes(u8 variant){
    var values::Program u=base();var bindings::State s=bindings::empty();
    let usize enabled=ok(bindings::enable_results(ref u,ref mut s,2));s.tracking=true;
    let usize destination=allocated(ref mut u,ref mut s,2);
    let usize outer=allocated(ref mut u,ref mut s,6);
    let usize none=allocated(ref mut u,ref mut s,3);
    let usize copied=allocated(ref mut u,ref mut s,4);
    let usize copy_outer=allocated(ref mut u,ref mut s,5);
    let usize scalar=ok(ops::scalar_value(ref mut u,ref mut s,1,1,3));
    let usize buffer=ok(ops::empty_buffer(ref mut u,ref mut s,0,4));
    let usize unrelated=ok(ops::empty_buffer(ref mut u,ref mut s,0,5));
    while(s.next<16){let usize dead=allocated(ref mut u,ref mut s,0);}
    s.reads=bit(unrelated);let usize pc=u.body.count;let usize registers=u.body.registers;
    mark(ref mut u);let usize payload=if(variant==1){buffer}else{scalar};
    assert(ok(ops::tag_into(ref mut u,ref mut s,destination,payload,variant,20))==destination);
    canonical(ref u,pc,destination,payload,variant,20);
    // Prove the emitter touched one row, then clear sentinels before using
    // ir::raw, which intentionally does not clear reserved instruction bytes.
    var usize tail=(pc+1)*8;while(tail<2048){assert(u.body.code[tail]==199);u.body.code[tail]=0;tail+=1;}
    assert(destination==0 && s.next==16 && u.body.registers==registers && u.body.count==pc+1);
    assert(s.pending==bit(destination) && s.generated==bit(destination) && s.kills==bit(destination));
    assert((s.live&bit(scalar))!=0 && (s.live&bit(buffer))==if(variant==1){0}else{bit(buffer)});
    assert(s.reads==bit(unrelated) && s.writes==0);
    let usize branch=checked_variant(ref mut u,ref mut s,destination,variant);
    // Whole move-only Result moves even when its Buffer alternative is inactive.
    let usize nested=ok(ops::tag_into(ref mut u,ref mut s,outer,destination,1,21));
    assert((s.live&bit(destination))==0 && s.pending==bit(outer));
    let usize plain=ok(ops::tag_into(ref mut u,ref mut s,copied,scalar,1,22));
    assert(s.pending==(bit(outer)|bit(copied)));
    let usize wrapped=ok(ops::tag_into(ref mut u,ref mut s,copy_outer,copied,1,23));
    assert((s.live&bit(copied))!=0 && s.pending==(bit(outer)|bit(copy_outer)));
    assert(s.generated==s.pending && s.kills==(bit(destination)|bit(outer)|bit(copied)|bit(copy_outer)) && s.required==0);
    let usize none_pc=u.body.count;
    let usize absent=ok(ops::tag_into(ref mut u,ref mut s,none,16,0,24));
    canonical(ref u,none_pc,none,0,0,24);
    let usize outer_branch=checked_variant(ref mut u,ref mut s,outer,1);
    let usize copy_branch=checked_variant(ref mut u,ref mut s,copy_outer,1);
    let usize none_branch=checked_variant(ref mut u,ref mut s,none,0);
    assert(s.pending==0 && s.generated==0 && s.reads==bit(unrelated));s.reads=0;
    var usize i=0;while(i<s.next){let usize dropped=ok(bindings::drop(ref mut u,ref mut s,i,40));i+=1;}
    assert(s.live==0 && s.pending==0 && s.next==16);
    let usize returned=ok(ir::raw(ref mut u.body,8,0,0,0,41));
    // Every guard has a different live set. Even failure blocks keep distinct
    // incoming states under the independent exact initialized/Dead CFG proof.
    let usize failure=u.body.count;let usize failed=ok(ir::raw(ref mut u.body,25,0,0,0,42));
    let usize outer_failure=u.body.count;let usize failed_outer=ok(ir::raw(ref mut u.body,25,0,0,0,42));
    let usize copy_failure=u.body.count;let usize failed_copy=ok(ir::raw(ref mut u.body,25,0,0,0,42));
    let usize none_failure=u.body.count;let usize failed_none=ok(ir::raw(ref mut u.body,25,0,0,0,42));
    let usize patched=ok(ir::patch(ref mut u.body,branch,failure,43));
    let usize outer_patch=ok(ir::patch(ref mut u.body,outer_branch,outer_failure,43));
    let usize copy_patch=ok(ir::patch(ref mut u.body,copy_branch,copy_failure,43));
    let usize none_patch=ok(ir::patch(ref mut u.body,none_branch,none_failure,43));
    let usize count=u.body.count;let usize end=u.body.registers;
    u.body.ends[0]=count;u.body.register_ends[0]=end;u.body.return_types[0]=1;
    assert(verifier::inspect_values(ref u).is_ok);
    let growth::Limits quota=growth::Limits{.object=4096,.instance=1048576,.engine=1048576};
    assert(switch(vm::run_values(ref u,4000000,0,quota)){case .ok(v):{v==42}case .err(_):{false}});
}
@test fn void preallocated_result_destinations_execute_buffer_success_and_u8_error_without_new_slots(){
    executes(1);executes(0);
}

fn void rejects_unchanged(ref mut values::Program u,ref mut bindings::State s,
    usize destination,usize payload,u8 variant,u8 kind){
    let bindings::Snapshot before=bindings::snapshot(s);
    let u8[2048] code=u.body.code;let usize[256] offsets=u.body.offsets;
    let u8[16] types=u.types;let u8[16] functions=u.functions;
    let usize count=u.body.count;let usize registers=u.body.registers;
    assert(switch(ops::tag_into(u,s,destination,payload,variant,77)){
        case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==77}
    });
    let ref bindings::State prior=ref before.state;
    assert(s.next==prior.next && s.live==prior.live && s.pending==prior.pending);
    assert(s.reads==prior.reads && s.writes==prior.writes && s.enforce_results==prior.enforce_results);
    assert(s.tracking==prior.tracking && s.kills==prior.kills && s.generated==prior.generated && s.required==prior.required);
    assert(s.names.count==prior.names.count && s.names.function==prior.names.function && s.names.pending_places==prior.names.pending_places);
    var usize i=0;while(i<64){
        assert(s.bindings[i]==prior.bindings[i] && s.names.begins[i]==prior.names.begins[i]);
        assert(s.names.ends[i]==prior.names.ends[i] && s.names.registers[i]==prior.names.registers[i]);
        assert(s.names.mutable[i]==prior.names.mutable[i]);i+=1;
    }
    assert(u.body.count==count && u.body.registers==registers);
    i=0;while(i<2048){assert(u.body.code[i]==code[i]);i+=1;}
    i=0;while(i<256){assert(u.body.offsets[i]==offsets[i]);i+=1;}
    i=0;while(i<16){assert(u.types[i]==types[i] && u.functions[i]==functions[i]);i+=1;}
}
@test fn void rejected_destinations_children_variants_loans_and_capacity_preserve_state_and_all_bytes(){
    var values::Program u=base();var bindings::State s=bindings::empty();
    let usize enabled=ok(bindings::enable_results(ref u,ref mut s,2));s.tracking=true;
    let usize buffer=ok(ops::empty_buffer(ref mut u,ref mut s,0,3));
    let usize scalar=ok(ops::scalar_value(ref mut u,ref mut s,1,1,4));
    let usize destination=allocated(ref mut u,ref mut s,2);
    let usize option=allocated(ref mut u,ref mut s,3);
    let usize plain=allocated(ref mut u,ref mut s,1);
    let usize inner=ok(ops::tag(ref mut u,ref mut s,4,scalar,1,5));
    let usize outer=allocated(ref mut u,ref mut s,5);
    let usize duplicate_buffer=allocated(ref mut u,ref mut s,8);
    let usize duplicate_scalar=allocated(ref mut u,ref mut s,7);
    let usize live_buffer=ok(bindings::initialize(ref u,ref mut s,duplicate_buffer,6));
    let usize live_scalar=ok(bindings::initialize(ref u,ref mut s,duplicate_scalar,6));
    let usize name=ok(bindings::declare_mut(ref u,ref mut s,b"x",0,1,buffer,0));
    mark(ref mut u);
    rejects_unchanged(ref mut u,ref mut s,inner,scalar,1,3); // Already live Result, still pending.
    rejects_unchanged(ref mut u,ref mut s,plain,scalar,1,3); // Non-wrapper destination.
    rejects_unchanged(ref mut u,ref mut s,16,buffer,1,3);
    rejects_unchanged(ref mut u,ref mut s,9,buffer,1,3); // Not allocated.
    rejects_unchanged(ref mut u,ref mut s,destination,16,1,3);
    rejects_unchanged(ref mut u,ref mut s,destination,16,0,3);
    rejects_unchanged(ref mut u,ref mut s,destination,9,1,3); // Missing child slot.
    rejects_unchanged(ref mut u,ref mut s,destination,plain,0,3); // Dead child.
    rejects_unchanged(ref mut u,ref mut s,destination,destination,1,3);
    rejects_unchanged(ref mut u,ref mut s,destination,scalar,1,3);
    rejects_unchanged(ref mut u,ref mut s,destination,buffer,0,3);
    rejects_unchanged(ref mut u,ref mut s,destination,duplicate_buffer,1,3);
    rejects_unchanged(ref mut u,ref mut s,destination,duplicate_scalar,0,3);
    rejects_unchanged(ref mut u,ref mut s,destination,buffer,2,3);
    rejects_unchanged(ref mut u,ref mut s,option,buffer,0,3);
    rejects_unchanged(ref mut u,ref mut s,option,16,1,3);
    u.body.function_count=2;u.functions[destination]=1;
    rejects_unchanged(ref mut u,ref mut s,destination,buffer,1,3);u.functions[destination]=0;
    u.functions[buffer]=1;rejects_unchanged(ref mut u,ref mut s,destination,buffer,1,3);
    u.functions[buffer]=0;u.body.function_count=1;
    s.reads=bit(buffer);rejects_unchanged(ref mut u,ref mut s,destination,buffer,1,3);s.reads=0;
    s.writes=bit(buffer);rejects_unchanged(ref mut u,ref mut s,destination,buffer,1,3);s.writes=0;
    s.reads=bit(buffer);s.writes=bit(buffer);
    rejects_unchanged(ref mut u,ref mut s,destination,buffer,1,3);s.reads=0;s.writes=0;
    s.reads=bit(destination);rejects_unchanged(ref mut u,ref mut s,destination,buffer,1,3);s.reads=0;
    s.pending|=bit(destination);rejects_unchanged(ref mut u,ref mut s,outer,inner,1,3);s.pending=bit(inner);
    let usize count=u.body.count;u.body.count=256;
    rejects_unchanged(ref mut u,ref mut s,destination,buffer,1,4);
    rejects_unchanged(ref mut u,ref mut s,outer,inner,1,4); // Must not acknowledge child on failure.
    u.body.count=257;rejects_unchanged(ref mut u,ref mut s,outer,inner,1,4);u.body.count=count;
    while(s.next<16){let usize dead=allocated(ref mut u,ref mut s,0);}
    // Last instruction and no free typed slots: exactly one canonical row wins.
    u.body.count=255;let usize registers=u.body.registers;
    assert(ok(ops::tag_into(ref mut u,ref mut s,outer,inner,1,78))==outer);
    canonical(ref u,255,outer,inner,1,78);
    assert(u.body.count==256 && u.body.registers==registers && s.next==16);
    assert(s.pending==bit(outer) && s.generated==bit(outer) && (s.live&bit(inner))!=0);
    assert(s.names.count==1 && s.bindings[name]==1 && s.names.mutable[name]);
    assert(u.body.code[count*8]==199 && u.body.offsets[count]==999);
}

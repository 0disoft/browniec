module tests::m2::value_buffer_source_ops;
import value_buffer_source_ops as buffers;
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
fn void rejected(Result<usize,errors::Error> r,u8 kind){
    assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==77}});
}
fn properties::Node node(u8 k,u8 a,u8 b){return properties::Node{.kind=k,.first=a,.second=b,.extent=0};}
fn values::Program base(){
    var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    u.body.function_count=1;u.catalog.count=6;
    u.catalog.nodes[0]=node(4,0,0);u.catalog.nodes[1]=node(1,12,0);
    u.catalog.nodes[2]=node(1,10,0);u.catalog.nodes[3]=node(6,1,2);
    u.catalog.nodes[4]=node(6,2,1);u.catalog.nodes[5]=node(5,1,0);
    let usize answer=ok(ir::literal(ref mut u.body,42,70));
    let usize index=ok(ir::integer(ref mut u.body,0,12,70));
    let usize byte=ok(ir::integer(ref mut u.body,42,10,70));
    let usize capacity=ok(ir::integer(ref mut u.body,8,12,70));return u;
}
fn void same(ref values::Program u,ref bindings::State s,usize count,usize registers){
    assert(u.body.count==count && u.body.registers==registers && s.next==2 && s.live==3 && s.pending==0);
    assert(s.names.count==0 && s.reads==0 && s.writes==0 && s.kills==0 && s.generated==0 && s.required==0);
    assert(u.types[2]==0 && u.functions[2]==0 && u.body.types[registers]==0);
    assert(u.body.code[count*8]==177 && u.body.code[count*8+7]==199 && u.body.offsets[count]==999);
}
fn void mark(ref mut values::Program u){
    let usize pc=u.body.count;var usize i=0;while(i<8){u.body.code[pc*8+i]=199;i+=1;}u.body.offsets[pc]=999;
}
fn void emitted(ref values::Program u,usize pc,u8 op,usize at){
    assert(u.body.code[pc*8]==op && u.body.offsets[pc]==at);
    var usize i=4;while(i<8){assert(u.body.code[pc*8+i]==0);i+=1;}
}
@test fn void six_buffer_emitters_publish_fresh_scalars_and_pending_exact_results(){
    var values::Program u=base();var bindings::State s=bindings::empty();
    let usize enabled=ok(bindings::enable_results(ref u,ref mut s,70));
    let usize a=ok(ops::empty_buffer(ref mut u,ref mut s,0,70));
    let usize b=ok(ops::empty_buffer(ref mut u,ref mut s,0,70));
    // An unrelated root may retain an outer argument loan during lowering.
    s.reads=1;let usize pc=u.body.count;mark(ref mut u);
    let usize pushed=ok(buffers::grow(ref mut u,ref mut s,102,3,b,2,71));
    emitted(ref u,pc,102,71);assert(pushed==2 && s.pending==4 && s.live==7 && s.reads==1);
    rejected(bindings::require_handled(ref u,ref s,16,77),18);
    s.reads=0;s.tracking=true;
    let usize reserved=ok(buffers::grow(ref mut u,ref mut s,103,3,a,3,72));
    let usize appended=ok(buffers::grow(ref mut u,ref mut s,104,3,a,b,73));
    assert(reserved==3 && appended==4 && s.pending==28 && s.live==31);
    assert(s.kills==24 && s.generated==24 && u.types[2]==4 && u.types[3]==4 && u.types[4]==4);
    let usize registers=u.body.registers;mark(ref mut u);let usize scalar_pc=u.body.count;
    let usize length=ok(buffers::scalar(ref mut u,ref s,99,a,0,74));
    emitted(ref u,scalar_pc,99,74);assert(length==registers && u.body.types[length]==12 && !u.body.slots[length]);
    let usize written=ok(buffers::write(ref mut u,ref s,a,1,2,75));emitted(ref u,written,101,75);
    let usize read=ok(buffers::scalar(ref mut u,ref s,100,a,1,76));
    assert(read==registers+1 && u.body.types[read]==10 && !u.body.slots[read] && s.pending==28 && s.live==31);
    let usize read_pc=u.body.count-1;emitted(ref u,read_pc,100,76);
    var usize i=2;while(i<5){let usize handled=ok(bindings::handle(ref u,ref mut s,i,78));i+=1;}
    assert(s.pending==0 && s.generated==0);let usize handled=ok(bindings::require_handled(ref u,ref s,16,78));
    i=0;while(i<5){let usize dropped=ok(bindings::drop(ref mut u,ref mut s,i,78));i+=1;}
    let usize done=ok(ir::raw(ref mut u.body,8,0,0,0,79));
    let usize count=u.body.count;let usize end=u.body.registers;
    u.body.ends[0]=count;u.body.register_ends[0]=end;u.body.return_types[0]=1;
    assert(verifier::inspect_values(ref u).is_ok);
    let growth::Limits quota=growth::Limits{.object=4096,.instance=1048576,.engine=1048576};
    assert(switch(vm::run_values(ref u,4000000,0,quota)){case .ok(v):{v==42}case .err(_):{false}});
}

@test fn void invalid_types_formals_loans_capacity_and_self_append_preserve_publication(){
    var values::Program u=base();var bindings::State s=bindings::empty();
    let usize enabled=ok(bindings::enable_results(ref u,ref mut s,70));
    let usize a=ok(ops::empty_buffer(ref mut u,ref mut s,0,70));
    let usize b=ok(ops::empty_buffer(ref mut u,ref mut s,0,70));
    let usize count=u.body.count;let usize registers=u.body.registers;
    u.body.code[count*8]=177;u.body.code[count*8+7]=199;u.body.offsets[count]=999;
    rejected(buffers::scalar(ref mut u,ref s,98,a,0,77),3);
    rejected(buffers::scalar(ref mut u,ref s,99,a,1,77),3);
    rejected(buffers::scalar(ref mut u,ref s,100,a,2,77),3);
    rejected(buffers::write(ref mut u,ref s,a,2,2,77),3);
    rejected(buffers::write(ref mut u,ref s,a,1,1,77),3);
    rejected(buffers::grow(ref mut u,ref mut s,101,3,a,2,77),3);
    rejected(buffers::grow(ref mut u,ref mut s,102,4,a,2,77),3);
    rejected(buffers::grow(ref mut u,ref mut s,102,5,a,2,77),3);
    rejected(buffers::grow(ref mut u,ref mut s,102,64,a,2,77),3);
    rejected(buffers::grow(ref mut u,ref mut s,102,3,a,1,77),3);
    rejected(buffers::grow(ref mut u,ref mut s,103,3,a,2,77),3);
    rejected(buffers::grow(ref mut u,ref mut s,104,3,a,a,77),3);
    rejected(buffers::grow(ref mut u,ref mut s,104,3,a,16,77),3);same(ref u,ref s,count,registers);
    u.types[1]=2;rejected(buffers::scalar(ref mut u,ref s,99,b,0,77),3);u.types[1]=1;
    u.types[1]=2;s.reads=2;rejected(buffers::scalar(ref mut u,ref s,99,a,0,77),3);s.reads=0;u.types[1]=1;
    s.live=1;rejected(buffers::grow(ref mut u,ref mut s,104,3,a,b,77),3);s.live=3;
    u.body.function_count=2;u.functions[1]=1;
    rejected(buffers::scalar(ref mut u,ref s,99,b,0,77),3);u.functions[1]=0;u.body.function_count=1;
    u.body.register_starts[0]=2;rejected(buffers::scalar(ref mut u,ref s,100,a,1,77),3);u.body.register_starts[0]=0;
    u.body.slots[2]=true;rejected(buffers::write(ref mut u,ref s,a,1,2,77),3);u.body.slots[2]=false;
    u.parameters[2]=1;rejected(buffers::grow(ref mut u,ref mut s,102,3,a,2,77),3);u.parameters[2]=0;
    u.body.array_parameters[1]=1;rejected(buffers::scalar(ref mut u,ref s,100,a,1,77),3);u.body.array_parameters[1]=0;
    u.body.record_parameters[2]=1;rejected(buffers::write(ref mut u,ref s,a,1,2,77),3);u.body.record_parameters[2]=0;
    u.body.slice_parameters[3]=1;rejected(buffers::grow(ref mut u,ref mut s,103,3,a,3,77),3);u.body.slice_parameters[3]=0;
    u.body.types[registers]=12;rejected(buffers::scalar(ref mut u,ref s,99,a,0,77),3);u.body.types[registers]=0;
    u.parameters[registers]=1;rejected(buffers::scalar(ref mut u,ref s,99,a,0,77),3);u.parameters[registers]=0;
    s.reads=65536;rejected(buffers::scalar(ref mut u,ref s,99,a,0,77),3);s.reads=0;
    s.reads=1;rejected(buffers::write(ref mut u,ref s,a,1,2,77),3);
    rejected(buffers::grow(ref mut u,ref mut s,102,3,a,2,77),3);
    rejected(bindings::consume(ref u,ref mut s,a,77),3);s.reads=0;
    s.writes=1;rejected(buffers::scalar(ref mut u,ref s,99,a,0,77),3);s.writes=0;
    s.writes=2;rejected(buffers::grow(ref mut u,ref mut s,104,3,a,b,77),3);s.writes=0;
    s.writes=65536;rejected(buffers::write(ref mut u,ref s,a,1,2,77),3);s.writes=0;
    s.reads=1;s.writes=1;rejected(buffers::grow(ref mut u,ref mut s,102,3,a,2,77),3);s.reads=0;s.writes=0;
    s.reads=4;rejected(buffers::scalar(ref mut u,ref s,99,a,0,77),3);s.reads=0;
    s.writes=4;rejected(buffers::write(ref mut u,ref s,a,1,2,77),3);s.writes=0;
    u.body.registers=128;rejected(buffers::scalar(ref mut u,ref s,99,a,0,77),4);u.body.registers=registers;
    u.body.count=256;u.body.code[2047]=198;u.body.offsets[255]=998;
    rejected(buffers::scalar(ref mut u,ref s,99,a,0,77),4);
    rejected(buffers::write(ref mut u,ref s,a,1,2,77),4);
    rejected(buffers::grow(ref mut u,ref mut s,102,3,a,2,77),4);
    assert(u.body.count==256 && u.body.code[2047]==198 && u.body.offsets[255]==998);
    u.body.count=count;same(ref u,ref s,count,registers);
    while(s.next<16){let usize allocated=ok(bindings::allocate(ref mut u,ref mut s,3,70));}
    rejected(buffers::grow(ref mut u,ref mut s,102,3,a,2,77),4);
    assert(s.next==16 && s.live==3 && s.pending==0 && u.body.count==count && u.body.registers==registers);
    assert(u.body.code[count*8]==177 && u.body.code[count*8+7]==199 && u.body.offsets[count]==999);
}

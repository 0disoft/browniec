module tests::m2::value_buffer_execution;
import value_ir as values;
import value_properties as properties;
import verifier as verifier;
import vm as vm;
import ir as ir;
import errors as errors;
import buffer_growth as growth;
import value_roots as roots;
import buffer_owners as owners;
import value_buffer_runtime as buffers;
import value_runtime as runtime;
import value_program as programs;
import value_frames as frames;
import std::bytes as bytes;
import std::vec as vec;

fn usize ok(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn properties::Node node(u8 k,u8 a,u8 b){return properties::Node{.kind=k,.first=a,.second=b,.extent=0};}
fn usize emit(ref mut values::Program u,u8 op,usize d,usize a,usize b){return ok(ir::raw(ref mut u.body,op,d,a,b,71));}
fn u8 encoded(usize value){assert(value<256);var usize i=0;var u8 b=0;while(i<value){i+=1;b+=1;}return b;}
fn usize scalar(ref mut values::Program u,u8 op,u8 tag,usize a,usize b){
    let usize d=u.body.registers;u.body.registers+=1;u.body.types[d]=tag;
    let usize pc=emit(u,op,d,a,b);return d;
}
fn void check(ref mut values::Program u,usize a,usize b){
    let usize equal=ok(ir::emit(ref mut u.body,11,a,b,71));
    let usize target=u.body.count+2;let usize branch=emit(u,21,0,equal,target);let usize fail=emit(u,25,0,0,0);
}
fn void finish(ref mut values::Program u){
    let usize done=emit(u,8,0,0,0);let usize count=u.body.count;let usize registers=u.body.registers;
    u.body.function_count=1;u.body.ends[0]=count;u.body.register_ends[0]=registers;u.body.return_types[0]=1;
}
fn values::Program base(){
    var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[1,1,4,4,2,0,0,0,0,0,0,0,0,0,0,0],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    u.catalog.count=4;u.catalog.nodes[0]=node(4,0,0);u.catalog.nodes[1]=node(1,12,0);
    u.catalog.nodes[2]=node(1,10,0);u.catalog.nodes[3]=node(6,1,2);
    let usize answer=ok(ir::literal(ref mut u.body,42,71));
    let usize initial=ok(ir::integer(ref mut u.body,41,10,71));
    let usize changed=ok(ir::integer(ref mut u.body,42,10,71));
    let usize index=ok(ir::integer(ref mut u.body,0,12,71));
    let usize capacity=ok(ir::integer(ref mut u.body,8,12,71));
    let usize one=ok(ir::integer(ref mut u.body,1,12,71));return u;
}
fn void drop(ref mut values::Program u,usize slot){let usize pc=emit(u,90,slot,0,0);}
fn values::Program complete(){
    var values::Program u=base();let usize a=emit(ref mut u,95,0,0,0);let usize b=emit(ref mut u,95,1,0,0);
    let usize empty=scalar(ref mut u,99,12,0,0);check(ref mut u,empty,3);
    let usize push=emit(ref mut u,102,2,1,1);
    let usize copied=emit(ref mut u,89,3,2,0);drop(ref mut u,3);drop(ref mut u,2);
    let usize reserve=emit(ref mut u,103,2,0,4);drop(ref mut u,2);
    let usize append=emit(ref mut u,104,2,0,1);
    // CASE retains this copyable Result; release it after selecting its payload.
    let usize selected=emit(ref mut u,92,4,2,1);
    drop(ref mut u,2);
    let usize payload=scalar(ref mut u,96,12,4,0);drop(ref mut u,4);check(ref mut u,payload,5);
    let usize length=scalar(ref mut u,99,12,0,0);check(ref mut u,length,5);
    let usize write=emit(ref mut u,101,0,3,2);
    let usize read=scalar(ref mut u,100,10,0,3);check(ref mut u,read,2);
    let usize source_length=scalar(ref mut u,99,12,1,0);check(ref mut u,source_length,5);
    let usize source_read=scalar(ref mut u,100,10,1,3);check(ref mut u,source_read,1);
    drop(ref mut u,0);drop(ref mut u,1);finish(ref mut u);
    let usize mismatch=u.body.count;let usize failed=emit(ref mut u,25,0,0,0);
    u.body.code[selected*8+4]=encoded(mismatch);let usize end=u.body.count;u.body.ends[0]=end;return u;
}
fn void runs(ref values::Program u,usize fuel){
    assert(verifier::inspect_values(u).is_ok);
    assert(switch(vm::run_values(u,fuel,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
@test fn void all_six_buffer_opcodes_preserve_owners_copy_results_and_extract_usize_payload(){
    let values::Program u=complete();runs(ref u,4000000);
    assert(!verifier::inspect(ref u.body).is_ok && !vm::run(ref u.body,4000000).is_ok);
}

fn values::Program single(u8 op){
    var values::Program u=base();let usize a=emit(ref mut u,95,0,0,0);let usize b=emit(ref mut u,95,1,0,0);
    if(op==99){let usize d=scalar(ref mut u,op,12,0,0);}
    else if(op==100){let usize d=scalar(ref mut u,op,10,0,3);}
    else if(op==101){let usize pc=emit(ref mut u,op,0,3,2);}
    else{let usize pc=emit(ref mut u,op,2,0,if(op==102){2}else if(op==103){4}else{1});drop(ref mut u,2);}
    drop(ref mut u,0);drop(ref mut u,1);finish(ref mut u);return u;
}
fn void corrupt(u8 op,usize field){
    var values::Program u=single(op);let usize pc=8;let usize at=pc*8;
    if(field<4){u.body.code[at+4+field]=1;}
    else if(field==4){u.body.code[at+1]=128;}
    else if(field==5){u.body.code[at+2]=128;}
    else if(field==6){u.body.code[at+3]=128;}
    else if(field==7){u.catalog.nodes[0]=node(1,12,0);}
    else if(field==8){u.functions[0]=1;}
    else if(field==9){u.body.code[7*8]=90;u.body.code[7*8+1]=0;} // Retire Buffer before operation.
    else if(field==10 && op>=102){u.catalog.nodes[3].first=2;}
    else if(field==11 && op>=102){u.catalog.nodes[3].second=1;}
    else if(field==12 && op>=102){u.catalog.nodes[3].kind=5;}
    else if(field==13 && (op==100 || op==101 || op==102 || op==103)){
        let usize reg=if(op==100 || op==103){3}else{2};u.body.slots[reg]=true;
    }
    else if(field==14 && (op==100 || op==101 || op==102 || op==103)){
        let usize reg=if(op==100 || op==103){3}else{2};
        u.body.code[reg*8]=19;u.body.code[reg*8+1]=0;u.body.code[reg*8+2]=encoded(reg+1);u.body.code[reg*8+3]=0;
    }
    else if(field==15 && op==104){u.body.code[at+3]=0;}
    else if(field==16 && op<=100){u.body.types[6]=1;}
    else if(field==17 && op<=100){u.body.code[at+1]=if(op==99){3}else{1};}
    else{return;}
    assert(!verifier::inspect_values(ref u).is_ok);
}
@test fn void verifier_rejects_malformed_buffer_operands_reserved_bytes_scalar_and_result_shapes(){
    var u8 op=99;while(op<=104){let values::Program valid=single(op);assert(verifier::inspect_values(ref valid).is_ok);
        var usize field=0;while(field<=17){corrupt(op,field);field+=1;}op+=1;}
}

@test fn void fuel_exact_boundary_bounds_and_quota_traps_allow_fresh_owner_cleanup_retry(){
    let values::Program u=complete();var usize lo=0;var usize hi=4000000;
    // Search only this small fixture; then assert the exact success/failure boundary.
    while(lo+1<hi){let usize mid=lo+(hi-lo)/2;
        if(vm::run_values(ref u,mid,0,limits()).is_ok){hi=mid;}else{lo=mid;}}
    runs(ref u,hi);assert(switch(vm::run_values(ref u,hi-1,0,limits())){case .ok(_):{false}case .err(e):{e.kind==8}});
    let growth::Limits tiny=growth::Limits{.object=4096,.instance=1,.engine=1};
    assert(switch(vm::run_values(ref u,4000000,0,tiny)){case .ok(_):{false}case .err(e):{e.kind==13}});
    var u8 op=100;while(op<=101){let values::Program bounds=single(op);
        assert(verifier::inspect_values(ref bounds).is_ok);
        assert(switch(vm::run_values(ref bounds,4000000,0,limits())){case .ok(_):{false}case .err(e):{e.kind==14 && e.offset==71}});op+=1;}
    runs(ref u,4000000);
}

fn usize owned(Result<usize,roots::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void content(ref roots::State s,ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,
    usize serial,usize binding,ref u8[] expected){
    var u8[128] actual=[0;128];var usize fuel=1000;
    assert(owned(roots::copy_out(s,data,scratch,serial,binding,0,ref mut actual[..expected.len],ref mut fuel))==expected.len);
    assert(bytes::equal(ref actual[..expected.len],expected));
}
fn roots::State opened(ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){
    return switch(roots::open(data,scratch,limits(),fuel)){
        case .ok(v):{v}case .err(_):{assert(false);opened(data,scratch,fuel)}
    };
}
@test fn void root_append_both_vector_directions_growth_and_shared_source_preserve_rejections(){
    var usize order=0;while(order<2){
        var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
        var usize fuel=1000000;
        var roots::State s=opened(ref mut data,ref mut scratch,ref mut fuel);
        let u8[64] target_bytes=[7;64];let u8[2] source_bytes=[42,43];
        let usize first=owned(roots::insert(ref mut s,ref mut data,ref mut scratch,0,
            if(order==0){ref target_bytes[..]}else{ref source_bytes[..]},limits(),ref mut fuel));
        let usize second=owned(roots::insert(ref mut s,ref mut data,ref mut scratch,1,
            if(order==0){ref source_bytes[..]}else{ref target_bytes[..]},limits(),ref mut fuel));
        let usize neighbor=owned(roots::insert(ref mut s,ref mut data,ref mut scratch,2,b"x",limits(),ref mut fuel));
        let usize target=if(order==0){first}else{second};let usize source=if(order==0){second}else{first};
        let usize dst=order;let usize src=1-order;
        let usize used=s.ledger.used;let usize peak=s.ledger.peak;let usize generation=s.rows[dst].generation;
        let roots::Row row=s.rows[src];let owners::Token token=owners::Token{.slot=row.slot,.generation=row.generation};
        let growth::Ledger ledger=s.ledger;
        assert(owners::begin_read(ref mut s.table,token,vec::at<bytes::Buffer>(ref data,src),ref ledger).is_ok);
        fuel=2567;assert(!roots::append_from(ref mut s,ref mut data,ref mut scratch,target,dst,source,src,limits(),ref mut fuel).is_ok && fuel==2055);
        let growth::Limits transient=growth::Limits{.object=128,.instance=used+128,.engine=used+128};fuel=10000;
        assert(switch(roots::append_from(ref mut s,ref mut data,ref mut scratch,target,dst,source,src,transient,ref mut fuel)){
            case .ok(_):{false}case .err(e):{switch(e){case .Quota:{true}case .Fuel:{false}case .State:{false}
                case .Binding:{false}case .Serial:{false}case .Owners:{false}case .Allocation:{false}case .Bounds:{false}}}
        });
        assert(s.ledger.used==used && s.ledger.peak==peak && s.rows[dst].generation==generation);
        content(ref s,ref data,ref scratch,target,dst,ref target_bytes);
        fuel=2568;assert(owned(roots::append_from(ref mut s,ref mut data,ref mut scratch,target,dst,source,src,limits(),ref mut fuel))==66 && fuel==0);
        var u8[66] expected=[7;66];expected[64]=42;expected[65]=43;
        content(ref s,ref data,ref scratch,target,dst,ref expected);content(ref s,ref data,ref scratch,source,src,ref source_bytes);
        content(ref s,ref data,ref scratch,neighbor,2,b"x");assert(vec::len<bytes::Buffer>(ref scratch)==0);
        assert(s.rows[dst].generation==generation+1 && s.rows[src].generation==row.generation);
        assert(owners::end_read(ref mut s.table,token).is_ok);
        assert(owned(roots::drain(ref mut s,ref mut data,ref mut scratch))==0);order+=1;
    }
}

fn programs::Program retained(ref values::Program u){
    return switch(programs::retain(u)){case .ok(v):{v}case .err(_):{assert(false);retained(u)}};
}
@test fn void result_publication_fuel_and_destination_precede_native_buffer_mutation(){
    let values::Program u=complete();
    let programs::Program p=retained(ref u);
    let runtime::Budget budget=switch(runtime::budget(ref p,0,limits(),1000000)){
        case .ok(v):{v}case .err(_):{assert(false);runtime::Budget{.values=limits(),.initial=0}}
    };
    var vec::Vec<frames::State> states=vec::empty<frames::State>();var vec::Vec<roots::State> owners=vec::empty<roots::State>();
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> rs=vec::empty<bytes::Buffer>();
    var usize fuel=ok(runtime::setup(ref p,ref mut states,ref mut owners,ref mut data,ref mut scratch,ref mut roots,ref mut rs,budget.values,1000000));
    let frames::Token token=switch(runtime::token(ref states,0,0)){case .ok(v):{v}case .err(_):{assert(false);frames::Token{.frame=0,.generation=0}}};
    let frames::Address address=frames::Address{.frame=0,.generation=token.generation,.slot=0};
    let ref mut frames::State s=vec::at_mut<frames::State>(ref mut states,0);
    let ref mut roots::State r=vec::at_mut<roots::State>(ref mut owners,0);
    let usize serial=switch(frames::buffer_value(programs::layout(ref p),s,ref mut data,address,b"kept",r,ref mut roots,ref mut rs,budget.values,ref mut fuel)){
        case .ok(v):{v}case .err(_):{assert(false);0}
    };
    var i64[128] registers=[0;128];registers[2]=42;let usize generation=r.rows[0].generation;
    fuel=2111;assert(!buffers::instruction(102,2,0,2,token,programs::layout(ref p),s,r,ref mut data,ref mut roots,ref mut rs,ref mut registers,budget.values,ref mut fuel).is_ok);
    assert(fuel==2111 && r.rows[0].generation==generation);content(r,ref roots,ref rs,serial,0,b"kept");
    fuel=6260;assert(buffers::instruction(102,2,0,2,token,programs::layout(ref p),s,r,ref mut data,ref mut roots,ref mut rs,ref mut registers,budget.values,ref mut fuel).is_ok && fuel==0);
    content(r,ref roots,ref rs,serial,0,b"kept*");assert(r.rows[0].generation==generation+1);
    fuel=10000;let frames::Address result=frames::Address{.frame=0,.generation=token.generation,.slot=2};
    let frames::Address payload=frames::Address{.frame=0,.generation=token.generation,.slot=4};
    assert(switch(frames::case_value(programs::layout(ref p),s,ref mut data,ref mut scratch,result,1,payload,r,ref mut roots,ref mut rs,ref mut fuel)){
        case .ok(v):{v.matched && v.payload}case .err(_):{false}
    });
    assert(switch(frames::scalar_read(programs::layout(ref p),s,ref data,payload,ref mut fuel)){case .ok(v):{v==5}case .err(_):{false}});
    fuel=6260;assert(!buffers::instruction(102,2,0,2,token,programs::layout(ref p),s,r,ref mut data,ref mut roots,ref mut rs,ref mut registers,budget.values,ref mut fuel).is_ok);
    assert(fuel==4148 && r.rows[0].generation==generation+1);content(r,ref roots,ref rs,serial,0,b"kept*");
    assert(frames::abort(s,ref mut data,ref mut scratch,r,ref mut roots,ref mut rs).is_ok && r.ledger.used==0);
}

module tests::m2::value_tag_test;
import value_source_ops as ops;
import value_source_bindings as bindings;
import value_ir as values;
import value_properties as properties;
import value_frames as frames;
import value_frame_layout as layouts;
import value_frame_meter as meter;
import value_roots as owners;
import value_runtime as runtime;
import fuel as fuel;
import verifier as verifier;
import vm as vm;
import ir as ir;
import errors as errors;
import buffer_growth as growth;
import static_image as images;
import std::bytes as bytes;
import std::vec as vec;

fn usize ok(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize native(Result<usize,frames::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize measured(Result<usize,meter::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn bool matched(Result<bool,frames::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);false}};}
fn void rejected(Result<usize,errors::Error> r,u8 kind,usize at){
    assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}});
}
fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn properties::Node node(u8 kind,u8 first,u8 second){return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};}
fn values::Program base(){
    var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    u.body.function_count=1;u.catalog.count=8;
    u.catalog.nodes[0]=node(1,1,0);u.catalog.nodes[1]=node(1,2,0);u.catalog.nodes[2]=node(4,0,0);
    u.catalog.nodes[3]=node(5,0,0);u.catalog.nodes[4]=node(5,2,0);
    u.catalog.nodes[5]=node(6,0,2);u.catalog.nodes[6]=node(6,2,0);u.catalog.nodes[7]=node(5,5,0);
    return u;
}
fn usize emit(ref mut values::Program u,u8 op,usize dst,usize a,usize b,usize at){return ok(ir::raw(ref mut u.body,op,dst,a,b,at));}
fn void finish(ref mut values::Program u){
    let usize done=emit(u,8,0,0,0,54);let usize count=u.body.count;let usize registers=u.body.registers;
    u.body.ends[0]=count;u.body.register_ends[0]=registers;u.body.return_types[0]=1;
}
fn void runs(ref values::Program u,usize budget){
    assert(verifier::inspect_values(u).is_ok);
    assert(switch(vm::run_values(u,budget,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void bad_ir(ref values::Program u){assert(!verifier::inspect_values(u).is_ok);}

// Each call owns only one Program; do not materialize a stack of fixture copies.
fn void variant(usize wrapper,u8 actual,bool inner_buffer){
    var values::Program u=base();var bindings::State s=bindings::empty();
    let usize answer=ok(ir::literal(ref mut u.body,42,0));
    let usize scalar=ok(ops::scalar_value(ref mut u,ref mut s,answer,0,1));
    var usize payload=16;
    if(wrapper==3 && actual==1){payload=scalar;}
    if((wrapper==4 && actual==1) || (wrapper==5 && actual==0) || (wrapper==6 && actual==1)){
        payload=ok(ops::empty_buffer(ref mut u,ref mut s,2,2));
    }
    if((wrapper==5 && actual==1) || (wrapper==6 && actual==0)){payload=scalar;}
    if(wrapper==7 && actual==1){
        let usize child=if(inner_buffer){ok(ops::empty_buffer(ref mut u,ref mut s,2,3))}else{scalar};
        payload=ok(ops::tag(ref mut u,ref mut s,5,child,if(inner_buffer){0}else{1},4));
    }
    let usize source=ok(ops::tag(ref mut u,ref mut s,wrapper,payload,actual,5));
    let usize next=s.next;let usize live=s.live;var usize[4] branches=[0;4];var usize i=0;
    while(i<4){let u8 wanted=if(i%2==0){0}else{1};let usize pc=u.body.count;
        let usize result=ok(ops::tag_test(ref mut u,ref mut s,source,wanted,50+i));
        assert(u.body.types[result]==2 && u.body.code[pc*8]==98 && u.body.code[pc*8+2] as usize==source);
        assert(u.body.code[pc*8+3]==wanted && u.body.offsets[pc]==50+i);
        var usize reserved=4;while(reserved<8){assert(u.body.code[pc*8+reserved]==0);reserved+=1;}
        assert(s.next==next && s.live==live);
        branches[i]=emit(ref mut u,if(wanted==actual){20}else{21},0,result,0,60+i);i+=1;
    }
    i=0;while(i<s.next){let usize dropped=ok(bindings::drop(ref mut u,ref mut s,i,70));i+=1;}
    finish(ref mut u);let usize fail=u.body.count;let usize failed=emit(ref mut u,25,0,0,0,80);
    i=0;while(i<4){let usize patched=ok(ir::patch(ref mut u.body,branches[i],fail,81));i+=1;}
    let usize end=u.body.count;u.body.ends[0]=end;runs(ref u,4000000);
    assert(!verifier::inspect(ref u.body).is_ok && !verifier::verify_sites(ref u.body).is_ok);
    assert(!vm::run(ref u.body,4000000).is_ok);
    let images::Builder builder=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let images::Image image=switch(images::freeze(ref builder,images::metadata_charge())){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(!verifier::verify_statics(ref u.body,ref image).is_ok);
}
@test fn void repeated_predicates_preserve_plain_nested_and_active_inactive_buffer_wrappers_in_vm(){
    var usize wrapper=3;while(wrapper<=7){variant(wrapper,0,false);variant(wrapper,1,false);wrapper+=1;}
    variant(7,1,true);
}

fn void sentinel(ref values::Program u,ref bindings::State s,usize count,usize registers){
    assert(u.body.count==count && u.body.registers==registers && s.next==1 && s.live==1);
    assert(u.types[0]==5 && u.functions[0]==0 && s.names.count==0);
    var usize i=1;while(i<16){assert(u.types[i]==0 && u.functions[i]==0);i+=1;}
    i=0;while(i<8){assert(u.body.code[count*8+i]==177);i+=1;}
    assert(u.body.offsets[count]==999);
}
@test fn void helper_checks_exact_wrapper_live_function_and_budgets_before_any_publication(){
    var values::Program u=base();var bindings::State s=bindings::empty();
    let usize answer=ok(ir::literal(ref mut u.body,42,0));
    let usize source=ok(ops::tag(ref mut u,ref mut s,4,16,0,1));
    let usize count=u.body.count;let usize registers=u.body.registers;
    var usize i=0;while(i<8){u.body.code[count*8+i]=177;i+=1;}u.body.offsets[count]=999;
    rejected(ops::tag_test(ref mut u,ref mut s,source,2,10),3,10);
    rejected(ops::tag_test(ref mut u,ref mut s,16,0,11),3,11);
    rejected(ops::tag_test(ref mut u,ref mut s,1,0,12),3,12);
    i=1;while(i<=3){u.types[0]=if(i==1){1}else if(i==2){2}else{3};
        rejected(ops::tag_test(ref mut u,ref mut s,0,0,13),3,13);i+=1;}u.types[0]=5;
    s.live=0;rejected(ops::tag_test(ref mut u,ref mut s,0,0,14),3,14);s.live=1;
    u.body.function_count=2;u.functions[0]=1;
    rejected(ops::tag_test(ref mut u,ref mut s,0,0,15),3,15);u.functions[0]=0;u.body.function_count=1;
    u.body.registers=128;rejected(ops::tag_test(ref mut u,ref mut s,0,0,16),4,16);u.body.registers=registers;
    u.body.count=256;rejected(ops::tag_test(ref mut u,ref mut s,0,0,17),4,17);u.body.count=count;
    u.body.register_starts[0]=registers+1;
    rejected(ops::tag_test(ref mut u,ref mut s,0,0,18),3,18);u.body.register_starts[0]=0;
    u.body.types[registers]=2;rejected(ops::tag_test(ref mut u,ref mut s,0,0,19),3,19);u.body.types[registers]=0;
    u.body.slots[registers]=true;rejected(ops::tag_test(ref mut u,ref mut s,0,0,20),3,20);u.body.slots[registers]=false;
    u.parameters[registers]=1;rejected(ops::tag_test(ref mut u,ref mut s,0,0,21),3,21);u.parameters[registers]=0;
    u.body.array_parameters[registers]=1;rejected(ops::tag_test(ref mut u,ref mut s,0,0,22),3,22);u.body.array_parameters[registers]=0;
    u.body.record_parameters[registers]=1;rejected(ops::tag_test(ref mut u,ref mut s,0,0,23),3,23);u.body.record_parameters[registers]=0;
    u.body.slice_parameters[registers]=1;rejected(ops::tag_test(ref mut u,ref mut s,0,0,24),3,24);u.body.slice_parameters[registers]=0;
    sentinel(ref u,ref s,count,registers);
    while(s.next<16){let usize allocated=ok(bindings::allocate(ref mut u,ref mut s,4,25));}
    let usize result=ok(ops::tag_test(ref mut u,ref mut s,0,0,26));
    assert(result==registers && s.next==16 && s.live==1 && u.body.registers==registers+1);
    assert(u.body.code[count*8+4]==0 && u.body.code[count*8+7]==0 && u.body.offsets[count]==26);
}

fn values::Program simple(){
    var values::Program u=base();var bindings::State s=bindings::empty();
    let usize answer=ok(ir::literal(ref mut u.body,42,0));
    let usize source=ok(ops::tag(ref mut u,ref mut s,4,16,0,49));
    let usize test=ok(ops::tag_test(ref mut u,ref mut s,source,0,51));
    let usize branch=emit(ref mut u,20,0,test,6,52);
    let usize drop=ok(bindings::drop(ref mut u,ref mut s,source,53));finish(ref mut u);
    let usize failed=emit(ref mut u,25,0,0,0,55);let usize end=u.body.count;u.body.ends[0]=end;return u;
}
fn void corrupt(usize field){
    var values::Program u=simple();
    if(field<8){u.body.code[16+field]=if(field==1){128}else if(field==2){16}else{2};}
    else if(field==8){u.body.types[1]=1;}
    else if(field==9){u.body.slots[1]=true;}
    else if(field==10){u.parameters[1]=1;}
    else if(field==11){u.body.array_parameters[1]=1;}
    else if(field==12){u.body.record_parameters[1]=1;}
    else if(field==13){u.body.slice_parameters[1]=1;}
    else if(field==14){u.types[0]=1;}
    else if(field==15){u.body.code[8]=90;} // DROP of Dead before the predicate.
    else if(field==16){u.body.code[32]=98;u.body.code[33]=1;u.body.code[34]=0;} // Second definition.
    else if(field==17){u.body.registers=129;}
    else if(field==18){u.body.count=257;}
    else if(field==19){u.body.function_count=2;u.functions[0]=1;}
    else if(field==20){u.body.code[16]=90;u.body.code[17]=0;u.body.code[18]=0;u.body.code[24]=98;
        u.body.code[25]=1;u.body.code[26]=0;u.body.code[27]=0;}
    else if(field==21){u.body.code[16]=19;u.body.code[17]=0;u.body.code[18]=4;u.body.code[19]=0;
        u.body.code[24]=98;u.body.code[25]=1;u.body.code[26]=0;u.body.code[27]=2;}
    bad_ir(ref u);
}
@test fn void independent_admission_rejects_reserved_operands_nonbool_definitions_and_dead_sources(){
    let values::Program valid=simple();assert(verifier::inspect_values(ref valid).is_ok);
    var usize field=1;while(field<=21){corrupt(field);field+=1;}
}

fn frames::Address at(frames::Token t,usize slot){return frames::Address{.frame=t.frame,.generation=t.generation,.slot=slot};}
fn layouts::Plan native_plan(){
    var properties::Catalog c=properties::empty();c.count=3;
    c.nodes[0]=node(4,0,0);c.nodes[1]=node(5,0,0);c.nodes[2]=node(6,0,0);
    let u8[16] types=[1,2,3,2,0,0,0,0,0,0,0,0,0,0,0,0];
    let u8[16] functions=[0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0];
    return switch(layouts::retain(ref c,ref types,ref functions,2)){
        case .ok(v):{v}case .err(_):{assert(false);native_plan()}
    };
}
fn void native_boundary(bool active,bool result){
    let layouts::Plan p=native_plan();var usize remaining=4000000;
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> root_scratch=vec::empty<bytes::Buffer>();
    var owners::State owned=switch(owners::open(ref mut roots,ref mut root_scratch,limits(),ref mut remaining)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var frames::State state=switch(frames::open(ref p,ref mut data,ref mut scratch,ref owned,limits(),ref mut remaining)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let frames::Token t=switch(frames::enter(ref p,ref mut state,ref mut data,0,ref owned,limits(),ref mut remaining)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let usize source=if(result){2}else{1};let u8 variant=if(active){1}else{0};
    if(active || result){let usize serial=native(frames::buffer_value(ref p,ref mut state,ref mut data,at(t,0),b"keep",
        ref mut owned,ref mut roots,ref mut root_scratch,limits(),ref mut remaining));}
    let usize built=native(frames::build_tag(ref p,ref mut state,ref mut data,ref mut scratch,at(t,source),at(t,0),variant,
        ref mut owned,ref mut roots,ref mut root_scratch,ref mut remaining));
    let usize bits=state.frames[0].live;let usize sequence=state.frames[0].next;let usize order=state.order[source];
    let usize used=owned.ledger.used;let usize peak=owned.ledger.peak;let usize serial=owned.rows[0].serial;
    let usize binding=owned.rows[0].binding;let usize root_count=vec::len<bytes::Buffer>(ref roots);
    let usize offset=switch(layouts::offset(ref p,source)){case .ok(v):{v}case .err(_):{assert(false);0}};
    var u8[16] original=[0;16];var usize i=0;
    while(i<16){original[i]=bytes::view(vec::at<bytes::Buffer>(ref data,0))[offset+i];i+=1;}
    let usize price=fuel::value_tag_test(16);remaining=price-1;
    assert(!frames::tag_test(ref p,ref state,ref data,at(t,source),variant,ref owned,ref roots,ref root_scratch,ref mut remaining).is_ok);
    assert(remaining==price-1);
    remaining=price;assert(matched(frames::tag_test(ref p,ref state,ref data,at(t,source),variant,ref owned,ref roots,ref root_scratch,ref mut remaining)));
    assert(remaining==0);
    remaining=price+1;assert(!matched(frames::tag_test(ref p,ref state,ref data,at(t,source),if(variant==1){0}else{1},ref owned,ref roots,ref root_scratch,ref mut remaining)));
    assert(remaining==1);
    remaining=1000000;
    assert(!frames::tag_test(ref p,ref state,ref data,at(t,source),2,ref owned,ref roots,ref root_scratch,ref mut remaining).is_ok);
    assert(!frames::tag_test(ref p,ref state,ref data,at(t,0),0,ref owned,ref roots,ref root_scratch,ref mut remaining).is_ok);
    assert(!frames::tag_test(ref p,ref state,ref data,at(t,3),0,ref owned,ref roots,ref root_scratch,ref mut remaining).is_ok);
    let frames::Address stale=frames::Address{.frame=0,.generation=t.generation+1,.slot=source};
    assert(!frames::tag_test(ref p,ref state,ref data,stale,variant,ref owned,ref roots,ref root_scratch,ref mut remaining).is_ok);
    state.frames[0].live=0;
    assert(!frames::tag_test(ref p,ref state,ref data,at(t,source),variant,ref owned,ref roots,ref root_scratch,ref mut remaining).is_ok);
    state.frames[0].live=bits;
    if(root_count!=0){owned.rows[0].binding=999;
        assert(!frames::tag_test(ref p,ref state,ref data,at(t,source),variant,ref owned,ref roots,ref root_scratch,ref mut remaining).is_ok);
        owned.rows[0].binding=binding;
    }
    assert(state.frames[0].live==bits && state.frames[0].next==sequence && state.order[source]==order);
    assert(owned.ledger.used==used && owned.ledger.peak==peak && owned.rows[0].serial==serial && owned.rows[0].binding==binding);
    assert(vec::len<bytes::Buffer>(ref roots)==root_count && bytes::equal(ref original,bytes::view(vec::at<bytes::Buffer>(ref data,0))[offset..offset+16]));
    let usize cleaned=native(frames::abort(ref mut state,ref mut data,ref mut scratch,ref mut owned,ref mut roots,ref mut root_scratch));
    assert(owned.ledger.used==0 && vec::len<bytes::Buffer>(ref roots)==0);
}
fn void vm_boundary(){
    let values::Program u=simple();let usize setup=runtime::context_charge()+owners::setup_cost()+
        measured(meter::setup_cost(16))+measured(meter::enter_cost(16));
    let usize prefix=setup+1+measured(meter::operation_cost(16));let usize price=fuel::value_tag_test(16);
    assert(switch(vm::run_values(ref u,prefix+price-1,0,limits())){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==51}});
    let usize exact=prefix+price+measured(meter::operation_cost(16))+2;
    assert(switch(vm::run_values(ref u,exact-1,0,limits())){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==54}});
    runs(ref u,exact);runs(ref u,exact+1);
}
@test fn void native_tag_meter_boundaries_authenticate_roots_and_preserve_source_on_failure(){
    native_boundary(false,false);native_boundary(true,false);native_boundary(false,true);native_boundary(true,true);vm_boundary();
}

module tests::m2::record_place_ir;
import ir as ir;
import record_place_ir as records;
import slice_place_ir as views;
import place_ir as graph;
import verifier as verifier;
import errors as errors;
import vm as vm;
import place_vm as array_adapter;
import slice_place_vm as slice_adapter;
import vm_execution as execution;
import array_vm as arrays;
import slice_vm as slices;
import slice_call_vm as calls;
import static_image as images;
import static_call_ir as image_calls;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void finish(ref mut ir::Program p,usize f){let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;}
fn usize scalar(ref mut ir::Program p,u8 tag,i64 n){return if(tag==2){built(ir::boolean(p,n!=0,0))}else{built(ir::integer(p,n,tag,0))};}
fn void analysis(ref ir::Program p){assert(switch(verifier::inspect_record_places(p)){case .ok(n):{n==p.count}case .err(_):{false}});}
fn void rejected(ref ir::Program p){assert(!verifier::inspect_record_places(p).is_ok);}
fn void rejected_at(ref ir::Program p,usize pc){assert(switch(verifier::inspect_record_places(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});}
fn void error(Result<usize,errors::Error> r,u8 kind,usize at){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}});}
fn void jump(ref mut ir::Program p,usize pc,usize target){var usize i=0;while(i<8){p.code[pc*8+i]=0;i+=1;}
    p.code[pc*8]=19;let usize patched=built(ir::patch(p,pc,target,0));}

// Constants 0/1, INIT2, constant3, SELECT4, READ5, STORE6, END7,
// DROP8, i32 result9, RETURN10. Both nested leaves have the same scalar type.
fn ir::Program basic(u8 tag){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    p.records.layouts.count=2;p.records.layouts.fields[0]=1;
    p.records.layouts.kinds[0]=1;p.records.layouts.types[0]=1;
    p.records.layouts.fields[1]=2;p.records.layouts.types[16]=tag;p.records.layouts.types[17]=tag;
    let usize root=built(ir::record(ref mut p,0,true,0));
    let usize first=scalar(ref mut p,tag,0);let usize second=scalar(ref mut p,tag,0);
    let usize initialized=built(ir::record_init(ref mut p,root,first,0));
    let usize cell=scalar(ref mut p,tag,42);
    let usize selected=built(records::select(ref mut p,0,root,0,0));
    let usize old=built(records::read(ref mut p,0,root,0,0));
    let usize stored=built(records::store(ref mut p,0,root,0,cell,0));
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize dropped=built(ir::record_drop(ref mut p,root,0));
    let usize answer=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,answer,0,0));
    finish(ref mut p,0);return p;
}
// Rebuilding a fixture from a prefix must clear old kind/ordinal tails: raw
// construction appends to zero-initialized storage and does not truncate IR.
fn ir::Program prefix(){
    var ir::Program p=basic(1);p.count=4;p.registers=3;
    var usize i=32;while(i<2048){p.code[i]=0;i+=1;}return p;
}

@test fn void six_scalar_domains_reconstruct_nested_leaf_types_without_an_index_register(){
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;
    while(i<6){let ir::Program p=basic(tags[i]);analysis(ref p);
        assert(p.code[4*8+4]==2 && p.code[4*8+3]==0 && p.code[5*8+4]==2 && p.types[3]==tags[i]);
        assert(p.registers==5 && p.records.count==1 && p.arrays.count==0);
        assert(switch(graph::inspect(ref p)){case .ok(n):{n==1}case .err(_):{false}});i+=1;}
}

@test fn void exact_record_field_identity_scalar_roles_and_definedness_are_independent(){
    var ir::Program p=basic(1);p.code[5*8+5]=1;rejected_at(ref p,5);
    p=basic(1);p.code[6*8+5]=1;rejected_at(ref p,6);
    p=basic(1);p.code[4*8+3]=1;rejected_at(ref p,4);
    p=basic(1);p.code[4*8+5]=2;rejected_at(ref p,4);
    p=basic(1);p.records.mutable[0]=false;rejected_at(ref p,4);
    p=basic(1);p.types[3]=2;rejected_at(ref p,5);
    p=basic(1);p.slots[3]=true;rejected_at(ref p,5);
    p=basic(1);p.code[5*8+1]=0;rejected_at(ref p,5);
    p=basic(1);p.code[6*8+3]=4;rejected_at(ref p,6);
    p=basic(1);p.code[6*8+3]=128;rejected_at(ref p,6);
    p=basic(1);p.record_parameters[2]=1;rejected(ref p);
    p=basic(1);p.array_parameters[2]=1;rejected(ref p);
    p=basic(1);p.slice_parameters[2]=1;rejected(ref p);
    p=basic(1);p.records.layouts.types[16]=3;rejected(ref p);
    p=basic(1);p.records.layouts.types[0]=0;rejected(ref p);
    p=basic(1);p.records.count=17;rejected(ref p);
}

@test fn void phases_reselection_drop_return_and_abort_keep_affine_obligations(){
    var ir::Program p=basic(1);jump(ref mut p,4,5);rejected_at(ref p,5);
    p=basic(1);p.code[6*8]=83;p.code[6*8+3]=0;rejected_at(ref p,6);
    p=basic(1);p.code[7*8]=85;p.code[7*8+2]=0;p.code[7*8+3]=2;p.code[7*8+4]=2;rejected_at(ref p,7);
    p=basic(1);p.code[6*8]=84;p.code[6*8+1]=5;p.code[6*8+2]=0;p.code[6*8+3]=0;
    p.types[5]=1;p.registers=6;p.register_ends[0]=6;rejected_at(ref p,6);
    p=basic(1);p.code[7*8]=84;p.code[7*8+1]=5;p.code[7*8+2]=0;p.code[7*8+3]=0;p.code[7*8+4]=2;
    p.types[5]=1;p.registers=6;p.register_ends[0]=6;rejected_at(ref p,7);
    p=basic(1);jump(ref mut p,7,8);rejected_at(ref p,8);
    p=basic(1);p.count=9;p.registers=4;jump(ref mut p,7,8);var usize i=0;while(i<8){p.code[8*8+i]=0;i+=1;}
    p.code[8*8]=25;finish(ref mut p,0);analysis(ref p);
    p=basic(1);jump(ref mut p,7,9);
    assert(switch(graph::inspect(ref p)){case .ok(_):{false}case .err(e):{e.offset==10}});
    p=basic(1);jump(ref mut p,7,8);p.code[8*8]=50;
    assert(switch(graph::inspect(ref p)){case .ok(_):{false}case .err(e):{e.offset==8}});
}

fn ir::Program mixed(bool wrong_kind){
    var ir::Program p=prefix();
    let usize root=built(ir::array(ref mut p,1,1,true,0));let usize initialized=built(ir::array_init(ref mut p,root,0,0));
    let usize index=built(ir::integer(ref mut p,0,12,0));
    let usize selected=built(records::select(ref mut p,0,0,0,0));
    let usize other=built(ir::place_select(ref mut p,1,root,index,0));
    let usize stored=built(ir::place_store(ref mut p,1,root,2,0));let usize ended=built(ir::place_end(ref mut p,1,0));
    let usize dropped=built(ir::array_drop(ref mut p,root,0));
    let usize saved=if(wrong_kind){built(ir::place_store(ref mut p,0,root,2,0))}else{built(records::store(ref mut p,0,0,0,2,0))};
    let usize done=built(ir::place_end(ref mut p,0,0));let usize record_drop=built(ir::record_drop(ref mut p,0,0));
    let usize answer=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,answer,0,0));
    finish(ref mut p,0);return p;
}
fn ir::Program mixed_slice(bool wrong_kind){
    var ir::Program p=prefix();
    let usize root=built(ir::array(ref mut p,1,1,true,0));let usize init=built(ir::array_init(ref mut p,root,0,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize site=built(ir::exclusive_slice(ref mut p,root,0));let usize open=built(ir::slice_open(ref mut p,site,lo,hi,0));
    let usize record=built(records::select(ref mut p,0,0,0,0));let usize slice=built(views::select(ref mut p,1,site,lo,0));
    let usize write=if(wrong_kind){built(views::store(ref mut p,0,site,2,0))}else{built(records::store(ref mut p,0,0,0,2,0))};
    let usize end_record=built(ir::place_end(ref mut p,0,0));let usize drop_record=built(ir::record_drop(ref mut p,0,0));
    let usize store=built(views::store(ref mut p,1,site,2,0));let usize end_slice=built(ir::place_end(ref mut p,1,0));
    let usize close=built(ir::slice_close(ref mut p,site,0));let usize drop=built(ir::array_drop(ref mut p,root,0));
    let usize answer=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,answer,0,0));
    finish(ref mut p,0);return p;
}
@test fn void record_array_namespaces_share_ids_but_do_not_confuse_roots_or_lifetimes(){
    let ir::Program p=mixed(false);analysis(ref p);
    let ir::Program bad=mixed(true);rejected(ref bad);
    var ir::Program collision=mixed(false);collision.code[8*8+1]=0;rejected_at(ref collision,8);
    let ir::Program slice=mixed_slice(false);analysis(ref slice);let ir::Program confused=mixed_slice(true);rejected(ref confused);
}

fn ir::Program branch(bool same){
    var ir::Program p=prefix();
    let usize condition=built(ir::boolean(ref mut p,true,0));
    if(same){let usize selected=built(records::select(ref mut p,0,0,0,0));}
    let usize fork=built(ir::raw(ref mut p,20,0,condition,0,0));
    if(!same){let usize selected=built(records::select(ref mut p,0,0,0,0));}
    let usize left=built(ir::raw(ref mut p,19,0,0,0,0));let usize right=p.count;
    if(!same){let usize selected=built(records::select(ref mut p,0,0,1,0));}
    let usize merge=p.count;let usize patch1=built(ir::patch(ref mut p,fork,right,0));
    let usize patch2=built(ir::patch(ref mut p,left,merge,0));
    let usize stored=built(records::store(ref mut p,0,0,0,2,0));let usize ended=built(ir::place_end(ref mut p,0,0));
    let usize dropped=built(ir::record_drop(ref mut p,0,0));let usize answer=built(ir::literal(ref mut p,42,0));
    let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);return p;
}
fn ir::Program looped(bool leak){
    var ir::Program p=prefix();let usize condition=built(ir::boolean(ref mut p,false,0));
    let usize start=p.count;let usize selected=built(records::select(ref mut p,0,0,1,0));
    let usize stored=built(records::store(ref mut p,0,0,1,2,0));if(!leak){let usize ended=built(ir::place_end(ref mut p,0,0));}
    let usize branch=built(ir::raw(ref mut p,20,0,condition,0,0));let usize back=built(ir::raw(ref mut p,22,0,start,0,0));
    let usize after=p.count;let usize patched=built(ir::patch(ref mut p,branch,after,0));
    if(leak){let usize ended=built(ir::place_end(ref mut p,0,0));}
    let usize dropped=built(ir::record_drop(ref mut p,0,0));let usize answer=built(ir::literal(ref mut p,42,0));
    let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);return p;
}
@test fn void joins_and_backedges_require_identical_selecting_pcs_fields_and_phases(){
    let ir::Program valid=branch(true);analysis(ref valid);let ir::Program invalid=branch(false);rejected(ref invalid);
    let ir::Program loop=looped(false);analysis(ref loop);let ir::Program leaked=looped(true);rejected(ref leaked);
}

@test fn void caller_and_callee_have_separate_place_ids_and_containing_record_sites(){
    var ir::Program p=basic(1);let usize start=p.count;let usize regs=p.registers;
    p.function_count=2;p.entry=1;p.starts[1]=start;p.register_starts[1]=regs;p.return_types[1]=1;
    let usize site=built(ir::record_in(ref mut p,1,0,true,0));
    let usize first=built(ir::literal(ref mut p,0,0));let usize second=built(ir::literal(ref mut p,0,0));
    let usize init=built(ir::record_init(ref mut p,site,first,0));let usize selected=built(records::select(ref mut p,0,site,1,0));
    let usize old=built(records::read(ref mut p,0,site,1,0));let usize[1] none=[0];
    let usize result=built(ir::call(ref mut p,0,ref none[..0],0));
    let usize stored=built(records::store(ref mut p,0,site,1,result,0));let usize ended=built(ir::place_end(ref mut p,0,0));
    let usize drop=built(ir::record_drop(ref mut p,site,0));let usize returned=built(ir::emit(ref mut p,8,result,0,0));
    finish(ref mut p,1);analysis(ref p);
    var ir::Program bad=p;bad.code[(start+3)*8+2]=0;rejected_at(ref bad,start+3);
}

@test fn void canonical_encoding_and_atomic_builder_limits_reject_bad_operands(){
    var ir::Program p=basic(1);let usize count=p.count;let usize regs=p.registers;
    error(records::select(ref mut p,16,0,0,77),3,77);error(records::select(ref mut p,0,16,0,77),3,77);
    error(records::select(ref mut p,0,0,128,77),3,77);error(records::select(ref mut p,0,0,18446744073709551615,77),3,77);
    error(records::read(ref mut p,16,0,0,77),3,77);error(records::store(ref mut p,0,0,1,128,77),3,77);
    assert(p.count==count && p.registers==regs && p.code[4*8+4]==2 && p.code[4*8+5]==0);
    p.count=256;error(records::select(ref mut p,0,0,0,77),4,77);error(records::read(ref mut p,0,0,0,77),4,77);
    error(records::store(ref mut p,0,0,0,2,77),4,77);assert(p.count==256 && p.registers==regs);
    p=basic(1);p.registers=128;error(records::read(ref mut p,0,0,0,77),4,77);assert(p.count==count && p.registers==128);
    var usize pc=4;while(pc<8){var usize byte=6;while(byte<8){p=basic(1);p.code[pc*8+byte]=1;rejected_at(ref p,pc);byte+=1;}pc+=1;}
    p=basic(1);p.code[7*8+5]=1;rejected_at(ref p,7);
    p=basic(1);p.code[4*8+4]=3;rejected_at(ref p,4);
    p=basic(1);p.code[4*8+5]=128;rejected_at(ref p,4);
}

@test fn void maximum_ordinal_full_registers_sixteen_ids_and_final_select_pc_fit(){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    p.records.layouts.count=2;p.records.layouts.fields[0]=16;p.records.layouts.fields[1]=8;
    var usize i=0;while(i<16){p.records.layouts.kinds[i]=1;p.records.layouts.types[i]=1;i+=1;}
    i=0;while(i<8){p.records.layouts.types[16+i]=10;i+=1;}
    let usize root=built(ir::record(ref mut p,0,true,0));i=0;while(i<128){let usize cell=built(ir::integer(ref mut p,20,10,0));i+=1;}
    let usize init=built(ir::record_init(ref mut p,root,0,0));
    let usize selected=built(records::select(ref mut p,15,root,127,0));
    error(records::read(ref mut p,15,root,127,77),4,77);
    let usize stored=built(records::store(ref mut p,15,root,127,127,0));let usize ended=built(ir::place_end(ref mut p,15,0));
    let usize drop=built(ir::record_drop(ref mut p,root,0));let usize trap=built(ir::raw(ref mut p,25,0,0,0,0));finish(ref mut p,0);
    assert(p.registers==128 && p.code[selected*8+5]==127);analysis(ref p);
    p=prefix();i=0;
    while(i<16){let usize capture=built(records::select(ref mut p,i,0,1,0));i+=1;}
    while(i>0){i-=1;let usize save=built(records::store(ref mut p,i,0,1,2,0));let usize end=built(ir::place_end(ref mut p,i,0));}
    let usize dropped=built(ir::record_drop(ref mut p,0,0));let usize answer=built(ir::literal(ref mut p,42,0));
    let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);analysis(ref p);
    p=prefix();while(p.count<254){let usize next=p.count+1;let usize step=built(ir::raw(ref mut p,19,0,next,0,0));}
    let usize last=built(records::select(ref mut p,15,0,1,0));let usize aborted=built(ir::raw(ref mut p,25,0,0,0,0));finish(ref mut p,0);
    assert(last==254 && p.count==256);analysis(ref p);
}

@test fn void analysis_never_grants_executable_or_old_adapter_authority_before_fuel_or_allocations(){
    let ir::Program p=basic(1);analysis(ref p);
    assert(!verifier::inspect(ref p).is_ok && !verifier::inspect_slice_places(ref p).is_ok && !verifier::verify(ref p).is_ok);
    let images::Builder builder=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let images::Image image=switch(images::freeze(ref builder,65536)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(!verifier::inspect_statics(ref p,ref image).is_ok);
    assert(!verifier::verify_statics(ref p,ref image).is_ok);
    let image_calls::Program unit=image_calls::Program{.body=p,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    assert(!verifier::inspect_reference_calls(ref unit,ref image).is_ok && !verifier::inspect_reference_returns(ref unit,ref image).is_ok);
    assert(!array_adapter::requirement(ref p).is_ok && !slice_adapter::requirement(ref p).is_ok);
    error(array_adapter::cost(ref p,4),5,4);error(slice_adapter::cost(ref p,4,true),5,4);
    assert(switch(vm::run(ref p,0)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==4}});
    assert(switch(vm::run(ref p,16000000)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==4}});
    var arrays::State a=arrays::empty(0);var bytes::Buffer data=bytes::empty();var slices::State l=slices::empty();var calls::Frames frames=calls::empty();
    assert(switch(execution::execute(ref p,0,ref mut a,ref mut data,ref mut l,ref mut frames)){case .ok(_):{false}case .err(e):{e.kind==5}});
    assert(a.owners.depth==0 && a.owners.arena.used==0 && bytes::len(ref data)==0);
}

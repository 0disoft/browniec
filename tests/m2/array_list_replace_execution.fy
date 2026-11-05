module tests::m2::array_list_replace_execution;
import ir as ir;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import errors as errors;
import array_list_vm as lists;
import array_vm as arrays;
import array_owners as owners;
import array_layout as layouts;
import static_call_ir as calls;
import static_image as images;
import program_image as programs;
import std::num as num;
import std::vec as vec;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 wide(usize n){return switch(num::i64_from_usize(n)){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 byte(usize n){return switch(num::u8_from_i64(wide(n))){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void finish(ref mut ir::Program p){let usize end=p.count;let usize regs=p.registers;
    p.function_count=1;p.entry=0;p.ends[0]=end;p.register_ends[0]=regs;p.return_types[0]=1;}
fn void value(Result<i64,errors::Error> r){assert(switch(r){case .ok(v):{v==42}case .err(_):{false}});}
fn void failure(Result<i64,errors::Error> r,u8 kind){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind}});}
fn void step_error(Result<usize,errors::Error> r,u8 kind){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind}});}
fn ir::Program pair(u8 tag,i64 left,i64 right,usize length){
    var ir::Program p=ir::empty();let usize id=built(ir::array(ref mut p,tag,length,true,0));
    let usize a=if(tag==2){built(ir::boolean(ref mut p,left==1,0))}else{built(ir::integer(ref mut p,left,tag,0))};
    let usize b=if(tag==2){built(ir::boolean(ref mut p,right==1,0))}else{built(ir::integer(ref mut p,right,tag,0))};
    let usize zero=built(ir::integer(ref mut p,0,12,0));let usize last=built(ir::integer(ref mut p,wide(length-1),12,0));
    let usize init=built(ir::array_init(ref mut p,id,a,0));
    var usize[4096] operands=[a;4096];operands[length-1]=b;
    let usize replace=built(ir::array_replace_values(ref mut p,id,ref operands[..length],0));
    let usize first=built(ir::array_read(ref mut p,id,zero,0));let usize final=built(ir::array_read(ref mut p,id,last,0));
    let usize eq0=built(ir::emit(ref mut p,11,first,a,0));let usize eq1=built(ir::emit(ref mut p,11,final,b,0));
    let usize drop=built(ir::array_drop(ref mut p,id,0));
    let usize yes=built(ir::literal(ref mut p,42,0));let usize no=built(ir::literal(ref mut p,0,0));let usize target=p.count+3;
    let usize branch0=built(ir::raw(ref mut p,20,0,eq0,target,0));let usize branch1=built(ir::raw(ref mut p,20,0,eq1,target,0));
    let usize returned=built(ir::emit(ref mut p,8,yes,0,0));let usize failed=built(ir::emit(ref mut p,8,no,0,0));
    finish(ref mut p);return p;
}
// Independent schedule for the successful straight-line pair path (last RETURN
// is skipped). Replacement has no allocation-padding charge and retains its owner.
fn usize price(ref ir::Program p,usize backing){
    let u8 tag=p.arrays.elements[0];let usize stride=if(tag==2 || tag==10){1}else if(tag==1 || tag==11){4}else{8};
    let usize n=p.arrays.lengths[0];let usize size=n*stride;
    var usize total=1+backing+257+2*n+size;var usize pc=0;
    while(pc+1<p.count){let u8 op=p.code[pc*8];total+=if(op==33){49+2*stride+size+7}
        else if(op==81){49+n+3*size}else if(op==35){33+stride}else if(op==37){49}else{1};pc+=1;}
    return total;
}
fn void exact(ref ir::Program p,usize backing){let usize fuel=price(p,backing);assert(verifier::verify(p).is_ok);
    failure(vm::run_with_array_limit(p,fuel-1,backing),8);value(vm::run_with_array_limit(p,fuel,backing));
    value(vm::run_with_array_limit(p,fuel+1,backing));}
@test fn void replacement_only_operand_pools_execute_six_domains_at_exact_fuel(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] low=[-2147483648,0,-9223372036854775808,0,0,0];
    let i64[6] high=[2147483647,1,9223372036854775807,255,4294967295,-1];var usize i=0;
    while(i<6){let ir::Program p=pair(tags[i],low[i],high[i],2);exact(ref p,16);i+=1;}
}
fn ir::Program pressure(){var ir::Program p=ir::empty();let usize root=built(ir::array(ref mut p,1,2,true,0));
    let usize a=built(ir::literal(ref mut p,20,0));let usize b=built(ir::literal(ref mut p,22,0));
    let usize init=built(ir::array_init(ref mut p,root,a,0));let usize octet=built(ir::integer(ref mut p,7,10,0));
    var usize i=0;while(i<15){let usize id=built(ir::array(ref mut p,10,1,false,0));let usize made=built(ir::array_init(ref mut p,id,octet,0));i+=1;}
    let usize[2] values=[a,b];let usize replaced=built(ir::array_replace_values(ref mut p,root,ref values,0));
    let usize zero=built(ir::integer(ref mut p,0,12,0));let usize one=built(ir::integer(ref mut p,1,12,0));
    let usize x=built(ir::array_read(ref mut p,root,zero,0));let usize y=built(ir::array_read(ref mut p,root,one,0));
    let usize sum=built(ir::emit(ref mut p,2,x,y,0));i=16;while(i>0){i-=1;let usize drop=built(ir::array_drop(ref mut p,i,0));}
    let usize returned=built(ir::emit(ref mut p,8,sum,0,0));finish(ref mut p);return p;
}
@test fn void full_4096_pool_and_full_sixteen_owner_quota_require_no_extra_extent(){
    let ir::Program full=pair(9,-9223372036854775808,9223372036854775807,4096);
    assert(full.list_used==4096);exact(ref full,32768);
    let ir::Program p=pressure();assert(p.arrays.count==16 && verifier::verify(ref p).is_ok);
    value(vm::run_with_array_limit(ref p,16000000,23));failure(vm::run_with_array_limit(ref p,16000000,22),13);
}
fn void same(ref arrays::State a,ref arrays::State b,ref u8[] data,ref u8[] before){
    assert(a.owners.depth==b.owners.depth && a.owners.arena.used==b.owners.arena.used && a.owners.arena.limit==b.owners.arena.limit);
    var usize i=0;while(i<512){assert(a.tokens[i].slot==b.tokens[i].slot && a.tokens[i].generation==b.tokens[i].generation);i+=1;}
    i=0;while(i<16){let owners::Owner x=a.owners.slots[i];let owners::Owner y=b.owners.slots[i];
        assert(a.owners.order[i]==b.owners.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length);
        assert(x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation && x.record==y.record && x.alignment==y.alignment);i+=1;
    }assert(data.len==before.len);i=0;while(i<data.len){assert(data[i]==before[i]);i+=1;}
}
@test fn void short_fuel_bad_cells_and_locked_or_stale_tokens_preserve_state_and_scratch_capacity(){
    let ir::Program p=pair(1,20,22,2);let lists::Requirement plan=switch(lists::requirement(ref p)){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(plan.length==2 && plan.bytes==8 && plan.cost==269);
    var vec::Vec<i64> cells=switch(lists::prepare_values(ref plan)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var bytes::Buffer scratch=switch(lists::prepare_encoded(ref plan)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize capacity=vec::capacity<i64>(ref cells);let usize encoded=bytes::capacity(ref scratch);
    var arrays::State state=arrays::empty(8);var u8[8] data=[85;8];let layouts::Array layout=switch(layouts::scalar(1,2)){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    let owners::Token token=switch(owners::create(ref layout,7,ref mut data,ref mut state.owners)){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    state.tokens[0]=token;
    var i64[128] regs=[0;128];regs[0]=20;regs[1]=22;
    {let arrays::State before=state;let u8[8] prior=data;
        step_error(lists::step(ref p,5,0,ref mut state,ref mut data,ref regs,ref mut cells,ref mut scratch,74),8);
        same(ref state,ref before,ref data,ref prior);regs[1]=2147483648;
        step_error(lists::step(ref p,5,0,ref mut state,ref mut data,ref regs,ref mut cells,ref mut scratch,75),5);
        same(ref state,ref before,ref data,ref prior);regs[1]=22;
    }
    let owners::ReadLease lease=switch(owners::begin_read(ref mut state.owners,token,data.len)){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    {let arrays::State before=state;let u8[8] prior=data;
        step_error(lists::step(ref p,5,0,ref mut state,ref mut data,ref regs,ref mut cells,ref mut scratch,75),5);
        same(ref state,ref before,ref data,ref prior);
    }assert(owners::end_read(ref mut state.owners,lease,data.len).is_ok);
    state.tokens[0].generation+=1;
    {let arrays::State before=state;let u8[8] prior=data;
        step_error(lists::step(ref p,5,0,ref mut state,ref mut data,ref regs,ref mut cells,ref mut scratch,75),5);
        same(ref state,ref before,ref data,ref prior);
    }state.tokens[0].generation-=1;
    let arrays::State metadata=state;
    assert(built(lists::step(ref p,5,0,ref mut state,ref mut data,ref regs,ref mut cells,ref mut scratch,75))==0);
    let u8[8] after=data;same(ref state,ref metadata,ref data,ref after);assert(data[0]==20 && data[4]==22);
    assert(vec::capacity<i64>(ref cells)==capacity && bytes::capacity(ref scratch)==encoded);
}
fn void rejected(ref ir::Program p){assert(!verifier::verify(p).is_ok);failure(vm::run_with_array_limit(p,0,65537),5);}
fn ir::Program borrowed(bool exclusive){var ir::Program p=ir::empty();let usize root=built(ir::array(ref mut p,1,2,true,0));
    let usize fill=built(ir::literal(ref mut p,21,0));let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,2,12,0));
    let usize site=if(exclusive){built(ir::exclusive_slice(ref mut p,root,0))}else{built(ir::slice(ref mut p,root,0))};
    let usize open=built(ir::slice_open(ref mut p,site,lo,hi,0));let usize[2] values=[fill,fill];
    let usize replaced=built(ir::array_replace_values(ref mut p,root,ref values,0));let usize close=built(ir::slice_close(ref mut p,site,0));
    let usize drop=built(ir::array_drop(ref mut p,root,0));let usize yes=built(ir::literal(ref mut p,42,0));let usize end=built(ir::emit(ref mut p,8,yes,0,0));
    finish(ref mut p);return p;}
@test fn void independent_proof_rejects_forged_pool_mutability_definitions_liveness_and_borrows(){
    let ir::Program original=pair(1,20,22,2);var ir::Program p=original;
    p.arrays.mutable[0]=false;rejected(ref p);p=original;p.list_used=3;rejected(ref p);p=original;
    p.code[5*8+2]=1;rejected(ref p);p=original;p.code[5*8+4]=1;rejected(ref p);p=original;
    let u8 future=p.code[6*8+1];p.list_operands[0]=future;rejected(ref p);p=original;p.list_operands[1]=127;rejected(ref p);p=original;
    p.code[4*8]=19;p.code[4*8+1]=0;p.code[4*8+3]=0;assert(ir::patch(ref mut p,4,5,0).is_ok);rejected(ref p);
    let ir::Program shared=borrowed(false);rejected(ref shared);let ir::Program exclusive=borrowed(true);rejected(ref exclusive);
    var ir::Program builder=original;builder.arrays.mutable[0]=false;let usize count=builder.count;let usize pool=builder.list_used;let usize[2] values=[0,1];
    assert(!ir::array_replace_values(ref mut builder,0,ref values,0).is_ok);assert(builder.count==count && builder.list_used==pool);
}
fn images::Image image(){var images::Builder b=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    return switch(images::freeze(ref b,images::metadata_charge())){case .ok(v):{v}case .err(_):{assert(false);image()}};}
@test fn void retained_replacement_prepays_setup_and_existing_owner_work_at_exact_fuel(){
    let calls::Program code=calls::Program{.body=pair(1,20,22,2),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    let programs::ReferenceReturnProgram retained=switch(programs::retain_reference_returns(ref code,image(),images::metadata_charge())){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize required=price(ref code.body,65536)+147456+196608+5;
    failure(programs::run_public_references(ref retained,required-1),8);value(programs::run_public_references(ref retained,required));
    value(programs::run_public_references(ref retained,required+1));
}
fn void refills(ref mut ir::Program p){var usize pc=0;while(pc<p.count){let usize at=pc*8;if(p.code[at]==40){
        let usize id=p.code[at+1] as usize;let u8 value=p.code[at+2];let usize start=p.list_used;let usize n=p.arrays.lengths[id];
        assert(start+n<=4096);var usize i=0;while(i<n){p.list_operands[start+i]=value;i+=1;}
        p.list_used=start+n;p.code[at]=81;p.code[at+2]=byte(start%256);p.code[at+3]=byte(start/256);
    }pc+=1;}}
@test fn void list_replacement_reuses_owners_and_scratch_through_calls_and_loops(){
    var ir::Program p=switch(compiler::compile(b"module main;fn i32[2] make(){var a=[0;2];a=[21;2];return a;}fn i32 main(){var n=0;var sum=0;while(n<3){let a=make();sum=sum+a[0]+a[1];n=n+1;}return sum-84;}")){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    refills(ref mut p);assert(verifier::verify(ref p).is_ok);value(vm::run_with_array_limit(ref p,16000000,8));
    let calls::Program code=calls::Program{.body=p,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    let programs::ReferenceReturnProgram retained=switch(programs::retain_reference_returns(ref code,image(),images::metadata_charge())){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    value(programs::run_public_references(ref retained,16000000));
}

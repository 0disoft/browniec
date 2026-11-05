module tests::m2::array_list_execution;
import ir as ir;
import verifier as verifier;
import vm as vm;
import errors as errors;
import array_list_vm as lists;
import array_vm as arrays;
import array_owners as owners;
import static_call_ir as calls;
import static_image as images;
import program_image as programs;
import std::num as num;
import std::vec as vec;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 wide(usize n){return switch(num::i64_from_usize(n)){case .ok(v):{v}case .err(_):{assert(false);0}};}
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
    var usize[4096] operands=[a;4096];operands[length-1]=b;
    let usize init=built(ir::array_values(ref mut p,id,ref operands[..length],0));
    let usize first=built(ir::array_read(ref mut p,id,zero,0));let usize final=built(ir::array_read(ref mut p,id,last,0));
    let usize eq0=built(ir::emit(ref mut p,11,first,a,0));let usize eq1=built(ir::emit(ref mut p,11,final,b,0));
    let usize drop=built(ir::array_drop(ref mut p,id,0));
    let usize yes=built(ir::literal(ref mut p,42,0));let usize no=built(ir::literal(ref mut p,0,0));let usize target=p.count+3;
    let usize branch0=built(ir::raw(ref mut p,20,0,eq0,target,0));let usize branch1=built(ir::raw(ref mut p,20,0,eq1,target,0));
    let usize returned=built(ir::emit(ref mut p,8,yes,0,0));let usize failed=built(ir::emit(ref mut p,8,no,0,0));
    finish(ref mut p);return p;
}
// Independent numeric oracle for this fixture's successful straight-line path.
// The final failure RETURN is not executed. No production pricing helper is used.
fn usize price(ref ir::Program p,usize backing){
    let u8 tag=p.arrays.elements[0];let usize stride=if(tag==2 || tag==10){1}else if(tag==1 || tag==11){4}else{8};
    let usize length=p.arrays.lengths[0];let usize size=length*stride;
    var usize total=1+backing+257+2*length+size;var usize pc=0;
    while(pc+1<p.count){let u8 op=p.code[pc*8];
        total+=if(op==80){56+length+3*size}else if(op==35){33+stride}else if(op==37){49}else{1};pc+=1;
    }return total;
}
fn void exact(ref ir::Program p,usize backing){let usize required=price(p,backing);
    assert(verifier::verify(p).is_ok);failure(vm::run_with_array_limit(p,required-1,backing),8);
    value(vm::run_with_array_limit(p,required,backing));value(vm::run_with_array_limit(p,required+1,backing));
}
@test fn void six_scalar_domains_execute_at_independently_computed_exact_fuel(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] low=[-2147483648,0,-9223372036854775808,0,0,0];
    let i64[6] high=[2147483647,1,9223372036854775807,255,4294967295,-1];var usize i=0;
    while(i<6){let ir::Program p=pair(tags[i],low[i],high[i],2);exact(ref p,16);i+=1;}
}
@test fn void full_4096_operand_ir_and_32768_byte_payload_preserve_capacity(){
    let ir::Program p=pair(9,-9223372036854775808,9223372036854775807,4096);
    assert(p.list_used==4096);exact(ref p,32768);failure(vm::run_with_array_limit(ref p,16000000,32767),13);
}
fn void unchanged(ref arrays::State a,ref arrays::State b,ref u8[] data){
    assert(a.owners.depth==b.owners.depth && a.owners.arena.used==b.owners.arena.used && a.owners.arena.limit==b.owners.arena.limit);
    var usize i=0;while(i<512){assert(a.tokens[i].slot==b.tokens[i].slot && a.tokens[i].generation==b.tokens[i].generation);i+=1;}
    i=0;while(i<16){let owners::Owner x=a.owners.slots[i];let owners::Owner y=b.owners.slots[i];
        assert(a.owners.order[i]==b.owners.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length);
        assert(x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation && x.record==y.record && x.alignment==y.alignment);i+=1;
    }i=0;while(i<data.len){assert(data[i]==85);i+=1;}
}
@test fn void instruction_shortage_bad_cells_and_quota_do_not_publish_or_allocate_again(){
    let ir::Program p=pair(1,20,22,2);assert(verifier::verify(ref p).is_ok);
    let lists::Requirement plan=switch(lists::requirement(ref p)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(plan.length==2 && plan.bytes==8 && plan.cost==269);
    var vec::Vec<i64> cells=switch(lists::prepare_values(ref plan)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var bytes::Buffer scratch=switch(lists::prepare_encoded(ref plan)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize capacity=vec::capacity<i64>(ref cells);let usize encoded_capacity=bytes::capacity(ref scratch);
    var arrays::State state=arrays::empty(8);let arrays::State before=state;var u8[8] data=[85;8];
    var i64[128] regs=[0;128];regs[0]=20;regs[1]=22;
    step_error(lists::step(ref p,4,0,ref mut state,ref mut data,ref regs,ref mut cells,ref mut scratch,81),8);
    unchanged(ref state,ref before,ref data);
    regs[1]=2147483648;
    step_error(lists::step(ref p,4,0,ref mut state,ref mut data,ref regs,ref mut cells,ref mut scratch,82),5);
    unchanged(ref state,ref before,ref data);regs[1]=22;
    var arrays::State quota=arrays::empty(7);let arrays::State quota_before=quota;
    step_error(lists::step(ref p,4,0,ref mut quota,ref mut data,ref regs,ref mut cells,ref mut scratch,82),13);
    unchanged(ref quota,ref quota_before,ref data);
    assert(built(lists::step(ref p,4,0,ref mut state,ref mut data,ref regs,ref mut cells,ref mut scratch,82))==0);
    assert(state.owners.depth==1 && state.owners.arena.used==8 && state.tokens[0].generation!=0);
    assert(vec::capacity<i64>(ref cells)==capacity && bytes::capacity(ref scratch)==encoded_capacity);
    step_error(lists::step(ref p,4,0,ref mut state,ref mut data,ref regs,ref mut cells,ref mut scratch,82),5);
}
@test fn void independent_admission_rejects_pool_type_definition_and_ownership_forgery(){
    let ir::Program original=pair(1,20,22,2);var ir::Program p=original;
    p.list_used=3;assert(!verifier::verify(ref p).is_ok);p=original;
    p.list_operands[2]=1;assert(!verifier::verify(ref p).is_ok);p=original;
    p.list_operands[1]=127;assert(!verifier::verify(ref p).is_ok);p=original;
    p.list_operands[1]=2;assert(!verifier::verify(ref p).is_ok);p=original;
    p.code[4*8+2]=1;assert(!verifier::verify(ref p).is_ok);p=original;
    p.code[4*8+4]=1;assert(!verifier::verify(ref p).is_ok);p=original;
    p.arrays.lengths[0]=3;assert(!verifier::verify(ref p).is_ok);p=original;
    p.array_functions[0]=1;assert(!verifier::verify(ref p).is_ok);p=original;
    p.code[5*8]=80;assert(!verifier::verify(ref p).is_ok);
    // One branch reaches the list without defining its first element.
    var ir::Program branch=ir::empty();let usize id=built(ir::array(ref mut branch,1,2,false,0));
    let usize condition=built(ir::boolean(ref mut branch,true,0));let usize jump=built(ir::raw(ref mut branch,20,0,condition,3,0));
    let usize left=built(ir::literal(ref mut branch,20,0));let usize right=built(ir::literal(ref mut branch,22,0));
    let usize[2] operands=[left,right];let usize init=built(ir::array_values(ref mut branch,id,ref operands,0));
    let usize drop=built(ir::array_drop(ref mut branch,id,0));let usize answer=built(ir::literal(ref mut branch,42,0));
    let usize returned=built(ir::emit(ref mut branch,8,answer,0,0));finish(ref mut branch);
    assert(!verifier::verify(ref branch).is_ok);failure(vm::run_with_array_limit(ref branch,0,65537),5);
}
fn images::Image image(){var images::Builder b=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    return switch(images::freeze(ref b,images::metadata_charge())){case .ok(v):{v}case .err(_):{assert(false);image()}};
}
@test fn void retained_coordinator_uses_exact_setup_prices_and_keeps_its_separate_dispatch(){
    let calls::Program code=calls::Program{.body=pair(1,20,22,2),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    let programs::ReferenceReturnProgram retained=switch(programs::retain_reference_returns(ref code,image(),images::metadata_charge())){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    // Existing entry/leave reserves plus one coordinator unit for each of the
    // four aggregate instructions (INITV, READ, READ, DROP); ordinary RETURN.
    let usize required=price(ref code.body,65536)+147456+196608+4;
    failure(programs::run_public_references(ref retained,required-1),8);
    value(programs::run_public_references(ref retained,required));value(programs::run_public_references(ref retained,required+1));
}
@test fn void owned_array_results_recreate_the_same_list_site_across_three_calls(){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=1;p.return_types[1]=1;
    let usize child=built(ir::array_in(ref mut p,0,1,2,false,0));p.array_results[0]=1;
    let usize a=built(ir::literal(ref mut p,20,0));let usize b=built(ir::literal(ref mut p,22,0));let usize[2] operands=[a,b];
    let usize init=built(ir::array_values(ref mut p,child,ref operands,0));let usize returned=built(ir::raw(ref mut p,39,0,child,0,0));
    let usize end=p.count;let usize regs=p.registers;p.ends[0]=end;p.register_ends[0]=regs;p.starts[1]=end;p.register_starts[1]=regs;
    let usize parent=built(ir::array_in(ref mut p,1,1,2,false,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
    var usize answer=0;var usize i=0;
    while(i<3){let usize called=built(ir::raw(ref mut p,9,128+parent,0,i,0));
        let usize x=built(ir::array_read(ref mut p,parent,lo,0));let usize y=built(ir::array_read(ref mut p,parent,hi,0));
        answer=built(ir::emit(ref mut p,2,x,y,0));let usize drop=built(ir::array_drop(ref mut p,parent,0));i+=1;
    }
    p.call_count=3;let usize last=built(ir::emit(ref mut p,8,answer,0,0));
    let usize end1=p.count;let usize regs1=p.registers;p.ends[1]=end1;p.register_ends[1]=regs1;
    assert(verifier::verify(ref p).is_ok);value(vm::run_with_array_limit(ref p,16000000,8));
}

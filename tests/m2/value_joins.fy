module tests::m2::value_joins;
import value_join_source as joins;
import record_expression_source as records;
import ir as ir;
import vm as vm;
import verifier as verifier;
import errors as errors;
import std::num as num;
import cells as cells;
fn u8 byte(usize n){let i64 packed=switch(cells::pack(n,0)){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(num::u8_from_i64(packed)){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize built(Result<usize,errors::Error> value){return switch(value){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void finish(ref mut ir::Program p){
    let usize count=p.count;let usize registers=p.registers;
    p.function_count=1;p.entry=0;p.starts[0]=0;p.ends[0]=count;
    p.register_starts[0]=0;p.register_ends[0]=registers;p.return_types[0]=1;
}
fn ir::Program branch(bool selected,bool record){
    var ir::Program p=ir::empty();var joins::Join join=joins::empty(0,false);
    if(record){p.records.layouts.count=1;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=1;}
    let usize condition=built(ir::boolean(ref mut p,selected,0));
    let usize branch=built(ir::raw(ref mut p,20,0,condition,0,0));
    var usize arm=0;var usize skip=256;
    while(arm<2){
        let usize n=built(ir::literal(ref mut p,42,0));
        if(record){
            let usize slot=built(ir::slot(ref mut p,1,0));let usize stored=built(ir::raw(ref mut p,18,slot,n,0,0));
            var records::Value value=records::Value{.id=16,.owned=false,.record=0,.ordinal=0,.tag=0,.slots=[0;16],.depth=0};
            value.slots[0]=slot;let usize accepted=built(joins::accept_record(ref mut p,ref mut join,0,ref value,0));
        }else{
            let usize id=if(arm==0){built(ir::array_in(ref mut p,0,1,1,false,0))}else{joins::array_target(ref join,1,1)};
            let usize initialized=built(ir::array_init(ref mut p,id,n,0));
            let usize accepted=built(joins::accept_array(ref mut p,ref mut join,0,id,true,0));
        }
        if(arm==0){skip=built(ir::raw(ref mut p,19,0,0,0,0));let usize target=p.count;let usize patched=built(ir::patch(ref mut p,branch,target,0));}
        arm+=1;
    }
    let usize target=p.count;let usize patched=built(ir::patch(ref mut p,skip,target,0));let usize encoded=built(joins::finish(ref mut p,ref join,0));
    var usize value=0;
    if(record){value=built(ir::record_read(ref mut p,encoded-144,0,0));let usize dropped=built(ir::record_drop(ref mut p,encoded-144,0));}
    else{let usize index=built(ir::integer(ref mut p,0,12,0));value=built(ir::array_read(ref mut p,encoded-128,index,0));let usize dropped=built(ir::array_drop(ref mut p,encoded-128,0));}
    let usize returned=built(ir::emit(ref mut p,8,value,0,0));finish(ref mut p);return p;
}
@test fn void branches_share_one_owner_and_exact_backing_without_a_phi_opcode(){
    var usize i=0;while(i<4){let ir::Program p=branch(i%2==0,i>=2);
        assert(verifier::verify(ref p).is_ok);
        assert(p.arrays.count+p.records.count==1);
        assert(switch(vm::run_with_array_limit(ref p,16000000,4)){case .ok(n):{n==42}case .err(_):{false}});
        assert(switch(vm::run_with_array_limit(ref p,16000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});i+=1;
    }
}
@test fn void independent_admission_rejects_missing_or_duplicate_branch_initialization(){
    var ir::Program p=branch(true,false);var usize pc=0;var usize second=256;
    while(pc<p.count){if(p.code[pc*8]==33){second=pc;}pc+=1;}
    assert(second!=256);p.code[second*8]=19;p.code[second*8+1]=0;p.code[second*8+2]=byte(second+1);
    assert(!verifier::verify(ref p).is_ok);
    var ir::Program q=branch(true,false);pc=0;
    while(pc<q.count){if(q.code[pc*8]==19){q.code[pc*8+2]=byte(pc+1);break;}pc+=1;}
    assert(!verifier::verify(ref q).is_ok);
}

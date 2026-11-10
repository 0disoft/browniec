module tests::m2::output_verifier_flow_work;
import output_verifier_flow_work as work;
import output_list_operands_work as lists;
import metadata_budget as budget;
import verifier as raw;
import ir as ir;
import static_ir as statics;
import struct_meta as records;
import slice_reborrow_ir as loans;
import errors as errors;

fn ir::Program program(){
    var ir::Program p=ir::empty();p.count=2;p.function_count=1;p.ends[0]=2;p.registers=1;p.register_ends[0]=1;
    p.return_types[0]=1;p.constant_count=1;p.constants[0]=42;p.types[0]=1;p.code[0]=1;p.code[8]=8;return p;
}
fn ir::Program list(){
    var ir::Program p=program();p.count=5;p.ends[0]=5;p.registers=2;p.register_ends[0]=2;p.types[0]=10;p.types[1]=1;
    p.constants[0]=65;p.constants[1]=42;p.constant_count=2;p.arrays.count=1;p.arrays.elements[0]=10;p.arrays.lengths[0]=4096;p.list_used=4096;
    p.code[8]=80;p.code[16]=37;p.code[24]=1;p.code[25]=1;p.code[26]=1;p.code[32]=8;p.code[34]=1;return p;
}
fn Result<usize,errors::Error> staged(ref ir::Program p,bool defers){
    let records::Prepared shapes=records::prepare(ref p.records)?;let loans::Sites forest=loans::metadata(p)?;
    let statics::Sites sites=statics::empty();var work::State w=work::empty();let usize started=work::begin(ref mut w,0)?;
    var budget::State meter=budget::empty();var lists::State operands=lists::empty(1,0);var bool pending=false;
    var usize turns=0;while(!w.done){assert(turns<600);assert(budget::reset(ref mut meter,0).is_ok);
        if(w.task!=0 && !w.approved){
            assert(w.task==3 && w.pc==1 && w.live==0);pending=true;
            let bool done=lists::advance(p,ref w.defined,ref mut operands,ref mut meter)?;
            if(done){let usize supplied=work::provide(ref mut w,1)?;}
        }else{
            if(defers){let work::State saved=w;assert(budget::admit(ref mut meter,1,0).is_ok);let budget::State before=meter;
                let bool done=work::advance(p,ref shapes,ref forest,ref sites,ref mut w,ref mut meter)?;
                assert(!done && w.phase==saved.phase && w.pc==saved.pc && w.index==saved.index && w.task==saved.task && w.approved==saved.approved);
                var usize i=0;while(i<512){assert(w.states[i]==saved.states[i]);i+=1;}
                i=0;while(i<256){assert(w.seen[i]==saved.seen[i] && w.arrays[i]==saved.arrays[i] && w.statics[i]==saved.statics[i]);i+=1;}
                assert(meter.total==before.total && meter.last==before.last && meter.stages==before.stages);
                assert(budget::reset(ref mut meter,0).is_ok);
            }
            let bool done=work::advance(p,ref shapes,ref forest,ref sites,ref mut w,ref mut meter)?;assert(done==w.done);
        }
        assert(meter.last==4096);turns+=1;
    }
    if(p.arrays.count!=0){assert(pending);}return .ok(p.count);
}
fn void same(ref ir::Program p){
    switch(raw::inspect_reborrow_calls(p)){
        case .ok(expected):{switch(staged(p,true)){case .ok(actual):{assert(actual==expected);}case .err(_):{assert(false);}};}
        case .err(expected):{switch(staged(p,true)){case .ok(_):{assert(false);}case .err(actual):{assert(actual.kind==expected.kind && actual.offset==expected.offset);}};}
    };
}
@test fn void scalar_proof_and_bounded_definition_banks_match_raw(){
    var ir::Program p=program();same(ref p);
    p=program();p.code[8]=25;same(ref p);
}
@test fn void scalar_constant_reserved_return_and_dead_pc_diagnostics_match_raw(){
    var ir::Program p=program();p.code[2]=1;same(ref p);
    p=program();p.code[4]=1;same(ref p);
    p=program();p.code[0]=117;same(ref p);
    p=program();p.code[8]=1;same(ref p);
    p=program();p.code[10]=1;same(ref p);
    p=program();p.code[0]=8;same(ref p);
}
@test fn void large_list_operand_task_preserves_pc_until_independent_proof_completes(){
    var ir::Program p=list();same(ref p);p.list_operands[4095]=1;same(ref p);
}

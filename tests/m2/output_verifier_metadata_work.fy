module tests::m2::output_verifier_metadata_work;
import output_verifier_metadata_work as work;
import verifier as raw;
import static_ir as statics;
import metadata_budget as budget;
import ir as ir;
import errors as errors;

fn ir::Program program(){
    var ir::Program p=ir::empty();p.count=2;p.function_count=1;p.ends[0]=2;p.registers=1;p.register_ends[0]=1;
    p.return_types[0]=1;p.constant_count=1;p.constants[0]=42;p.types[0]=1;p.code[0]=1;p.code[8]=8;return p;
}
fn Result<usize,errors::Error> staged(ref ir::Program p,bool defers){
    var work::State w=work::empty(false);let statics::Sites sites=statics::empty();
    var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<1024);assert(budget::reset(ref mut meter,0).is_ok);
        if(defers){let work::State saved=w;assert(budget::admit(ref mut meter,1,0).is_ok);let budget::State before=meter;
            let bool done=work::advance(p,ref sites,ref mut w,ref mut meter)?;
            assert(!done && w.phase==saved.phase && w.function==saved.function && w.pc==saved.pc &&
                w.code_end==saved.code_end && w.register_end==saved.register_end && !w.done);
            assert(meter.total==before.total && meter.stages==before.stages && meter.last==before.last);
            assert(budget::reset(ref mut meter,0).is_ok);
        }
        let bool done=work::advance(p,ref sites,ref mut w,ref mut meter)?;
        assert(done==w.done && meter.last==4096);turns+=1;
    }return .ok(p.count);
}
fn void same(ref ir::Program p){
    // Each fixture has valid scalar CFG unless its metadata rejects first.
    switch(raw::inspect_reborrow_calls(p)){
        case .ok(expected):{switch(staged(p,true)){case .ok(actual):{assert(actual==expected);}case .err(_):{assert(false);}};}
        case .err(expected):{switch(staged(p,true)){case .ok(_):{assert(false);}case .err(actual):{assert(actual.kind==expected.kind && actual.offset==expected.offset);}};}
    };
}
@test fn void complete_scalar_metadata_and_partitions_match_raw_verifier(){
    var ir::Program p=program();same(ref p);
    p.count=4;p.function_count=2;p.starts[1]=2;p.ends[1]=4;p.registers=2;p.register_ends[1]=2;
    p.register_starts[1]=1;p.types[1]=1;p.return_types[1]=1;p.code[16]=1;p.code[17]=1;p.code[24]=8;p.code[26]=1;same(ref p);
}
@test fn void metadata_error_precedence_catalogs_partitions_and_formals_match_raw(){
    var ir::Program p=program();p.count=257;same(ref p);
    p=program();p.list_operands[4095]=1;p.ends[0]=1;same(ref p);
    p=program();p.records.layouts.types[511]=1;same(ref p);
    p=program();p.array_functions[15]=1;same(ref p);
    p=program();p.return_types[0]=2;same(ref p);
    p=program();p.starts[0]=1;same(ref p);
    p=program();p.register_ends[0]=0;same(ref p);
    p=program();p.slice_origins[0]=17;same(ref p);
    p=program();p.array_parameters[0]=1;same(ref p);
    p=program();p.record_parameters[0]=1;same(ref p);
    p=program();p.array_results[0]=1;same(ref p);
    p=program();p.record_results[0]=1;same(ref p);
}

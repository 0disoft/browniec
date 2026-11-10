module tests::m2::output_call_arguments_work;
import output_call_arguments_work as work;
import array_parameters as raw;
import struct_layout as layouts;
import static_ir as statics;
import register_set as registers;
import metadata_budget as budget;
import ir as ir;
import errors as errors;

fn ir::Program program(){
    var ir::Program p=ir::empty();p.count=1;p.function_count=2;p.registers=2;p.register_ends[0]=1;p.register_starts[1]=1;
    p.register_ends[1]=2;p.arities[1]=1;p.call_count=1;p.call_arities[0]=1;p.types[0]=1;p.types[1]=1;return p;
}
fn registers::Set defined(){var registers::Set r=registers::empty();registers::insert(ref mut r,0);return r;}
fn Result<usize,errors::Error> staged(ref ir::Program p,ref statics::Sites sites,usize live){
    let layouts::Plan plan=switch(layouts::plan(ref p.records.layouts,18446744073709551615)){
        case .ok(v):{v}case .err(_):{assert(false);return .err(errors::make(5,7));}
    };
    let registers::Set r=defined();var work::State w=work::empty();let usize started=work::begin(ref mut w,1,0,0,live,7,true)?;
    var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<600);assert(budget::reset(ref mut meter,0).is_ok);
        let work::State saved=w;assert(budget::admit(ref mut meter,1,0).is_ok);let budget::State before=meter;
        let bool denied=work::advance(p,ref plan,sites,ref r,ref mut w,ref mut meter)?;
        assert(!denied && w.index==saved.index && w.phase==saved.phase && w.writers==saved.writers && w.writer_roots==saved.writer_roots);
        assert(meter.total==before.total && meter.last==before.last && meter.stages==before.stages);
        assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(p,ref plan,sites,ref r,ref mut w,ref mut meter)?;assert(done==w.done && meter.last==4096);turns+=1;
    }return .ok(p.call_arities[0] as usize);
}
fn void same(ref ir::Program p,ref statics::Sites sites,usize live){
    let registers::Set r=defined();
    switch(raw::arguments_static(p,1,0,0,ref r,live,7,ref sites.parameters)){
        case .ok(expected):{switch(staged(p,sites,live)){case .ok(actual):{assert(actual==expected);}case .err(_):{assert(false);}};}
        case .err(expected):{switch(staged(p,sites,live)){case .ok(_):{assert(false);}case .err(actual):{assert(actual.kind==expected.kind && actual.offset==expected.offset);}};}
    };
}
@test fn void scalar_static_and_unused_argument_rows_match_raw(){
    var ir::Program p=program();var statics::Sites sites=statics::empty();same(ref p,ref sites,0);
    p.call_args[7]=1;same(ref p,ref sites,0);p=program();p.slots[0]=true;same(ref p,ref sites,0);
    p=program();p.call_args[0]=127;same(ref p,ref sites,0);
    p=program();sites.parameters[1]=1;p.call_args[0]=192;same(ref p,ref sites,0);
}
@test fn void record_actuals_use_staged_nominal_proof_and_preserve_live_errors(){
    var ir::Program p=program();let statics::Sites sites=statics::empty();
    p.records.layouts.count=1;p.records.layouts.fields[0]=2;p.records.layouts.types[0]=10;p.records.layouts.types[1]=1;
    p.records.count=2;p.record_functions[0]=1;p.record_functions[1]=0;p.record_parameters[1]=1;p.types[1]=0;p.call_args[0]=145;
    same(ref p,ref sites,131072);same(ref p,ref sites,0);
    p.records.mutable[1]=true;same(ref p,ref sites,131072);p.records.mutable[1]=false;
    p.call_args[0]=160;same(ref p,ref sites,131072);
}

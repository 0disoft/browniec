module tests::m2::output_normalize_work;
import output_normalize_work as work;
import output_return_ir as raw;
import static_call_ir as programs;
import ir as ir;
import errors as errors;
import metadata_budget as budget;

fn programs::Program program(){
    var programs::Program unit=programs::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[1;16]};
    unit.body.count=5;unit.body.function_count=1;unit.body.ends[0]=5;
    unit.body.code[0]=66;unit.body.code[1]=1;unit.body.code[5]=1;
    unit.body.code[8]=68;unit.body.code[16]=56;unit.body.code[24]=67;unit.body.code[25]=1;
    unit.body.code[32]=65;unit.body.code[34]=1;return unit;
}
fn void equal(ref programs::Program a,ref programs::Program b){
    var usize i=0;while(i<2048){assert(a.body.code[i]==b.body.code[i]);i+=1;}
    i=0;while(i<16){assert(a.origins[i]==b.origins[i] && a.results[i]==b.results[i] && a.body.slice_elements[i]==b.body.slice_elements[i]);i+=1;}
    assert(a.body.count==b.body.count && a.body.function_count==b.body.function_count);
}
fn Result<usize,errors::Error> staged(ref mut programs::Program unit,ref raw::Signature signature){
    var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<850);assert(budget::reset(ref mut meter,0).is_ok);
        let programs::Program saved=*unit;let work::State before=w;assert(budget::admit(ref mut meter,1,0).is_ok);let budget::State allowance=meter;
        let bool denied=work::advance(unit,signature,ref mut w,ref mut meter)?;assert(!denied);equal(ref saved,unit);
        assert(w.pc==before.pc && w.function==before.function && w.phase==before.phase && w.rewritten==before.rewritten);
        var usize i=0;while(i<256){assert(w.interior[i]==before.interior[i]);i+=1;}
        assert(meter.total==allowance.total && meter.last==allowance.last && meter.stages==allowance.stages);
        assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(unit,signature,ref mut w,ref mut meter)?;assert(done==w.done && meter.last==4096);turns+=1;
    }return .ok(w.rewritten);
}
fn void same(programs::Program initial){
    var programs::Program expected=initial;var programs::Program actual=initial;
    var raw::Signature signature=raw::empty();signature.elements[0]=10;
    switch(raw::normalize(ref mut expected,ref signature)){
        case .ok(count):{switch(staged(ref mut actual,ref signature)){case .ok(got):{assert(count==got);}case .err(_):{assert(false);}};}
        case .err(e):{switch(staged(ref mut actual,ref signature)){case .ok(_):{assert(false);}case .err(a):{assert(e.kind==a.kind && e.offset==a.offset);}};}
    };equal(ref expected,ref actual);
}
@test fn void valid_bindings_shared_exclusive_and_terminal_rewrites_match_raw(){
    same(program());var programs::Program unit=program();unit.body.slice_elements[1]=138;same(unit);
    unit=program();unit.body.code[16]=63;same(unit);
    unit=program();unit.body.count=256;unit.body.ends[0]=256;same(unit);
}
@test fn void binding_tail_entry_jump_and_dangling_marker_errors_match_raw_mutations(){
    var programs::Program unit=program();unit.body.code[7]=1;same(unit);
    unit=program();unit.body.code[25]=2;same(unit);
    unit=program();unit.body.code[24]=8;same(unit);
    unit=program();unit.body.function_count=2;unit.body.starts[1]=1;same(unit);
    unit=program();unit.body.code[32]=19;unit.body.code[34]=3;same(unit);
    unit=program();unit.body.code[25]=16;unit.body.code[5]=16;same(unit);
    unit=program();unit.body.code[0]=1;same(unit);
    unit=program();unit.body.count=257;same(unit);
    unit=program();unit.body.function_count=17;same(unit);
}

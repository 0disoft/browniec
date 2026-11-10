module tests::m2::output_list_operands_work;
import output_list_operands_work as work;
import metadata_budget as budget;
import array_list_ir as raw;
import register_set as registers;
import ir as ir;
import errors as errors;

fn ir::Program program(){
    var ir::Program p=ir::empty();p.count=2;p.function_count=1;p.starts[0]=0;p.ends[0]=2;
    p.registers=1;p.register_ends[0]=1;p.types[0]=10;p.code[8]=80;
    p.arrays.count=1;p.arrays.elements[0]=10;p.arrays.lengths[0]=4096;p.list_used=4096;return p;
}
fn registers::Set defined(){var registers::Set s=registers::empty();registers::insert(ref mut s,0);return s;}
fn Result<usize,errors::Error> staged(ref ir::Program p,ref registers::Set definitions){
    var work::State state=work::empty(1,0);var budget::State meter=budget::empty();var usize turns=0;
    while(!state.done){assert(turns<70);assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(p,definitions,ref mut state,ref mut meter)?;
        assert(meter.last==4096 && done==state.done);turns+=1;
    }return .ok(state.length);
}
fn void same(ref ir::Program p,ref registers::Set definitions){
    switch(raw::operands(p,1,0,definitions)){
        case .ok(n):{switch(staged(p,definitions)){case .ok(m):{assert(n==m);}case .err(_):{assert(false);}};}
        case .err(e):{switch(staged(p,definitions)){case .ok(_):{assert(false);}case .err(a):{assert(e.kind==a.kind && e.offset==a.offset);}};}
    };
}
@test fn void maximum_lists_resume_and_match_raw_operand_proof(){
    var ir::Program p=program();let registers::Set s=defined();same(ref p,ref s);
    p.arrays.lengths[0]=65;same(ref p,ref s);p.arrays.lengths[0]=0;same(ref p,ref s);
    p=program();p.code[8]=87;p.code[12]=3;p.code[13]=1;same(ref p,ref s);
}
@test fn void late_undefined_foreign_and_aggregate_operands_match_raw_errors(){
    let registers::Set s=defined();var ir::Program p=program();p.list_operands[4095]=127;same(ref p,ref s);
    p=program();let registers::Set no=registers::empty();same(ref p,ref no);
    p.slots[0]=true;same(ref p,ref s);p=program();p.types[0]=1;same(ref p,ref s);
    p=program();p.array_parameters[0]=1;same(ref p,ref s);
    p=program();p.record_parameters[0]=1;same(ref p,ref s);
    p=program();p.slice_parameters[0]=1;same(ref p,ref s);
    p=program();p.register_starts[0]=1;same(ref p,ref s);
    p=program();p.code[9]=16;same(ref p,ref s);
    p=program();p.code[10]=1;same(ref p,ref s);
    p=program();p.list_used=4097;same(ref p,ref s);
    p=program();p.function_count=0;same(ref p,ref s);
}
@test fn void denied_entry_and_mid_scan_leave_every_cursor_and_counter_unchanged(){
    let ir::Program p=program();let registers::Set s=defined();var work::State w=work::empty(1,0);var budget::State meter=budget::empty();
    var usize turn=0;while(!w.done){
        assert(budget::reset(ref mut meter,0).is_ok);assert(budget::admit(ref mut meter,1,0).is_ok);
        let work::State before=w;let budget::State saved=meter;
        switch(work::advance(ref p,ref s,ref mut w,ref mut meter)){case .ok(done):{assert(!done);}case .err(_):{assert(false);}};
        assert(w.pc==before.pc && w.function==before.function && w.cursor==before.cursor && w.start==before.start &&
            w.length==before.length && w.root==before.root && w.begun==before.begun && w.done==before.done);
        assert(meter.total==saved.total && meter.last==saved.last && meter.stages==saved.stages);
        assert(budget::reset(ref mut meter,0).is_ok);assert(work::advance(ref p,ref s,ref mut w,ref mut meter).is_ok);
        turn+=1;assert(turn<70);
    }assert(turn==65);
    let usize total=meter.total;assert(work::advance(ref p,ref s,ref mut w,ref mut meter).is_ok);assert(total==meter.total);
}

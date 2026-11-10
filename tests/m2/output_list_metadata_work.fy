module tests::m2::output_list_metadata_work;
import output_list_metadata_work as work;
import metadata_budget as budget;
import array_list_ir as raw;
import ir as ir;
import errors as errors;

fn Result<usize,errors::Error> staged(ref ir::Program p){
    var work::State state=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    while(!state.done){assert(turns<280);assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(p,ref mut state,ref mut meter)?;
        assert(meter.last==4096 && done==state.done);turns+=1;
    }
    let usize total=meter.total;assert(work::advance(p,ref mut state,ref mut meter).is_ok);
    assert(total==meter.total);return .ok(p.list_used);
}
fn void same(ref ir::Program p){
    switch(raw::metadata(p)){
        case .ok(n):{switch(staged(p)){case .ok(m):{assert(n==m);}case .err(_):{assert(false);}};}
        case .err(e):{switch(staged(p)){case .ok(_):{assert(false);}case .err(actual):{assert(e.kind==actual.kind && e.offset==actual.offset);}};}
    };
}
fn ir::Program span(){
    var ir::Program p=ir::empty();p.count=2;p.arrays.count=1;p.arrays.lengths[0]=4096;
    p.list_used=4096;p.code[8]=80;return p;
}
@test fn void dense_spans_and_full_padding_match_raw_metadata(){
    var ir::Program p=ir::empty();same(ref p);p=span();same(ref p);
    p.arrays.lengths[0]=1;p.list_used=1;same(ref p);
    p.code[8]=87;p.code[10]=0;p.code[12]=3;p.code[13]=1;same(ref p);
    p.count=256;same(ref p);
}
@test fn void forged_spans_tail_padding_and_error_order_match_raw_metadata(){
    var ir::Program p=span();p.code[10]=1;same(ref p);
    p=span();p.arrays.lengths[0]=4097;same(ref p);
    p=span();p.arrays.lengths[0]=0;same(ref p);
    p=span();p.code[9]=1;same(ref p);
    p=span();p.list_used=4095;same(ref p);
    p=span();p.list_used=4097;same(ref p);
    p=span();p.count=257;same(ref p);
    p=span();p.arrays.count=17;same(ref p);
    p=ir::empty();p.list_used=1;same(ref p);
    p=ir::empty();p.list_operands[4095]=1;same(ref p);
    p=span();p.code[9]=1;p.list_operands[4095]=1;same(ref p);
}
@test fn void partial_room_leaves_continuation_and_counters_unchanged(){
    let ir::Program p=ir::empty();var work::State state=work::empty();var budget::State meter=budget::empty();
    var usize turn=0;while(!state.done){
        assert(budget::reset(ref mut meter,0).is_ok);assert(budget::admit(ref mut meter,1,0).is_ok);
        let work::State saved=state;let budget::State before=meter;
        switch(work::advance(ref p,ref mut state,ref mut meter)){case .ok(done):{assert(!done);}case .err(_):{assert(false);}};
        assert(state.phase==saved.phase && state.pc==saved.pc && state.cursor==saved.cursor && state.done==saved.done);
        assert(meter.total==before.total && meter.last==before.last && meter.stages==before.stages);
        assert(budget::reset(ref mut meter,0).is_ok);assert(work::advance(ref p,ref mut state,ref mut meter).is_ok);
        turn+=1;assert(turn<25);
    }assert(turn==18);
}

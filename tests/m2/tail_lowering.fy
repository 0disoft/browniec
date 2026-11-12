module tests::m2::tail_lowering;
import operand_tail_work as work;
import lexer as lexer;
import ir as ir;
import locals as locals;
import metadata_budget as budget;
fn void run(ref u8[] source,bool wrapped,bool propagation,u8 initial,u8 expected,bool primary){
    var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);let lexer::State original=s;
    var ir::Program p=ir::empty();var locals::Table names=locals::empty();
    let usize literal=switch(ir::integer(ref mut p,42,initial,0)){case .ok(v):{v}case .err(_):{assert(false);0}};
    let usize value=if(wrapped){switch(ir::construct(ref mut p,5,1,literal,0)){case .ok(v):{v}case .err(_):{assert(false);0}}}else{literal};
    if(propagation){names.count=2;names.registers[0]=128;names.registers[1]=129;names.pending_places=9;}
    var work::State w=work::begin(s,value,5,primary);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<2000);let usize count=p.count;let usize constants=p.constant_count;let usize registers=p.registers;
        let usize cursor=s.cursor;let usize visits=w.visits;let u8 phase=w.phase;let usize row=w.row;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut s,ref mut p,ref names,ref mut w,ref mut meter).is_ok);
        assert(s.cursor==cursor && p.count==count && p.constant_count==constants && p.registers==registers && w.visits==visits && w.phase==phase && w.row==row && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(source,ref mut s,ref mut p,ref names,ref mut w,ref mut meter).is_ok);
        assert(p.count-count<=1 && w.visits-visits<=1);
        if(phase==37 || phase==38){assert(w.phase!=phase || w.row==row || w.row+1==row);}
        turns+=1;
    }
    let usize result=switch(work::prepared(ref w)){case .ok(v):{v}case .err(_):{assert(false);0}};assert(p.types[result]==expected);
    if(primary || original.kind==46 && source.len==3){assert(s.cursor==original.cursor && s.tokens==original.tokens && result==value);}
    else{assert(s.kind==59);}
    if(propagation){assert(names.count==2 && names.pending_places==9 && names.registers[0]==128 && names.registers[1]==129);
        assert(p.code[6*8]==86 && p.code[6*8+1]==3 && p.code[7*8]==86 && p.code[7*8+1]==0);
        assert(p.code[8*8]==37 && p.code[8*8+1]==1 && p.code[9*8]==37 && p.code[9*8+1]==0);
        assert(p.code[10*8]==8 && p.code[11*8]==25);}
    let usize total=meter.total;assert(work::advance(source,ref mut s,ref mut p,ref names,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void postfix_and_cast_stages_defer_each_token_and_emit_one_instruction(){
    run(b".is_ok;",true,false,1,2,false);run(b"as i64;",false,false,1,9,false);
    run(b"as u32 as usize;",false,false,10,12,false);run(b"as i64;",false,false,1,1,true);
    run(b"..;",false,false,1,1,false);
}
@test fn void propagation_releases_one_reverse_selection_or_local_before_failure_return(){run(b"?;",true,true,1,1,false);}

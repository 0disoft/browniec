module tests::m2::call_operand_kernel;
import call_operand_work as work;
import lexer as lexer;
import locals as locals;
import functions as functions;
import ir as ir;
import metadata_budget as budget;
@test fn void pending_arguments_and_cleanup_rows_do_not_replay_or_publish_early(){
    let ref u8[] source=b"(42)";var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    var locals::Table names=locals::empty();var functions::Table signatures=functions::empty();signatures.count=1;signatures.arities[0]=1;signatures.param_types[0]=1;
    var ir::Program p=ir::empty();p.return_types[0]=1;var work::State w=work::begin(ref names,s,0,0,0);
    var budget::State meter=budget::empty();var usize turns=0;assert(!work::prepared(ref w).is_ok && !work::resume(ref mut w,1,0).is_ok);
    while(!w.done){assert(turns<2000);let u8 phase=w.phase;let usize count=p.count;let usize cursor=s.cursor;let usize row=w.row;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut s,ref mut p,ref signatures,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.row==row && p.count==count && s.cursor==cursor && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(source,ref mut s,ref mut p,ref signatures,ref mut w,ref mut meter).is_ok);
        if(phase==8){assert(p.count-count<=1);}
        if(w.request!=0){assert(w.request==1 && !work::resume(ref mut w,2,0).is_ok);let usize position=s.cursor;
            assert(budget::reset(ref mut meter,0).is_ok && work::advance(source,ref mut s,ref mut p,ref signatures,ref mut w,ref mut meter).is_ok && meter.last==0 && s.cursor==position);
            assert(lexer::next(source,ref mut s).is_ok);let usize value=switch(ir::integer(ref mut p,42,1,1)){case .ok(v):{v}case .err(_):{assert(false);0}};
            // Synthetic candidate rows check reverse finalizer order. Complete
            // source tests separately prove that real captures are well formed.
            w.names.count=2;w.names.registers[0]=128;w.names.registers[1]=129;
            assert(work::resume(ref mut w,1,value).is_ok && !work::resume(ref mut w,1,value).is_ok);}
        if(!w.done){assert(!work::prepared(ref w).is_ok);}turns+=1;
    }
    assert(work::prepared(ref w).is_ok && names.count==0 && s.kind==0 && p.count==4);
    assert(p.code[8]==9 && p.code[16]==37 && p.code[17]==1 && p.code[24]==37 && p.code[25]==0);
    let usize total=meter.total;assert(work::advance(source,ref mut s,ref mut p,ref signatures,ref mut w,ref mut meter).is_ok && meter.total==total);
}

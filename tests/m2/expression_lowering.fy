module tests::m2::expression_lowering;
import expression_source_work as work;
import lexer as lexer;
import ir as ir;
import vm as vm;
import verifier as verifier;
import metadata_budget as budget;
fn void run(ref u8[] source){var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    var work::State w=work::begin(0,1,1);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok && !work::resume(ref mut w,0).is_ok);
    while(!w.done){assert(turns<2000);assert(budget::reset(ref mut meter,0).is_ok);let usize visits=w.visits;
        let usize cursor=s.cursor;let usize count=p.count;let usize used=w.used;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut s,ref mut p,ref mut w,ref mut meter).is_ok);
        assert(w.visits==visits && s.cursor==cursor && p.count==count && w.used==used && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);assert(work::advance(source,ref mut s,ref mut p,ref mut w,ref mut meter).is_ok);
        assert(w.visits-visits<=1);if(w.waiting){let work::Frame f=work::current(ref w);let i64 value=s.value;
            assert(s.kind==1 && lexer::next(source,ref mut s).is_ok);let usize reg=switch(ir::integer(ref mut p,value,if(f.expected==0){1}else{f.expected},cursor)){case .ok(v):{v}case .err(_):{assert(false);0}};
            assert(work::resume(ref mut w,reg).is_ok && !work::resume(ref mut w,reg).is_ok);}
        turns+=1;
    }
    let usize result=switch(work::prepared(ref w)){case .ok(v):{v}case .err(_):{assert(false);0}};assert(s.kind==59);
    assert(ir::emit(ref mut p,8,result,0,0).is_ok);let usize end=p.count;let usize registers=p.registers;p.ends[0]=end;p.register_ends[0]=registers;
    assert(verifier::verify(ref p).is_ok && switch(vm::run(ref p,1000000)){case .ok(v):{v==42}case .err(_):{false}});
    let usize total=meter.total;assert(work::advance(source,ref mut s,ref mut p,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void pratt_frames_defer_and_resume_without_replaying_operands(){run(b"20+11*2;");run(b"50-12/3*2;");}

@test fn void expression_depth_rejects_before_requesting_an_operand(){let ref u8[] source=b"1;";
    var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);var ir::Program p=ir::empty();
    var work::State w=work::begin(33,1,1);var budget::State meter=budget::empty();
    switch(work::advance(source,ref mut s,ref mut p,ref mut w,ref mut meter)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==4 && e.offset==0 && !w.waiting && p.count==0);}};
    w=work::begin(32,1,1);assert(budget::reset(ref mut meter,0).is_ok);
    assert(work::advance(source,ref mut s,ref mut p,ref mut w,ref mut meter).is_ok && w.waiting && p.count==0);
}

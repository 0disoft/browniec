module tests::m2::expression_lowering;
import expression_source_work as work;
import lexer as lexer;
import functions as functions;
import ir as ir;
import vm as vm;
import verifier as verifier;
import metadata_budget as budget;
fn void run(ref u8[] source){var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    var work::Bank bank=work::empty_bank();var functions::Table signatures=functions::empty();var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=1;p.return_types[1]=1;p.arities[0]=2;
    p.types[0]=1;p.types[1]=1;p.registers=2;assert(ir::emit(ref mut p,2,0,1,0).is_ok);assert(ir::emit(ref mut p,8,2,0,0).is_ok);
    let usize start=p.count;let usize first=p.registers;p.ends[0]=start;p.register_ends[0]=first;p.starts[1]=start;p.register_starts[1]=first;
    var work::State w=work::begin(0,1,1);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok && !work::resume(ref mut w,0).is_ok);
    while(!w.done){assert(turns<2000);assert(budget::reset(ref mut meter,0).is_ok);let usize visits=w.visits;
        let usize cursor=s.cursor;let usize count=p.count;let usize used=w.used;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut s,ref mut p,ref signatures,ref mut bank,ref mut w,ref mut meter).is_ok);
        assert(w.visits==visits && s.cursor==cursor && p.count==count && w.used==used && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);assert(work::advance(source,ref mut s,ref mut p,ref signatures,ref mut bank,ref mut w,ref mut meter).is_ok);
        assert(w.visits-visits<=1);if(w.waiting){let work::Frame f=work::current(ref w);
            let usize before=w.visits;let usize position=s.cursor;assert(budget::reset(ref mut meter,0).is_ok);
            assert(work::advance(source,ref mut s,ref mut p,ref signatures,ref mut bank,ref mut w,ref mut meter).is_ok && meter.last==0 && w.visits==before && s.cursor==position);
            if(w.request==2){let usize initial=w.value;assert(work::resume(ref mut w,initial).is_ok);}
            else if(s.kind==45 || s.kind==33 || s.kind==126){assert(work::unary(ref mut w,s.kind,f.expected,s.begin).is_ok && !work::unary(ref mut w,s.kind,f.expected,s.begin).is_ok);}
            else if(s.kind==2){let u8[8] tags=[1;8];
                assert(work::call(ref mut w,0,2,ref tags,s.begin).is_ok && !work::call(ref mut w,0,2,ref tags,s.begin).is_ok);}
            else if(s.kind==40){assert(work::group(ref mut w,f.expected).is_ok && !work::group(ref mut w,f.expected).is_ok);}
            else{let i64 value=s.value;let usize at=s.begin;
                assert(s.kind==1 && lexer::next(source,ref mut s).is_ok);let usize reg=switch(ir::integer(ref mut p,value,if(f.expected==0){1}else{f.expected},at)){case .ok(v):{v}case .err(_):{assert(false);0}};
                assert(work::resume(ref mut w,reg).is_ok && !work::resume(ref mut w,reg).is_ok);}}
        turns+=1;
    }
    let usize result=switch(work::prepared(ref w)){case .ok(v):{v}case .err(_):{assert(false);0}};assert(s.kind==59);
    assert(ir::emit(ref mut p,8,result,0,0).is_ok);let usize end=p.count;let usize registers=p.registers;p.ends[1]=end;p.register_ends[1]=registers;
    assert(verifier::verify(ref p).is_ok && switch(vm::run(ref p,1000000)){case .ok(v):{v==42}case .err(_):{false}});
    let usize total=meter.total;assert(work::advance(source,ref mut s,ref mut p,ref signatures,ref mut bank,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void pratt_frames_defer_and_resume_without_replaying_operands(){run(b"20+11*2;");run(b"50-12/3*2;");}

@test fn void expression_depth_rejects_before_requesting_an_operand(){let ref u8[] source=b"1;";
    var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);var work::Bank bank=work::empty_bank();var functions::Table signatures=functions::empty();var ir::Program p=ir::empty();
    var work::State w=work::begin(33,1,1);var budget::State meter=budget::empty();
    switch(work::advance(source,ref mut s,ref mut p,ref signatures,ref mut bank,ref mut w,ref mut meter)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==4 && e.offset==0 && !w.waiting && p.count==0);}};
    w=work::begin(32,1,1);assert(budget::reset(ref mut meter,0).is_ok);
    assert(work::advance(source,ref mut s,ref mut p,ref signatures,ref mut bank,ref mut w,ref mut meter).is_ok && w.waiting && p.count==0);
}

@test fn void group_children_share_the_pratt_stack_and_resume_one_tail(){run(b"(20+1)*2;");run(b"((20+11*2));");}

@test fn void nested_scalar_calls_share_pratt_frames_and_evaluate_each_argument_once(){run(b"sum((20),11*2);");run(b"sum(sum(10,10),sum(11,11));");}

@test fn void unary_children_defer_tokens_checks_and_emission_on_shared_frames(){
    run(b"-(-42);");run(b"~(-43);");run(b"-20+62;");run(b"~0+43;");
    run(b"-sum(20,22)+84;");run(b"sum(-(-20),~(-23));");
}

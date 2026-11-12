module tests::m2::evaluation_lowering;
import conditional_evaluation_work as work;
import static_evaluation_work as statics;
import record_evaluation_work as records;
import compiler as compiler;
import lexer as lexer;
import locals as locals;
import functions as functions;
import ir as ir;
import loops as loops;
import value_join_source as joins;
import metadata_budget as budget;
@test fn void actual_conditional_steps_defer_without_emission_or_operand_replay(){
    let ref u8[] source=b"if(true){if(false){0}else{42}}else{0};";
    var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    let locals::Table names=locals::empty();let functions::Table signatures=functions::empty();var ir::Program p=ir::empty();
    var loops::State flow=loops::empty();var joins::Join join=joins::empty(1,false);
    var work::State w=work::begin(ref names,0,0,1);var budget::State meter=budget::empty();var usize turns=0;var usize operands=0;
    assert(!work::prepared(ref w).is_ok);while(!w.done){assert(turns<10000);let usize visits=w.visits;let usize count=p.count;let usize registers=p.registers;let usize cursor=s.cursor;
        let work::Frame f=work::current(ref w);assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut s,ref mut p,ref signatures,ref mut join,ref mut w,ref mut meter).is_ok);
        let work::Frame after=work::current(ref w);assert(after.phase==f.phase && w.visits==visits && p.count==count && p.registers==registers && s.cursor==cursor && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(source,ref mut s,ref mut p,ref signatures,ref mut join,ref mut w,ref mut meter).is_ok && w.visits-visits<=1);
        let u8 request=w.request;if(request!=0){assert(request==1 || request==4);operands+=1;
            let usize value=switch(compiler::expression_staged(source,ref mut s,ref mut p,ref w.names,ref signatures,1,w.child_depth,w.expected,1,w.child_structure,ref mut flow)){
                case .ok(v):{v}case .err(_):{assert(false);0}};
            assert(work::resume(ref mut w,request,value,false).is_ok);}
        turns+=1;}
    assert(operands==5 && names.count==0 && w.names.count==0 && !w.stopped && work::prepared(ref w).is_ok);
    let usize total=meter.total;let usize count=p.count;assert(work::advance(source,ref mut s,ref mut p,ref signatures,ref mut join,ref mut w,ref mut meter).is_ok && meter.total==total && p.count==count);
}
@test fn void record_and_static_evaluation_guards_keep_candidates_private(){
    var ir::Program p=ir::empty();var records::State r=records::begin(0,0,0);var budget::State meter=budget::empty();
    assert(!records::prepared(ref r).is_ok && budget::admit(ref mut meter,1,0).is_ok);
    assert(records::advance(ref mut p,ref mut r,ref mut meter).is_ok && r.phase==0 && r.request==0 && p.count==0);
    assert(budget::reset(ref mut meter,0).is_ok && records::advance(ref mut p,ref mut r,ref mut meter).is_ok && r.request==4 && p.count==0);
    let locals::Table names=locals::empty();let ref u8[] source=b".len;";var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    var statics::State w=statics::begin(0,0,0,0,false,false);assert(!statics::prepared(ref w).is_ok);
    while(!w.done){let usize visits=w.visits;let usize cursor=s.cursor;let usize count=p.count;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(statics::advance(source,ref mut s,ref mut p,ref names,ref mut w,ref mut meter).is_ok && w.visits==visits && s.cursor==cursor && p.count==count && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok && statics::advance(source,ref mut s,ref mut p,ref names,ref mut w,ref mut meter).is_ok && w.visits-visits<=1);}
    assert(statics::prepared(ref w).is_ok && p.count==1 && p.registers==1 && p.types[0]==12);
}

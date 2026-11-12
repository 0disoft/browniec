module tests::m2::preflight_lowering;
import operand_preflight_work as work;
import lexer as lexer;
import casts as casts;
import errors as errors;
import metadata_budget as budget;
fn void run(ref u8[] source,u8 expected,bool primary,u8 context){var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    let lexer::State before=s;var work::State w=work::begin(s,expected,primary);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);while(!w.done){assert(turns<2000);let usize visits=w.visits;let usize cursor=w.look.cursor;let u8 phase=w.phase;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut w,ref mut meter).is_ok && w.visits==visits && w.look.cursor==cursor && w.phase==phase && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(source,ref mut w,ref mut meter).is_ok && w.visits-visits<=1);turns+=1;}
    assert(s.cursor==before.cursor && s.tokens==before.tokens && s.begin==before.begin);
    assert(switch(work::prepared(ref w)){case .ok(v):{v==context}case .err(_):{false}});
    let usize total=meter.total;assert(work::advance(source,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void cast_and_result_scans_preserve_contexts_and_never_consume_the_real_lexer(){
    run(b"42 as i64;",9,false,0);run(b"42 as i64;",9,true,9);run(b"(42 as i64);",9,false,9);
    run(b"r.is_ok;",2,false,0);run(b"r.other.is_ok;",2,false,0);run(b"r..is_ok;",2,false,2);
    run(b"f(r.is_ok);",2,false,2);run(b"(r).is_ok;",2,false,0);run(b"r.is_ok;",6,false,6);
    run(b"~(20+22);",1,false,1);run(b"- -42 as i64;",9,false,0);run(b"r.is_ok as i64;",9,false,0);
}
@test fn void malformed_cast_lookahead_keeps_raw_error_order_without_publication(){
    let ref u8[] source=b"f( /*";var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);let lexer::State before=s;
    let Result<bool,errors::Error> raw=casts::follows(source,ref s);assert(!raw.is_ok);
    var work::State w=work::begin(s,2,false);var budget::State meter=budget::empty();var bool failed=false;var usize turns=0;
    while(!failed){assert(turns<100 && budget::reset(ref mut meter,0).is_ok);switch(work::advance(source,ref mut w,ref mut meter)){
        case .ok(_):{}case .err(e):{switch(raw){case .ok(_):{assert(false);}case .err(z):{assert(e.kind==z.kind && e.offset==z.offset);}};failed=true;}};turns+=1;}
    assert(!work::prepared(ref w).is_ok && s.cursor==before.cursor && s.tokens==before.tokens);
}

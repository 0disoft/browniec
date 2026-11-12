module tests::m2::preflight_lowering;
import operand_preflight_work as work;
import lexer as lexer;
import casts as casts;
import errors as errors;
import metadata_budget as budget;
import operand_route_work as routes;
import functions as functions;
import locals as locals;
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

fn void route(ref u8[] source,usize a,usize b,usize encoded,bool capture,bool scoped,u8 lane){
    var lexer::State s=lexer::empty();if(scoped){s.cursor=2;}assert(lexer::next(source,ref mut s).is_ok);let lexer::State original=s;
    var functions::Table signatures=functions::empty();signatures.count=1;signatures.begins[0]=a;signatures.ends[0]=b;signatures.return_types[0]=1;
    signatures.arities[0]=1;signatures.param_types[0]=1;if(capture){signatures.param_lengths[0]=1;}
    if(scoped){signatures.begins[0]=0;signatures.ends[0]=1;signatures.context.modules=1;signatures.context.ends[0]=5;signatures.context.function_count=1;signatures.context.functions[0]=8192;}
    var locals::Table names=locals::empty();if(encoded<256){names.count=1;names.begins[0]=a;names.ends[0]=b;names.registers[0]=encoded;}
    var routes::State w=routes::begin(s,0);var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<4000);let usize visits=w.visits;let usize cursor=w.look.cursor;let u8 phase=w.phase;let usize row=w.row;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(routes::advance(source,ref names,ref signatures,ref mut w,ref mut meter).is_ok && w.phase==phase && w.visits==visits && w.look.cursor==cursor && w.row==row && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok && routes::advance(source,ref names,ref signatures,ref mut w,ref mut meter).is_ok && w.visits-visits<=1);
        if(w.row>row){assert(w.row-row<=1);}turns+=1;}
    assert(w.lane==lane && s.cursor==original.cursor && s.tokens==original.tokens && s.begin==original.begin);
    let usize total=meter.total;assert(routes::advance(source,ref names,ref signatures,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void ordinary_routes_resume_group_tokens_name_rows_and_formals_without_consumption(){
    route(b"id(42);",0,2,256,false,false,3);route(b"id(42);",0,2,256,true,false,4);
    route(b"id(42);",0,2,0,false,false,0);route(b"((id(42)));",2,4,256,false,false,1);
    route(b"(a[0]+22);",1,2,128,false,false,1);route(b"(a)[0];",1,2,128,false,false,0);
    route(b"(p.x+22);",1,2,144,false,false,1);route(b"(p).x;",1,2,144,false,false,0);
    route(b"(if(true){42}else{0});",1,3,256,false,false,0);route(b"-42;",0,1,256,false,false,2);
    route(b"f f()",2,3,256,false,true,3);
}

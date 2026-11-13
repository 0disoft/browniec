module tests::m2::value_probe_lowering;
import value_probe_work as work;
import value_source_context as context;
import value_source_headers as headers;
import lexer as lexer;
import errors as errors;
import metadata_budget as budget;
import std::bytes as bytes;
fn void token(ref lexer::State a,ref lexer::State b){assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end && a.kind==b.kind && a.value==b.value && a.tokens==b.tokens && a.min_magnitude==b.min_magnitude && a.context==b.context);}
fn void result(Result<bool,errors::Error> a,Result<bool,errors::Error> b){switch(a){case .ok(x):{assert(switch(b){case .ok(y):{x==y}case .err(_):{false}});}case .err(x):{assert(switch(b){case .ok(_):{false}case .err(y):{x.kind==y.kind && x.offset==y.offset}});}};}
fn void compare(ref u8[] source){var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);let lexer::State before=s;
    result(context::postfix_receiver_raw(source,ref s),context::postfix_receiver(source,ref s));
    result(context::tail_control_raw(source,ref s),context::tail_control(source,ref s));
    result(context::tail_expression_raw(source,ref s),context::tail_expression(source,ref s));
    result(context::assignment_ahead_raw(source,ref s),context::assignment_ahead(source,ref s));token(ref before,ref s);
}
@test fn void typed_advisory_walks_keep_raw_decisions_errors_and_private_cursors(){
    compare(b"x=42;");compare(b"x+=42;");compare(b"_ = 42;");compare(b"(x).is_ok;");compare(b"x..y;");compare(b"x.foo+1;");compare(b"x[0];");compare(b"x?;");
    compare(b"if(true){42}else if(false){0}else{1}}");compare(b"if(true){42}else{0}+2;");compare(b"switch(x){case .some(n):{n}case .none:{0}}.is_ok;");
    compare(b"if(true){foo((1))}else{return 0;};");compare(b"foo() }");compare(b"foo(); }");compare(b"x @");compare(b"if(true){42}else{@}");compare(b"x /* unclosed");
    var bytes::Buffer large=bytes::empty();assert(bytes::append(ref mut large,b"x=").is_ok);let u8[256] padding=[32;256];var usize i=0;while(i<16){assert(bytes::append(ref mut large,ref padding).is_ok);i+=1;}compare(bytes::view(ref large));
}
fn void pure(ref u8[] source,u8 terminator){var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);let lexer::State before=s;
    let Result<usize,errors::Error> a=headers::pure_raw(source,ref s,terminator);let Result<usize,errors::Error> b=headers::pure(source,ref s,terminator);
    switch(a){case .ok(x):{assert(switch(b){case .ok(y):{x==y}case .err(_):{false}});}case .err(x):{assert(switch(b){case .ok(_):{false}case .err(y):{x.kind==y.kind && x.offset==y.offset}});}};token(ref before,ref s);
}
@test fn void typed_for_header_walk_keeps_raw_restrictions_and_offsets(){
    pure(b"i=(1+2);",59);pure(b"i+=1)",41);pure(b"f();",59);pure(b"x.len;",59);pure(b"ref x;",59);pure(b"if(true){1};",59);pure(b"(1+2",59);pure(b"x @",59);pure(b")",59);pure(b";",59);
}
@test fn void advisory_walks_charge_bounded_children_and_guard_denied_completed_steps(){
    let ref u8[] source=b"if(true){ /* a long comment split across lexer stages ........................................................ */ 42 }else{0}}";
    var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);let lexer::State before=s;
    var work::State w=work::begin(s,1,0);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<1000);let u8 phase=w.phase;let usize at=w.look.begin;let usize parens=w.parens;let usize braces=w.braces;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut w,ref mut meter).is_ok && meter.total==total && w.phase==phase && w.look.begin==at && w.parens==parens && w.braces==braces);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(source,ref mut w,ref mut meter).is_ok);turns+=1;
    }
    assert(turns>20 && switch(work::prepared(ref w)){case .ok(v):{v==1}case .err(_):{false}});let usize total=meter.total;
    assert(work::advance(source,ref mut w,ref mut meter).is_ok && meter.total==total);token(ref before,ref s);
}

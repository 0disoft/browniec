module tests::m2::type_parse_work;
import type_parse_work as work;
import types as raw;
import lexer as lexer;
import errors as errors;
import metadata_budget as budget;
fn void same_state(ref lexer::State a,ref lexer::State b){
    assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end && a.tokens==b.tokens && a.kind==b.kind &&
        a.value==b.value && a.min_magnitude==b.min_magnitude && a.context==b.context);
}
fn Result<u8,errors::Error> run(ref u8[] source,ref mut lexer::State s){
    var work::State w=work::begin(*s);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<1800);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let bool waiting=w.waiting;let usize cursor=w.token.cursor;
        let usize visits=w.scan.scan.visits;let usize inner=w.scan.scan.inner;let u8 lexical=w.scan.phase;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.waiting==waiting && w.token.cursor==cursor && w.scan.phase==lexical &&
            w.scan.scan.visits==visits && w.scan.scan.inner==inner && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);
        switch(work::advance(source,ref mut w,ref mut meter)){
            case .ok(done):{assert(done==w.done && meter.last==4096);}
            case .err(e):{*s=work::observed(ref w);return .err(e);}
        };turns+=1;
    }
    let usize total=meter.total;assert(work::advance(source,ref mut w,ref mut meter).is_ok && meter.total==total);
    *s=work::observed(ref w);return work::prepared(ref w);
}
fn void compare(ref u8[] source,bool scoped){
    var lexer::State a=lexer::empty();
    if(scoped){a=switch(lexer::scoped(source,0,source.len,false)){case .ok(v):{v}case .err(_):{assert(false);lexer::empty()}};}
    assert(lexer::next_raw(source,ref mut a).is_ok);var lexer::State b=a;
    let Result<u8,errors::Error> expected=raw::parse(source,ref mut a);
    let Result<u8,errors::Error> actual=run(source,ref mut b);same_state(ref a,ref b);
    switch(expected){case .ok(tag):{switch(actual){case .ok(value):{assert(tag==value);}case .err(_):{assert(false);}};}
        case .err(e):{switch(actual){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};}};
}
@test fn void scalar_and_wrapper_tags_and_remaining_token_match(){
    compare(b"i32 name",false);compare(b"bool ;",false);compare(b"i64 x",false);compare(b"u8 x",false);
    compare(b"u32 x",false);compare(b"usize x",false);compare(b"Option<i32> p",false);compare(b"Option<bool> p",false);
    compare(b"Result<i32,i32> p",false);compare(b"Result<i32,bool> p",false);
    compare(b"Result<bool,i32> p",false);compare(b"Result<bool,bool> p",false);
    compare(b"Result /*a*/ < bool /*b*/, i32 /*c*/ > name::field",true);
}
@test fn void syntax_type_and_lexical_diagnostic_order_match(){
    compare(b"",false);compare(b"123",false);compare(b"void",false);compare(b"Other p",false);
    compare(b"Option i32",false);compare(b"Option<",false);compare(b"Option<Option<i32>>",false);
    compare(b"Option<i64>,",false);compare(b"Option<u8 \xff",false);compare(b"Option<i32,",false);
    compare(b"Result<i32 i32>",false);compare(b"Result<i32,u32>",false);compare(b"Result<i32,bool",false);
    compare(b"i32 \xff",false);compare(b"Result<i32,bool> \"\\q\"",false);
    compare(b"i32 name /*bare\r*/",true);compare(b"Option<i32> name::1",true);
}
@test fn void long_intertoken_comments_resume_inside_the_type_parser(){
    var u8[4096] source=[32;4096];source[0]=105;source[1]=51;source[2]=50;
    source[3]=47;source[4]=42;source[4093]=42;source[4094]=47;source[4095]=59;
    compare(ref source,false);compare(ref source,true);
    source[4093]=32;compare(ref source,false);
}

module tests::m2::lexer_work;
import lexer_work as work;
import lexer as raw;
import metadata_budget as budget;
import errors as errors;
fn void equal(ref raw::State a,ref raw::State b){
    assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end && a.tokens==b.tokens && a.kind==b.kind &&
        a.value==b.value && a.min_magnitude==b.min_magnitude && a.context==b.context);
}
fn Result<usize,errors::Error> next(ref u8[] source,ref mut raw::State result){
    var work::State w=work::begin(*result);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<1024);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let u8 mode=w.scan.mode;let usize inner=w.scan.inner;let usize visits=w.scan.visits;
        let usize literal=w.scan.literal.cursor;let usize checked=w.scan.literal.checked;let usize cursor=w.scan.target.cursor;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.scan.mode==mode && w.scan.inner==inner && w.scan.visits==visits && w.scan.target.cursor==cursor &&
            w.scan.literal.cursor==literal && w.scan.literal.checked==checked && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);
        switch(work::advance(source,ref mut w,ref mut meter)){
            case .ok(done):{assert(done==w.done && meter.last==4096 && w.scan.visits-visits<=16);}
            case .err(e):{*result=work::observed(ref w);return .err(e);}
        };turns+=1;
    }
    let usize total=meter.total;assert(work::advance(source,ref mut w,ref mut meter).is_ok && meter.total==total);
    *result=switch(work::prepared(ref w)){case .ok(v):{v}case .err(e):{return .err(e);}};return .ok(0);
}
fn void trace(ref u8[] source,raw::State initial){
    var raw::State expected=initial;var raw::State actual=initial;var usize tokens=0;
    while(tokens<1030){let Result<usize,errors::Error> a=raw::next(source,ref mut expected);
        let Result<usize,errors::Error> b=next(source,ref mut actual);equal(ref expected,ref actual);
        switch(a){case .ok(_):{assert(b.is_ok);if(expected.kind==0){return;}}
            case .err(e):{switch(b){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};return;}};
        tokens+=1;
    }assert(false);
}
fn raw::State scoped(ref u8[] source,usize start,usize end,bool text){return switch(raw::scoped(source,start,end,text)){
    case .ok(v):{v}case .err(_):{assert(false);raw::empty()}};}
@test fn void operators_comments_numbers_literals_and_token_limits_match(){
    trace(b"\xef\xbb\xbf a_9 //line\r\n /* outer /*inner*/ */ 0 9223372036854775808 18446744073709551615 == != <= >= && || << >> += -= *= /= %= <<= >>= &= ^= |= ( ) { } ; + - * / % = , ! < > . : ? & ^ | ~ [ ] b\"\\xff\" \"\\u{1f600}\"",raw::empty());
    trace(b"18446744073709551616",raw::empty());trace(b"abc c\"bad\"",raw::empty());trace(b"\xff",raw::empty());
    var u8[2050] source=[59;2050];trace(ref source,raw::empty());
}
@test fn void scoped_qualified_lookahead_and_failed_state_match(){
    let ref u8[] names=b"a /*x*/ :: b :: c : d text::validate";
    trace(names,scoped(names,0,names.len,false));trace(names,scoped(names,0,names.len,true));
    let ref u8[] bad=b"first :: second :: 1";trace(bad,scoped(bad,0,bad.len,false));
    let ref u8[] comment=b"name /* bare\r */";trace(comment,scoped(comment,0,comment.len,false));
    let ref u8[] invalid=b"name \"\\xff\"";trace(invalid,scoped(invalid,0,invalid.len,false));
    let ref u8[] fenced=b"ignore a::b//tail\xef\xbb\xbfmodule z;";
    trace(fenced,scoped(fenced,7,16,false));trace(fenced,scoped(fenced,16,fenced.len,false));
    var raw::State forged=raw::empty();forged.context=1;trace(b"a",forged);
}
@test fn void long_names_comments_and_literal_sources_resume(){
    var u8[4096] source=[65;4096];trace(ref source,raw::empty());
    source=[32;4096];source[0]=47;source[1]=47;trace(ref source,raw::empty());
    source=[65;4096];source[0]=47;source[1]=42;source[4094]=42;source[4095]=47;trace(ref source,raw::empty());
    source=[65;4096];source[0]=34;source[4095]=34;trace(ref source,raw::empty());
    trace(b"/* /*x*/",raw::empty());trace(b"//bad\r",raw::empty());trace(b"/*\x00*/",raw::empty());
    trace(b"/*\xef\xbb\xbf*/",raw::empty());trace(b" /* good */ \"\xff\\q\"",raw::empty());
}

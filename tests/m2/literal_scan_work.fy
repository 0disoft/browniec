module tests::m2::literal_scan_work;
import literal_scan_work as work;
import literal_source as raw;
import metadata_budget as budget;
import errors as errors;
fn Result<usize,errors::Error> staged(ref u8[] source,usize begin){
    var work::State w=work::empty(begin);var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<512);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize cursor=w.cursor;let usize checked=w.checked;let usize visits=w.visits;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        let bool deferred=work::advance(source,ref mut w,ref mut meter)?;
        assert(!deferred && w.phase==phase && w.cursor==cursor && w.checked==checked && w.visits==visits && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);let bool done=work::advance(source,ref mut w,ref mut meter)?;
        assert(done==w.done && meter.last==4096 && w.visits-visits<=16);turns+=1;
    }return .ok(w.end);
}
fn void same(ref u8[] source,usize begin){
    switch(raw::scan(source,begin)){
        case .ok(a):{switch(staged(source,begin)){case .ok(b):{assert(a==b);}case .err(_):{assert(false);}};}
        case .err(a):{switch(staged(source,begin)){case .ok(_):{assert(false);}
            case .err(b):{assert(a.kind==b.kind && a.offset==b.offset);}};}
    };
}
@test fn void token_only_scanning_preserves_raw_and_cooked_encoding(){
    same(b"b\"\\xff\\0\"",0);same(b"\"\\u{0}\\u{7ff}\\u{ffff}\\u{10ffff}\"",0);
    same(b"\"\\xc2\\xa2\"",0);same(b"\"\\xf0\\x90\\x80\\x80\"",0);
    var u8[4096] data=[65;4096];data[0]=34;data[4095]=34;data[255]=240;data[256]=144;data[257]=128;data[258]=128;same(ref data,0);
}
@test fn void token_only_errors_keep_escape_before_encoding_precedence(){
    same(b"\"\\xc0\\x80\"",0);same(b"\"\\xed\\xa0\\x80\"",0);same(b"\"\\xf4\\x90\\x80\\x80\"",0);
    same(b"\"\\xc2\"",0);same(b"\"\\xc2A\"",0);same(b"\"\xff\\q\"",0);same(b"\"\\xff\\q\"",0);
    same(b"\"\\u{d800}\"",0);same(b"\"\\u{}\"",0);same(b"b\"\\u{41}\"",0);same(b"\"\xef\xbb\xbf\"",0);
    same(b"nothing",0);same(b"\"open",0);same(b"\"\\x0\"",0);same(b"\"\x00\"",0);same(b"\"\n\"",0);
}
